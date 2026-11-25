package cli

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"text/tabwriter"

	"github.com/spf13/cobra"

	"github.com/gubernator-org/gubernator/internal/ebpf"
)

var ebpfCmd = &cobra.Command{
	Use:   "ebpf",
	Short: "Inspect kernel network telemetry, captured flows, and service mesh topology",
	Long:  "eBPF subsystem provides kernel-level packet tracing, socket inspection, L4/L7 flow monitoring, and service mesh topology visualization.",
}

var ebpfStatusCmd = &cobra.Command{
	Use:   "status",
	Short: "Show eBPF kernel capabilities, active probes, and telemetry stats",
	Run: func(cmd *cobra.Command, args []string) {
		resp, err := DoAPIRequest("GET", "/v1/ebpf/stats", nil)
		if err != nil {
			_, _ = fmt.Fprintf(os.Stderr, "Failed to connect to Manager: %v\n", err)
			os.Exit(1)
		}
		defer func() { _ = resp.Body.Close() }()

		if resp.StatusCode != http.StatusOK {
			body, _ := io.ReadAll(resp.Body)
			_, _ = fmt.Fprintf(os.Stderr, "Failed to fetch eBPF status: %s\n", string(body))
			os.Exit(1)
		}

		var stats ebpf.NetworkStats
		if err := json.NewDecoder(resp.Body).Decode(&stats); err != nil {
			_, _ = fmt.Fprintf(os.Stderr, "Failed to parse response: %v\n", err)
			os.Exit(1)
		}

		modeStr := "KERNEL ACTIVE 🟢"
		if stats.Mode == "emulation" {
			modeStr = "EMULATION MODE 🟡"
		} else if !stats.EBPFSupported {
			modeStr = "DISABLED / UNSUPPORTED 🔴"
		}

		fmt.Println("🛰️  GUBERNATOR eBPF KERNEL OBSERVABILITY")
		fmt.Println("================================================================")
		fmt.Printf("  • Kernel Release:    %s\n", stats.KernelVersion)
		fmt.Printf("  • Operational Mode:  %s\n", modeStr)
		fmt.Printf("  • Active Probes:     %d\n", stats.ActiveProbes)
		if len(stats.ProbesList) > 0 {
			fmt.Printf("    Probes:            %s\n", strings.Join(stats.ProbesList, ", "))
		}
		fmt.Printf("  • Captured Flows:    %d total (%d active in last 30s)\n", stats.TotalFlows, stats.ActiveFlows)
		fmt.Printf("  • Packet Rate:       %.1f pkts/sec\n", stats.PacketsPerSec)
		fmt.Printf("  • Throughput:        %s\n", formatBytesRate(stats.BytesPerSec))
		fmt.Printf("  • Dropped Packets:   %d\n", stats.DroppedPackets)
		fmt.Println("----------------------------------------------------------------")

		if len(stats.ProtocolCounts) > 0 {
			fmt.Println("📊 Protocol Distribution (Active Flows):")
			for proto, cnt := range stats.ProtocolCounts {
				fmt.Printf("  - %-12s: %d\n", proto, cnt)
			}
		}

		if len(stats.StatusCounts) > 0 {
			fmt.Println("🚦 Flow Health Breakdown:")
			for st, cnt := range stats.StatusCounts {
				fmt.Printf("  - %-12s: %d\n", strings.ToUpper(st), cnt)
			}
		}

		if len(stats.Interfaces) > 0 {
			fmt.Println("\n🔌 Network Device Telemetry (/proc/net/dev):")
			fmt.Printf("  %-12s %-12s %-12s %-12s %-12s %-8s\n", "IFACE", "RX BYTES", "TX BYTES", "RX PKTS", "TX PKTS", "DROPS")
			for _, iface := range stats.Interfaces {
				if iface.RxBytes > 0 || iface.TxBytes > 0 {
					fmt.Printf("  %-12s %-12s %-12s %-12d %-12d %-8d\n",
						iface.Name,
						formatBytes(iface.RxBytes),
						formatBytes(iface.TxBytes),
						iface.RxPackets,
						iface.TxPackets,
						iface.RxDrops+iface.TxDrops,
					)
				}
			}
		}
	},
}

var (
	flowLimit  int
	flowProto  string
	flowErrors bool
	flowQuery  string
)

var ebpfFlowsCmd = &cobra.Command{
	Use:   "flows",
	Short: "Stream or list recent L4/L7 network flows captured by eBPF probes",
	Run: func(cmd *cobra.Command, args []string) {
		statusParam := ""
		if flowErrors {
			statusParam = "ERRORS"
		}

		params := url.Values{}
		params.Set("limit", fmt.Sprintf("%d", flowLimit))
		if flowProto != "" {
			params.Set("protocol", flowProto)
		}
		if statusParam != "" {
			params.Set("status", statusParam)
		}
		if flowQuery != "" {
			params.Set("q", flowQuery)
		}

		path := "/v1/ebpf/flows?" + params.Encode()
		resp, err := DoAPIRequest("GET", path, nil)
		if err != nil {
			_, _ = fmt.Fprintf(os.Stderr, "Failed to connect to Manager: %v\n", err)
			os.Exit(1)
		}
		defer func() { _ = resp.Body.Close() }()

		if resp.StatusCode != http.StatusOK {
			body, _ := io.ReadAll(resp.Body)
			_, _ = fmt.Fprintf(os.Stderr, "Failed to fetch flows: %s\n", string(body))
			os.Exit(1)
		}

		var flows []ebpf.Flow
		if err := json.NewDecoder(resp.Body).Decode(&flows); err != nil {
			_, _ = fmt.Fprintf(os.Stderr, "Failed to parse flows: %v\n", err)
			os.Exit(1)
		}

		if len(flows) == 0 {
			fmt.Println("No captured flows matching criteria.")
			return
		}

		fmt.Printf("%-10s %-20s -> %-20s %-8s %-22s %-9s %-10s %-8s\n",
			"TIME", "SOURCE", "DESTINATION", "PROTO", "TARGET / PATH", "LATENCY", "BANDWIDTH", "STATUS")
		fmt.Println(strings.Repeat("-", 115))

		for _, f := range flows {
			timeStr := f.Timestamp.Format("15:04:05")
			targetStr := f.Path
			if f.Method != "" {
				targetStr = f.Method + " " + f.Path
			}
			if len(targetStr) > 22 {
				targetStr = targetStr[:19] + "..."
			}

			statusBadge := "OK 🟢"
			if f.Status == ebpf.FlowStatusWarning {
				statusBadge = "WARN 🟡"
			} else if f.Status == ebpf.FlowStatusError {
				statusBadge = "ERR 🔴"
			}

			src := f.SourceName
			if src == "" {
				src = f.SourceIP
			}
			if len(src) > 20 {
				src = src[:17] + "..."
			}

			dst := f.DestName
			if dst == "" {
				dst = f.DestIP
			}
			if len(dst) > 20 {
				dst = dst[:17] + "..."
			}

			fmt.Printf("%-10s %-20s -> %-20s %-8s %-22s %-8.1fms %-10s %-8s\n",
				timeStr, src, dst, f.Protocol, targetStr, f.LatencyMs, formatBytesRate(f.ThroughputBps), statusBadge)
		}
	},
}

var ebpfTopologyCmd = &cobra.Command{
	Use:   "topology",
	Short: "Show synthesized eBPF service mesh topology and inter-service edges",
	Run: func(cmd *cobra.Command, args []string) {
		resp, err := DoAPIRequest("GET", "/v1/ebpf/topology", nil)
		if err != nil {
			_, _ = fmt.Fprintf(os.Stderr, "Failed to connect to Manager: %v\n", err)
			os.Exit(1)
		}
		defer func() { _ = resp.Body.Close() }()

		if resp.StatusCode != http.StatusOK {
			body, _ := io.ReadAll(resp.Body)
			_, _ = fmt.Fprintf(os.Stderr, "Failed to fetch topology: %s\n", string(body))
			os.Exit(1)
		}

		var topo ebpf.NetworkTopology
		if err := json.NewDecoder(resp.Body).Decode(&topo); err != nil {
			_, _ = fmt.Fprintf(os.Stderr, "Failed to parse topology: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("🕸️  eBPF SERVICE MESH TOPOLOGY (%d nodes, %d active edges)\n", len(topo.Nodes), len(topo.Edges))
		fmt.Println("==================================================================================")
		fmt.Println("\n📦 Service Nodes:")
		fmt.Printf("  %-24s %-12s %-15s %-10s %-12s %-10s\n", "NAME", "TYPE", "IP", "ACTIVE", "TRANSFER", "ERRORS")
		fmt.Println("  " + strings.Repeat("-", 85))
		for _, n := range topo.Nodes {
			transferStr := formatBytesRate(n.InboundBps + n.OutboundBps)
			errStr := fmt.Sprintf("%.1f%%", n.ErrorRate)
			fmt.Printf("  %-24s %-12s %-15s %-10d %-12s %-10s\n", n.Name, n.Type, n.IP, n.ActiveFlows, transferStr, errStr)
		}

		if len(topo.Edges) > 0 {
			fmt.Println("\n🔗 Active Communication Edges:")
			fmt.Printf("  %-22s -> %-22s %-8s %-10s %-12s %-8s\n", "SOURCE", "TARGET", "PROTO", "RTT", "THROUGHPUT", "ERRORS")
			fmt.Println("  " + strings.Repeat("-", 88))
			for _, e := range topo.Edges {
				rttStr := fmt.Sprintf("%.1fms", e.RttMs)
				rateStr := formatBytesRate(e.ThroughputBps)
				errStr := fmt.Sprintf("%.1f%%", e.ErrorRate)
				fmt.Printf("  %-22s -> %-22s %-8s %-10s %-12s %-8s\n", e.SourceID, e.TargetID, e.Protocol, rttStr, rateStr, errStr)
			}
		}
	},
}

var (
	simPattern  string
	simRate     int
	simDuration int
	simErrors   float64
)

var ebpfSimulateCmd = &cobra.Command{
	Use:   "simulate",
	Short: "Inject on-demand traffic flows for eBPF observability testing",
	Run: func(cmd *cobra.Command, args []string) {
		reqBody := ebpf.SimulationProfile{
			Pattern:   simPattern,
			Rate:      simRate,
			DurationS: simDuration,
			ErrorPct:  simErrors,
		}
		data, _ := json.Marshal(reqBody)

		resp, err := DoAPIRequest("POST", "/v1/ebpf/simulate", bytes.NewReader(data))
		if err != nil {
			_, _ = fmt.Fprintf(os.Stderr, "Failed to connect to Manager: %v\n", err)
			os.Exit(1)
		}
		defer func() { _ = resp.Body.Close() }()

		if resp.StatusCode != http.StatusOK {
			body, _ := io.ReadAll(resp.Body)
			_, _ = fmt.Fprintf(os.Stderr, "Failed to start simulation: %s\n", string(body))
			os.Exit(1)
		}

		fmt.Printf("⚡ eBPF traffic simulation started!\n")
		fmt.Printf("  • Pattern:  %s\n", simPattern)
		fmt.Printf("  • Rate:     %d events/sec\n", simRate)
		fmt.Printf("  • Duration: %d seconds\n", simDuration)
		fmt.Printf("  • Errors:   %.1f%%\n", simErrors)
		fmt.Println("View live flows via: gbnt ebpf flows")
	},
}

func formatBytesRate(bps float64) string {
	if bps >= 1024*1024 {
		return fmt.Sprintf("%.2f MB/s", bps/(1024*1024))
	} else if bps >= 1024 {
		return fmt.Sprintf("%.1f KB/s", bps/1024)
	}
	return fmt.Sprintf("%.0f B/s", bps)
}

func formatBytes(b uint64) string {
	if b >= 1024*1024*1024 {
		return fmt.Sprintf("%.2f GB", float64(b)/(1024*1024*1024))
	} else if b >= 1024*1024 {
		return fmt.Sprintf("%.1f MB", float64(b)/(1024*1024))
	} else if b >= 1024 {
		return fmt.Sprintf("%.1f KB", float64(b)/1024)
	}
	return fmt.Sprintf("%d B", b)
}

var (
	quarantineNode   string
	quarantineReason string
	purpleNode       string
	purpleContainer  string
)

var ebpfAlertsCmd = &cobra.Command{
	Use:   "alerts",
	Short: "List live eBPF Runtime IDS security alerts",
	Run: func(cmd *cobra.Command, args []string) {
		resp, err := DoAPIRequest("GET", "/v1/ebpf/alerts?limit=50", nil)
		if err != nil {
			_, _ = fmt.Fprintf(os.Stderr, "Failed to connect to Manager: %v\n", err)
			os.Exit(1)
		}
		defer func() { _ = resp.Body.Close() }()
		var alerts []ebpf.SecurityAlert
		_ = json.NewDecoder(resp.Body).Decode(&alerts)
		if len(alerts) == 0 {
			fmt.Println("No runtime IDS alerts recorded.")
			return
		}
		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		_, _ = fmt.Fprintln(w, "ID\tSEVERITY\tMITRE\tNODE\tCONTAINER\tSTATUS\tTITLE")
		for _, a := range alerts {
			_, _ = fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
				a.ID, a.Severity, a.MitreTechnique, a.NodeHost, a.ContainerName, a.Status, a.Title)
		}
		_ = w.Flush()
	},
}

var ebpfSurfaceCmd = &cobra.Command{
	Use:   "surface",
	Short: "Audit live listening ports & shadow services across all Centurion nodes",
	Run: func(cmd *cobra.Command, args []string) {
		resp, err := DoAPIRequest("GET", "/v1/ebpf/attack-surface", nil)
		if err != nil {
			_, _ = fmt.Fprintf(os.Stderr, "Failed to connect to Manager: %v\n", err)
			os.Exit(1)
		}
		defer func() { _ = resp.Body.Close() }()
		var entries []ebpf.AttackSurfaceEntry
		_ = json.NewDecoder(resp.Body).Decode(&entries)
		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		_, _ = fmt.Fprintln(w, "NODE\tPROTO\tBIND:PORT\tPROCESS\tSHADOW\tRISK\tREASON")
		for _, e := range entries {
			_, _ = fmt.Fprintf(w, "%s\t%s\t%s:%d\t%s\t%v\t%s\t%s\n",
				e.NodeHost, e.Protocol, e.BindAddress, e.Port, e.ProcessName, e.IsShadow, e.RiskLevel, e.RiskReason)
		}
		_ = w.Flush()
	},
}

var ebpfQuarantineCmd = &cobra.Command{
	Use:   "quarantine <container>",
	Short: "Isolate a compromised container's network while preserving RAM/processes for DFIR",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		body, _ := json.Marshal(ebpf.QuarantineRequest{
			ContainerName: args[0],
			NodeHost:      quarantineNode,
			Reason:        quarantineReason,
		})
		resp, err := DoAPIRequest("POST", "/v1/ebpf/quarantine", bytes.NewReader(body))
		if err != nil {
			_, _ = fmt.Fprintf(os.Stderr, "Failed to connect to Manager: %v\n", err)
			os.Exit(1)
		}
		defer func() { _ = resp.Body.Close() }()
		var rec ebpf.QuarantineRecord
		_ = json.NewDecoder(resp.Body).Decode(&rec)
		fmt.Printf("Quarantined %s (id=%s, method=%s, node=%s)\n  %s\n", rec.ContainerName, rec.ID, rec.Method, rec.NodeHost, rec.Details)
	},
}

var ebpfPurpleTeamCmd = &cobra.Command{
	Use:   "purple-team [scenario-id]",
	Short: "List or execute controlled MITRE ATT&CK Purple Team validation playbooks",
	Run: func(cmd *cobra.Command, args []string) {
		if len(args) == 0 {
			resp, err := DoAPIRequest("GET", "/v1/ebpf/purple-team/scenarios", nil)
			if err != nil {
				_, _ = fmt.Fprintf(os.Stderr, "Failed to connect to Manager: %v\n", err)
				os.Exit(1)
			}
			defer func() { _ = resp.Body.Close() }()
			var payload struct {
				Scenarios []ebpf.PurpleTeamScenario `json:"scenarios"`
			}
			_ = json.NewDecoder(resp.Body).Decode(&payload)
			w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
			_, _ = fmt.Fprintln(w, "SCENARIO ID\tMITRE\tSEVERITY\tNAME")
			for _, sc := range payload.Scenarios {
				_, _ = fmt.Fprintf(w, "%s\t%s\t%s\t%s\n", sc.ID, sc.MitreTechnique, sc.Severity, sc.Name)
			}
			_ = w.Flush()
			return
		}
		body, _ := json.Marshal(ebpf.PurpleTeamRunRequest{
			ScenarioID:      args[0],
			TargetNode:      purpleNode,
			TargetContainer: purpleContainer,
		})
		resp, err := DoAPIRequest("POST", "/v1/ebpf/purple-team/run", bytes.NewReader(body))
		if err != nil {
			_, _ = fmt.Fprintf(os.Stderr, "Failed to connect to Manager: %v\n", err)
			os.Exit(1)
		}
		defer func() { _ = resp.Body.Close() }()
		var run ebpf.PurpleTeamRun
		_ = json.NewDecoder(resp.Body).Decode(&run)
		fmt.Printf("Purple Team Run %s (%s / %s): detected=%v mttd=%.2fms score=%d/100\n",
			run.ID, run.ScenarioName, run.MitreTechnique, run.Detected, run.MTTDMs, run.Score)
	},
}

func init() {
	ebpfFlowsCmd.Flags().IntVarP(&flowLimit, "limit", "n", 25, "Maximum number of flows to show")
	ebpfFlowsCmd.Flags().StringVarP(&flowProto, "protocol", "p", "", "Filter by protocol (HTTP, gRPC, DNS, TCP, REDIS, POSTGRES)")
	ebpfFlowsCmd.Flags().BoolVarP(&flowErrors, "errors", "e", false, "Show only warning or error flows")
	ebpfFlowsCmd.Flags().StringVarP(&flowQuery, "search", "s", "", "Search query matching endpoints or path")

	ebpfSimulateCmd.Flags().StringVar(&simPattern, "pattern", "burst", "Traffic pattern (normal, burst, errors, mixed)")
	ebpfSimulateCmd.Flags().IntVar(&simRate, "rate", 15, "Target events per second")
	ebpfSimulateCmd.Flags().IntVar(&simDuration, "duration", 10, "Duration in seconds")
	ebpfSimulateCmd.Flags().Float64Var(&simErrors, "errors", 0, "Error injection percentage (0-100)")

	ebpfQuarantineCmd.Flags().StringVar(&quarantineNode, "node", "manager", "Target Centurion node")
	ebpfQuarantineCmd.Flags().StringVar(&quarantineReason, "reason", "CLI forensic quarantine", "Reason for isolation")
	ebpfPurpleTeamCmd.Flags().StringVar(&purpleNode, "node", "manager", "Target Centurion node")
	ebpfPurpleTeamCmd.Flags().StringVar(&purpleContainer, "container", "gbnt-caddy", "Target container")

	ebpfCmd.AddCommand(ebpfStatusCmd)
	ebpfCmd.AddCommand(ebpfFlowsCmd)
	ebpfCmd.AddCommand(ebpfTopologyCmd)
	ebpfCmd.AddCommand(ebpfSimulateCmd)
	ebpfCmd.AddCommand(ebpfAlertsCmd)
	ebpfCmd.AddCommand(ebpfSurfaceCmd)
	ebpfCmd.AddCommand(ebpfQuarantineCmd)
	ebpfCmd.AddCommand(ebpfPurpleTeamCmd)
	rootCmd.AddCommand(ebpfCmd)
}

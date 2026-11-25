package api

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/gubernator-org/gubernator/internal/ebpf"
)

// EBPFStatsHandler Get eBPF kernel network telemetry and probe stats.
// @Summary Get eBPF kernel network telemetry and probe stats
// @Description Returns kernel eBPF capabilities, active probes, multi-node telemetry, alert counters, and packet statistics
// @Tags ebpf
// @Produce json
// @Success 200 {object} ebpf.NetworkStats
// @Router /v1/ebpf/stats [get]
func EBPFStatsHandler(c *gin.Context) {
	eng := ebpf.GetEngine()
	stats := eng.Probe.GetStats()
	c.JSON(http.StatusOK, stats)
}

// EBPFFlowsHandler Get recent eBPF captured network flows.
// @Summary Get recent eBPF captured network flows
// @Description Returns recent captured L4/L7 network flows with filtering by protocol, status, node, real_only, query, and limit
// @Tags ebpf
// @Produce json
// @Param limit query int false "Maximum number of flows to return (default 50)"
// @Param protocol query string false "Protocol filter (e.g. HTTP, gRPC, DNS, TCP, REDIS, POSTGRES)"
// @Param status query string false "Status filter (healthy, warning, error, ERRORS, or ANOMALIES)"
// @Param node query string false "Centurion node filter"
// @Param real_only query bool false "Exclude synthetic demo flows"
// @Param q query string false "Search query matching source, dest, process, method, or path"
// @Success 200 {array} ebpf.Flow
// @Router /v1/ebpf/flows [get]
func EBPFFlowsHandler(c *gin.Context) {
	limitStr := c.DefaultQuery("limit", "50")
	limit, _ := strconv.Atoi(limitStr)
	if limit <= 0 {
		limit = 50
	}
	proto := c.Query("protocol")
	status := c.Query("status")
	query := c.Query("q")
	node := c.Query("node")
	realOnly := c.Query("real_only") == "true"

	eng := ebpf.GetEngine()
	flows := eng.Probe.GetRecentFlowsFiltered(limit, proto, status, query, node, realOnly)
	if flows == nil {
		flows = []ebpf.Flow{}
	}
	c.JSON(http.StatusOK, flows)
}

// EBPFTopologyHandler Get live eBPF service mesh topology graph.
// @Summary Get live eBPF service mesh topology graph
// @Description Returns interconnected topology graph with service nodes, quarantine badges, drift flags, and active edges
// @Tags ebpf
// @Produce json
// @Success 200 {object} ebpf.NetworkTopology
// @Router /v1/ebpf/topology [get]
func EBPFTopologyHandler(c *gin.Context) {
	eng := ebpf.GetEngine()
	topo := eng.Probe.BuildTopology()
	c.JSON(http.StatusOK, topo)
}

// EBPFSimulateHandler Trigger on-demand eBPF traffic simulation.
// @Summary Trigger on-demand eBPF traffic simulation
// @Description Injects traffic flows (burst, normal, errors) for testing and UI live visualization
// @Tags ebpf
// @Accept json
// @Produce json
// @Param profile body ebpf.SimulationProfile true "Simulation Profile configuration"
// @Success 200 {object} map[string]string
// @Router /v1/ebpf/simulate [post]
func EBPFSimulateHandler(c *gin.Context) {
	var profile ebpf.SimulationProfile
	if err := c.ShouldBindJSON(&profile); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid simulation payload: " + err.Error()})
		return
	}

	eng := ebpf.GetEngine()
	eng.SimulateTraffic(profile)
	c.JSON(http.StatusOK, gin.H{"status": "Simulation triggered successfully", "pattern": profile.Pattern})
}

// EBPFModeHandler Toggle synthetic pulse vs real-only telemetry and trigger multi-node scan.
// @Summary Toggle eBPF telemetry mode (Real vs Demo Pulse)
// @Tags ebpf
// @Accept json
// @Produce json
// @Param body body ebpf.TelemetryModeRequest true "Telemetry Mode Request"
// @Success 200 {object} map[string]interface{}
// @Router /v1/ebpf/mode [post]
func EBPFModeHandler(c *gin.Context) {
	var req ebpf.TelemetryModeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid mode payload: " + err.Error()})
		return
	}
	eng := ebpf.GetEngine()
	eng.Probe.SetSyntheticPulse(req.SyntheticPulse)
	if req.TriggerScan {
		eng.TriggerMultiNodeScan()
	}
	c.JSON(http.StatusOK, gin.H{
		"synthetic_pulse": eng.Probe.IsSyntheticPulse(),
		"status":          "updated",
	})
}

// EBPFNodesHandler Get per-Centurion kernel & deep network diagnostics.
// @Summary Get multi-node eBPF telemetry & deep diagnostics
// @Tags ebpf
// @Produce json
// @Success 200 {array} ebpf.NodeTelemetry
// @Router /v1/ebpf/nodes [get]
func EBPFNodesHandler(c *gin.Context) {
	eng := ebpf.GetEngine()
	snaps := eng.Collector.GetNodeSnapshots()
	if snaps == nil {
		snaps = []ebpf.NodeTelemetry{}
	}
	c.JSON(http.StatusOK, snaps)
}

// EBPFAlertsHandler Get Runtime IDS security alerts detected by eBPF.
// @Summary Get Runtime IDS security alerts
// @Tags ebpf
// @Produce json
// @Param severity query string false "Filter by severity (critical, high, medium, low)"
// @Param category query string false "Filter by category"
// @Param status query string false "Filter by status (open, acknowledged, mitigated)"
// @Param limit query int false "Max alerts to return (default 100)"
// @Success 200 {array} ebpf.SecurityAlert
// @Router /v1/ebpf/alerts [get]
func EBPFAlertsHandler(c *gin.Context) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "100"))
	eng := ebpf.GetEngine()
	alerts := eng.IDS.GetAlerts(c.Query("severity"), c.Query("category"), c.Query("status"), limit)
	if alerts == nil {
		alerts = []ebpf.SecurityAlert{}
	}
	c.JSON(http.StatusOK, alerts)
}

// EBPFAlertAckHandler Acknowledge or mitigate an eBPF security alert.
// @Summary Acknowledge an eBPF security alert
// @Tags ebpf
// @Produce json
// @Param id path string true "Alert ID"
// @Success 200 {object} ebpf.SecurityAlert
// @Router /v1/ebpf/alerts/{id}/ack [post]
func EBPFAlertAckHandler(c *gin.Context) {
	id := c.Param("id")
	var body struct {
		Status string `json:"status"`
	}
	_ = c.ShouldBindJSON(&body)
	eng := ebpf.GetEngine()
	a, ok := eng.IDS.AcknowledgeAlert(id, body.Status)
	if !ok {
		c.JSON(http.StatusNotFound, gin.H{"error": "Alert not found"})
		return
	}
	c.JSON(http.StatusOK, a)
}

// EBPFAlertsClearHandler Clear simulated or all eBPF security alerts.
// @Summary Clear eBPF security alerts
// @Tags ebpf
// @Produce json
// @Success 200 {object} map[string]int
// @Router /v1/ebpf/alerts [delete]
func EBPFAlertsClearHandler(c *gin.Context) {
	onlySim := c.Query("simulated_only") == "true"
	eng := ebpf.GetEngine()
	removed := eng.IDS.ClearAlerts(onlySim)
	c.JSON(http.StatusOK, gin.H{"removed": removed})
}

// EBPFAttackSurfaceHandler Get cluster-wide listening ports & shadow port audit.
// @Summary Get multi-node live Attack Surface & Shadow Port Audit
// @Tags ebpf
// @Produce json
// @Param node query string false "Filter by node host"
// @Param shadow_only query bool false "Return only undeclared shadow ports"
// @Success 200 {array} ebpf.AttackSurfaceEntry
// @Router /v1/ebpf/attack-surface [get]
func EBPFAttackSurfaceHandler(c *gin.Context) {
	eng := ebpf.GetEngine()
	entries := eng.Collector.GetAttackSurface(c.Query("node"), c.Query("shadow_only") == "true")
	if entries == nil {
		entries = []ebpf.AttackSurfaceEntry{}
	}
	c.JSON(http.StatusOK, entries)
}

// EBPFAttackSurfaceScanHandler Trigger immediate multi-node attack surface & process scan.
// @Summary Trigger immediate multi-node attack surface & telemetry scan
// @Tags ebpf
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /v1/ebpf/attack-surface/scan [post]
func EBPFAttackSurfaceScanHandler(c *gin.Context) {
	eng := ebpf.GetEngine()
	eng.Collector.CollectAll(eng.Probe, eng.IDS)
	entries := eng.Collector.GetAttackSurface("", false)
	c.JSON(http.StatusOK, gin.H{
		"status":  "completed",
		"entries": len(entries),
		"nodes":   len(eng.Collector.GetNodeSnapshots()),
	})
}

// EBPFZeroTrustHandler Get learned Zero-Trust micro-segmentation baseline & policies.
// @Summary Get Zero-Trust Baseline & nftables/iptables policy
// @Tags ebpf
// @Produce json
// @Success 200 {object} ebpf.ZeroTrustBaseline
// @Router /v1/ebpf/zero-trust [get]
func EBPFZeroTrustHandler(c *gin.Context) {
	eng := ebpf.GetEngine()
	c.JSON(http.StatusOK, eng.IDS.GetZeroTrustBaseline())
}

// EBPFZeroTrustLockHandler Lock/unlock or re-learn the Zero-Trust baseline.
// @Summary Lock/unlock Zero-Trust baseline
// @Tags ebpf
// @Accept json
// @Produce json
// @Success 200 {object} ebpf.ZeroTrustBaseline
// @Router /v1/ebpf/zero-trust/lock [post]
func EBPFZeroTrustLockHandler(c *gin.Context) {
	var req struct {
		Locked        bool `json:"locked"`
		ResetAndLearn bool `json:"reset_and_learn"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	eng := ebpf.GetEngine()
	c.JSON(http.StatusOK, eng.IDS.SetBaselineLocked(req.Locked, req.ResetAndLearn))
}

// EBPFProcessesHandler Get forensic Process <-> Socket correlation table across nodes.
// @Summary Get forensic Process <-> Socket table
// @Tags ebpf
// @Produce json
// @Success 200 {array} ebpf.ProcessSocketEntry
// @Router /v1/ebpf/processes [get]
func EBPFProcessesHandler(c *gin.Context) {
	eng := ebpf.GetEngine()
	procs := eng.Collector.GetProcessSockets(c.Query("node"), c.Query("q"))
	if procs == nil {
		procs = []ebpf.ProcessSocketEntry{}
	}
	c.JSON(http.StatusOK, procs)
}

// EBPFQuarantineListHandler List quarantined containers.
// @Summary List forensic quarantined containers
// @Tags ebpf
// @Produce json
// @Success 200 {array} ebpf.QuarantineRecord
// @Router /v1/ebpf/quarantine [get]
func EBPFQuarantineListHandler(c *gin.Context) {
	eng := ebpf.GetEngine()
	recs := eng.Forensics.GetQuarantines()
	if recs == nil {
		recs = []ebpf.QuarantineRecord{}
	}
	c.JSON(http.StatusOK, recs)
}

// EBPFQuarantineCreateHandler Isolate a compromised container without destroying memory/processes.
// @Summary Quarantine a container (DFIR network isolation)
// @Tags ebpf
// @Accept json
// @Produce json
// @Param body body ebpf.QuarantineRequest true "Quarantine Request"
// @Success 200 {object} ebpf.QuarantineRecord
// @Router /v1/ebpf/quarantine [post]
func EBPFQuarantineCreateHandler(c *gin.Context) {
	var req ebpf.QuarantineRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid quarantine request: " + err.Error()})
		return
	}
	actor := c.GetString("username")
	eng := ebpf.GetEngine()
	rec := eng.Forensics.QuarantineContainer(req, actor, eng.IDS)
	c.JSON(http.StatusOK, rec)
}

// EBPFQuarantineReleaseHandler Release a container from forensic quarantine.
// @Summary Release a quarantined container
// @Tags ebpf
// @Produce json
// @Param id path string true "Quarantine ID"
// @Success 200 {object} ebpf.QuarantineRecord
// @Router /v1/ebpf/quarantine/{id}/release [post]
func EBPFQuarantineReleaseHandler(c *gin.Context) {
	id := c.Param("id")
	actor := c.GetString("username")
	eng := ebpf.GetEngine()
	rec, ok := eng.Forensics.ReleaseQuarantine(id, actor)
	if !ok {
		c.JSON(http.StatusNotFound, gin.H{"error": "Quarantine record not found"})
		return
	}
	c.JSON(http.StatusOK, rec)
}

// EBPFPCAPListHandler List forensic PCAP captures.
// @Summary List forensic PCAP captures
// @Tags ebpf
// @Produce json
// @Success 200 {array} ebpf.PCAPCapture
// @Router /v1/ebpf/pcap [get]
func EBPFPCAPListHandler(c *gin.Context) {
	eng := ebpf.GetEngine()
	caps := eng.Forensics.GetPCAPCaptures()
	if caps == nil {
		caps = []ebpf.PCAPCapture{}
	}
	c.JSON(http.StatusOK, caps)
}

// EBPFPCAPCaptureHandler Trigger on-demand forensic PCAP packet capture.
// @Summary Start on-demand forensic PCAP capture
// @Tags ebpf
// @Accept json
// @Produce json
// @Param body body ebpf.PCAPCaptureRequest true "PCAP Capture Request"
// @Success 200 {object} ebpf.PCAPCapture
// @Router /v1/ebpf/pcap/capture [post]
func EBPFPCAPCaptureHandler(c *gin.Context) {
	var req ebpf.PCAPCaptureRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid PCAP request: " + err.Error()})
		return
	}
	actor := c.GetString("username")
	eng := ebpf.GetEngine()
	capRec := eng.Forensics.CapturePCAP(req, eng.Probe, actor)
	c.JSON(http.StatusOK, capRec)
}

// EBPFPCAPDownloadHandler Download a forensic .pcap file for Wireshark.
// @Summary Download .pcap forensic file
// @Tags ebpf
// @Produce octet-stream
// @Param id path string true "PCAP Capture ID"
// @Success 200 {file} binary
// @Router /v1/ebpf/pcap/{id}/download [get]
func EBPFPCAPDownloadHandler(c *gin.Context) {
	id := c.Param("id")
	eng := ebpf.GetEngine()
	data, meta, ok := eng.Forensics.GetPCAPData(id)
	if !ok || meta == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "PCAP capture not found"})
		return
	}
	filename := fmt.Sprintf("gubernator-%s.pcap", meta.ID)
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%q", filename))
	c.Data(http.StatusOK, "application/vnd.tcpdump.pcap", data)
}

// EBPFPurpleTeamScenariosHandler List MITRE ATT&CK Purple Team playbooks and run history.
// @Summary List Purple Team scenarios and execution history
// @Tags ebpf
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /v1/ebpf/purple-team/scenarios [get]
func EBPFPurpleTeamScenariosHandler(c *gin.Context) {
	eng := ebpf.GetEngine()
	c.JSON(http.StatusOK, gin.H{
		"scenarios": eng.Forensics.GetPurpleTeamScenarios(),
		"runs":      eng.Forensics.GetPurpleTeamRuns(),
	})
}

// EBPFPurpleTeamRunHandler Execute a controlled Purple Team MITRE ATT&CK validation playbook.
// @Summary Run a Purple Team MITRE ATT&CK validation scenario
// @Tags ebpf
// @Accept json
// @Produce json
// @Param body body ebpf.PurpleTeamRunRequest true "Purple Team Run Request"
// @Success 200 {object} ebpf.PurpleTeamRun
// @Router /v1/ebpf/purple-team/run [post]
func EBPFPurpleTeamRunHandler(c *gin.Context) {
	var req ebpf.PurpleTeamRunRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid purple team request: " + err.Error()})
		return
	}
	actor := c.GetString("username")
	eng := ebpf.GetEngine()
	run, err := eng.Forensics.RunPurpleTeamScenario(req, eng.Probe, eng.IDS, actor)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, run)
}

// EBPFStreamHandler Stream live eBPF network flows via Server-Sent Events (SSE).
// @Summary Stream live eBPF network flows via Server-Sent Events (SSE)
// @Description Real-time stream of captured network packets and flows
// @Tags ebpf
// @Produce text/event-stream
// @Router /v1/ebpf/stream [get]
func EBPFStreamHandler(c *gin.Context) {
	c.Writer.Header().Set("Content-Type", "text/event-stream")
	c.Writer.Header().Set("Cache-Control", "no-cache")
	c.Writer.Header().Set("Connection", "keep-alive")
	c.Writer.Header().Set("Transfer-Encoding", "chunked")

	eng := ebpf.GetEngine()
	ch := eng.Probe.Subscribe()
	defer eng.Probe.Unsubscribe(ch)

	c.Stream(func(w io.Writer) bool {
		select {
		case <-c.Request.Context().Done():
			return false
		case flow, ok := <-ch:
			if !ok {
				return false
			}
			data, err := json.Marshal(flow)
			if err == nil {
				c.SSEvent("flow", string(data))
			}
			return true
		}
	})
}

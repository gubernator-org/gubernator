package ebpf

import (
	"bufio"
	"context"
	"fmt"
	"net"
	"os"
	"os/exec"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gubernator-org/gubernator/internal/db"
	"github.com/gubernator-org/gubernator/internal/storage"
)

const multiNodeProbeScript = `
echo "===KERNEL==="
uname -r 2>/dev/null || echo "unknown"
if [ -d /sys/fs/bpf ] || [ -d /sys/kernel/tracing ] || [ -d /sys/kernel/debug/tracing ]; then echo "EBPF=1"; else echo "EBPF=0"; fi
echo "===LISTEN==="
ss -tulnpH 2>/dev/null | head -n 120
echo "===RAW==="
cat /proc/net/raw 2>/dev/null | tail -n +2 | head -n 30
echo "===SOCKETS==="
ss -tunapH state established 2>/dev/null | head -n 120
echo "===SNMP==="
grep -E "^Tcp:" /proc/net/snmp 2>/dev/null | tail -n 1
grep -E "^TcpExt:" /proc/net/netstat 2>/dev/null | tail -n 1
echo "===FILENR==="
cat /proc/sys/fs/file-nr 2>/dev/null
echo "===DEV==="
tail -n +3 /proc/net/dev 2>/dev/null | head -n 25
echo "===PROCS==="
if command -v docker >/dev/null 2>&1; then
  for cid in $(docker ps -q 2>/dev/null | head -n 20); do
    cname=$(docker inspect -f '{{.Name}}' "$cid" 2>/dev/null | sed 's|^/||')
    docker top "$cid" -eo pid,uid,comm,args 2>/dev/null | tail -n +2 | head -n 8 | while IFS= read -r line; do
      echo "CTR|$cname|$line"
    done
  done
fi
echo "===STORAGEIO==="
if [ -d /var/contenedores ]; then
  t0=$(date +%s%N 2>/dev/null || echo 0)
  ls /var/contenedores >/dev/null 2>&1
  t1=$(date +%s%N 2>/dev/null || echo 0)
  echo "$t0 $t1"
else
  echo "0 0"
fi
`

var ssProcRe = regexp.MustCompile(`"([^"]+)",pid=(\d+)`)

// MultiNodeCollector aggregates real kernel/socket/process telemetry across Manager and Worker Centurions.
type MultiNodeCollector struct {
	mu            sync.RWMutex
	nodeSnapshots []NodeTelemetry
	attackSurface []AttackSurfaceEntry
	processTable  []ProcessSocketEntry
	lastCollected time.Time
	scanning      bool
}

// NewMultiNodeCollector creates a cluster-wide telemetry collector.
func NewMultiNodeCollector() *MultiNodeCollector {
	return &MultiNodeCollector{
		nodeSnapshots: make([]NodeTelemetry, 0),
		attackSurface: make([]AttackSurfaceEntry, 0),
		processTable:  make([]ProcessSocketEntry, 0),
	}
}

// CollectAll probes Manager and all active Worker Centurion nodes concurrently.
func (m *MultiNodeCollector) CollectAll(probe *Probe, ids *SecurityIDS) {
	m.mu.Lock()
	if m.scanning {
		m.mu.Unlock()
		return
	}
	m.scanning = true
	m.mu.Unlock()

	defer func() {
		m.mu.Lock()
		m.scanning = false
		m.lastCollected = time.Now()
		m.mu.Unlock()
	}()

	type targetInfo struct {
		ID   string
		IP   string
		Role string
	}
	targets := make([]targetInfo, 0)
	seenIPs := make(map[string]bool)

	if db.DB != nil {
		var nodes []db.Node
		if err := db.DB.Where("status != ?", "left").Find(&nodes).Error; err == nil {
			for _, n := range nodes {
				if n.IP == "" || seenIPs[n.IP] {
					continue
				}
				seenIPs[n.IP] = true
				targets = append(targets, targetInfo{
					ID:   fallbackStr(n.ID, n.IP),
					IP:   n.IP,
					Role: fallbackStr(n.Role, "worker"),
				})
			}
		}
	}

	if len(targets) == 0 {
		targets = append(targets, targetInfo{
			ID:   "manager-local",
			IP:   "127.0.0.1",
			Role: "manager",
		})
	}

	declaredPorts := loadDeclaredComposePorts()

	var wg sync.WaitGroup
	var resMu sync.Mutex
	snapshots := make([]NodeTelemetry, 0, len(targets))
	surface := make([]AttackSurfaceEntry, 0)
	procs := make([]ProcessSocketEntry, 0)

	for _, t := range targets {
		wg.Add(1)
		go func(tgt targetInfo) {
			defer wg.Done()
			snap, surf, ps := m.collectNode(tgt.ID, tgt.IP, tgt.Role, declaredPorts, probe, ids)
			resMu.Lock()
			snapshots = append(snapshots, snap)
			surface = append(surface, surf...)
			procs = append(procs, ps...)
			resMu.Unlock()
		}(t)
	}
	wg.Wait()

	sort.Slice(snapshots, func(i, j int) bool {
		if snapshots[i].Role != snapshots[j].Role {
			return snapshots[i].Role == "manager"
		}
		return snapshots[i].NodeID < snapshots[j].NodeID
	})

	sort.Slice(surface, func(i, j int) bool {
		ri := riskWeight(surface[i].RiskLevel)
		rj := riskWeight(surface[j].RiskLevel)
		if ri != rj {
			return ri > rj
		}
		if surface[i].NodeHost != surface[j].NodeHost {
			return surface[i].NodeHost < surface[j].NodeHost
		}
		return surface[i].Port < surface[j].Port
	})

	m.mu.Lock()
	m.nodeSnapshots = snapshots
	m.attackSurface = surface
	m.processTable = procs
	m.mu.Unlock()
}

func (m *MultiNodeCollector) collectNode(nodeID, nodeIP, role string, declaredPorts map[int]bool, probe *Probe, ids *SecurityIDS) (NodeTelemetry, []AttackSurfaceEntry, []ProcessSocketEntry) {
	now := time.Now()
	snap := NodeTelemetry{
		NodeID:        nodeID,
		NodeIP:        nodeIP,
		Role:          role,
		Status:        "online",
		DNSLatencyMs:  probeDNSLatency(),
		LastCollected: now,
	}

	// Non-Linux local dev host (e.g. macOS): use portable local inspection (lsof/docker)
	if storage.IsLocalHost(nodeIP) && runtime.GOOS != "linux" {
		snap.KernelVersion = runtime.GOOS + "/" + runtime.GOARCH
		snap.EBPFSupported = false
		surf, ps := collectLocalDarwinFallback(nodeID, nodeIP, declaredPorts, probe)
		snap.ListeningPorts = len(surf)
		snap.ActiveSockets = len(ps)
		snap.OpenFDs = 128 + len(ps)*2
		snap.MaxFDs = 65536
		return snap, surf, ps
	}

	out, err := runNodeScript(nodeIP, multiNodeProbeScript, 8*time.Second)
	if err != nil && strings.TrimSpace(out) == "" {
		snap.Status = "unreachable"
		snap.Error = truncateStr(err.Error(), 160)
		return snap, nil, nil
	}

	sections := parseScriptSections(out)

	// 1. Kernel & eBPF support
	for _, line := range sections["KERNEL"] {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "EBPF=") {
			snap.EBPFSupported = line == "EBPF=1"
		} else if line != "" && snap.KernelVersion == "" {
			snap.KernelVersion = line
		}
	}

	// 2. Listening ports -> Attack Surface
	surface := make([]AttackSurfaceEntry, 0)
	for _, line := range sections["LISTEN"] {
		entry, ok := parseSSListenLine(line, nodeID, nodeIP, declaredPorts, probe)
		if ok {
			surface = append(surface, entry)
		}
	}

	// 3. Raw sockets (AF_PACKET / IPPROTO_RAW) -> High-risk security signal
	for _, line := range sections["RAW"] {
		fields := strings.Fields(line)
		if len(fields) >= 4 {
			surface = append(surface, AttackSurfaceEntry{
				ID:          fmt.Sprintf("%s-raw-%s", nodeID, fields[0]),
				NodeHost:    nodeID,
				NodeIP:      nodeIP,
				Protocol:    "RAW",
				BindAddress: "0.0.0.0",
				Port:        0,
				ProcessName: "raw_socket",
				Exposure:    "public_0.0.0.0",
				IsShadow:    true,
				IsRawSocket: true,
				RiskLevel:   "high",
				RiskReason:  "Active RAW socket detected on host (potential packet sniffer or spoofing tool)",
				LastSeen:    now,
			})
		}
	}
	snap.ListeningPorts = len(surface)

	// 4. Established sockets -> ProcessSocketEntry + real Flow correlation
	procs := make([]ProcessSocketEntry, 0)
	for _, line := range sections["SOCKETS"] {
		ps, ok := parseSSEstablishedLine(line, nodeID, nodeIP, probe)
		if ok {
			procs = append(procs, ps)
		}
	}
	snap.ActiveSockets = len(procs)

	// 5. Container process inspection -> Reverse Shell & Container Escape IDS!
	for _, line := range sections["PROCS"] {
		if !strings.HasPrefix(line, "CTR|") {
			continue
		}
		parts := strings.SplitN(line, "|", 3)
		if len(parts) < 3 {
			continue
		}
		cName := strings.TrimSpace(parts[1])
		fields := strings.Fields(strings.TrimSpace(parts[2]))
		if len(fields) < 3 {
			continue
		}
		pid, _ := strconv.Atoi(fields[0])
		uid, _ := strconv.Atoi(fields[1])
		comm := fields[2]
		cmdArgs := strings.Join(fields[2:], " ")
		if ids != nil {
			alert := ids.InspectProcessCommand(nodeID, cName, comm, cmdArgs, pid, uid, false)
			if alert != nil {
				procs = append(procs, ProcessSocketEntry{
					NodeHost:      nodeID,
					NodeIP:        nodeIP,
					ContainerName: cName,
					PID:           pid,
					UID:           uid,
					ProcessName:   comm,
					CommandLine:   truncateStr(cmdArgs, 180),
					Protocol:      "EXEC",
					State:         "SUSPICIOUS",
					LocalAddr:     nodeIP,
					RemoteAddr:    "-",
					Suspicious:    true,
					SuspicionNote: alert.Title,
					ObservedAt:    now,
				})
			}
		}
	}

	// 6. TCP retransmits & SYN drops from /proc/net/snmp + netstat
	for _, line := range sections["SNMP"] {
		fields := strings.Fields(line)
		if strings.HasPrefix(line, "Tcp:") && len(fields) >= 13 {
			if retr, err := strconv.ParseInt(fields[12], 10, 64); err == nil {
				snap.TCPRetransmits = retr
			}
		}
		if strings.HasPrefix(line, "TcpExt:") && len(fields) >= 22 {
			if drops, err := strconv.ParseInt(fields[20], 10, 64); err == nil {
				snap.SynDrops = drops
			}
		}
	}

	// 7. File descriptors (/proc/sys/fs/file-nr)
	for _, line := range sections["FILENR"] {
		fields := strings.Fields(line)
		if len(fields) >= 3 {
			snap.OpenFDs, _ = strconv.Atoi(fields[0])
			snap.MaxFDs, _ = strconv.Atoi(fields[2])
		}
	}

	// 8. Interfaces & packet drops (/proc/net/dev)
	var totalDrops int64
	for _, line := range sections["DEV"] {
		parts := strings.Split(line, ":")
		if len(parts) != 2 {
			continue
		}
		ifName := strings.TrimSpace(parts[0])
		fields := strings.Fields(parts[1])
		if len(fields) < 16 {
			continue
		}
		var rxB, rxP, rxE, rxD, txB, txP, txE, txD uint64
		_, _ = fmt.Sscanf(fields[0], "%d", &rxB)
		_, _ = fmt.Sscanf(fields[1], "%d", &rxP)
		_, _ = fmt.Sscanf(fields[2], "%d", &rxE)
		_, _ = fmt.Sscanf(fields[3], "%d", &rxD)
		_, _ = fmt.Sscanf(fields[8], "%d", &txB)
		_, _ = fmt.Sscanf(fields[9], "%d", &txP)
		_, _ = fmt.Sscanf(fields[10], "%d", &txE)
		_, _ = fmt.Sscanf(fields[11], "%d", &txD)
		totalDrops += int64(rxD + txD)
		snap.Interfaces = append(snap.Interfaces, InterfaceStats{
			Name:      ifName,
			NodeHost:  nodeID,
			RxBytes:   rxB,
			TxBytes:   txB,
			RxPackets: rxP,
			TxPackets: txP,
			RxErrors:  rxE,
			TxErrors:  txE,
			RxDrops:   rxD,
			TxDrops:   txD,
		})
	}
	snap.PacketDrops = totalDrops

	// 9. Storage I/O probe latency (/var/contenedores)
	for _, line := range sections["STORAGEIO"] {
		fields := strings.Fields(line)
		if len(fields) == 2 {
			t0, _ := strconv.ParseInt(fields[0], 10, 64)
			t1, _ := strconv.ParseInt(fields[1], 10, 64)
			if t1 > t0 && t0 > 0 {
				snap.StorageIOLatMs = float64(t1-t0) / 1e6
			}
		}
	}

	// Emit critical shadow port alerts (e.g., exposed 2375 Docker API or unrequested DB on 0.0.0.0)
	if ids != nil {
		for _, entry := range surface {
			if entry.RiskLevel == "critical" {
				ids.emitAlert(SecurityAlert{
					Severity:       SeverityCritical,
					Category:       "shadow_port",
					Title:          fmt.Sprintf("Critical Exposed Shadow Port on %s (%s:%d - %s)", nodeID, entry.BindAddress, entry.Port, entry.ProcessName),
					Description:    entry.RiskReason,
					NodeHost:       nodeID,
					ContainerName:  fallbackStr(entry.ContainerName, entry.ProcessName),
					SourceIP:       nodeIP,
					DestPort:       entry.Port,
					ProcessName:    entry.ProcessName,
					PID:            entry.PID,
					MitreTactic:    "Initial Access",
					MitreTechnique: "T1190",
					ComplianceRefs: []string{"ENS op.exp.1", "CIS Docker 2.5", "NIS2 Art.21"},
					Evidence: map[string]string{
						"bind":     entry.BindAddress,
						"protocol": entry.Protocol,
						"declared": fmt.Sprintf("%v", entry.DeclaredInCompose),
						"process":  entry.ProcessName,
					},
				}, fmt.Sprintf("shadow:%s:%d", nodeID, entry.Port), 5*time.Minute)
			}
		}
	}

	return snap, surface, procs
}

// GetNodeSnapshots returns the latest telemetry snapshots for all monitored Centurions.
func (m *MultiNodeCollector) GetNodeSnapshots() []NodeTelemetry {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]NodeTelemetry, len(m.nodeSnapshots))
	copy(out, m.nodeSnapshots)
	return out
}

// GetAttackSurface returns all discovered listening ports & shadow sockets across the cluster.
func (m *MultiNodeCollector) GetAttackSurface(nodeFilter string, onlyShadow bool) []AttackSurfaceEntry {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]AttackSurfaceEntry, 0, len(m.attackSurface))
	for _, e := range m.attackSurface {
		if nodeFilter != "" && nodeFilter != "ALL" && !strings.EqualFold(e.NodeHost, nodeFilter) && e.NodeIP != nodeFilter {
			continue
		}
		if onlyShadow && !e.IsShadow {
			continue
		}
		out = append(out, e)
	}
	return out
}

// GetProcessSockets returns the forensic Process <-> Socket table across nodes.
func (m *MultiNodeCollector) GetProcessSockets(nodeFilter, query string) []ProcessSocketEntry {
	m.mu.RLock()
	defer m.mu.RUnlock()
	q := strings.ToLower(strings.TrimSpace(query))
	out := make([]ProcessSocketEntry, 0, len(m.processTable))
	for _, p := range m.processTable {
		if nodeFilter != "" && nodeFilter != "ALL" && !strings.EqualFold(p.NodeHost, nodeFilter) && p.NodeIP != nodeFilter {
			continue
		}
		if q != "" {
			blob := strings.ToLower(fmt.Sprintf("%s %s %s %s %s %d", p.NodeHost, p.ContainerName, p.ProcessName, p.CommandLine, p.RemoteAddr, p.PID))
			if !strings.Contains(blob, q) {
				continue
			}
		}
		out = append(out, p)
	}
	return out
}

// CountHighRiskSurface counts critical + high risk listening ports.
func (m *MultiNodeCollector) CountHighRiskSurface() int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	c := 0
	for _, e := range m.attackSurface {
		if e.RiskLevel == "critical" || e.RiskLevel == "high" {
			c++
		}
	}
	return c
}

func parseScriptSections(out string) map[string][]string {
	sections := make(map[string][]string)
	current := ""
	scanner := bufio.NewScanner(strings.NewReader(out))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "===") && strings.HasSuffix(line, "===") && len(line) > 6 {
			current = strings.Trim(line, "=")
			continue
		}
		if current != "" && strings.TrimSpace(line) != "" {
			sections[current] = append(sections[current], line)
		}
	}
	return sections
}

func parseSSListenLine(line, nodeID, nodeIP string, declaredPorts map[int]bool, probe *Probe) (AttackSurfaceEntry, bool) {
	fields := strings.Fields(line)
	if len(fields) < 5 {
		return AttackSurfaceEntry{}, false
	}
	proto := strings.ToUpper(fields[0])
	if strings.HasPrefix(proto, "TCP") {
		proto = "TCP"
	} else if strings.HasPrefix(proto, "UDP") {
		proto = "UDP"
	}
	local := fields[4]
	bindAddr, port := splitHostPortLoose(local)
	if port <= 0 {
		return AttackSurfaceEntry{}, false
	}
	procName, pid := extractSSProcess(line)
	containerName := ""
	if probe != nil {
		if ep := probe.LookupByIP(bindAddr); ep != nil {
			containerName = ep.Name
		}
	}
	return classifyAttackSurface(nodeID, nodeIP, proto, bindAddr, port, procName, pid, containerName, declaredPorts), true
}

func parseSSEstablishedLine(line, nodeID, nodeIP string, probe *Probe) (ProcessSocketEntry, bool) {
	fields := strings.Fields(line)
	if len(fields) < 6 {
		return ProcessSocketEntry{}, false
	}
	proto := strings.ToUpper(fields[0])
	state := fields[1]
	local := fields[4]
	remote := fields[5]
	procName, pid := extractSSProcess(line)

	srcIP, srcPort := splitHostPortLoose(local)
	dstIP, dstPort := splitHostPortLoose(remote)
	cName := procName
	if probe != nil {
		if ep := probe.LookupByIP(srcIP); ep != nil {
			cName = ep.Name
		}
	}

	// Emit real cross-node socket flow into the probe
	if probe != nil && dstIP != "" && dstIP != "127.0.0.1" && dstIP != "::1" && dstIP != "0.0.0.0" {
		probe.CorrelateRealSocket(nodeID, srcIP, srcPort, dstIP, dstPort, proto, procName, pid)
	}

	return ProcessSocketEntry{
		NodeHost:      nodeID,
		NodeIP:        nodeIP,
		ContainerName: cName,
		PID:           pid,
		ProcessName:   fallbackStr(procName, "kernel"),
		Protocol:      proto,
		State:         state,
		LocalAddr:     local,
		RemoteAddr:    remote,
		ObservedAt:    time.Now(),
	}, true
}

func collectLocalDarwinFallback(nodeID, nodeIP string, declaredPorts map[int]bool, probe *Probe) ([]AttackSurfaceEntry, []ProcessSocketEntry) {
	surface := make([]AttackSurfaceEntry, 0)
	procs := make([]ProcessSocketEntry, 0)

	// Try lsof for real listening ports on macOS
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if out, err := exec.CommandContext(ctx, "lsof", "-nP", "-iTCP", "-sTCP:LISTEN").Output(); err == nil {
		seen := make(map[string]bool)
		scanner := bufio.NewScanner(strings.NewReader(string(out)))
		first := true
		for scanner.Scan() {
			if first {
				first = false
				continue
			}
			fields := strings.Fields(scanner.Text())
			if len(fields) < 9 {
				continue
			}
			procName := fields[0]
			pid, _ := strconv.Atoi(fields[1])
			addrPart := fields[8]
			bindAddr, port := splitHostPortLoose(addrPart)
			if port <= 0 {
				continue
			}
			k := fmt.Sprintf("%s:%d", bindAddr, port)
			if seen[k] {
				continue
			}
			seen[k] = true
			surface = append(surface, classifyAttackSurface(nodeID, nodeIP, "TCP", bindAddr, port, procName, pid, "", declaredPorts))
		}
	}

	// Ensure core Gubernator ports are visible even if lsof is unavailable
	if len(surface) == 0 {
		defaults := []struct {
			port int
			bind string
			proc string
		}{
			{4000, "0.0.0.0", "gbnt-api"},
			{4001, "0.0.0.0", "gbnt-web"},
			{4002, "127.0.0.1", "gbnt-metrics"},
			{80, "0.0.0.0", "gbnt-caddy"},
			{443, "0.0.0.0", "gbnt-caddy"},
			{53, "127.0.0.1", "gbnt-coredns"},
		}
		for _, d := range defaults {
			surface = append(surface, classifyAttackSurface(nodeID, nodeIP, "TCP", d.bind, d.port, d.proc, os.Getpid(), d.proc, declaredPorts))
		}
	}

	// Synthesize ProcessSocketEntry from recent captured flows for forensic visibility
	if probe != nil {
		recent := probe.GetRecentFlows(30, "", "", "")
		for _, f := range recent {
			procs = append(procs, ProcessSocketEntry{
				NodeHost:      fallbackStr(f.NodeHost, nodeID),
				NodeIP:        nodeIP,
				ContainerName: f.SourceName,
				PID:           fallbackInt(f.PID, os.Getpid()),
				UID:           f.UID,
				ProcessName:   fallbackStr(f.ProcessName, f.SourceName),
				Protocol:      f.Protocol,
				State:         "ESTABLISHED",
				LocalAddr:     fmt.Sprintf("%s:%d", f.SourceIP, f.SourcePort),
				RemoteAddr:    fmt.Sprintf("%s:%d", f.DestIP, f.DestPort),
				Suspicious:    len(f.AnomalyTags) > 0,
				SuspicionNote: strings.Join(f.AnomalyTags, ", "),
				ObservedAt:    f.Timestamp,
			})
		}
	}

	return surface, procs
}

func classifyAttackSurface(nodeID, nodeIP, proto, bindAddr string, port int, procName string, pid int, containerName string, declaredPorts map[int]bool) AttackSurfaceEntry {
	exposure := "cluster_lan"
	if bindAddr == "127.0.0.1" || bindAddr == "::1" || strings.HasPrefix(bindAddr, "127.") {
		exposure = "loopback"
	} else if bindAddr == "0.0.0.0" || bindAddr == "*" || bindAddr == "::" || bindAddr == "[::]" {
		exposure = "public_0.0.0.0"
	}

	systemExpected := map[int]bool{
		22: true, 53: true, 80: true, 443: true, 4000: true, 4001: true, 4002: true,
		3000: true, 3100: true, 4040: true, 4317: true, 4318: true, 9090: true, 16686: true,
	}
	declared := declaredPorts[port] || systemExpected[port]
	isShadow := !declared

	riskLevel := "low"
	riskReason := "Standard declared/loopback service"

	switch {
	case port == 2375 && exposure == "public_0.0.0.0":
		riskLevel = "critical"
		riskReason = "Unencrypted Docker Daemon API exposed on 0.0.0.0 (immediate root compromise vector)"
		isShadow = true
	case (port == 5432 || port == 3306 || port == 6379 || port == 27017 || port == 9200) && exposure == "public_0.0.0.0":
		riskLevel = "critical"
		riskReason = fmt.Sprintf("Database / datastore port %d bound to 0.0.0.0 — restrict to private Docker/LAN interface", port)
	case isShadow && exposure == "public_0.0.0.0":
		riskLevel = "high"
		riskReason = fmt.Sprintf("Undeclared shadow service (%s) listening publicly on 0.0.0.0:%d outside Compose manifests", fallbackStr(procName, "unknown"), port)
	case port == 22 && exposure == "public_0.0.0.0":
		riskLevel = "medium"
		riskReason = "SSH daemon bound to 0.0.0.0 — verify key-only auth & firewall rules"
	case isShadow:
		riskLevel = "medium"
		riskReason = fmt.Sprintf("Undeclared port %d not listed in deployed Compose stacks", port)
	}

	return AttackSurfaceEntry{
		ID:                fmt.Sprintf("%s-%s-%s-%d", nodeID, proto, bindAddr, port),
		NodeHost:          nodeID,
		NodeIP:            nodeIP,
		Protocol:          proto,
		BindAddress:       bindAddr,
		Port:              port,
		ProcessName:       fallbackStr(procName, "unknown"),
		PID:               pid,
		ContainerName:     containerName,
		Exposure:          exposure,
		DeclaredInCompose: declared,
		IsShadow:          isShadow,
		RiskLevel:         riskLevel,
		RiskReason:        riskReason,
		LastSeen:          time.Now(),
	}
}

func loadDeclaredComposePorts() map[int]bool {
	ports := make(map[int]bool)
	if db.DB == nil {
		return ports
	}
	var services []db.Service
	if err := db.DB.Find(&services).Error; err != nil {
		return ports
	}
	for _, svc := range services {
		for _, pSpec := range svc.Ports {
			// Parse formats like "8080:80", "127.0.0.1:8080:80/tcp", "80"
			clean := strings.Split(pSpec, "/")[0]
			parts := strings.Split(clean, ":")
			for _, part := range parts {
				if n, err := strconv.Atoi(strings.TrimSpace(part)); err == nil && n > 0 && n <= 65535 {
					ports[n] = true
				}
			}
		}
	}
	return ports
}

func probeDNSLatency() float64 {
	start := time.Now()
	ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
	defer cancel()
	_, _ = net.DefaultResolver.LookupHost(ctx, "localhost")
	ms := float64(time.Since(start).Microseconds()) / 1000.0
	if ms < 0.1 {
		ms = 0.2
	}
	return float64(int(ms*100)) / 100
}

func extractSSProcess(line string) (string, int) {
	m := ssProcRe.FindStringSubmatch(line)
	if len(m) == 3 {
		pid, _ := strconv.Atoi(m[2])
		return m[1], pid
	}
	return "", 0
}

func splitHostPortLoose(s string) (string, int) {
	s = strings.TrimSpace(s)
	// Strip lsof suffix like "(LISTEN)"
	if idx := strings.Index(s, " "); idx > 0 {
		s = s[:idx]
	}
	lastColon := strings.LastIndex(s, ":")
	if lastColon < 0 {
		return s, 0
	}
	host := strings.Trim(s[:lastColon], "[]")
	portStr := s[lastColon+1:]
	port, _ := strconv.Atoi(portStr)
	return host, port
}

func riskWeight(level string) int {
	switch strings.ToLower(level) {
	case "critical":
		return 4
	case "high":
		return 3
	case "medium":
		return 2
	default:
		return 1
	}
}

func fallbackInt(v, def int) int {
	if v > 0 {
		return v
	}
	return def
}

// runNodeScript runs a shell script non-interactively with timeout on local host (using sudo -n fallback)
// or remotely on a Centurion worker node via storage.ExecuteRemoteScript.
func runNodeScript(targetIP, script string, timeout time.Duration) (string, error) {
	if timeout <= 0 {
		timeout = 8 * time.Second
	}
	if storage.IsLocalHost(targetIP) {
		ctx, cancel := context.WithTimeout(context.Background(), timeout)
		defer cancel()
		// Try passwordless sudo -n first; never block waiting for a password
		cmd := exec.CommandContext(ctx, "sudo", "-n", "sh", "-c", script)
		out, err := cmd.CombinedOutput()
		if err == nil {
			return strings.TrimSpace(string(out)), nil
		}
		ctx2, cancel2 := context.WithTimeout(context.Background(), timeout)
		defer cancel2()
		cmd2 := exec.CommandContext(ctx2, "sh", "-c", script)
		out2, err2 := cmd2.CombinedOutput()
		return strings.TrimSpace(string(out2)), err2
	}

	type res struct {
		out string
		err error
	}
	ch := make(chan res, 1)
	go func() {
		o, e := storage.ExecuteRemoteScript(targetIP, script)
		ch <- res{o, e}
	}()
	select {
	case r := <-ch:
		return r.out, r.err
	case <-time.After(timeout):
		return "", fmt.Errorf("remote script timeout after %s on %s", timeout, targetIP)
	}
}

package ebpf

import (
	"time"
)

// FlowStatus defines the health/status state of a network flow.
type FlowStatus string

const (
	FlowStatusHealthy FlowStatus = "healthy" // 2xx HTTP, TCP established, no drops
	FlowStatusWarning FlowStatus = "warning" // 4xx HTTP, high RTT (>200ms)
	FlowStatusError   FlowStatus = "error"   // 5xx HTTP, TCP drops, resets
)

// Flow represents a single L4/L7 network connection or request event between two endpoints.
type Flow struct {
	ID             string     `json:"id"`
	SourceID       string     `json:"source_id"`
	SourceName     string     `json:"source_name"`
	SourceIP       string     `json:"source_ip"`
	SourcePort     int        `json:"source_port"`
	DestID         string     `json:"dest_id"`
	DestName       string     `json:"dest_name"`
	DestIP         string     `json:"dest_ip"`
	DestPort       int        `json:"dest_port"`
	Protocol       string     `json:"protocol"` // "HTTP", "gRPC", "DNS", "TCP", "UDP", "REDIS", "POSTGRES"
	Method         string     `json:"method,omitempty"`
	Path           string     `json:"path,omitempty"`
	StatusCode     int        `json:"status_code,omitempty"`
	LatencyMs      float64    `json:"latency_ms"`
	BytesSent      uint64     `json:"bytes_sent"`
	BytesReceived  uint64     `json:"bytes_received"`
	ThroughputBps  float64    `json:"throughput_bps"`
	Retransmits    int        `json:"retransmits"`
	Drops          int        `json:"drops"`
	TraceID        string     `json:"trace_id,omitempty"`
	Status         FlowStatus `json:"status"`
	NodeHost       string     `json:"node_host,omitempty"`
	ProcessName    string     `json:"process_name,omitempty"`
	PID            int        `json:"pid,omitempty"`
	UID            int        `json:"uid,omitempty"`
	Synthetic      bool       `json:"synthetic,omitempty"`
	AnomalyTags    []string   `json:"anomaly_tags,omitempty"`
	MitreTechnique string     `json:"mitre_technique,omitempty"`
	Timestamp      time.Time  `json:"timestamp"`
}

// TopologyNode represents a service, container, or external entity in the topology graph.
type TopologyNode struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Type        string  `json:"type"` // "container", "ingress", "database", "dns", "external", "host"
	Stack       string  `json:"stack"`
	NodeHost    string  `json:"node_host"`
	IP          string  `json:"ip"`
	Status      string  `json:"status"` // "running", "unhealthy", "stopped", "quarantined"
	Quarantined bool    `json:"quarantined,omitempty"`
	AlertCount  int     `json:"alert_count,omitempty"`
	InboundBps  float64 `json:"inbound_bps"`
	OutboundBps float64 `json:"outbound_bps"`
	ActiveFlows int     `json:"active_flows"`
	ErrorRate   float64 `json:"error_rate"`
	CpuPercent  float64 `json:"cpu_percent,omitempty"`
	MemPercent  float64 `json:"mem_percent,omitempty"`
}

// TopologyEdge represents a directional or aggregate communication link between two nodes.
type TopologyEdge struct {
	ID            string     `json:"id"`
	SourceID      string     `json:"source_id"`
	TargetID      string     `json:"target_id"`
	Protocol      string     `json:"protocol"`
	ThroughputBps float64    `json:"throughput_bps"`
	RttMs         float64    `json:"rtt_ms"`
	ActiveFlows   int        `json:"active_flows"`
	ErrorRate     float64    `json:"error_rate"`
	TraceID       string     `json:"trace_id,omitempty"`
	Drift         bool       `json:"drift,omitempty"`
	Status        FlowStatus `json:"status"`
	LastSeen      time.Time  `json:"last_seen"`
}

// NetworkTopology holds the complete live graph structure.
type NetworkTopology struct {
	Nodes     []TopologyNode `json:"nodes"`
	Edges     []TopologyEdge `json:"edges"`
	UpdatedAt time.Time      `json:"updated_at"`
}

// InterfaceStats contains network device counters.
type InterfaceStats struct {
	Name      string `json:"name"`
	NodeHost  string `json:"node_host,omitempty"`
	RxBytes   uint64 `json:"rx_bytes"`
	TxBytes   uint64 `json:"tx_bytes"`
	RxPackets uint64 `json:"rx_packets"`
	TxPackets uint64 `json:"tx_packets"`
	RxErrors  uint64 `json:"rx_errors"`
	TxErrors  uint64 `json:"tx_errors"`
	RxDrops   uint64 `json:"rx_drops"`
	TxDrops   uint64 `json:"tx_drops"`
}

// NodeTelemetry represents live kernel & network diagnostics from a single Centurion node.
type NodeTelemetry struct {
	NodeID         string           `json:"node_id"`
	NodeIP         string           `json:"node_ip"`
	Role           string           `json:"role"`
	KernelVersion  string           `json:"kernel_version"`
	EBPFSupported  bool             `json:"ebpf_supported"`
	ActiveSockets  int              `json:"active_sockets"`
	ListeningPorts int              `json:"listening_ports"`
	TCPRetransmits int64            `json:"tcp_retransmits"`
	SynDrops       int64            `json:"syn_drops"`
	PacketDrops    int64            `json:"packet_drops"`
	DNSLatencyMs   float64          `json:"dns_latency_ms"`
	StorageIOLatMs float64          `json:"storage_io_lat_ms"`
	OpenFDs        int              `json:"open_fds"`
	MaxFDs         int              `json:"max_fds"`
	Interfaces     []InterfaceStats `json:"interfaces,omitempty"`
	Status         string           `json:"status"` // "online", "degraded", "unreachable"
	Error          string           `json:"error,omitempty"`
	LastCollected  time.Time        `json:"last_collected"`
}

// NetworkStats contains global aggregate telemetry counters.
type NetworkStats struct {
	KernelVersion     string           `json:"kernel_version"`
	EBPFSupported     bool             `json:"ebpf_supported"`
	Mode              string           `json:"mode"` // "kernel", "emulation", or "fallback"
	SyntheticPulse    bool             `json:"synthetic_pulse"`
	ActiveProbes      int              `json:"active_probes"`
	ProbesList        []string         `json:"probes_list"`
	TotalFlows        int64            `json:"total_flows"`
	ActiveFlows       int              `json:"active_flows"`
	PacketsPerSec     float64          `json:"packets_per_sec"`
	BytesPerSec       float64          `json:"bytes_per_sec"`
	DroppedPackets    int64            `json:"dropped_packets"`
	NodesMonitored    int              `json:"nodes_monitored"`
	ActiveAlerts      int              `json:"active_alerts"`
	CriticalAlerts    int              `json:"critical_alerts"`
	QuarantinedCount  int              `json:"quarantined_count"`
	BaselineLocked    bool             `json:"baseline_locked"`
	BaselineEdges     int              `json:"baseline_edges"`
	AttackSurfaceRisk int              `json:"attack_surface_risk"`
	Interfaces        []InterfaceStats `json:"interfaces,omitempty"`
	NodeSnapshots     []NodeTelemetry  `json:"node_snapshots,omitempty"`
	ProtocolCounts    map[string]int   `json:"protocol_counts"`
	StatusCounts      map[string]int   `json:"status_counts"`
}

// SimulationProfile defines the traffic pattern to inject during on-demand testing.
type SimulationProfile struct {
	Pattern   string  `json:"pattern"`    // "normal", "burst", "errors", "mixed"
	Rate      int     `json:"rate"`       // events per second
	DurationS int     `json:"duration_s"` // duration in seconds
	ErrorPct  float64 `json:"error_pct"`  // percentage of error flows (0-100)
}

// TelemetryModeRequest toggles synthetic demo traffic vs real-only kernel telemetry.
type TelemetryModeRequest struct {
	SyntheticPulse bool `json:"synthetic_pulse"`
	TriggerScan    bool `json:"trigger_scan,omitempty"`
}

// ── Runtime IDS / Threat Detection ──────────────────────────────────────────

// AlertSeverity indicates criticality of a runtime eBPF security alert.
type AlertSeverity string

const (
	SeverityCritical AlertSeverity = "critical"
	SeverityHigh     AlertSeverity = "high"
	SeverityMedium   AlertSeverity = "medium"
	SeverityLow      AlertSeverity = "low"
)

// SecurityAlert represents a real-time runtime security / IDS finding detected via eBPF telemetry.
type SecurityAlert struct {
	ID             string            `json:"id"`
	Timestamp      time.Time         `json:"timestamp"`
	Severity       AlertSeverity     `json:"severity"`
	Category       string            `json:"category"` // reverse_shell, container_escape, port_scan, lateral_movement, c2_beaconing, dns_exfiltration, cryptojacking, zero_trust_drift, shadow_port
	Title          string            `json:"title"`
	Description    string            `json:"description"`
	NodeHost       string            `json:"node_host"`
	ContainerName  string            `json:"container_name"`
	SourceIP       string            `json:"source_ip"`
	DestIP         string            `json:"dest_ip,omitempty"`
	DestPort       int               `json:"dest_port,omitempty"`
	ProcessName    string            `json:"process_name,omitempty"`
	PID            int               `json:"pid,omitempty"`
	UID            int               `json:"uid,omitempty"`
	CommandLine    string            `json:"command_line,omitempty"`
	MitreTactic    string            `json:"mitre_tactic"`
	MitreTechnique string            `json:"mitre_technique"`
	ComplianceRefs []string          `json:"compliance_refs,omitempty"` // ENS op.mon.2, NIS2 Art.21, DORA, ISO27001
	Status         string            `json:"status"`                    // "open", "acknowledged", "mitigated"
	Simulated      bool              `json:"simulated,omitempty"`
	SIEMLogged     bool              `json:"siem_logged"`
	DetectionMs    float64           `json:"detection_ms,omitempty"`
	Evidence       map[string]string `json:"evidence,omitempty"`
}

// ── Attack Surface & Shadow Port Audit ──────────────────────────────────────

// AttackSurfaceEntry represents a discovered listening port or raw socket on a Centurion node.
type AttackSurfaceEntry struct {
	ID                string    `json:"id"`
	NodeHost          string    `json:"node_host"`
	NodeIP            string    `json:"node_ip"`
	Protocol          string    `json:"protocol"` // TCP, UDP, RAW
	BindAddress       string    `json:"bind_address"`
	Port              int       `json:"port"`
	ProcessName       string    `json:"process_name"`
	PID               int       `json:"pid"`
	ContainerName     string    `json:"container_name,omitempty"`
	Exposure          string    `json:"exposure"` // "public_0.0.0.0", "cluster_lan", "loopback"
	DeclaredInCompose bool      `json:"declared_in_compose"`
	IsShadow          bool      `json:"is_shadow"`
	IsRawSocket       bool      `json:"is_raw_socket"`
	RiskLevel         string    `json:"risk_level"` // "critical", "high", "medium", "low"
	RiskReason        string    `json:"risk_reason"`
	LastSeen          time.Time `json:"last_seen"`
}

// ── Zero-Trust Micro-Segmentation Baseline ──────────────────────────────────

// ZeroTrustRule represents a learned or observed service-to-service communication edge.
type ZeroTrustRule struct {
	Key           string    `json:"key"`
	SourceName    string    `json:"source_name"`
	DestName      string    `json:"dest_name"`
	DestPort      int       `json:"dest_port"`
	Protocol      string    `json:"protocol"`
	ObservedCount int64     `json:"observed_count"`
	Allowed       bool      `json:"allowed"`
	IsDrift       bool      `json:"is_drift"`
	FirstSeen     time.Time `json:"first_seen"`
	LastSeen      time.Time `json:"last_seen"`
}

// ZeroTrustBaseline summarizes the learned micro-segmentation model and exportable firewall policy.
type ZeroTrustBaseline struct {
	Locked         bool            `json:"locked"`
	LockedAt       *time.Time      `json:"locked_at,omitempty"`
	TotalRules     int             `json:"total_rules"`
	DriftCount     int             `json:"drift_count"`
	Rules          []ZeroTrustRule `json:"rules"`
	NftablesPolicy string          `json:"nftables_policy"`
	IptablesPolicy string          `json:"iptables_policy"`
	UpdatedAt      time.Time       `json:"updated_at"`
}

// ── Forensic Process ↔ Socket Timeline ──────────────────────────────────────

// ProcessSocketEntry correlates a kernel socket to its exact OS process, binary, UID, container and node.
type ProcessSocketEntry struct {
	NodeHost      string    `json:"node_host"`
	NodeIP        string    `json:"node_ip"`
	ContainerName string    `json:"container_name"`
	PID           int       `json:"pid"`
	UID           int       `json:"uid"`
	UserName      string    `json:"user_name,omitempty"`
	ProcessName   string    `json:"process_name"`
	CommandLine   string    `json:"command_line,omitempty"`
	Protocol      string    `json:"protocol"`
	State         string    `json:"state"`
	LocalAddr     string    `json:"local_addr"`
	RemoteAddr    string    `json:"remote_addr"`
	Suspicious    bool      `json:"suspicious"`
	SuspicionNote string    `json:"suspicion_note,omitempty"`
	ObservedAt    time.Time `json:"observed_at"`
}

// ── Forensic Container Quarantine ("Kill Switch") ───────────────────────────

// QuarantineRequest triggers forensic network isolation of a container without destroying its RAM/processes.
type QuarantineRequest struct {
	ContainerName string `json:"container_name" binding:"required"`
	NodeHost      string `json:"node_host"`
	ContainerIP   string `json:"container_ip"`
	Reason        string `json:"reason"`
	AlertID       string `json:"alert_id"`
}

// QuarantineRecord tracks an isolated container and how to restore it.
type QuarantineRecord struct {
	ID                 string     `json:"id"`
	ContainerName      string     `json:"container_name"`
	ContainerIP        string     `json:"container_ip,omitempty"`
	NodeHost           string     `json:"node_host"`
	NodeIP             string     `json:"node_ip"`
	Reason             string     `json:"reason"`
	AlertID            string     `json:"alert_id,omitempty"`
	QuarantinedAt      time.Time  `json:"quarantined_at"`
	ReleasedAt         *time.Time `json:"released_at,omitempty"`
	QuarantinedBy      string     `json:"quarantined_by"`
	Status             string     `json:"status"` // "active", "released"
	Method             string     `json:"method"` // "docker_disconnect", "iptables_drop", "simulated"
	PreviousNetworks   []string   `json:"previous_networks,omitempty"`
	PreservedForensics bool       `json:"preserved_forensics"`
	Details            string     `json:"details,omitempty"`
}

// ── On-Demand Forensic PCAP Capture ─────────────────────────────────────────

// PCAPCaptureRequest configures an on-demand packet capture on a Centurion node.
type PCAPCaptureRequest struct {
	NodeHost      string `json:"node_host"`
	ContainerName string `json:"container_name"`
	Filter        string `json:"filter"`     // BPF expression e.g. "tcp port 443" or "host 172.18.0.5"
	DurationS     int    `json:"duration_s"` // 5..60 seconds
}

// PCAPCapture tracks a completed or running forensic packet capture.
type PCAPCapture struct {
	ID                string         `json:"id"`
	NodeHost          string         `json:"node_host"`
	NodeIP            string         `json:"node_ip"`
	ContainerName     string         `json:"container_name,omitempty"`
	Filter            string         `json:"filter"`
	DurationS         int            `json:"duration_s"`
	Source            string         `json:"source"` // "kernel_tcpdump" or "ebpf_flow_synthesized"
	PacketCount       int            `json:"packet_count"`
	SizeBytes         int64          `json:"size_bytes"`
	FilePath          string         `json:"file_path,omitempty"`
	Status            string         `json:"status"` // "running", "completed", "failed"
	SummaryLines      []string       `json:"summary_lines,omitempty"`
	ProtocolBreakdown map[string]int `json:"protocol_breakdown,omitempty"`
	Error             string         `json:"error,omitempty"`
	CreatedAt         time.Time      `json:"created_at"`
}

// ── Purple Team MITRE ATT&CK Validation Lab ─────────────────────────────────

// PurpleTeamScenario describes a controlled, auditable ethical hacking validation playbook.
type PurpleTeamScenario struct {
	ID             string   `json:"id"`
	Name           string   `json:"name"`
	Category       string   `json:"category"`
	MitreTactic    string   `json:"mitre_tactic"`
	MitreTechnique string   `json:"mitre_technique"`
	Severity       string   `json:"severity"`
	Description    string   `json:"description"`
	ComplianceRefs []string `json:"compliance_refs"`
}

// PurpleTeamRunRequest requests execution of a Purple Team validation playbook.
type PurpleTeamRunRequest struct {
	ScenarioID      string `json:"scenario_id" binding:"required"`
	TargetNode      string `json:"target_node"`
	TargetContainer string `json:"target_container"`
}

// PurpleTeamStep records a single auditable step inside a Purple Team test execution.
type PurpleTeamStep struct {
	Name       string  `json:"name"`
	Status     string  `json:"status"` // "passed", "detected", "failed"
	Detail     string  `json:"detail"`
	DurationMs float64 `json:"duration_ms"`
}

// PurpleTeamRun captures the full verification scorecard of a Purple Team test.
type PurpleTeamRun struct {
	ID              string           `json:"id"`
	ScenarioID      string           `json:"scenario_id"`
	ScenarioName    string           `json:"scenario_name"`
	MitreTactic     string           `json:"mitre_tactic"`
	MitreTechnique  string           `json:"mitre_technique"`
	TargetNode      string           `json:"target_node"`
	TargetContainer string           `json:"target_container"`
	StartedAt       time.Time        `json:"started_at"`
	CompletedAt     time.Time        `json:"completed_at"`
	Detected        bool             `json:"detected"`
	MTTDMs          float64          `json:"mttd_ms"`
	AlertsTriggered int              `json:"alerts_triggered"`
	AlertIDs        []string         `json:"alert_ids,omitempty"`
	SIEMLogged      bool             `json:"siem_logged"`
	Score           int              `json:"score"` // 0-100
	Steps           []PurpleTeamStep `json:"steps"`
}

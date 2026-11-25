package ebpf

import (
	"encoding/json"
	"fmt"
	"math"
	"net"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/gubernator-org/gubernator/internal/audit"
	"github.com/gubernator-org/gubernator/internal/db"
)

var (
	reverseShellRe = regexp.MustCompile(`(?i)(\bnc\b.*-[ec]|\bncat\b|\bsocat\b.*exec|bash\s+-i|/dev/tcp/|python[23]?\s+-c.*socket|perl\s+-e.*socket|php\s+-r.*fsockopen|curl\s+.*\|\s*(sh|bash)|wget\s+.*\|\s*(sh|bash)|mkfifo\s+/tmp/)`)
	escapeCmdRe    = regexp.MustCompile(`(?i)(\bnsenter\b|\bunshare\b.*--mount|/var/run/docker\.sock|/etc/shadow|/proc/1/root|chroot\s+/host|capsh\s+--|insmod\b|modprobe\b)`)
	miningPorts    = map[int]bool{
		3333: true, 4444: true, 5555: true, 7777: true,
		8888: true, 9999: true, 14433: true, 14444: true, 45700: true,
	}
	sensitiveLateralPorts = map[int]string{
		22:    "SSH",
		2375:  "Docker Daemon (Unencrypted)",
		2376:  "Docker Daemon TLS",
		3306:  "MySQL/MariaDB",
		5432:  "PostgreSQL",
		6379:  "Redis",
		27017: "MongoDB",
		4000:  "Gubernator Control API",
		2019:  "Caddy Admin API",
	}
)

type portScanWindow struct {
	ports map[int]time.Time
}

type beaconHistory struct {
	timestamps []time.Time
}

// SecurityIDS performs real-time runtime threat detection, Zero-Trust baseline tracking,
// and automatic SIEM / Audit chain recording on all eBPF network & process telemetry.
type SecurityIDS struct {
	mu             sync.RWMutex
	alerts         []SecurityAlert
	maxAlerts      int
	dedupCache     map[string]time.Time
	scanTracker    map[string]*portScanWindow // srcIP/srcName -> recent dest ports
	beaconTracker  map[string]*beaconHistory  // src->dst:port -> timestamps
	baselineLocked bool
	baselineLockAt *time.Time
	baselineRules  map[string]*ZeroTrustRule
}

// NewSecurityIDS creates a new runtime IDS and Zero-Trust engine.
func NewSecurityIDS() *SecurityIDS {
	return &SecurityIDS{
		alerts:        make([]SecurityAlert, 0, 200),
		maxAlerts:     500,
		dedupCache:    make(map[string]time.Time),
		scanTracker:   make(map[string]*portScanWindow),
		beaconTracker: make(map[string]*beaconHistory),
		baselineRules: make(map[string]*ZeroTrustRule),
	}
}

// AnalyzeFlow inspects every emitted Flow in real time for threats and Zero-Trust drift.
// It returns any triggered alerts and mutates flow anomaly tags / MITRE metadata.
func (s *SecurityIDS) AnalyzeFlow(f *Flow) []SecurityAlert {
	start := time.Now()
	var triggered []SecurityAlert

	// 1. Update Zero-Trust Baseline / Detect Drift
	if f.SourceName != "" && f.DestName != "" && f.SourceName != f.DestName {
		if driftAlert := s.trackZeroTrust(f, start); driftAlert != nil {
			triggered = append(triggered, *driftAlert)
			f.AnomalyTags = appendUnique(f.AnomalyTags, "zero_trust_drift")
			if f.MitreTechnique == "" {
				f.MitreTechnique = "T1049"
			}
		}
	}

	// 2. Cryptojacking / Mining Pool detection (T1496)
	if miningPorts[f.DestPort] || strings.Contains(strings.ToLower(f.Path), "stratum") || strings.Contains(strings.ToLower(f.DestName), "xmr") || strings.Contains(strings.ToLower(f.DestName), "pool") {
		if a := s.emitAlert(SecurityAlert{
			Severity:       SeverityCritical,
			Category:       "cryptojacking",
			Title:          fmt.Sprintf("Cryptojacking / Mining Pool Connection (%s -> %s:%d)", f.SourceName, f.DestIP, f.DestPort),
			Description:    "Outbound traffic matched a known Stratum cryptomining port or pool signature. Correlate with sustained CPU utilization and isolate the container immediately.",
			NodeHost:       fallbackStr(f.NodeHost, "manager"),
			ContainerName:  f.SourceName,
			SourceIP:       f.SourceIP,
			DestIP:         f.DestIP,
			DestPort:       f.DestPort,
			ProcessName:    f.ProcessName,
			PID:            f.PID,
			UID:            f.UID,
			MitreTactic:    "Impact",
			MitreTechnique: "T1496",
			ComplianceRefs: []string{"ENS op.exp.8", "NIS2 Art.21", "ISO27001 A.8.16"},
			Simulated:      f.Synthetic,
			DetectionMs:    elapsedMs(start),
			Evidence: map[string]string{
				"protocol":  f.Protocol,
				"dest_port": fmt.Sprintf("%d", f.DestPort),
				"path":      f.Path,
			},
		}, fmt.Sprintf("crypto:%s:%s:%d", f.SourceName, f.DestIP, f.DestPort), 15*time.Second); a != nil {
			triggered = append(triggered, *a)
			f.AnomalyTags = appendUnique(f.AnomalyTags, "cryptojacking")
			f.MitreTechnique = "T1496"
		}
	}

	// 3. DNS Tunneling / Exfiltration detection (T1071.004)
	if strings.EqualFold(f.Protocol, "DNS") && f.Path != "" {
		q := strings.TrimSpace(f.Path)
		entropy := shannonEntropy(q)
		if len(q) > 52 || (len(q) > 36 && entropy > 3.8) || strings.Contains(strings.ToLower(q), "exfil") {
			if a := s.emitAlert(SecurityAlert{
				Severity:       SeverityHigh,
				Category:       "dns_exfiltration",
				Title:          fmt.Sprintf("Suspected DNS Tunneling / Exfiltration from %s", f.SourceName),
				Description:    fmt.Sprintf("High-entropy or abnormally long DNS query (%d chars, entropy %.2f) detected — consistent with DNS data exfiltration or C2 tunneling.", len(q), entropy),
				NodeHost:       fallbackStr(f.NodeHost, "manager"),
				ContainerName:  f.SourceName,
				SourceIP:       f.SourceIP,
				DestIP:         f.DestIP,
				DestPort:       f.DestPort,
				ProcessName:    f.ProcessName,
				PID:            f.PID,
				MitreTactic:    "Exfiltration",
				MitreTechnique: "T1071.004",
				ComplianceRefs: []string{"ENS op.mon.2", "NIS2 Art.21", "DORA Art.10"},
				Simulated:      f.Synthetic,
				DetectionMs:    elapsedMs(start),
				Evidence: map[string]string{
					"dns_query": q,
					"length":    fmt.Sprintf("%d", len(q)),
					"entropy":   fmt.Sprintf("%.2f", entropy),
				},
			}, fmt.Sprintf("dns:%s:%s", f.SourceName, q[:minInt(len(q), 24)]), 10*time.Second); a != nil {
				triggered = append(triggered, *a)
				f.AnomalyTags = appendUnique(f.AnomalyTags, "dns_exfiltration")
				f.MitreTechnique = "T1071.004"
			}
		}
	}

	// 4. Internal Port Scan Sweep detection (T1046)
	if f.SourceName != "" && f.DestPort > 0 && !f.Synthetic || (f.Synthetic && hasTag(f.AnomalyTags, "purple_portscan")) {
		srcKey := fallbackStr(f.SourceName, f.SourceIP)
		distinctPorts := s.recordPortProbe(srcKey, f.DestPort, f.Timestamp)
		if distinctPorts >= 6 {
			if a := s.emitAlert(SecurityAlert{
				Severity:       SeverityHigh,
				Category:       "port_scan",
				Title:          fmt.Sprintf("Internal Port Scan Sweep Detected from %s (%d ports/30s)", srcKey, distinctPorts),
				Description:    fmt.Sprintf("Container/host %s probed %d distinct destination ports within 30 seconds, indicative of reconnaissance (nmap/masscan).", srcKey, distinctPorts),
				NodeHost:       fallbackStr(f.NodeHost, "manager"),
				ContainerName:  f.SourceName,
				SourceIP:       f.SourceIP,
				DestIP:         f.DestIP,
				DestPort:       f.DestPort,
				ProcessName:    f.ProcessName,
				PID:            f.PID,
				MitreTactic:    "Discovery",
				MitreTechnique: "T1046",
				ComplianceRefs: []string{"ENS op.mon.2", "NIS2 Art.21", "ISO27001 A.8.16"},
				Simulated:      f.Synthetic,
				DetectionMs:    elapsedMs(start),
				Evidence: map[string]string{
					"distinct_ports_30s": fmt.Sprintf("%d", distinctPorts),
					"last_dest_ip":       f.DestIP,
					"last_dest_port":     fmt.Sprintf("%d", f.DestPort),
				},
			}, fmt.Sprintf("scan:%s", srcKey), 20*time.Second); a != nil {
				triggered = append(triggered, *a)
				f.AnomalyTags = appendUnique(f.AnomalyTags, "port_scan")
				f.MitreTechnique = "T1046"
			}
		}
	}

	// 5. East-West Lateral Movement to Sensitive Ports (T1021)
	if svcLabel, isSensitive := sensitiveLateralPorts[f.DestPort]; isSensitive {
		srcLower := strings.ToLower(f.SourceName)
		// Flag unexpected sources hitting SSH, Docker daemon, or DBs (excluding Prometheus/Grafana/Manager expected paths)
		isUnexpected := f.DestPort == 22 || f.DestPort == 2375 || f.DestPort == 2376 ||
			(strings.Contains(srcLower, "caddy") && (f.DestPort == 5432 || f.DestPort == 3306 || f.DestPort == 6379)) ||
			hasTag(f.AnomalyTags, "purple_lateral")
		if isUnexpected {
			if a := s.emitAlert(SecurityAlert{
				Severity:       SeverityCritical,
				Category:       "lateral_movement",
				Title:          fmt.Sprintf("East-West Lateral Movement Attempt: %s -> %s (%s:%d)", f.SourceName, f.DestName, svcLabel, f.DestPort),
				Description:    fmt.Sprintf("Unexpected lateral connection toward privileged/sensitive service %s (port %d) from %s.", svcLabel, f.DestPort, f.SourceName),
				NodeHost:       fallbackStr(f.NodeHost, "manager"),
				ContainerName:  f.SourceName,
				SourceIP:       f.SourceIP,
				DestIP:         f.DestIP,
				DestPort:       f.DestPort,
				ProcessName:    f.ProcessName,
				PID:            f.PID,
				MitreTactic:    "Lateral Movement",
				MitreTechnique: "T1021",
				ComplianceRefs: []string{"ENS op.mon.2", "NIS2 Art.21", "DORA Art.10", "ISO27001 A.8.22"},
				Simulated:      f.Synthetic,
				DetectionMs:    elapsedMs(start),
				Evidence: map[string]string{
					"service":   svcLabel,
					"dest_port": fmt.Sprintf("%d", f.DestPort),
					"dest_node": f.DestName,
					"protocol":  f.Protocol,
				},
			}, fmt.Sprintf("lat:%s:%s:%d", f.SourceName, f.DestName, f.DestPort), 15*time.Second); a != nil {
				triggered = append(triggered, *a)
				f.AnomalyTags = appendUnique(f.AnomalyTags, "lateral_movement")
				f.MitreTechnique = "T1021"
			}
		}
	}

	// 6. External C2 Beaconing & Egress Exfiltration Spike (T1071 / T1041)
	if isExternalIP(f.DestIP) {
		// Large outbound exfiltration spike (>5 MB single flow)
		if f.BytesSent > 5*1024*1024 {
			if a := s.emitAlert(SecurityAlert{
				Severity:       SeverityHigh,
				Category:       "c2_beaconing",
				Title:          fmt.Sprintf("Anomalous Egress Volume to External IP (%s -> %s:%d)", f.SourceName, f.DestIP, f.DestPort),
				Description:    fmt.Sprintf("Outbound transfer of %.2f MB to non-RFC1918 IP %s detected from container %s.", float64(f.BytesSent)/(1024*1024), f.DestIP, f.SourceName),
				NodeHost:       fallbackStr(f.NodeHost, "manager"),
				ContainerName:  f.SourceName,
				SourceIP:       f.SourceIP,
				DestIP:         f.DestIP,
				DestPort:       f.DestPort,
				ProcessName:    f.ProcessName,
				PID:            f.PID,
				MitreTactic:    "Exfiltration",
				MitreTechnique: "T1041",
				ComplianceRefs: []string{"ENS op.mon.2", "NIS2 Art.21", "DORA Art.10"},
				Simulated:      f.Synthetic,
				DetectionMs:    elapsedMs(start),
				Evidence: map[string]string{
					"bytes_sent": fmt.Sprintf("%d", f.BytesSent),
					"dest_ip":    f.DestIP,
				},
			}, fmt.Sprintf("exfil:%s:%s", f.SourceName, f.DestIP), 30*time.Second); a != nil {
				triggered = append(triggered, *a)
				f.AnomalyTags = appendUnique(f.AnomalyTags, "egress_exfiltration")
				f.MitreTechnique = "T1041"
			}
		}

		// Periodic C2 Beaconing check (low-jitter repeated callbacks)
		if jitter, count, isBeacon := s.recordBeacon(fmt.Sprintf("%s->%s:%d", f.SourceName, f.DestIP, f.DestPort), f.Timestamp); isBeacon {
			if a := s.emitAlert(SecurityAlert{
				Severity:       SeverityHigh,
				Category:       "c2_beaconing",
				Title:          fmt.Sprintf("Periodic C2 Beaconing Pattern (%s -> %s:%d)", f.SourceName, f.DestIP, f.DestPort),
				Description:    fmt.Sprintf("Detected %d regular outbound callbacks with low timing jitter (CV=%.2f) to external endpoint %s:%d.", count, jitter, f.DestIP, f.DestPort),
				NodeHost:       fallbackStr(f.NodeHost, "manager"),
				ContainerName:  f.SourceName,
				SourceIP:       f.SourceIP,
				DestIP:         f.DestIP,
				DestPort:       f.DestPort,
				MitreTactic:    "Command and Control",
				MitreTechnique: "T1071",
				ComplianceRefs: []string{"ENS op.mon.2", "NIS2 Art.21"},
				Simulated:      f.Synthetic,
				DetectionMs:    elapsedMs(start),
				Evidence: map[string]string{
					"callback_count": fmt.Sprintf("%d", count),
					"jitter_cv":      fmt.Sprintf("%.3f", jitter),
				},
			}, fmt.Sprintf("beacon:%s:%s:%d", f.SourceName, f.DestIP, f.DestPort), 30*time.Second); a != nil {
				triggered = append(triggered, *a)
				f.AnomalyTags = appendUnique(f.AnomalyTags, "c2_beaconing")
				f.MitreTechnique = "T1071"
			}
		}
	}

	return triggered
}

// InspectProcessCommand inspects a running container/host process for Reverse Shells (T1059.004)
// and Container Escape attempts (T1611).
func (s *SecurityIDS) InspectProcessCommand(nodeHost, containerName, procName, cmdLine string, pid, uid int, simulated bool) *SecurityAlert {
	start := time.Now()
	combined := strings.TrimSpace(procName + " " + cmdLine)
	if combined == "" {
		return nil
	}

	// Container escape / host privilege probe
	if escapeCmdRe.MatchString(combined) {
		return s.emitAlert(SecurityAlert{
			Severity:       SeverityCritical,
			Category:       "container_escape",
			Title:          fmt.Sprintf("Container Escape / Host Privilege Probe in %s", fallbackStr(containerName, nodeHost)),
			Description:    "Detected suspicious process attempting namespace breakout, Docker socket access, or host credential inspection.",
			NodeHost:       fallbackStr(nodeHost, "manager"),
			ContainerName:  containerName,
			ProcessName:    procName,
			PID:            pid,
			UID:            uid,
			CommandLine:    truncateStr(cmdLine, 220),
			MitreTactic:    "Privilege Escalation",
			MitreTechnique: "T1611",
			ComplianceRefs: []string{"ENS op.exp.2", "NIS2 Art.21", "ISO27001 A.8.2", "CIS Docker 5.4"},
			Simulated:      simulated,
			DetectionMs:    elapsedMs(start),
			Evidence: map[string]string{
				"cmdline": truncateStr(cmdLine, 220),
				"pid":     fmt.Sprintf("%d", pid),
				"uid":     fmt.Sprintf("%d", uid),
			},
		}, fmt.Sprintf("escape:%s:%s:%d", nodeHost, containerName, pid), 15*time.Second)
	}

	// Reverse shell / suspicious interactive shell
	if reverseShellRe.MatchString(combined) {
		return s.emitAlert(SecurityAlert{
			Severity:       SeverityCritical,
			Category:       "reverse_shell",
			Title:          fmt.Sprintf("Reverse Shell / Suspicious Exec in %s (%s)", fallbackStr(containerName, nodeHost), procName),
			Description:    "Process command line matched reverse shell or remote pipe-to-shell execution pattern inside a running workload.",
			NodeHost:       fallbackStr(nodeHost, "manager"),
			ContainerName:  containerName,
			ProcessName:    procName,
			PID:            pid,
			UID:            uid,
			CommandLine:    truncateStr(cmdLine, 220),
			MitreTactic:    "Execution",
			MitreTechnique: "T1059.004",
			ComplianceRefs: []string{"ENS op.mon.2", "NIS2 Art.21", "DORA Art.10", "ISO27001 A.8.16"},
			Simulated:      simulated,
			DetectionMs:    elapsedMs(start),
			Evidence: map[string]string{
				"cmdline": truncateStr(cmdLine, 220),
				"pid":     fmt.Sprintf("%d", pid),
				"uid":     fmt.Sprintf("%d", uid),
			},
		}, fmt.Sprintf("revshell:%s:%s:%d", nodeHost, containerName, pid), 15*time.Second)
	}

	return nil
}

func (s *SecurityIDS) trackZeroTrust(f *Flow, start time.Time) *SecurityAlert {
	key := fmt.Sprintf("%s->%s:%d/%s", f.SourceName, f.DestName, f.DestPort, strings.ToUpper(f.Protocol))
	now := time.Now()

	s.mu.Lock()
	rule, exists := s.baselineRules[key]
	if !exists {
		isDrift := s.baselineLocked
		rule = &ZeroTrustRule{
			Key:           key,
			SourceName:    f.SourceName,
			DestName:      f.DestName,
			DestPort:      f.DestPort,
			Protocol:      strings.ToUpper(f.Protocol),
			ObservedCount: 1,
			Allowed:       !s.baselineLocked,
			IsDrift:       isDrift,
			FirstSeen:     now,
			LastSeen:      now,
		}
		s.baselineRules[key] = rule
		s.mu.Unlock()

		if isDrift {
			return s.emitAlert(SecurityAlert{
				Severity:       SeverityMedium,
				Category:       "zero_trust_drift",
				Title:          fmt.Sprintf("Zero-Trust Baseline Drift: %s -> %s:%d", f.SourceName, f.DestName, f.DestPort),
				Description:    fmt.Sprintf("Unauthorized east-west edge (%s) observed while Zero-Trust baseline is locked.", key),
				NodeHost:       fallbackStr(f.NodeHost, "manager"),
				ContainerName:  f.SourceName,
				SourceIP:       f.SourceIP,
				DestIP:         f.DestIP,
				DestPort:       f.DestPort,
				MitreTactic:    "Discovery",
				MitreTechnique: "T1049",
				ComplianceRefs: []string{"ENS mp.com.1", "ISO27001 A.8.22", "NIS2 Art.21"},
				Simulated:      f.Synthetic,
				DetectionMs:    elapsedMs(start),
				Evidence: map[string]string{
					"edge_key": key,
				},
			}, "zt:"+key, 30*time.Second)
		}
		return nil
	}

	rule.ObservedCount++
	rule.LastSeen = now
	s.mu.Unlock()
	return nil
}

// IsEdgeDrift checks whether a topology edge is flagged as Zero-Trust drift.
func (s *SecurityIDS) IsEdgeDrift(sourceName, destName, proto string) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if !s.baselineLocked {
		return false
	}
	prefix := fmt.Sprintf("%s->%s:", sourceName, destName)
	protoUpper := strings.ToUpper(proto)
	for k, r := range s.baselineRules {
		if strings.HasPrefix(k, prefix) && r.Protocol == protoUpper && r.IsDrift {
			return true
		}
	}
	return false
}

// SetBaselineLocked locks or unlocks the Zero-Trust baseline.
// If resetAndLearn is true, existing drifted rules are promoted to allowed baseline rules.
func (s *SecurityIDS) SetBaselineLocked(locked bool, resetAndLearn bool) ZeroTrustBaseline {
	s.mu.Lock()
	if resetAndLearn {
		for _, r := range s.baselineRules {
			r.Allowed = true
			r.IsDrift = false
		}
	}
	s.baselineLocked = locked
	if locked {
		now := time.Now()
		s.baselineLockAt = &now
	} else {
		s.baselineLockAt = nil
	}
	s.mu.Unlock()
	return s.GetZeroTrustBaseline()
}

// GetZeroTrustBaseline returns the learned communication matrix and generated nftables/iptables policies.
func (s *SecurityIDS) GetZeroTrustBaseline() ZeroTrustBaseline {
	s.mu.RLock()
	defer s.mu.RUnlock()

	rules := make([]ZeroTrustRule, 0, len(s.baselineRules))
	driftCount := 0
	for _, r := range s.baselineRules {
		rules = append(rules, *r)
		if r.IsDrift {
			driftCount++
		}
	}
	sort.Slice(rules, func(i, j int) bool {
		if rules[i].IsDrift != rules[j].IsDrift {
			return rules[i].IsDrift
		}
		return rules[i].ObservedCount > rules[j].ObservedCount
	})

	return ZeroTrustBaseline{
		Locked:         s.baselineLocked,
		LockedAt:       s.baselineLockAt,
		TotalRules:     len(rules),
		DriftCount:     driftCount,
		Rules:          rules,
		NftablesPolicy: generateNftablesPolicy(rules),
		IptablesPolicy: generateIptablesPolicy(rules),
		UpdatedAt:      time.Now(),
	}
}

func generateNftablesPolicy(rules []ZeroTrustRule) string {
	var b strings.Builder
	b.WriteString("# Gubernator eBPF Zero-Trust Micro-Segmentation Policy (nftables)\n")
	b.WriteString("table inet gbnt_zerotrust {\n")
	b.WriteString("  chain forward {\n")
	b.WriteString("    type filter hook forward priority 0; policy drop;\n")
	b.WriteString("    ct state established,related accept\n")
	b.WriteString("    iifname \"lo\" accept\n")
	for _, r := range rules {
		if !r.Allowed || r.DestPort <= 0 {
			continue
		}
		l4 := "tcp"
		if strings.EqualFold(r.Protocol, "UDP") || strings.EqualFold(r.Protocol, "DNS") {
			l4 = "udp"
		}
		b.WriteString(fmt.Sprintf("    # %s -> %s (%s)\n", r.SourceName, r.DestName, r.Protocol))
		b.WriteString(fmt.Sprintf("    %s dport %d accept\n", l4, r.DestPort))
	}
	b.WriteString("    log prefix \"[GBNT-ZT-DROP] \" counter drop\n")
	b.WriteString("  }\n")
	b.WriteString("}\n")
	return b.String()
}

func generateIptablesPolicy(rules []ZeroTrustRule) string {
	var b strings.Builder
	b.WriteString("#!/bin/sh\n# Gubernator eBPF Zero-Trust Micro-Segmentation (iptables DOCKER-USER)\n")
	b.WriteString("iptables -N GBNT_ZEROTRUST 2>/dev/null || iptables -F GBNT_ZEROTRUST\n")
	b.WriteString("iptables -A GBNT_ZEROTRUST -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT\n")
	for _, r := range rules {
		if !r.Allowed || r.DestPort <= 0 {
			continue
		}
		l4 := "tcp"
		if strings.EqualFold(r.Protocol, "UDP") || strings.EqualFold(r.Protocol, "DNS") {
			l4 = "udp"
		}
		b.WriteString(fmt.Sprintf("# Allow %s -> %s (%s)\n", r.SourceName, r.DestName, r.Protocol))
		b.WriteString(fmt.Sprintf("iptables -A GBNT_ZEROTRUST -p %s --dport %d -j ACCEPT\n", l4, r.DestPort))
	}
	b.WriteString("iptables -A GBNT_ZEROTRUST -j LOG --log-prefix \"[GBNT-ZT-DROP] \"\n")
	b.WriteString("iptables -A GBNT_ZEROTRUST -j DROP\n")
	return b.String()
}

func (s *SecurityIDS) emitAlert(a SecurityAlert, dedupKey string, dedupTTL time.Duration) *SecurityAlert {
	now := time.Now()
	s.mu.Lock()
	if dedupKey != "" && dedupTTL > 0 {
		if prev, ok := s.dedupCache[dedupKey]; ok && now.Sub(prev) < dedupTTL {
			s.mu.Unlock()
			return nil
		}
		s.dedupCache[dedupKey] = now
	}

	if a.ID == "" {
		a.ID = "ebpf-alert-" + uuid.New().String()[:8]
	}
	if a.Timestamp.IsZero() {
		a.Timestamp = now
	}
	if a.Status == "" {
		a.Status = "open"
	}

	// Automatically forward to Gubernator Tamper-Evident Audit Chain + OpenSearch SIEM
	if db.DB != nil && (a.Severity == SeverityCritical || a.Severity == SeverityHigh || a.Simulated) {
		detailsJSON, _ := json.Marshal(map[string]interface{}{
			"alert_id":        a.ID,
			"category":        a.Category,
			"severity":        a.Severity,
			"title":           a.Title,
			"node":            a.NodeHost,
			"container":       a.ContainerName,
			"mitre_tactic":    a.MitreTactic,
			"mitre_technique": a.MitreTechnique,
			"compliance_refs": a.ComplianceRefs,
			"simulated":       a.Simulated,
			"evidence":        a.Evidence,
		})
		action := "EBPF_INTRUSION_" + strings.ToUpper(a.Category)
		if _, err := audit.RecordEvent("ebpf-ids", "EBPF-IDS", fallbackStr(a.SourceIP, "127.0.0.1"), action, "ALERT", string(detailsJSON)); err == nil {
			a.SIEMLogged = true
		}
	}

	if len(s.alerts) >= s.maxAlerts {
		s.alerts = s.alerts[1:]
	}
	s.alerts = append(s.alerts, a)
	s.mu.Unlock()
	return &a
}

// GetAlerts returns recent security alerts filtered by severity, category, or status.
func (s *SecurityIDS) GetAlerts(severity, category, status string, limit int) []SecurityAlert {
	s.mu.RLock()
	defer s.mu.RUnlock()

	out := make([]SecurityAlert, 0)
	for i := len(s.alerts) - 1; i >= 0; i-- {
		a := s.alerts[i]
		if severity != "" && severity != "ALL" && !strings.EqualFold(string(a.Severity), severity) {
			continue
		}
		if category != "" && category != "ALL" && !strings.EqualFold(a.Category, category) {
			continue
		}
		if status != "" && status != "ALL" && !strings.EqualFold(a.Status, status) {
			continue
		}
		out = append(out, a)
		if limit > 0 && len(out) >= limit {
			break
		}
	}
	return out
}

// AcknowledgeAlert updates an alert's status to acknowledged or mitigated.
func (s *SecurityIDS) AcknowledgeAlert(id string, newStatus string) (*SecurityAlert, bool) {
	if newStatus == "" {
		newStatus = "acknowledged"
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.alerts {
		if s.alerts[i].ID == id {
			s.alerts[i].Status = newStatus
			cp := s.alerts[i]
			return &cp, true
		}
	}
	return nil, false
}

// ClearAlerts removes either simulated alerts or all alerts.
func (s *SecurityIDS) ClearAlerts(onlySimulated bool) int {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !onlySimulated {
		n := len(s.alerts)
		s.alerts = make([]SecurityAlert, 0, 200)
		return n
	}
	kept := make([]SecurityAlert, 0, len(s.alerts))
	removed := 0
	for _, a := range s.alerts {
		if a.Simulated {
			removed++
			continue
		}
		kept = append(kept, a)
	}
	s.alerts = kept
	return removed
}

// CountAlerts returns total open alerts, critical open alerts, and per-container open alert counts.
func (s *SecurityIDS) CountAlerts() (openTotal int, criticalOpen int, byContainer map[string]int) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	byContainer = make(map[string]int)
	for _, a := range s.alerts {
		if a.Status == "open" {
			openTotal++
			if a.Severity == SeverityCritical {
				criticalOpen++
			}
			if a.ContainerName != "" {
				byContainer[a.ContainerName]++
			}
		}
	}
	return
}

func (s *SecurityIDS) recordPortProbe(srcKey string, port int, ts time.Time) int {
	s.mu.Lock()
	defer s.mu.Unlock()
	if ts.IsZero() {
		ts = time.Now()
	}
	w, ok := s.scanTracker[srcKey]
	if !ok {
		w = &portScanWindow{ports: make(map[int]time.Time)}
		s.scanTracker[srcKey] = w
	}
	w.ports[port] = ts
	cutoff := ts.Add(-30 * time.Second)
	for p, t := range w.ports {
		if t.Before(cutoff) {
			delete(w.ports, p)
		}
	}
	return len(w.ports)
}

func (s *SecurityIDS) recordBeacon(key string, ts time.Time) (float64, int, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if ts.IsZero() {
		ts = time.Now()
	}
	bh, ok := s.beaconTracker[key]
	if !ok {
		bh = &beaconHistory{}
		s.beaconTracker[key] = bh
	}
	bh.timestamps = append(bh.timestamps, ts)
	if len(bh.timestamps) > 12 {
		bh.timestamps = bh.timestamps[len(bh.timestamps)-12:]
	}
	if len(bh.timestamps) < 5 {
		return 0, len(bh.timestamps), false
	}
	intervals := make([]float64, 0, len(bh.timestamps)-1)
	var sum float64
	for i := 1; i < len(bh.timestamps); i++ {
		d := bh.timestamps[i].Sub(bh.timestamps[i-1]).Seconds()
		if d > 0.2 {
			intervals = append(intervals, d)
			sum += d
		}
	}
	if len(intervals) < 4 {
		return 0, len(bh.timestamps), false
	}
	mean := sum / float64(len(intervals))
	if mean <= 0 {
		return 0, len(bh.timestamps), false
	}
	var sq float64
	for _, iv := range intervals {
		diff := iv - mean
		sq += diff * diff
	}
	cv := math.Sqrt(sq/float64(len(intervals))) / mean
	return cv, len(bh.timestamps), cv < 0.22
}

func shannonEntropy(s string) float64 {
	if len(s) == 0 {
		return 0
	}
	freq := make(map[rune]float64)
	for _, r := range s {
		freq[r]++
	}
	var ent float64
	n := float64(len(s))
	for _, c := range freq {
		p := c / n
		ent -= p * math.Log2(p)
	}
	return ent
}

func isExternalIP(ipStr string) bool {
	ip := net.ParseIP(strings.TrimSpace(ipStr))
	if ip == nil {
		return false
	}
	if ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() || ip.IsUnspecified() {
		return false
	}
	return true
}

func appendUnique(slice []string, item string) []string {
	for _, v := range slice {
		if v == item {
			return slice
		}
	}
	return append(slice, item)
}

func hasTag(slice []string, item string) bool {
	for _, v := range slice {
		if v == item {
			return true
		}
	}
	return false
}

func fallbackStr(v, def string) string {
	if strings.TrimSpace(v) == "" {
		return def
	}
	return v
}

func truncateStr(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}

func elapsedMs(start time.Time) float64 {
	ms := float64(time.Since(start).Microseconds()) / 1000.0
	if ms < 0.1 {
		ms = 0.15
	}
	return math.Round(ms*100) / 100
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}

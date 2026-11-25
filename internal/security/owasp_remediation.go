package security

import (
	"fmt"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
	"gorm.io/gorm"

	"github.com/gubernator-org/gubernator/internal/audit"
	"github.com/gubernator-org/gubernator/internal/caddy"
	"github.com/gubernator-org/gubernator/internal/db"
	"github.com/gubernator-org/gubernator/internal/ebpf"
)

// OWASPRemediationResult captures the outcome of a 1-click OWASP control auto-remediation.
type OWASPRemediationResult struct {
	Success       bool         `json:"success"`
	ControlID     string       `json:"control_id"`
	ActionsTaken  []string     `json:"actions_taken"`
	Message       string       `json:"message"`
	BeforeScore   float64      `json:"before_score"`
	AfterScore    float64      `json:"after_score"`
	UpdatedReport OWASPSummary `json:"updated_report"`
}

// OWASPComposeHardenResult returns an automatically hardened docker-compose.yml and before/after scores.
type OWASPComposeHardenResult struct {
	Success        bool               `json:"success"`
	BeforeScore    float64            `json:"before_score"`
	AfterScore     float64            `json:"after_score"`
	ChangesApplied []string           `json:"changes_applied"`
	HardenedYAML   string             `json:"hardened_yaml"`
	AuditResult    ComposeOWASPResult `json:"audit_result"`
}

// RemediateOWASPControl executes a real, auditable cluster remediation for a specific OWASP control ID.
func RemediateOWASPControl(database *gorm.DB, controlID string, actor string) (*OWASPRemediationResult, error) {
	if database == nil {
		database = db.DB
	}
	if actor == "" {
		actor = "admin"
	}

	before := EvaluateOWASPCompliance(database)
	actions := make([]string, 0)

	switch strings.ToLower(strings.TrimSpace(controlID)) {
	case "owasp-a03":
		cfg, err := loadOrInitWAF(database)
		if err != nil {
			return nil, err
		}
		cfg.Enabled = true
		cfg.Mode = "enforce"
		if cfg.ParanoiaLevel < 2 {
			cfg.ParanoiaLevel = 2
		}
		cfg.BlockSQLi = true
		cfg.BlockXSS = true
		cfg.BlockRCE = true
		cfg.BlockLFI = true
		cfg.BlockScanners = true
		cfg.BlockXXE = true
		cfg.BlockNoSQLi = true
		if _, err := caddy.UpdateWAFConfig(cfg); err != nil {
			return nil, err
		}
		actions = append(actions, "Enabled Caddy Threat Shield WAF in 'enforce' mode (Paranoia L2) with OWASP CRS SQLi/XSS/RCE/LFI/XXE/NoSQLi rules and reloaded Caddyfile.")

	case "owasp-a05":
		cfg, err := loadOrInitWAF(database)
		if err != nil {
			return nil, err
		}
		cfg.Enabled = true
		cfg.InjectSecureHeaders = true
		cfg.EnforceHTTPMethods = true
		if cfg.CSPMode == "" || cfg.CSPMode == "off" {
			cfg.CSPMode = "balanced"
		}
		if _, err := caddy.UpdateWAFConfig(cfg); err != nil {
			return nil, err
		}
		actions = append(actions, "Enabled OWASP Secure Headers injection (HSTS, CSP Balanced, nosniff, X-Frame-Options, Referrer-Policy, Server strip) and CRS-911 HTTP method blocking on Caddy Ingress.")

	case "owasp-a07":
		secCfg := loadOrInitSecConfig(database)
		secCfg.MFAEnforced = true
		secCfg.MFAEnforcePrivileged = true
		if secCfg.MaxFailedLogins <= 0 || secCfg.MaxFailedLogins > 5 {
			secCfg.MaxFailedLogins = 5
		}
		if secCfg.LockoutDurationMinutes < 15 {
			secCfg.LockoutDurationMinutes = 15
		}
		secCfg.UpdatedAt = time.Now()
		if err := database.Save(&secCfg).Error; err != nil {
			return nil, err
		}
		actions = append(actions, "Enabled Mandatory TOTP MFA enforcement and 5-attempt / 15-minute brute-force account lockout in SecurityConfig.")

	case "owasp-a08":
		var pol db.SecurityPolicy
		if err := database.First(&pol, "id = ?", "default").Error; err != nil {
			pol = db.SecurityPolicy{ID: "default", Name: "Cluster Gatekeeper Policy"}
		}
		pol.EnforceSignatures = "enforce"
		pol.BlockCVESeverity = "critical"
		pol.UpdatedAt = time.Now()
		if err := database.Save(&pol).Error; err != nil {
			return nil, err
		}
		actions = append(actions, "Configured Security Gatekeeper to enforce Cosign signatures and block Critical CVEs prior to container deployment.")

	case "owasp-a09":
		secCfg := loadOrInitSecConfig(database)
		secCfg.SIEMEnabled = true
		if secCfg.SIEMHost == "" {
			secCfg.SIEMHost = "127.0.0.1"
		}
		if secCfg.SIEMPort <= 0 {
			secCfg.SIEMPort = 514
		}
		if secCfg.SIEMProtocol == "" {
			secCfg.SIEMProtocol = "UDP"
		}
		if secCfg.SIEMFormat == "" {
			secCfg.SIEMFormat = "RFC5424"
		}
		secCfg.UpdatedAt = time.Now()
		if err := database.Save(&secCfg).Error; err != nil {
			return nil, err
		}
		actions = append(actions, fmt.Sprintf("Enabled real-time SIEM audit log forwarding (%s %s:%d %s).", secCfg.SIEMProtocol, secCfg.SIEMHost, secCfg.SIEMPort, secCfg.SIEMFormat))

	case "owasp-a10":
		cfg, err := loadOrInitWAF(database)
		if err != nil {
			return nil, err
		}
		cfg.Enabled = true
		cfg.BlockSSRF = true
		if _, err := caddy.UpdateWAFConfig(cfg); err != nil {
			return nil, err
		}
		zt := ebpf.GetEngine().IDS.SetBaselineLocked(true, true)
		actions = append(actions, fmt.Sprintf("Enabled OWASP CRS-934 SSRF blocking in Caddy WAF and locked eBPF Zero-Trust micro-segmentation baseline (%d authorized edges).", zt.TotalRules))

	case "owasp-asvs-v2":
		secCfg := loadOrInitSecConfig(database)
		if secCfg.PasswordMinLength < 12 {
			secCfg.PasswordMinLength = 12
		}
		secCfg.PasswordRequireComplexity = true
		if secCfg.MaxFailedLogins <= 0 || secCfg.MaxFailedLogins > 5 {
			secCfg.MaxFailedLogins = 5
		}
		if secCfg.LockoutDurationMinutes < 15 {
			secCfg.LockoutDurationMinutes = 15
		}
		secCfg.UpdatedAt = time.Now()
		if err := database.Save(&secCfg).Error; err != nil {
			return nil, err
		}
		actions = append(actions, "Enforced OWASP ASVS V2.1 password policy (min 12 chars, complexity required, 5-attempt lockout).")

	case "owasp-asvs-v3":
		secCfg := loadOrInitSecConfig(database)
		secCfg.SessionTimeoutMinutes = 15
		secCfg.UpdatedAt = time.Now()
		if err := database.Save(&secCfg).Error; err != nil {
			return nil, err
		}
		actions = append(actions, "Configured OWASP ASVS V3.5 session inactivity timeout to 15 minutes (with immediate server-side JWT JTI revocation on logout).")

	case "owasp-llm01":
		cfg, err := loadOrInitWAF(database)
		if err != nil {
			return nil, err
		}
		cfg.Enabled = true
		cfg.LLMShieldEnabled = true
		if _, err := caddy.UpdateWAFConfig(cfg); err != nil {
			return nil, err
		}
		actions = append(actions, "Enabled OWASP LLM01 Prompt Injection & Jailbreak Shield on Caddy Ingress WAF.")

	case "owasp-api9":
		eng := ebpf.GetEngine()
		eng.Collector.CollectAll(eng.Probe, eng.IDS)
		actions = append(actions, "Executed fresh multi-node eBPF Attack Surface & Shadow Port reconciliation across all Centurion nodes.")

	default:
		return nil, fmt.Errorf("control '%s' requires manual remediation or is not auto-fixable", controlID)
	}

	after := EvaluateOWASPCompliance(database)
	TriggerComplianceAudit("OWASP_REMEDIATION_" + strings.ToUpper(controlID))

	if database != nil {
		_, _ = audit.RecordEvent(actor, "OWASP-REMEDIATION", "127.0.0.1", "OWASP_AUTO_REMEDIATE", "SUCCESS",
			fmt.Sprintf("Control=%s score=%.1f%%->%.1f%% actions=%s", controlID, before.OverallScore, after.OverallScore, strings.Join(actions, " | ")))
	}

	return &OWASPRemediationResult{
		Success:       true,
		ControlID:     controlID,
		ActionsTaken:  actions,
		Message:       fmt.Sprintf("Remediation applied for %s (OWASP score %.1f%% -> %.1f%%)", controlID, before.OverallScore, after.OverallScore),
		BeforeScore:   before.OverallScore,
		AfterScore:    after.OverallScore,
		UpdatedReport: after,
	}, nil
}

// RemediateAllSafeOWASP applies all safe, non-disruptive OWASP remediations in one click
// (skips mandatory MFA enforcement and strict Cosign signature blocking to avoid accidental lockout).
func RemediateAllSafeOWASP(database *gorm.DB, actor string) (*OWASPRemediationResult, error) {
	if database == nil {
		database = db.DB
	}
	if actor == "" {
		actor = "admin"
	}

	before := EvaluateOWASPCompliance(database)
	safeControls := []string{
		"owasp-a03",
		"owasp-a05",
		"owasp-a10",
		"owasp-asvs-v2",
		"owasp-asvs-v3",
		"owasp-llm01",
	}

	var allActions []string
	for _, cid := range safeControls {
		res, err := RemediateOWASPControl(database, cid, actor)
		if err == nil && res != nil {
			allActions = append(allActions, res.ActionsTaken...)
		}
	}

	// Also safely enable Critical CVE blocking (without locking out unsigned images yet)
	if database != nil {
		var pol db.SecurityPolicy
		if err := database.First(&pol, "id = ?", "default").Error; err != nil {
			pol = db.SecurityPolicy{ID: "default", Name: "Cluster Gatekeeper Policy", EnforceSignatures: "audit"}
		}
		if pol.BlockCVESeverity == "" || strings.EqualFold(pol.BlockCVESeverity, "none") {
			pol.BlockCVESeverity = "critical"
			pol.UpdatedAt = time.Now()
			if err := database.Save(&pol).Error; err == nil {
				allActions = append(allActions, "Enabled Security Gatekeeper Critical CVE blocking (keeping signatures in audit mode for safety).")
			}
		}
	}

	after := EvaluateOWASPCompliance(database)
	TriggerComplianceAudit("OWASP_REMEDIATE_ALL_SAFE")

	return &OWASPRemediationResult{
		Success:       true,
		ControlID:     "all-safe",
		ActionsTaken:  allActions,
		Message:       fmt.Sprintf("Applied %d safe OWASP remediations (score %.1f%% -> %.1f%%, Grade %s)", len(allActions), before.OverallScore, after.OverallScore, after.Grade),
		BeforeScore:   before.OverallScore,
		AfterScore:    after.OverallScore,
		UpdatedReport: after,
	}, nil
}

// HardenComposeOWASP automatically transforms a docker-compose.yml manifest to fix OWASP Docker Top 10 (D01-D10) issues.
func HardenComposeOWASP(rawCompose string) (*OWASPComposeHardenResult, error) {
	before := LintComposeOWASP(rawCompose)
	if !before.Valid {
		return nil, fmt.Errorf("cannot harden invalid YAML: %s", before.ParseError)
	}

	var doc map[string]interface{}
	if err := yaml.Unmarshal([]byte(rawCompose), &doc); err != nil {
		return nil, err
	}

	changes := make([]string, 0)
	servicesRaw, ok := doc["services"].(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("no 'services' block found in Compose file")
	}

	sensitivePorts := map[string]bool{
		"5432": true, "3306": true, "6379": true, "27017": true,
		"9200": true, "11434": true, "8888": true,
	}

	for svcName, svcObj := range servicesRaw {
		svc, ok := svcObj.(map[string]interface{})
		if !ok {
			continue
		}

		// D01: Remove privileged: true
		if priv, ok := svc["privileged"].(bool); ok && priv {
			delete(svc, "privileged")
			changes = append(changes, fmt.Sprintf("[%s] Removed `privileged: true` (D01)", svcName))
		}

		// D01: Ensure cap_drop: [ALL]
		hasCapDrop := false
		if caps, ok := svc["cap_drop"].([]interface{}); ok {
			for _, c := range caps {
				if strings.EqualFold(fmt.Sprint(c), "ALL") {
					hasCapDrop = true
				}
			}
		}
		if !hasCapDrop {
			svc["cap_drop"] = []string{"ALL"}
			changes = append(changes, fmt.Sprintf("[%s] Added `cap_drop: [ALL]` (D01)", svcName))
		}

		// D01: Ensure security_opt: [no-new-privileges:true]
		hasNNP := false
		var secOpts []interface{}
		if rawOpts, ok := svc["security_opt"].([]interface{}); ok {
			secOpts = rawOpts
			for _, o := range rawOpts {
				if strings.Contains(strings.ToLower(fmt.Sprint(o)), "no-new-privileges") {
					hasNNP = true
				}
			}
		}
		if !hasNNP {
			secOpts = append(secOpts, "no-new-privileges:true")
			svc["security_opt"] = secOpts
			changes = append(changes, fmt.Sprintf("[%s] Added `security_opt: no-new-privileges:true` (D01)", svcName))
		}

		// D03: Remove /var/run/docker.sock mounts
		if vols, ok := svc["volumes"].([]interface{}); ok {
			filtered := make([]interface{}, 0, len(vols))
			for _, v := range vols {
				if strings.Contains(fmt.Sprint(v), "/var/run/docker.sock") {
					changes = append(changes, fmt.Sprintf("[%s] Removed dangerous `/var/run/docker.sock` bind mount (D03)", svcName))
					continue
				}
				filtered = append(filtered, v)
			}
			if len(filtered) == 0 {
				delete(svc, "volumes")
			} else {
				svc["volumes"] = filtered
			}
		}

		// D04: Remove host namespaces
		for _, ns := range []string{"network_mode", "pid", "ipc"} {
			if val, ok := svc[ns].(string); ok && strings.EqualFold(strings.TrimSpace(val), "host") {
				delete(svc, ns)
				changes = append(changes, fmt.Sprintf("[%s] Removed `%s: host` (D04)", svcName, ns))
			}
		}

		// D05: Replace hardcoded plaintext secrets with ${VAR} references
		switch env := svc["environment"].(type) {
		case []interface{}:
			for i, item := range env {
				s := fmt.Sprint(item)
				if idx := strings.Index(s, "="); idx > 0 {
					k := strings.TrimSpace(s[:idx])
					v := strings.TrimSpace(s[idx+1:])
					if secretKeyRe.MatchString(k) && v != "" && !envVarRefRe.MatchString(v) {
						env[i] = fmt.Sprintf("%s=${%s}", k, k)
						changes = append(changes, fmt.Sprintf("[%s] Externalized plaintext secret `%s` to `${%s}` (D05)", svcName, k, k))
					}
				}
			}
			svc["environment"] = env
		case map[string]interface{}:
			for k, v := range env {
				vs := strings.TrimSpace(fmt.Sprint(v))
				if secretKeyRe.MatchString(k) && vs != "" && !envVarRefRe.MatchString(vs) {
					env[k] = fmt.Sprintf("${%s}", k)
					changes = append(changes, fmt.Sprintf("[%s] Externalized plaintext secret `%s` to `${%s}` (D05)", svcName, k, k))
				}
			}
			svc["environment"] = env
		}

		// D06: Ensure non-root user
		if _, hasUser := svc["user"]; !hasUser {
			svc["user"] = "10001:10001"
			changes = append(changes, fmt.Sprintf("[%s] Added non-root `user: \"10001:10001\"` (D06)", svcName))
		}

		// D07: Ensure deploy.resources.limits
		deployMap, _ := svc["deploy"].(map[string]interface{})
		if deployMap == nil {
			deployMap = make(map[string]interface{})
		}
		resMap, _ := deployMap["resources"].(map[string]interface{})
		if resMap == nil {
			resMap = make(map[string]interface{})
		}
		limMap, _ := resMap["limits"].(map[string]interface{})
		if len(limMap) == 0 {
			resMap["limits"] = map[string]interface{}{
				"cpus":   "1.0",
				"memory": "512M",
			}
			deployMap["resources"] = resMap
			svc["deploy"] = deployMap
			changes = append(changes, fmt.Sprintf("[%s] Added CPU/Memory resource limits (D07)", svcName))
		}

		// D08: Restrict sensitive DB/AI ports to 127.0.0.1
		if ports, ok := svc["ports"].([]interface{}); ok {
			for i, p := range ports {
				ps := strings.TrimSpace(fmt.Sprint(p))
				if strings.HasPrefix(ps, "127.0.0.1:") {
					continue
				}
				for sp := range sensitivePorts {
					if strings.Contains(ps, ":"+sp) || strings.HasPrefix(ps, sp+":") || ps == sp {
						if !strings.Contains(ps, ":") {
							ports[i] = fmt.Sprintf("127.0.0.1:%s:%s", ps, ps)
						} else {
							ports[i] = "127.0.0.1:" + ps
						}
						changes = append(changes, fmt.Sprintf("[%s] Restricted sensitive port `%s` to loopback `%v` (D08)", svcName, ps, ports[i]))
						break
					}
				}
			}
			svc["ports"] = ports
		}

		servicesRaw[svcName] = svc
	}

	outBytes, err := yaml.Marshal(doc)
	if err != nil {
		return nil, err
	}
	hardenedStr := string(outBytes)
	after := LintComposeOWASP(hardenedStr)

	return &OWASPComposeHardenResult{
		Success:        true,
		BeforeScore:    before.Score,
		AfterScore:     after.Score,
		ChangesApplied: changes,
		HardenedYAML:   hardenedStr,
		AuditResult:    after,
	}, nil
}

func loadOrInitWAF(database *gorm.DB) (db.ManagedWAFConfig, error) {
	if database == nil {
		return db.ManagedWAFConfig{}, fmt.Errorf("database not initialized")
	}
	db.DB = database
	cfg, err := caddy.GetWAFConfig()
	if err != nil {
		return db.ManagedWAFConfig{}, err
	}
	return *cfg, nil
}

func loadOrInitSecConfig(database *gorm.DB) db.SecurityConfig {
	var secCfg db.SecurityConfig
	if err := database.First(&secCfg, "id = ?", "default").Error; err != nil {
		secCfg = db.SecurityConfig{
			ID:                        "default",
			MaxFailedLogins:           5,
			LockoutDurationMinutes:    15,
			PasswordMinLength:         12,
			PasswordRequireComplexity: true,
			SessionTimeoutMinutes:     15,
		}
	}
	return secCfg
}

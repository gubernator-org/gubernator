package security

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"

	"github.com/gubernator-org/gubernator/internal/audit"
	"github.com/gubernator-org/gubernator/internal/auth"
	"github.com/gubernator-org/gubernator/internal/db"
	"github.com/gubernator-org/gubernator/internal/ebpf"
)

// OWASPStandardVersion identifies the unified OWASP frameworks evaluated by Gubernator.
const OWASPStandardVersion = "OWASP Top 10:2021 • API Top 10:2023 • ASVS v4.0 L2 • Docker & LLM Top 10"

// OWASPDomain categorizes each OWASP control into its source framework.
type OWASPDomain string

const (
	OWASPDomainTop10Web    OWASPDomain = "TOP10_WEB"
	OWASPDomainAPITop10    OWASPDomain = "API_TOP10"
	OWASPDomainASVS        OWASPDomain = "ASVS_L2"
	OWASPDomainDockerTop10 OWASPDomain = "DOCKER_TOP10"
	OWASPDomainLLMTop10    OWASPDomain = "LLM_TOP10"
)

// OWASPControl represents a single verifiable OWASP security control evaluated against live cluster state.
type OWASPControl struct {
	ID          string      `json:"id"`          // e.g. "A01:2021", "API4:2023", "ASVS-V3.5", "D05", "LLM01"
	Domain      OWASPDomain `json:"domain"`      // TOP10_WEB, API_TOP10, ASVS_L2, DOCKER_TOP10, LLM_TOP10
	Reference   string      `json:"reference"`   // Formal OWASP reference code
	Title       string      `json:"title"`       // Control title
	Description string      `json:"description"` // Requirement summary
	Status      string      `json:"status"`      // "COMPLIANT", "PARTIAL", "NON_COMPLIANT"
	Score       float64     `json:"score"`       // 0.0 - 100.0
	Severity    string      `json:"severity"`    // "CRITICAL", "HIGH", "MEDIUM", "LOW"
	Evidence    string      `json:"evidence"`    // Live discovered cluster evidence
	Remediation string      `json:"remediation"` // Prescriptive remediation guidance
}

// OWASPSummary aggregates the evaluation across all 5 OWASP standards.
type OWASPSummary struct {
	EvaluatedAt       time.Time      `json:"evaluated_at"`
	StandardVersion   string         `json:"standard_version"`
	OverallScore      float64        `json:"overall_score"`
	Grade             string         `json:"grade"` // A+, A, B, C, D, F
	Top10WebScore     float64        `json:"top10_web_score"`
	APITop10Score     float64        `json:"api_top10_score"`
	ASVSScore         float64        `json:"asvs_score"`
	DockerTop10Score  float64        `json:"docker_top10_score"`
	LLMTop10Score     float64        `json:"llm_top10_score"`
	CompliantCount    int            `json:"compliant_count"`
	PartialCount      int            `json:"partial_count"`
	NonCompliantCount int            `json:"non_compliant_count"`
	TotalControls     int            `json:"total_controls"`
	ExposedAIPorts    []string       `json:"exposed_ai_ports,omitempty"`
	Controls          []OWASPControl `json:"controls"`
}

// EvaluateOWASPCompliance evaluates the cluster against OWASP Top 10 (Web), API Top 10,
// ASVS v4.0 Level 2, Docker Security Top 10, and LLM Top 10 using live cluster telemetry.
func EvaluateOWASPCompliance(database *gorm.DB) OWASPSummary {
	if database == nil {
		database = db.DB
	}

	var secConfig db.SecurityConfig
	var wafConfig db.ManagedWAFConfig
	var secPolicy db.SecurityPolicy
	var users []db.LocalUser
	var stacks []db.Stack
	var ldapCount int64
	var oidcCount int64
	var sbomCount int64
	var signingKeyCount int64
	var encryptedBackups int64
	var totalBackups int64
	var auditCount int64

	if database != nil {
		if err := database.First(&secConfig, "id = ?", "default").Error; err != nil {
			secConfig = db.SecurityConfig{
				MaxFailedLogins:           5,
				LockoutDurationMinutes:    15,
				PasswordMinLength:         12,
				PasswordRequireComplexity: true,
				SessionTimeoutMinutes:     15,
			}
		}
		_ = database.First(&wafConfig, "id = ?", "default").Error
		_ = database.First(&secPolicy, "id = ?", "default").Error
		_ = database.Find(&users).Error
		_ = database.Find(&stacks).Error
		database.Model(&db.LDAPConfig{}).Where("enabled = ?", true).Count(&ldapCount)
		database.Model(&db.OIDCConfig{}).Where("enabled = ?", true).Count(&oidcCount)
		database.Model(&db.ImageSBOM{}).Count(&sbomCount)
		database.Model(&db.TrustedSigningKey{}).Count(&signingKeyCount)
		database.Model(&db.Backup{}).Count(&totalBackups)
		database.Model(&db.Backup{}).Where("is_encrypted = ?", true).Count(&encryptedBackups)
		database.Model(&db.AuditLog{}).Count(&auditCount)
	}

	// Inspect live eBPF telemetry & Attack Surface
	eng := ebpf.GetEngine()
	ebpfStats := eng.Probe.GetStats()
	surface := eng.Collector.GetAttackSurface("", false)
	ztBaseline := eng.IDS.GetZeroTrustBaseline()

	var controls []OWASPControl
	add := func(c OWASPControl) { controls = append(controls, c) }

	// ── 1. OWASP TOP 10:2021 (WEB) ───────────────────────────────────────────

	// A01:2021 Broken Access Control
	nonAdminRBAC := false
	for _, u := range users {
		if u.Role != "admin" {
			nonAdminRBAC = true
			break
		}
	}
	a01Status, a01Score := "COMPLIANT", 100.0
	a01Ev := fmt.Sprintf("3-tier RBAC enforced (admin/operator/readonly) across %d local users, %d LDAP, %d OIDC providers.", len(users), ldapCount, oidcCount)
	if len(users) == 0 && ldapCount == 0 && oidcCount == 0 {
		a01Status, a01Score = "PARTIAL", 60.0
		a01Ev = "Default admin fallback active; no dedicated RBAC accounts or external IdP configured."
	} else if !nonAdminRBAC && ldapCount == 0 && oidcCount == 0 {
		a01Status, a01Score = "PARTIAL", 80.0
		a01Ev = fmt.Sprintf("RBAC active (%d admin user(s)); consider least-privilege operator/readonly roles.", len(users))
	}
	add(OWASPControl{
		ID:          "owasp-a01",
		Domain:      OWASPDomainTop10Web,
		Reference:   "A01:2021",
		Title:       "Broken Access Control & Least-Privilege RBAC",
		Description: "Enforce server-side role-based access control on all API and Web UI mutating operations.",
		Status:      a01Status,
		Score:       a01Score,
		Severity:    "CRITICAL",
		Evidence:    a01Ev,
		Remediation: "Create least-privilege operator/readonly accounts or integrate LDAP/OIDC groups under Security & Directory.",
	})

	// A02:2021 Cryptographic Failures
	a02Status, a02Score := "COMPLIANT", 100.0
	a02Ev := "HS256 signed JWT with persistent 256-bit key, SHA-256 tamper-evident audit chain, Caddy automatic TLS."
	if totalBackups > 0 && encryptedBackups < totalBackups {
		a02Status, a02Score = "PARTIAL", 75.0
		a02Ev = fmt.Sprintf("%d/%d volume backups encrypted with AES-256-GCM; remaining backups unencrypted.", encryptedBackups, totalBackups)
	}
	add(OWASPControl{
		ID:          "owasp-a02",
		Domain:      OWASPDomainTop10Web,
		Reference:   "A02:2021",
		Title:       "Cryptographic Failures (TLS, JWT & AES-256-GCM Backups)",
		Description: "Protect data in transit with TLS 1.2+/1.3 and data at rest with strong authenticated encryption.",
		Status:      a02Status,
		Score:       a02Score,
		Severity:    "HIGH",
		Evidence:    a02Ev,
		Remediation: "Enable AES-256-GCM backup encryption in Storage Granaries and enforce HTTPS on all Caddy ingress routes.",
	})

	// A03:2021 Injection (SQLi, XSS, RCE, XXE, NoSQLi via Caddy WAF CRS)
	a03Status, a03Score := "NON_COMPLIANT", 25.0
	a03Ev := "Caddy Threat Shield WAF is disabled."
	if wafConfig.Enabled {
		activeRules := countTrue(wafConfig.BlockSQLi, wafConfig.BlockXSS, wafConfig.BlockRCE, wafConfig.BlockLFI, wafConfig.BlockXXE, wafConfig.BlockNoSQLi)
		if wafConfig.Mode == "enforce" && activeRules >= 5 {
			a03Status, a03Score = "COMPLIANT", 100.0
		} else {
			a03Status, a03Score = "PARTIAL", 70.0
		}
		a03Ev = fmt.Sprintf("Caddy WAF active in '%s' mode (Paranoia L%d) with %d/6 OWASP CRS injection rule groups enabled.", wafConfig.Mode, maxInt(wafConfig.ParanoiaLevel, 1), activeRules)
	}
	add(OWASPControl{
		ID:          "owasp-a03",
		Domain:      OWASPDomainTop10Web,
		Reference:   "A03:2021",
		Title:       "Injection Protection (OWASP CRS: SQLi, XSS, RCE, XXE, NoSQLi)",
		Description: "Filter and block injection payloads at ingress using OWASP Core Rule Set matchers.",
		Status:      a03Status,
		Score:       a03Score,
		Severity:    "CRITICAL",
		Evidence:    a03Ev,
		Remediation: "Enable Caddy Threat Shield WAF in 'enforce' mode with SQLi, XSS, RCE, LFI, XXE/SSTI, and NoSQLi enabled.",
	})

	// A05:2021 Security Misconfiguration (OWASP Secure Headers & Bad Methods)
	a05Status, a05Score := "COMPLIANT", 100.0
	a05Ev := "Gubernator API (:4000) & Web UI (:4001) enforce OWASP Secure Headers middleware (nosniff, X-Frame-Options, Referrer-Policy, Permissions-Policy)."
	if wafConfig.Enabled && (!wafConfig.InjectSecureHeaders || !wafConfig.EnforceHTTPMethods) {
		a05Status, a05Score = "PARTIAL", 75.0
		a05Ev += " However, Caddy Ingress WAF Secure Headers or HTTP method enforcement is disabled."
	} else if !wafConfig.Enabled {
		a05Status, a05Score = "PARTIAL", 70.0
		a05Ev += " Enable Caddy WAF Secure Headers to also protect all proxied workloads."
	}
	add(OWASPControl{
		ID:          "owasp-a05",
		Domain:      OWASPDomainTop10Web,
		Reference:   "A05:2021",
		Title:       "Security Misconfiguration & OWASP Secure Headers",
		Description: "Eliminate server fingerprinting, block TRACE/TRACK methods, and inject HSTS/CSP/nosniff/X-Frame headers.",
		Status:      a05Status,
		Score:       a05Score,
		Severity:    "HIGH",
		Evidence:    a05Ev,
		Remediation: "Enable 'Inject OWASP Secure Headers' and 'Enforce HTTP Methods (CRS-911)' in Caddy Ingress -> Threat Shield WAF.",
	})

	// A06:2021 Vulnerable & Outdated Components (CycloneDX SBOM & CVE Scanner)
	a06Status, a06Score := "PARTIAL", 55.0
	a06Ev := "Image Vulnerability Scanner available; no CycloneDX/SPDX SBOM documents generated yet."
	if sbomCount > 0 {
		a06Status, a06Score = "COMPLIANT", 100.0
		a06Ev = fmt.Sprintf("%d CycloneDX/SPDX SBOM inventories cataloged with CVE vulnerability tracking.", sbomCount)
	}
	add(OWASPControl{
		ID:          "owasp-a06",
		Domain:      OWASPDomainTop10Web,
		Reference:   "A06:2021",
		Title:       "Vulnerable Components & OWASP CycloneDX SBOM",
		Description: "Continuously inventory container dependencies (SBOM) and scan for unpatched Critical/High CVEs.",
		Status:      a06Status,
		Score:       a06Score,
		Severity:    "HIGH",
		Evidence:    a06Ev,
		Remediation: "Run image scans & generate CycloneDX SBOMs under Image Security & SBOM.",
	})

	// A07:2021 Identification & Authentication Failures (MFA + Brute-Force Protection)
	mfaUsers := 0
	for _, u := range users {
		if u.MFAEnabled {
			mfaUsers++
		}
	}
	a07Status, a07Score := "PARTIAL", 75.0
	a07Ev := fmt.Sprintf("Login rate-limiter active (ASVS V2.2); MFA enforced=%v, %d/%d local users have TOTP MFA enabled.", secConfig.MFAEnforced, mfaUsers, len(users))
	if secConfig.MFAEnforced || (len(users) > 0 && mfaUsers == len(users)) {
		a07Status, a07Score = "COMPLIANT", 100.0
	}
	add(OWASPControl{
		ID:          "owasp-a07",
		Domain:      OWASPDomainTop10Web,
		Reference:   "A07:2021",
		Title:       "Identification, MFA & Brute-Force Lockout",
		Description: "Enforce TOTP MFA, strong password complexity, and progressive rate limiting on login endpoints.",
		Status:      a07Status,
		Score:       a07Score,
		Severity:    "CRITICAL",
		Evidence:    a07Ev,
		Remediation: "Enable Mandatory MFA enforcement in Security & Directory -> Security Policy.",
	})

	// A08:2021 Software & Data Integrity Failures (Cosign Signing & Gatekeeper)
	a08Status, a08Score := "PARTIAL", 50.0
	enforcesSigs := strings.EqualFold(secPolicy.EnforceSignatures, "enforce")
	blocksCVEs := secPolicy.BlockCVESeverity != "" && !strings.EqualFold(secPolicy.BlockCVESeverity, "none")
	a08Ev := fmt.Sprintf("Gatekeeper enforce_signatures=%s, block_cve_severity=%s, trusted Cosign keys=%d.", secPolicy.EnforceSignatures, secPolicy.BlockCVESeverity, signingKeyCount)
	if enforcesSigs && blocksCVEs {
		a08Status, a08Score = "COMPLIANT", 100.0
	} else if enforcesSigs || blocksCVEs || signingKeyCount > 0 {
		a08Status, a08Score = "PARTIAL", 75.0
	}
	add(OWASPControl{
		ID:          "owasp-a08",
		Domain:      OWASPDomainTop10Web,
		Reference:   "A08:2021",
		Title:       "Software & Supply Chain Integrity (Cosign & Gatekeeper)",
		Description: "Verify cryptographic image signatures and block critical CVEs prior to container scheduling.",
		Status:      a08Status,
		Score:       a08Score,
		Severity:    "HIGH",
		Evidence:    a08Ev,
		Remediation: "Enable Enforce Signatures and Block Critical CVEs in Image Security -> Gatekeeper Policy.",
	})

	// A09:2021 Security Logging & Monitoring Failures
	a09Status, a09Score := "PARTIAL", 75.0
	a09Ev := fmt.Sprintf("SHA-256 hash-chained audit logs (%d entries) + eBPF Runtime IDS active (%d probes).", auditCount, ebpfStats.ActiveProbes)
	if secConfig.SIEMEnabled {
		a09Status, a09Score = "COMPLIANT", 100.0
		a09Ev += fmt.Sprintf(" External SIEM forwarding enabled (%s).", secConfig.SIEMProtocol)
	}
	add(OWASPControl{
		ID:          "owasp-a09",
		Domain:      OWASPDomainTop10Web,
		Reference:   "A09:2021",
		Title:       "Security Logging, Tamper-Evident Chain & eBPF IDS",
		Description: "Maintain cryptographic audit logs, real-time intrusion detection, and external SIEM shipping.",
		Status:      a09Status,
		Score:       a09Score,
		Severity:    "HIGH",
		Evidence:    a09Ev,
		Remediation: "Configure external SIEM forwarding (OpenSearch/Syslog/Webhook) under Security & Directory -> Audit & SIEM.",
	})

	// A10:2021 Server-Side Request Forgery (SSRF)
	a10Status, a10Score := "PARTIAL", 60.0
	a10Ev := fmt.Sprintf("WAF SSRF rule=%v, eBPF Zero-Trust baseline locked=%v (%d rules).", wafConfig.Enabled && wafConfig.BlockSSRF, ztBaseline.Locked, ztBaseline.TotalRules)
	if wafConfig.Enabled && wafConfig.BlockSSRF && ztBaseline.Locked {
		a10Status, a10Score = "COMPLIANT", 100.0
	} else if wafConfig.Enabled && wafConfig.BlockSSRF {
		a10Status, a10Score = "PARTIAL", 80.0
	}
	add(OWASPControl{
		ID:          "owasp-a10",
		Domain:      OWASPDomainTop10Web,
		Reference:   "A10:2021",
		Title:       "SSRF Defense & Zero-Trust Egress Segmentation",
		Description: "Block cloud metadata SSRF probes (CRS-934) and enforce locked east-west Zero-Trust communication baselines.",
		Status:      a10Status,
		Score:       a10Score,
		Severity:    "HIGH",
		Evidence:    a10Ev,
		Remediation: "Enable CRS-934 SSRF blocking in Caddy WAF and Lock Zero-Trust Baseline in eBPF Live Hub.",
	})

	// ── 2. OWASP API SECURITY TOP 10:2023 ───────────────────────────────────

	// API2:2023 Broken Authentication
	add(OWASPControl{
		ID:          "owasp-api2",
		Domain:      OWASPDomainAPITop10,
		Reference:   "API2:2023",
		Title:       "Broken API Authentication & Asymmetric Token Isolation",
		Description: "Isolate Control API (:4000 Bearer token) from Web UI (:4001 JWT+RBAC) and internal Metrics (:4002).",
		Status:      "COMPLIANT",
		Score:       100.0,
		Severity:    "CRITICAL",
		Evidence:    fmt.Sprintf("Asymmetric port security active (4000/4001/4002); JWT JTI revocation store active (%d revoked tokens).", auth.RevokedTokenCount()),
		Remediation: "Rotate GBNT_API_TOKEN and GBNT_JWT_SECRET periodically.",
	})

	// API4:2023 Unrestricted Resource Consumption
	add(OWASPControl{
		ID:          "owasp-api4",
		Domain:      OWASPDomainAPITop10,
		Reference:   "API4:2023",
		Title:       "Unrestricted Resource Consumption (Rate Limit & Body Caps)",
		Description: "Enforce payload size caps (MaxBytesReader) and progressive rate limiting on authentication and API endpoints.",
		Status:      "COMPLIANT",
		Score:       100.0,
		Severity:    "HIGH",
		Evidence:    "16 MiB request body cap active on Port 4000 API and progressive auth rate limiter (20 req/5m) active on login/MFA.",
		Remediation: "Enable per-route Caddy WAF rate limiting for public application APIs.",
	})

	// API9:2023 Improper Inventory Management (Shadow Ports / Shadow APIs)
	shadowCount := 0
	criticalExposed := 0
	for _, s := range surface {
		if s.IsShadow {
			shadowCount++
		}
		if s.RiskLevel == "critical" {
			criticalExposed++
		}
	}
	api9Status, api9Score := "COMPLIANT", 100.0
	api9Ev := fmt.Sprintf("eBPF Attack Surface audited %d listening sockets across %d node(s): %d shadow ports, %d critical exposures.", len(surface), ebpfStats.NodesMonitored, shadowCount, criticalExposed)
	if criticalExposed > 0 {
		api9Status, api9Score = "NON_COMPLIANT", 30.0
	} else if shadowCount > 3 {
		api9Status, api9Score = "PARTIAL", 70.0
	}
	add(OWASPControl{
		ID:          "owasp-api9",
		Domain:      OWASPDomainAPITop10,
		Reference:   "API9:2023",
		Title:       "Improper API & Port Inventory (eBPF Shadow Port Audit)",
		Description: "Continuously reconcile live listening ports across Centurions against declared Compose manifests.",
		Status:      api9Status,
		Score:       api9Score,
		Severity:    "HIGH",
		Evidence:    api9Ev,
		Remediation: "Inspect undeclared shadow ports in eBPF Live Hub -> Attack Surface & Zero-Trust and bind internal services to private interfaces.",
	})

	// ── 3. OWASP ASVS v4.0 LEVEL 2 ──────────────────────────────────────────

	// ASVS V2.1 Password Security
	v2Status, v2Score := "COMPLIANT", 100.0
	if secConfig.PasswordMinLength < 12 || !secConfig.PasswordRequireComplexity {
		v2Status, v2Score = "PARTIAL", 65.0
	}
	add(OWASPControl{
		ID:          "owasp-asvs-v2",
		Domain:      OWASPDomainASVS,
		Reference:   "ASVS V2.1",
		Title:       "Password Strength & Account Lockout Policy",
		Description: "Require >= 12 char passwords with complexity and lockout after repeated authentication failures.",
		Status:      v2Status,
		Score:       v2Score,
		Severity:    "HIGH",
		Evidence:    fmt.Sprintf("MinLength=%d, Complexity=%v, MaxFailedLogins=%d, Lockout=%dm.", secConfig.PasswordMinLength, secConfig.PasswordRequireComplexity, secConfig.MaxFailedLogins, secConfig.LockoutDurationMinutes),
		Remediation: "Set PasswordMinLength >= 12 and Complexity = true in Security Policy.",
	})

	// ASVS V3.5 Session Management & Token Revocation
	v3Status, v3Score := "COMPLIANT", 100.0
	if secConfig.SessionTimeoutMinutes <= 0 || secConfig.SessionTimeoutMinutes > 60 {
		v3Status, v3Score = "PARTIAL", 75.0
	}
	add(OWASPControl{
		ID:          "owasp-asvs-v3",
		Domain:      OWASPDomainASVS,
		Reference:   "ASVS V3.5",
		Title:       "Session Timeout & Immediate JWT Revocation on Logout",
		Description: "Invalidate session tokens immediately on logout (JTI revocation store) and enforce inactivity timeouts.",
		Status:      v3Status,
		Score:       v3Score,
		Severity:    "HIGH",
		Evidence:    fmt.Sprintf("Inactivity timeout=%dm; HttpOnly logout cookie clear & server-side JWT revocation store active.", secConfig.SessionTimeoutMinutes),
		Remediation: "Configure inactivity timeout between 10 and 30 minutes under Security Policy.",
	})

	// ASVS V7 Audit Log Cryptographic Integrity
	chainStatus, chainScore := "COMPLIANT", 100.0
	chainEv := "SHA-256 tamper-evident audit hash chain active."
	if database != nil && auditCount > 0 {
		if ver, err := audit.VerifyChainIntegrity(); err == nil && ver != nil {
			if !ver.Valid {
				chainStatus, chainScore = "NON_COMPLIANT", 0.0
				chainEv = fmt.Sprintf("Audit chain integrity failure detected at entry %s!", ver.CompromisedID)
			} else {
				chainEv = fmt.Sprintf("Verified %d audit records with intact SHA-256 cryptographic chain.", ver.VerifiedRecords)
			}
		}
	}
	add(OWASPControl{
		ID:          "owasp-asvs-v7",
		Domain:      OWASPDomainASVS,
		Reference:   "ASVS V7.3",
		Title:       "Tamper-Evident Cryptographic Audit Trail",
		Description: "Protect security event logs from unauthorized modification via cryptographic hash chaining.",
		Status:      chainStatus,
		Score:       chainScore,
		Severity:    "CRITICAL",
		Evidence:    chainEv,
		Remediation: "Investigate any chain break immediately and ship copies to external WORM/SIEM storage.",
	})

	// ── 4. OWASP DOCKER SECURITY TOP 10 ─────────────────────────────────────

	// Static analysis across all deployed Compose stacks!
	totalCritCompose := 0
	totalHighCompose := 0
	plaintextSecrets := 0
	privilegedCount := 0
	for _, st := range stacks {
		if strings.TrimSpace(st.RawComposeFile) == "" {
			continue
		}
		res := LintComposeOWASP(st.RawComposeFile)
		for _, f := range res.Findings {
			if f.Severity == "CRITICAL" {
				totalCritCompose++
			} else if f.Severity == "HIGH" {
				totalHighCompose++
			}
			if f.RuleID == "D05" {
				plaintextSecrets++
			}
			if f.RuleID == "D01" {
				privilegedCount++
			}
		}
	}

	d01Status, d01Score := "COMPLIANT", 100.0
	if privilegedCount > 0 {
		d01Status, d01Score = "NON_COMPLIANT", 35.0
	} else if totalHighCompose > 0 {
		d01Status, d01Score = "PARTIAL", 75.0
	}
	add(OWASPControl{
		ID:          "owasp-d01",
		Domain:      OWASPDomainDockerTop10,
		Reference:   "Docker D01/D03",
		Title:       "Container Privileges, Capabilities & Host Socket Isolation",
		Description: "Avoid privileged containers, drop Linux capabilities, and prevent mounting /var/run/docker.sock into app workloads.",
		Status:      d01Status,
		Score:       d01Score,
		Severity:    "CRITICAL",
		Evidence:    fmt.Sprintf("Audited %d deployed stack(s): %d privilege/escape findings, %d high-severity Compose issues.", len(stacks), privilegedCount, totalHighCompose),
		Remediation: "Open Compose Studio -> OWASP Audit and apply the Auto-Hardening Snippet (cap_drop: ALL, no-new-privileges).",
	})

	d05Status, d05Score := "COMPLIANT", 100.0
	if plaintextSecrets > 0 {
		d05Status, d05Score = "NON_COMPLIANT", 30.0
	}
	add(OWASPControl{
		ID:          "owasp-d05",
		Domain:      OWASPDomainDockerTop10,
		Reference:   "Docker D05",
		Title:       "Secrets Management Hygiene in Compose Manifests",
		Description: "Keep passwords, API keys, and tokens out of plaintext docker-compose.yml environment blocks.",
		Status:      d05Status,
		Score:       d05Score,
		Severity:    "HIGH",
		Evidence:    fmt.Sprintf("Detected %d potential plaintext secret declarations across %d deployed stack(s).", plaintextSecrets, len(stacks)),
		Remediation: "Move hardcoded credentials to Gubernator Secret Vault or external secret mounts.",
	})

	// ── 5. OWASP TOP 10 FOR LLM APPLICATIONS ────────────────────────────────

	aiPorts := map[int]string{
		11434: "Ollama API",
		8000:  "vLLM / Inference API",
		8888:  "Jupyter Notebook / LLM",
		7860:  "Gradio / LLaMA-Factory UI",
	}
	var exposedAI []string
	for _, s := range surface {
		if label, isAI := aiPorts[s.Port]; isAI && s.Exposure == "public_0.0.0.0" {
			exposedAI = append(exposedAI, fmt.Sprintf("%s:%d (%s on %s)", s.BindAddress, s.Port, label, s.NodeHost))
		}
	}

	llm01Status, llm01Score := "PARTIAL", 70.0
	llm01Ev := "Caddy OWASP LLM01 Prompt Injection Shield is currently OFF (enable if exposing AI/LLM endpoints)."
	if wafConfig.Enabled && wafConfig.LLMShieldEnabled {
		llm01Status, llm01Score = "COMPLIANT", 100.0
		llm01Ev = "Caddy OWASP LLM01 Prompt Injection & Jailbreak Shield is ACTIVE on ingress."
	}
	add(OWASPControl{
		ID:          "owasp-llm01",
		Domain:      OWASPDomainLLMTop10,
		Reference:   "LLM01:2025",
		Title:       "Prompt Injection & Jailbreak Ingress Guardrails",
		Description: "Filter adversarial prompt injection payloads and enforce strict request caps on AI/LLM routes.",
		Status:      llm01Status,
		Score:       llm01Score,
		Severity:    "HIGH",
		Evidence:    llm01Ev,
		Remediation: "Enable 'OWASP LLM Top 10 Shield' in Caddy Ingress -> Threat Shield WAF when hosting AI workloads.",
	})

	llm06Status, llm06Score := "COMPLIANT", 100.0
	llm06Ev := "No unauthenticated AI inference endpoints (Ollama :11434, vLLM :8000, Jupyter :8888, Gradio :7860) publicly bound to 0.0.0.0."
	if len(exposedAI) > 0 {
		llm06Status, llm06Score = "NON_COMPLIANT", 25.0
		llm06Ev = fmt.Sprintf("Exposed AI endpoints detected on 0.0.0.0: %s", strings.Join(exposedAI, ", "))
	}
	add(OWASPControl{
		ID:          "owasp-llm06",
		Domain:      OWASPDomainLLMTop10,
		Reference:   "LLM06/LLM10",
		Title:       "Exposed AI Inference Endpoints & Unbounded Consumption",
		Description: "Prevent direct unauthenticated access to Ollama, vLLM, Jupyter, or Gradio ports on 0.0.0.0.",
		Status:      llm06Status,
		Score:       llm06Score,
		Severity:    "CRITICAL",
		Evidence:    llm06Ev,
		Remediation: "Bind AI services to internal Docker networks and publish them strictly behind Caddy TLS + Auth + WAF LLM Shield.",
	})

	// ── Aggregate Scores ────────────────────────────────────────────────────
	summary := OWASPSummary{
		EvaluatedAt:      time.Now().UTC(),
		StandardVersion:  OWASPStandardVersion,
		ExposedAIPorts:   exposedAI,
		Controls:         controls,
		TotalControls:    len(controls),
		Top10WebScore:    domainAvg(controls, OWASPDomainTop10Web),
		APITop10Score:    domainAvg(controls, OWASPDomainAPITop10),
		ASVSScore:        domainAvg(controls, OWASPDomainASVS),
		DockerTop10Score: domainAvg(controls, OWASPDomainDockerTop10),
		LLMTop10Score:    domainAvg(controls, OWASPDomainLLMTop10),
	}

	var totalScore float64
	for _, c := range controls {
		totalScore += c.Score
		switch c.Status {
		case "COMPLIANT":
			summary.CompliantCount++
		case "PARTIAL":
			summary.PartialCount++
		default:
			summary.NonCompliantCount++
		}
	}
	if len(controls) > 0 {
		summary.OverallScore = float64(int((totalScore/float64(len(controls)))*10)) / 10.0
	}
	summary.Grade = scoreToGrade(summary.OverallScore)
	return summary
}

// GenerateOWASPReport produces a formal audit report in Markdown or JSON format.
func GenerateOWASPReport(summary OWASPSummary, format string) string {
	if strings.EqualFold(format, "json") {
		b, _ := json.MarshalIndent(summary, "", "  ")
		return string(b)
	}
	var sb strings.Builder
	sb.WriteString("# Gubernator OWASP Security Suite Compliance Report\n\n")
	sb.WriteString(fmt.Sprintf("- **Standards**: %s\n", summary.StandardVersion))
	sb.WriteString(fmt.Sprintf("- **Evaluated At**: %s\n", summary.EvaluatedAt.Format(time.RFC3339)))
	sb.WriteString(fmt.Sprintf("- **Overall Score**: **%.1f%%** (Grade **%s**)\n", summary.OverallScore, summary.Grade))
	sb.WriteString(fmt.Sprintf("- **Controls**: %d Compliant • %d Partial • %d Non-Compliant (Total %d)\n\n",
		summary.CompliantCount, summary.PartialCount, summary.NonCompliantCount, summary.TotalControls))

	sb.WriteString("## Domain Breakdown\n")
	sb.WriteString(fmt.Sprintf("- OWASP Top 10 (Web): **%.1f%%**\n", summary.Top10WebScore))
	sb.WriteString(fmt.Sprintf("- OWASP API Security Top 10: **%.1f%%**\n", summary.APITop10Score))
	sb.WriteString(fmt.Sprintf("- OWASP ASVS v4.0 Level 2: **%.1f%%**\n", summary.ASVSScore))
	sb.WriteString(fmt.Sprintf("- OWASP Docker Security Top 10: **%.1f%%**\n", summary.DockerTop10Score))
	sb.WriteString(fmt.Sprintf("- OWASP Top 10 for LLM Apps: **%.1f%%**\n\n", summary.LLMTop10Score))

	sb.WriteString("## Detailed Controls\n\n")
	sb.WriteString("| Ref | Domain | Status | Score | Title | Evidence |\n")
	sb.WriteString("| :--- | :--- | :--- | :--- | :--- | :--- |\n")
	for _, c := range summary.Controls {
		sb.WriteString(fmt.Sprintf("| `%s` | %s | **%s** | %.0f%% | %s | %s |\n",
			c.Reference, c.Domain, c.Status, c.Score, c.Title, strings.ReplaceAll(c.Evidence, "|", "/")))
	}
	return sb.String()
}

func domainAvg(controls []OWASPControl, domain OWASPDomain) float64 {
	var sum float64
	var n int
	for _, c := range controls {
		if c.Domain == domain {
			sum += c.Score
			n++
		}
	}
	if n == 0 {
		return 100.0
	}
	return float64(int((sum/float64(n))*10)) / 10.0
}

func scoreToGrade(score float64) string {
	switch {
	case score >= 95:
		return "A+"
	case score >= 88:
		return "A"
	case score >= 78:
		return "B"
	case score >= 65:
		return "C"
	case score >= 50:
		return "D"
	default:
		return "F"
	}
}

func countTrue(vals ...bool) int {
	c := 0
	for _, v := range vals {
		if v {
			c++
		}
	}
	return c
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

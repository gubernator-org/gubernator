package security

import (
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os/exec"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/gubernator-org/gubernator/internal/audit"
	"github.com/gubernator-org/gubernator/internal/db"
)

// OWASPDASTRequest configures a controlled active ethical DAST scan against a target URL.
type OWASPDASTRequest struct {
	TargetURL  string `json:"target_url" binding:"required"`
	ProbeWAF   bool   `json:"probe_waf"`   // Also run benign SQLi/XSS/LFI/SSRF WAF verification probes
	IncludeZAP bool   `json:"include_zap"` // Optional: launch ephemeral OWASP ZAP Baseline container if Docker allows
}

// OWASPDASTFinding represents an individual WSTG / OWASP Top 10 finding discovered during a DAST scan.
type OWASPDASTFinding struct {
	WSTGCode    string `json:"wstg_code"` // e.g. "WSTG-CONF-07", "WSTG-CRYP-01", "WSTG-SESS-02"
	OWASPRef    string `json:"owasp_ref"` // e.g. "A05:2021", "A02:2021"
	Severity    string `json:"severity"`  // "CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO"
	Status      string `json:"status"`    // "PASS", "FAIL", "WARN"
	Title       string `json:"title"`
	Evidence    string `json:"evidence"`
	Remediation string `json:"remediation"`
}

// OWASPDASTResult stores the complete scorecard and findings of an OWASP WSTG DAST scan.
type OWASPDASTResult struct {
	ID              string             `json:"id"`
	TargetURL       string             `json:"target_url"`
	ScannedAt       time.Time          `json:"scanned_at"`
	DurationMs      int64              `json:"duration_ms"`
	ScannerEngine   string             `json:"scanner_engine"` // "gubernator-wstg-native" or "gubernator-wstg+zap"
	HTTPStatus      int                `json:"http_status"`
	TLSVersion      string             `json:"tls_version,omitempty"`
	Score           float64            `json:"score"`
	Grade           string             `json:"grade"` // A+, A, B, C, D, F
	PassedChecks    int                `json:"passed_checks"`
	FailedChecks    int                `json:"failed_checks"`
	WarningChecks   int                `json:"warning_checks"`
	HeadersPresent  map[string]string  `json:"headers_present,omitempty"`
	WAFBlockedCount int                `json:"waf_blocked_count"`
	WAFProbesRun    int                `json:"waf_probes_run"`
	Findings        []OWASPDASTFinding `json:"findings"`
	ZAPOutput       string             `json:"zap_output,omitempty"`
	Error           string             `json:"error,omitempty"`
}

var (
	dastMu      sync.RWMutex
	dastHistory = make([]OWASPDASTResult, 0, 30)
)

// GetOWASPDASTHistory returns recent DAST scan reports (newest first).
func GetOWASPDASTHistory() []OWASPDASTResult {
	dastMu.RLock()
	defer dastMu.RUnlock()
	out := make([]OWASPDASTResult, len(dastHistory))
	copy(out, dastHistory)
	return out
}

// RunOWASPDASTScan executes a non-destructive OWASP WSTG security audit against a target HTTP/HTTPS URL.
func RunOWASPDASTScan(req OWASPDASTRequest, actor string) (*OWASPDASTResult, error) {
	rawURL := strings.TrimSpace(req.TargetURL)
	if rawURL == "" {
		return nil, fmt.Errorf("target_url is required")
	}
	if !strings.HasPrefix(rawURL, "http://") && !strings.HasPrefix(rawURL, "https://") {
		rawURL = "http://" + rawURL
	}
	parsed, err := url.Parse(rawURL)
	if err != nil || parsed.Host == "" {
		return nil, fmt.Errorf("invalid target_url: %s", rawURL)
	}

	start := time.Now()
	result := OWASPDASTResult{
		ID:             "dast-" + uuid.New().String()[:8],
		TargetURL:      parsed.String(),
		ScannedAt:      start.UTC(),
		ScannerEngine:  "gubernator-wstg-native",
		HeadersPresent: make(map[string]string),
		Findings:       make([]OWASPDASTFinding, 0, 16),
	}

	client := &http.Client{
		Timeout: 6 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true}, // intentional for self-signed cluster certs inspection
		},
		CheckRedirect: func(r *http.Request, via []*http.Request) error {
			if len(via) >= 3 {
				return http.ErrUseLastResponse
			}
			return nil
		},
	}

	// 1. Primary GET request with Origin header to simultaneously inspect TLS, Headers, Cookies, and CORS
	httpReq, err := http.NewRequest(http.MethodGet, parsed.String(), nil)
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("User-Agent", "Gubernator-OWASP-WSTG-Scanner/4.3")
	httpReq.Header.Set("Origin", "https://evil-owasp-probe.invalid")

	resp, err := client.Do(httpReq)
	if err != nil {
		result.Error = err.Error()
		result.Score = 0
		result.Grade = "F"
		result.DurationMs = time.Since(start).Milliseconds()
		storeDASTResult(result)
		return &result, nil
	}
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 64*1024))
	_ = resp.Body.Close()

	result.HTTPStatus = resp.StatusCode
	penalty := 0.0
	record := func(f OWASPDASTFinding, pts float64) {
		result.Findings = append(result.Findings, f)
		switch f.Status {
		case "PASS":
			result.PassedChecks++
		case "WARN":
			result.WarningChecks++
			penalty += pts
		default:
			result.FailedChecks++
			penalty += pts
		}
	}

	// 2. WSTG-CRYP-01: Transport Layer Security
	if parsed.Scheme == "https" && resp.TLS != nil {
		tlsVer := tlsVersionString(resp.TLS.Version)
		result.TLSVersion = tlsVer
		if resp.TLS.Version >= tls.VersionTLS12 {
			record(OWASPDASTFinding{
				WSTGCode:    "WSTG-CRYP-01",
				OWASPRef:    "A02:2021",
				Severity:    "HIGH",
				Status:      "PASS",
				Title:       "Modern TLS Protocol Enforced",
				Evidence:    fmt.Sprintf("Negotiated %s", tlsVer),
				Remediation: "Maintain TLS 1.2+ / TLS 1.3 via Caddy Ingress.",
			}, 0)
		} else {
			record(OWASPDASTFinding{
				WSTGCode:    "WSTG-CRYP-01",
				OWASPRef:    "A02:2021",
				Severity:    "HIGH",
				Status:      "FAIL",
				Title:       "Deprecated TLS Version Negotiated",
				Evidence:    fmt.Sprintf("Negotiated weak protocol: %s", tlsVer),
				Remediation: "Disable TLS 1.0/1.1 and enforce TLS 1.2/1.3.",
			}, 18)
		}
		if len(resp.TLS.PeerCertificates) > 0 {
			cert := resp.TLS.PeerCertificates[0]
			if time.Now().After(cert.NotAfter) {
				record(OWASPDASTFinding{
					WSTGCode:    "WSTG-CRYP-01",
					OWASPRef:    "A02:2021",
					Severity:    "HIGH",
					Status:      "FAIL",
					Title:       "TLS Certificate Expired",
					Evidence:    fmt.Sprintf("Certificate CN=%s expired at %s", cert.Subject.CommonName, cert.NotAfter.Format(time.RFC3339)),
					Remediation: "Renew or rotate the certificate in Caddy Ingress -> TLS Certs.",
				}, 15)
			}
		}
	} else {
		record(OWASPDASTFinding{
			WSTGCode:    "WSTG-CRYP-01",
			OWASPRef:    "A02:2021",
			Severity:    "HIGH",
			Status:      "WARN",
			Title:       "Cleartext HTTP Endpoint (No HTTPS)",
			Evidence:    fmt.Sprintf("Target %s served over plain HTTP", parsed.String()),
			Remediation: "Publish this service behind Caddy Ingress with automatic HTTPS TLS termination.",
		}, 12)
	}

	// 3. WSTG-CONF-07: OWASP Secure Headers Check
	secHeaders := []struct {
		key      string
		severity string
		pts      float64
		httpsReq bool
	}{
		{"Strict-Transport-Security", "MEDIUM", 8, true},
		{"Content-Security-Policy", "MEDIUM", 10, false},
		{"X-Content-Type-Options", "MEDIUM", 8, false},
		{"X-Frame-Options", "MEDIUM", 7, false},
		{"Referrer-Policy", "LOW", 5, false},
		{"Permissions-Policy", "LOW", 4, false},
	}
	for _, sh := range secHeaders {
		val := resp.Header.Get(sh.key)
		if val != "" {
			result.HeadersPresent[sh.key] = val
			record(OWASPDASTFinding{
				WSTGCode:    "WSTG-CONF-07",
				OWASPRef:    "A05:2021",
				Severity:    sh.severity,
				Status:      "PASS",
				Title:       fmt.Sprintf("Header Present: %s", sh.key),
				Evidence:    val,
				Remediation: "Header configured properly.",
			}, 0)
		} else if !sh.httpsReq || parsed.Scheme == "https" {
			record(OWASPDASTFinding{
				WSTGCode:    "WSTG-CONF-07",
				OWASPRef:    "A05:2021",
				Severity:    sh.severity,
				Status:      "FAIL",
				Title:       fmt.Sprintf("Missing OWASP Security Header: %s", sh.key),
				Evidence:    fmt.Sprintf("Response did not include `%s`.", sh.key),
				Remediation: "Enable 'Inject OWASP Secure Headers' in Caddy Ingress -> Threat Shield WAF.",
			}, sh.pts)
		}
	}

	// Server fingerprinting header check
	if srv := resp.Header.Get("Server"); srv != "" {
		result.HeadersPresent["Server"] = srv
		record(OWASPDASTFinding{
			WSTGCode:    "WSTG-INFO-02",
			OWASPRef:    "A05:2021",
			Severity:    "LOW",
			Status:      "WARN",
			Title:       "Server Banner Fingerprinting Exposed",
			Evidence:    fmt.Sprintf("Server: %s", srv),
			Remediation: "Strip `Server` and `X-Powered-By` headers via Caddy WAF Secure Headers.",
		}, 4)
	}
	if xpb := resp.Header.Get("X-Powered-By"); xpb != "" {
		result.HeadersPresent["X-Powered-By"] = xpb
		record(OWASPDASTFinding{
			WSTGCode:    "WSTG-INFO-02",
			OWASPRef:    "A05:2021",
			Severity:    "LOW",
			Status:      "WARN",
			Title:       "X-Powered-By Technology Disclosure",
			Evidence:    fmt.Sprintf("X-Powered-By: %s", xpb),
			Remediation: "Strip `X-Powered-By` header in application or reverse proxy.",
		}, 4)
	}

	// 4. WSTG-SESS-02: Cookie Security Flags
	cookies := resp.Cookies()
	if len(cookies) > 0 {
		weakCookies := 0
		for _, ck := range cookies {
			if !ck.HttpOnly || (parsed.Scheme == "https" && !ck.Secure) {
				weakCookies++
			}
		}
		if weakCookies > 0 {
			record(OWASPDASTFinding{
				WSTGCode:    "WSTG-SESS-02",
				OWASPRef:    "A07:2021",
				Severity:    "MEDIUM",
				Status:      "FAIL",
				Title:       "Cookies Missing HttpOnly / Secure Attributes",
				Evidence:    fmt.Sprintf("%d/%d cookies lacked HttpOnly or Secure flag.", weakCookies, len(cookies)),
				Remediation: "Set `HttpOnly`, `Secure`, and `SameSite=Lax` or `Strict` on all session cookies.",
			}, 10)
		} else {
			record(OWASPDASTFinding{
				WSTGCode:    "WSTG-SESS-02",
				OWASPRef:    "A07:2021",
				Severity:    "MEDIUM",
				Status:      "PASS",
				Title:       "Session Cookies Properly Flagged",
				Evidence:    fmt.Sprintf("All %d response cookies enforce HttpOnly/Secure.", len(cookies)),
				Remediation: "No action required.",
			}, 0)
		}
	}

	// 5. WSTG-CLNT-07: CORS Misconfiguration
	acao := resp.Header.Get("Access-Control-Allow-Origin")
	acac := resp.Header.Get("Access-Control-Allow-Credentials")
	if strings.Contains(acao, "evil-owasp-probe.invalid") || (acao == "*" && strings.EqualFold(acac, "true")) {
		record(OWASPDASTFinding{
			WSTGCode:    "WSTG-CLNT-07",
			OWASPRef:    "A01:2021",
			Severity:    "HIGH",
			Status:      "FAIL",
			Title:       "Permissive CORS Origin Reflection / Credentials Misconfiguration",
			Evidence:    fmt.Sprintf("ACAO=%q ACAC=%q for untrusted Origin", acao, acac),
			Remediation: "Restrict Access-Control-Allow-Origin to an explicit allowlist of trusted origins.",
		}, 15)
	} else {
		record(OWASPDASTFinding{
			WSTGCode:    "WSTG-CLNT-07",
			OWASPRef:    "A01:2021",
			Severity:    "MEDIUM",
			Status:      "PASS",
			Title:       "CORS Policy Rejects Arbitrary Untrusted Origins",
			Evidence:    fmt.Sprintf("ACAO=%q", acao),
			Remediation: "No action required.",
		}, 0)
	}

	// 6. WSTG-CONF-06: Dangerous HTTP TRACE Method
	traceReq, _ := http.NewRequest(http.MethodTrace, parsed.String(), nil)
	if traceResp, err := client.Do(traceReq); err == nil {
		_ = traceResp.Body.Close()
		if traceResp.StatusCode == http.StatusOK {
			record(OWASPDASTFinding{
				WSTGCode:    "WSTG-CONF-06",
				OWASPRef:    "A05:2021",
				Severity:    "MEDIUM",
				Status:      "FAIL",
				Title:       "HTTP TRACE Method Enabled (Cross-Site Tracing Risk)",
				Evidence:    "TRACE request returned 200 OK",
				Remediation: "Enable OWASP CRS-911 HTTP Method Enforcement in Caddy WAF.",
			}, 10)
		} else {
			record(OWASPDASTFinding{
				WSTGCode:    "WSTG-CONF-06",
				OWASPRef:    "A05:2021",
				Severity:    "LOW",
				Status:      "PASS",
				Title:       "HTTP TRACE Method Disabled",
				Evidence:    fmt.Sprintf("TRACE returned HTTP %d", traceResp.StatusCode),
				Remediation: "No action required.",
			}, 0)
		}
	}

	// 7. WSTG-CONF-04: Exposed Sensitive Dotfiles & Endpoints
	baseRoot := fmt.Sprintf("%s://%s", parsed.Scheme, parsed.Host)
	sensitivePaths := []struct {
		path   string
		marker string
	}{
		{"/.env", "="},
		{"/.git/HEAD", "ref:"},
		{"/phpinfo.php", "phpinfo"},
		{"/actuator/env", "propertySources"},
	}
	exposedFound := make([]string, 0)
	for _, sp := range sensitivePaths {
		pResp, pErr := client.Get(baseRoot + sp.path)
		if pErr == nil {
			bodyBytes, _ := io.ReadAll(io.LimitReader(pResp.Body, 4096))
			_ = pResp.Body.Close()
			if pResp.StatusCode == http.StatusOK && strings.Contains(strings.ToLower(string(bodyBytes)), strings.ToLower(sp.marker)) {
				exposedFound = append(exposedFound, sp.path)
			}
		}
	}
	if len(exposedFound) > 0 {
		record(OWASPDASTFinding{
			WSTGCode:    "WSTG-CONF-04",
			OWASPRef:    "A05:2021",
			Severity:    "CRITICAL",
			Status:      "FAIL",
			Title:       "Sensitive Configuration / Repository Files Publicly Accessible",
			Evidence:    fmt.Sprintf("Accessible sensitive paths: %s", strings.Join(exposedFound, ", ")),
			Remediation: "Remove exposed dotfiles immediately and enable Caddy WAF Paranoia Level >= 2.",
		}, 25)
	} else {
		record(OWASPDASTFinding{
			WSTGCode:    "WSTG-CONF-04",
			OWASPRef:    "A05:2021",
			Severity:    "HIGH",
			Status:      "PASS",
			Title:       "No Sensitive Dotfiles (.env / .git / actuator) Publicly Exposed",
			Evidence:    "Checked /.env, /.git/HEAD, /phpinfo.php, /actuator/env — all protected.",
			Remediation: "No action required.",
		}, 0)
	}

	// 8. Optional Benign Active WAF Validation Probes (SQLi, XSS, LFI, SSRF)
	if req.ProbeWAF {
		probes := []struct {
			name string
			code string
			uri  string
		}{
			{"SQLi", "WSTG-INPV-05", "/?gbnt_dast=1+union+select+1,2--"},
			{"XSS", "WSTG-INPV-01", "/?gbnt_dast=<script>alert(1)</script>"},
			{"LFI", "WSTG-ATHZ-01", "/../../../../etc/passwd"},
			{"SSRF", "WSTG-INPV-19", "/?gbnt_dast=http://169.254.169.254/latest/meta-data/"},
		}
		for _, pr := range probes {
			result.WAFProbesRun++
			pResp, pErr := client.Get(baseRoot + pr.uri)
			if pErr == nil {
				_ = pResp.Body.Close()
				if pResp.StatusCode == http.StatusForbidden || pResp.StatusCode == http.StatusNotAcceptable || pResp.StatusCode == http.StatusBadRequest {
					result.WAFBlockedCount++
					record(OWASPDASTFinding{
						WSTGCode:    pr.code,
						OWASPRef:    "A03:2021",
						Severity:    "HIGH",
						Status:      "PASS",
						Title:       fmt.Sprintf("WAF Blocked %s Validation Probe", pr.name),
						Evidence:    fmt.Sprintf("Probe %s blocked with HTTP %d", pr.name, pResp.StatusCode),
						Remediation: "WAF enforcement verified.",
					}, 0)
				} else {
					record(OWASPDASTFinding{
						WSTGCode:    pr.code,
						OWASPRef:    "A03:2021",
						Severity:    "MEDIUM",
						Status:      "WARN",
						Title:       fmt.Sprintf("WAF Did Not Block %s Probe (HTTP %d)", pr.name, pResp.StatusCode),
						Evidence:    fmt.Sprintf("Probe %s returned HTTP %d (WAF may be disabled, in detection mode, or IP whitelisted)", pr.name, pResp.StatusCode),
						Remediation: "Enable Caddy Threat Shield WAF in 'enforce' mode for this route.",
					}, 6)
				}
			}
		}
	}

	// 9. Optional OWASP ZAP Baseline Docker Launch
	if req.IncludeZAP {
		ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
		defer cancel()
		cmd := exec.CommandContext(ctx, "docker", "run", "--rm", "--network", "host",
			"ghcr.io/zaproxy/zaproxy:stable", "zap-baseline.py", "-t", parsed.String(), "-m", "1")
		out, zapErr := cmd.CombinedOutput()
		if zapErr == nil || len(out) > 0 {
			result.ScannerEngine = "gubernator-wstg+zap"
			txt := string(out)
			if len(txt) > 3500 {
				txt = txt[:3500] + "\n... [truncated]"
			}
			result.ZAPOutput = txt
		} else {
			result.ZAPOutput = "OWASP ZAP Docker image unavailable locally (docker pull ghcr.io/zaproxy/zaproxy:stable)."
		}
	}

	score := 100.0 - penalty
	if score < 0 {
		score = 0
	}
	result.Score = float64(int(score*10)) / 10.0
	result.Grade = scoreToGrade(result.Score)
	result.DurationMs = time.Since(start).Milliseconds()

	storeDASTResult(result)

	if db.DB != nil {
		if actor == "" {
			actor = "admin"
		}
		_, _ = audit.RecordEvent(actor, "OWASP-DAST", parsed.Hostname(), "OWASP_DAST_SCAN", "SUCCESS",
			fmt.Sprintf("Scanned target=%s grade=%s score=%.1f pass=%d fail=%d warn=%d waf_blocked=%d/%d",
				result.TargetURL, result.Grade, result.Score, result.PassedChecks, result.FailedChecks, result.WarningChecks, result.WAFBlockedCount, result.WAFProbesRun))
	}

	return &result, nil
}

func storeDASTResult(r OWASPDASTResult) {
	dastMu.Lock()
	dastHistory = append([]OWASPDASTResult{r}, dastHistory...)
	if len(dastHistory) > 30 {
		dastHistory = dastHistory[:30]
	}
	dastMu.Unlock()
}

func tlsVersionString(v uint16) string {
	switch v {
	case tls.VersionTLS13:
		return "TLS 1.3"
	case tls.VersionTLS12:
		return "TLS 1.2"
	case tls.VersionTLS11:
		return "TLS 1.1"
	case tls.VersionTLS10:
		return "TLS 1.0"
	default:
		return fmt.Sprintf("0x%x", v)
	}
}

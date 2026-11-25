package security

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gubernator-org/gubernator/internal/auth"
	"github.com/gubernator-org/gubernator/internal/caddy"
	"github.com/gubernator-org/gubernator/internal/db"
)

func TestOWASPComplianceAndReport(t *testing.T) {
	database := setupComplianceTestDB(t)
	summary := EvaluateOWASPCompliance(database)
	if summary.TotalControls < 15 {
		t.Fatalf("expected >= 15 OWASP controls, got %d", summary.TotalControls)
	}
	if summary.OverallScore <= 0 || summary.Grade == "" {
		t.Fatalf("expected valid score and grade, got %.1f (%s)", summary.OverallScore, summary.Grade)
	}

	md := GenerateOWASPReport(summary, "markdown")
	if !strings.Contains(md, "Gubernator OWASP Security Suite Compliance Report") || !strings.Contains(md, "A01:2021") {
		t.Fatalf("unexpected markdown report content")
	}
	js := GenerateOWASPReport(summary, "json")
	if !strings.Contains(js, `"overall_score"`) {
		t.Fatalf("unexpected json report content")
	}
}

func TestLintComposeOWASP(t *testing.T) {
	insecureCompose := `
services:
  evil-app:
    image: nginx:latest
    privileged: true
    network_mode: host
    ports:
      - "5432:5432"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - DB_PASSWORD=supersecretplaintext
`
	res := LintComposeOWASP(insecureCompose)
	if !res.Valid {
		t.Fatalf("expected valid yaml, got error: %s", res.ParseError)
	}
	if res.CriticalCount < 2 {
		t.Fatalf("expected >= 2 critical findings (privileged + docker.sock), got %d", res.CriticalCount)
	}
	if res.HighCount < 3 {
		t.Fatalf("expected >= 3 high findings (host net + secret + exposed 5432), got %d", res.HighCount)
	}
	if res.Score >= 50 {
		t.Fatalf("expected low score for insecure compose, got %.1f", res.Score)
	}

	hardenedCompose := `
services:
  safe-app:
    image: nginx:1.27-alpine
    user: "10001:10001"
    read_only: true
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    environment:
      - DB_PASSWORD=${DB_PASSWORD}
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 256M
`
	safeRes := LintComposeOWASP(hardenedCompose)
	if safeRes.Score != 100.0 || safeRes.Grade != "A+" || len(safeRes.Findings) != 0 {
		t.Fatalf("expected 100%% A+ for hardened compose, got score=%.1f grade=%s findings=%+v", safeRes.Score, safeRes.Grade, safeRes.Findings)
	}
}

func TestOWASPDASTScanner(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/.env" {
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write([]byte("DB_PASSWORD=leaked"))
			return
		}
		if strings.Contains(r.URL.RawQuery, "union+select") {
			w.WriteHeader(http.StatusForbidden)
			return
		}
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Content-Security-Policy", "default-src 'self'")
		w.Header().Set("Server", "LeakyServer/1.0")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	}))
	defer srv.Close()

	res, err := RunOWASPDASTScan(OWASPDASTRequest{
		TargetURL: srv.URL,
		ProbeWAF:  true,
	}, "tester")
	if err != nil {
		t.Fatalf("DAST scan failed: %v", err)
	}
	if res.HTTPStatus != 200 || res.WAFBlockedCount < 1 {
		t.Fatalf("expected HTTP 200 and >= 1 WAF probe blocked, got status=%d waf=%d", res.HTTPStatus, res.WAFBlockedCount)
	}
	foundEnvLeak := false
	foundFixableHeader := false
	for _, f := range res.Findings {
		if f.WSTGCode == "WSTG-CONF-04" && f.Status == "FAIL" {
			foundEnvLeak = true
			if !f.AutoFixable || f.RemediateControlID != "owasp-a03" {
				t.Fatalf("expected WSTG-CONF-04 to map to auto-fixable owasp-a03, got %+v", f)
			}
		}
		if f.WSTGCode == "WSTG-INFO-02" && f.Status == "WARN" && f.AutoFixable && f.RemediateControlID == "owasp-a05" {
			foundFixableHeader = true
		}
	}
	if !foundEnvLeak {
		t.Fatalf("expected WSTG-CONF-04 FAIL for exposed /.env, got %+v", res.Findings)
	}
	if !foundFixableHeader {
		t.Fatalf("expected WSTG-INFO-02 WARN to be auto-fixable via owasp-a05, got %+v", res.Findings)
	}
}

func TestOWASPWAFSnippetAndJWTRevocation(t *testing.T) {
	// 1. Caddy WAF OWASP CRS + Secure Headers + LLM Shield snippet generation
	cfg := db.ManagedWAFConfig{
		Enabled:             true,
		Mode:                "enforce",
		ParanoiaLevel:       2,
		BlockSQLi:           true,
		BlockXSS:            true,
		BlockRCE:            true,
		BlockLFI:            true,
		BlockScanners:       true,
		BlockSSRF:           true,
		BlockXXE:            true,
		BlockNoSQLi:         true,
		EnforceHTTPMethods:  true,
		InjectSecureHeaders: true,
		CSPMode:             "strict",
		LLMShieldEnabled:    true,
	}
	snippet := caddy.BuildWAFSnippet("ai.gbnt.local", cfg, nil)
	for _, expected := range []string{"@waf_ssrf", "@waf_xxe_ssti", "@waf_nosqli", "@waf_bad_methods", "@waf_paranoia_dotfiles", "@waf_llm_prompt_inj", "Strict-Transport-Security", "Content-Security-Policy"} {
		if !strings.Contains(snippet, expected) {
			t.Fatalf("expected Caddyfile WAF snippet to contain %q", expected)
		}
	}

	// 2. OWASP ASVS V3.5 JWT Revocation on Logout
	tok, err := auth.GenerateToken(auth.UserSession{Username: "alice", Role: auth.RoleAdmin, Provider: "local"})
	if err != nil {
		t.Fatalf("GenerateToken failed: %v", err)
	}
	if _, err := auth.ValidateToken(tok); err != nil {
		t.Fatalf("expected fresh token to validate, got %v", err)
	}
	auth.RevokeToken(tok)
	if _, err := auth.ValidateToken(tok); err == nil {
		t.Fatalf("expected revoked token to fail validation")
	}
}

func TestOWASPAutoRemediationAndComposeHardening(t *testing.T) {
	database := setupComplianceTestDB(t)

	// 1. Safe bulk auto-remediation should raise the OWASP compliance score
	res, err := RemediateAllSafeOWASP(database, "tester")
	if err != nil || !res.Success {
		t.Fatalf("RemediateAllSafeOWASP failed: err=%v res=%+v", err, res)
	}
	if res.AfterScore <= res.BeforeScore {
		t.Fatalf("expected OWASP score to improve after auto-remediation: before=%.1f after=%.1f", res.BeforeScore, res.AfterScore)
	}
	if len(res.ActionsTaken) < 4 {
		t.Fatalf("expected >= 4 remediation actions, got %d", len(res.ActionsTaken))
	}

	// 2. Compose Auto-Hardening should fix privileged, docker.sock, host net, plaintext secret, root user, limits & exposed DB port
	insecure := `
services:
  api:
    image: nginx:1.27-alpine
    privileged: true
    network_mode: host
    ports:
      - "5432:5432"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - DB_PASSWORD=hardcodedsecret
`
	hardened, err := HardenComposeOWASP(insecure)
	if err != nil || !hardened.Success {
		t.Fatalf("HardenComposeOWASP failed: %v", err)
	}
	if hardened.AfterScore <= hardened.BeforeScore || hardened.AfterScore < 95.0 {
		t.Fatalf("expected hardened score >= 95%% (from %.1f%%), got %.1f%%; changes=%v", hardened.BeforeScore, hardened.AfterScore, hardened.ChangesApplied)
	}
	if !strings.Contains(hardened.HardenedYAML, "${DB_PASSWORD}") || strings.Contains(hardened.HardenedYAML, "privileged") {
		t.Fatalf("expected secrets externalized and privileged removed, got:\n%s", hardened.HardenedYAML)
	}
}

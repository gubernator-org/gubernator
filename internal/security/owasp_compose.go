package security

import (
	"fmt"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"
)

var (
	secretKeyRe = regexp.MustCompile(`(?i)(PASSWORD|PASSWD|SECRET|API_KEY|ACCESS_KEY|PRIVATE_KEY|JWT_SECRET|DB_PASS|AUTH_TOKEN)`)
	envVarRefRe = regexp.MustCompile(`\$\{[A-Za-z0-9_]+`)
)

// ComposeOWASPFinding describes a pre-deploy OWASP Docker Top 10 finding inside a Compose manifest.
type ComposeOWASPFinding struct {
	RuleID      string `json:"rule_id"`   // D01..D08
	OWASPRef    string `json:"owasp_ref"` // e.g. "OWASP Docker D01"
	Service     string `json:"service"`   // Affected compose service name
	Severity    string `json:"severity"`  // "CRITICAL", "HIGH", "MEDIUM", "LOW"
	Title       string `json:"title"`
	Detail      string `json:"detail"`
	Remediation string `json:"remediation"`
}

// ComposeOWASPResult summarizes the static OWASP audit of a docker-compose.yml manifest.
type ComposeOWASPResult struct {
	Valid            bool                  `json:"valid"`
	Score            float64               `json:"score"`
	Grade            string                `json:"grade"`
	ServicesAudited  int                   `json:"services_audited"`
	CriticalCount    int                   `json:"critical_count"`
	HighCount        int                   `json:"high_count"`
	MediumCount      int                   `json:"medium_count"`
	LowCount         int                   `json:"low_count"`
	Findings         []ComposeOWASPFinding `json:"findings"`
	HardeningSnippet string                `json:"hardening_snippet"`
	ParseError       string                `json:"parse_error,omitempty"`
}

// LintComposeOWASP statically audits a docker-compose.yml against OWASP Docker Security Top 10 (D01-D10).
func LintComposeOWASP(rawCompose string) ComposeOWASPResult {
	res := ComposeOWASPResult{
		Valid:    true,
		Score:    100.0,
		Grade:    "A+",
		Findings: make([]ComposeOWASPFinding, 0),
		HardeningSnippet: `# OWASP Docker Top 10 Recommended Service Hardening Block
user: "10001:10001"
read_only: true
cap_drop:
  - ALL
security_opt:
  - no-new-privileges:true
deploy:
  resources:
    limits:
      cpus: "1.0"
      memory: 512M`,
	}

	var doc map[string]interface{}
	if err := yaml.Unmarshal([]byte(rawCompose), &doc); err != nil {
		res.Valid = false
		res.Score = 0
		res.Grade = "F"
		res.ParseError = err.Error()
		return res
	}

	servicesRaw, ok := doc["services"].(map[string]interface{})
	if !ok || len(servicesRaw) == 0 {
		return res
	}
	res.ServicesAudited = len(servicesRaw)

	penalty := 0.0
	addFinding := func(f ComposeOWASPFinding, pts float64) {
		res.Findings = append(res.Findings, f)
		penalty += pts
		switch f.Severity {
		case "CRITICAL":
			res.CriticalCount++
		case "HIGH":
			res.HighCount++
		case "MEDIUM":
			res.MediumCount++
		default:
			res.LowCount++
		}
	}

	for svcName, svcObj := range servicesRaw {
		svc, ok := svcObj.(map[string]interface{})
		if !ok {
			continue
		}

		// D01: Privileged mode / missing cap_drop / missing no-new-privileges
		if priv, ok := svc["privileged"].(bool); ok && priv {
			addFinding(ComposeOWASPFinding{
				RuleID:      "D01",
				OWASPRef:    "OWASP Docker D01",
				Service:     svcName,
				Severity:    "CRITICAL",
				Title:       "Privileged Container Mode Enabled",
				Detail:      "Setting `privileged: true` grants full host kernel capabilities and trivial container escape.",
				Remediation: "Remove `privileged: true` and grant only minimal Linux capabilities with `cap_drop: [ALL]`.",
			}, 25)
		}

		hasCapDropAll := false
		if caps, ok := svc["cap_drop"].([]interface{}); ok {
			for _, c := range caps {
				if strings.EqualFold(fmt.Sprint(c), "ALL") {
					hasCapDropAll = true
				}
			}
		}
		if !hasCapDropAll {
			addFinding(ComposeOWASPFinding{
				RuleID:      "D01",
				OWASPRef:    "OWASP Docker D01",
				Service:     svcName,
				Severity:    "MEDIUM",
				Title:       "Linux Capabilities Not Dropped (cap_drop: ALL missing)",
				Detail:      "Default Docker capability set includes CAP_NET_RAW and others unnecessary for standard workloads.",
				Remediation: "Add `cap_drop: [ALL]` and explicitly add back only required capabilities.",
			}, 6)
		}

		hasNoNewPriv := false
		if secOpts, ok := svc["security_opt"].([]interface{}); ok {
			for _, o := range secOpts {
				if strings.Contains(strings.ToLower(fmt.Sprint(o)), "no-new-privileges") {
					hasNoNewPriv = true
				}
			}
		}
		if !hasNoNewPriv {
			addFinding(ComposeOWASPFinding{
				RuleID:      "D01",
				OWASPRef:    "OWASP Docker D01",
				Service:     svcName,
				Severity:    "LOW",
				Title:       "Missing `no-new-privileges:true`",
				Detail:      "Processes inside the container could gain extra privileges via setuid/setgid binaries.",
				Remediation: "Add `security_opt: [\"no-new-privileges:true\"]`.",
			}, 4)
		}

		// D02: Unpinned :latest or untagged image
		if img, ok := svc["image"].(string); ok {
			img = strings.TrimSpace(img)
			if img != "" && (!strings.Contains(img, ":") || strings.HasSuffix(img, ":latest")) && !strings.Contains(img, "@sha256:") {
				addFinding(ComposeOWASPFinding{
					RuleID:      "D02",
					OWASPRef:    "OWASP Docker D02",
					Service:     svcName,
					Severity:    "MEDIUM",
					Title:       "Unpinned Container Image Tag (:latest or untagged)",
					Detail:      fmt.Sprintf("Image `%s` uses a mutable tag, risking supply-chain drift or unexpected CVEs.", img),
					Remediation: "Pin an immutable version tag or SHA-256 digest (e.g. `nginx:1.27-alpine@sha256:...`).",
				}, 7)
			}
		}

		// D03: Dangerous host mounts (/var/run/docker.sock, /etc, /proc, /)
		if vols, ok := svc["volumes"].([]interface{}); ok {
			for _, v := range vols {
				vs := strings.TrimSpace(fmt.Sprint(v))
				if strings.Contains(vs, "/var/run/docker.sock") {
					addFinding(ComposeOWASPFinding{
						RuleID:      "D03",
						OWASPRef:    "OWASP Docker D03",
						Service:     svcName,
						Severity:    "CRITICAL",
						Title:       "Docker Daemon Socket Mounted into Container",
						Detail:      fmt.Sprintf("Mount `%s` gives the container root-equivalent control over the host node.", vs),
						Remediation: "Remove `/var/run/docker.sock` mount or isolate behind a read-only socket proxy.",
					}, 25)
				} else if strings.HasPrefix(vs, "/etc:") || strings.HasPrefix(vs, "/root:") || strings.HasPrefix(vs, "/:") || strings.HasPrefix(vs, "/proc:") {
					addFinding(ComposeOWASPFinding{
						RuleID:      "D03",
						OWASPRef:    "OWASP Docker D03",
						Service:     svcName,
						Severity:    "HIGH",
						Title:       "Sensitive Host Filesystem Bind Mount",
						Detail:      fmt.Sprintf("Mount `%s` exposes sensitive host directories.", vs),
						Remediation: "Use dedicated Docker named volumes or `/var/contenedores/<app>` shared storage.",
					}, 15)
				}
			}
		}

		// D04: Host network/PID/IPC namespace sharing
		for _, nsKey := range []string{"network_mode", "pid", "ipc"} {
			if val, ok := svc[nsKey].(string); ok && strings.EqualFold(strings.TrimSpace(val), "host") {
				addFinding(ComposeOWASPFinding{
					RuleID:      "D04",
					OWASPRef:    "OWASP Docker D04",
					Service:     svcName,
					Severity:    "HIGH",
					Title:       fmt.Sprintf("Host Namespace Shared (`%s: host`)", nsKey),
					Detail:      fmt.Sprintf("Sharing host `%s` namespace weakens container isolation and enables lateral pivoting.", nsKey),
					Remediation: fmt.Sprintf("Remove `%s: host` and use isolated Docker bridge/overlay networks.", nsKey),
				}, 15)
			}
		}

		// D05: Hardcoded plaintext secrets in environment
		checkEnvPair := func(k, v string) {
			if secretKeyRe.MatchString(k) && strings.TrimSpace(v) != "" && !envVarRefRe.MatchString(v) {
				addFinding(ComposeOWASPFinding{
					RuleID:      "D05",
					OWASPRef:    "OWASP Docker D05",
					Service:     svcName,
					Severity:    "HIGH",
					Title:       fmt.Sprintf("Hardcoded Secret in Environment (`%s`)", k),
					Detail:      "Plaintext credentials inside `docker-compose.yml` leak in backups, Git, and container inspect metadata.",
					Remediation: "Use Gubernator Secret Vault, Docker secrets, or external `${VAR}` variable injection.",
				}, 12)
			}
		}
		switch env := svc["environment"].(type) {
		case []interface{}:
			for _, item := range env {
				s := fmt.Sprint(item)
				if idx := strings.Index(s, "="); idx > 0 {
					checkEnvPair(strings.TrimSpace(s[:idx]), strings.TrimSpace(s[idx+1:]))
				}
			}
		case map[string]interface{}:
			for k, v := range env {
				checkEnvPair(k, fmt.Sprint(v))
			}
		}

		// D06: Missing non-root user or read_only rootfs
		if _, hasUser := svc["user"]; !hasUser {
			addFinding(ComposeOWASPFinding{
				RuleID:      "D06",
				OWASPRef:    "OWASP Docker D06",
				Service:     svcName,
				Severity:    "MEDIUM",
				Title:       "Container Runs as Default Root User",
				Detail:      "No non-root `user:` UID/GID specified; compromise yields UID 0 inside the container.",
				Remediation: "Add `user: \"10001:10001\"` (or non-root image user) and `read_only: true` where compatible.",
			}, 6)
		}

		// D07: Missing CPU/Memory resource limits
		hasLimits := false
		if deploy, ok := svc["deploy"].(map[string]interface{}); ok {
			if resources, ok := deploy["resources"].(map[string]interface{}); ok {
				if limits, ok := resources["limits"].(map[string]interface{}); ok && len(limits) > 0 {
					hasLimits = true
				}
			}
		}
		if !hasLimits {
			if _, ok := svc["mem_limit"]; ok {
				hasLimits = true
			}
		}
		if !hasLimits {
			addFinding(ComposeOWASPFinding{
				RuleID:      "D07",
				OWASPRef:    "OWASP Docker D07",
				Service:     svcName,
				Severity:    "MEDIUM",
				Title:       "Missing CPU / Memory Resource Limits",
				Detail:      "Unbounded containers can starve the Centurion host during DoS or cryptojacking incidents.",
				Remediation: "Define `deploy.resources.limits` (`cpus` and `memory`).",
			}, 6)
		}

		// D08: Sensitive DB/AI ports exposed on 0.0.0.0
		if ports, ok := svc["ports"].([]interface{}); ok {
			sensitive := map[string]string{
				"5432": "PostgreSQL", "3306": "MySQL", "6379": "Redis", "27017": "MongoDB",
				"9200": "OpenSearch/ES", "11434": "Ollama LLM", "8888": "Jupyter Notebook",
			}
			for _, p := range ports {
				ps := strings.TrimSpace(fmt.Sprint(p))
				if strings.HasPrefix(ps, "127.0.0.1:") {
					continue
				}
				for portNum, label := range sensitive {
					if strings.Contains(ps, ":"+portNum) || strings.HasPrefix(ps, portNum+":") || ps == portNum {
						addFinding(ComposeOWASPFinding{
							RuleID:      "D08",
							OWASPRef:    "OWASP Docker D08",
							Service:     svcName,
							Severity:    "HIGH",
							Title:       fmt.Sprintf("Sensitive %s Port (%s) Exposed Publicly", label, portNum),
							Detail:      fmt.Sprintf("Port mapping `%s` binds on 0.0.0.0 instead of keeping traffic on internal Docker networks.", ps),
							Remediation: "Remove public host port binding or bind strictly to `127.0.0.1:" + portNum + ":" + portNum + "`.",
						}, 12)
					}
				}
			}
		}
	}

	score := 100.0 - penalty
	if score < 0 {
		score = 0
	}
	res.Score = float64(int(score*10)) / 10.0
	res.Grade = scoreToGrade(res.Score)
	return res
}

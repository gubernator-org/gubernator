package cli

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"text/tabwriter"

	"github.com/spf13/cobra"

	"github.com/gubernator-org/gubernator/internal/security"
)

var (
	owaspScanWAF bool
	owaspScanZAP bool
)

var owaspCmd = &cobra.Command{
	Use:   "owasp",
	Short: "OWASP Security Suite (Top 10, API, ASVS L2, Docker Linter & WSTG DAST Scanner)",
}

var owaspStatusCmd = &cobra.Command{
	Use:   "status",
	Short: "Evaluate cluster compliance against OWASP Top 10, API Top 10, ASVS L2, Docker & LLM Top 10",
	Run: func(cmd *cobra.Command, args []string) {
		resp, err := DoAPIRequest("GET", "/v1/security/owasp/status", nil)
		if err != nil {
			_, _ = fmt.Fprintf(os.Stderr, "Failed to connect to Manager: %v\n", err)
			os.Exit(1)
		}
		defer func() { _ = resp.Body.Close() }()
		var summary security.OWASPSummary
		if err := json.NewDecoder(resp.Body).Decode(&summary); err != nil {
			_, _ = fmt.Fprintf(os.Stderr, "Failed to parse OWASP summary: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("OWASP Security Suite — Score: %.1f%% (Grade %s)\n", summary.OverallScore, summary.Grade)
		fmt.Printf("  Top 10 Web: %.1f%% | API Top 10: %.1f%% | ASVS L2: %.1f%% | Docker Top 10: %.1f%% | LLM Top 10: %.1f%%\n\n",
			summary.Top10WebScore, summary.APITop10Score, summary.ASVSScore, summary.DockerTop10Score, summary.LLMTop10Score)

		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		_, _ = fmt.Fprintln(w, "REF\tDOMAIN\tSTATUS\tSCORE\tTITLE")
		for _, c := range summary.Controls {
			_, _ = fmt.Fprintf(w, "%s\t%s\t%s\t%.0f%%\t%s\n", c.Reference, c.Domain, c.Status, c.Score, c.Title)
		}
		_ = w.Flush()
	},
}

var owaspScanCmd = &cobra.Command{
	Use:   "scan <url>",
	Short: "Run a non-destructive OWASP WSTG active DAST audit against a Caddy route or HTTP endpoint",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		body, _ := json.Marshal(security.OWASPDASTRequest{
			TargetURL:  args[0],
			ProbeWAF:   owaspScanWAF,
			IncludeZAP: owaspScanZAP,
		})
		resp, err := DoAPIRequest("POST", "/v1/security/owasp/dast/scan", bytes.NewReader(body))
		if err != nil {
			_, _ = fmt.Fprintf(os.Stderr, "Failed to connect to Manager: %v\n", err)
			os.Exit(1)
		}
		defer func() { _ = resp.Body.Close() }()
		var res security.OWASPDASTResult
		_ = json.NewDecoder(resp.Body).Decode(&res)
		fmt.Printf("OWASP DAST Scan [%s] -> %s\n", res.ID, res.TargetURL)
		fmt.Printf("  Grade: %s (%.1f%%) | HTTP %d | Pass: %d | Warn: %d | Fail: %d | WAF Blocked: %d/%d\n\n",
			res.Grade, res.Score, res.HTTPStatus, res.PassedChecks, res.WarningChecks, res.FailedChecks, res.WAFBlockedCount, res.WAFProbesRun)
		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		_, _ = fmt.Fprintln(w, "WSTG\tSTATUS\tSEVERITY\tTITLE\tEVIDENCE")
		for _, f := range res.Findings {
			_, _ = fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\n", f.WSTGCode, f.Status, f.Severity, f.Title, f.Evidence)
		}
		_ = w.Flush()
	},
}

var owaspLintCmd = &cobra.Command{
	Use:   "lint <docker-compose.yml>",
	Short: "Statically audit a local docker-compose.yml file against OWASP Docker Security Top 10 (D01-D10)",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		raw, err := os.ReadFile(args[0])
		if err != nil {
			_, _ = fmt.Fprintf(os.Stderr, "Failed to read file: %v\n", err)
			os.Exit(1)
		}
		res := security.LintComposeOWASP(string(raw))
		fmt.Printf("OWASP Docker Top 10 Compose Audit: Score %.1f%% (Grade %s) — %d services audited\n",
			res.Score, res.Grade, res.ServicesAudited)
		if len(res.Findings) == 0 {
			fmt.Println("  No OWASP Docker security issues detected.")
			return
		}
		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		_, _ = fmt.Fprintln(w, "RULE\tSEVERITY\tSERVICE\tTITLE\tREMEDIATION")
		for _, f := range res.Findings {
			_, _ = fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\n", f.RuleID, f.Severity, f.Service, f.Title, f.Remediation)
		}
		_ = w.Flush()
	},
}

func init() {
	owaspScanCmd.Flags().BoolVar(&owaspScanWAF, "waf", true, "Run benign SQLi/XSS/LFI/SSRF WAF enforcement probes")
	owaspScanCmd.Flags().BoolVar(&owaspScanZAP, "zap", false, "Also run OWASP ZAP Baseline container (requires Docker)")
	owaspCmd.AddCommand(owaspStatusCmd)
	owaspCmd.AddCommand(owaspScanCmd)
	owaspCmd.AddCommand(owaspLintCmd)
	rootCmd.AddCommand(owaspCmd)
}

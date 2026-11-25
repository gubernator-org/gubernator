package api

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/gubernator-org/gubernator/internal/db"
	"github.com/gubernator-org/gubernator/internal/security"
)

// SecurityOWASPStatusHandler returns live OWASP Security Suite compliance evaluation.
// @Summary Evaluate OWASP Security Suite compliance (Top 10, API, ASVS L2, Docker, LLM)
// @Tags security
// @Produce json
// @Success 200 {object} security.OWASPSummary
// @Router /v1/security/owasp/status [get]
func SecurityOWASPStatusHandler(c *gin.Context) {
	summary := security.EvaluateOWASPCompliance(db.DB)
	c.JSON(http.StatusOK, summary)
}

// SecurityOWASPReportHandler exports the OWASP compliance report in Markdown or JSON.
// @Summary Export OWASP compliance report
// @Tags security
// @Produce text/markdown
// @Param format query string false "markdown or json"
// @Router /v1/security/owasp/report [get]
func SecurityOWASPReportHandler(c *gin.Context) {
	summary := security.EvaluateOWASPCompliance(db.DB)
	format := strings.ToLower(c.DefaultQuery("format", "markdown"))
	ts := time.Now().Format("20060102-150405")
	if format == "json" {
		c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=owasp-compliance-report-%s.json", ts))
		c.JSON(http.StatusOK, summary)
		return
	}
	report := security.GenerateOWASPReport(summary, "markdown")
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=owasp-compliance-report-%s.md", ts))
	c.Data(http.StatusOK, "text/markdown; charset=utf-8", []byte(report))
}

// SecurityOWASPDASTScanHandler executes an active ethical OWASP WSTG DAST scan against a target URL.
// @Summary Run active OWASP WSTG DAST scan
// @Tags security
// @Accept json
// @Produce json
// @Param body body security.OWASPDASTRequest true "DAST Scan Target"
// @Success 200 {object} security.OWASPDASTResult
// @Router /v1/security/owasp/dast/scan [post]
func SecurityOWASPDASTScanHandler(c *gin.Context) {
	var req security.OWASPDASTRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid DAST scan request: " + err.Error()})
		return
	}
	res, err := security.RunOWASPDASTScan(req, c.GetString("username"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, res)
}

// SecurityOWASPDASTHistoryHandler returns recent OWASP DAST scan reports.
// @Summary List OWASP DAST scan history
// @Tags security
// @Produce json
// @Success 200 {array} security.OWASPDASTResult
// @Router /v1/security/owasp/dast/history [get]
func SecurityOWASPDASTHistoryHandler(c *gin.Context) {
	c.JSON(http.StatusOK, security.GetOWASPDASTHistory())
}

// SecurityOWASPComposeLintHandler statically audits a docker-compose.yml against OWASP Docker Top 10.
// @Summary Lint docker-compose.yml against OWASP Docker Security Top 10
// @Tags security
// @Accept json
// @Produce json
// @Success 200 {object} security.ComposeOWASPResult
// @Router /v1/security/owasp/compose-lint [post]
func SecurityOWASPComposeLintHandler(c *gin.Context) {
	var req struct {
		ComposeYAML string `json:"compose_yaml"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request: " + err.Error()})
		return
	}
	res := security.LintComposeOWASP(req.ComposeYAML)
	c.JSON(http.StatusOK, res)
}

// SecurityOWASPRemediateHandler applies a 1-click cluster auto-remediation for a specific OWASP control.
// @Summary Auto-remediate a specific OWASP control
// @Tags security
// @Produce json
// @Param id path string true "OWASP Control ID (e.g. owasp-a03, owasp-a05, owasp-a10)"
// @Success 200 {object} security.OWASPRemediationResult
// @Router /v1/security/owasp/remediate/{id} [post]
func SecurityOWASPRemediateHandler(c *gin.Context) {
	id := c.Param("id")
	res, err := security.RemediateOWASPControl(db.DB, id, c.GetString("username"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, res)
}

// SecurityOWASPRemediateAllHandler applies all safe, non-disruptive OWASP cluster remediations in 1 click.
// @Summary Auto-remediate all safe OWASP controls
// @Tags security
// @Produce json
// @Success 200 {object} security.OWASPRemediationResult
// @Router /v1/security/owasp/remediate-all [post]
func SecurityOWASPRemediateAllHandler(c *gin.Context) {
	res, err := security.RemediateAllSafeOWASP(db.DB, c.GetString("username"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, res)
}

// SecurityOWASPComposeHardenHandler automatically hardens a docker-compose.yml against OWASP Docker Top 10.
// @Summary Auto-harden docker-compose.yml against OWASP Docker Top 10
// @Tags security
// @Accept json
// @Produce json
// @Success 200 {object} security.OWASPComposeHardenResult
// @Router /v1/security/owasp/compose-harden [post]
func SecurityOWASPComposeHardenHandler(c *gin.Context) {
	var req struct {
		ComposeYAML string `json:"compose_yaml"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request: " + err.Error()})
		return
	}
	res, err := security.HardenComposeOWASP(req.ComposeYAML)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, res)
}

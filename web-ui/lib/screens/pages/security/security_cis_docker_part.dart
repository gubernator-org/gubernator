part of '../security_page.dart';

extension _SecurityCisDockerExt on _SecurityPageState {
  // ---------------------------------------------------------------------------
  // CIS DOCKER BENCHMARK V1.6.0 SUITE WIDGETS
  // ---------------------------------------------------------------------------

  void _openCISDockerReportDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final reportContent = await ApiService.fetchCISDockerReport(format: 'markdown');
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (reportContent == null || reportContent.isEmpty) {
      _showSnackBar("Failed to generate CIS Docker Benchmark report", isError: true);
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF6366F1), size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "CIS Docker Benchmark v1.6.0 Technical Compliance Report",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          content: SizedBox(
            width: 850,
            height: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      "Prescriptive auditor documentation formatted for ISO/IEC & SRE container audits",
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.25),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        reportContent,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text("Copy to Clipboard"),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: reportContent));
                _showSnackBar("CIS Docker Benchmark report copied to clipboard");
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.data_object, size: 16),
              label: const Text("Download JSON (.json)"),
              onPressed: () async {
                final jsonContent = await ApiService.fetchCISDockerReport(format: 'json');
                if (jsonContent != null && jsonContent.isNotEmpty) {
                  try {
                    final bytes = utf8.encode(jsonContent);
                    final blob = html.Blob([bytes], 'application/json');
                    final url = html.Url.createObjectUrlFromBlob(blob);
                    final now = DateTime.now();
                    final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
                    final filename = "cis-docker-benchmark-report-$dateStr.json";
                    html.AnchorElement(href: url)
                      ..setAttribute('download', filename)
                      ..click();
                    html.Url.revokeObjectUrl(url);
                    _showSnackBar("Report downloaded: $filename");
                  } catch (e) {
                    _showSnackBar("Error downloading JSON report: $e", isError: true);
                  }
                }
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              label: const Text("Download Markdown (.md)"),
              onPressed: () {
                try {
                  final bytes = utf8.encode(reportContent);
                  final blob = html.Blob([bytes], 'text/markdown');
                  final url = html.Url.createObjectUrlFromBlob(blob);
                  final now = DateTime.now();
                  final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
                  final filename = "cis-docker-benchmark-report-$dateStr.md";
                  html.AnchorElement(href: url)
                    ..setAttribute('download', filename)
                    ..click();
                  html.Url.revokeObjectUrl(url);
                  _showSnackBar("Report downloaded: $filename");
                } catch (e) {
                  _showSnackBar("Error downloading report: $e", isError: true);
                }
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  void _openCISRemediationDialog(CISDockerCheckModel check) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color statusColor;
    switch (check.status) {
      case "PASS":
        statusColor = const Color(0xFF10B981);
        break;
      case "WARN":
        statusColor = const Color(0xFFF59E0B);
        break;
      case "FAIL":
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFF3B82F6);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  check.id,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  check.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          content: SizedBox(
            width: 750,
            height: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadata Badges Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.folder_outlined, size: 14),
                        label: Text(check.section, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        avatar: Icon(check.isLevel1 ? Icons.looks_one_outlined : Icons.looks_two_outlined, size: 14),
                        label: Text(check.level, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        backgroundColor: (check.isLevel1 ? const Color(0xFF10B981) : const Color(0xFF8B5CF6)).withValues(alpha: 0.15),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(check.scored ? "Scored" : "Not Scored", style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          check.status,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Discovered Evidence
                  const Row(
                    children: [
                      Icon(Icons.terminal_rounded, size: 16, color: Colors.grey),
                      SizedBox(width: 6),
                      Text("Discovered Technical Evidence:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.25)),
                    ),
                    child: SelectableText(
                      check.evidence,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Audit Procedure
                  if (check.audit.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.fact_check_outlined, size: 16, color: Color(0xFF3B82F6)),
                            SizedBox(width: 6),
                            Text("Audit Verification Procedure:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: check.audit));
                            _showSnackBar("Audit procedure copied");
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.copy, size: 12, color: Color(0xFF3B82F6)),
                                SizedBox(width: 4),
                                Text("Copy", style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.25)),
                      ),
                      child: SelectableText(
                        check.audit,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Remediation
                  if (check.remediation.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.build_circle_outlined, size: 16, color: Color(0xFFF59E0B)),
                            SizedBox(width: 6),
                            Text("Prescriptive Remediation Steps:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: check.remediation));
                            _showSnackBar("Remediation steps copied");
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.copy, size: 12, color: Color(0xFFF59E0B)),
                                SizedBox(width: 4),
                                Text("Copy", style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                      ),
                      child: SelectableText(
                        check.remediation,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (check.remediation.isNotEmpty)
              ElevatedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
                label: const Text("Copy Remediation"),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: check.remediation));
                  _showSnackBar("Remediation copied to clipboard");
                },
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCISDockerDashboardTab(bool isDark, Color primaryColor) {
    if (_cisLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Evaluating CIS Docker Benchmark v1.6.0 compliance...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_cisError != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Text("Error loading CIS Docker audit: $_cisError", style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadCISStatus,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _cisSummary;
    if (summary == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text("No CIS Docker audit data available"),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadCISStatus, child: const Text("Evaluate Now")),
          ],
        ),
      );
    }

    final filteredChecks = summary.checks.where((c) {
      // Section filter
      if (_cisSectionFilter != "ALL") {
        if (!c.id.startsWith("$_cisSectionFilter.") && !c.section.startsWith(_cisSectionFilter)) {
          return false;
        }
      }
      // Level filter
      if (_cisLevelFilter != "ALL") {
        if (_cisLevelFilter == "Level 1" && !c.isLevel1) return false;
        if (_cisLevelFilter == "Level 2" && !c.isLevel2) return false;
      }
      // Status filter
      if (_cisStatusFilter == "ISSUES") {
        return !c.isPass;
      } else if (_cisStatusFilter != "ALL") {
        return c.status == _cisStatusFilter;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCISDockerHeaderBanner(isDark, primaryColor, summary),
          const SizedBox(height: 16),
          _buildCISDockerKPICards(isDark, summary),
          const SizedBox(height: 20),
          _buildCISDockerControlsBar(isDark, primaryColor, summary),
          const SizedBox(height: 14),
          if (filteredChecks.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text(
                "No recommendations match the selected filters.",
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            )
          else
            ...filteredChecks.map((check) => _buildCISDockerCheckCard(isDark, primaryColor, check)),
        ],
      ),
    );
  }

  Widget _buildCISDockerHeaderBanner(bool isDark, Color primaryColor, CISDockerSummaryModel summary) {
    const bannerColor = Color(0xFF6366F1);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFF1F5F9), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: bannerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bannerColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline_rounded, color: bannerColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "CIS Docker Benchmark v1.6.0",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: bannerColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "HARDENING STANDARD",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: bannerColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Prescriptive consensus-based security benchmark for Docker Engine, host operating systems, daemon configurations, and runtime container isolation.",
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: _loadCISStatus,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("Re-Audit"),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _openCISDockerReportDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: bannerColor,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.description_outlined, size: 16),
            label: const Text("Export Audit Report"),
          ),
        ],
      ),
    );
  }

  Widget _buildCISDockerKPICards(bool isDark, CISDockerSummaryModel summary) {
    Color gradeColor;
    String gradeEmoji;
    switch (summary.postureGrade) {
      case "A+":
      case "A":
        gradeColor = const Color(0xFF10B981);
        gradeEmoji = "🏆";
        break;
      case "B":
        gradeColor = const Color(0xFF3B82F6);
        gradeEmoji = "🛡️";
        break;
      case "C":
        gradeColor = const Color(0xFFF59E0B);
        gradeEmoji = "⚡";
        break;
      default:
        gradeColor = const Color(0xFFEF4444);
        gradeEmoji = "⚠️";
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            // KPI 1: Posture Grade
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: gradeColor.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "POSTURE GRADE",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        Text(gradeEmoji, style: const TextStyle(fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: gradeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        summary.postureGrade,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: gradeColor,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "CIS v1.6.0 Consensus",
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black45),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // KPI 2: Overall Compliance Score
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "COMPLIANCE SCORE",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        Icon(Icons.speed_rounded, size: 18, color: Color(0xFF6366F1)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${summary.scorePercent.toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: summary.scorePercent / 100.0,
                        backgroundColor: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // KPI 3: Level 1 (Baseline)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "LEVEL 1 BASELINE",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        Icon(Icons.looks_one_rounded, size: 18, color: Color(0xFF10B981)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${summary.level1Score.toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: summary.level1Score / 100.0,
                        backgroundColor: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // KPI 4: Level 2 (Defense in Depth)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "LEVEL 2 DEFENSE",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        Icon(Icons.looks_two_rounded, size: 18, color: Color(0xFF8B5CF6)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${summary.level2Score.toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: summary.level2Score / 100.0,
                        backgroundColor: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCISDockerControlsBar(bool isDark, Color primaryColor, CISDockerSummaryModel summary) {
    const sections = [
      {"id": "ALL", "label": "All Sections"},
      {"id": "1", "label": "1. Host"},
      {"id": "2", "label": "2. Daemon"},
      {"id": "3", "label": "3. Files"},
      {"id": "4", "label": "4. Images"},
      {"id": "5", "label": "5. Runtime"},
      {"id": "6", "label": "6. Ops"},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Section Chips
          const Text("Section:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ...sections.map((sec) {
            final isSelected = _cisSectionFilter == sec["id"];
            return ChoiceChip(
              label: Text(
                sec["id"] == "ALL" ? "All (${summary.totalChecks})" : sec["label"]!,
                style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
              side: BorderSide(
                color: isSelected ? const Color(0xFF6366F1) : (isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.3)),
              ),
              onSelected: (val) {
                if (val) _updateState(() => _cisSectionFilter = sec["id"]!);
              },
            );
          }),

          const SizedBox(width: 6),
          // Level Chips
          const Text("Level:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ChoiceChip(
            label: const Text("All", style: TextStyle(fontSize: 11)),
            selected: _cisLevelFilter == "ALL",
            selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _cisLevelFilter = "ALL");
            },
          ),
          ChoiceChip(
            label: const Text("Level 1", style: TextStyle(fontSize: 11)),
            selected: _cisLevelFilter == "Level 1",
            selectedColor: const Color(0xFF10B981).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _cisLevelFilter = "Level 1");
            },
          ),
          ChoiceChip(
            label: const Text("Level 2", style: TextStyle(fontSize: 11)),
            selected: _cisLevelFilter == "Level 2",
            selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _cisLevelFilter = "Level 2");
            },
          ),

          const SizedBox(width: 6),
          // Status Chips
          const Text("Status:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ChoiceChip(
            label: const Text("All", style: TextStyle(fontSize: 11)),
            selected: _cisStatusFilter == "ALL",
            selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _cisStatusFilter = "ALL");
            },
          ),
          ChoiceChip(
            label: Text("Action Required (${summary.warnCount + summary.failCount})", style: const TextStyle(fontSize: 11)),
            selected: _cisStatusFilter == "ISSUES",
            selectedColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _cisStatusFilter = "ISSUES");
            },
          ),
          ChoiceChip(
            label: Text("PASS (${summary.passCount})", style: const TextStyle(fontSize: 11)),
            selected: _cisStatusFilter == "PASS",
            selectedColor: const Color(0xFF10B981).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _cisStatusFilter = "PASS");
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCISDockerCheckCard(bool isDark, Color primaryColor, CISDockerCheckModel check) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (check.status) {
      case "PASS":
        statusColor = const Color(0xFF10B981);
        statusText = "PASS";
        statusIcon = Icons.check_circle_rounded;
        break;
      case "WARN":
        statusColor = const Color(0xFFF59E0B);
        statusText = "WARN";
        statusIcon = Icons.warning_amber_rounded;
        break;
      case "FAIL":
        statusColor = const Color(0xFFEF4444);
        statusText = "FAIL";
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = const Color(0xFF3B82F6);
        statusText = "INFO";
        statusIcon = Icons.info_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: check.isPass
              ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2))
              : statusColor.withValues(alpha: 0.4),
          width: check.isPass ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Check ID, Section, Level, Scored, Title, Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  check.id,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (check.isLevel1 ? const Color(0xFF10B981) : const Color(0xFF8B5CF6)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  check.level,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: check.isLevel1 ? const Color(0xFF10B981) : const Color(0xFF8B5CF6),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      check.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      check.section,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                tooltip: "Inspect Details & Remediation",
                onPressed: () => _openCISRemediationDialog(check),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Discovered Technical Evidence Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.terminal_rounded, size: 15, color: Colors.grey),
                    SizedBox(width: 6),
                    Text(
                      "Discovered Technical Evidence:",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  check.evidence,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Remediation guidance if not PASS
          if (check.remediation.isNotEmpty && !check.isPass) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Actionable Remediation Guidance:",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          check.remediation,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text("Copy Fix", style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: check.remediation));
                      _showSnackBar("Remediation copied to clipboard");
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

}

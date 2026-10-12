part of '../security_page.dart';

extension _SecurityIsoDoraExt on _SecurityPageState {
  // ---------------------------------------------------------------------------
  // ISO/IEC 27001:2022 ANNEX A COMPLIANCE TAB & COMPONENTS
  // ---------------------------------------------------------------------------

  void _openISO27001ReportDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final reportContent = await ApiService.fetchISO27001Report(format: 'text');
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (reportContent == null || reportContent.isEmpty) {
      _showSnackBar("Failed to generate ISO/IEC 27001 audit report", isError: true);
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
              const Icon(Icons.verified_user_rounded, color: Color(0xFF8B5CF6), size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "ISO/IEC 27001:2022 Statement of Applicability (SoA) & Audit Report",
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
                      "Official Statement of Applicability formatted for ISO/IEC 27001 lead auditors and SRE teams",
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
                _showSnackBar("ISO/IEC 27001 Statement of Applicability copied to clipboard");
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.data_object, size: 16),
              label: const Text("Download JSON (.json)"),
              onPressed: () async {
                final jsonContent = await ApiService.fetchISO27001Report(format: 'json');
                if (jsonContent != null && jsonContent.isNotEmpty) {
                  try {
                    final bytes = utf8.encode(jsonContent);
                    final blob = html.Blob([bytes], 'application/json');
                    final url = html.Url.createObjectUrlFromBlob(blob);
                    final now = DateTime.now();
                    final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
                    final filename = "iso-27001-audit-report-$dateStr.json";
                    html.AnchorElement(href: url)
                      ..setAttribute('download', filename)
                      ..click();
                    html.Url.revokeObjectUrl(url);
                    _showSnackBar("Downloaded $filename");
                  } catch (e) {
                    _showSnackBar("Download failed: $e", isError: true);
                  }
                }
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download, size: 16),
              label: const Text("Download SoA (.txt)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                try {
                  final bytes = utf8.encode(reportContent);
                  final blob = html.Blob([bytes], 'text/plain;charset=utf-8');
                  final url = html.Url.createObjectUrlFromBlob(blob);
                  final now = DateTime.now();
                  final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
                  final filename = "iso-27001-soa-report-$dateStr.txt";
                  html.AnchorElement(href: url)
                    ..setAttribute('download', filename)
                    ..click();
                  html.Url.revokeObjectUrl(url);
                  _showSnackBar("Downloaded $filename");
                } catch (e) {
                  _showSnackBar("Download failed: $e", isError: true);
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

  void _openISO27001RemediationDialog(ISO27001ControlModel control) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) {
        Color statusColor = const Color(0xFFEF4444);
        String statusLabel = "NON-COMPLIANT";
        if (control.isCompliant) {
          statusColor = const Color(0xFF10B981);
          statusLabel = "COMPLIANT";
        } else if (control.isPartial) {
          statusColor = const Color(0xFFF59E0B);
          statusLabel = "PARTIAL COMPLIANCE";
        }

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                ),
                child: Text(
                  control.id,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF8B5CF6)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  control.title,
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
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          control.theme,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "$statusLabel (${control.score.toStringAsFixed(0)}%)",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. Requirement
                  const Text("1. ISO/IEC 27001:2022 Annex A Requirement", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(control.description, style: const TextStyle(fontSize: 12.5, height: 1.4)),
                  ),
                  const SizedBox(height: 14),

                  // 2. Discovered Evidence
                  const Text("2. Discovered Cluster Evidence", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                    child: Text(
                      control.evidence,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Remediation
                  const Text("3. Prescriptive Remediation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF59E0B))),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(control.remediation, style: const TextStyle(fontSize: 12.5, height: 1.4)),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.copy, size: 14),
                            label: const Text("Copy Fix", style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF59E0B),
                              side: const BorderSide(color: Color(0xFFF59E0B)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: control.remediation));
                              _showSnackBar("Remediation copied to clipboard");
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Auditor Procedure
                  const Text("4. Auditor Verification Guide", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3B82F6))),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      control.audit,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Done"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildISO27001DashboardTab(bool isDark, Color primaryColor) {
    if (_isoLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Evaluating ISO/IEC 27001:2022 Annex A compliance...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_isoError != null) {
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
              Text("Error loading ISO/IEC 27001 evaluation: $_isoError", style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadISO27001Status,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _isoSummary;
    if (summary == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text("No ISO/IEC 27001 evaluation data available"),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadISO27001Status, child: const Text("Evaluate Now")),
          ],
        ),
      );
    }

    final filteredControls = summary.controls.where((c) {
      // Theme filter
      if (_isoThemeFilter != "ALL") {
        if (_isoThemeFilter == "A.5" && !c.isThemeA5) return false;
        if (_isoThemeFilter == "A.8" && !c.isThemeA8) return false;
      }
      // Status filter
      if (_isoStatusFilter == "ISSUES") {
        return !c.isCompliant;
      } else if (_isoStatusFilter != "ALL") {
        return c.status == _isoStatusFilter;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildISO27001HeaderBanner(isDark, primaryColor, summary),
          const SizedBox(height: 16),
          _buildISO27001KPICards(isDark, summary),
          const SizedBox(height: 20),
          _buildISO27001ControlsBar(isDark, primaryColor, summary),
          const SizedBox(height: 14),
          if (filteredControls.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text(
                "No controls match the selected filters.",
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            )
          else
            ...filteredControls.map((control) => _buildISO27001ControlCard(isDark, primaryColor, control)),
        ],
      ),
    );
  }

  Widget _buildISO27001HeaderBanner(bool isDark, Color primaryColor, ISO27001SummaryModel summary) {
    const bannerColor = Color(0xFF8B5CF6);
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
            child: const Icon(Icons.language_rounded, color: bannerColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "ISO/IEC 27001:2022 (Annex A Controls)",
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
                        "GLOBAL ENTERPRISE STANDARD",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: bannerColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "International Information Security Management System (ISMS) compliance for cloud-native container workloads across Organizational (A.5) and Technological (A.8) control themes.",
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: _loadISO27001Status,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("Re-Audit"),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _openISO27001ReportDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: bannerColor,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.description_outlined, size: 16),
            label: const Text("Export SoA Report"),
          ),
        ],
      ),
    );
  }

  Widget _buildISO27001KPICards(bool isDark, ISO27001SummaryModel summary) {
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
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey),
                        ),
                        Text(gradeEmoji, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          summary.postureGrade,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: gradeColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          summary.postureGrade == "A+" || summary.postureGrade == "A"
                              ? "EXCELLENT"
                              : (summary.postureGrade == "B" ? "GOOD" : "ATTENTION"),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: gradeColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${summary.compliantCount}/${summary.totalControls} Controls Compliant",
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // KPI 2: Overall Readiness Score
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
                    const Text(
                      "READINESS SCORE",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${summary.overallScore.toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (summary.overallScore / 100.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // KPI 3: Theme A.5 Organizational
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
                    const Text(
                      "THEME A.5 (ORGANIZATIONAL)",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${summary.themeA5Score.toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (summary.themeA5Score / 100.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // KPI 4: Theme A.8 Technological
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
                    const Text(
                      "THEME A.8 (TECHNOLOGICAL)",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${summary.themeA8Score.toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (summary.themeA8Score / 100.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                        minHeight: 6,
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

  Widget _buildISO27001ControlsBar(bool isDark, Color primaryColor, ISO27001SummaryModel summary) {
    const bannerColor = Color(0xFF8B5CF6);
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
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Theme chips
          const Text("Theme:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ChoiceChip(
            label: Text("All (${summary.totalControls})", style: const TextStyle(fontSize: 11)),
            selected: _isoThemeFilter == "ALL",
            selectedColor: bannerColor.withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _isoThemeFilter = "ALL");
            },
          ),
          ChoiceChip(
            label: const Text("A.5 Organizational", style: TextStyle(fontSize: 11)),
            selected: _isoThemeFilter == "A.5",
            selectedColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _isoThemeFilter = "A.5");
            },
          ),
          ChoiceChip(
            label: const Text("A.8 Technological", style: TextStyle(fontSize: 11)),
            selected: _isoThemeFilter == "A.8",
            selectedColor: const Color(0xFF10B981).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _isoThemeFilter = "A.8");
            },
          ),

          const SizedBox(width: 8),
          // Status chips
          const Text("Status:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ChoiceChip(
            label: const Text("All", style: TextStyle(fontSize: 11)),
            selected: _isoStatusFilter == "ALL",
            selectedColor: bannerColor.withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _isoStatusFilter = "ALL");
            },
          ),
          ChoiceChip(
            label: Text("Action Required (${summary.partialCount + summary.nonCompliantCount})", style: const TextStyle(fontSize: 11)),
            selected: _isoStatusFilter == "ISSUES",
            selectedColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _isoStatusFilter = "ISSUES");
            },
          ),
          ChoiceChip(
            label: Text("Compliant (${summary.compliantCount})", style: const TextStyle(fontSize: 11)),
            selected: _isoStatusFilter == "COMPLIANT",
            selectedColor: const Color(0xFF10B981).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _isoStatusFilter = "COMPLIANT");
            },
          ),
          ChoiceChip(
            label: Text("Partial (${summary.partialCount})", style: const TextStyle(fontSize: 11)),
            selected: _isoStatusFilter == "PARTIAL",
            selectedColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _isoStatusFilter = "PARTIAL");
            },
          ),
          ChoiceChip(
            label: Text("Non-Compliant (${summary.nonCompliantCount})", style: const TextStyle(fontSize: 11)),
            selected: _isoStatusFilter == "NON_COMPLIANT",
            selectedColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _isoStatusFilter = "NON_COMPLIANT");
            },
          ),
        ],
      ),
    );
  }

  Widget _buildISO27001ControlCard(bool isDark, Color primaryColor, ISO27001ControlModel control) {
    Color statusColor = const Color(0xFFEF4444);
    IconData statusIcon = Icons.cancel_rounded;
    String statusText = "NON-COMPLIANT";

    if (control.isCompliant) {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle_rounded;
      statusText = "COMPLIANT";
    } else if (control.isPartial) {
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.warning_rounded;
      statusText = "PARTIAL";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                ),
                child: Text(
                  control.id,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF8B5CF6)),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: control.isThemeA5 ? const Color(0xFF3B82F6).withValues(alpha: 0.1) : const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  control.theme,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: control.isThemeA5 ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.build_circle_outlined, size: 14),
                label: const Text("Remediation", style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8B5CF6),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: () => _openISO27001RemediationDialog(control),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            control.title,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            control.description,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 10),

          // Discovered Evidence
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      "DISCOVERED CLUSTER EVIDENCE:",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  control.evidence,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Actionable remediation box if not fully compliant
          if (control.remediation.isNotEmpty && !control.isCompliant) ...[
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
                          control.remediation,
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
                      Clipboard.setData(ClipboardData(text: control.remediation));
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

  // =========================================================================
  // DORA COMPLIANCE (REGULATION EU 2022/2554) DASHBOARD & REPORTING
  // =========================================================================

  void _openDORAReportDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final reportContent = await ApiService.fetchDORAReport(format: 'markdown');
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (reportContent == null || reportContent.isEmpty) {
      _showSnackBar("Failed to generate DORA operational resilience report", isError: true);
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
              const Icon(Icons.account_balance_rounded, color: Color(0xFFF59E0B), size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "EU DORA (Regulation 2022/2554) Operational Resilience Audit Report",
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
                      "Statutory audit document formatted for financial entities, competent authorities, and lead auditors",
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
                _showSnackBar("DORA Operational Resilience Report copied to clipboard");
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.data_object, size: 16),
              label: const Text("Download JSON (.json)"),
              onPressed: () async {
                final jsonContent = await ApiService.fetchDORAReport(format: 'json');
                if (jsonContent != null && jsonContent.isNotEmpty) {
                  try {
                    final bytes = utf8.encode(jsonContent);
                    final blob = html.Blob([bytes], 'application/json');
                    final url = html.Url.createObjectUrlFromBlob(blob);
                    final now = DateTime.now();
                    final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
                    final filename = "dora-compliance-report-$dateStr.json";
                    html.AnchorElement(href: url)
                      ..setAttribute('download', filename)
                      ..click();
                    html.Url.revokeObjectUrl(url);
                    _showSnackBar("Downloaded $filename");
                  } catch (e) {
                    _showSnackBar("Download failed: $e", isError: true);
                  }
                }
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download, size: 16),
              label: const Text("Download Report (.md)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                try {
                  final bytes = utf8.encode(reportContent);
                  final blob = html.Blob([bytes], 'text/markdown;charset=utf-8');
                  final url = html.Url.createObjectUrlFromBlob(blob);
                  final now = DateTime.now();
                  final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
                  final filename = "dora-compliance-report-$dateStr.md";
                  html.AnchorElement(href: url)
                    ..setAttribute('download', filename)
                    ..click();
                  html.Url.revokeObjectUrl(url);
                  _showSnackBar("Downloaded $filename");
                } catch (e) {
                  _showSnackBar("Download failed: $e", isError: true);
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

  void _openDORARemediationDialog(DORAMeasureModel measure) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) {
        Color statusColor = const Color(0xFFEF4444);
        String statusLabel = "NON-COMPLIANT";
        if (measure.isCompliant) {
          statusColor = const Color(0xFF10B981);
          statusLabel = "COMPLIANT";
        } else if (measure.isPartial) {
          statusColor = const Color(0xFFF59E0B);
          statusLabel = "PARTIAL COMPLIANCE";
        }

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Text(
                  measure.id,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF59E0B)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  measure.title,
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
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatDORAPillarName(measure.pillar),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          measure.article,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "$statusLabel (${measure.score.toStringAsFixed(0)}%)",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. Requirement
                  const Text("1. DORA Regulatory Requirement & Objective", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(measure.description, style: const TextStyle(fontSize: 12.5, height: 1.4)),
                  ),
                  const SizedBox(height: 14),

                  // 2. Discovered Evidence
                  const Text("2. Discovered Cluster Evidence", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                    child: Text(
                      measure.evidence,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Remediation
                  const Text("3. Prescriptive Remediation & Operational Guidance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF59E0B))),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(measure.remediation, style: const TextStyle(fontSize: 12.5, height: 1.4)),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.copy, size: 14),
                            label: const Text("Copy Fix", style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF59E0B),
                              side: const BorderSide(color: Color(0xFFF59E0B)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: measure.remediation));
                              _showSnackBar("Remediation copied to clipboard");
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Done"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDORADashboardTab(bool isDark, Color primaryColor) {
    if (_doraLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFF59E0B))),
            SizedBox(height: 16),
            Text("Evaluating EU DORA (Regulation 2022/2554) operational resilience...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_doraError != null) {
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
              Text("Error loading DORA evaluation: $_doraError", style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDORAStatus,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _doraSummary;
    if (summary == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text("No DORA evaluation data available"),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadDORAStatus, child: const Text("Evaluate Now")),
          ],
        ),
      );
    }

    final filteredMeasures = summary.measures.where((m) {
      if (_doraPillarFilter != "ALL") {
        if (!m.pillar.startsWith(_doraPillarFilter)) return false;
      }
      if (_doraStatusFilter == "ISSUES") {
        return !m.isCompliant;
      } else if (_doraStatusFilter != "ALL") {
        return m.status == _doraStatusFilter;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDORAHeaderBanner(isDark, primaryColor, summary),
          const SizedBox(height: 16),
          _buildDORAKPICards(isDark, summary),
          const SizedBox(height: 20),
          _buildDORAControlsBar(isDark, primaryColor, summary),
          const SizedBox(height: 14),
          if (filteredMeasures.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text(
                "No measures match the selected filters.",
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            )
          else
            ...filteredMeasures.map((measure) => _buildDORAMeasureCard(isDark, primaryColor, measure)),
        ],
      ),
    );
  }

  Widget _buildDORAHeaderBanner(bool isDark, Color primaryColor, DORASummaryModel summary) {
    const bannerColor = Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFFFFBEB), Colors.white],
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
            child: const Icon(Icons.account_balance_rounded, color: bannerColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "EU DORA — Regulation (EU) 2022/2554",
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
                        "FINANCIAL SECTOR STATUTORY STANDARD",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: bannerColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Digital Operational Resilience Act compliance for financial entities and cloud ICT providers. Continuous cluster verification across ICT Risk, Incident Reporting, Resilience Testing, Third-Party Risk, and Supervisory Oversight.",
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: _loadDORAStatus,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("Re-Audit"),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _openDORAReportDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: bannerColor,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.description_outlined, size: 16),
            label: const Text("Export DORA Report"),
          ),
        ],
      ),
    );
  }

  Widget _buildDORAKPICards(bool isDark, DORASummaryModel summary) {
    Color readinessColor;
    String readinessEmoji;
    switch (summary.overallReadiness) {
      case "HIGH":
        readinessColor = const Color(0xFF10B981);
        readinessEmoji = "🏆";
        break;
      case "MEDIUM":
        readinessColor = const Color(0xFF3B82F6);
        readinessEmoji = "🛡️";
        break;
      case "BASIC":
        readinessColor = const Color(0xFFF59E0B);
        readinessEmoji = "⚡";
        break;
      default:
        readinessColor = const Color(0xFFEF4444);
        readinessEmoji = "⚠️";
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            // KPI 1: Overall Readiness
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: readinessColor.withValues(alpha: 0.35),
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
                          "READINESS POSTURE",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey),
                        ),
                        Text(readinessEmoji, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          summary.overallReadiness,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: readinessColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${summary.overallScore.toStringAsFixed(1)}%",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: readinessColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${summary.compliantCount}/${summary.totalMeasures} Measures Compliant",
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // KPI 2: Pillar 1 ICT Risk
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
                    const Text(
                      "P1: ICT RISK (ART. 5-16)",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${summary.pillar1Score.toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (summary.pillar1Score / 100.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // KPI 3: Pillar 2 Incident Mgmt
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
                    const Text(
                      "P2: INCIDENTS (ART. 17-23)",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${summary.pillar2Score.toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (summary.pillar2Score / 100.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // KPI 4: Pillar 3 Resilience Testing
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
                    const Text(
                      "P3: TESTING (ART. 24-27)",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${summary.pillar3Score.toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (summary.pillar3Score / 100.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // KPI 5: Pillar 4 & 5 Third-Party & Oversight
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
                    const Text(
                      "P4/P5: 3RD-PARTY & SHARING",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${(((summary.pillar4Score + summary.pillar5Score) / 2)).toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (((summary.pillar4Score + summary.pillar5Score) / 200.0)).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
                        minHeight: 6,
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

  Widget _buildDORAControlsBar(bool isDark, Color primaryColor, DORASummaryModel summary) {
    const bannerColor = Color(0xFFF59E0B);
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
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Pillar chips
          const Text("Pillar:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ChoiceChip(
            label: Text("All (${summary.totalMeasures})", style: const TextStyle(fontSize: 11)),
            selected: _doraPillarFilter == "ALL",
            selectedColor: bannerColor.withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _doraPillarFilter = "ALL");
            },
          ),
          ChoiceChip(
            label: const Text("P1 ICT Risk", style: TextStyle(fontSize: 11)),
            selected: _doraPillarFilter == "PILLAR_1",
            selectedColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _doraPillarFilter = "PILLAR_1");
            },
          ),
          ChoiceChip(
            label: const Text("P2 Incidents", style: TextStyle(fontSize: 11)),
            selected: _doraPillarFilter == "PILLAR_2",
            selectedColor: const Color(0xFF10B981).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _doraPillarFilter = "PILLAR_2");
            },
          ),
          ChoiceChip(
            label: const Text("P3 Testing", style: TextStyle(fontSize: 11)),
            selected: _doraPillarFilter == "PILLAR_3",
            selectedColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _doraPillarFilter = "PILLAR_3");
            },
          ),
          ChoiceChip(
            label: const Text("P4 3rd-Party", style: TextStyle(fontSize: 11)),
            selected: _doraPillarFilter == "PILLAR_4",
            selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _doraPillarFilter = "PILLAR_4");
            },
          ),
          ChoiceChip(
            label: const Text("P5 Oversight", style: TextStyle(fontSize: 11)),
            selected: _doraPillarFilter == "PILLAR_5",
            selectedColor: const Color(0xFFEC4899).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _doraPillarFilter = "PILLAR_5");
            },
          ),

          const SizedBox(width: 8),
          // Status chips
          const Text("Status:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ChoiceChip(
            label: const Text("All", style: TextStyle(fontSize: 11)),
            selected: _doraStatusFilter == "ALL",
            selectedColor: bannerColor.withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _doraStatusFilter = "ALL");
            },
          ),
          ChoiceChip(
            label: Text("Action Required (${summary.partialCount + summary.nonCompliantCount})", style: const TextStyle(fontSize: 11)),
            selected: _doraStatusFilter == "ISSUES",
            selectedColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _doraStatusFilter = "ISSUES");
            },
          ),
          ChoiceChip(
            label: Text("Compliant (${summary.compliantCount})", style: const TextStyle(fontSize: 11)),
            selected: _doraStatusFilter == "COMPLIANT",
            selectedColor: const Color(0xFF10B981).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _doraStatusFilter = "COMPLIANT");
            },
          ),
          ChoiceChip(
            label: Text("Partial (${summary.partialCount})", style: const TextStyle(fontSize: 11)),
            selected: _doraStatusFilter == "PARTIAL",
            selectedColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _doraStatusFilter = "PARTIAL");
            },
          ),
          ChoiceChip(
            label: Text("Non-Compliant (${summary.nonCompliantCount})", style: const TextStyle(fontSize: 11)),
            selected: _doraStatusFilter == "NON_COMPLIANT",
            selectedColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
            onSelected: (val) {
              if (val) _updateState(() => _doraStatusFilter = "NON_COMPLIANT");
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDORAMeasureCard(bool isDark, Color primaryColor, DORAMeasureModel measure) {
    Color statusColor = const Color(0xFFEF4444);
    IconData statusIcon = Icons.cancel_rounded;
    String statusText = "NON-COMPLIANT";

    if (measure.isCompliant) {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle_rounded;
      statusText = "COMPLIANT";
    } else if (measure.isPartial) {
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.warning_rounded;
      statusText = "PARTIAL";
    }

    Color pillarColor = const Color(0xFF3B82F6);
    if (measure.pillar.startsWith("PILLAR_2")) pillarColor = const Color(0xFF10B981);
    if (measure.pillar.startsWith("PILLAR_3")) pillarColor = const Color(0xFFF59E0B);
    if (measure.pillar.startsWith("PILLAR_4")) pillarColor = const Color(0xFF8B5CF6);
    if (measure.pillar.startsWith("PILLAR_5")) pillarColor = const Color(0xFFEC4899);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Text(
                  measure.id,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFF59E0B)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: pillarColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDORAPillarName(measure.pillar),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: pillarColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  measure.article,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.build_circle_outlined, size: 14),
                label: const Text("Remediation", style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF59E0B),
                  side: const BorderSide(color: Color(0xFFF59E0B)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: () => _openDORARemediationDialog(measure),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            measure.title,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            measure.description,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 10),

          // Discovered Evidence
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      "DISCOVERED CLUSTER EVIDENCE:",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  measure.evidence,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Actionable remediation box if not fully compliant
          if (measure.remediation.isNotEmpty && !measure.isCompliant) ...[
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
                          measure.remediation,
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
                      Clipboard.setData(ClipboardData(text: measure.remediation));
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

  String _formatDORAPillarName(String pillar) {
    switch (pillar) {
      case "PILLAR_1_ICT_RISK":
        return "Pillar 1: ICT Risk Management";
      case "PILLAR_2_INCIDENT_MGMT":
        return "Pillar 2: Incident Reporting & SIEM";
      case "PILLAR_3_RESILIENCE_TESTING":
        return "Pillar 3: Resilience Testing & Failover";
      case "PILLAR_4_THIRD_PARTY_RISK":
        return "Pillar 4: Third-Party & Cloud Exit";
      case "PILLAR_5_INFO_SHARING":
        return "Pillar 5: Information Sharing";
      default:
        return pillar;
    }
  }
}

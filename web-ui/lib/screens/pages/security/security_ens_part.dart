part of '../security_page.dart';

extension _SecurityEnsExt on _SecurityPageState {
  // ---------------------------------------------------------------------------
  // ESQUEMA NACIONAL DE SEGURIDAD (ENS RD 311/2022) SUB-DASHBOARD
  // ---------------------------------------------------------------------------

  void _openENSReportDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final reportContent = await ApiService.fetchENSReport(format: 'markdown');
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (reportContent == null || reportContent.isEmpty) {
      _showSnackBar("Error generating ENS technical report", isError: true);
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
              const Icon(Icons.verified_user_rounded, color: Color(0xFF14B8A6), size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "ENS Technical Compliance Report (RD 311/2022)",
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
                      "Technical evidence formatted in CommonMark ready for CCN-STIC audits",
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
                _showSnackBar("ENS report copied to clipboard");
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
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
                  final filename = "informe-cumplimiento-ens-$dateStr.md";
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

  Widget _buildENSDashboardTab(bool isDark, Color primaryColor) {
    if (_ensLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Evaluating ENS compliance (RD 311/2022)...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_ensError != null) {
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
              Text("Error loading ENS audit: $_ensError", style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadENSStatus,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _ensSummary;
    if (summary == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text("No ENS audit data available"),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadENSStatus, child: const Text("Evaluate Now")),
          ],
        ),
      );
    }

    final filteredMeasures = summary.measures.where((m) {
      if (_ensLevelFilter == "BASICO") {
        return m.applicableLevels.contains("BASICO");
      } else if (_ensLevelFilter == "MEDIO") {
        return m.applicableLevels.contains("MEDIO");
      } else if (_ensLevelFilter == "ALTO") {
        return m.applicableLevels.contains("ALTO");
      } else if (_ensLevelFilter == "ISSUES") {
        return m.status != "COMPLIANT";
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildENSHeaderBanner(isDark, primaryColor, summary),
          const SizedBox(height: 16),
          _buildENSKPICards(isDark, summary),
          const SizedBox(height: 20),
          _buildENSControlsBar(isDark, primaryColor, summary),
          const SizedBox(height: 14),
          if (filteredMeasures.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text(
                "No measures match the selected filter.",
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            )
          else
            ...filteredMeasures.map((measure) => _buildENSMeasureCard(isDark, primaryColor, measure)),
        ],
      ),
    );
  }

  Widget _buildENSHeaderBanner(bool isDark, Color primaryColor, ENSSummaryModel summary) {
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
          color: const Color(0xFF14B8A6).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF14B8A6), size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "National Security Framework (ENS - RD 311/2022)",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "Real Decreto 311/2022",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF14B8A6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Automated technical audit of orchestrator operational and protection controls according to CCN-STIC guidelines.",
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: _loadENSStatus,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("Refresh"),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14B8A6),
              foregroundColor: Colors.white,
            ),
            onPressed: _openENSReportDialog,
            icon: const Icon(Icons.description_outlined, size: 16),
            label: const Text("Export Report"),
          ),
        ],
      ),
    );
  }

  Widget _buildENSKPICards(bool isDark, ENSSummaryModel summary) {
    Color categoryColor;
    String categoryEmoji;
    switch (summary.overallCategory) {
      case "ALTO":
        categoryColor = const Color(0xFF14B8A6);
        categoryEmoji = "🏆";
        break;
      case "MEDIO":
        categoryColor = const Color(0xFF10B981);
        categoryEmoji = "🛡️";
        break;
      case "BASICO":
        categoryColor = const Color(0xFFF59E0B);
        categoryEmoji = "⚡";
        break;
      default:
        categoryColor = const Color(0xFFEF4444);
        categoryEmoji = "⚠️";
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            // KPI 1: Overall Category
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: categoryColor.withValues(alpha: 0.35),
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
                          "OVERALL CATEGORY",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        Text(categoryEmoji, style: const TextStyle(fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        summary.overallCategory,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: categoryColor,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Status: ${summary.clusterStatus} • Evaluated",
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black45),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // KPI 2: BASIC Score
            Expanded(
              child: _buildScoreKPICard(
                isDark: isDark,
                title: "BASIC TIER",
                score: summary.basicoScore,
                threshold: 100.0,
                color: const Color(0xFFF59E0B),
                subtitle: summary.basicoScore >= 100.0 ? "100% Compliant" : "Pending measures",
              ),
            ),
            const SizedBox(width: 12),

            // KPI 3: MEDIO Score
            Expanded(
              child: _buildScoreKPICard(
                isDark: isDark,
                title: "MEDIUM TIER",
                score: summary.medioScore,
                threshold: 85.0,
                color: const Color(0xFF10B981),
                subtitle: summary.medioScore >= 85.0 ? "Passes threshold (≥85%)" : "Partial rating",
              ),
            ),
            const SizedBox(width: 12),

            // KPI 4: ALTO Score
            Expanded(
              child: _buildScoreKPICard(
                isDark: isDark,
                title: "HIGH TIER",
                score: summary.altoScore,
                threshold: 80.0,
                color: const Color(0xFF14B8A6),
                subtitle: summary.altoScore >= 80.0 ? "Passes threshold (≥80%)" : "Pending requirements",
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScoreKPICard({
    required bool isDark,
    required String title,
    required double score,
    required double threshold,
    required Color color,
    required String subtitle,
  }) {
    final meets = score >= threshold;
    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              Icon(
                meets ? Icons.check_circle_outline : Icons.pending_outlined,
                size: 16,
                color: meets ? Colors.green : Colors.amber,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "${score.toStringAsFixed(1)}%",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: meets ? color : (isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (score / 100.0).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildENSControlsBar(bool isDark, Color primaryColor, ENSSummaryModel summary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Counters
        Row(
          children: [
            _buildCountChip("${summary.totalMeasures} Measures", Colors.grey, isDark),
            const SizedBox(width: 8),
            _buildCountChip("${summary.compliantCount} Compliant", const Color(0xFF10B981), isDark),
            const SizedBox(width: 8),
            _buildCountChip("${summary.partialCount} Partial", const Color(0xFFF59E0B), isDark),
            const SizedBox(width: 8),
            _buildCountChip("${summary.nonCompliantCount} Non-Compliant", const Color(0xFFEF4444), isDark),
          ],
        ),

        // Filter buttons
        Row(
          children: [
            _buildFilterButton("All", "ALL", isDark, primaryColor),
            const SizedBox(width: 6),
            _buildFilterButton("BASIC", "BASICO", isDark, primaryColor),
            const SizedBox(width: 6),
            _buildFilterButton("MEDIUM", "MEDIO", isDark, primaryColor),
            const SizedBox(width: 6),
            _buildFilterButton("HIGH", "ALTO", isDark, primaryColor),
            const SizedBox(width: 6),
            _buildFilterButton("⚠️ Requires Action", "ISSUES", isDark, primaryColor),
          ],
        ),
      ],
    );
  }

  Widget _buildCountChip(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildFilterButton(String label, String value, bool isDark, Color primaryColor) {
    final selected = _ensLevelFilter == value;
    return InkWell(
      onTap: () => _updateState(() => _ensLevelFilter = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? primaryColor : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? primaryColor : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildENSMeasureCard(bool isDark, Color primaryColor, ENSMeasureModel measure) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (measure.isCompliant) {
      statusColor = const Color(0xFF10B981);
      statusLabel = "COMPLIANT (100%)";
      statusIcon = Icons.check_circle_rounded;
    } else if (measure.isPartial) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = "PARTIAL (${(measure.score * 100).toInt()}%)";
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = const Color(0xFFEF4444);
      statusLabel = "NON-COMPLIANT (0%)";
      statusIcon = Icons.cancel_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.25),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(statusIcon, color: statusColor, size: 26),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                measure.id,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                measure.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            // Applicable Levels
            ...measure.applicableLevels.map((lvl) {
              return Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Text(
                  lvl,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              );
            }),
            const SizedBox(width: 8),
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            "Area: ${measure.area} • Dimension: ${measure.dimension} • Weight: ${measure.weight.toStringAsFixed(1)}",
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black45),
          ),
        ),
        children: [
          // Discovered Technical Evidence
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2),
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

          // Recommendation if not 100% compliant
          if (measure.recommendation.isNotEmpty && !measure.isCompliant) ...[
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
                          "Technical Remediation (CCN-STIC):",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          measure.recommendation,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
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

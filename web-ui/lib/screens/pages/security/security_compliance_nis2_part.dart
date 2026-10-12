part of '../security_page.dart';

extension _SecurityComplianceNis2Ext on _SecurityPageState {
  // ---------------------------------------------------------------------------
  // TAB 5: UNIFIED COMPLIANCE & REGULATORY SUITE (NIS 2, CIS, ENS & ISO 27001)
  // ---------------------------------------------------------------------------

  Widget _buildComplianceHubTab(bool isDark, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildContinuousComplianceExecutiveHeader(isDark, primaryColor),
        const SizedBox(height: 16),
        // Top Segmented Pill Selector between Standards
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildStandardPill(
                isDark: isDark,
                primaryColor: const Color(0xFF3B82F6),
                title: "🇪🇺 NIS 2 Directive (EU 2022/2555)",
                isSelected: _selectedComplianceStandard == "NIS2",
                onTap: () {
                  _updateState(() => _selectedComplianceStandard = "NIS2");
                  if (_nis2Summary == null) {
                    _loadNIS2Status();
                  }
                },
              ),
              _buildStandardPill(
                isDark: isDark,
                primaryColor: const Color(0xFF6366F1),
                title: "🔒 CIS Docker Benchmark v1.6.0",
                isSelected: _selectedComplianceStandard == "CIS",
                onTap: () {
                  _updateState(() => _selectedComplianceStandard = "CIS");
                  if (_cisSummary == null) {
                    _loadCISStatus();
                  }
                },
              ),
              _buildStandardPill(
                isDark: isDark,
                primaryColor: const Color(0xFF14B8A6),
                title: "🇪🇸 Spanish ENS (RD 311/2022)",
                isSelected: _selectedComplianceStandard == "ENS",
                onTap: () {
                  _updateState(() => _selectedComplianceStandard = "ENS");
                  if (_ensSummary == null) {
                    _loadENSStatus();
                  }
                },
              ),
              _buildStandardPill(
                isDark: isDark,
                primaryColor: const Color(0xFF8B5CF6),
                title: "🌐 ISO/IEC 27001:2022 (Annex A)",
                isSelected: _selectedComplianceStandard == "ISO27001",
                onTap: () {
                  _updateState(() => _selectedComplianceStandard = "ISO27001");
                  if (_isoSummary == null) {
                    _loadISO27001Status();
                  }
                },
              ),
              _buildStandardPill(
                isDark: isDark,
                primaryColor: const Color(0xFFF59E0B),
                title: "🏛️ EU DORA (Reg. 2022/2554)",
                isSelected: _selectedComplianceStandard == "DORA",
                onTap: () {
                  _updateState(() => _selectedComplianceStandard = "DORA");
                  if (_doraSummary == null) {
                    _loadDORAStatus();
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Active Standard Dashboard View
        Expanded(
          child: _selectedComplianceStandard == "NIS2"
              ? _buildNIS2DashboardTab(isDark, primaryColor)
              : (_selectedComplianceStandard == "CIS"
                  ? _buildCISDockerDashboardTab(isDark, primaryColor)
                  : (_selectedComplianceStandard == "ENS"
                      ? _buildENSDashboardTab(isDark, primaryColor)
                      : (_selectedComplianceStandard == "ISO27001"
                          ? _buildISO27001DashboardTab(isDark, primaryColor)
                          : _buildDORADashboardTab(isDark, primaryColor)))),
        ),
      ],
    );
  }

  Widget _buildStandardPill({
    required bool isDark,
    required Color primaryColor,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? primaryColor.withValues(alpha: 0.25) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
          border: isSelected
              ? Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1.2)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : primaryColor)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinuousComplianceExecutiveHeader(bool isDark, Color primaryColor) {
    final overview = _complianceOverview;
    final avgScore = overview?.overallScore ?? 0.0;
    final source = overview?.triggerSource ?? "AUTO";
    
    // Posture colors & text
    Color postureColor;
    String postureLabel;
    IconData postureIcon;
    if (avgScore >= 90.0) {
      postureColor = const Color(0xFF10B981); // emerald green
      postureLabel = "EXEMPLARY (HIGH TIER)";
      postureIcon = Icons.verified_rounded;
    } else if (avgScore >= 75.0) {
      postureColor = const Color(0xFF3B82F6); // blue
      postureLabel = "COMPLIANT (HEALTHY)";
      postureIcon = Icons.shield_rounded;
    } else if (avgScore >= 60.0) {
      postureColor = const Color(0xFFF59E0B); // amber
      postureLabel = "ACCEPTABLE (NEEDS IMPROVEMENT)";
      postureIcon = Icons.warning_amber_rounded;
    } else {
      postureColor = const Color(0xFFEF4444); // red
      postureLabel = "RISK / DEGRADED";
      postureIcon = Icons.error_outline_rounded;
    }

    String sourceLabel = "Continuous Watchdog (15m)";
    if (source.contains("MFA")) {
      sourceLabel = "Hot MFA Policy Mutation";
    } else if (source.contains("SECURITY_CONFIG")) {
      sourceLabel = "Security Policy Adjustment";
    } else if (source.contains("MANUAL")) {
      sourceLabel = "Manual Forced Audit";
    } else if (source == "BOOT_AUDIT" || source == "INIT") {
      sourceLabel = "Cluster Startup";
    }

    String lastTimeStr = "Evaluating...";
    if (overview != null && overview.evaluatedAt.isNotEmpty) {
      final dt = DateTime.tryParse(overview.evaluatedAt)?.toLocal();
      if (dt != null) {
        lastTimeStr = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
      }
    }

    final nis2Score = overview?.getStandard("NIS2")?.score ?? (_nis2Summary?.essentialScore ?? 0.0);
    final cisScore = overview?.getStandard("CIS")?.score ?? (_cisSummary?.scorePercent ?? 0.0);
    final ensScore = overview?.getStandard("ENS")?.score ?? (_ensSummary?.medioScore ?? 0.0);
    final isoScore = overview?.getStandard("ISO27001")?.score ?? (_isoSummary?.overallScore ?? 0.0);
    final doraScore = overview?.getStandard("DORA")?.score ?? (_doraSummary?.overallScore ?? 0.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [Colors.white, const Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Left: Watchdog Status & Posture
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      postureColor.withValues(alpha: 0.25),
                      postureColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: postureColor.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Icon(postureIcon, color: postureColor, size: 26),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${avgScore > 0 ? avgScore.toStringAsFixed(1) : '--'}%",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: postureColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: postureColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: postureColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          postureLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: postureColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              "ACTIVE WATCHDOG",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF10B981),
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (_complianceOverviewLoading) ...[
                              const SizedBox(width: 6),
                              const SizedBox(
                                width: 8,
                                height: 8,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 13, color: isDark ? Colors.white54 : Colors.black45),
                      const SizedBox(width: 4),
                      Text(
                        "Last evaluated: $lastTimeStr",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "•  $sourceLabel",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Center: 5 Interactive Mini-KPI Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildComplianceMiniPill(
                isDark: isDark,
                standardKey: "NIS2",
                title: "NIS 2",
                score: nis2Score,
                flagIcon: "🇪🇺",
                accentColor: const Color(0xFF3B82F6),
              ),
              _buildComplianceMiniPill(
                isDark: isDark,
                standardKey: "CIS",
                title: "CIS Docker",
                score: cisScore,
                flagIcon: "🔒",
                accentColor: const Color(0xFF6366F1),
              ),
              _buildComplianceMiniPill(
                isDark: isDark,
                standardKey: "ENS",
                title: "ENS Spain",
                score: ensScore,
                flagIcon: "🇪🇸",
                accentColor: const Color(0xFF14B8A6),
              ),
              _buildComplianceMiniPill(
                isDark: isDark,
                standardKey: "ISO27001",
                title: "ISO 27001",
                score: isoScore,
                flagIcon: "🌐",
                accentColor: const Color(0xFF8B5CF6),
              ),
              _buildComplianceMiniPill(
                isDark: isDark,
                standardKey: "DORA",
                title: "EU DORA",
                score: doraScore,
                flagIcon: "🏛️",
                accentColor: const Color(0xFFF59E0B),
              ),
            ],
          ),

          // Right: Master Re-evaluation Button
          ElevatedButton.icon(
            onPressed: _evaluatingAllCompliance ? null : _evaluateAllCompliance,
            icon: _evaluatingAllCompliance
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.shield_outlined, size: 18),
            label: Text(
              _evaluatingAllCompliance ? "Auditing Cluster..." : "Re-evaluate Entire Cluster",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceMiniPill({
    required bool isDark,
    required String standardKey,
    required String title,
    required double score,
    required String flagIcon,
    required Color accentColor,
  }) {
    final isSelected = _selectedComplianceStandard == standardKey;
    Color scoreColor = score >= 85 ? const Color(0xFF10B981) : (score >= 65 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
    
    return InkWell(
      onTap: () {
        _updateState(() => _selectedComplianceStandard = standardKey);
        if (standardKey == "NIS2" && _nis2Summary == null && !_nis2Loading) _loadNIS2Status();
        if (standardKey == "CIS" && _cisSummary == null && !_cisLoading) _loadCISStatus();
        if (standardKey == "ENS" && _ensSummary == null && !_ensLoading) _loadENSStatus();
        if (standardKey == "ISO27001" && _isoSummary == null && !_isoLoading) _loadISO27001Status();
        if (standardKey == "DORA" && _doraSummary == null && !_doraLoading) _loadDORAStatus();
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? accentColor.withValues(alpha: 0.22) : accentColor.withValues(alpha: 0.12))
              : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.25)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flagIcon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : accentColor)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                score > 0 ? "${score.toStringAsFixed(1)}%" : "--",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: scoreColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNIS2ReportDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final reportContent = await ApiService.fetchNIS2Report(format: 'markdown');
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (reportContent == null || reportContent.isEmpty) {
      _showSnackBar("Failed to generate NIS 2 technical compliance report", isError: true);
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
              const Icon(Icons.verified_user_rounded, color: Color(0xFF3B82F6), size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "NIS 2 Directive (EU 2022/2555) Technical Compliance Report",
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
                      "Technical CommonMark evidence documentation formatted for EU CSIRT & regulatory audits",
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
                _showSnackBar("NIS 2 compliance report copied to clipboard");
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.data_object, size: 16),
              label: const Text("Download JSON (.json)"),
              onPressed: () async {
                final jsonContent = await ApiService.fetchNIS2Report(format: 'json');
                if (jsonContent != null && jsonContent.isNotEmpty) {
                  try {
                    final bytes = utf8.encode(jsonContent);
                    final blob = html.Blob([bytes], 'application/json');
                    final url = html.Url.createObjectUrlFromBlob(blob);
                    final now = DateTime.now();
                    final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
                    final filename = "nis2-compliance-report-$dateStr.json";
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
                backgroundColor: const Color(0xFF3B82F6),
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
                  final filename = "nis2-compliance-report-$dateStr.md";
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

  Widget _buildNIS2DashboardTab(bool isDark, Color primaryColor) {
    if (_nis2Loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Evaluating NIS 2 Directive (EU 2022/2555) compliance...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_nis2Error != null) {
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
              Text("Error loading NIS 2 audit: $_nis2Error", style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadNIS2Status,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _nis2Summary;
    if (summary == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text("No NIS 2 audit data available"),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadNIS2Status, child: const Text("Evaluate Now")),
          ],
        ),
      );
    }

    final filteredMeasures = summary.measures.where((m) {
      if (_nis2DomainFilter == "ISSUES") {
        return m.status != "COMPLIANT";
      } else if (_nis2DomainFilter != "ALL") {
        return m.domain == _nis2DomainFilter;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNIS2HeaderBanner(isDark, primaryColor, summary),
          const SizedBox(height: 16),
          _buildNIS2KPICards(isDark, summary),
          const SizedBox(height: 20),
          _buildNIS2ControlsBar(isDark, primaryColor, summary),
          const SizedBox(height: 14),
          if (filteredMeasures.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text(
                "No measures match the selected domain filter.",
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            )
          else
            ...filteredMeasures.map((measure) => _buildNIS2MeasureCard(isDark, primaryColor, measure)),
        ],
      ),
    );
  }

  Widget _buildNIS2HeaderBanner(bool isDark, Color primaryColor, NIS2SummaryModel summary) {
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
          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.security_rounded, color: Color(0xFF3B82F6), size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Directive (EU) 2022/2555 (NIS 2)",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "Article 21 Risk Management",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Automated technical compliance assessment across supply chain SBOM, Cosign signatures, SIEM telemetry, and cryptographic controls.",
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
            onPressed: _loadNIS2Status,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("Refresh"),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
            ),
            onPressed: _openNIS2ReportDialog,
            icon: const Icon(Icons.description_outlined, size: 16),
            label: const Text("Export Audit Report"),
          ),
        ],
      ),
    );
  }

  Widget _buildNIS2KPICards(bool isDark, NIS2SummaryModel summary) {
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
                          "OVERALL READINESS",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        Text(readinessEmoji, style: const TextStyle(fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: readinessColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        summary.overallReadiness,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: readinessColor,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "EU 2022/2555 Baseline",
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black45),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // KPI 2: Essential Entities (EE)
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
                          "ESSENTIAL ENTITIES (EE)",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        Icon(Icons.corporate_fare_rounded, size: 16, color: Color(0xFF3B82F6)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${summary.essentialScore.toStringAsFixed(1)}%",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: summary.essentialScore >= 85 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: summary.essentialScore / 100.0,
                        minHeight: 6,
                        backgroundColor: isDark ? Colors.white10 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation(
                          summary.essentialScore >= 85 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Supervisory threshold: 85%",
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black45),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // KPI 3: Important Entities (IE)
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
                          "IMPORTANT ENTITIES (IE)",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        Icon(Icons.business_rounded, size: 16, color: Color(0xFF6366F1)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${summary.importantScore.toStringAsFixed(1)}%",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: summary.importantScore >= 75 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: summary.importantScore / 100.0,
                        minHeight: 6,
                        backgroundColor: isDark ? Colors.white10 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation(
                          summary.importantScore >= 75 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Supervisory threshold: 75%",
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black45),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // KPI 4: Controls Breakdown
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
                          "ARTICLE 21 CONTROLS",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        Icon(Icons.rule_folder_outlined, size: 16, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${summary.totalMeasures} Measures",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildNIS2BadgeChip("${summary.compliantCount} Compliant", const Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        _buildNIS2BadgeChip("${summary.partialCount} Partial", const Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        _buildNIS2BadgeChip("${summary.nonCompliantCount} Issues", const Color(0xFFEF4444)),
                      ],
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

  Widget _buildNIS2BadgeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildNIS2ControlsBar(bool isDark, Color primaryColor, NIS2SummaryModel summary) {
    final domains = [
      "ALL",
      "ISSUES",
      "Risk Governance",
      "Incident Response",
      "Business Continuity",
      "Supply Chain",
      "Vulnerability Handling",
      "Effectiveness & Audit",
      "Cyber Hygiene",
      "Cryptography",
      "Access Control",
      "MFA & Authentication",
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
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          const Text("Domain Filter:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: domains.map((domain) {
                  final isSelected = _nis2DomainFilter == domain;
                  String label = domain;
                  if (domain == "ALL") label = "All Controls (${summary.totalMeasures})";
                  if (domain == "ISSUES") label = "Needs Action (${summary.partialCount + summary.nonCompliantCount})";

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF3B82F6) : (isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.3)),
                      ),
                      onSelected: (val) {
                        if (val) {
                          _updateState(() => _nis2DomainFilter = domain);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNIS2MeasureCard(bool isDark, Color primaryColor, NIS2MeasureModel measure) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (measure.status) {
      case "COMPLIANT":
        statusColor = const Color(0xFF10B981);
        statusText = "COMPLIANT";
        statusIcon = Icons.check_circle_rounded;
        break;
      case "PARTIAL":
        statusColor = const Color(0xFFF59E0B);
        statusText = "PARTIAL";
        statusIcon = Icons.warning_amber_rounded;
        break;
      default:
        statusColor = const Color(0xFFEF4444);
        statusText = "NON-COMPLIANT";
        statusIcon = Icons.cancel_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: measure.isCompliant
              ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2))
              : statusColor.withValues(alpha: 0.4),
          width: measure.isCompliant ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Article ID, Name, Domain, Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  measure.article,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  measure.domain,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  measure.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                    const SizedBox(width: 6),
                    Text(
                      "${measure.score.toStringAsFixed(0)}%",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Technical Discovered Evidence Box
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

          // Actionable Remediation if not 100% compliant
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
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

}

part of '../security_page.dart';

extension _SecurityOwaspExt on _SecurityPageState {
  Widget _buildOWASPDashboardTab(bool isDark, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-navigation inside OWASP Suite
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              selected: _owaspSubView == 'compliance',
              label: const Text('OWASP Compliance Matrix (Top 10 / API / ASVS / Docker / LLM)', style: TextStyle(fontSize: 12)),
              onSelected: (_) => _updateState(() => _owaspSubView = 'compliance'),
            ),
            ChoiceChip(
              selected: _owaspSubView == 'dast',
              label: Text('Active WSTG DAST Scanner (${_owaspDastHistory.length})', style: const TextStyle(fontSize: 12)),
              onSelected: (_) {
                _updateState(() => _owaspSubView = 'dast');
                _loadOWASPDASTHistory();
              },
            ),
            ChoiceChip(
              selected: _owaspSubView == 'compose',
              label: const Text('Compose Docker Top 10 Auditor (D01-D10)', style: TextStyle(fontSize: 12)),
              onSelected: (_) => _updateState(() => _owaspSubView = 'compose'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: switch (_owaspSubView) {
            'dast' => _buildOWASPDASTView(isDark, primaryColor),
            'compose' => _buildOWASPComposeAuditorView(isDark, primaryColor),
            _ => _buildOWASPComplianceView(isDark, primaryColor),
          },
        ),
      ],
    );
  }

  Widget _buildOWASPComplianceView(bool isDark, Color primaryColor) {
    if (_owaspLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final summary = _owaspSummary;
    if (summary == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _loadOWASPStatus,
          icon: const Icon(Icons.refresh),
          label: const Text('Evaluate OWASP Security Suite'),
        ),
      );
    }

    final filtered = summary.controls.where((c) {
      if (_owaspDomainFilter != 'ALL' && c.domain != _owaspDomainFilter) return false;
      if (_owaspStatusFilter == 'ISSUES' && c.status == 'COMPLIANT') return false;
      if (_owaspStatusFilter != 'ALL' && _owaspStatusFilter != 'ISSUES' && c.status != _owaspStatusFilter) return false;
      return true;
    }).toList();

    final gradeColor = _owaspGradeColor(summary.grade);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Executive Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: gradeColor.withValues(alpha: 0.4)),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: gradeColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: gradeColor, width: 2),
                      ),
                      child: Text(
                        summary.grade,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: gradeColor),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OWASP Security Suite — ${summary.overallScore.toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          summary.standardVersion,
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${summary.compliantCount} Compliant • ${summary.partialCount} Partial • ${summary.nonCompliantCount} Non-Compliant (Total ${summary.totalControls})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (summary.nonCompliantCount > 0 || summary.partialCount > 0)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.black,
                        ),
                        onPressed: _owaspRemediating ? null : _remediateAllSafeOWASP,
                        icon: _owaspRemediating && _owaspRemediatingId == 'all-safe'
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.auto_fix_high, size: 15),
                        label: const Text('Auto-Fix All (Safe)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    OutlinedButton.icon(
                      onPressed: _loadOWASPStatus,
                      icon: const Icon(Icons.refresh, size: 15),
                      label: const Text('Re-Evaluate', style: TextStyle(fontSize: 12)),
                    ),
                    FilledButton.icon(
                      onPressed: () => _downloadOWASPReport('markdown'),
                      icon: const Icon(Icons.download, size: 15),
                      label: const Text('Export Markdown', style: TextStyle(fontSize: 12)),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _downloadOWASPReport('json'),
                      icon: const Icon(Icons.code, size: 15),
                      label: const Text('JSON', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 5 Domain Scorecards
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _owaspDomainCard('Top 10 Web', summary.top10WebScore, 'TOP10_WEB', isDark),
              _owaspDomainCard('API Top 10', summary.apiTop10Score, 'API_TOP10', isDark),
              _owaspDomainCard('ASVS v4.0 L2', summary.asvsScore, 'ASVS_L2', isDark),
              _owaspDomainCard('Docker Top 10', summary.dockerTop10Score, 'DOCKER_TOP10', isDark),
              _owaspDomainCard('LLM Top 10', summary.llmTop10Score, 'LLM_TOP10', isDark),
            ],
          ),
          const SizedBox(height: 14),

          // Filter bar
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final d in const ['ALL', 'TOP10_WEB', 'API_TOP10', 'ASVS_L2', 'DOCKER_TOP10', 'LLM_TOP10'])
                FilterChip(
                  selected: _owaspDomainFilter == d,
                  label: Text(d == 'ALL' ? 'All Domains' : d.replaceAll('_', ' '), style: const TextStyle(fontSize: 11)),
                  onSelected: (_) => _updateState(() => _owaspDomainFilter = d),
                ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _owaspStatusFilter,
                underline: const SizedBox(),
                isDense: true,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Status', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'ISSUES', child: Text('Issues Only', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'COMPLIANT', child: Text('Compliant', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'PARTIAL', child: Text('Partial', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'NON_COMPLIANT', child: Text('Non-Compliant', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (v) {
                  if (v != null) _updateState(() => _owaspStatusFilter = v);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Controls list
          ...filtered.map((c) {
            final col = c.status == 'COMPLIANT'
                ? const Color(0xFF10B981)
                : (c.status == 'PARTIAL' ? Colors.amber : Colors.redAccent);
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: col.withValues(alpha: 0.35)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _owaspPill(c.reference, Colors.cyan),
                        _owaspPill(c.status, col),
                        _owaspPill(c.severity, c.severity == 'CRITICAL' ? Colors.redAccent : Colors.orangeAccent),
                        Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(c.description, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                    const SizedBox(height: 6),
                    Text('Evidence: ${c.evidence}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                    if (c.status != 'COMPLIANT') ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              'Remediation: ${c.remediation}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: col),
                            ),
                          ),
                          if (c.autoFixable) ...[
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                                foregroundColor: const Color(0xFF10B981),
                                side: const BorderSide(color: Color(0xFF10B981)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              onPressed: _owaspRemediating ? null : () => _remediateOWASPControl(c.id),
                              icon: _owaspRemediating && _owaspRemediatingId == c.id
                                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.build_circle_outlined, size: 14),
                              label: Text(
                                c.autoFixLabel.isNotEmpty ? c.autoFixLabel : 'Apply Auto-Fix',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOWASPDASTView(bool isDark, Color primaryColor) {
    final latest = _owaspLatestDast ?? (_owaspDastHistory.isNotEmpty ? _owaspDastHistory.first : null);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: const Color(0xFF06B6D4).withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.radar, color: Color(0xFF06B6D4), size: 20),
                      SizedBox(width: 8),
                      Text('Active Ethical OWASP WSTG DAST Scanner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Audits TLS, OWASP Secure Headers, Cookie flags, CORS policy, TRACE method, exposed dotfiles (.env/.git), and active WAF blocking.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _owaspDastUrlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Target Caddy Route or Cluster HTTP/HTTPS URL',
                            hintText: 'https://app.gbnt.local or http://127.0.0.1:4001',
                            prefixIcon: Icon(Icons.language, size: 18),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _owaspDastRunning ? null : _runOWASPDAST,
                        icon: _owaspDastRunning
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Run WSTG Audit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    children: [
                      FilterChip(
                        selected: _owaspDastProbeWaf,
                        label: const Text('Active Benign WAF Probes (SQLi/XSS/LFI/SSRF)', style: TextStyle(fontSize: 11)),
                        onSelected: (v) => _updateState(() => _owaspDastProbeWaf = v),
                      ),
                      FilterChip(
                        selected: _owaspDastIncludeZap,
                        label: const Text('Also Launch OWASP ZAP Baseline Container (Docker)', style: TextStyle(fontSize: 11)),
                        onSelected: (v) => _updateState(() => _owaspDastIncludeZap = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (latest != null) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _owaspGradeColor(latest.grade).withValues(alpha: 0.45)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _owaspPill('GRADE ${latest.grade} (${latest.score.toStringAsFixed(1)}%)', _owaspGradeColor(latest.grade)),
                        _owaspPill('HTTP ${latest.httpStatus}', Colors.blueAccent),
                        if (latest.tlsVersion.isNotEmpty) _owaspPill(latest.tlsVersion, const Color(0xFF10B981)),
                        if (latest.wafProbesRun > 0)
                          _owaspPill('WAF Blocked ${latest.wafBlockedCount}/${latest.wafProbesRun}', Colors.purpleAccent),
                        Text(latest.targetUrl, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('(${latest.durationMs}ms)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    if (latest.error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Error: ${latest.error}', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    const SizedBox(height: 12),
                    ...latest.findings.map((f) {
                      final col = f.status == 'PASS'
                          ? const Color(0xFF10B981)
                          : (f.status == 'WARN' ? Colors.amber : Colors.redAccent);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          f.status == 'PASS' ? Icons.check_circle : (f.status == 'WARN' ? Icons.warning_amber : Icons.cancel),
                          color: col,
                          size: 18,
                        ),
                        title: Wrap(
                          spacing: 6,
                          children: [
                            _owaspPill(f.wstgCode, Colors.cyan),
                            Text(f.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        subtitle: Text('${f.evidence}${f.status != 'PASS' ? '\nFix: ${f.remediation}' : ''}',
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                      );
                    }),
                    if (latest.zapOutput.isNotEmpty) ...[
                      const Divider(height: 20),
                      const Text('OWASP ZAP Baseline Output:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFF0B1120), borderRadius: BorderRadius.circular(8)),
                        child: SelectableText(latest.zapOutput, style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: Color(0xFFA5F3FC))),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOWASPComposeAuditorView(bool isDark, Color primaryColor) {
    final res = _owaspComposeResult;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.fact_check_outlined, color: Color(0xFF06B6D4), size: 20),
                      const SizedBox(width: 8),
                      const Text('OWASP Docker Top 10 (D01-D10) Compose Shift-Left Auditor',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const Spacer(),
                      if (widget.state.stacks.isNotEmpty)
                        DropdownButton<String>(
                          hint: const Text('Load Deployed Stack...', style: TextStyle(fontSize: 12)),
                          underline: const SizedBox(),
                          items: widget.state.stacks
                              .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 12))))
                              .toList(),
                          onChanged: (stackId) {
                            if (stackId == null) return;
                            final st = widget.state.stacks.firstWhere((s) => s.id == stackId);
                            _updateState(() {
                              _owaspSelectedStackId = stackId;
                              _owaspLastChanges = [];
                            });
                            _owaspComposeCtrl.text = st.rawComposeFile;
                            _runOWASPComposeLint();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _owaspComposeCtrl,
                    maxLines: 8,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Paste docker-compose.yml here or select a deployed stack above...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _owaspComposeLinting ? null : _runOWASPComposeLint,
                        icon: const Icon(Icons.security, size: 16),
                        label: const Text('Audit Compose YAML'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.black,
                        ),
                        onPressed: _owaspComposeLinting ? null : _hardenOWASPCompose,
                        icon: const Icon(Icons.auto_fix_high, size: 16),
                        label: const Text('Auto-Harden YAML (1-Click)', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      if (_owaspSelectedStackId != null && _owaspLastChanges.isNotEmpty)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), foregroundColor: Colors.black),
                          onPressed: _saveHardenedComposeToStack,
                          icon: const Icon(Icons.save_outlined, size: 16),
                          label: const Text('Save Hardened YAML to Stack'),
                        ),
                      if (res != null && res.hardeningSnippet.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: res.hardeningSnippet));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('OWASP Auto-Hardening YAML snippet copied to clipboard')),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 15),
                          label: const Text('Copy Snippet'),
                        ),
                    ],
                  ),
                  if (_owaspLastChanges.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Applied ${_owaspLastChanges.length} Auto-Hardening Fix(es):',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                          const SizedBox(height: 4),
                          ..._owaspLastChanges.map((ch) => Text('• $ch', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (res != null) ...[
            const SizedBox(height: 14),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _owaspGradeColor(res.grade).withValues(alpha: 0.45)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _owaspPill('GRADE ${res.grade} (${res.score.toStringAsFixed(1)}%)', _owaspGradeColor(res.grade)),
                        _owaspPill('CRITICAL: ${res.criticalCount}', res.criticalCount > 0 ? Colors.redAccent : Colors.grey),
                        _owaspPill('HIGH: ${res.highCount}', res.highCount > 0 ? Colors.orangeAccent : Colors.grey),
                        _owaspPill('MEDIUM: ${res.mediumCount}', res.mediumCount > 0 ? Colors.amber : Colors.grey),
                        _owaspPill('SERVICES: ${res.servicesAudited}', Colors.cyan),
                      ],
                    ),
                    if (res.parseError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('YAML Parse Error: ${res.parseError}', style: const TextStyle(color: Colors.redAccent)),
                      ),
                    const SizedBox(height: 10),
                    if (res.findings.isEmpty && res.valid)
                      const Text('Zero OWASP Docker Top 10 issues found! Compose manifest is hardened.',
                          style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold))
                    else
                      ...res.findings.map((f) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: _owaspPill(f.ruleId, f.severity == 'CRITICAL' ? Colors.redAccent : Colors.orangeAccent),
                            title: Text('[${f.service}] ${f.title}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            subtitle: Text('${f.detail}\nFix: ${f.remediation}', style: const TextStyle(fontSize: 11)),
                          )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _owaspDomainCard(String title, double score, String domainCode, bool isDark) {
    final col = score >= 85 ? const Color(0xFF10B981) : (score >= 65 ? Colors.amber : Colors.redAccent);
    return InkWell(
      onTap: () => _updateState(() => _owaspDomainFilter = _owaspDomainFilter == domainCode ? 'ALL' : domainCode),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 175,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _owaspDomainFilter == domainCode ? col : col.withValues(alpha: 0.35),
            width: _owaspDomainFilter == domainCode ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${score.toStringAsFixed(1)}%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: col)),
          ],
        ),
      ),
    );
  }

  Widget _owaspPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, fontFamily: 'monospace')),
    );
  }

  Color _owaspGradeColor(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return const Color(0xFF10B981);
      case 'B':
        return const Color(0xFF06B6D4);
      case 'C':
        return Colors.amber;
      default:
        return Colors.redAccent;
    }
  }
}

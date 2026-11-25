import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';

/// Dedicated top-level OWASP Security Suite Page accessible directly from the SECURITY sidebar.
/// Sub-tabs (Level-3 sidebar):
///  0 = OWASP Compliance Matrix (Top 10 Web, API, ASVS L2, Docker & LLM Top 10)
///  1 = Active WSTG DAST Scanner (+ Optional OWASP ZAP Baseline)
///  2 = Compose Docker Top 10 Auditor (D01-D10 + Auto-Hardening Snippet)
class OwaspPage extends StatefulWidget {
  final DashboardState state;
  final int selectedSubIndex;
  final ValueChanged<int>? onNavigateDestination;

  const OwaspPage({
    super.key,
    required this.state,
    this.selectedSubIndex = 0,
    this.onNavigateDestination,
  });

  @override
  State<OwaspPage> createState() => _OwaspPageState();
}

class _OwaspPageState extends State<OwaspPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Compliance Matrix state
  OWASPSummaryModel? _summary;
  bool _loading = true;
  String _domainFilter = 'ALL';
  String _statusFilter = 'ALL';

  // DAST Scanner state
  List<OWASPDASTResultModel> _dastHistory = [];
  OWASPDASTResultModel? _latestDast;
  bool _dastRunning = false;
  bool _probeWaf = true;
  bool _includeZap = false;
  final TextEditingController _dastUrlCtrl = TextEditingController();

  // Compose Auditor state
  final TextEditingController _composeCtrl = TextEditingController();
  OWASPComposeLintResultModel? _composeResult;
  bool _composeLinting = false;

  @override
  void initState() {
    super.initState();
    final origin = html.window.location.origin;
    _dastUrlCtrl.text = origin.isNotEmpty ? origin : 'http://127.0.0.1:4001';
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.selectedSubIndex.clamp(0, 2),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
        if (_tabController.index == 1 && _dastHistory.isEmpty) {
          _loadDastHistory();
        }
      }
    });
    _loadCompliance();
    _loadDastHistory();
  }

  @override
  void didUpdateWidget(OwaspPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSubIndex != widget.selectedSubIndex) {
      final target = widget.selectedSubIndex.clamp(0, 2);
      if (_tabController.index != target) {
        _tabController.animateTo(target);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dastUrlCtrl.dispose();
    _composeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCompliance() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.fetchOWASPStatus();
      if (mounted) {
        setState(() {
          _summary = res;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDastHistory() async {
    final hist = await ApiService.fetchOWASPDASTHistory();
    if (mounted) setState(() => _dastHistory = hist);
  }

  Future<void> _runDast() async {
    final target = _dastUrlCtrl.text.trim();
    if (target.isEmpty) return;
    setState(() => _dastRunning = true);
    try {
      final res = await ApiService.runOWASPDASTScan(
        targetUrl: target,
        probeWaf: _probeWaf,
        includeZap: _includeZap,
      );
      if (mounted) {
        setState(() {
          _latestDast = res;
          _dastRunning = false;
        });
        _loadDastHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _dastRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DAST Scan failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _runComposeLint() async {
    final yaml = _composeCtrl.text.trim();
    if (yaml.isEmpty) return;
    setState(() => _composeLinting = true);
    try {
      final res = await ApiService.lintComposeOWASP(yaml);
      if (mounted) {
        setState(() {
          _composeResult = res;
          _composeLinting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _composeLinting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Compose audit failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _downloadReport(String format) async {
    final content = await ApiService.fetchOWASPReport(format: format);
    if (content == null || !mounted) return;
    final ext = format == 'json' ? 'json' : 'md';
    final mime = format == 'json' ? 'application/json' : 'text/markdown';
    final blob = html.Blob([content], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final a = html.AnchorElement(href: url)
      ..setAttribute('download', 'owasp-security-report.$ext')
      ..click();
    html.Url.revokeObjectUrl(url);
    a.remove();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final grade = _summary?.grade ?? '...';
    final score = _summary?.overallScore ?? 0.0;
    final gradeColor = _gradeColor(grade);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.verified_user, color: Color(0xFF06B6D4), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'OWASP Security Suite',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (_summary != null)
                              _pill('GRADE $grade • ${score.toStringAsFixed(1)}%', gradeColor),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Top 10 Web • API Top 10 • ASVS v4.0 L2 • Docker Top 10 • LLM Top 10 • Active WSTG DAST',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.onNavigateDestination != null) ...[
                      OutlinedButton.icon(
                        onPressed: () => widget.onNavigateDestination!(7),
                        icon: const Icon(Icons.shield_outlined, size: 15),
                        label: const Text('Caddy WAF CRS', style: TextStyle(fontSize: 12)),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => widget.onNavigateDestination!(14),
                        icon: const Icon(Icons.grain, size: 15),
                        label: const Text('eBPF Live Hub', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    OutlinedButton.icon(
                      onPressed: _loadCompliance,
                      icon: const Icon(Icons.refresh, size: 15),
                      label: const Text('Re-Evaluate', style: TextStyle(fontSize: 12)),
                    ),
                    FilledButton.icon(
                      onPressed: () => _downloadReport('markdown'),
                      icon: const Icon(Icons.download, size: 15),
                      label: const Text('Export Report', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), foregroundColor: Colors.black),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // View Body (driven by Level-3 Sidebar subIndex)
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildComplianceTab(theme, isDark),
                _buildDastTab(theme, isDark),
                _buildComposeAuditorTab(theme, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 0: Compliance Matrix ─────────────────────────────────────────────

  Widget _buildComplianceTab(ThemeData theme, bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)));
    }
    final summary = _summary;
    if (summary == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _loadCompliance,
          icon: const Icon(Icons.refresh),
          label: const Text('Evaluate OWASP Security Suite'),
        ),
      );
    }

    final filtered = summary.controls.where((c) {
      if (_domainFilter != 'ALL' && c.domain != _domainFilter) return false;
      if (_statusFilter == 'ISSUES' && c.status == 'COMPLIANT') return false;
      if (_statusFilter != 'ALL' && _statusFilter != 'ISSUES' && c.status != _statusFilter) return false;
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _domainCard('Top 10 Web', summary.top10WebScore, 'TOP10_WEB', isDark),
              _domainCard('API Top 10', summary.apiTop10Score, 'API_TOP10', isDark),
              _domainCard('ASVS v4.0 L2', summary.asvsScore, 'ASVS_L2', isDark),
              _domainCard('Docker Top 10', summary.dockerTop10Score, 'DOCKER_TOP10', isDark),
              _domainCard('LLM Top 10', summary.llmTop10Score, 'LLM_TOP10', isDark),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final d in const ['ALL', 'TOP10_WEB', 'API_TOP10', 'ASVS_L2', 'DOCKER_TOP10', 'LLM_TOP10'])
                FilterChip(
                  selected: _domainFilter == d,
                  label: Text(d == 'ALL' ? 'All Domains' : d.replaceAll('_', ' '), style: const TextStyle(fontSize: 11)),
                  onSelected: (_) => setState(() => _domainFilter = d),
                ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _statusFilter,
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
                  if (v != null) setState(() => _statusFilter = v);
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _downloadReport('json'),
                icon: const Icon(Icons.code, size: 14),
                label: const Text('JSON', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                        _pill(c.reference, const Color(0xFF06B6D4)),
                        _pill(c.status, col),
                        _pill(c.severity, c.severity == 'CRITICAL' ? Colors.redAccent : Colors.orangeAccent),
                        Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(c.description, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                    const SizedBox(height: 6),
                    Text('Evidence: ${c.evidence}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                    if (c.status != 'COMPLIANT') ...[
                      const SizedBox(height: 6),
                      Text('Remediation: ${c.remediation}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: col)),
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

  // ── Tab 1: Active WSTG DAST Scanner (+ ZAP) ──────────────────────────────

  Widget _buildDastTab(ThemeData theme, bool isDark) {
    final latest = _latestDast ?? (_dastHistory.isNotEmpty ? _dastHistory.first : null);
    final origin = html.window.location.origin.isNotEmpty ? html.window.location.origin : 'http://127.0.0.1:4001';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
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
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.radar, color: Color(0xFF06B6D4), size: 20),
                      SizedBox(width: 8),
                      Text('Active Ethical OWASP WSTG DAST Scanner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Audits TLS, OWASP Secure Headers, Cookie flags, CORS, TRACE method, sensitive dotfiles (.env/.git/actuator), and benign WAF validation probes.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dastUrlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Target Caddy Route or Cluster HTTP/HTTPS URL',
                            hintText: 'https://app.gbnt.local or http://192.168.252.48:4001',
                            prefixIcon: Icon(Icons.language, size: 18),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _runDast(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _dastRunning ? null : _runDast,
                        icon: _dastRunning
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Run WSTG Audit'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), foregroundColor: Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.dashboard, size: 14),
                        label: const Text('This Dashboard (:4001)', style: TextStyle(fontSize: 11)),
                        onPressed: () => setState(() => _dastUrlCtrl.text = origin),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.api, size: 14),
                        label: const Text('Control API (:4000)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          final host = html.window.location.hostname ?? '127.0.0.1';
                          setState(() => _dastUrlCtrl.text = 'http://$host:4000');
                        },
                      ),
                      FilterChip(
                        selected: _probeWaf,
                        label: const Text('Active Benign WAF Probes (SQLi/XSS/LFI/SSRF)', style: TextStyle(fontSize: 11)),
                        onSelected: (v) => setState(() => _probeWaf = v),
                      ),
                      FilterChip(
                        selected: _includeZap,
                        label: const Text('Launch OWASP ZAP Baseline Container (Docker)', style: TextStyle(fontSize: 11)),
                        onSelected: (v) => setState(() => _includeZap = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (latest != null) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _gradeColor(latest.grade).withValues(alpha: 0.45)),
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
                        _pill('GRADE ${latest.grade} (${latest.score.toStringAsFixed(1)}%)', _gradeColor(latest.grade)),
                        _pill('HTTP ${latest.httpStatus}', Colors.blueAccent),
                        if (latest.tlsVersion.isNotEmpty) _pill(latest.tlsVersion, const Color(0xFF10B981)),
                        if (latest.wafProbesRun > 0)
                          _pill('WAF Blocked ${latest.wafBlockedCount}/${latest.wafProbesRun}', Colors.purpleAccent),
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
                            _pill(f.wstgCode, const Color(0xFF06B6D4)),
                            Text(f.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        subtitle: Text(
                          '${f.evidence}${f.status != 'PASS' ? '\nFix: ${f.remediation}' : ''}',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
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
                        child: SelectableText(
                          latest.zapOutput,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: Color(0xFFA5F3FC)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (_dastHistory.length > 1) ...[
            const SizedBox(height: 16),
            Text('Recent DAST Scan History', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._dastHistory.map((h) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: _pill(h.grade, _gradeColor(h.grade)),
                    title: Text(h.targetUrl, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: Text('${h.score.toStringAsFixed(1)}% • Pass: ${h.passedChecks} • Warn: ${h.warningChecks} • Fail: ${h.failedChecks}',
                        style: const TextStyle(fontSize: 11)),
                    trailing: TextButton(
                      onPressed: () => setState(() => _latestDast = h),
                      child: const Text('Inspect'),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: Compose Docker Top 10 Auditor (D01-D10) ───────────────────────

  Widget _buildComposeAuditorTab(ThemeData theme, bool isDark) {
    final res = _composeResult;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.fact_check_outlined, color: Color(0xFF06B6D4), size: 20),
                      const SizedBox(width: 8),
                      const Text('OWASP Docker Top 10 (D01-D10) Shift-Left Compose Auditor',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                            _composeCtrl.text = st.rawComposeFile;
                            _runComposeLint();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _composeCtrl,
                    maxLines: 10,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Select a deployed stack above or paste any docker-compose.yml here...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _composeLinting ? null : _runComposeLint,
                        icon: const Icon(Icons.security, size: 16),
                        label: const Text('Audit Compose YAML'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), foregroundColor: Colors.black),
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
                          label: const Text('Copy Auto-Hardening Snippet'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (res != null) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _gradeColor(res.grade).withValues(alpha: 0.45)),
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
                        _pill('GRADE ${res.grade} (${res.score.toStringAsFixed(1)}%)', _gradeColor(res.grade)),
                        _pill('CRITICAL: ${res.criticalCount}', res.criticalCount > 0 ? Colors.redAccent : Colors.grey),
                        _pill('HIGH: ${res.highCount}', res.highCount > 0 ? Colors.orangeAccent : Colors.grey),
                        _pill('MEDIUM: ${res.mediumCount}', res.mediumCount > 0 ? Colors.amber : Colors.grey),
                        _pill('SERVICES: ${res.servicesAudited}', const Color(0xFF06B6D4)),
                      ],
                    ),
                    if (res.parseError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('YAML Parse Error: ${res.parseError}', style: const TextStyle(color: Colors.redAccent)),
                      ),
                    const SizedBox(height: 10),
                    if (res.findings.isEmpty && res.valid)
                      const Text(
                        'Zero OWASP Docker Top 10 issues found! Compose manifest is properly hardened.',
                        style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                      )
                    else
                      ...res.findings.map((f) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: _pill(f.ruleId, f.severity == 'CRITICAL' ? Colors.redAccent : Colors.orangeAccent),
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

  Widget _domainCard(String title, double score, String domainCode, bool isDark) {
    final col = score >= 85 ? const Color(0xFF10B981) : (score >= 65 ? Colors.amber : Colors.redAccent);
    return InkWell(
      onTap: () => setState(() => _domainFilter = _domainFilter == domainCode ? 'ALL' : domainCode),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 185,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _domainFilter == domainCode ? col : col.withValues(alpha: 0.35),
            width: _domainFilter == domainCode ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${score.toStringAsFixed(1)}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: col)),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, fontFamily: 'monospace')),
    );
  }

  Color _gradeColor(String grade) {
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

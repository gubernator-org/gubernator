part of '../slo_page.dart';

// SLO Detail Modal Dialog
class _SLODetailDialog extends StatefulWidget {
  final SLOItem item;

  const _SLODetailDialog({required this.item});

  @override
  State<_SLODetailDialog> createState() => _SLODetailDialogState();
}

class _SLODetailDialogState extends State<_SLODetailDialog> {
  String _selectedRange = '24h';
  List<SLOHistoryPoint> _history = [];
  SLOREDMetrics? _redMetrics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetailData();
  }

  Future<void> _fetchDetailData() async {
    setState(() => _loading = true);
    try {
      final historyFuture = ApiService.fetchSLOHistory(widget.item.serviceId, _selectedRange);
      final redFuture = ApiService.fetchSLOREDMetrics(widget.item.serviceId);

      final results = await Future.wait([historyFuture, redFuture]);

      if (mounted) {
        setState(() {
          _history = results[0] as List<SLOHistoryPoint>;
          _redMetrics = results[1] as SLOREDMetrics;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    final double currentAvail = 100.0 - (100.0 - item.target) * (item.burnRate > 0 ? item.burnRate : 1.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text('${item.serviceName} — SLO Deep Dive',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 20),

            // Big 3 Highlight Numbers
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text('TARGET OBJECTIVE', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${item.target}%', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                          Text('Window: ${item.window}', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: theme.colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text('EST. AVAILABILITY', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${currentAvail.toStringAsFixed(2)}%',
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                          Text('Burn Rate: ${item.burnRate.toStringAsFixed(2)}x', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: theme.colorScheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text('BUDGET REMAINING', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${item.errorBudgetRemaining.toStringAsFixed(2)}%',
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                          Text('Status: ${item.status}', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Range Selector & Trend Chart
            Row(
              children: [
                Text('Error Budget Trend Chart', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: '1h', label: Text('1h')),
                    ButtonSegment(value: '6h', label: Text('6h')),
                    ButtonSegment(value: '24h', label: Text('24h')),
                    ButtonSegment(value: '7d', label: Text('7d')),
                    ButtonSegment(value: '30d', label: Text('30d')),
                  ],
                  selected: {_selectedRange},
                  onSelectionChanged: (set) {
                    setState(() => _selectedRange = set.first);
                    _fetchDetailData();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 180,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : CustomPaint(
                      painter: _SLOTrendChartPainter(history: _history, theme: theme),
                    ),
            ),
            const SizedBox(height: 20),

            // RED Metrics Cards
            Text('RED Metrics (Request Rate, Error Rate, P99 Duration)',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildREDCard('Requests / sec', '${(_redMetrics?.rps ?? 0).toStringAsFixed(1)} RPS', Icons.speed, Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildREDCard('Error Rate (5xx)', '${(_redMetrics?.errorRps ?? 0).toStringAsFixed(2)} RPS', Icons.error_outline, Colors.red),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildREDCard('P99 Latency', '${(_redMetrics?.p99LatencyMs ?? 0).toStringAsFixed(1)} ms', Icons.timer, Colors.amber),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildREDCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter for SLO Error Budget Trend Chart
class _SLOTrendChartPainter extends CustomPainter {
  final List<SLOHistoryPoint> history;
  final ThemeData theme;

  _SLOTrendChartPainter({required this.history, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final paintGrid = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1.0;

    // Draw grid lines
    canvas.drawLine(Offset(0, size.height * 0.2), Offset(size.width, size.height * 0.2), paintGrid);
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), paintGrid);
    canvas.drawLine(Offset(0, size.height * 0.8), Offset(size.width, size.height * 0.8), paintGrid);

    if (history.length < 2) {
      final textPainter = TextPainter(
        text: const TextSpan(text: 'Simulated Budget Trend: 100% Stable', style: TextStyle(color: Colors.white38, fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
      return;
    }

    final path = Path();
    final double dx = size.width / (history.length - 1);

    for (int i = 0; i < history.length; i++) {
      final pt = history[i];
      final double y = size.height - (pt.budgetRemaining / 100.0) * size.height;
      final double x = i * dx;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paintLine);
  }

  @override
  bool shouldRepaint(covariant _SLOTrendChartPainter oldDelegate) => true;
}

// SLO Form Dialog (Add / Edit / Disable)
class _SLOFormDialog extends StatefulWidget {
  final SLOItem? existingItem;
  final List<Service> services;
  final VoidCallback onSave;

  const _SLOFormDialog({
    this.existingItem,
    required this.services,
    required this.onSave,
  });

  @override
  State<_SLOFormDialog> createState() => _SLOFormDialogState();
}

class _SLOFormDialogState extends State<_SLOFormDialog> {
  late String _serviceId;
  late TextEditingController _targetController;
  late String _window;
  late String _indicator;
  late TextEditingController _latencyThresholdController;
  late String _template;
  late TextEditingController _journeyController;
  late TextEditingController _errorQueryController;
  late TextEditingController _totalQueryController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _serviceId = item?.serviceId ?? (widget.services.isNotEmpty ? widget.services.first.id : '');
    _targetController = TextEditingController(text: item != null ? '${item.target}' : '99.9');
    _window = item?.window ?? '30d';
    _indicator = item?.indicator ?? 'ratio';
    _latencyThresholdController = TextEditingController(text: item?.latencyThreshold ?? '200ms');
    _template = item?.template ?? 'caddy-http';
    _journeyController = TextEditingController(text: item?.journey ?? '');
    _errorQueryController = TextEditingController(text: item?.errorQuery ?? '');
    _totalQueryController = TextEditingController(text: item?.totalQuery ?? '');
  }

  @override
  void dispose() {
    _targetController.dispose();
    _latencyThresholdController.dispose();
    _journeyController.dispose();
    _errorQueryController.dispose();
    _totalQueryController.dispose();
    super.dispose();
  }

  Future<void> _submit(bool enable) async {
    if (!enable && widget.existingItem != null) {
      setState(() => _saving = true);
      final ok = await ApiService.deleteSLO(widget.existingItem!.serviceId);
      if (mounted) {
        setState(() => _saving = false);
        if (ok) {
          widget.onSave();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SLO disabled and rules synced.')),
          );
        }
      }
      return;
    }

    final target = double.tryParse(_targetController.text.trim()) ?? 99.9;
    setState(() => _saving = true);

    final ok = await ApiService.editSLO(
      serviceId: _serviceId,
      enable: enable,
      target: target,
      window: _window,
      indicator: _indicator,
      latencyThreshold: _latencyThresholdController.text.trim(),
      template: _template,
      journey: _journeyController.text.trim(),
      errorQuery: _errorQueryController.text.trim(),
      totalQuery: _totalQueryController.text.trim(),
    );

    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        widget.onSave();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(enable ? 'SLO configuration saved & rules synced.' : 'SLO disabled.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save SLO configuration.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingItem != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isEditing ? Icons.edit : Icons.add_chart, color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Configure SLO — ${widget.existingItem!.serviceName}' : 'Add / Configure New SLO',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 20),

              // Service Selector (if new)
              if (!isEditing) ...[
                const Text('Select Service:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _serviceId.isNotEmpty ? _serviceId : null,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: widget.services
                      .map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text('${s.name} (Stack: ${s.stackId.length > 8 ? s.stackId.substring(0, 8) : s.stackId})'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _serviceId = val);
                  },
                ),
                const SizedBox(height: 16),
              ],

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Target Availability %:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _targetController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, suffixText: '%'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Time Window:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _window,
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                          items: const [
                            DropdownMenuItem(value: '30d', child: Text('30 Days (Standard)')),
                            DropdownMenuItem(value: '7d', child: Text('7 Days')),
                            DropdownMenuItem(value: '24h', child: Text('24 Hours')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _window = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SLI Query Template:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _template,
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'caddy-http', child: Text('caddy-http (Reverse Proxy 5xx)')),
                            DropdownMenuItem(value: 'http-status', child: Text('http-status (HTTP 5xx Rate)')),
                            DropdownMenuItem(value: 'latency-p99', child: Text('latency-p99 (P99 Duration)')),
                            DropdownMenuItem(value: 'grpc', child: Text('grpc (gRPC Error Codes)')),
                            DropdownMenuItem(value: 'host-disk', child: Text('host-disk (Node Disk Capacity < 15%)')),
                            DropdownMenuItem(value: 'gluster-storage', child: Text('gluster-storage (GlusterFS Cluster Pool)')),
                            DropdownMenuItem(value: '', child: Text('Custom PromQL Queries')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _template = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('User Journey Name:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _journeyController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            hintText: 'e.g. Checkout Flow',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_template.isEmpty) ...[
                const Text('Custom PromQL Error Query:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: _errorQueryController,
                  style: const TextStyle(fontFamily: 'Courier New', fontSize: 12),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'sum(rate(my_errors_total[{{.window}}]))',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Custom PromQL Total Query:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: _totalQueryController,
                  style: const TextStyle(fontFamily: 'Courier New', fontSize: 12),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'sum(rate(my_requests_total[{{.window}}]))',
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isEditing) ...[
                    OutlinedButton.icon(
                      onPressed: _saving ? null : () => _submit(false),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Disable SLO'),
                    ),
                    const Spacer(),
                  ],
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _submit(true),
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check),
                    label: const Text('Save & Sync Rules'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// SLO Alert Notifications Configuration Dialog (Email / Webhook / Triggers)
class _SLONotificationsDialog extends StatefulWidget {
  const _SLONotificationsDialog();

  @override
  State<_SLONotificationsDialog> createState() => _SLONotificationsDialogState();
}

class _SLONotificationsDialogState extends State<_SLONotificationsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  bool _saving = false;
  bool _testingEmail = false;
  bool _testingWebhook = false;

  bool _enableEmail = false;
  late TextEditingController _smtpHostController;
  late TextEditingController _smtpPortController;
  late TextEditingController _smtpUserController;
  late TextEditingController _smtpPassController;
  late TextEditingController _fromEmailController;
  late TextEditingController _toEmailController;

  bool _enableWebhook = false;
  late TextEditingController _webhookUrlController;

  bool _notifyOnExhaustion = true;
  bool _notifyOnBurn = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _smtpHostController = TextEditingController();
    _smtpPortController = TextEditingController(text: '587');
    _smtpUserController = TextEditingController();
    _smtpPassController = TextEditingController();
    _fromEmailController = TextEditingController();
    _toEmailController = TextEditingController();
    _webhookUrlController = TextEditingController();
    _loadConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _smtpUserController.dispose();
    _smtpPassController.dispose();
    _fromEmailController.dispose();
    _toEmailController.dispose();
    _webhookUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final res = await ApiService.fetchSLONotifyConfig();
      if (mounted) {
        setState(() {
          _enableEmail = res['enable_email'] == true;
          _smtpHostController.text = res['smtp_host'] ?? 'smtp.gmail.com';
          _smtpPortController.text = '${res['smtp_port'] ?? 587}';
          _smtpUserController.text = res['smtp_user'] ?? '';
          _smtpPassController.text = res['smtp_pass'] ?? '';
          _fromEmailController.text = res['from_email'] ?? 'alerts@gubernator.local';
          _toEmailController.text = res['to_email'] ?? '';

          _enableWebhook = res['enable_webhook'] == true;
          _webhookUrlController.text = res['webhook_url'] ?? '';

          _notifyOnExhaustion = res['notify_on_exhaustion'] != false;
          _notifyOnBurn = res['notify_on_burn'] != false;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    final cfg = {
      'enable_email': _enableEmail,
      'smtp_host': _smtpHostController.text.trim(),
      'smtp_port': int.tryParse(_smtpPortController.text.trim()) ?? 587,
      'smtp_user': _smtpUserController.text.trim(),
      'smtp_pass': _smtpPassController.text.trim(),
      'from_email': _fromEmailController.text.trim(),
      'to_email': _toEmailController.text.trim(),
      'enable_webhook': _enableWebhook,
      'webhook_url': _webhookUrlController.text.trim(),
      'notify_on_exhaustion': _notifyOnExhaustion,
      'notify_on_burn': _notifyOnBurn,
    };
    final ok = await ApiService.saveSLONotifyConfig(cfg);
    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SLO alert notification channels saved.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save notification configuration.')),
        );
      }
    }
  }

  Future<void> _testChannel(String channel) async {
    if (channel == 'email') setState(() => _testingEmail = true);
    if (channel == 'webhook') setState(() => _testingWebhook = true);
    try {
      final res = await ApiService.testSLONotify(channel);
      if (mounted) {
        final msg = res['message'] ?? res['error'] ?? 'Completed';
        final isErr = res.containsKey('error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: isErr ? Theme.of(context).colorScheme.error : Colors.green.shade800,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _testingEmail = false;
          _testingWebhook = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        height: 520,
        padding: const EdgeInsets.all(24),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_active, color: theme.colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'SLO Alert Notification Settings',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(icon: Icon(Icons.email_outlined, size: 18), text: 'Email (SMTP)'),
                      Tab(icon: Icon(Icons.webhook_outlined, size: 18), text: 'Webhook'),
                      Tab(icon: Icon(Icons.tune, size: 18), text: 'Triggers'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Email (SMTP)
                        SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                title: const Text('Enable Email Alert Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: const Text('Send automatic SMTP emails when SLO target is breached or budget exhausted.'),
                                value: _enableEmail,
                                onChanged: (val) => setState(() => _enableEmail = val),
                              ),
                              const Divider(),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: _smtpHostController,
                                      enabled: _enableEmail,
                                      decoration: const InputDecoration(labelText: 'SMTP Host', hintText: 'smtp.gmail.com', isDense: true),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 1,
                                    child: TextField(
                                      controller: _smtpPortController,
                                      enabled: _enableEmail,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Port', hintText: '587', isDense: true),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _smtpUserController,
                                      enabled: _enableEmail,
                                      decoration: const InputDecoration(labelText: 'SMTP User (Optional)', isDense: true),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _smtpPassController,
                                      enabled: _enableEmail,
                                      obscureText: true,
                                      decoration: const InputDecoration(labelText: 'SMTP Password (Optional)', isDense: true),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _fromEmailController,
                                      enabled: _enableEmail,
                                      decoration: const InputDecoration(labelText: 'From Address', hintText: 'alerts@gubernator.local', isDense: true),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _toEmailController,
                                      enabled: _enableEmail,
                                      decoration: const InputDecoration(labelText: 'Recipient Email (To)', hintText: 'devops@company.com', isDense: true),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: (_enableEmail && !_testingEmail) ? () => _testChannel('email') : null,
                                icon: _testingEmail
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.send, size: 16),
                                label: const Text('Send Test Email Alert'),
                              ),
                            ],
                          ),
                        ),

                        // Tab 2: Webhook
                        SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                title: const Text('Enable Webhook Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: const Text('Post JSON alert payloads to Slack, Discord, Microsoft Teams, or custom endpoints.'),
                                value: _enableWebhook,
                                onChanged: (val) => setState(() => _enableWebhook = val),
                              ),
                              const Divider(),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _webhookUrlController,
                                enabled: _enableWebhook,
                                decoration: const InputDecoration(
                                  labelText: 'Webhook URL',
                                  hintText: 'https://hooks.slack.com/services/... or https://discord.com/api/webhooks/...',
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: (_enableWebhook && !_testingWebhook) ? () => _testChannel('webhook') : null,
                                icon: _testingWebhook
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.send, size: 16),
                                label: const Text('Send Test Webhook Alert'),
                              ),
                            ],
                          ),
                        ),

                        // Tab 3: Triggers
                        SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                title: const Text('Alert on Budget Exhaustion (0% Remaining)', style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: const Text('Triggers immediate alert when service Error Budget is completely consumed.'),
                                value: _notifyOnExhaustion,
                                onChanged: (val) => setState(() => _notifyOnExhaustion = val == true),
                              ),
                              const Divider(),
                              CheckboxListTile(
                                title: const Text('Alert on High Burn Rate (> 1.0x)', style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: const Text('Triggers multi-window burn rate alert when error rate threatens SLO objective.'),
                                value: _notifyOnBurn,
                                onChanged: (val) => setState(() => _notifyOnBurn = val == true),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _saving ? null : _saveConfig,
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save),
                        label: const Text('Save Notification Settings'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}


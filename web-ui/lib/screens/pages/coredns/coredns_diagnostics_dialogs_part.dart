part of '../coredns_page.dart';

extension _CoreDnsDiagnosticsExt on _CoreDnsPageState {

  void _showCurlDialog(String hostname, String ip) {
    String selectedProtocol = 'http';
    String selectedMethod = 'GET';
    bool followRedirect = true;
    bool insecure = true;
    int timeoutSec = 5;
    bool running = true;
    DNSCurlResult? curlResult;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);

          void runCurl() async {
            setDialogState(() {
              running = true;
            });
            final res = await ApiService.performDNSCurl(
              hostname: hostname,
              ip: ip,
              protocol: selectedProtocol,
              method: selectedMethod,
              followRedirect: followRedirect,
              insecure: insecure,
              timeoutSeconds: timeoutSec,
            );
            if (context.mounted) {
              setDialogState(() {
                curlResult = res;
                running = false;
              });
            }
          }

          if (curlResult == null && running) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              runCurl();
            });
          }

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF58A6FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.terminal, color: Color(0xFF58A6FF), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Curl Resolution Test — $hostname',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Executing from Cluster Manager (Target IP: ${ip.isNotEmpty ? ip : "Dynamic"})',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 720,
              height: 540,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'http', label: Text('HTTP')),
                              ButtonSegment(value: 'https', label: Text('HTTPS')),
                            ],
                            selected: {selectedProtocol},
                            onSelectionChanged: (newVal) {
                              setDialogState(() {
                                selectedProtocol = newVal.first;
                              });
                              runCurl();
                            },
                            style: SegmentedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: selectedMethod,
                            isDense: true,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 'GET', child: Text('GET')),
                              DropdownMenuItem(value: 'HEAD', child: Text('HEAD')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedMethod = val);
                                runCurl();
                              }
                            },
                          ),
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: followRedirect,
                                visualDensity: VisualDensity.compact,
                                onChanged: (v) {
                                  setDialogState(() => followRedirect = v ?? true);
                                  runCurl();
                                },
                              ),
                              const Text('-L (Follow)', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: running ? null : runCurl,
                            icon: running
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.refresh, size: 16),
                            label: const Text('Re-run Curl'),
                            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (curlResult != null) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (curlResult!.statusCode >= 200 && curlResult!.statusCode < 300)
                                ? Colors.green.withValues(alpha: 0.2)
                                : (curlResult!.statusCode >= 300 && curlResult!.statusCode < 400)
                                    ? Colors.amber.withValues(alpha: 0.2)
                                    : Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (curlResult!.statusCode >= 200 && curlResult!.statusCode < 300)
                                  ? Colors.green
                                  : (curlResult!.statusCode >= 300 && curlResult!.statusCode < 400)
                                      ? Colors.amber
                                      : Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            curlResult!.statusCode > 0
                                ? '${curlResult!.statusCode} ${curlResult!.statusText}'
                                : (curlResult!.error ?? 'FAILED'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: (curlResult!.statusCode >= 200 && curlResult!.statusCode < 300)
                                  ? Colors.green
                                  : (curlResult!.statusCode >= 300 && curlResult!.statusCode < 400)
                                      ? Colors.amber
                                      : Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          avatar: const Icon(Icons.timer_outlined, size: 14),
                          label: Text('${curlResult!.latencyMs.toStringAsFixed(1)} ms'),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          avatar: const Icon(Icons.dns, size: 14),
                          label: Text(ip.isNotEmpty ? ip : 'Dynamic DNS'),
                          visualDensity: VisualDensity.compact,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: 'Copy Curl Command',
                          onPressed: () {
                            ClipboardService.copy(curlResult!.command);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied curl command!')),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new, size: 16),
                          tooltip: 'Open in Browser ($selectedProtocol://$hostname)',
                          onPressed: () {
                            html.window.open('$selectedProtocol://$hostname', '_blank');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: running && curlResult == null
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 12),
                                  Text('Executing curl resolution test from cluster manager...',
                                      style: TextStyle(fontFamily: 'Courier New', color: Color(0xFF8B949E))),
                                ],
                              ),
                            )
                          : SelectableText(
                              curlResult?.rawOutput.isNotEmpty == true
                                  ? curlResult!.rawOutput
                                  : (curlResult?.error ?? 'No output returned'),
                              style: const TextStyle(
                                fontFamily: 'Courier New',
                                fontSize: 12,
                                color: Color(0xFF58A6FF),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (curlResult != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Output'),
                  onPressed: () {
                    ClipboardService.copy(curlResult!.rawOutput);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied curl output to clipboard!')),
                    );
                  },
                ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text('Open in Browser ($selectedProtocol)'),
                onPressed: () {
                  html.window.open('$selectedProtocol://$hostname', '_blank');
                },
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPingDialog(String hostname, String ip) {
    int packetCount = 3;
    bool running = true;
    DNSPingResult? pingResult;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);

          void runPing() async {
            setDialogState(() {
              running = true;
            });
            final res = await ApiService.performDNSPing(
              hostname: hostname,
              ip: ip,
              count: packetCount,
            );
            if (context.mounted) {
              setDialogState(() {
                pingResult = res;
                running = false;
              });
            }
          }

          if (pingResult == null && running) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              runPing();
            });
          }

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3FB950).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.network_ping, color: Color(0xFF3FB950), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ping Reachability Test — $hostname',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('ICMP Network Reachability (Target: ${ip.isNotEmpty ? ip : hostname})',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 680,
              height: 480,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Text('Packets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: packetCount,
                            isDense: true,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('1 packet')),
                              DropdownMenuItem(value: 3, child: Text('3 packets')),
                              DropdownMenuItem(value: 5, child: Text('5 packets')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => packetCount = val);
                                runPing();
                              }
                            },
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: running ? null : runPing,
                            icon: running
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.refresh, size: 16),
                            label: const Text('Re-run Ping'),
                            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (pingResult != null) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: pingResult!.packetLoss == 0
                                ? Colors.green.withValues(alpha: 0.2)
                                : (pingResult!.packetLoss < 50)
                                    ? Colors.amber.withValues(alpha: 0.2)
                                    : Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: pingResult!.packetLoss == 0
                                  ? Colors.green
                                  : (pingResult!.packetLoss < 50)
                                      ? Colors.amber
                                      : Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${pingResult!.packetLoss.toStringAsFixed(0)}% Packet Loss (${pingResult!.packetsRecv}/${pingResult!.packetsSent})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: pingResult!.packetLoss == 0
                                  ? Colors.green
                                  : (pingResult!.packetLoss < 50)
                                      ? Colors.amber
                                      : Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (pingResult!.avgLatency > 0)
                          Chip(
                            avatar: const Icon(Icons.speed, size: 14),
                            label: Text('Avg: ${pingResult!.avgLatency.toStringAsFixed(2)} ms'),
                            visualDensity: VisualDensity.compact,
                          ),
                        const SizedBox(width: 8),
                        if (pingResult!.minLatency > 0)
                          Chip(
                            label: Text('Min: ${pingResult!.minLatency.toStringAsFixed(2)} ms | Max: ${pingResult!.maxLatency.toStringAsFixed(2)} ms'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: running && pingResult == null
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 12),
                                  Text('Executing ping from cluster manager...',
                                      style: TextStyle(fontFamily: 'Courier New', color: Color(0xFF8B949E))),
                                ],
                              ),
                            )
                          : SelectableText(
                              pingResult?.rawOutput.isNotEmpty == true
                                  ? pingResult!.rawOutput
                                  : (pingResult?.error ?? 'No output returned'),
                              style: const TextStyle(
                                fontFamily: 'Courier New',
                                fontSize: 12,
                                color: Color(0xFF3FB950),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (pingResult != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Output'),
                  onPressed: () {
                    ClipboardService.copy(pingResult!.rawOutput);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied ping output to clipboard!')),
                    );
                  },
                ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditClusterDomainDialog(String currentDomain) {
    final controller = TextEditingController(text: currentDomain);
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.language, color: Colors.cyanAccent),
              SizedBox(width: 10),
              Text('Edit Cluster Base Domain'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set the base DNS domain for internal service resolution across all Centurion nodes. '
                  'Gubernator will automatically regenerate container hostnames and reload CoreDNS without downtime.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Cluster Domain',
                    hintText: 'e.g. gbnt.local, acme.corp, internal.banco.es',
                    prefixIcon: Icon(Icons.dns),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Colors.cyanAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Example: node-1.caddy.${controller.text.isNotEmpty ? controller.text.trim() : "domain"}',
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: saving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 16),
              label: const Text('Save & Reload DNS'),
              onPressed: saving
                  ? null
                  : () async {
                      final newDomain = controller.text.trim().toLowerCase();
                      if (newDomain.isEmpty) return;
                      setDialogState(() => saving = true);
                      final ok = await ApiService.updateClusterDomain(newDomain);
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                      }
                      if (mounted) {
                        if (ok) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text('Cluster base domain updated to $newDomain and CoreDNS reloaded.')),
                          );
                          widget.onRefresh();
                          _loadSuiteData();
                        } else {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('Failed to update cluster domain.')),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

// Modal Dialog to Add Custom Static DNS Record
class _AddCustomRecordDialog extends StatefulWidget {
  final VoidCallback onSaved;

  const _AddCustomRecordDialog({required this.onSaved});

  @override
  State<_AddCustomRecordDialog> createState() => _AddCustomRecordDialogState();
}

class _AddCustomRecordDialogState extends State<_AddCustomRecordDialog> {
  final TextEditingController _domainController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _ttlController = TextEditingController(text: '60');
  String _recordType = 'A';
  bool _saving = false;

  @override
  void dispose() {
    _domainController.dispose();
    _ipController.dispose();
    _ttlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final domain = _domainController.text.trim();
    final ip = _ipController.text.trim();
    final ttl = int.tryParse(_ttlController.text.trim()) ?? 60;

    if (domain.isEmpty || ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Domain and IP/Value are required.')));
      return;
    }

    setState(() => _saving = true);
    final ok = await ApiService.createCustomDNSRecord(
      domain: domain,
      ip: ip,
      recordType: _recordType,
      ttl: ttl,
    );

    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        widget.onSaved();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Custom static DNS record added successfully.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add custom DNS record.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dns, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text('Add Custom Static DNS Record', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _domainController,
                    decoration: const InputDecoration(
                      labelText: 'Domain Name',
                      hintText: 'e.g. redis.gbnt or api.mycompany.test',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _recordType,
                    decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'A', child: Text('A (IPv4)')),
                      DropdownMenuItem(value: 'AAAA', child: Text('AAAA (IPv6)')),
                      DropdownMenuItem(value: 'CNAME', child: Text('CNAME')),
                      DropdownMenuItem(value: 'TXT', child: Text('TXT')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _recordType = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Target Value / IP Address',
                hintText: 'e.g. 192.168.252.30',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ttlController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'TTL (Seconds)',
                suffixText: 'sec',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: const Text('Save Record & Reload DNS'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

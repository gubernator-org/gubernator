part of '../ebpf_page.dart';

// ── Flow Details Dialog ─────────────────────────────────────────────────────

class _FlowDetailsDialog extends StatelessWidget {
  final EbpfFlow flow;

  const _FlowDetailsDialog({required this.flow});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.grain, color: Color(0xFF06B6D4), size: 20),
          const SizedBox(width: 8),
          Text('eBPF Captured Flow Telemetry', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRow('Flow ID', flow.id, theme, copyable: true),
              _buildRow('Timestamp', flow.timestamp.toIso8601String(), theme),
              _buildRow('Protocol', flow.protocol, theme),
              _buildRow('Status', '${flow.status.toUpperCase()} (${flow.statusCode})', theme),
              _buildRow('Source Endpoint', '${flow.sourceName} (${flow.sourceIp}:${flow.sourcePort})', theme),
              _buildRow('Destination Endpoint', '${flow.destName} (${flow.destIp}:${flow.destPort})', theme),
              if (flow.path.isNotEmpty) _buildRow('Path / Method', '${flow.method} ${flow.path}', theme),
              if (flow.traceId.isNotEmpty) _buildRow('Jaeger Trace ID', flow.traceId, theme, copyable: true),
              _buildRow('Latency (RTT)', '${flow.latencyMs.toStringAsFixed(2)} ms', theme),
              _buildRow('Bytes Sent / Recv', '${flow.bytesSent} B / ${flow.bytesReceived} B', theme),
              _buildRow('Throughput Rate', '${(flow.throughputBps / 1024).toStringAsFixed(2)} KB/s', theme),
              _buildRow('Retransmits / Drops', '${flow.retransmits} / ${flow.drops}', theme),
            ],
          ),
        ),
      ),
      actions: [
        if (flow.traceId.isNotEmpty)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.purple.withValues(alpha: 0.2),
              foregroundColor: Colors.purpleAccent,
              side: const BorderSide(color: Colors.purpleAccent),
            ),
            onPressed: () {
              final host = html.window.location.hostname ?? '127.0.0.1';
              final url = 'http://$host:16686/trace/${flow.traceId}';
              html.window.open(url, '_blank');
            },
            icon: const Icon(Icons.timeline, size: 14),
            label: const Text('Open in Jaeger (:16686)', style: TextStyle(fontSize: 11)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value, ThemeData theme, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                if (copyable)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 14),
                    tooltip: 'Copy',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Simulation Dialog ───────────────────────────────────────────────────────

class _SimulationDialog extends StatefulWidget {
  final Function(String pattern, int rate, int duration, double errors) onSimulate;

  const _SimulationDialog({required this.onSimulate});

  @override
  State<_SimulationDialog> createState() => _SimulationDialogState();
}

class _SimulationDialogState extends State<_SimulationDialog> {
  String _pattern = 'burst';
  int _rate = 15;
  int _duration = 10;
  double _errors = 0.0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.bolt, color: Color(0xFF06B6D4)),
          SizedBox(width: 8),
          Text('Trigger eBPF Traffic Simulation'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inject simulated traffic flows across discovered cluster containers to evaluate live graphs, test filters, or trigger SLO error budget burns.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Pattern Selector
            DropdownButtonFormField<String>(
              initialValue: _pattern,
              decoration: const InputDecoration(labelText: 'Traffic Pattern', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('Normal Web Traffic (200 OK)')),
                DropdownMenuItem(value: 'burst', child: Text('Burst Spike (High Rate)')),
                DropdownMenuItem(value: 'errors', child: Text('Fault Injection (500/502 Errors)')),
                DropdownMenuItem(value: 'mixed', child: Text('Mixed Microservices')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _pattern = val);
              },
            ),
            const SizedBox(height: 14),

            // Rate Slider
            Text('Rate: $_rate events/sec', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Slider(
              value: _rate.toDouble(),
              min: 2,
              max: 50,
              divisions: 24,
              activeColor: const Color(0xFF06B6D4),
              onChanged: (val) => setState(() => _rate = val.toInt()),
            ),

            // Duration Slider
            Text('Duration: $_duration seconds', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Slider(
              value: _duration.toDouble(),
              min: 3,
              max: 60,
              divisions: 19,
              activeColor: const Color(0xFF06B6D4),
              onChanged: (val) => setState(() => _duration = val.toInt()),
            ),

            // Error Injection Slider
            Text('Error Percentage: ${_errors.toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Slider(
              value: _errors,
              min: 0,
              max: 100,
              divisions: 20,
              activeColor: Colors.redAccent,
              onChanged: (val) => setState(() => _errors = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onSimulate(_pattern, _rate, _duration, _errors);
          },
          icon: const Icon(Icons.bolt, size: 16),
          label: const Text('Start Simulation'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), foregroundColor: Colors.black),
        ),
      ],
    );
  }
}


import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/ebpf_animated_mesh_canvas.dart';

part 'ebpf/ebpf_tabs_part.dart';
part 'ebpf/ebpf_dialogs_part.dart';

/// Dedicated eBPF Live Hub Page for Kernel Network Observability,
/// L4/L7 Flow Tracing, and Service Mesh Topology.
class EbpfPage extends StatefulWidget {
  const EbpfPage({super.key});

  @override
  State<EbpfPage> createState() => _EbpfPageState();
}

class _EbpfPageState extends State<EbpfPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Telemetry & State
  EbpfStats? _stats;
  List<EbpfFlow> _flows = [];
  EbpfTopology? _topology;
  bool _loading = true;

  // Topology View Mode: 'canvas' (2D Vector Graph with animated particles) or 'matrix' (edges table)
  String _topologyViewMode = 'canvas';

  // Filters
  String _selectedProtocol = 'ALL';
  String _selectedStatus = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();
  int _limit = 50;

  // Live Auto-Refresh
  bool _autoRefresh = true;
  Timer? _refreshTimer;

  final List<String> _protocols = [
    'ALL',
    'HTTP',
    'gRPC',
    'DNS',
    'TCP',
    'UDP',
    'REDIS',
    'POSTGRES',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
    _startTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    if (_autoRefresh) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted) {
          _fetchFlowsAndStatsSilently();
        }
      });
    }
  }

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefresh = !_autoRefresh;
      if (_autoRefresh) {
        _startTimer();
      } else {
        _refreshTimer?.cancel();
      }
    });
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    try {
      final statsFuture = ApiService.fetchEbpfStats();
      final flowsFuture = ApiService.fetchEbpfFlows(
        limit: _limit,
        protocol: _selectedProtocol,
        status: _selectedStatus,
        query: _searchCtrl.text.trim(),
      );
      final topoFuture = ApiService.fetchEbpfTopology();

      final results = await Future.wait([statsFuture, flowsFuture, topoFuture]);
      if (mounted) {
        setState(() {
          _stats = results[0] as EbpfStats;
          _flows = results[1] as List<EbpfFlow>;
          _topology = results[2] as EbpfTopology;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _fetchFlowsAndStatsSilently() async {
    try {
      final statsFuture = ApiService.fetchEbpfStats();
      final flowsFuture = ApiService.fetchEbpfFlows(
        limit: _limit,
        protocol: _selectedProtocol,
        status: _selectedStatus,
        query: _searchCtrl.text.trim(),
      );
      final topoFuture = _tabController.index == 1 ? ApiService.fetchEbpfTopology() : null;

      final stats = await statsFuture;
      final flows = await flowsFuture;
      EbpfTopology? topo;
      if (topoFuture != null) {
        topo = await topoFuture;
      }

      if (mounted) {
        setState(() {
          _stats = stats;
          _flows = flows;
          if (topo != null) {
            _topology = topo;
          }
        });
      }
    } catch (_) {}
  }

  void _openSimulationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _SimulationDialog(
        onSimulate: (pattern, rate, duration, errors) async {
          final success = await ApiService.simulateEbpfTraffic(
            pattern: pattern,
            rate: rate,
            durationS: duration,
            errorPct: errors,
          );
          if (mounted && success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚡ eBPF traffic simulation started ($pattern @ $rate req/s)'),
                backgroundColor: const Color(0xFF06B6D4),
                behavior: SnackBarBehavior.floating,
              ),
            );
            _fetchFlowsAndStatsSilently();
          }
        },
      ),
    );
  }

  void _openFlowDetails(EbpfFlow flow) {
    showDialog(
      context: context,
      builder: (ctx) => _FlowDetailsDialog(flow: flow),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top Header Toolbar ─────────────────────────────────────────
          _buildHeaderToolbar(theme),

          // ── Navigation Tabs ────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF06B6D4),
              unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              indicatorColor: const Color(0xFF06B6D4),
              indicatorWeight: 3,
              tabs: [
                Tab(
                  icon: const Icon(Icons.swap_calls, size: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Live Captured Flows'),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_flows.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  icon: const Icon(Icons.hub, size: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Service Mesh Topology'),
                      if (_topology != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_topology!.nodes.length} Nodes',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(
                  icon: Icon(Icons.memory, size: 18),
                  text: 'Kernel Probes & Diagnostics',
                ),
              ],
            ),
          ),

          // ── Tab Views ──────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFlowsTab(theme),
                      _buildTopologyTab(theme),
                      _buildDiagnosticsTab(theme),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderToolbar(ThemeData theme) {
    final mode = _stats?.mode ?? 'kernel';
    final isKernel = mode == 'kernel';
    final kernelVer = _stats?.kernelVersion ?? 'detecting...';
    final activeProbes = _stats?.activeProbes ?? 8;
    final pktsRate = _stats?.packetsPerSec ?? 0.0;
    final bytesRate = _stats?.bytesPerSec ?? 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.grain, color: Color(0xFF06B6D4), size: 22),
          ),
          const SizedBox(width: 14),

          // Title & Subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'eBPF Live Hub & Kernel Observability',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  // Mode Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isKernel
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isKernel
                            ? const Color(0xFF10B981).withValues(alpha: 0.4)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isKernel ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isKernel ? 'eBPF KERNEL ACTIVE' : 'eBPF EMULATION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isKernel ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Kernel $kernelVer • Socket & packet tracing with L4/L7 protocol decoding and service mesh topology.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),

          const Spacer(),

          // Telemetry Pills
          _buildPill(
            icon: Icons.shield,
            label: 'Probes',
            value: '$activeProbes Active',
            color: const Color(0xFF06B6D4),
            theme: theme,
          ),
          const SizedBox(width: 8),
          _buildPill(
            icon: Icons.speed,
            label: 'Rate',
            value: '${pktsRate.toStringAsFixed(1)} pkts/s',
            color: Colors.blueAccent,
            theme: theme,
          ),
          const SizedBox(width: 8),
          _buildPill(
            icon: Icons.swap_vert,
            label: 'Throughput',
            value: _formatBytesRate(bytesRate),
            color: Colors.tealAccent,
            theme: theme,
          ),

          const SizedBox(width: 16),

          // Live Tail Toggle
          OutlinedButton.icon(
            onPressed: _toggleAutoRefresh,
            icon: Icon(
              _autoRefresh ? Icons.pause_circle_outline : Icons.play_circle_outline,
              size: 16,
              color: _autoRefresh ? const Color(0xFF10B981) : Colors.grey,
            ),
            label: Text(
              _autoRefresh ? 'Live Tail (2s)' : 'Paused',
              style: TextStyle(color: _autoRefresh ? const Color(0xFF10B981) : null),
            ),
          ),
          const SizedBox(width: 8),

          // Refresh Button
          IconButton(
            tooltip: 'Refresh Now',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadAllData,
          ),
          const SizedBox(width: 8),

          // Simulation Button
          FilledButton.icon(
            onPressed: _openSimulationDialog,
            icon: const Icon(Icons.bolt, size: 16),
            label: const Text('Simulate Traffic'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateState(VoidCallback fn) {
    if (mounted) setState(fn);
  }
}

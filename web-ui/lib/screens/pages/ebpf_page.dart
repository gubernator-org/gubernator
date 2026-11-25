import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/ebpf_animated_mesh_canvas.dart';

part 'ebpf/ebpf_tabs_part.dart';
part 'ebpf/ebpf_security_tabs_part.dart';
part 'ebpf/ebpf_dialogs_part.dart';

/// Dedicated eBPF Live Hub Page for Multi-Node Kernel Network Observability,
/// Runtime IDS Threat Detection, Attack Surface & Zero-Trust, Purple Team MITRE Lab,
/// and Forensic Response (Quarantine + PCAP + Process Timeline).
class EbpfPage extends StatefulWidget {
  final int selectedSubIndex;

  const EbpfPage({super.key, this.selectedSubIndex = 0});

  @override
  State<EbpfPage> createState() => _EbpfPageState();
}

class _EbpfPageState extends State<EbpfPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Core Telemetry & State
  EbpfStats? _stats;
  List<EbpfFlow> _flows = [];
  EbpfTopology? _topology;
  List<EbpfNodeTelemetry> _nodes = [];
  bool _loading = true;

  // Security IDS, Attack Surface, Zero-Trust & Forensics State
  List<EbpfSecurityAlert> _alerts = [];
  List<EbpfAttackSurfaceEntry> _attackSurface = [];
  EbpfZeroTrustBaseline _zeroTrust = EbpfZeroTrustBaseline();
  List<EbpfProcessSocket> _processes = [];
  List<EbpfQuarantineRecord> _quarantines = [];
  List<EbpfPcapCapture> _pcaps = [];
  List<EbpfPurpleTeamScenario> _purpleScenarios = [];
  List<EbpfPurpleTeamRun> _purpleRuns = [];

  // View Modes & Sub-tab States
  String _topologyViewMode = 'canvas';
  String _surfaceSubMode = 'surface'; // 'surface' or 'zerotrust'
  String _forensicsSubMode = 'purple'; // 'purple', 'quarantine', 'pcap', 'processes'
  String _ztPolicyFormat = 'nftables'; // 'nftables' or 'iptables'

  // Filters
  String _selectedProtocol = 'ALL';
  String _selectedStatus = 'ALL';
  String _selectedNode = 'ALL';
  bool _realOnlyFlows = false;
  final TextEditingController _searchCtrl = TextEditingController();
  int _limit = 50;

  // Alerts & Surface Filters
  String _alertSeverity = 'ALL';
  String _alertStatus = 'ALL';
  bool _shadowPortsOnly = false;
  final TextEditingController _processSearchCtrl = TextEditingController();

  // Purple Team & PCAP Controls
  String _purpleTargetNode = 'manager';
  String _purpleTargetContainer = 'gbnt-caddy';
  bool _runningPurple = false;
  bool _scanningSurface = false;
  bool _capturingPcap = false;

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
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.selectedSubIndex.clamp(0, 5),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
        _fetchTabDataSilently();
      }
    });
    _loadAllData();
    _startTimer();
  }

  @override
  void didUpdateWidget(EbpfPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSubIndex != widget.selectedSubIndex) {
      final target = widget.selectedSubIndex.clamp(0, 5);
      if (_tabController.index != target) {
        _tabController.animateTo(target);
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _searchCtrl.dispose();
    _processSearchCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    if (_autoRefresh) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted) {
          _fetchTabDataSilently();
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

  List<String> get _availableNodes {
    final set = <String>{'ALL'};
    for (final n in _nodes) {
      if (n.nodeId.isNotEmpty) set.add(n.nodeId);
    }
    if (set.length == 1) set.add('manager');
    return set.toList();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    await _fetchTabDataSilently(loadAll: true);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchFlowsAndStatsSilently() => _fetchTabDataSilently();

  Future<void> _fetchTabDataSilently({bool loadAll = false}) async {
    EbpfStats? stats;
    List<EbpfFlow>? flows;
    EbpfTopology? topo;
    List<EbpfNodeTelemetry>? nodes;
    List<EbpfSecurityAlert>? alerts;
    List<EbpfAttackSurfaceEntry>? surface;
    EbpfZeroTrustBaseline? zt;
    List<EbpfProcessSocket>? procs;
    List<EbpfQuarantineRecord>? quars;
    List<EbpfPcapCapture>? pcaps;
    ({List<EbpfPurpleTeamScenario> scenarios, List<EbpfPurpleTeamRun> runs})? purple;

    final idx = _tabController.index;

    await Future.wait([
      () async {
        try {
          stats = await ApiService.fetchEbpfStats();
        } catch (_) {}
      }(),
      if (loadAll || idx == 0)
        () async {
          try {
            flows = await ApiService.fetchEbpfFlows(
              limit: _limit,
              protocol: _selectedProtocol,
              status: _selectedStatus,
              query: _searchCtrl.text.trim(),
              node: _selectedNode,
              realOnly: _realOnlyFlows,
            );
          } catch (_) {}
        }(),
      if (loadAll || idx == 1)
        () async {
          try {
            topo = await ApiService.fetchEbpfTopology();
          } catch (_) {}
        }(),
      if (loadAll || idx == 2)
        () async {
          try {
            alerts = await ApiService.fetchEbpfAlerts(
              severity: _alertSeverity,
              status: _alertStatus,
            );
          } catch (_) {}
        }(),
      if (loadAll || idx == 3)
        () async {
          try {
            surface = await ApiService.fetchEbpfAttackSurface(
              node: _selectedNode,
              shadowOnly: _shadowPortsOnly,
            );
          } catch (_) {}
          try {
            zt = await ApiService.fetchEbpfZeroTrust();
          } catch (_) {}
        }(),
      if (loadAll || idx == 4)
        () async {
          try {
            purple = await ApiService.fetchEbpfPurpleTeam();
          } catch (_) {}
          try {
            quars = await ApiService.fetchEbpfQuarantines();
          } catch (_) {}
          try {
            pcaps = await ApiService.fetchEbpfPcaps();
          } catch (_) {}
          try {
            procs = await ApiService.fetchEbpfProcesses(
              node: _selectedNode,
              query: _processSearchCtrl.text.trim(),
            );
          } catch (_) {}
        }(),
      if (loadAll || idx == 5)
        () async {
          try {
            nodes = await ApiService.fetchEbpfNodes();
          } catch (_) {}
        }(),
    ]);

    if (mounted) {
      setState(() {
        if (stats != null) {
          _stats = stats;
          if (stats!.nodeSnapshots.isNotEmpty) {
            _nodes = stats!.nodeSnapshots;
          }
        }
        if (flows != null) _flows = flows!;
        if (topo != null) _topology = topo;
        if (nodes != null && nodes!.isNotEmpty) _nodes = nodes!;
        if (alerts != null) _alerts = alerts!;
        if (surface != null) _attackSurface = surface!;
        if (zt != null) _zeroTrust = zt!;
        if (procs != null) _processes = procs!;
        if (quars != null) _quarantines = quars!;
        if (pcaps != null) _pcaps = pcaps!;
        if (purple != null) {
          _purpleScenarios = purple!.scenarios;
          _purpleRuns = purple!.runs;
        }
      });
    }
  }

  Future<void> _toggleSyntheticPulse(bool enabled) async {
    final ok = await ApiService.setEbpfTelemetryMode(
      syntheticPulse: enabled,
      triggerScan: !enabled,
    );
    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Demo pulse enabled alongside real kernel telemetry'
                : 'Switched to Real-Only Multi-Node Kernel Telemetry',
          ),
          backgroundColor: const Color(0xFF06B6D4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchTabDataSilently(loadAll: true);
    }
  }

  Future<void> _triggerSurfaceScan() async {
    setState(() => _scanningSurface = true);
    try {
      await ApiService.scanEbpfAttackSurface();
      await _fetchTabDataSilently(loadAll: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Multi-node Attack Surface & Process telemetry scan completed'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _scanningSurface = false);
    }
  }

  Future<void> _quarantineContainer({
    required String containerName,
    String nodeHost = 'manager',
    String containerIp = '',
    String reason = '',
    String alertId = '',
  }) async {
    try {
      final rec = await ApiService.quarantineEbpfContainer(
        containerName: containerName,
        nodeHost: nodeHost,
        containerIp: containerIp,
        reason: reason.isEmpty ? 'Forensic network isolation triggered from eBPF Live Hub' : reason,
        alertId: alertId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quarantined $containerName (${rec.method}) — RAM/processes preserved for DFIR'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchTabDataSilently(loadAll: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quarantine failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _releaseQuarantine(String id, String containerName) async {
    final ok = await ApiService.releaseEbpfQuarantine(id);
    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored network connectivity for $containerName'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchTabDataSilently(loadAll: true);
    }
  }

  Future<void> _capturePcap({
    String nodeHost = 'manager',
    String containerName = '',
    String filter = '',
    int durationS = 5,
  }) async {
    setState(() => _capturingPcap = true);
    try {
      final cap = await ApiService.captureEbpfPcap(
        nodeHost: nodeHost,
        containerName: containerName,
        filter: filter,
        durationS: durationS,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PCAP ${cap.id} ready (${cap.packetCount} pkts, ${_formatBytes(cap.sizeBytes)})'),
            backgroundColor: const Color(0xFF06B6D4),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Download .pcap',
              textColor: Colors.black,
              onPressed: () => ApiService.downloadEbpfPcap(cap.id),
            ),
          ),
        );
        _fetchTabDataSilently(loadAll: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PCAP capture error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _capturingPcap = false);
    }
  }

  Future<void> _runPurpleScenario(EbpfPurpleTeamScenario sc) async {
    setState(() => _runningPurple = true);
    try {
      final run = await ApiService.runEbpfPurpleTeam(
        scenarioId: sc.id,
        targetNode: _purpleTargetNode,
        targetContainer: _purpleTargetContainer,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Purple Team [${run.mitreTechnique}]: ${run.detected ? "DETECTED" : "MISSED"} in ${run.mttdMs.toStringAsFixed(2)}ms — Score ${run.score}/100',
            ),
            backgroundColor: run.detected ? const Color(0xFF10B981) : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _fetchTabDataSilently(loadAll: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purple Team error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _runningPurple = false);
    }
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
                content: Text('eBPF traffic simulation started ($pattern @ $rate req/s)'),
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
      builder: (ctx) => _FlowDetailsDialog(
        flow: flow,
        onQuarantine: () {
          Navigator.of(ctx).pop();
          _quarantineContainer(
            containerName: flow.sourceName,
            nodeHost: flow.nodeHost.isEmpty ? 'manager' : flow.nodeHost,
            containerIp: flow.sourceIp,
            reason: 'Isolated from live eBPF flow ${flow.sourceName} -> ${flow.destName}:${flow.destPort}',
          );
        },
        onCapturePcap: () {
          Navigator.of(ctx).pop();
          _capturePcap(
            nodeHost: flow.nodeHost.isEmpty ? 'manager' : flow.nodeHost,
            containerName: flow.sourceName,
            filter: flow.sourceIp.isNotEmpty ? 'host ${flow.sourceIp}' : '',
          );
        },
      ),
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
          _buildHeaderToolbar(theme),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
                : TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildFlowsTab(theme),
                      _buildTopologyTab(theme),
                      _buildThreatIdsTab(theme),
                      _buildAttackSurfaceAndZeroTrustTab(theme),
                      _buildPurpleTeamAndForensicsTab(theme),
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
    final openAlerts = _stats?.activeAlerts ?? 0;
    final nodesMonitored = _stats?.nodesMonitored ?? _nodes.length;
    final synthPulse = _stats?.syntheticPulse ?? false;

    return Container(
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
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.grain, color: Color(0xFF06B6D4), size: 22),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'eBPF Live Hub • Security & Kernel Observability',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
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
                                isKernel ? 'eBPF KERNEL ACTIVE' : 'eBPF HYBRID/DEV',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isKernel ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (openAlerts > 0)
                          InkWell(
                            onTap: () => _tabController.animateTo(2),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                '$openAlerts IDS ALERTS',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kernel $kernelVer • $nodesMonitored Centurion(s) • Runtime IDS (MITRE ATT&CK), Zero-Trust, Purple Team & DFIR.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildPill(
                icon: Icons.shield,
                label: 'Probes',
                value: '$activeProbes Active',
                color: const Color(0xFF06B6D4),
                theme: theme,
              ),
              _buildPill(
                icon: Icons.speed,
                label: 'Rate',
                value: '${pktsRate.toStringAsFixed(1)} pkts/s',
                color: Colors.blueAccent,
                theme: theme,
              ),
              _buildPill(
                icon: Icons.swap_vert,
                label: 'Throughput',
                value: _formatBytesRate(bytesRate),
                color: theme.brightness == Brightness.dark ? Colors.tealAccent : Colors.teal.shade700,
                theme: theme,
              ),
              FilterChip(
                selected: !synthPulse,
                label: Text(
                  synthPulse ? 'Demo Pulse ON' : 'Real Telemetry Only',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                avatar: Icon(
                  synthPulse ? Icons.science_outlined : Icons.verified_user_outlined,
                  size: 14,
                  color: synthPulse ? Colors.amber : const Color(0xFF10B981),
                ),
                onSelected: (_) => _toggleSyntheticPulse(!synthPulse),
              ),
              OutlinedButton.icon(
                onPressed: _toggleAutoRefresh,
                icon: Icon(
                  _autoRefresh ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  size: 16,
                  color: _autoRefresh ? const Color(0xFF10B981) : Colors.grey,
                ),
                label: Text(
                  _autoRefresh ? 'Live (3s)' : 'Paused',
                  style: TextStyle(color: _autoRefresh ? const Color(0xFF10B981) : null),
                ),
              ),
              IconButton(
                tooltip: 'Refresh & Scan Nodes',
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadAllData,
              ),
              FilledButton.icon(
                onPressed: _openSimulationDialog,
                icon: const Icon(Icons.bolt, size: 16),
                label: const Text('Simulate'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.black,
                ),
              ),
            ],
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

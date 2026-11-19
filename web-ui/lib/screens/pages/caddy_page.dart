import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

part 'caddy/caddy_routes_caddyfile_part.dart';
part 'caddy/caddy_certs_logs_metrics_part.dart';
part 'caddy/caddy_waf_part.dart';

/// Caddy Ingress Visualization Suite — Multi-node Caddy cluster manager inspired by caddy-ui.
class CaddyPage extends StatefulWidget {
  final DashboardState state;
  final VoidCallback onRefresh;
  final int selectedSubIndex;

  const CaddyPage({
    super.key,
    required this.state,
    required this.onRefresh,
    this.selectedSubIndex = 0,
  });

  @override
  State<CaddyPage> createState() => _CaddyPageState();
}

class _CaddyPageState extends State<CaddyPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCaddyNode = 'node-local-manager';
  
  // Data states
  Map<String, dynamic> _caddyStatusData = {};
  List<dynamic> _routesList = [];
  List<dynamic> _certsList = [];
  List<String> _logsList = [];
  Map<String, dynamic> _metricsData = {};
  bool _loading = false;
  
  // WAF Threat Shield state
  Map<String, dynamic> _wafConfig = {};
  Map<String, dynamic> _wafStats = {};
  List<dynamic> _wafEvents = [];
  String _wafEventFilter = 'ALL';
  String _wafSimulateVector = 'SQLI';
  String _wafSimulateHost = '';
  bool _wafSaving = false;

  // Filters & Search
  String _routeFilter = '';
  String _logSearch = '';
  String _logLevelFilter = 'ALL';
  bool _accessLoggingEnabled = true;
  String _caddyfileViewMode = 'table'; // 'table', 'json', 'raw'
  String _caddyfileFilter = '';
  bool _syncingCerts = false;

  Future<void> _openUrl(String url) async {
    String cleanUrl = url.trim();
    if (cleanUrl.isEmpty || cleanUrl == ':80') return;
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }
    final uri = Uri.tryParse(cleanUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        _showSnackBar('Could not open $cleanUrl: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 8,
      vsync: this,
      initialIndex: widget.selectedSubIndex.clamp(0, 7),
    );
    _loadCaddyData();
  }

  @override
  void didUpdateWidget(CaddyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSubIndex != widget.selectedSubIndex) {
      final target = widget.selectedSubIndex.clamp(0, 7);
      if (_tabController.index != target) {
        _tabController.animateTo(target);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCaddyData() async {
    setState(() => _loading = true);
    try {
      final status = await ApiService.fetchCaddyStatus(nodeId: _selectedCaddyNode);
      final routes = await ApiService.fetchCaddyRoutes(nodeId: _selectedCaddyNode);
      final certs = await ApiService.fetchCaddyCerts(nodeId: _selectedCaddyNode);
      final logs = await ApiService.fetchCaddyLogs(nodeId: _selectedCaddyNode);
      final metrics = await ApiService.fetchCaddyMetrics(nodeId: _selectedCaddyNode);
      final wafCfg = await ApiService.fetchWAFConfig();
      final wafStats = await ApiService.fetchWAFStats();
      final wafEvts = await ApiService.fetchWAFEvents(limit: 50, type: _wafEventFilter);

      if (mounted) {
        setState(() {
          _caddyStatusData = status;
          _routesList = routes;
          _certsList = certs;
          _logsList = logs;
          _metricsData = metrics;
          _wafConfig = wafCfg;
          _wafStats = wafStats;
          _wafEvents = wafEvts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
  }

  void _updateState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedNode = widget.state.nodes.firstWhere(
      (n) => n.id == _selectedCaddyNode,
      orElse: () => widget.state.nodes.firstWhere(
        (n) => n.role == 'manager',
        orElse: () => Node(
          id: 'node-local-manager', ip: '127.0.0.1', role: 'manager', status: 'active',
          caddyStatus: widget.state.caddyStatus, caddyfile: widget.state.caddyfile,
        ),
      ),
    );

    final status = selectedNode.caddyStatus.isNotEmpty ? selectedNode.caddyStatus : 'not running';
    final caddyfile = selectedNode.caddyfile;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar & Node Selector
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.alt_route, size: 28, color: Color(0xFFF97316)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Load Balancing & Ingress Suite',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('Multi-node reverse proxy gateway, route matrix, certificates, logs & metrics',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            )),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Text('Select Caddy Node: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      DropdownButton<String>(
                        value: widget.state.nodes.any((n) => n.id == _selectedCaddyNode)
                            ? _selectedCaddyNode
                            : (widget.state.nodes.any((n) => n.role == 'manager')
                                ? widget.state.nodes.firstWhere((n) => n.role == 'manager').id
                                : (widget.state.nodes.isNotEmpty ? widget.state.nodes.first.id : 'node-local-manager')),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCaddyNode = val);
                            _loadCaddyData();
                          }
                        },
                        items: widget.state.nodes.map((node) {
                          final name = node.role == 'manager' ? '${node.id} (Manager)' : node.id;
                          return DropdownMenuItem<String>(value: node.id, child: Text(name));
                        }).toList(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: _loading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh, size: 20),
                        tooltip: 'Refresh Caddy metrics',
                        onPressed: () {
                          widget.onRefresh();
                          _loadCaddyData();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Tab Views (controlled via Level-3 Sidebar Navigation)
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildDashboardTab(selectedNode, status, theme, isDark),
                _buildRoutesTab(theme, isDark),
                _buildCaddyfileTab(caddyfile, theme, isDark),
                _buildCertsTab(theme, isDark),
                _buildLogsTab(theme, isDark),
                _buildLogConfigTab(theme, isDark),
                _buildMetricsTab(theme, isDark),
                _buildWAFTab(theme, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: Dashboard ---
  Widget _buildDashboardTab(Node selectedNode, String status, ThemeData theme, bool isDark) {
    final activeRoutes = _routesList.length;
    final activeCerts = _certsList.length;
    final activeCaddyNodes = widget.state.nodes
        .where((n) => n.caddyStatus.toLowerCase().contains('running'))
        .length;
    final totalNodes = widget.state.nodes.length;
    final version = (_caddyStatusData['version'] ?? '').toString().trim();
    final uptimeSec = (_caddyStatusData['uptime_seconds'] as num?)?.toDouble();
    final memBytes = (_caddyStatusData['memory_bytes'] as num?)?.toDouble();
    final lastReload = (_caddyStatusData['last_reload'] ?? '').toString().trim();

    final versionLabel = version.isNotEmpty ? version : 'Detecting...';
    final memLabel = (memBytes != null && memBytes > 0)
        ? '${(memBytes / 1024 / 1024).toStringAsFixed(1)} MB'
        : 'N/A';
    final uptimeLabel = (uptimeSec != null && uptimeSec > 0)
        ? '${(uptimeSec / 3600).toStringAsFixed(1)} hrs'
        : (status.contains('running') ? 'Active' : 'Stopped');
    final reloadLabel = lastReload.isNotEmpty ? lastReload : 'Live Sync';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _metricCard('Caddy Status', status.contains('running') ? 'RUNNING' : 'STOPPED', Icons.check_circle_outline, status.contains('running') ? Colors.green : Colors.redAccent, theme)),
              const SizedBox(width: 12),
              Expanded(child: _metricCard('Active Instances', '$activeCaddyNodes / $totalNodes Nodes', Icons.hub, Colors.blue, theme)),
              const SizedBox(width: 12),
              Expanded(child: _metricCard('Managed Routes', '$activeRoutes Hosts', Icons.alt_route, const Color(0xFFF97316), theme)),
              const SizedBox(width: 12),
              Expanded(child: _metricCard('TLS Certificates', '$activeCerts Domains', Icons.shield, Colors.purple, theme)),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.memory, size: 20, color: Color(0xFFF97316)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Process & System Info (${selectedNode.id})',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _infoPill('Caddy Version', versionLabel, isDark),
                      _infoPill('Memory Usage', memLabel, isDark),
                      _infoPill('Uptime', uptimeLabel, isDark),
                      _infoPill('Config Sync', reloadLabel, isDark),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String val, IconData icon, Color color, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 4),
                Text(val, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoPill(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class CaddyParsedBlock {
  final String host;
  final String cleanHost;
  final String scheme;
  final String url;
  final List<String> upstreams;
  final String tls;
  final bool wafEnabled;
  final String wafMode;
  final String lbPolicy;
  final String healthUri;
  final List<String> directives;
  final String raw;

  const CaddyParsedBlock({
    required this.host,
    required this.cleanHost,
    required this.scheme,
    required this.url,
    required this.upstreams,
    required this.tls,
    required this.wafEnabled,
    required this.wafMode,
    required this.lbPolicy,
    required this.healthUri,
    required this.directives,
    required this.raw,
  });

  Map<String, dynamic> toJson() => {
    'ingress_host': host,
    'clean_host': cleanHost,
    'scheme': scheme,
    'url': url,
    'upstreams': upstreams,
    'tls': tls,
    'waf': {
      'enabled': wafEnabled,
      'mode': wafMode,
    },
    if (lbPolicy.isNotEmpty) 'lb_policy': lbPolicy,
    if (healthUri.isNotEmpty) 'health_uri': healthUri,
    if (directives.isNotEmpty) 'other_directives': directives,
  };
}

import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/clipboard_service.dart';
import '../../widgets/common_widgets.dart';

part 'coredns/coredns_diagnostics_dialogs_part.dart';
part 'coredns/coredns_tabs_part.dart';

/// Comprehensive CoreDNS 4-Tab Management Suite
class CoreDnsPage extends StatefulWidget {
  final DashboardState state;
  final VoidCallback onRefresh;

  const CoreDnsPage({
    super.key,
    required this.state,
    required this.onRefresh,
  });

  @override
  State<CoreDnsPage> createState() => _CoreDnsPageState();
}

class _CoreDnsPageState extends State<CoreDnsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  CoreDNSStatusInfo? _statusInfo;
  List<CustomDNSRecord> _customRecords = [];
  bool _loadingData = true;

  // Tab 0: Auto Search
  String _autoSearchQuery = '';

  // Tab 1: Custom Search
  String _customSearchQuery = '';

  // Tab 2: Dig Playground
  final TextEditingController _digDomainController = TextEditingController(text: 'payment.checkout-stack.gbnt');
  String _digRecordType = 'A';
  DNSDigResult? _digResult;
  bool _runningDig = false;

  // Tab 3: Config Editor
  final TextEditingController _configController = TextEditingController();
  final TextEditingController _forwardersController = TextEditingController();
  bool _loadingConfig = false;
  bool _savingConfig = false;
  bool _restartingCoreDNS = false;

  final ScrollController _autoScrollController = ScrollController();
  final ScrollController _customScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _configController.addListener(_onConfigTextChange);
    _loadSuiteData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _digDomainController.dispose();
    _configController.removeListener(_onConfigTextChange);
    _configController.dispose();
    _forwardersController.dispose();
    _autoScrollController.dispose();
    _customScrollController.dispose();
    super.dispose();
  }

  void _onConfigTextChange() {
    final lines = _configController.text.split('\n');
    for (var line in lines) {
      if (line.trim().startsWith('forward . ')) {
        final parts = line.trim().split(RegExp(r'\s+'));
        final ips = parts.length > 2 ? parts.sublist(2).join(' ') : '';
        if (_forwardersController.text != ips) {
          _forwardersController.text = ips;
        }
        break;
      }
    }
  }

  Future<void> _loadSuiteData() async {
    setState(() => _loadingData = true);
    try {
      final statusFuture = ApiService.fetchCoreDNSStatusInfo();
      final customFuture = ApiService.fetchCustomDNSRecords();

      final results = await Future.wait([statusFuture, customFuture]);

      if (mounted) {
        setState(() {
          _statusInfo = results[0] as CoreDNSStatusInfo;
          _customRecords = results[1] as List<CustomDNSRecord>;
          _loadingData = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _loadConfig() async {
    setState(() => _loadingConfig = true);
    try {
      final config = await ApiService.getCoreDNSConfig();
      if (mounted) {
        setState(() {
          _configController.text = config;
          _loadingConfig = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingConfig = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load Corefile: $e')));
      }
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _savingConfig = true);
    try {
      final ok = await ApiService.updateCoreDNSConfig(_configController.text);
      if (mounted) {
        setState(() => _savingConfig = false);
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CoreDNS configuration saved and container restarted.')),
          );
          _loadSuiteData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save Corefile.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingConfig = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving Corefile: $e')));
      }
    }
  }

  void _applyForwarderPreset(String ips) {
    _forwardersController.text = ips;
    _syncTextFromForwarders();
  }

  void _syncTextFromForwarders() {
    final ipsStr = _forwardersController.text.trim();
    var newForward = '    forward .';
    if (ipsStr.isNotEmpty) {
      final ips = ipsStr.split(RegExp(r'\s+'));
      newForward += ' ${ips.join(' ')}';
    }
    final lines = _configController.text.split('\n');
    bool found = false;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim().startsWith('forward .')) {
        lines[i] = newForward;
        found = true;
        break;
      }
    }
    if (found) {
      final newText = lines.join('\n');
      if (_configController.text != newText) {
        _configController.text = newText;
      }
    }
  }

  Future<void> _runDigQuery() async {
    final domain = _digDomainController.text.trim();
    if (domain.isEmpty) return;

    setState(() => _runningDig = true);
    try {
      final res = await ApiService.performDNSDig(domain: domain, recordType: _digRecordType);
      if (mounted) {
        setState(() {
          _digResult = res;
          _runningDig = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _runningDig = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DNS Query Error: $e')));
      }
    }
  }

  void _showAddCustomRecordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AddCustomRecordDialog(
        onSaved: () => _loadSuiteData(),
      ),
    );
  }

  Future<void> _deleteCustomRecord(String id) async {
    final ok = await ApiService.deleteCustomDNSRecord(id);
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Custom DNS record deleted.')));
        _loadSuiteData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete custom record.')));
      }
    }
  }

  Future<void> _restartCoreDNS() async {
    setState(() => _restartingCoreDNS = true);
    try {
      final info = await ApiService.restartCoreDNS();
      final ok = info.status == 'running';
      if (mounted) {
        setState(() {
          _statusInfo = info;
          _restartingCoreDNS = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'CoreDNS container restarted and DNS records synchronized.'
                  : 'CoreDNS restart finished (status: ${info.status}).',
            ),
            backgroundColor: ok ? Colors.green.shade700 : Colors.orange.shade800,
          ),
        );
        widget.onRefresh();
        _loadSuiteData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _restartingCoreDNS = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restarting CoreDNS: $e')),
        );
      }
    }
  }

  void _updateState(VoidCallback fn) {
    if (mounted) setState(fn);
  }


  Widget _buildSummaryCards(ThemeData theme) {
    final status = _statusInfo?.status ?? 'running';
    final totalRecords = _statusInfo?.totalRecords ?? widget.state.dnsRecords.length;
    final forwardersCount = _statusInfo?.forwarders.length ?? 2;
    final listeningPort = _statusInfo?.listeningPort ?? 5354;
    final clusterDomain = widget.state.clusterDomain.isNotEmpty ? widget.state.clusterDomain : 'gbnt.local';
    final canEdit = widget.state.currentUser?.role == 'admin';

    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'SERVER STATUS',
            value: status.toUpperCase(),
            icon: Icons.dns,
            valueColor: status == 'running' ? Colors.green : Colors.red,
            trailing: IconButton(
              icon: _restartingCoreDNS
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.restart_alt,
                      size: 18,
                      color: status == 'running' ? null : Colors.orangeAccent,
                    ),
              tooltip: 'Restart CoreDNS Service',
              onPressed: _restartingCoreDNS ? null : _restartCoreDNS,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            label: 'CLUSTER DOMAIN',
            value: clusterDomain,
            icon: Icons.language,
            valueColor: Colors.cyanAccent,
            trailing: canEdit
                ? IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    tooltip: 'Edit Base Domain',
                    onPressed: () => _showEditClusterDomainDialog(clusterDomain),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            label: 'LISTENER PORT',
            value: '53 / $listeningPort',
            icon: Icons.settings_ethernet,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            label: 'TOTAL DNS RECORDS',
            value: '$totalRecords',
            icon: Icons.format_list_bulleted,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            label: 'FORWARDERS',
            value: '$forwardersCount Active',
            icon: Icons.public,
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dns_outlined, size: 28, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CoreDNS Management Suite', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Cluster Service Discovery, Static Records & DNS Playground',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _restartingCoreDNS ? null : _restartCoreDNS,
                icon: _restartingCoreDNS
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restart_alt, size: 18),
                label: Text(_restartingCoreDNS ? 'Restarting...' : 'Restart CoreDNS'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  widget.onRefresh();
                  _loadSuiteData();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _showAddCustomRecordDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('+ Add Static Record'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSummaryCards(theme),
          const SizedBox(height: 20),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            onTap: (idx) {
              if (idx == 3 && _configController.text.isEmpty) {
                _loadConfig();
              }
            },
            tabs: const [
              Tab(icon: Icon(Icons.lan, size: 18), text: 'Auto-Discovered (*.gbnt)'),
              Tab(icon: Icon(Icons.edit_note, size: 18), text: 'Custom Static Records'),
              Tab(icon: Icon(Icons.play_arrow, size: 18), text: 'DNS Playground (Dig)'),
              Tab(icon: Icon(Icons.settings, size: 18), text: 'Upstream & Corefile'),
            ],
          ),
          const SizedBox(height: 20),
          if (_loadingData)
            const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
          else
            AnimatedBuilder(
              animation: _tabController,
              builder: (ctx, child) {
                switch (_tabController.index) {
                  case 0:
                    return _buildTabAutoDiscovered(theme);
                  case 1:
                    return _buildTabCustomRecords(theme);
                  case 2:
                    return _buildTabPlayground(theme);
                  case 3:
                    return _buildTabConfig(theme);
                  default:
                    return _buildTabAutoDiscovered(theme);
                }
              },
            ),
        ],
      ),
    );
  }
}

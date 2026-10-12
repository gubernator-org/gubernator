import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

part 'slo/slo_tabs_part.dart';
part 'slo/slo_dialogs_part.dart';

/// Advanced SLO & Error Budgets Suite (5 Tabs)
class SloPage extends StatefulWidget {
  final DashboardState state;
  final VoidCallback onRefresh;

  const SloPage({
    super.key,
    required this.state,
    required this.onRefresh,
  });

  @override
  State<SloPage> createState() => _SloPageState();
}

class _SloPageState extends State<SloPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<SLOItem> _slos = [];
  List<UserJourney> _journeys = [];
  List<SLOCorrelationEvent> _correlations = [];
  List<SLOValidationItem> _validations = [];

  bool _loading = true;
  String? _error;
  bool _syncing = false;
  bool _validating = false;

  String _searchQuery = '';
  String _sortBy = 'lowest_budget'; // lowest_budget, highest_burn, name, target
  bool _isTableView = false;

  final TextEditingController _composeController = TextEditingController(
    text: '''version: "3.8"
name: checkout-stack

services:
  payment-api:
    image: hashicorp/http-echo:latest
    ports:
      - "8080:8080"
    labels:
      gbnt.slo.enable: "true"
      gbnt.slo.target: "99.9"
      gbnt.slo.window: "30d"
      gbnt.slo.template: "caddy-http"
      gbnt.slo.journey: "Checkout Flow"
''',
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _composeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final slosFuture = ApiService.fetchSLOs();
      final journeysFuture = ApiService.fetchUserJourneys();
      final correlationsFuture = ApiService.fetchSLOCorrelations();

      final results = await Future.wait([slosFuture, journeysFuture, correlationsFuture]);

      if (mounted) {
        setState(() {
          _slos = (results[0] as List<SLOItem>?) ?? [];
          _journeys = (results[1] as List<UserJourney>?) ?? [];
          _correlations = (results[2] as List<SLOCorrelationEvent>?) ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _syncSLOs() async {
    setState(() => _syncing = true);
    final ok = await ApiService.syncSLOs();
    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'SLO rules synchronized with Prometheus.' : 'Failed to sync SLO rules.'),
          backgroundColor: ok ? null : Theme.of(context).colorScheme.error,
        ),
      );
      _loadData();
    }
  }

  Future<void> _runBacktest() async {
    if (_composeController.text.trim().isEmpty) return;
    setState(() => _validating = true);
    try {
      final res = await ApiService.validateSLO(_composeController.text);
      if (mounted) {
        setState(() {
          _validations = res;
          _validating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _validating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backtest error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Color _getBudgetColor(double budgetRemaining) {
    if (budgetRemaining <= 0) return Colors.red;
    if (budgetRemaining < 20) return Colors.amber.shade800;
    if (budgetRemaining < 50) return Colors.amber.shade600;
    return Colors.green.shade600;
  }

  List<SLOItem> _getFilteredAndSortedSLOs() {
    List<SLOItem> list = _slos.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.serviceName.toLowerCase().contains(q) ||
          s.template.toLowerCase().contains(q) ||
          s.journey.toLowerCase().contains(q) ||
          s.errorQuery.toLowerCase().contains(q);
    }).toList();

    list.sort((a, b) {
      switch (_sortBy) {
        case 'lowest_budget':
          return a.errorBudgetRemaining.compareTo(b.errorBudgetRemaining);
        case 'highest_burn':
          return b.burnRate.compareTo(a.burnRate);
        case 'name':
          return a.serviceName.compareTo(b.serviceName);
        case 'target':
          return b.target.compareTo(a.target);
        default:
          return a.errorBudgetRemaining.compareTo(b.errorBudgetRemaining);
      }
    });

    return list;
  }

  void _showSLODetailModal(SLOItem item) {
    showDialog(
      context: context,
      builder: (ctx) => _SLODetailDialog(item: item),
    );
  }

  void _showAddEditSLODialog([SLOItem? existingItem]) async {
    List<Service> allServices = [];
    try {
      allServices = await ApiService.fetchServices();
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => _SLOFormDialog(
        existingItem: existingItem,
        services: allServices,
        onSave: () => _loadData(),
      ),
    );
  }

  void _showSLONotificationsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const _SLONotificationsDialog(),
    );
  }

  Widget _buildSummaryCards(ThemeData theme) {
    final total = _slos.length;
    final healthy = _slos.where((s) => s.status == 'healthy').length;
    final warning = _slos.where((s) => s.status == 'warning').length;
    final exhausted = _slos.where((s) => s.status == 'exhausted').length;

    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'TOTAL SLOs',
            value: '$total',
            icon: Icons.speed,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            label: 'HEALTHY',
            value: '$healthy',
            icon: Icons.check_circle,
            valueColor: Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            label: 'WARNING',
            value: '$warning',
            icon: Icons.warning,
            valueColor: Colors.amber.shade800,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            label: 'EXHAUSTED',
            value: '$exhausted',
            icon: Icons.error,
            valueColor: Colors.red,
          ),
        ),
      ],
    );
  }


  void _updateState(VoidCallback fn) {
    if (mounted) setState(fn);
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
              Icon(Icons.speed, size: 28, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SLO & Error Budgets Suite',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Google SRE Multi-Burn-Rate Sloth Engine & Pyrra Interactive Suite',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _showAddEditSLODialog(),
                icon: const Icon(Icons.add_chart, size: 18),
                label: const Text('+ Configure / Add SLO'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _syncing ? null : _syncSLOs,
                icon: _syncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync, size: 18),
                label: const Text('Sync Rules'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSummaryCards(theme),
          const SizedBox(height: 20),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.speed, size: 18), text: 'Overview & Budgets'),
              Tab(icon: Icon(Icons.route, size: 18), text: 'User Journeys'),
              Tab(icon: Icon(Icons.timeline, size: 18), text: 'Deployment Correlation'),
              Tab(icon: Icon(Icons.dashboard_customize, size: 18), text: 'SLI Templates'),
              Tab(icon: Icon(Icons.science, size: 18), text: 'Backtest & Validator'),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
          else if (_error != null)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Error loading SLO suite: $_error', style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            AnimatedBuilder(
              animation: _tabController,
              builder: (ctx, child) {
                switch (_tabController.index) {
                  case 0:
                    return _buildTabOverview(theme);
                  case 1:
                    return _buildTabJourneys(theme);
                  case 2:
                    return _buildTabCorrelation(theme);
                  case 3:
                    return _buildTabTemplates(theme);
                  case 4:
                    return _buildTabBacktest(theme);
                  default:
                    return _buildTabOverview(theme);
                }
              },
            ),
        ],
      ),
    );
  }
}

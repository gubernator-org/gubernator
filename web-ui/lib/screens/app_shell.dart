import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../theme/theme.dart';
import '../widgets/sidebar.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/update_dialog.dart';
import 'pages/overview_page.dart';
import 'pages/legions_page.dart';
import 'pages/centurions_page.dart';
import 'pages/tasks_page.dart';
import 'pages/caddy_page.dart';
import 'pages/coredns_page.dart';
import 'pages/grafana_page.dart';
import 'pages/loki_logs_page.dart';
import 'pages/jaeger_page.dart';
import 'pages/network_page.dart';
import 'pages/scope_page.dart';
import 'pages/slo_page.dart';
import 'pages/security_page.dart';
import 'pages/storage_page.dart';
import 'pages/image_security_page.dart';
import 'pages/compose_studio_page.dart';
import 'pages/ebpf_page.dart';
import 'pages/opensearch_dashboards_page.dart';
import 'pages/opensearch_discover_page.dart';
import 'pages/opensearch_traces_page.dart';
import 'pages/sre_feature_adaptive_page.dart';

/// Main application shell with sidebar navigation + content area.
class AppShell extends StatefulWidget {
  final String currentThemeId;
  final ValueChanged<String> onThemeChanged;
  final String displayName;
  final ValueChanged<String> onNameChanged;
  final UserSession? currentUser;
  final VoidCallback? onLogout;

  bool get isDark => GubernatorTheme.getThemeDef(currentThemeId).isDark;

  const AppShell({
    super.key,
    required this.currentThemeId,
    required this.onThemeChanged,
    required this.displayName,
    required this.onNameChanged,
    this.currentUser,
    this.onLogout,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  DashboardState _state = DashboardState();
  bool _loading = true;
  String? _error;
  DateTime? _lastRefresh;
  Timer? _timer;
  int _selectedIndex = 0;
  int _selectedSubIndex = 0;
  final Map<int, int> _lastSubIndexByPage = {};
  String? _lokiFilterContainer;
  String? _tasksFilterStack;
  bool _sidebarCollapsed = false;
  Set<String> _collapsedSections = {};
  Set<int> _expandedItems = {};
  bool _fetching = false;
  bool _hasPromptedUpdate = false;

  static const String _collapsedSectionsStorageKey =
      'gbnt_sidebar_collapsed_sections';
  static const String _expandedItemsStorageKey =
      'gbnt_sidebar_expanded_items';
  static const List<String> _allSectionIds = [
    'cluster',
    'infrastructure',
    'observability',
    'network',
    'security',
  ];
  static const Set<int> _pagesWithSubItems = {2, 4, 5, 6, 7, 8, 14, 15};

  // Cached singleton instances for platform-view / iframe pages to eliminate DOM re-creation
  late final Widget _grafanaPage = const GrafanaPage(key: ValueKey('page-grafana-singleton'));
  late final Widget _networkPage = const NetworkPage(key: ValueKey('page-network-singleton'));
  late final Widget _jaegerPage = const JaegerPage(key: ValueKey('page-jaeger-singleton'));
  late final Widget _scopePage = const ScopePage(key: ValueKey('page-scope-singleton'));

  Duration get _pageTransitionDuration {
    // If the active page embeds an iframe/platform view, skip cross-fade animation to eliminate GPU recomposition flicker
    if (_selectedIndex == 9 || _selectedIndex == 11 || _selectedIndex == 12 || _selectedIndex == 13 || _selectedIndex == 14) {
      return Duration.zero;
    }
    return const Duration(milliseconds: 150);
  }

  @override
  void initState() {
    super.initState();
    _loadCollapsedSections();
    clearGrafanaStaleCookies();
    ApiService.sendTimeBeacon();
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchData());
    // Auto-collapse on narrow screens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (MediaQuery.of(context).size.width < 1200) {
        setState(() => _sidebarCollapsed = true);
      }
    });
  }

  void _loadCollapsedSections() {
    try {
      final raw = html.window.localStorage[_collapsedSectionsStorageKey];
      if (raw != null && raw.trim().isNotEmpty) {
        final validIds = _allSectionIds.toSet();
        _collapsedSections = raw
            .split(',')
            .map((e) => e.trim())
            .where((e) => validIds.contains(e))
            .toSet();
      }
    } catch (_) {}
    try {
      final rawItems = html.window.localStorage[_expandedItemsStorageKey];
      if (rawItems != null && rawItems.trim().isNotEmpty) {
        _expandedItems = rawItems
            .split(',')
            .map((e) => int.tryParse(e.trim()))
            .whereType<int>()
            .where((id) => _pagesWithSubItems.contains(id))
            .toSet();
      }
    } catch (_) {}
  }

  void _saveCollapsedSections() {
    try {
      html.window.localStorage[_collapsedSectionsStorageKey] =
          _collapsedSections.join(',');
    } catch (_) {}
  }

  void _saveExpandedItems() {
    try {
      html.window.localStorage[_expandedItemsStorageKey] =
          _expandedItems.join(',');
    } catch (_) {}
  }

  void _toggleSidebarItemExpand(int itemIndex) {
    setState(() {
      if (_expandedItems.contains(itemIndex)) {
        _expandedItems.remove(itemIndex);
      } else {
        _expandedItems.add(itemIndex);
      }
    });
    _saveExpandedItems();
  }

  String _sectionIdForIndex(int index) {
    switch (index) {
      case 0:
      case 1:
      case 2:
      case 3:
      case 16:
        return 'cluster';
      case 4:
      case 7:
      case 8:
        return 'infrastructure';
      case 6:
      case 9:
      case 10:
      case 12:
        return 'observability';
      case 11:
      case 13:
      case 14:
        return 'network';
      case 5:
      case 15:
        return 'security';
      default:
        return 'cluster';
    }
  }

  void _toggleSidebarSection(String sectionId) {
    setState(() {
      if (_collapsedSections.contains(sectionId)) {
        _collapsedSections.remove(sectionId);
      } else {
        _collapsedSections.add(sectionId);
      }
    });
    _saveCollapsedSections();
  }

  void _toggleAllSidebarSections() {
    final allCollapsed =
        _allSectionIds.every((id) => _collapsedSections.contains(id));
    setState(() {
      if (allCollapsed) {
        _collapsedSections.clear();
      } else {
        _collapsedSections = _allSectionIds.toSet();
      }
    });
    _saveCollapsedSections();
  }

  void _selectDestination(int index, {int? subIndex}) {
    final owningSection = _sectionIdForIndex(index);
    final resolvedSub = subIndex ?? _lastSubIndexByPage[index] ?? 0;
    setState(() {
      if (index == 3) {
        _tasksFilterStack = null;
      }
      if (index == 9 || index == 11) {
        clearGrafanaStaleCookies();
      }
      _selectedIndex = index;
      _selectedSubIndex = resolvedSub;
      if (_pagesWithSubItems.contains(index)) {
        _lastSubIndexByPage[index] = resolvedSub;
        if (_expandedItems.add(index)) {
          _saveExpandedItems();
        }
      }
      if (_collapsedSections.remove(owningSection)) {
        _saveCollapsedSections();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final data = await ApiService.fetchState();
      if (mounted) {
        final shouldPrompt = data.updateAvailable && !_hasPromptedUpdate;
        setState(() {
          _state = data;
          _loading = false;
          _error = null;
          _lastRefresh = DateTime.now();
        });
        if (shouldPrompt) {
          _hasPromptedUpdate = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showUpdateDialog();
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    } finally {
      _fetching = false;
    }
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (_) => SettingsDialog(
        currentThemeId: widget.currentThemeId,
        onThemeChanged: widget.onThemeChanged,
        displayName: widget.displayName,
        onNameChanged: widget.onNameChanged,
        version: _state.version,
        nodes: _state.nodes,
      ),
    );
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => UpdateDialog(
        currentVersion: _state.version,
        latestVersion: _state.latestVersion,
        releaseNotes: _state.releaseNotes,
        releaseUrl: _state.releaseUrl,
        onUpdateTriggered: _fetchData,
      ),
    );
  }

  void _showVersionCheckModal() {
    showDialog(
      context: context,
      builder: (context) => VersionCheckModal(
        currentVersion: _state.version,
        onUpdateTriggered: _fetchData,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final sec = dt.second.toString().padLeft(2, '0');
    return '$hour:$min:$sec';
  }

  List<SidebarSection> _buildSidebarSections() {
    final running = _state.tasks.where((t) => t.status == 'running').length;
    return [
      SidebarSection(
        id: 'cluster',
        title: 'Cluster',
        icon: Icons.hub_outlined,
        items: [
          const SidebarItem(
            index: 0,
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard,
            label: 'Overview',
          ),
          SidebarItem(
            index: 1,
            icon: Icons.dns_outlined,
            activeIcon: Icons.dns,
            label: 'Centurions [Host]',
            badgeCount: _state.nodes.length,
            showBadge: true,
          ),
          SidebarItem(
            index: 2,
            icon: Icons.layers_outlined,
            activeIcon: Icons.layers,
            label: 'Legions [Stacks]',
            badgeCount: _state.stacks.length,
            showBadge: true,
            subItems: const [
              SidebarSubItem(
                subIndex: 0,
                icon: Icons.layers_outlined,
                label: 'Managed Stacks',
              ),
              SidebarSubItem(
                subIndex: 1,
                icon: Icons.travel_explore_outlined,
                label: 'Unmanaged / Discovered',
              ),
              SidebarSubItem(
                subIndex: 2,
                icon: Icons.account_tree_outlined,
                label: 'Cluster Topology',
              ),
            ],
          ),
          SidebarItem(
            index: 3,
            icon: Icons.view_in_ar_outlined,
            activeIcon: Icons.view_in_ar,
            label: 'Containers',
            badgeCount: running,
            showBadge: true,
          ),
          const SidebarItem(
            index: 16,
            icon: Icons.code_outlined,
            activeIcon: Icons.code,
            label: 'Compose Studio',
          ),
        ],
      ),
      const SidebarSection(
        id: 'infrastructure',
        title: 'Infrastructure',
        icon: Icons.storage_outlined,
        items: [
          SidebarItem(
            index: 4,
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2,
            label: 'Storage & Backups',
            subItems: [
              SidebarSubItem(
                subIndex: 0,
                icon: Icons.inventory_2_outlined,
                label: 'Volumes',
              ),
              SidebarSubItem(
                subIndex: 1,
                icon: Icons.backup_outlined,
                label: 'Backups & Snapshots',
              ),
              SidebarSubItem(
                subIndex: 2,
                icon: Icons.schedule_outlined,
                label: 'Schedules',
              ),
              SidebarSubItem(
                subIndex: 3,
                icon: Icons.folder_shared_outlined,
                label: 'Storage Pools',
              ),
              SidebarSubItem(
                subIndex: 4,
                icon: Icons.dns_outlined,
                label: 'Network Mounts & fstab',
              ),
              SidebarSubItem(
                subIndex: 5,
                icon: Icons.hub_outlined,
                label: 'GlusterFS Cluster',
              ),
            ],
          ),
          SidebarItem(
            index: 7,
            icon: Icons.alt_route_outlined,
            activeIcon: Icons.alt_route,
            label: 'Load Balancing',
            subItems: [
              SidebarSubItem(
                subIndex: 0,
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
              ),
              SidebarSubItem(
                subIndex: 1,
                icon: Icons.fork_right,
                label: 'Routes',
              ),
              SidebarSubItem(
                subIndex: 2,
                icon: Icons.description_outlined,
                label: 'Caddyfile',
              ),
              SidebarSubItem(
                subIndex: 3,
                icon: Icons.lock_outlined,
                label: 'TLS Certs',
              ),
              SidebarSubItem(
                subIndex: 4,
                icon: Icons.receipt_long_outlined,
                label: 'Access Logs',
              ),
              SidebarSubItem(
                subIndex: 5,
                icon: Icons.tune,
                label: 'Log Config',
              ),
              SidebarSubItem(
                subIndex: 6,
                icon: Icons.show_chart,
                label: 'Metrics',
              ),
              SidebarSubItem(
                subIndex: 7,
                icon: Icons.security_outlined,
                label: 'WAF & Threat Shield',
              ),
            ],
          ),
          SidebarItem(
            index: 8,
            icon: Icons.manage_search_outlined,
            activeIcon: Icons.manage_search,
            label: 'CoreDNS',
            subItems: [
              SidebarSubItem(
                subIndex: 0,
                icon: Icons.lan_outlined,
                label: 'Auto-Discovered (*.gbnt)',
              ),
              SidebarSubItem(
                subIndex: 1,
                icon: Icons.edit_note,
                label: 'Custom Static Records',
              ),
              SidebarSubItem(
                subIndex: 2,
                icon: Icons.play_arrow_outlined,
                label: 'DNS Playground (Dig)',
              ),
              SidebarSubItem(
                subIndex: 3,
                icon: Icons.settings_outlined,
                label: 'Upstream & Corefile',
              ),
            ],
          ),
        ],
      ),
      SidebarSection(
        id: 'observability',
        title: 'Observability & SRE',
        icon: Icons.insights_outlined,
        items: [
          const SidebarItem(
            index: 6,
            icon: Icons.speed_outlined,
            activeIcon: Icons.speed,
            label: 'SLO & Error Budgets',
            subItems: [
              SidebarSubItem(
                subIndex: 0,
                icon: Icons.speed_outlined,
                label: 'Overview & Budgets',
              ),
              SidebarSubItem(
                subIndex: 1,
                icon: Icons.route_outlined,
                label: 'User Journeys',
              ),
              SidebarSubItem(
                subIndex: 2,
                icon: Icons.timeline,
                label: 'Deployment Correlation',
              ),
              SidebarSubItem(
                subIndex: 3,
                icon: Icons.dashboard_customize_outlined,
                label: 'SLI Templates',
              ),
              SidebarSubItem(
                subIndex: 4,
                icon: Icons.science_outlined,
                label: 'Backtest & Validator',
              ),
            ],
          ),
          // Monitoring (Grafana or OpenSearch Dashboards)
          SidebarItem(
            index: 9,
            icon: _state.activeSreProfile == 'enterprise-elk'
                ? Icons.dashboard_customize_outlined
                : Icons.analytics_outlined,
            activeIcon: _state.activeSreProfile == 'enterprise-elk'
                ? Icons.dashboard_customize
                : Icons.analytics,
            label: _state.activeSreProfile == 'enterprise-elk'
                ? 'OpenSearch Dashboards'
                : (_state.activeSreProfile == 'ultra-light'
                    ? 'VMUI / Grafana'
                    : 'Monitoring'),
          ),
          // Logs Explorer (Loki, OpenSearch SIEM or VictoriaLogs)
          SidebarItem(
            index: 10,
            icon: _state.activeSreProfile == 'enterprise-elk'
                ? Icons.security_update_good_outlined
                : Icons.receipt_long_outlined,
            activeIcon: _state.activeSreProfile == 'enterprise-elk'
                ? Icons.security_update_good
                : Icons.receipt_long,
            label: _state.activeSreProfile == 'enterprise-elk'
                ? 'SIEM & Audit Logs'
                : (_state.activeSreProfile == 'ultra-light'
                    ? 'VictoriaLogs'
                    : 'Loki Logs'),
          ),
          SidebarItem(
            index: 12,
            icon: _state.activeSreProfile == 'enterprise-elk'
                ? Icons.polyline_outlined
                : Icons.timeline_outlined,
            activeIcon: _state.activeSreProfile == 'enterprise-elk'
                ? Icons.polyline
                : Icons.timeline,
            label: _state.activeSreProfile == 'enterprise-elk'
                ? 'Trace Analytics'
                : 'Jaeger',
          ),
        ],
      ),
      const SidebarSection(
        id: 'network',
        title: 'Network & eBPF',
        icon: Icons.lan_outlined,
        items: [
          SidebarItem(
            index: 11,
            icon: Icons.network_check_outlined,
            activeIcon: Icons.network_check,
            label: 'Network Monitor',
          ),
          SidebarItem(
            index: 13,
            icon: Icons.hub_outlined,
            activeIcon: Icons.hub,
            label: 'Network Topology',
          ),
          SidebarItem(
            index: 14,
            icon: Icons.grain_outlined,
            activeIcon: Icons.grain,
            label: 'eBPF Live Hub',
            subItems: [
              SidebarSubItem(
                subIndex: 0,
                icon: Icons.swap_calls,
                label: 'Live Captured Flows',
              ),
              SidebarSubItem(
                subIndex: 1,
                icon: Icons.hub_outlined,
                label: 'Service Mesh Topology',
              ),
              SidebarSubItem(
                subIndex: 2,
                icon: Icons.memory_outlined,
                label: 'Kernel Probes & Diagnostics',
              ),
            ],
          ),
        ],
      ),
      const SidebarSection(
        id: 'security',
        title: 'Security',
        icon: Icons.verified_user_outlined,
        items: [
          SidebarItem(
            index: 5,
            icon: Icons.security_outlined,
            activeIcon: Icons.security,
            label: 'Image Security & SBOM',
            subItems: [
              SidebarSubItem(
                subIndex: 0,
                icon: Icons.security_outlined,
                label: 'Vulnerabilities',
              ),
              SidebarSubItem(
                subIndex: 1,
                icon: Icons.inventory_outlined,
                label: 'SBOM Explorer',
              ),
              SidebarSubItem(
                subIndex: 2,
                icon: Icons.verified_outlined,
                label: 'Signatures & Keys',
              ),
              SidebarSubItem(
                subIndex: 3,
                icon: Icons.gavel_outlined,
                label: 'Gatekeeper Policies',
              ),
            ],
          ),
          SidebarItem(
            index: 15,
            icon: Icons.shield_outlined,
            activeIcon: Icons.shield,
            label: 'Security & Directory',
            subItems: [
              SidebarSubItem(
                subIndex: 0,
                icon: Icons.people_alt_outlined,
                label: 'Local Users & MFA',
              ),
              SidebarSubItem(
                subIndex: 1,
                icon: Icons.dns_outlined,
                label: 'Active Directory / LDAP',
              ),
              SidebarSubItem(
                subIndex: 2,
                icon: Icons.vpn_key_outlined,
                label: 'SSO / OIDC',
              ),
              SidebarSubItem(
                subIndex: 3,
                icon: Icons.security_update_good_outlined,
                label: 'Forensic Audit & SIEM',
              ),
              SidebarSubItem(
                subIndex: 4,
                icon: Icons.verified_user_outlined,
                label: 'Compliance & Regulatory',
              ),
            ],
          ),
        ],
      ),
    ];
  }

  // Navigation labels for the header breadcrumb
  static const _pageLabels = [
    'Overview',
    'Centurions [Host]',
    'Legions [Stacks]',
    'Containers',
    'Storage & Backups',
    'Image Security & SBOM',
    'SLO & Error Budgets',
    'Load Balancing',
    'CoreDNS',
    'Monitoring',
    'Loki Logs',
    'Network Monitor',
    'Jaeger',
    'Network Topology',
    'eBPF Live Hub',
    'Security & Directory',
    'Compose Studio',
  ];

  String? _getSubPageLabel(List<SidebarSection> sections, int index, int subIndex) {
    for (final section in sections) {
      for (final item in section.items) {
        if (item.index == index && item.subItems.isNotEmpty) {
          for (final sub in item.subItems) {
            if (sub.subIndex == subIndex) {
              return sub.label;
            }
          }
        }
      }
    }
    return null;
  }

  String _getPageLabel(int index) {
    if (index == 9) {
      if (_state.activeSreProfile == 'enterprise-elk') return 'OpenSearch Dashboards';
      if (_state.activeSreProfile == 'ultra-light') return 'VMUI / Grafana';
      return 'Monitoring';
    }
    if (index == 10) {
      if (_state.activeSreProfile == 'enterprise-elk') return 'SIEM & Audit Logs';
      if (_state.activeSreProfile == 'ultra-light') return 'VictoriaLogs';
      return 'Loki Logs';
    }
    if (index == 12) {
      if (_state.activeSreProfile == 'enterprise-elk') return 'Trace Analytics (APM)';
      return 'Jaeger';
    }
    if (index >= 0 && index < _pageLabels.length) {
      return _pageLabels[index];
    }
    return 'Overview';
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return OverviewPage(
          state: _state,
          onRefresh: _fetchData,
          onViewLegions: () => _selectDestination(2),
          onViewCenturions: () => _selectDestination(1),
          onViewTasks: () => _selectDestination(3),
          onViewStackContainers: (stackName) {
            final owningSection = _sectionIdForIndex(3);
            setState(() {
              _tasksFilterStack = stackName;
              _selectedIndex = 3;
              if (_collapsedSections.remove(owningSection)) {
                _saveCollapsedSections();
              }
            });
          },
        );
      case 1:
        return CenturionsPage(state: _state, onRefresh: _fetchData);
      case 2:
        return LegionsPage(
          state: _state,
          onRefresh: _fetchData,
          selectedSubIndex: _selectedSubIndex,
          onSwitchToManaged: () => _selectDestination(2, subIndex: 0),
          onViewContainerLogs: (containerName) {
            final owningSection = _sectionIdForIndex(10);
            setState(() {
              _lokiFilterContainer = containerName;
              _selectedIndex = 10; // Navigate to Loki Logs Explorer
              if (_collapsedSections.remove(owningSection)) {
                _saveCollapsedSections();
              }
            });
          },
          onViewStackContainers: (stackName) {
            final owningSection = _sectionIdForIndex(3);
            setState(() {
              _tasksFilterStack = stackName;
              _selectedIndex = 3; // Navigate to Containers tab filtered by stack
              if (_collapsedSections.remove(owningSection)) {
                _saveCollapsedSections();
              }
            });
          },
        );
      case 3:
        return TasksPage(
          state: _state,
          onRefresh: _fetchData,
          initialFilterStack: _tasksFilterStack,
        );
      case 4:
        return StoragePage(
          state: _state,
          onRefresh: _fetchData,
          selectedSubIndex: _selectedSubIndex,
        );
      case 5:
        return ImageSecurityPage(
          state: _state,
          onRefresh: _fetchData,
          onNavigateTab: (idx) => _selectDestination(idx),
          selectedSubIndex: _selectedSubIndex,
        );
      case 6:
        return SloPage(
          state: _state,
          onRefresh: _fetchData,
          selectedSubIndex: _selectedSubIndex,
        );
      case 7:
        return CaddyPage(
          state: _state,
          onRefresh: _fetchData,
          selectedSubIndex: _selectedSubIndex,
        );
      case 8:
        return CoreDnsPage(
          state: _state,
          onRefresh: _fetchData,
          selectedSubIndex: _selectedSubIndex,
        );
      case 9:
        if (_state.activeSreProfile == 'enterprise-elk') {
          return const OpenSearchDashboardsPage();
        }
        return _grafanaPage;
      case 10:
        if (_state.activeSreProfile == 'enterprise-elk') {
          return OpenSearchDiscoverPage(
            onSwitchedProfile: _fetchData,
          );
        }
        return LokiLogsPage(
          initialContainer: _lokiFilterContainer,
          activeProfile: _state.activeSreProfile,
        );
      case 11:
        if (_state.activeSreProfile == 'enterprise-elk') {
          return SreFeatureAdaptivePage(
            featureName: 'Network Bandwidth & Traffic Monitor',
            featureIcon: Icons.network_check,
            activeProfileId: _state.activeSreProfile,
            onSwitchedProfile: _fetchData,
            onBackToOverview: () => _selectDestination(0),
          );
        }
        return _networkPage;
      case 12:
        if (_state.activeSreProfile == 'enterprise-elk') {
          return OpenSearchTracesPage(
            onSwitchedProfile: _fetchData,
          );
        }
        return _jaegerPage;
      case 13:
        return _scopePage;
      case 14:
        return EbpfPage(
          key: const ValueKey('page-ebpf-singleton'),
          selectedSubIndex: _selectedSubIndex,
        );
      case 15:
        return SecurityPage(
          state: _state,
          onRefresh: _fetchData,
          selectedSubIndex: _selectedSubIndex,
        );
      case 16:
        return ComposeStudioPage(state: _state, onRefresh: _fetchData);
      default:
        return OverviewPage(
          state: _state,
          onRefresh: _fetchData,
          onViewLegions: () => setState(() => _selectedIndex = 2),
          onViewCenturions: () => setState(() => _selectedIndex = 1),
          onViewTasks: () => setState(() => _selectedIndex = 3),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = widget.currentUser ?? _state.currentUser;

    final sidebarSections = _buildSidebarSections();
    final activeSubLabel =
        _getSubPageLabel(sidebarSections, _selectedIndex, _selectedSubIndex);

    return Scaffold(
      body: Row(
        children: [
          // ─── Sidebar ─────────────────────────────────────
          GubernatorSidebar(
            selectedIndex: _selectedIndex,
            selectedSubIndex: _selectedSubIndex,
            onDestinationSelected: (index) => _selectDestination(index),
            onSubDestinationSelected: (index, subIndex) =>
                _selectDestination(index, subIndex: subIndex),
            currentThemeId: widget.currentThemeId,
            onThemeChanged: widget.onThemeChanged,
            version: _state.version,
            updateAvailable: _state.updateAvailable,
            latestVersion: _state.latestVersion,
            onVersionCheckPressed: _showVersionCheckModal,
            onUpdatePressed: _showUpdateDialog,
            onSettingsPressed: _openSettings,
            sections: sidebarSections,
            collapsedSections: _collapsedSections,
            onToggleSection: _toggleSidebarSection,
            expandedItems: _expandedItems,
            onToggleItemExpand: _toggleSidebarItemExpand,
            onToggleAllSections: _toggleAllSidebarSections,
            isCollapsed: _sidebarCollapsed,
            onToggleCollapse: () =>
                setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            monitorRunning: _state.monitorRunning,
          ),

          // ─── Main Content Area ───────────────────────────
          Expanded(
            child: Column(
              children: [
                // ─── Top Header Bar ─────────────────────────
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    border: Border(
                      bottom: BorderSide(
                        color: theme.dividerColor,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Breadcrumb
                      Text(
                        _getPageLabel(_selectedIndex),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (activeSubLabel != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.45),
                          ),
                        ),
                        Text(
                          activeSubLabel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: GubernatorTheme.getThemeDef(
                                    widget.currentThemeId)
                                .sidebarActive,
                          ),
                        ),
                      ],

                      const Spacer(),

                      // User Profile Badge & Role Chip
                      if (user != null) ...[
                        Builder(builder: (context) {
                          final roleColor = user.isAdmin
                              ? (isDark ? Colors.amber : Colors.amber.shade800)
                              : user.isOperator
                                  ? (isDark ? Colors.blue : Colors.blue.shade700)
                                  : (isDark ? Colors.green : Colors.green.shade700);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.55 : 0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.dividerColor,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: roleColor.withValues(alpha: 0.18),
                                  child: Text(
                                    user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: roleColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  user.displayName,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: roleColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    user.isAdmin ? '👑 ADMIN' : user.isOperator ? '⚡ OPERATOR' : '👁️ READ-ONLY',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: roleColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(width: 12),
                      ],

                      // Last refresh
                      if (_lastRefresh != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Row(
                            children: [
                              Icon(Icons.access_time,
                                  size: 14,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4)),
                              const SizedBox(width: 4),
                              Text(
                                _formatTime(_lastRefresh!),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                  fontFamily: 'Courier New',
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Observability quick links
                      if (_state.monitorRunning) ...[
                        IconButton(
                          icon: const Icon(Icons.analytics_outlined, size: 20),
                          tooltip: 'Open Grafana (new tab)',
                          onPressed: () =>
                              html.window.open('/grafana/', '_blank'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.timeline, size: 20),
                          tooltip: 'Open Jaeger (new tab)',
                          onPressed: () =>
                              html.window.open('/jaeger/', '_blank'),
                        ),
                        const SizedBox(width: 4),
                      ],

                      // Refresh button
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Refresh now',
                        onPressed: _fetchData,
                      ),

                      // Logout button
                      if (widget.onLogout != null)
                        IconButton(
                          icon: const Icon(Icons.logout, size: 20, color: Colors.redAccent),
                          tooltip: 'Sign Out',
                          onPressed: widget.onLogout,
                        ),
                    ],
                  ),
                ),

                // ─── Page Content ───────────────────────────
                Expanded(
                  child: _loading && _state.nodes.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null && _state.nodes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cloud_off,
                                      size: 64,
                                      color: theme.colorScheme.error
                                          .withValues(alpha: 0.6)),
                                  const SizedBox(height: 16),
                                  Text('Connection error',
                                      style: theme.textTheme.titleLarge),
                                  const SizedBox(height: 8),
                                  Text(_error!,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                      )),
                                  const SizedBox(height: 24),
                                  FilledButton.icon(
                                    onPressed: _fetchData,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : AnimatedSwitcher(
                              duration: _pageTransitionDuration,
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  alignment: Alignment.topLeft,
                                  children: [
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                );
                              },
                              child: KeyedSubtree(
                                key: ValueKey<int>(_selectedIndex),
                                child: _buildCurrentPage(),
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

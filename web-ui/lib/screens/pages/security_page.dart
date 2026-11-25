import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';


part 'security/security_identity_part.dart';
part 'security/security_audit_siem_part.dart';
part 'security/security_compliance_nis2_part.dart';
part 'security/security_ens_part.dart';
part 'security/security_cis_docker_part.dart';
part 'security/security_iso_dora_part.dart';
part 'security/security_owasp_part.dart';

class SecurityPage extends StatefulWidget {
  final DashboardState state;
  final VoidCallback onRefresh;
  final int selectedSubIndex;

  const SecurityPage({
    super.key,
    required this.state,
    required this.onRefresh,
    this.selectedSubIndex = 0,
  });

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // LDAP State
  List<LDAPConfig> _ldapConfigs = [];
  bool _ldapLoading = true;
  String? _ldapError;

  // Local Users State
  List<LocalUser> _localUsers = [];
  bool _usersLoading = true;
  String? _usersError;

  // Audit Logs State
  List<AuditLog> _auditLogs = [];
  bool _auditLoading = true;
  String? _auditError;
  String _selectedProviderFilter = "";

  // OIDC / SSO State
  List<OIDCConfig> _oidcConfigs = [];
  List<OIDCProviderPreset> _oidcPresets = [];
  bool _oidcLoading = true;
  String? _oidcError;

  // SIEM & ENS Global Security State (ENS op.mon.1, op.acc.2)
  SIEMConfig? _siemConfig;
  SIEMStats? _siemStats;
  bool _siemLoading = true;
  bool _siemSaving = false;
  bool _siemTesting = false;

  // Forensic Audit Verification (SHA-256 Hash Chain)
  AuditVerificationResult? _auditVerification;
  bool _verifyingAudit = false;

  // Continuous Compliance Overview State
  ComplianceOverviewModel? _complianceOverview;
  bool _complianceOverviewLoading = true;
  bool _evaluatingAllCompliance = false;

  // Compliance Suite State (NIS 2, CIS Docker & ENS)
  String _selectedComplianceStandard = "NIS2"; // "NIS2", "CIS", "ENS", "ISO27001"

  // NIS 2 Compliance State (Directive (EU) 2022/2555)
  NIS2SummaryModel? _nis2Summary;
  bool _nis2Loading = true;
  String? _nis2Error;
  String _nis2DomainFilter = "ALL";

  // CIS Docker Benchmark v1.6.0 Compliance State
  CISDockerSummaryModel? _cisSummary;
  bool _cisLoading = true;
  String? _cisError;
  String _cisSectionFilter = "ALL"; // ALL, 1, 2, 3, 4, 5, 6
  String _cisLevelFilter = "ALL"; // ALL, Level 1, Level 2
  String _cisStatusFilter = "ALL"; // ALL, ISSUES, PASS, WARN, FAIL, INFO

  // ENS Compliance State (RD 311/2022)
  ENSSummaryModel? _ensSummary;
  bool _ensLoading = true;
  String? _ensError;
  String _ensLevelFilter = "ALL";

  // ISO/IEC 27001:2022 Annex A Compliance State
  ISO27001SummaryModel? _isoSummary;
  bool _isoLoading = true;
  String? _isoError;
  String _isoThemeFilter = "ALL"; // ALL, A.5, A.8
  String _isoStatusFilter = "ALL"; // ALL, ISSUES, COMPLIANT, PARTIAL, NON_COMPLIANT

  // DORA Compliance State (Regulation (EU) 2022/2554)
  DORASummaryModel? _doraSummary;
  bool _doraLoading = true;
  String? _doraError;
  String _doraPillarFilter = "ALL";
  String _doraStatusFilter = "ALL";

  // OWASP Security Suite State (Top 10 Web, API, ASVS L2, Docker, LLM, DAST & Compose Auditor)
  OWASPSummaryModel? _owaspSummary;
  bool _owaspLoading = true;
  String _owaspSubView = 'compliance'; // 'compliance', 'dast', 'compose'
  String _owaspDomainFilter = 'ALL';
  String _owaspStatusFilter = 'ALL';
  List<OWASPDASTResultModel> _owaspDastHistory = [];
  OWASPDASTResultModel? _owaspLatestDast;
  bool _owaspDastRunning = false;
  bool _owaspDastProbeWaf = true;
  bool _owaspDastIncludeZap = false;
  final TextEditingController _owaspDastUrlCtrl = TextEditingController(text: 'http://127.0.0.1:4001');
  final TextEditingController _owaspComposeCtrl = TextEditingController();
  OWASPComposeLintResultModel? _owaspComposeResult;
  bool _owaspComposeLinting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.selectedSubIndex.clamp(0, 4),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        if (_tabController.index == 0 && _localUsers.isEmpty && !_usersLoading) {
          _loadLocalUsers();
        } else if (_tabController.index == 4) {
          if (_complianceOverview == null && !_complianceOverviewLoading) {
            _loadComplianceOverview();
          }
          if (_nis2Summary == null && !_nis2Loading) _loadNIS2Status();
          if (_cisSummary == null && !_cisLoading) _loadCISStatus();
          if (_ensSummary == null && !_ensLoading) _loadENSStatus();
          if (_isoSummary == null && !_isoLoading) _loadISO27001Status();
          if (_doraSummary == null && !_doraLoading) _loadDORAStatus();
          if (_owaspSummary == null && !_owaspLoading) _loadOWASPStatus();
        }
      }
    });
    _loadAllData();
  }

  @override
  void didUpdateWidget(SecurityPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSubIndex != widget.selectedSubIndex) {
      final target = widget.selectedSubIndex.clamp(0, 4);
      if (_tabController.index != target) {
        _tabController.animateTo(target);
      }
    }
  }

  @override
  void dispose() {
    _owaspDastUrlCtrl.dispose();
    _owaspComposeCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    _loadLDAPConfigs();
    _loadLocalUsers();
    _loadAuditLogs();
    _loadOIDCConfigs();
    _loadSIEMConfig();
    _verifyAuditChain();
    _loadComplianceOverview();
    _loadNIS2Status();
    _loadCISStatus();
    _loadENSStatus();
    _loadISO27001Status();
    _loadDORAStatus();
    _loadOWASPStatus();
  }

  Future<void> _loadOWASPStatus() async {
    setState(() => _owaspLoading = true);
    try {
      final summary = await ApiService.fetchOWASPStatus();
      if (mounted) {
        setState(() {
          _owaspSummary = summary;
          _owaspLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _owaspLoading = false);
    }
  }

  Future<void> _loadOWASPDASTHistory() async {
    final hist = await ApiService.fetchOWASPDASTHistory();
    if (mounted) setState(() => _owaspDastHistory = hist);
  }

  Future<void> _runOWASPDAST() async {
    final target = _owaspDastUrlCtrl.text.trim();
    if (target.isEmpty) return;
    setState(() => _owaspDastRunning = true);
    try {
      final res = await ApiService.runOWASPDASTScan(
        targetUrl: target,
        probeWaf: _owaspDastProbeWaf,
        includeZap: _owaspDastIncludeZap,
      );
      if (mounted) {
        setState(() {
          _owaspLatestDast = res;
          _owaspDastRunning = false;
        });
        _loadOWASPDASTHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _owaspDastRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DAST Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _runOWASPComposeLint() async {
    final yaml = _owaspComposeCtrl.text.trim();
    if (yaml.isEmpty) return;
    setState(() => _owaspComposeLinting = true);
    try {
      final res = await ApiService.lintComposeOWASP(yaml);
      if (mounted) {
        setState(() {
          _owaspComposeResult = res;
          _owaspComposeLinting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _owaspComposeLinting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lint Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _downloadOWASPReport(String format) async {
    final content = await ApiService.fetchOWASPReport(format: format);
    if (content == null || !mounted) return;
    final ext = format == 'json' ? 'json' : 'md';
    final mime = format == 'json' ? 'application/json' : 'text/markdown';
    final blob = html.Blob([content], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final a = html.AnchorElement(href: url)
      ..setAttribute('download', 'owasp-compliance-report.$ext')
      ..click();
    html.Url.revokeObjectUrl(url);
    a.remove();
  }

  Future<void> _loadComplianceOverview() async {
    setState(() => _complianceOverviewLoading = true);
    try {
      final overview = await ApiService.fetchComplianceOverview();
      if (mounted) {
        setState(() {
          _complianceOverview = overview;
          _complianceOverviewLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _complianceOverviewLoading = false);
    }
  }

  Future<void> _evaluateAllCompliance() async {
    setState(() => _evaluatingAllCompliance = true);
    try {
      final overview = await ApiService.evaluateAllCompliance();
      if (mounted) {
        setState(() {
          _complianceOverview = overview;
          _evaluatingAllCompliance = false;
        });
      }
      // Concurrently reload all active standard summaries
      await Future.wait([
        _loadNIS2Status(),
        _loadCISStatus(),
        _loadENSStatus(),
        _loadISO27001Status(),
        _loadDORAStatus(),
        _loadOWASPStatus(),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.verified_user_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text("Audit synchronized: All regulatory frameworks have been re-evaluated."),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _evaluatingAllCompliance = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error during cluster re-evaluation: $e"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadNIS2Status() async {
    setState(() {
      _nis2Loading = true;
      _nis2Error = null;
    });
    try {
      final summary = await ApiService.fetchNIS2Status();
      if (mounted) {
        setState(() {
          _nis2Summary = summary;
          _nis2Loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _nis2Error = e.toString();
          _nis2Loading = false;
        });
      }
    }
  }

  Future<void> _loadENSStatus() async {
    setState(() {
      _ensLoading = true;
      _ensError = null;
    });
    try {
      final summary = await ApiService.fetchENSStatus();
      if (mounted) {
        setState(() {
          _ensSummary = summary;
          _ensLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ensError = e.toString();
          _ensLoading = false;
        });
      }
    }
  }

  Future<void> _loadCISStatus() async {
    setState(() {
      _cisLoading = true;
      _cisError = null;
    });
    try {
      final summary = await ApiService.fetchCISDockerStatus();
      if (mounted) {
        setState(() {
          _cisSummary = summary;
          _cisLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cisError = e.toString();
          _cisLoading = false;
        });
      }
    }
  }

  Future<void> _loadISO27001Status() async {
    setState(() {
      _isoLoading = true;
      _isoError = null;
    });
    try {
      final summary = await ApiService.fetchISO27001Status();
      if (mounted) {
        setState(() {
          _isoSummary = summary;
          _isoLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isoError = e.toString();
          _isoLoading = false;
        });
      }
    }
  }

  Future<void> _loadDORAStatus() async {
    setState(() {
      _doraLoading = true;
      _doraError = null;
    });
    try {
      final summary = await ApiService.fetchDORAStatus();
      if (mounted) {
        setState(() {
          _doraSummary = summary;
          _doraLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _doraError = e.toString();
          _doraLoading = false;
        });
      }
    }
  }

  Future<void> _loadSIEMConfig() async {
    setState(() => _siemLoading = true);
    final status = await ApiService.fetchSIEMStatus();
    if (mounted) {
      setState(() {
        if (status != null) {
          _siemConfig = status.config;
          _siemStats = status.stats;
        }
        _siemLoading = false;
      });
    }
  }

  Future<void> _verifyAuditChain() async {
    setState(() => _verifyingAudit = true);
    final res = await ApiService.verifyAuditChain();
    if (mounted) {
      setState(() {
        _auditVerification = res;
        _verifyingAudit = false;
      });
    }
  }

  Future<void> _loadOIDCConfigs() async {
    setState(() {
      _oidcLoading = true;
      _oidcError = null;
    });
    try {
      final configs = await ApiService.fetchOIDCConfigs();
      final presets = await ApiService.fetchOIDCPresets();
      if (mounted) {
        setState(() {
          _oidcConfigs = configs;
          _oidcPresets = presets;
          _oidcLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _oidcError = e.toString();
          _oidcLoading = false;
        });
      }
    }
  }

  Future<void> _loadLDAPConfigs() async {
    setState(() {
      _ldapLoading = true;
      _ldapError = null;
    });
    try {
      final configs = await ApiService.fetchLDAPConfigs();
      if (mounted) {
        setState(() {
          _ldapConfigs = configs;
          _ldapLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ldapError = e.toString();
          _ldapLoading = false;
        });
      }
    }
  }

  LocalUser _defaultAdminFallback() {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    return LocalUser(
      id: 'local-admin',
      username: 'admin',
      displayName: 'Cluster Administrator',
      email: 'admin@gubernator.local',
      role: 'admin',
      enabled: true,
      mfaEnabled: false,
      createdAt: nowIso,
      updatedAt: nowIso,
    );
  }

  Future<void> _loadLocalUsers() async {
    setState(() {
      _usersLoading = true;
      _usersError = null;
    });
    try {
      final users = await ApiService.fetchLocalUsers();
      if (mounted) {
        setState(() {
          _localUsers = users.isNotEmpty ? users : [_defaultAdminFallback()];
          _usersLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_localUsers.isEmpty) {
            _localUsers = [_defaultAdminFallback()];
          }
          _usersError = null;
          _usersLoading = false;
        });
      }
    }
  }

  Future<void> _loadAuditLogs() async {
    setState(() {
      _auditLoading = true;
      _auditError = null;
    });
    try {
      final logs = await ApiService.fetchAuditLogs(provider: _selectedProviderFilter);
      if (mounted) {
        setState(() {
          _auditLogs = logs;
          _auditLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _auditError = e.toString();
          _auditLoading = false;
        });
      }
    }
  }

  void _updateState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // UI BUILD METHOD & TABS
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, color: primaryColor, size: 26),
                          const SizedBox(width: 10),
                          const Flexible(
                            child: Text(
                              "Security, Directory & User Access Control",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Local user accounts, Active Directory/LDAP servers, RBAC policies, and audit access logs.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text("Refresh All"),
                  onPressed: _loadAllData,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Views Container (controlled via Level-3 Sidebar Navigation)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildLocalUsersTab(isDark, primaryColor),
                  _buildLDAPTab(isDark, primaryColor),
                  _buildOIDCTab(isDark, primaryColor),
                  _buildAuditLogsTab(isDark, primaryColor),
                  _buildComplianceHubTab(isDark, primaryColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

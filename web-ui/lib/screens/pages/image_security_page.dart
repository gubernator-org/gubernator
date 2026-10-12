import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/image_remediation_dialog.dart';
import '../../widgets/image_history_dialog.dart';
import '../../widgets/image_build_dialog.dart';
import '../../widgets/sign_image_dialog.dart';
import '../../widgets/image_distribute_dialog.dart';

part 'image_security/image_vulnerabilities_sbom_part.dart';
part 'image_security/image_signatures_policies_part.dart';

/// Image Security & SBOM (The Imperial Seal / The Armory)
class ImageSecurityPage extends StatefulWidget {
  final DashboardState state;
  final VoidCallback onRefresh;
  final Function(int tabIndex)? onNavigateTab;
  final Function(String stackId)? onOpenInComposeStudio;

  const ImageSecurityPage({
    super.key,
    required this.state,
    required this.onRefresh,
    this.onNavigateTab,
    this.onOpenInComposeStudio,
  });

  @override
  State<ImageSecurityPage> createState() => _ImageSecurityPageState();
}

class _ImageSecurityPageState extends State<ImageSecurityPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data states
  List<ImageScanModel> _scans = [];
  SecuritySummaryModel _summary = SecuritySummaryModel();
  List<TrustedKeyModel> _keys = [];
  SecurityPolicyModel? _policy;
  bool _loading = false;

  // Filters & Selected states
  String _scanSearch = '';
  String _severityFilter = 'ALL';
  String? _selectedSbomImage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    try {
      final scansFuture = ApiService.fetchImageScans();
      final keysFuture = ApiService.fetchTrustedKeys();
      final policyFuture = ApiService.fetchSecurityPolicy();

      final results = await Future.wait([
        scansFuture.catchError((_) => {'scans': <ImageScanModel>[], 'summary': SecuritySummaryModel()}),
        keysFuture.catchError((_) => <TrustedKeyModel>[]),
        policyFuture.catchError((_) => SecurityPolicyModel(id: 'default', name: 'Cluster Policy', updatedAt: '')),
      ]);

      if (mounted) {
        final scansData = results[0] as Map<String, dynamic>;
        setState(() {
          _scans = scansData['scans'] as List<ImageScanModel>;
          _summary = scansData['summary'] as SecuritySummaryModel;
          _keys = results[1] as List<TrustedKeyModel>;
          _policy = results[2] as SecurityPolicyModel;
          _loading = false;
        });

        if (_scans.isNotEmpty && _selectedSbomImage == null) {
          _loadSbom(_scans.first.imageName);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSbom(String image) async {
    setState(() {
      _selectedSbomImage = image;
    });
    try {
      await ApiService.fetchScanDetails(image); // fallback check
      if (mounted) {
        setState(() {
          _selectedSbomImage = image;
        });
      }
    } catch (_) {}
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF10B981),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _updateState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Color(0xFFF97316), size: 28),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Image Security & SBOM',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            'THE IMPERIAL SEAL',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF97316), letterSpacing: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Container vulnerability scanning (CVEs), Software Bill of Materials, Cosign signatures, and admission gatekeeper',
                      style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    ),
                  ],
                ),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                  onPressed: _loadAllData,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary Metric Badges
            Row(
              children: [
                _summaryCard('Scanned Images', '${_summary.totalScanned}', Icons.image, Colors.blue, isDark),
                const SizedBox(width: 12),
                _summaryCard('Critical CVEs', '${_summary.criticalCount}', Icons.dangerous, Colors.redAccent, isDark),
                const SizedBox(width: 12),
                _summaryCard('High CVEs', '${_summary.highCount}', Icons.warning_amber, Colors.orange, isDark),
                const SizedBox(width: 12),
                _summaryCard('Verified Signatures', '${_summary.verifiedSigned}', Icons.verified, const Color(0xFF10B981), isDark),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Bar
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFF97316),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF97316).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.2),
                unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[700],
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: [
                  Tab(
                    height: 42,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.security, size: 18),
                          const SizedBox(width: 8),
                          Text('Vulnerabilities (${_scans.length})'),
                        ],
                      ),
                    ),
                  ),
                  const Tab(
                    height: 42,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory, size: 18),
                          SizedBox(width: 8),
                          Text('SBOM Explorer'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    height: 42,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified, size: 18),
                          const SizedBox(width: 8),
                          Text('Signatures & Keys (${_keys.length})'),
                        ],
                      ),
                    ),
                  ),
                  const Tab(
                    height: 42,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.gavel, size: 18),
                          SizedBox(width: 8),
                          Text('Gatekeeper Policies'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildVulnerabilitiesTab(isDark),
                        _buildSBOMTab(isDark),
                        _buildSignaturesTab(isDark),
                        _buildPoliciesTab(isDark),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

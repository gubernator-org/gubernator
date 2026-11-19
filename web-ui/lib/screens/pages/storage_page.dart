import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';


part 'storage/storage_volumes_part.dart';
part 'storage/storage_backups_pools_part.dart';
part 'storage/storage_mounts_fstab_part.dart';
part 'storage/storage_gluster_part.dart';

/// Storage & Backups (The Granaries) — Multi-node persistent storage and backup suite.
class StoragePage extends StatefulWidget {
  final DashboardState state;
  final VoidCallback onRefresh;
  final int selectedSubIndex;

  const StoragePage({
    super.key,
    required this.state,
    required this.onRefresh,
    this.selectedSubIndex = 0,
  });

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data states
  List<StorageVolumeModel> _volumes = [];
  List<BackupModel> _backups = [];
  List<BackupScheduleModel> _schedules = [];
  List<StorageMountModel> _mounts = [];
  PoolHealthModel? _poolHealth;
  List<GlusterPeerModel> _glusterPeers = [];
  List<GlusterVolumeModel> _glusterVolumes = [];
  GlusterClusterDiagnosticsModel? _glusterDiag;
  bool _loading = false;

  // Filters
  String _volumeSearch = '';
  String _volumeTypeFilter = 'ALL';
  String _volumeNodeFilter = 'ALL';
  String _backupSearch = '';
  String _mountSearch = '';
  String _mountTypeFilter = 'ALL';
  final String _poolPath = '/var/contenedores';

  // Cockpit-Storaged & Storage Network State
  StorageNetworkReportModel _storageNetworkReport = StorageNetworkReportModel.empty();
  List<GlusterSnapshotModel> _glusterSnapshots = [];
  GlusterProfileReportModel? _activeProfileReport;
  GlusterQuotasReportModel? _activeQuotasReport;
  String _selectedGlusterVolumeForProfile = '';
  int _glusterSubTab = 0; // 0: Overview, 1: Performance (Cockpit), 2: Storage Network (Dual NIC), 3: Quotas, 4: Snapshots, 5: Options

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.selectedSubIndex.clamp(0, 5),
    );
    _loadAllData();
  }

  @override
  void didUpdateWidget(StoragePage oldWidget) {
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
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }
    setState(() => _loading = true);
    try {
      final volsFuture = ApiService.fetchStorageVolumes(
        targetNode: _volumeNodeFilter != 'ALL' ? _volumeNodeFilter : null,
      );
      final backupsFuture = ApiService.fetchBackups();
      final schedulesFuture = ApiService.fetchBackupSchedules();
      final healthFuture = ApiService.fetchStoragePoolHealth(path: _poolPath);
      final mountsFuture = ApiService.fetchStorageMounts();
      final glusterPeersFuture = ApiService.fetchGlusterPeers();
      final glusterVolsFuture = ApiService.fetchGlusterVolumes();
      final glusterDiagFuture = ApiService.fetchGlusterDiagnostics();
      final storageNetFuture = ApiService.fetchStorageNetworkReport();
      final glusterSnapsFuture = ApiService.fetchGlusterSnapshots();

      final results = await Future.wait([
        volsFuture.catchError((_) => <StorageVolumeModel>[]),
        backupsFuture.catchError((_) => <BackupModel>[]),
        schedulesFuture.catchError((_) => <BackupScheduleModel>[]),
        healthFuture.catchError((_) => PoolHealthModel(poolPath: _poolPath, status: 'error')),
        mountsFuture.catchError((_) => <StorageMountModel>[]),
        glusterPeersFuture.catchError((_) => <GlusterPeerModel>[]),
        glusterVolsFuture.catchError((_) => <GlusterVolumeModel>[]),
        glusterDiagFuture.catchError((_) => GlusterClusterDiagnosticsModel(installed: false)),
        storageNetFuture.catchError((_) => StorageNetworkReportModel.empty()),
        glusterSnapsFuture.catchError((_) => <GlusterSnapshotModel>[]),
      ]);

      if (mounted) {
        setState(() {
          _volumes = results[0] as List<StorageVolumeModel>;
          _backups = results[1] as List<BackupModel>;
          _schedules = results[2] as List<BackupScheduleModel>;
          _poolHealth = results[3] as PoolHealthModel;
          _mounts = results[4] as List<StorageMountModel>;
          _glusterPeers = results[5] as List<GlusterPeerModel>;
          _glusterVolumes = results[6] as List<GlusterVolumeModel>;
          _glusterDiag = results[7] as GlusterClusterDiagnosticsModel;
          _storageNetworkReport = results[8] as StorageNetworkReportModel;
          _glusterSnapshots = results[9] as List<GlusterSnapshotModel>;
          if (_glusterVolumes.isNotEmpty && _selectedGlusterVolumeForProfile.isEmpty) {
            _selectedGlusterVolumeForProfile = _glusterVolumes.first.name;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF10B981),
        duration: Duration(seconds: isError ? 6 : 4),
        action: isError
            ? SnackBarAction(
                label: 'View Error',
                textColor: Colors.white,
                onPressed: () => _showErrorDialog('Operation Failed', message),
              )
            : null,
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 22),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The system returned the following detailed error output:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: SelectableText(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Courier New',
                    fontSize: 12,
                    color: Color(0xFFFCA5A5),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Error'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              _showSnackBar('Error message copied to clipboard');
            },
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
        ],
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
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2, color: Color(0xFF10B981), size: 28),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Storage & Backups',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            'THE GRANARIES',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981), letterSpacing: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cluster persistent volumes, shared storage pools (/var/contenedores), snapshots, and backup policies',
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
            const SizedBox(height: 20),

            // Tab Bar
            // Tab Content (controlled via Level-3 Sidebar Navigation)
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildVolumesTab(isDark),
                        _buildBackupsTab(isDark),
                        _buildSchedulesTab(isDark),
                        _buildPoolsTab(isDark),
                        _buildMountsTab(isDark),
                        _buildGlusterTab(isDark),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }


  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (bytes > 0) ? (bytes.bitLength - 1) ~/ 10 : 0;
    if (i >= suffixes.length) i = suffixes.length - 1;
    double count = bytes / (1 << (i * 10));
    return '${count.toStringAsFixed(1)} ${suffixes[i]}';
  }
}

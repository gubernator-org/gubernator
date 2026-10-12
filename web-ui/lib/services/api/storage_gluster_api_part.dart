part of '../api_service.dart';

class StorageGlusterApi {
  static Map<String, String> get authHeaders => ApiService.authHeaders;
  static String? get authToken => ApiService.authToken;
  static set authToken(String? token) => ApiService.authToken = token;

  // ── Storage & Backups API Methods ─────────────────────────────────

  /// Fetches all cluster persistent volumes, docker volumes, and bind mounts.
  static Future<List<StorageVolumeModel>> fetchStorageVolumes({String? targetNode}) async {
    final url = (targetNode != null && targetNode.isNotEmpty && targetNode != 'all')
        ? '/api/storage/volumes?node=${Uri.encodeQueryComponent(targetNode)}'
        : '/api/storage/volumes';
    final response = await http.get(Uri.parse(url), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = (data['volumes'] as List? ?? [])
          .map((e) => StorageVolumeModel.fromJson(e))
          .toList();
      return list;
    }
    throw Exception('Failed to fetch storage volumes: ${response.statusCode}');
  }

  /// Creates a new Docker named volume on target nodes.
  static Future<String> createDockerVolume({
    required String name,
    required String targetNode,
    String driver = 'local',
    Map<String, String>? driverOpts,
    Map<String, String>? labels,
  }) async {
    final response = await http.post(
      Uri.parse('/api/storage/volumes/docker'),
      headers: authHeaders,
      body: jsonEncode({
        'name': name,
        'driver': driver,
        'target_node': targetNode,
        if (driverOpts != null && driverOpts.isNotEmpty) 'driver_opts': driverOpts,
        if (labels != null && labels.isNotEmpty) 'labels': labels,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['message'] ?? 'Volume created successfully';
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['error'] ?? 'Failed to create volume (${response.statusCode})');
  }

  /// Deletes a Docker volume from target node(s).
  static Future<String> deleteDockerVolume({
    required String name,
    String? targetNode,
    bool force = false,
  }) async {
    final queryParams = <String, String>{
      'name': name,
      if (targetNode != null && targetNode.isNotEmpty) 'node': targetNode,
      if (force) 'force': 'true',
    };
    final uri = Uri.parse('/api/storage/volumes/docker').replace(queryParameters: queryParams);
    final response = await http.delete(uri, headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['message'] ?? 'Volume deleted successfully';
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['error'] ?? 'Failed to delete volume (${response.statusCode})');
  }

  /// Prunes unused / dangling Docker volumes on target node(s).
  static Future<String> pruneDockerVolumes({String? targetNode}) async {
    final response = await http.post(
      Uri.parse('/api/storage/volumes/docker/prune'),
      headers: authHeaders,
      body: jsonEncode({
        'target_node': targetNode ?? 'all',
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['report'] ?? data['message'] ?? 'Pruned successfully';
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['error'] ?? 'Failed to prune volumes (${response.statusCode})');
  }

  /// Inspects a Docker volume and returns JSON metadata.
  static Future<Map<String, dynamic>> inspectDockerVolume({
    required String name,
    String? targetNode,
  }) async {
    final queryParams = <String, String>{
      'name': name,
      if (targetNode != null && targetNode.isNotEmpty) 'node': targetNode,
    };
    final uri = Uri.parse('/api/storage/volumes/docker/inspect').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: authHeaders);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['error'] ?? 'Failed to inspect volume (${response.statusCode})');
  }

  /// Creates a new storage directory on target nodes.
  static Future<bool> createStorageDirectory({
    required String path,
    required String targetNode,
    String permissions = '0777',
  }) async {
    final response = await http.post(
      Uri.parse('/api/storage/directories'),
      headers: authHeaders,
      body: jsonEncode({
        'path': path,
        'target_node': targetNode,
        'permissions': permissions,
      }),
    );
    return response.statusCode == 200;
  }

  /// Lists files and subdirectories within a given path on a specific node.
  static Future<List<DirectoryEntryModel>> listDirectoryContents({
    required String path,
    String? targetNode,
  }) async {
    final queryParams = <String, String>{'path': path};
    if (targetNode != null && targetNode.isNotEmpty) {
      queryParams['node'] = targetNode;
    }
    final uri = Uri.parse('/api/storage/directories/ls').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['entries'] as List? ?? [])
          .map((e) => DirectoryEntryModel.fromJson(e))
          .toList();
    }
    throw Exception('Failed to list directory contents: ${response.statusCode}');
  }

  /// Fetches shared storage pool health and capacity diagnostics.
  static Future<PoolHealthModel> fetchStoragePoolHealth({String path = '/var/contenedores'}) async {
    final url = '/api/storage/pools/health?path=${Uri.encodeQueryComponent(path)}';
    final response = await http.get(Uri.parse(url), headers: authHeaders);
    if (response.statusCode == 200) {
      return PoolHealthModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch storage pool health: ${response.statusCode}');
  }

  /// Fetches all backup archives.
  static Future<List<BackupModel>> fetchBackups() async {
    final response = await http.get(Uri.parse('/api/backups'), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = (data['backups'] as List? ?? [])
          .map((e) => BackupModel.fromJson(e))
          .toList();
      return list;
    }
    throw Exception('Failed to fetch backups: ${response.statusCode}');
  }

  /// Creates a new compressed backup archive (with optional AES-256-GCM encryption).
  static Future<BackupModel> createBackup({
    required String name,
    String stackId = '',
    String volumeName = '',
    String sourcePath = '',
    String destinationPath = '',
    bool pauseContainers = true,
    bool encrypted = false,
    String encryptionPassphrase = '',
  }) async {
    final body = jsonEncode({
      'name': name,
      'stack_id': stackId,
      'volume_name': volumeName,
      'source_path': sourcePath,
      'destination_path': destinationPath,
      'pause_containers': pauseContainers,
      'encrypted': encrypted,
      'encryption_passphrase': encryptionPassphrase,
    });
    final response = await http.post(
      Uri.parse('/api/backups/create'),
      headers: authHeaders,
      body: body,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return BackupModel.fromJson(data['backup']);
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['error'] ?? 'Failed to create backup');
  }

  /// Restores a backup archive to target directory (with optional AES-256-GCM decryption).
  static Future<bool> restoreBackup({
    required String backupId,
    String targetPath = '',
    String encryptionPassphrase = '',
  }) async {
    final body = jsonEncode({
      'backup_id': backupId,
      'target_path': targetPath,
      'encryption_passphrase': encryptionPassphrase,
    });
    final response = await http.post(
      Uri.parse('/api/backups/restore'),
      headers: authHeaders,
      body: body,
    );
    if (response.statusCode == 200) {
      return true;
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['error'] ?? 'Failed to restore backup');
  }

  /// Deletes a backup archive.
  static Future<bool> deleteBackup(String id) async {
    final response = await http.delete(Uri.parse('/api/backups/$id'), headers: authHeaders);
    return response.statusCode == 200;
  }

  /// Fetches all automated backup schedules.
  static Future<List<BackupScheduleModel>> fetchBackupSchedules() async {
    final response = await http.get(Uri.parse('/api/backups/schedules'), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = (data['schedules'] as List? ?? [])
          .map((e) => BackupScheduleModel.fromJson(e))
          .toList();
      return list;
    }
    throw Exception('Failed to fetch backup schedules: ${response.statusCode}');
  }

  /// Creates or updates a backup schedule.
  static Future<BackupScheduleModel> saveBackupSchedule(BackupScheduleModel schedule) async {
    final response = await http.post(
      Uri.parse('/api/backups/schedules'),
      headers: authHeaders,
      body: jsonEncode(schedule.toJson()),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return BackupScheduleModel.fromJson(data['schedule']);
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['error'] ?? 'Failed to save schedule');
  }

  /// Deletes a backup schedule.
  static Future<bool> deleteBackupSchedule(String id) async {
    final response = await http.delete(Uri.parse('/api/backups/schedules/$id'), headers: authHeaders);
    return response.statusCode == 200;
  }

  /// Fetches all network storage mounts (NFS, S3, Samba, /etc/fstab).
  static Future<List<StorageMountModel>> fetchStorageMounts() async {
    final response = await http.get(Uri.parse('/api/storage/mounts'), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = (data['mounts'] as List? ?? [])
          .map((e) => StorageMountModel.fromJson(e))
          .toList();
      return list;
    }
    throw Exception('Failed to fetch mounts: ${response.statusCode}');
  }

  /// Creates and mounts a new network storage entry.
  static Future<StorageMountModel> createStorageMount(Map<String, dynamic> req) async {
    final response = await http.post(
      Uri.parse('/api/storage/mounts'),
      headers: authHeaders,
      body: jsonEncode(req),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return StorageMountModel.fromJson(data['mount']);
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['error'] ?? 'Failed to configure mount');
  }

  /// Tests connectivity and R/W access for a remote mount.
  static Future<TestMountResultModel> testStorageMount(Map<String, dynamic> req) async {
    final response = await http.post(
      Uri.parse('/api/storage/mounts/test'),
      headers: authHeaders,
      body: jsonEncode(req),
    );
    if (response.statusCode == 200) {
      return TestMountResultModel.fromJson(jsonDecode(response.body));
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['error'] ?? 'Failed to test mount');
  }

  /// Mounts an existing configured entry on target node(s).
  static Future<bool> mountStorageEntry(String id, {String? targetNode}) async {
    final body = targetNode != null && targetNode.isNotEmpty ? jsonEncode({'target_node': targetNode}) : null;
    final response = await http.post(
      Uri.parse('/api/storage/mounts/$id/mount'),
      headers: authHeaders,
      body: body,
    );
    if (response.statusCode == 200) return true;
    final errData = jsonDecode(response.body);
    throw Exception(errData['error'] ?? 'Mount failed');
  }

  /// Unmounts an existing entry from target node(s).
  static Future<bool> unmountStorageEntry(String id, {String? targetNode}) async {
    final body = targetNode != null && targetNode.isNotEmpty ? jsonEncode({'target_node': targetNode}) : null;
    final response = await http.post(
      Uri.parse('/api/storage/mounts/$id/unmount'),
      headers: authHeaders,
      body: body,
    );
    if (response.statusCode == 200) return true;
    final errData = jsonDecode(response.body);
    throw Exception(errData['error'] ?? 'Unmount failed');
  }

  /// Deletes a mount and cleans up /etc/fstab across target nodes.
  /// If deleteGluster is true, also deletes the underlying GlusterFS volume.
  static Future<bool> deleteStorageMount(String id, {bool deleteGluster = false}) async {
    final url = deleteGluster ? '/api/storage/mounts/$id?delete_gluster=true' : '/api/storage/mounts/$id';
    final response = await http.delete(Uri.parse(url), headers: authHeaders);
    return response.statusCode == 200;
  }

  /// Executes mount -a on host or all cluster nodes.
  static Future<String> mountAllStorageEntries({String? targetNode}) async {
    final body = targetNode != null && targetNode.isNotEmpty ? jsonEncode({'target_node': targetNode}) : null;
    final response = await http.post(
      Uri.parse('/api/storage/mounts/mount-all'),
      headers: authHeaders,
      body: body,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data['output'] ?? 'OK';
    }
    throw Exception(data['error'] ?? 'mount -a failed');
  }

  /// Fetches raw /etc/fstab contents from a specific host or local manager.
  static Future<Map<String, dynamic>> fetchRawFstab({String? node}) async {
    final query = (node != null && node.isNotEmpty) ? '?node=$node' : '';
    final response = await http.get(Uri.parse('/api/storage/fstab/raw$query'), headers: authHeaders);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to read fstab: ${response.statusCode}');
  }

  /// Saves and safely writes raw /etc/fstab on target node(s) with automated backup.
  static Future<String> saveRawFstab(String content, {String? node}) async {
    final response = await http.post(
      Uri.parse('/api/storage/fstab/raw'),
      headers: authHeaders,
      body: jsonEncode({
        'node': node ?? 'all',
        'content': content,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data['message'] ?? 'fstab saved successfully';
    }
    throw Exception(data['error'] ?? 'Failed to save /etc/fstab');
  }

  // ── Docker Daemon Management (/etc/docker/daemon.json) ──────────────────────

  /// Fetches the status and configuration of /etc/docker/daemon.json across nodes.
  static Future<Map<String, dynamic>> fetchDockerDaemonConfig({String? scope, String? node}) async {
    final params = <String>[];
    if (scope != null && scope.isNotEmpty) params.add('scope=${Uri.encodeComponent(scope)}');
    if (node != null && node.isNotEmpty) params.add('node=${Uri.encodeComponent(node)}');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final response = await http.get(Uri.parse('/api/docker/daemon$query'), headers: authHeaders);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to fetch Docker daemon status: ${response.statusCode}');
  }

  /// Saves, backs up, and applies /etc/docker/daemon.json to target nodes.
  static Future<Map<String, dynamic>> saveDockerDaemonConfig({
    required String targetScope,
    String? nodeId,
    required String rawJson,
    required String action,
    bool backup = true,
  }) async {
    final response = await http.post(
      Uri.parse('/api/docker/daemon'),
      headers: authHeaders,
      body: jsonEncode({
        'target_scope': targetScope,
        'node_id': nodeId ?? '',
        'raw_json': rawJson,
        'action': action,
        'backup': backup,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['error'] ?? 'Failed to apply Docker daemon configuration');
  }

  // ─── GlusterFS Cluster Storage Services ───────────────────────────────────

  /// Fetches all peers in the GlusterFS trusted storage pool.
  static Future<List<GlusterPeerModel>> fetchGlusterPeers() async {
    final response = await http.get(Uri.parse('/api/storage/gluster/peers'), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['peers'] is List) {
        return (data['peers'] as List).map((p) => GlusterPeerModel.fromJson(p)).toList();
      }
      return [];
    }
    throw Exception('Failed to fetch GlusterFS peers: ${response.statusCode}');
  }

  /// Probes a new node into the trusted storage pool.
  static Future<void> probeGlusterPeer(String hostname) async {
    final response = await http.post(
      Uri.parse('/api/storage/gluster/peers/probe'),
      headers: authHeaders,
      body: jsonEncode({'hostname': hostname}),
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to probe peer $hostname');
    }
  }

  /// Detaches a peer from the trusted storage pool.
  static Future<void> detachGlusterPeer(String hostname, {bool force = false}) async {
    final url = force ? '/api/storage/gluster/peers/$hostname?force=true' : '/api/storage/gluster/peers/$hostname';
    final response = await http.delete(Uri.parse(url), headers: authHeaders);
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to detach peer $hostname');
    }
  }

  /// Fetches all GlusterFS volumes.
  static Future<List<GlusterVolumeModel>> fetchGlusterVolumes() async {
    final response = await http.get(Uri.parse('/api/storage/gluster/volumes'), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['volumes'] is List) {
        return (data['volumes'] as List).map((v) => GlusterVolumeModel.fromJson(v)).toList();
      }
      return [];
    }
    throw Exception('Failed to fetch GlusterFS volumes: ${response.statusCode}');
  }

  /// Creates and tunes a new GlusterFS volume.
  static Future<void> createGlusterVolume(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('/api/storage/gluster/volumes'),
      headers: authHeaders,
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to create GlusterFS volume');
    }
  }

  /// Deletes a GlusterFS volume and optionally unmounts from /etc/fstab across cluster nodes.
  static Future<void> deleteGlusterVolume(String name, {bool unmount = true}) async {
    final url = unmount ? '/api/storage/gluster/volumes/$name?unmount=true' : '/api/storage/gluster/volumes/$name?unmount=false';
    final response = await http.delete(Uri.parse(url), headers: authHeaders);
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to delete volume $name');
    }
  }

  /// Deletes all GlusterFS volumes across the cluster.
  static Future<void> deleteAllGlusterVolumes({bool unmount = true}) async {
    final url = unmount ? '/api/storage/gluster/volumes/delete-all?unmount=true' : '/api/storage/gluster/volumes/delete-all?unmount=false';
    final response = await http.post(Uri.parse(url), headers: authHeaders);
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to delete all GlusterFS volumes');
    }
  }

  /// Starts a GlusterFS volume.
  static Future<void> startGlusterVolume(String name) async {
    final response = await http.post(Uri.parse('/api/storage/gluster/volumes/$name/start'), headers: authHeaders);
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to start volume $name');
    }
  }

  /// Stops a GlusterFS volume.
  static Future<void> stopGlusterVolume(String name, {bool force = false}) async {
    final url = force ? '/api/storage/gluster/volumes/$name/stop?force=true' : '/api/storage/gluster/volumes/$name/stop';
    final response = await http.post(Uri.parse(url), headers: authHeaders);
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to stop volume $name');
    }
  }

  /// Fetches self-healing & split-brain diagnostics for a volume.
  static Future<GlusterHealModel> fetchGlusterHealReport(String name) async {
    final response = await http.get(Uri.parse('/api/storage/gluster/volumes/$name/heal'), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return GlusterHealModel.fromJson(data['heal_report']);
    }
    throw Exception('Failed to fetch heal report: ${response.statusCode}');
  }

  /// Triggers a manual self-heal cycle.
  static Future<void> triggerGlusterSelfHeal(String name) async {
    final response = await http.post(Uri.parse('/api/storage/gluster/volumes/$name/heal'), headers: authHeaders);
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to trigger self-heal for $name');
    }
  }

  /// Auto-mounts volume to /var/contenedores across cluster hosts or specific target nodes.
  static Future<void> mountGlusterCluster(String name, {String mountPoint = '/var/contenedores', List<String>? targetNodes}) async {
    final payload = <String, dynamic>{'mount_point': mountPoint};
    if (targetNodes != null && targetNodes.isNotEmpty) {
      payload['target_nodes'] = targetNodes;
    }
    final response = await http.post(
      Uri.parse('/api/storage/gluster/volumes/$name/mount-cluster'),
      headers: authHeaders,
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to mount volume $name across cluster');
    }
  }

  /// Fetches cluster diagnostics for GlusterFS.
  static Future<GlusterClusterDiagnosticsModel> fetchGlusterDiagnostics() async {
    final response = await http.get(Uri.parse('/api/storage/gluster/diagnostics'), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return GlusterClusterDiagnosticsModel.fromJson(data['diagnostics']);
    }
    throw Exception('Failed to fetch Gluster diagnostics: ${response.statusCode}');
  }

  /// Fetches real-time dedicated storage network traffic and interface discovery.
  static Future<StorageNetworkReportModel> fetchStorageNetworkReport() async {
    final response = await http.get(Uri.parse('/api/storage/gluster/network'), headers: authHeaders);
    if (response.statusCode == 200) {
      return StorageNetworkReportModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch storage network report: ${response.statusCode}');
  }

  /// Fetches real-time I/O performance and FOP profiling for a volume.
  static Future<GlusterProfileReportModel> fetchGlusterVolumeProfile(String name) async {
    final response = await http.get(Uri.parse('/api/storage/gluster/volumes/$name/profile'), headers: authHeaders);
    if (response.statusCode == 200) {
      return GlusterProfileReportModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch profile for $name: ${response.statusCode}');
  }

  /// Starts volume profiling.
  static Future<void> startGlusterVolumeProfile(String name) async {
    final response = await http.post(Uri.parse('/api/storage/gluster/volumes/$name/profile/start'), headers: authHeaders);
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to start profiling on $name');
    }
  }

  /// Stops volume profiling.
  static Future<void> stopGlusterVolumeProfile(String name) async {
    final response = await http.post(Uri.parse('/api/storage/gluster/volumes/$name/profile/stop'), headers: authHeaders);
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to stop profiling on $name');
    }
  }

  /// Fetches directory path quotas for a volume.
  static Future<GlusterQuotasReportModel> fetchGlusterQuotas(String name) async {
    final response = await http.get(Uri.parse('/api/storage/gluster/volumes/$name/quotas'), headers: authHeaders);
    if (response.statusCode == 200) {
      return GlusterQuotasReportModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch quotas for $name: ${response.statusCode}');
  }

  /// Sets or updates a directory quota limit on a volume.
  static Future<void> setGlusterQuota(String name, String path, String hardLimit) async {
    final response = await http.post(
      Uri.parse('/api/storage/gluster/volumes/$name/quotas'),
      headers: authHeaders,
      body: jsonEncode({'path': path, 'hard_limit': hardLimit}),
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to set quota on $name');
    }
  }

  /// Disables quotas on a volume.
  static Future<void> disableGlusterQuota(String name) async {
    final response = await http.delete(Uri.parse('/api/storage/gluster/volumes/$name/quotas'), headers: authHeaders);
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to disable quotas on $name');
    }
  }

  /// Fetches volume snapshots.
  static Future<List<GlusterSnapshotModel>> fetchGlusterSnapshots({String? volumeName}) async {
    final url = volumeName != null && volumeName.isNotEmpty
        ? '/api/storage/gluster/snapshots?volume=$volumeName'
        : '/api/storage/gluster/snapshots';
    final response = await http.get(Uri.parse(url), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['snapshots'] is List) {
        return (data['snapshots'] as List).map((s) => GlusterSnapshotModel.fromJson(s)).toList();
      }
      return [];
    }
    throw Exception('Failed to fetch snapshots: ${response.statusCode}');
  }

  /// Creates a point-in-time snapshot.
  static Future<void> createGlusterSnapshot(String name, String volumeName, {String description = ''}) async {
    final response = await http.post(
      Uri.parse('/api/storage/gluster/snapshots'),
      headers: authHeaders,
      body: jsonEncode({'name': name, 'volume_name': volumeName, 'description': description}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to create snapshot');
    }
  }

  /// Restores a snapshot (rollback).
  static Future<void> restoreGlusterSnapshot(String name) async {
    final response = await http.post(Uri.parse('/api/storage/gluster/snapshots/$name/restore'), headers: authHeaders);
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to restore snapshot $name');
    }
  }

  /// Deletes a snapshot.
  static Future<void> deleteGlusterSnapshot(String name) async {
    final response = await http.delete(Uri.parse('/api/storage/gluster/snapshots/$name'), headers: authHeaders);
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to delete snapshot $name');
    }
  }

  /// Starts or stops volume rebalance.
  static Future<Map<String, dynamic>> rebalanceGlusterVolume(String name, {String action = 'start'}) async {
    final response = await http.post(
      Uri.parse('/api/storage/gluster/volumes/$name/rebalance?action=$action'),
      headers: authHeaders,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Failed to rebalance $name');
  }

  /// Sets or resets an advanced volume tuning option.
  static Future<void> setGlusterVolumeOption(String name, String key, String value, {bool reset = false}) async {
    final response = await http.post(
      Uri.parse('/api/storage/gluster/volumes/$name/options'),
      headers: authHeaders,
      body: jsonEncode({'key': key, 'value': value, 'reset': reset}),
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to configure option on $name');
    }
  }
}

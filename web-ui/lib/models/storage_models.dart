/// Persistent Storage, Volumes, Backups, Network Mounts, and GlusterFS models.
library;

// ── Storage & Backups Models ──────────────────────────────────────

class StorageVolumeModel {
  final String id;
  final String name;
  final String type; // "shared_pool", "docker_named", "host_bind"
  final String driver;
  final String sourcePath;
  final String targetPath;
  final String stackId;
  final String stackName;
  final String serviceName;
  final String nodeId;
  final String nodeIp;
  final String nodeHostname;
  final String nodeRole;
  final int sizeBytes;
  final String sizeFormatted;
  final bool isShared;
  final String lastScannedAt;

  StorageVolumeModel({
    required this.id,
    required this.name,
    required this.type,
    this.driver = 'local',
    required this.sourcePath,
    required this.targetPath,
    this.stackId = '',
    this.stackName = '',
    this.serviceName = '',
    this.nodeId = 'cluster',
    this.nodeIp = '',
    this.nodeHostname = '',
    this.nodeRole = '',
    this.sizeBytes = 0,
    this.sizeFormatted = '0 B',
    this.isShared = false,
    this.lastScannedAt = '',
  });

  factory StorageVolumeModel.fromJson(Map<String, dynamic> json) {
    return StorageVolumeModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'host_bind',
      driver: json['driver'] ?? 'local',
      sourcePath: json['source_path'] ?? '',
      targetPath: json['target_path'] ?? '',
      stackId: json['stack_id'] ?? '',
      stackName: json['stack_name'] ?? '',
      serviceName: json['service_name'] ?? '',
      nodeId: json['node_id'] ?? 'cluster',
      nodeIp: json['node_ip'] ?? '',
      nodeHostname: json['node_hostname'] ?? '',
      nodeRole: json['node_role'] ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      sizeFormatted: json['size_formatted'] ?? '0 B',
      isShared: json['is_shared'] == true,
      lastScannedAt: json['last_scanned_at'] ?? '',
    );
  }
}

class DirectoryEntryModel {
  final String name;
  final String path;
  final bool isDir;
  final int sizeBytes;
  final String sizeFormatted;
  final String permissions;
  final String modTime;
  final String nodeId;

  DirectoryEntryModel({
    required this.name,
    required this.path,
    required this.isDir,
    this.sizeBytes = 0,
    this.sizeFormatted = '0 B',
    this.permissions = '',
    this.modTime = '',
    this.nodeId = '',
  });

  factory DirectoryEntryModel.fromJson(Map<String, dynamic> json) {
    return DirectoryEntryModel(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      isDir: json['is_dir'] == true,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      sizeFormatted: json['size_formatted'] ?? '0 B',
      permissions: json['permissions'] ?? '',
      modTime: json['mod_time'] ?? '',
      nodeId: json['node_id'] ?? '',
    );
  }
}

class BackupModel {
  final String id;
  final String name;
  final String stackId;
  final String stackName;
  final String volumeName;
  final String sourcePath;
  final String filePath;
  final int sizeBytes;
  final String sizeFormatted;
  final String sha256;
  final String status;
  final bool isScheduled;
  final String scheduleId;
  final bool isEncrypted;
  final String encryptionAlgo;
  final String createdAt;

  BackupModel({
    required this.id,
    required this.name,
    this.stackId = '',
    this.stackName = '',
    this.volumeName = '',
    this.sourcePath = '',
    this.filePath = '',
    this.sizeBytes = 0,
    this.sizeFormatted = '0 B',
    this.sha256 = '',
    this.status = 'completed',
    this.isScheduled = false,
    this.scheduleId = '',
    this.isEncrypted = false,
    this.encryptionAlgo = '',
    this.createdAt = '',
  });

  factory BackupModel.fromJson(Map<String, dynamic> json) {
    return BackupModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      stackId: json['stack_id'] ?? '',
      stackName: json['stack_name'] ?? '',
      volumeName: json['volume_name'] ?? '',
      sourcePath: json['source_path'] ?? '',
      filePath: json['file_path'] ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      sizeFormatted: json['size_formatted'] ?? '0 B',
      sha256: json['sha256'] ?? '',
      status: json['status'] ?? 'completed',
      isScheduled: json['is_scheduled'] == true,
      scheduleId: json['schedule_id'] ?? '',
      isEncrypted: json['is_encrypted'] == true,
      encryptionAlgo: json['encryption_algo'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class BackupScheduleModel {
  final String id;
  final String name;
  final String cronExpression;
  final String targetType;
  final String targetId;
  final String targetName;
  final String destinationPath;
  final int retentionCount;
  final bool pauseContainers;
  final bool enabled;
  final String? lastRunAt;
  final String createdAt;

  final bool encrypted;
  final String? encryptionPassphrase;

  BackupScheduleModel({
    required this.id,
    required this.name,
    required this.cronExpression,
    this.targetType = 'stack',
    this.targetId = '',
    this.targetName = '',
    this.destinationPath = '',
    this.retentionCount = 7,
    this.pauseContainers = true,
    this.enabled = true,
    this.encrypted = false,
    this.encryptionPassphrase,
    this.lastRunAt,
    this.createdAt = '',
  });

  factory BackupScheduleModel.fromJson(Map<String, dynamic> json) {
    return BackupScheduleModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      cronExpression: json['cron_expression'] ?? '0 3 * * *',
      targetType: json['target_type'] ?? 'stack',
      targetId: json['target_id'] ?? '',
      targetName: json['target_name'] ?? '',
      destinationPath: json['destination_path'] ?? '',
      retentionCount: (json['retention_count'] as num?)?.toInt() ?? 7,
      pauseContainers: json['pause_containers'] != false,
      enabled: json['enabled'] != false,
      encrypted: json['encrypted'] == true,
      encryptionPassphrase: json['encryption_passphrase'],
      lastRunAt: json['last_run_at'],
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'cron_expression': cronExpression,
      'target_type': targetType,
      'target_id': targetId,
      'target_name': targetName,
      'destination_path': destinationPath,
      'retention_count': retentionCount,
      'pause_containers': pauseContainers,
      'enabled': enabled,
      'encrypted': encrypted,
      'encryption_passphrase': encryptionPassphrase,
    };
  }
}

class NodePoolHealthModel {
  final String nodeId;
  final String nodeIp;
  final String role;
  final String status;
  final String path;
  final bool isMounted;
  final bool isWritable;
  final int totalBytes;
  final int usedBytes;
  final int freeBytes;
  final double usagePercent;
  final String? error;

  NodePoolHealthModel({
    required this.nodeId,
    required this.nodeIp,
    required this.role,
    required this.status,
    required this.path,
    this.isMounted = false,
    this.isWritable = false,
    this.totalBytes = 0,
    this.usedBytes = 0,
    this.freeBytes = 0,
    this.usagePercent = 0.0,
    this.error,
  });

  factory NodePoolHealthModel.fromJson(Map<String, dynamic> json) {
    return NodePoolHealthModel(
      nodeId: json['node_id'] ?? '',
      nodeIp: json['node_ip'] ?? '',
      role: json['role'] ?? '',
      status: json['status'] ?? 'unknown',
      path: json['path'] ?? '',
      isMounted: json['is_mounted'] == true,
      isWritable: json['is_writable'] == true,
      totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
      usedBytes: (json['used_bytes'] as num?)?.toInt() ?? 0,
      freeBytes: (json['free_bytes'] as num?)?.toInt() ?? 0,
      usagePercent: (json['usage_percent'] as num?)?.toDouble() ?? 0.0,
      error: json['error'],
    );
  }
}

class PoolHealthModel {
  final String poolPath;
  final String status;
  final int totalBytes;
  final int usedBytes;
  final int freeBytes;
  final double usagePercent;
  final String totalFormatted;
  final String usedFormatted;
  final String freeFormatted;
  final List<NodePoolHealthModel> nodes;

  PoolHealthModel({
    required this.poolPath,
    required this.status,
    this.totalBytes = 0,
    this.usedBytes = 0,
    this.freeBytes = 0,
    this.usagePercent = 0.0,
    this.totalFormatted = '0 B',
    this.usedFormatted = '0 B',
    this.freeFormatted = '0 B',
    this.nodes = const [],
  });

  factory PoolHealthModel.fromJson(Map<String, dynamic> json) {
    return PoolHealthModel(
      poolPath: json['pool_path'] ?? '/var/contenedores',
      status: json['status'] ?? 'unknown',
      totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
      usedBytes: (json['used_bytes'] as num?)?.toInt() ?? 0,
      freeBytes: (json['free_bytes'] as num?)?.toInt() ?? 0,
      usagePercent: (json['usage_percent'] as num?)?.toDouble() ?? 0.0,
      totalFormatted: json['total_formatted'] ?? '0 B',
      usedFormatted: json['used_formatted'] ?? '0 B',
      freeFormatted: json['free_formatted'] ?? '0 B',
      nodes: (json['nodes'] as List<dynamic>?)
              ?.map((e) => NodePoolHealthModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class StorageMountModel {
  final String id;
  final String name;
  final String device;
  final String mountPoint;
  final String fsType;
  final String options;
  final int dump;
  final int pass;
  final String targetNode;
  final String? credentialsFile;
  final bool autoMount;
  final String status;
  final bool isActive;
  final String? errorMessage;
  final String description;
  final String createdAt;
  final String updatedAt;

  StorageMountModel({
    required this.id,
    required this.name,
    required this.device,
    required this.mountPoint,
    required this.fsType,
    this.options = '',
    this.dump = 0,
    this.pass = 0,
    this.targetNode = 'all',
    this.credentialsFile,
    this.autoMount = true,
    this.status = 'unmounted',
    this.isActive = true,
    this.errorMessage,
    this.description = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory StorageMountModel.fromJson(Map<String, dynamic> json) {
    return StorageMountModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      device: json['device'] ?? '',
      mountPoint: json['mount_point'] ?? '',
      fsType: json['fs_type'] ?? 'nfs',
      options: json['options'] ?? '',
      dump: (json['dump'] as num?)?.toInt() ?? 0,
      pass: (json['pass'] as num?)?.toInt() ?? 0,
      targetNode: json['target_node'] ?? 'all',
      credentialsFile: json['credentials_file'],
      autoMount: json['auto_mount'] != false,
      status: json['status'] ?? 'unmounted',
      isActive: json['is_active'] != false,
      errorMessage: json['error_message'],
      description: json['description'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  factory StorageMountModel.empty() {
    return StorageMountModel(
      id: '',
      name: '',
      device: '',
      mountPoint: '',
      fsType: '',
    );
  }
}

class TestMountResultModel {
  final bool success;
  final int latencyMs;
  final bool isWritable;
  final int totalBytes;
  final int freeBytes;
  final String? errorMessage;
  final String? output;

  TestMountResultModel({
    required this.success,
    this.latencyMs = 0,
    this.isWritable = false,
    this.totalBytes = 0,
    this.freeBytes = 0,
    this.errorMessage,
    this.output,
  });

  factory TestMountResultModel.fromJson(Map<String, dynamic> json) {
    return TestMountResultModel(
      success: json['success'] == true,
      latencyMs: (json['latency_ms'] as num?)?.toInt() ?? 0,
      isWritable: json['is_writable'] == true,
      totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
      freeBytes: (json['free_bytes'] as num?)?.toInt() ?? 0,
      errorMessage: json['error_message'],
      output: json['output'],
    );
  }
}

class GlusterPeerModel {
  final String hostname;
  final String uuid;
  final String state;
  final bool connected;
  final bool isLocal;
  final int pingMs;
  final String checkedAt;

  GlusterPeerModel({
    required this.hostname,
    this.uuid = '',
    this.state = 'Peer in Cluster',
    this.connected = true,
    this.isLocal = false,
    this.pingMs = 0,
    this.checkedAt = '',
  });

  factory GlusterPeerModel.fromJson(Map<String, dynamic> json) {
    return GlusterPeerModel(
      hostname: json['hostname'] ?? '',
      uuid: json['uuid'] ?? '',
      state: json['state'] ?? 'Peer in Cluster',
      connected: json['connected'] != false,
      isLocal: json['is_local'] == true,
      pingMs: (json['ping_ms'] as num?)?.toInt() ?? 0,
      checkedAt: json['checked_at'] ?? '',
    );
  }
}

class GlusterBrickModel {
  final String path;
  final String host;
  final String fullSpec;
  final int port;
  final bool online;
  final int pid;
  final int sizeTotal;
  final int sizeFree;
  final bool isArbiter;

  GlusterBrickModel({
    required this.path,
    required this.host,
    required this.fullSpec,
    this.port = 49152,
    this.online = true,
    this.pid = 0,
    this.sizeTotal = 0,
    this.sizeFree = 0,
    this.isArbiter = false,
  });

  factory GlusterBrickModel.fromJson(Map<String, dynamic> json) {
    return GlusterBrickModel(
      path: json['path'] ?? '',
      host: json['host'] ?? '',
      fullSpec: json['full_spec'] ?? '',
      port: (json['port'] as num?)?.toInt() ?? 49152,
      online: json['online'] != false,
      pid: (json['pid'] as num?)?.toInt() ?? 0,
      sizeTotal: (json['size_total'] as num?)?.toInt() ?? 0,
      sizeFree: (json['size_free'] as num?)?.toInt() ?? 0,
      isArbiter: json['is_arbiter'] == true,
    );
  }
}

class GlusterVolumeModel {
  final String name;
  final String uuid;
  final String type;
  final String status;
  final int replicaCount;
  final int arbiterCount;
  final int numBricks;
  final String transport;
  final List<GlusterBrickModel> bricks;
  final Map<String, String> options;
  final bool isMounted;
  final String mountPoint;
  final int capacityTotal;
  final int capacityUsed;
  final int capacityFree;
  final double capacityPercent;
  final int pendingHeals;
  final String createdAt;

  GlusterVolumeModel({
    required this.name,
    this.uuid = '',
    this.type = 'Replicate',
    this.status = 'Started',
    this.replicaCount = 3,
    this.arbiterCount = 0,
    this.numBricks = 3,
    this.transport = 'tcp',
    this.bricks = const [],
    this.options = const {},
    this.isMounted = true,
    this.mountPoint = '/var/contenedores',
    this.capacityTotal = 0,
    this.capacityUsed = 0,
    this.capacityFree = 0,
    this.capacityPercent = 0.0,
    this.pendingHeals = 0,
    this.createdAt = '',
  });

  factory GlusterVolumeModel.fromJson(Map<String, dynamic> json) {
    List<GlusterBrickModel> brickList = [];
    if (json['bricks'] is List) {
      brickList = (json['bricks'] as List)
          .map((b) => GlusterBrickModel.fromJson(b as Map<String, dynamic>))
          .toList();
    }

    Map<String, String> opts = {};
    if (json['options'] is Map) {
      json['options'].forEach((k, v) => opts[k.toString()] = v.toString());
    }

    return GlusterVolumeModel(
      name: json['name'] ?? '',
      uuid: json['uuid'] ?? '',
      type: json['type'] ?? 'Replicate',
      status: json['status'] ?? 'Started',
      replicaCount: (json['replica_count'] as num?)?.toInt() ?? 3,
      arbiterCount: (json['arbiter_count'] as num?)?.toInt() ?? 0,
      numBricks: (json['num_bricks'] as num?)?.toInt() ?? brickList.length,
      transport: json['transport'] ?? 'tcp',
      bricks: brickList,
      options: opts,
      isMounted: json['is_mounted'] == true,
      mountPoint: json['mount_point'] ?? '/var/contenedores',
      capacityTotal: (json['capacity_total'] as num?)?.toInt() ?? 0,
      capacityUsed: (json['capacity_used'] as num?)?.toInt() ?? 0,
      capacityFree: (json['capacity_free'] as num?)?.toInt() ?? 0,
      capacityPercent: (json['capacity_percent'] as num?)?.toDouble() ?? 0.0,
      pendingHeals: (json['pending_heals'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class GlusterHealModel {
  final String volumeName;
  final int totalPending;
  final bool inSplitBrain;
  final int splitBrainCount;
  final List<GlusterBrickHealModel> bricksHealInfo;
  final String lastHealCheck;
  final String statusSummary;

  GlusterHealModel({
    required this.volumeName,
    this.totalPending = 0,
    this.inSplitBrain = false,
    this.splitBrainCount = 0,
    this.bricksHealInfo = const [],
    this.lastHealCheck = '',
    this.statusSummary = 'Healthy — 0 pending entries',
  });

  factory GlusterHealModel.fromJson(Map<String, dynamic> json) {
    List<GlusterBrickHealModel> bricks = [];
    if (json['bricks_heal_info'] is List) {
      bricks = (json['bricks_heal_info'] as List)
          .map((b) => GlusterBrickHealModel.fromJson(b as Map<String, dynamic>))
          .toList();
    }

    return GlusterHealModel(
      volumeName: json['volume_name'] ?? '',
      totalPending: (json['total_pending'] as num?)?.toInt() ?? 0,
      inSplitBrain: json['in_split_brain'] == true,
      splitBrainCount: (json['split_brain_count'] as num?)?.toInt() ?? 0,
      bricksHealInfo: bricks,
      lastHealCheck: json['last_heal_check'] ?? '',
      statusSummary: json['status_summary'] ?? '',
    );
  }
}

class GlusterBrickHealModel {
  final String brickSpec;
  final String status;
  final int numberOfEntries;
  final List<String> pendingFiles;

  GlusterBrickHealModel({
    required this.brickSpec,
    this.status = 'Connected',
    this.numberOfEntries = 0,
    this.pendingFiles = const [],
  });

  factory GlusterBrickHealModel.fromJson(Map<String, dynamic> json) {
    List<String> files = [];
    if (json['pending_files'] is List) {
      files = (json['pending_files'] as List).map((f) => f.toString()).toList();
    }
    return GlusterBrickHealModel(
      brickSpec: json['brick_spec'] ?? '',
      status: json['status'] ?? 'Connected',
      numberOfEntries: (json['number_of_entries'] as num?)?.toInt() ?? 0,
      pendingFiles: files,
    );
  }
}

class GlusterClusterDiagnosticsModel {
  final bool installed;
  final bool daemonRunning;
  final String version;
  final int peersCount;
  final int volumesCount;
  final int onlineVolumes;
  final bool quorumHealthy;
  final int healthScore;
  final List<String> issues;
  final List<GlusterPeerModel> peers;
  final String checkedAt;

  GlusterClusterDiagnosticsModel({
    this.installed = true,
    this.daemonRunning = true,
    this.version = '',
    this.peersCount = 3,
    this.volumesCount = 1,
    this.onlineVolumes = 1,
    this.quorumHealthy = true,
    this.healthScore = 100,
    this.issues = const [],
    this.peers = const [],
    this.checkedAt = '',
  });

  factory GlusterClusterDiagnosticsModel.fromJson(Map<String, dynamic> json) {
    List<String> issueList = [];
    if (json['issues'] is List) {
      issueList = (json['issues'] as List).map((i) => i.toString()).toList();
    }
    List<GlusterPeerModel> peerList = [];
    if (json['peers'] is List) {
      peerList = (json['peers'] as List)
          .map((p) => GlusterPeerModel.fromJson(p as Map<String, dynamic>))
          .toList();
    }
    return GlusterClusterDiagnosticsModel(
      installed: json['installed'] != false,
      daemonRunning: json['daemon_running'] != false,
      version: json['version'] ?? '',
      peersCount: (json['peers_count'] as num?)?.toInt() ?? 0,
      volumesCount: (json['volumes_count'] as num?)?.toInt() ?? 0,
      onlineVolumes: (json['online_volumes'] as num?)?.toInt() ?? 0,
      quorumHealthy: json['quorum_healthy'] != false,
      healthScore: (json['health_score'] as num?)?.toInt() ?? 100,
      issues: issueList,
      peers: peerList,
      checkedAt: json['checked_at'] ?? '',
    );
  }
}

// -----------------------------------------------------------------------------
// Cockpit-Storaged & Storage Network Models
// -----------------------------------------------------------------------------

class StorageNetworkReportModel {
  final String dedicatedSubnet;
  final String corednsSuffix;
  final List<NodeStorageNetworkModel> nodes;
  final double totalRxRateMBs;
  final double totalTxRateMBs;
  final bool activeTraffic;

  StorageNetworkReportModel({
    required this.dedicatedSubnet,
    required this.corednsSuffix,
    required this.nodes,
    required this.totalRxRateMBs,
    required this.totalTxRateMBs,
    required this.activeTraffic,
  });

  factory StorageNetworkReportModel.fromJson(Map<String, dynamic> json) {
    var nodesList = <NodeStorageNetworkModel>[];
    if (json['nodes'] is List) {
      nodesList = (json['nodes'] as List).map((n) => NodeStorageNetworkModel.fromJson(n)).toList();
    }
    return StorageNetworkReportModel(
      dedicatedSubnet: json['dedicated_subnet'] ?? '10.10.100.0/24',
      corednsSuffix: json['coredns_suffix'] ?? '.storage.gbnt.local',
      nodes: nodesList,
      totalRxRateMBs: (json['total_rx_rate_mbs'] as num?)?.toDouble() ?? 0.0,
      totalTxRateMBs: (json['total_tx_rate_mbs'] as num?)?.toDouble() ?? 0.0,
      activeTraffic: json['active_traffic'] ?? false,
    );
  }

  factory StorageNetworkReportModel.empty() {
    return StorageNetworkReportModel(
      dedicatedSubnet: '10.10.100.0/24',
      corednsSuffix: '.storage.gbnt.local',
      nodes: [],
      totalRxRateMBs: 0.0,
      totalTxRateMBs: 0.0,
      activeTraffic: false,
    );
  }
}

class NodeStorageNetworkModel {
  final String nodeId;
  final String nodeRole;
  final String hostIp;
  final String storageIp;
  final String storageDns;
  final String storageNic;
  final List<StorageNetworkInterfaceModel> interfaces;
  final bool isOnline;

  NodeStorageNetworkModel({
    required this.nodeId,
    required this.nodeRole,
    required this.hostIp,
    required this.storageIp,
    required this.storageDns,
    required this.storageNic,
    required this.interfaces,
    required this.isOnline,
  });

  factory NodeStorageNetworkModel.fromJson(Map<String, dynamic> json) {
    var ifaces = <StorageNetworkInterfaceModel>[];
    if (json['interfaces'] is List) {
      ifaces = (json['interfaces'] as List).map((i) => StorageNetworkInterfaceModel.fromJson(i)).toList();
    }
    return NodeStorageNetworkModel(
      nodeId: json['node_id'] ?? '',
      nodeRole: json['node_role'] ?? 'worker',
      hostIp: json['host_ip'] ?? '',
      storageIp: json['storage_ip'] ?? '',
      storageDns: json['storage_dns'] ?? '',
      storageNic: json['storage_nic'] ?? 'enp0s2',
      interfaces: ifaces,
      isOnline: json['is_online'] ?? true,
    );
  }
}

class StorageNetworkInterfaceModel {
  final String name;
  final List<String> ipAddresses;
  final String mac;
  final int mtu;
  final bool isUp;
  final bool isStorage;
  final double rxRateMBs;
  final double txRateMBs;
  final int rxBytes;
  final int txBytes;

  StorageNetworkInterfaceModel({
    required this.name,
    required this.ipAddresses,
    required this.mac,
    required this.mtu,
    required this.isUp,
    required this.isStorage,
    required this.rxRateMBs,
    required this.txRateMBs,
    required this.rxBytes,
    required this.txBytes,
  });

  factory StorageNetworkInterfaceModel.fromJson(Map<String, dynamic> json) {
    var ips = <String>[];
    if (json['ip_addresses'] is List) {
      ips = (json['ip_addresses'] as List).map((e) => e.toString()).toList();
    }
    return StorageNetworkInterfaceModel(
      name: json['name'] ?? '',
      ipAddresses: ips,
      mac: json['mac'] ?? '',
      mtu: json['mtu'] ?? 1500,
      isUp: json['is_up'] ?? false,
      isStorage: json['is_storage'] ?? false,
      rxRateMBs: (json['rx_rate_mbs'] as num?)?.toDouble() ?? 0.0,
      txRateMBs: (json['tx_rate_mbs'] as num?)?.toDouble() ?? 0.0,
      rxBytes: json['rx_bytes'] ?? 0,
      txBytes: json['tx_bytes'] ?? 0,
    );
  }
}

class GlusterProfileReportModel {
  final String volumeName;
  final bool isProfiling;
  final int totalIOPS;
  final double totalReadMBs;
  final double totalWriteMBs;
  final double avgLatencyMs;
  final List<ProfileFopModel> topOperations;
  final List<BlockSizeModel> blockSizeProfile;

  GlusterProfileReportModel({
    required this.volumeName,
    required this.isProfiling,
    required this.totalIOPS,
    required this.totalReadMBs,
    required this.totalWriteMBs,
    required this.avgLatencyMs,
    required this.topOperations,
    required this.blockSizeProfile,
  });

  factory GlusterProfileReportModel.fromJson(Map<String, dynamic> json) {
    var fops = <ProfileFopModel>[];
    if (json['top_operations'] is List) {
      fops = (json['top_operations'] as List).map((f) => ProfileFopModel.fromJson(f)).toList();
    }
    var blocks = <BlockSizeModel>[];
    if (json['block_size_profile'] is List) {
      blocks = (json['block_size_profile'] as List).map((b) => BlockSizeModel.fromJson(b)).toList();
    }
    return GlusterProfileReportModel(
      volumeName: json['volume_name'] ?? '',
      isProfiling: json['is_profiling'] ?? false,
      totalIOPS: json['total_iops'] ?? 0,
      totalReadMBs: (json['total_read_mbs'] as num?)?.toDouble() ?? 0.0,
      totalWriteMBs: (json['total_write_mbs'] as num?)?.toDouble() ?? 0.0,
      avgLatencyMs: (json['avg_latency_ms'] as num?)?.toDouble() ?? 0.0,
      topOperations: fops,
      blockSizeProfile: blocks,
    );
  }

  factory GlusterProfileReportModel.empty(String name) {
    return GlusterProfileReportModel(
      volumeName: name,
      isProfiling: false,
      totalIOPS: 0,
      totalReadMBs: 0.0,
      totalWriteMBs: 0.0,
      avgLatencyMs: 0.0,
      topOperations: [],
      blockSizeProfile: [],
    );
  }
}

class ProfileFopModel {
  final String operation;
  final int hits;
  final double percentage;
  final double avgLatencyUs;
  final double maxLatencyUs;

  ProfileFopModel({
    required this.operation,
    required this.hits,
    required this.percentage,
    required this.avgLatencyUs,
    required this.maxLatencyUs,
  });

  factory ProfileFopModel.fromJson(Map<String, dynamic> json) {
    return ProfileFopModel(
      operation: json['operation'] ?? '',
      hits: json['hits'] ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      avgLatencyUs: (json['avg_latency_us'] as num?)?.toDouble() ?? 0.0,
      maxLatencyUs: (json['max_latency_us'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BlockSizeModel {
  final String range;
  final int readHits;
  final int writeHits;
  final double percentage;

  BlockSizeModel({
    required this.range,
    required this.readHits,
    required this.writeHits,
    required this.percentage,
  });

  factory BlockSizeModel.fromJson(Map<String, dynamic> json) {
    return BlockSizeModel(
      range: json['range'] ?? '',
      readHits: json['read_hits'] ?? 0,
      writeHits: json['write_hits'] ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class GlusterQuotasReportModel {
  final String volumeName;
  final bool quotaEnabled;
  final List<GlusterQuotaModel> quotas;

  GlusterQuotasReportModel({
    required this.volumeName,
    required this.quotaEnabled,
    required this.quotas,
  });

  factory GlusterQuotasReportModel.fromJson(Map<String, dynamic> json) {
    var list = <GlusterQuotaModel>[];
    if (json['quotas'] is List) {
      list = (json['quotas'] as List).map((q) => GlusterQuotaModel.fromJson(q)).toList();
    }
    return GlusterQuotasReportModel(
      volumeName: json['volume_name'] ?? '',
      quotaEnabled: json['quota_enabled'] ?? true,
      quotas: list,
    );
  }

  factory GlusterQuotasReportModel.empty(String name) {
    return GlusterQuotasReportModel(volumeName: name, quotaEnabled: false, quotas: []);
  }
}

class GlusterQuotaModel {
  final String id;
  final String volumeName;
  final String path;
  final String hardLimit;
  final String softLimit;
  final double usedMB;
  final double totalMB;
  final double percent;

  GlusterQuotaModel({
    required this.id,
    required this.volumeName,
    required this.path,
    required this.hardLimit,
    required this.softLimit,
    required this.usedMB,
    required this.totalMB,
    required this.percent,
  });

  factory GlusterQuotaModel.fromJson(Map<String, dynamic> json) {
    return GlusterQuotaModel(
      id: json['id'] ?? '',
      volumeName: json['volume_name'] ?? '',
      path: json['path'] ?? '/',
      hardLimit: json['hard_limit'] ?? 'Unlimited',
      softLimit: json['soft_limit'] ?? '80%',
      usedMB: (json['used_mb'] as num?)?.toDouble() ?? 0.0,
      totalMB: (json['total_mb'] as num?)?.toDouble() ?? 0.0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class GlusterSnapshotModel {
  final String id;
  final String name;
  final String volumeName;
  final String status;
  final String description;
  final String createdAt;

  GlusterSnapshotModel({
    required this.id,
    required this.name,
    required this.volumeName,
    required this.status,
    required this.description,
    required this.createdAt,
  });

  factory GlusterSnapshotModel.fromJson(Map<String, dynamic> json) {
    return GlusterSnapshotModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      volumeName: json['volume_name'] ?? '',
      status: json['status'] ?? 'Active',
      description: json['description'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}






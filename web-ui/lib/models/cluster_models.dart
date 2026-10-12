/// Cluster, Node, Stack, Service, Task, and Deployment models.
library;

import 'auth_security_models.dart';

class Node {
  final String id;
  final String ip;
  final String role;
  final String status;
  final Map<String, dynamic> labels;
  final String caddyStatus;
  final String caddyfile;
  final String createdAt;
  final String updatedAt;

  final double cpuPercent;
  final int memUsedBytes;
  final int memTotalBytes;
  final double memPercent;
  final int diskUsedBytes;
  final int diskTotalBytes;
  final int diskFreeBytes;
  final double diskPercent;
  final double netBps;

  final bool authMismatch;

  Node({
    required this.id,
    required this.ip,
    required this.role,
    required this.status,
    this.labels = const {},
    this.caddyStatus = '',
    this.caddyfile = '',
    this.authMismatch = false,
    this.createdAt = '',
    this.updatedAt = '',
    this.cpuPercent = 0.0,
    this.memUsedBytes = 0,
    this.memTotalBytes = 0,
    this.memPercent = 0.0,
    this.diskUsedBytes = 0,
    this.diskTotalBytes = 0,
    this.diskFreeBytes = 0,
    this.diskPercent = 0.0,
    this.netBps = 0.0,
  });

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      id: json['id'] ?? '',
      ip: json['ip'] ?? '',
      role: json['role'] ?? '',
      status: json['status'] ?? '',
      labels: json['labels'] ?? {},
      caddyStatus: json['caddy_status'] ?? '',
      caddyfile: json['caddyfile'] ?? '',
      authMismatch: json['auth_mismatch'] == true,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0.0,
      memUsedBytes: (json['mem_used_bytes'] as num?)?.toInt() ?? 0,
      memTotalBytes: (json['mem_total_bytes'] as num?)?.toInt() ?? 0,
      memPercent: (json['mem_percent'] as num?)?.toDouble() ?? 0.0,
      diskUsedBytes: (json['disk_used_bytes'] as num?)?.toInt() ?? 0,
      diskTotalBytes: (json['disk_total_bytes'] as num?)?.toInt() ?? 0,
      diskFreeBytes: (json['disk_free_bytes'] as num?)?.toInt() ?? 0,
      diskPercent: (json['disk_percent'] as num?)?.toDouble() ?? 0.0,
      netBps: (json['net_bps'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class StackModel {
  final String id;
  final String name;
  final String rawComposeFile;
  final String nodeId;
  final String createdAt;

  StackModel({
    required this.id,
    required this.name,
    this.rawComposeFile = '',
    this.nodeId = '',
    this.createdAt = '',
  });

  factory StackModel.fromJson(Map<String, dynamic> json) {
    return StackModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      rawComposeFile: json['raw_compose_file'] ?? '',
      nodeId: json['node_id'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  bool hasAutoscaling(List<Service> services) {
    return services.any((s) => s.stackId == id && s.isAutoscalingEnabled);
  }

  Service? primaryAutoscaleService(List<Service> services) {
    final list = services.where((s) => s.stackId == id && s.isAutoscalingEnabled).toList();
    if (list.isEmpty) return null;
    // Prefer GPU service if any, else first
    return list.firstWhere((s) => s.autoscaleMetric == 'gpu', orElse: () => list.first);
  }
}

class Service {
  final String id;
  final String stackId;
  final String name;
  final String image;
  final int desiredReplicas;
  final List<String> constraints;
  final List<String> ports;
  final String cpuLimit;
  final String memoryLimit;
  final String cpuReservation;
  final String memoryReservation;

  Service({
    required this.id,
    required this.stackId,
    required this.name,
    required this.image,
    this.desiredReplicas = 1,
    this.constraints = const [],
    this.ports = const [],
    this.cpuLimit = '',
    this.memoryLimit = '',
    this.cpuReservation = '',
    this.memoryReservation = '',
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'] ?? '',
      stackId: json['stack_id'] ?? '',
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      desiredReplicas: json['desired_replicas'] ?? 1,
      constraints: (json['constraints'] as List?)?.map((e) => e.toString()).toList() ?? [],
      ports: (json['ports'] as List?)?.map((e) => e.toString()).toList() ?? [],
      cpuLimit: json['cpu_limit'] ?? '',
      memoryLimit: json['memory_limit'] ?? '',
      cpuReservation: json['cpu_reservation'] ?? '',
      memoryReservation: json['memory_reservation'] ?? '',
    );
  }

  bool get isAutoscalingEnabled {
    for (final c in constraints) {
      final lower = c.toLowerCase().trim();
      if (lower == 'gbnt.autoscaling.enable=true' ||
          lower == 'gbnt.autoscaling.enable: true' ||
          lower == 'gbnt.autoscaling.enable=1' ||
          lower == 'gbnt.autoscaling.enable=yes') {
        return true;
      }
    }
    return false;
  }

  String get autoscaleScope {
    // Check single-host affinity overrides first
    for (final c in constraints) {
      final lower = c.toLowerCase().trim();
      if (lower.contains('gbnt.placement.strategy=single-host') ||
          lower.contains('node.hostname ==') ||
          lower.contains('gbnt.node.hostname ==')) {
        return 'host';
      }
    }
    for (final c in constraints) {
      final lower = c.toLowerCase().trim();
      if (lower.startsWith('gbnt.autoscaling.scope=')) {
        final val = lower.split('=').last.trim();
        if (val == 'cluster' || val == 'all' || val == 'multi-host') {
          return 'cluster';
        }
        return 'host';
      }
      if (lower.contains('gbnt.placement.strategy=spread') ||
          lower.contains('gbnt.placement.strategy=multi-host')) {
        return 'cluster';
      }
    }
    return 'host';
  }

  String get autoscaleMetric {
    for (final c in constraints) {
      final lower = c.toLowerCase().trim();
      if (lower.startsWith('gbnt.autoscaling.metric=')) {
        final val = lower.split('=').last.trim();
        if (val.contains('gpu') || val.contains('cuda') || val.contains('nvidia')) {
          return 'gpu';
        }
        return 'cpu';
      }
      if (lower.contains('gpu') || lower.contains('nvidia') || lower.contains('cuda')) {
        return 'gpu';
      }
    }
    return 'cpu';
  }

  double get autoscaleTarget {
    for (final c in constraints) {
      final lower = c.toLowerCase().trim();
      if (lower.startsWith('gbnt.autoscaling.target=')) {
        final val = double.tryParse(lower.split('=').last.trim());
        if (val != null && val > 0) return val;
      }
    }
    return 80.0;
  }

  int get autoscaleMin {
    for (final c in constraints) {
      final lower = c.toLowerCase().trim();
      if (lower.startsWith('gbnt.autoscaling.min=')) {
        final val = int.tryParse(lower.split('=').last.trim());
        if (val != null && val >= 1) return val;
      }
    }
    return 1;
  }

  int get autoscaleMax {
    for (final c in constraints) {
      final lower = c.toLowerCase().trim();
      if (lower.startsWith('gbnt.autoscaling.max=')) {
        final val = int.tryParse(lower.split('=').last.trim());
        if (val != null && val >= 1) return val;
      }
    }
    return 5;
  }

  String get autoscaleCooldown {
    for (final c in constraints) {
      final lower = c.toLowerCase().trim();
      if (lower.startsWith('gbnt.autoscaling.cooldown=')) {
        return lower.split('=').last.trim();
      }
    }
    return '60s';
  }
}

class Task {
  final String id;
  final String serviceId;
  final String nodeId;
  final String status;
  final String containerName;
  final String containerIp;
  final String cpuLimit;
  final String memoryLimit;
  final String cpuReservation;
  final String memoryReservation;
  final double cpuPercent;
  final int memUsedBytes;
  final String error;
  final String createdAt;

  Task({
    required this.id,
    required this.serviceId,
    required this.nodeId,
    required this.status,
    this.containerName = '',
    this.containerIp = '',
    this.cpuLimit = '',
    this.memoryLimit = '',
    this.cpuReservation = '',
    this.memoryReservation = '',
    this.cpuPercent = 0.0,
    this.memUsedBytes = 0,
    this.error = '',
    this.createdAt = '',
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] ?? '',
      serviceId: json['service_id'] ?? '',
      nodeId: json['node_id'] ?? '',
      status: json['status'] ?? '',
      containerName: json['container_name'] ?? '',
      containerIp: json['container_ip'] ?? '',
      cpuLimit: json['cpu_limit'] ?? '',
      memoryLimit: json['memory_limit'] ?? '',
      cpuReservation: json['cpu_reservation'] ?? '',
      memoryReservation: json['memory_reservation'] ?? '',
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0.0,
      memUsedBytes: (json['mem_used_bytes'] as num?)?.toInt() ?? 0,
      error: json['error'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class DnsRecord {
  final String ip;
  final String hostname;

  DnsRecord({
    required this.ip,
    required this.hostname,
  });

  factory DnsRecord.fromJson(Map<String, dynamic> json) {
    return DnsRecord(
      ip: json['ip'] ?? '',
      hostname: json['hostname'] ?? '',
    );
  }
}

class DashboardState {
  final List<Node> nodes;
  final List<StackModel> stacks;
  final List<Service> services;
  final List<Task> tasks;
  final List<DnsRecord> dnsRecords;
  final bool monitorRunning;
  final String caddyStatus;
  final String caddyfile;
  final String version;
  final String clusterDomain;
  final String clusterJoinToken;
  final String activeApiToken;
  final String managerIp;
  final bool updateAvailable;
  final String latestVersion;
  final String releaseNotes;
  final String releaseUrl;
  final String activeSreProfile;
  final UserSession? currentUser;

  DashboardState({
    this.nodes = const [],
    this.stacks = const [],
    this.services = const [],
    this.tasks = const [],
    this.dnsRecords = const [],
    this.monitorRunning = false,
    this.caddyStatus = 'not running',
    this.caddyfile = '',
    this.activeSreProfile = 'cloud-native',
    this.version = 'dev',
    this.clusterDomain = 'gbnt.local',
    this.clusterJoinToken = '',
    this.activeApiToken = '',
    this.managerIp = '',
    this.updateAvailable = false,
    this.latestVersion = '',
    this.releaseNotes = '',
    this.releaseUrl = '',
    this.currentUser,
  });

  factory DashboardState.fromJson(Map<String, dynamic> json) {
    return DashboardState(
      nodes: (json['nodes'] as List? ?? [])
          .map((e) => Node.fromJson(e))
          .toList(),
      stacks: (json['stacks'] as List? ?? [])
          .map((e) => StackModel.fromJson(e))
          .toList(),
      services: (json['services'] as List? ?? [])
          .map((e) => Service.fromJson(e))
          .toList(),
      tasks: (json['tasks'] as List? ?? [])
          .map((e) => Task.fromJson(e))
          .toList(),
      dnsRecords: (json['dns_records'] as List? ?? [])
          .map((e) => DnsRecord.fromJson(e))
          .toList(),
      monitorRunning: json['monitor_running'] ?? false,
      caddyStatus: json['caddy_status'] ?? 'not running',
      caddyfile: json['caddyfile'] ?? '',
      activeSreProfile: json['active_sre_profile'] ?? 'cloud-native',
      version: json['version'] ?? 'dev',
      clusterDomain: json['cluster_domain'] ?? 'gbnt.local',
      clusterJoinToken: json['cluster_join_token'] ?? '',
      activeApiToken: json['active_api_token'] ?? '',
      managerIp: json['manager_ip'] ?? '',
      updateAvailable: json['update_available'] ?? false,
      latestVersion: json['latest_version'] ?? '',
      releaseNotes: json['release_notes'] ?? '',
      releaseUrl: json['release_url'] ?? '',
      currentUser: json['current_user'] != null ? UserSession.fromJson(json['current_user']) : null,
    );
  }
}

class AdoptionStatsModel {
  final int totalDownloads;
  final Map<String, int> downloadsByOs;
  final int totalReleases;
  final String latestReleaseTag;
  final String latestReleaseDate;
  final int githubStars;
  final int githubForks;
  final int githubWatchers;
  final int githubOpenIssues;
  final List<ReleaseStatsModel> recentReleases;
  final String dataSource;
  final String privacyPolicy;
  final bool telemetryEnabled;
  final String documentationUrl;
  final String checkedAt;

  AdoptionStatsModel({
    this.totalDownloads = 0,
    this.downloadsByOs = const {},
    this.totalReleases = 0,
    this.latestReleaseTag = '',
    this.latestReleaseDate = '',
    this.githubStars = 0,
    this.githubForks = 0,
    this.githubWatchers = 0,
    this.githubOpenIssues = 0,
    this.recentReleases = const [],
    this.dataSource = '',
    this.privacyPolicy = '',
    this.telemetryEnabled = true,
    this.documentationUrl = '',
    this.checkedAt = '',
  });

  factory AdoptionStatsModel.fromJson(Map<String, dynamic> json) {
    Map<String, int> osMap = {};
    if (json['downloads_by_os'] is Map) {
      json['downloads_by_os'].forEach((k, v) {
        osMap[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }

    List<ReleaseStatsModel> releases = [];
    if (json['recent_releases'] is List) {
      releases = (json['recent_releases'] as List)
          .map((r) => ReleaseStatsModel.fromJson(r as Map<String, dynamic>))
          .toList();
    }

    return AdoptionStatsModel(
      totalDownloads: (json['total_downloads'] as num?)?.toInt() ?? 0,
      downloadsByOs: osMap,
      totalReleases: (json['total_releases'] as num?)?.toInt() ?? 0,
      latestReleaseTag: json['latest_release_tag'] ?? '',
      latestReleaseDate: json['latest_release_date'] ?? '',
      githubStars: (json['github_stars'] as num?)?.toInt() ?? 0,
      githubForks: (json['github_forks'] as num?)?.toInt() ?? 0,
      githubWatchers: (json['github_watchers'] as num?)?.toInt() ?? 0,
      githubOpenIssues: (json['github_open_issues'] as num?)?.toInt() ?? 0,
      recentReleases: releases,
      dataSource: json['data_source'] ?? '',
      privacyPolicy: json['privacy_policy'] ?? '',
      telemetryEnabled: json['telemetry_enabled'] != false,
      documentationUrl: json['documentation_url'] ?? '',
      checkedAt: json['checked_at'] ?? '',
    );
  }
}

class ReleaseStatsModel {
  final String tagName;
  final String publishedAt;
  final int downloads;
  final String htmlUrl;

  ReleaseStatsModel({
    required this.tagName,
    this.publishedAt = '',
    this.downloads = 0,
    this.htmlUrl = '',
  });

  factory ReleaseStatsModel.fromJson(Map<String, dynamic> json) {
    return ReleaseStatsModel(
      tagName: json['tag_name'] ?? '',
      publishedAt: json['published_at'] ?? '',
      downloads: (json['downloads'] as num?)?.toInt() ?? 0,
      htmlUrl: json['html_url'] ?? '',
    );
  }
}

/// Information and commands for joining a worker node into the cluster
class NodeJoinInfo {
  final String managerIp;
  final String managerHttp;
  final String joinToken;
  final String apiToken;
  final String managerPublicKey;
  final String oneLinerCmd;
  final String dockerCmd;
  final String cliCmd;
  final String cloudInitYaml;

  NodeJoinInfo({
    this.managerIp = '',
    this.managerHttp = '',
    this.joinToken = '',
    this.apiToken = '',
    this.managerPublicKey = '',
    this.oneLinerCmd = '',
    this.dockerCmd = '',
    this.cliCmd = '',
    this.cloudInitYaml = '',
  });

  factory NodeJoinInfo.fromJson(Map<String, dynamic> json) {
    return NodeJoinInfo(
      managerIp: json['manager_ip'] ?? '',
      managerHttp: json['manager_http'] ?? '',
      joinToken: json['join_token'] ?? '',
      apiToken: json['api_token'] ?? '',
      managerPublicKey: json['manager_public_key'] ?? '',
      oneLinerCmd: json['one_liner_cmd'] ?? '',
      dockerCmd: json['docker_cmd'] ?? '',
      cliCmd: json['cli_cmd'] ?? '',
      cloudInitYaml: json['cloud_init_yaml'] ?? '',
    );
  }
}

/// A step log entry generated during SSH node provisioning
class ProvisionStepLog {
  final String step;
  final String message;
  final String status; // "ok", "warn", "error", "running"

  ProvisionStepLog({required this.step, required this.message, required this.status});

  factory ProvisionStepLog.fromJson(Map<String, dynamic> json) {
    return ProvisionStepLog(
      step: json['step'] ?? '',
      message: json['message'] ?? '',
      status: json['status'] ?? 'ok',
    );
  }
}

/// Result returned from remote SSH node provisioning
class NodeProvisionResult {
  final bool success;
  final String message;
  final String? error;
  final List<ProvisionStepLog> logs;
  final Node? node;

  NodeProvisionResult({
    required this.success,
    required this.message,
    this.error,
    this.logs = const [],
    this.node,
  });
}

class ServerStackFileModel {
  final String path;
  final String filename;
  final String directory;
  final int size;
  final String modifiedAt;
  final String inferredName;
  final bool isExample;
  final int services;

  ServerStackFileModel({
    required this.path,
    required this.filename,
    required this.directory,
    required this.size,
    required this.modifiedAt,
    required this.inferredName,
    required this.isExample,
    required this.services,
  });

  factory ServerStackFileModel.fromJson(Map<String, dynamic> json) {
    return ServerStackFileModel(
      path: json['path'] ?? '',
      filename: json['filename'] ?? '',
      directory: json['directory'] ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      modifiedAt: json['modified_at'] ?? '',
      inferredName: json['inferred_name'] ?? '',
      isExample: json['is_example'] == true,
      services: (json['services'] as num?)?.toInt() ?? 0,
    );
  }
}

class POCExampleModel {
  final String id;
  final String name;
  final String category;
  final String description;
  final String filename;
  final String defaultStack;
  final List<String> services;
  final String composeRaw;
  final String icon;
  final List<String> tags;

  POCExampleModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.filename,
    required this.defaultStack,
    required this.services,
    required this.composeRaw,
    required this.icon,
    required this.tags,
  });

  factory POCExampleModel.fromJson(Map<String, dynamic> json) {
    return POCExampleModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      filename: json['filename'] ?? '',
      defaultStack: json['default_stack'] ?? '',
      services: (json['services'] as List<dynamic>? ?? []).map((s) => s.toString()).toList(),
      composeRaw: json['compose_raw'] ?? '',
      icon: json['icon'] ?? '',
      tags: (json['tags'] as List<dynamic>? ?? []).map((t) => t.toString()).toList(),
    );
  }
}

/// Host port collision metadata returned during stack scheduling conflict
class PortConflictModel {
  final int hostPort;
  final String protocol;
  final String service;
  final String conflictingStack;
  final String conflictingService;
  final String nodeId;
  final String nodeIp;
  final int suggestedPort;

  PortConflictModel({
    required this.hostPort,
    required this.protocol,
    required this.service,
    required this.conflictingStack,
    required this.conflictingService,
    required this.nodeId,
    required this.nodeIp,
    required this.suggestedPort,
  });

  factory PortConflictModel.fromJson(Map<String, dynamic> json) {
    return PortConflictModel(
      hostPort: (json['host_port'] as num?)?.toInt() ?? 0,
      protocol: json['protocol'] ?? 'tcp',
      service: json['service'] ?? '',
      conflictingStack: json['conflicting_stack'] ?? '',
      conflictingService: json['conflicting_service'] ?? '',
      nodeId: json['node_id'] ?? '',
      nodeIp: json['node_ip'] ?? '',
      suggestedPort: (json['suggested_port'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Result of deploying a stack, capturing success, error, or port conflict metadata
class DeployStackResult {
  final bool success;
  final String? error;
  final bool isConflict;
  final List<PortConflictModel> conflicts;
  final String? remappedCompose;
  final String? stackId;

  DeployStackResult({
    required this.success,
    this.error,
    this.isConflict = false,
    this.conflicts = const [],
    this.remappedCompose,
    this.stackId,
  });
}

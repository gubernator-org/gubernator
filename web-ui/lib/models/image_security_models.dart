/// Container Image Security, CVE Scanning, Cosign Signing, Remediation, and Registry models.
library;

// ── Image Security & SBOM Models ─────────────────────────────────────────────

class ImageScanModel {
  final String id;
  final String imageName;
  final String imageDigest;
  final String scannedAt;
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final int totalCount;
  final String signatureStatus;
  final String? signatureSigner;
  final List<String> hosts;
  final List<String> services;
  final bool inUse;

  ImageScanModel({
    required this.id,
    required this.imageName,
    this.imageDigest = '',
    required this.scannedAt,
    this.criticalCount = 0,
    this.highCount = 0,
    this.mediumCount = 0,
    this.lowCount = 0,
    this.totalCount = 0,
    this.signatureStatus = 'unsigned',
    this.signatureSigner,
    this.hosts = const [],
    this.services = const [],
    this.inUse = true,
  });

  factory ImageScanModel.fromJson(Map<String, dynamic> json) {
    return ImageScanModel(
      id: json['id'] ?? '',
      imageName: json['image_name'] ?? '',
      imageDigest: json['image_digest'] ?? '',
      scannedAt: json['scanned_at'] != null ? json['scanned_at'].toString().split('T')[0] : '',
      criticalCount: (json['critical_count'] as num?)?.toInt() ?? 0,
      highCount: (json['high_count'] as num?)?.toInt() ?? 0,
      mediumCount: (json['medium_count'] as num?)?.toInt() ?? 0,
      lowCount: (json['low_count'] as num?)?.toInt() ?? 0,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      signatureStatus: json['signature_status'] ?? 'unsigned',
      signatureSigner: json['signature_signer'],
      hosts: (json['hosts'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      services: (json['services'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      inUse: json['in_use'] ?? true,
    );
  }
}

class ImageVulnerabilityModel {
  final String id;
  final String scanId;
  final String cveId;
  final String packageName;
  final String installedVersion;
  final String? fixedVersion;
  final String severity;
  final double cvssScore;
  final String title;
  final String description;
  final String primaryUrl;

  ImageVulnerabilityModel({
    required this.id,
    required this.scanId,
    required this.cveId,
    required this.packageName,
    required this.installedVersion,
    this.fixedVersion,
    required this.severity,
    this.cvssScore = 0.0,
    this.title = '',
    this.description = '',
    this.primaryUrl = '',
  });

  factory ImageVulnerabilityModel.fromJson(Map<String, dynamic> json) {
    return ImageVulnerabilityModel(
      id: json['id'] ?? '',
      scanId: json['scan_id'] ?? '',
      cveId: json['cve_id'] ?? '',
      packageName: json['package_name'] ?? '',
      installedVersion: json['installed_version'] ?? '',
      fixedVersion: json['fixed_version'],
      severity: json['severity'] ?? 'LOW',
      cvssScore: (json['cvss_score'] as num?)?.toDouble() ?? 0.0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      primaryUrl: json['primary_url'] ?? '',
    );
  }
}

class TrustedKeyModel {
  final String id;
  final String name;
  final String publicKeyPem;
  final String keyType;
  final bool isDefault;
  final bool hasPrivateKey;
  final String createdAt;

  TrustedKeyModel({
    required this.id,
    required this.name,
    required this.publicKeyPem,
    this.keyType = 'cosign-ecdsa',
    this.isDefault = false,
    this.hasPrivateKey = false,
    required this.createdAt,
  });

  factory TrustedKeyModel.fromJson(Map<String, dynamic> json) {
    return TrustedKeyModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      publicKeyPem: json['public_key_pem'] ?? '',
      keyType: json['key_type'] ?? 'cosign-ecdsa',
      isDefault: json['is_default'] ?? false,
      hasPrivateKey: json['has_private_key'] == true,
      createdAt: json['created_at'] != null ? json['created_at'].toString().split('T')[0] : '',
    );
  }
}

class SecurityPolicyModel {
  final String id;
  final String name;
  final String enforceSignatures;
  final String blockCveSeverity;
  final bool allowUnfixedCve;
  final String trustedRegistries;
  final String updatedAt;

  SecurityPolicyModel({
    required this.id,
    required this.name,
    this.enforceSignatures = 'audit',
    this.blockCveSeverity = 'none',
    this.allowUnfixedCve = true,
    this.trustedRegistries = '["docker.io","ghcr.io","quay.io"]',
    required this.updatedAt,
  });

  factory SecurityPolicyModel.fromJson(Map<String, dynamic> json) {
    return SecurityPolicyModel(
      id: json['id'] ?? 'default',
      name: json['name'] ?? 'Cluster Security Policy',
      enforceSignatures: json['enforce_signatures'] ?? 'audit',
      blockCveSeverity: json['block_cve_severity'] ?? 'none',
      allowUnfixedCve: json['allow_unfixed_cve'] ?? true,
      trustedRegistries: json['trusted_registries'] ?? '["docker.io","ghcr.io","quay.io"]',
      updatedAt: json['updated_at'] != null ? json['updated_at'].toString().split('T')[0] : '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enforce_signatures': enforceSignatures,
        'block_cve_severity': blockCveSeverity,
        'allow_unfixed_cve': allowUnfixedCve,
        'trusted_registries': trustedRegistries,
      };
}

class SecuritySummaryModel {
  final int totalImages;
  final int totalScanned;
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final int verifiedSigned;
  final int unsignedCount;

  SecuritySummaryModel({
    this.totalImages = 0,
    this.totalScanned = 0,
    this.criticalCount = 0,
    this.highCount = 0,
    this.mediumCount = 0,
    this.lowCount = 0,
    this.verifiedSigned = 0,
    this.unsignedCount = 0,
  });

  factory SecuritySummaryModel.fromJson(Map<String, dynamic> json) {
    return SecuritySummaryModel(
      totalImages: (json['total_images'] as num?)?.toInt() ?? 0,
      totalScanned: (json['total_scanned'] as num?)?.toInt() ?? 0,
      criticalCount: (json['critical_count'] as num?)?.toInt() ?? 0,
      highCount: (json['high_count'] as num?)?.toInt() ?? 0,
      mediumCount: (json['medium_count'] as num?)?.toInt() ?? 0,
      lowCount: (json['low_count'] as num?)?.toInt() ?? 0,
      verifiedSigned: (json['verified_signed'] as num?)?.toInt() ?? 0,
      unsignedCount: (json['unsigned_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Image Security Auto-Remediation Candidate Version
class SuggestedVersionModel {
  final String version;
  final String type; // "patch", "alpine_stable", "latest"
  final String description;
  final String riskLevel; // "low", "medium", "high"
  final bool isRecommended;

  SuggestedVersionModel({
    required this.version,
    required this.type,
    required this.description,
    required this.riskLevel,
    required this.isRecommended,
  });

  factory SuggestedVersionModel.fromJson(Map<String, dynamic> json) {
    return SuggestedVersionModel(
      version: json['version'] ?? '',
      type: json['type'] ?? 'patch',
      description: json['description'] ?? '',
      riskLevel: json['risk_level'] ?? 'low',
      isRecommended: json['is_recommended'] == true,
    );
  }
}

/// Affected stack and service for a container image
class AffectedStackInfoModel {
  final String stackId;
  final String stackName;
  final String serviceName;
  final int replicas;

  AffectedStackInfoModel({
    required this.stackId,
    required this.stackName,
    required this.serviceName,
    required this.replicas,
  });

  factory AffectedStackInfoModel.fromJson(Map<String, dynamic> json) {
    return AffectedStackInfoModel(
      stackId: json['stack_id'] ?? '',
      stackName: json['stack_name'] ?? '',
      serviceName: json['service_name'] ?? '',
      replicas: (json['replicas'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Preview and risk assessment for container image remediation
class RemediationPreviewModel {
  final String currentImage;
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final List<SuggestedVersionModel> suggestedVersions;
  final List<AffectedStackInfoModel> affectedStacks;
  final bool isInUse;
  final String riskAssessment;
  final String riskLevel;

  RemediationPreviewModel({
    required this.currentImage,
    required this.criticalCount,
    required this.highCount,
    required this.mediumCount,
    required this.suggestedVersions,
    required this.affectedStacks,
    this.isInUse = true,
    required this.riskAssessment,
    required this.riskLevel,
  });

  factory RemediationPreviewModel.fromJson(Map<String, dynamic> json) {
    return RemediationPreviewModel(
      currentImage: json['current_image'] ?? '',
      criticalCount: (json['critical_count'] as num?)?.toInt() ?? 0,
      highCount: (json['high_count'] as num?)?.toInt() ?? 0,
      mediumCount: (json['medium_count'] as num?)?.toInt() ?? 0,
      suggestedVersions: (json['suggested_versions'] as List<dynamic>? ?? [])
          .map((v) => SuggestedVersionModel.fromJson(v as Map<String, dynamic>))
          .toList(),
      affectedStacks: (json['affected_stacks'] as List<dynamic>? ?? [])
          .map((s) => AffectedStackInfoModel.fromJson(s as Map<String, dynamic>))
          .toList(),
      isInUse: json['is_in_use'] ?? ((json['affected_stacks'] as List<dynamic>? ?? []).isNotEmpty),
      riskAssessment: json['risk_assessment'] ?? '',
      riskLevel: json['risk_level'] ?? 'low',
    );
  }
}

/// Step log entry during automated image remediation & rollback
class RemediationStepLogModel {
  final String step;
  final String message;
  final String status; // "ok", "warn", "error"
  final String timestamp;

  RemediationStepLogModel({
    required this.step,
    required this.message,
    required this.status,
    required this.timestamp,
  });

  factory RemediationStepLogModel.fromJson(Map<String, dynamic> json) {
    return RemediationStepLogModel(
      step: json['step'] ?? '',
      message: json['message'] ?? '',
      status: json['status'] ?? 'ok',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

/// Result of executing an automated image remediation
class RemediationResultModel {
  final bool success;
  final String message;
  final bool rolledBack;
  final String stackId;
  final String newImage;
  final String oldImage;
  final List<RemediationStepLogModel> logs;

  RemediationResultModel({
    required this.success,
    required this.message,
    required this.rolledBack,
    required this.stackId,
    required this.newImage,
    required this.oldImage,
    required this.logs,
  });

  factory RemediationResultModel.fromJson(Map<String, dynamic> json) {
    return RemediationResultModel(
      success: json['success'] == true,
      message: json['message'] ?? '',
      rolledBack: json['rolled_back'] == true,
      stackId: json['stack_id'] ?? '',
      newImage: json['new_image'] ?? '',
      oldImage: json['old_image'] ?? '',
      logs: (json['logs'] as List<dynamic>? ?? [])
          .map((l) => RemediationStepLogModel.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Physical Docker image stored on a cluster node
class HostDockerImageModel {
  final String id;
  final String repository;
  final String tag;
  final String fullName;
  final String size;
  final int sizeBytes;
  final String createdAt;
  final String nodeId;
  final String nodeName;
  final String nodeIp;
  final bool inUse;
  final List<String> containersUsing;

  HostDockerImageModel({
    required this.id,
    required this.repository,
    required this.tag,
    required this.fullName,
    required this.size,
    required this.sizeBytes,
    required this.createdAt,
    required this.nodeId,
    required this.nodeName,
    required this.nodeIp,
    required this.inUse,
    this.containersUsing = const [],
  });

  factory HostDockerImageModel.fromJson(Map<String, dynamic> json) {
    return HostDockerImageModel(
      id: json['id'] ?? '',
      repository: json['repository'] ?? '',
      tag: json['tag'] ?? '',
      fullName: json['full_name'] ?? '',
      size: json['size'] ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] ?? '',
      nodeId: json['node_id'] ?? '',
      nodeName: json['node_name'] ?? '',
      nodeIp: json['node_ip'] ?? '',
      inUse: json['in_use'] == true,
      containersUsing: (json['containers_using'] as List<dynamic>? ?? [])
          .map((c) => c.toString())
          .toList(),
    );
  }
}

/// Single layer in an image construction history
class ImageLayerModel {
  final int order;
  final String id;
  final String createdBy;
  final String instruction;
  final String args;
  final String size;
  final int sizeBytes;
  final String createdAt;
  final String comment;

  ImageLayerModel({
    required this.order,
    required this.id,
    required this.createdBy,
    required this.instruction,
    required this.args,
    required this.size,
    required this.sizeBytes,
    required this.createdAt,
    required this.comment,
  });

  factory ImageLayerModel.fromJson(Map<String, dynamic> json) {
    return ImageLayerModel(
      order: (json['order'] as num?)?.toInt() ?? 0,
      id: json['id'] ?? '',
      createdBy: json['created_by'] ?? '',
      instruction: json['instruction'] ?? '',
      args: json['args'] ?? '',
      size: json['size'] ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] ?? '',
      comment: json['comment'] ?? '',
    );
  }
}

/// Complete layer breakdown and reconstructed Dockerfile
class ImageHistoryModel {
  final String image;
  final String imageId;
  final String nodeId;
  final String nodeName;
  final List<ImageLayerModel> layers;
  final String reconstructedDockerfile;
  final int totalSizeBytes;
  final String totalSize;

  ImageHistoryModel({
    required this.image,
    required this.imageId,
    required this.nodeId,
    required this.nodeName,
    required this.layers,
    required this.reconstructedDockerfile,
    required this.totalSizeBytes,
    required this.totalSize,
  });

  factory ImageHistoryModel.fromJson(Map<String, dynamic> json) {
    return ImageHistoryModel(
      image: json['image'] ?? '',
      imageId: json['image_id'] ?? '',
      nodeId: json['node_id'] ?? '',
      nodeName: json['node_name'] ?? '',
      layers: (json['layers'] as List<dynamic>? ?? [])
          .map((l) => ImageLayerModel.fromJson(l as Map<String, dynamic>))
          .toList(),
      reconstructedDockerfile: json['reconstructed_dockerfile'] ?? '',
      totalSizeBytes: (json['total_size_bytes'] as num?)?.toInt() ?? 0,
      totalSize: json['total_size'] ?? '',
    );
  }
}

/// Outcome of docker image prune operation across cluster nodes
class ImagePruneResultModel {
  final int totalImagesDeleted;
  final String totalSpaceReclaimed;
  final int totalSpaceReclaimedBytes;
  final Map<String, String> nodeResults;
  final List<String> logs;

  ImagePruneResultModel({
    required this.totalImagesDeleted,
    required this.totalSpaceReclaimed,
    required this.totalSpaceReclaimedBytes,
    required this.nodeResults,
    required this.logs,
  });

  factory ImagePruneResultModel.fromJson(Map<String, dynamic> json) {
    Map<String, String> nodeRes = {};
    if (json['node_results'] is Map) {
      (json['node_results'] as Map).forEach((k, v) {
        nodeRes[k.toString()] = v.toString();
      });
    }

    return ImagePruneResultModel(
      totalImagesDeleted: (json['total_images_deleted'] as num?)?.toInt() ?? 0,
      totalSpaceReclaimed: json['total_space_reclaimed'] ?? '0 B',
      totalSpaceReclaimedBytes: (json['total_space_reclaimed_bytes'] as num?)?.toInt() ?? 0,
      nodeResults: nodeRes,
      logs: (json['logs'] as List<dynamic>? ?? []).map((l) => l.toString()).toList(),
    );
  }
}

/// Outcome of Dockerfile build execution in The Forge
class ImageBuildResultModel {
  final bool success;
  final String imageTag;
  final String imageId;
  final String nodeId;
  final String nodeName;
  final String duration;
  final List<String> logs;
  final String? error;

  ImageBuildResultModel({
    required this.success,
    required this.imageTag,
    required this.imageId,
    required this.nodeId,
    required this.nodeName,
    required this.duration,
    required this.logs,
    this.error,
  });

  factory ImageBuildResultModel.fromJson(Map<String, dynamic> json) {
    return ImageBuildResultModel(
      success: json['success'] == true,
      imageTag: json['image_tag'] ?? '',
      imageId: json['image_id'] ?? '',
      nodeId: json['node_id'] ?? '',
      nodeName: json['node_name'] ?? '',
      duration: json['duration'] ?? '',
      logs: (json['logs'] as List<dynamic>? ?? []).map((l) => l.toString()).toList(),
      error: json['error'],
    );
  }
}

/// Outcome of distributing an image across Centurion cluster nodes
class ImageDistributeResultModel {
  final bool success;
  final String image;
  final String sourceNode;
  final List<String> targetNodes;
  final Map<String, String> nodeResults;
  final String duration;
  final String? error;

  ImageDistributeResultModel({
    required this.success,
    required this.image,
    required this.sourceNode,
    required this.targetNodes,
    required this.nodeResults,
    required this.duration,
    this.error,
  });

  factory ImageDistributeResultModel.fromJson(Map<String, dynamic> json) {
    final rawResults = json['node_results'] as Map<String, dynamic>? ?? {};
    final nodeResults = rawResults.map((k, v) => MapEntry(k, v.toString()));
    return ImageDistributeResultModel(
      success: json['success'] == true,
      image: json['image'] ?? '',
      sourceNode: json['source_node'] ?? '',
      targetNodes: (json['target_nodes'] as List<dynamic>? ?? []).map((t) => t.toString()).toList(),
      nodeResults: nodeResults,
      duration: json['duration'] ?? '',
      error: json['error'],
    );
  }
}

part of '../api_service.dart';

class ImageComplianceApi {
  static Map<String, String> get authHeaders => ApiService.authHeaders;
  static String? get authToken => ApiService.authToken;
  static set authToken(String? token) => ApiService.authToken = token;

  // ── Image Security & SBOM API Methods ──────────────────────────────────────

  /// Fetches all image vulnerability scans and cluster security summary.
  static Future<Map<String, dynamic>> fetchImageScans() async {
    final response = await http.get(Uri.parse('/api/security/scans'), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final scans = (data['scans'] as List? ?? [])
          .map((e) => ImageScanModel.fromJson(e))
          .toList();
      final summary = data['summary'] != null ? SecuritySummaryModel.fromJson(data['summary']) : SecuritySummaryModel();
      return {
        'scans': scans,
        'summary': summary,
      };
    }
    throw Exception('Failed to fetch security scans: ${response.statusCode}');
  }

  /// Fetches details and CVEs for a specific scan ID.
  static Future<Map<String, dynamic>> fetchScanDetails(String scanId) async {
    final response = await http.get(Uri.parse('/api/security/scans/$scanId'), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final scan = ImageScanModel.fromJson(data['scan']);
      final vulns = (data['vulnerabilities'] as List? ?? [])
          .map((e) => ImageVulnerabilityModel.fromJson(e))
          .toList();
      return {
        'scan': scan,
        'vulnerabilities': vulns,
      };
    }
    throw Exception('Failed to fetch scan details: ${response.statusCode}');
  }

  /// Triggers an immediate vulnerability scan for an image.
  static Future<Map<String, dynamic>> triggerImageScan(String image) async {
    final response = await http.post(
      Uri.parse('/api/security/scans/trigger'),
      headers: authHeaders,
      body: jsonEncode({'image': image}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'scan': ImageScanModel.fromJson(data['scan']),
        'vulnerabilities': (data['vulnerabilities'] as List? ?? [])
            .map((e) => ImageVulnerabilityModel.fromJson(e))
            .toList(),
      };
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Scan failed');
  }

  /// Forces a complete re-scan and sync of all cluster images across all hosts.
  static Future<Map<String, dynamic>> syncAllImageScans() async {
    final response = await http.post(
      Uri.parse('/api/security/scans/sync-all'),
      headers: authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final scans = (data['scans'] as List? ?? [])
          .map((e) => ImageScanModel.fromJson(e))
          .toList();
      final summary = data['summary'] != null ? SecuritySummaryModel.fromJson(data['summary']) : SecuritySummaryModel();
      return {
        'scans': scans,
        'summary': summary,
      };
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Sync failed');
  }

  /// Fetches trusted public signing keys.
  static Future<List<TrustedKeyModel>> fetchTrustedKeys() async {
    final response = await http.get(Uri.parse('/api/security/keys'), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = (data['keys'] as List? ?? [])
          .map((e) => TrustedKeyModel.fromJson(e))
          .toList();
      return list;
    }
    throw Exception('Failed to fetch trusted keys: ${response.statusCode}');
  }

  /// Generates a new Cosign ECDSA keypair.
  static Future<Map<String, dynamic>> generateTrustedKey(String name, {bool isDefault = false}) async {
    final response = await http.post(
      Uri.parse('/api/security/keys/generate'),
      headers: authHeaders,
      body: jsonEncode({'name': name, 'is_default': isDefault}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Keypair generation failed');
  }

  /// Saves or imports an existing public key.
  static Future<TrustedKeyModel> saveTrustedKey(String name, String pubPEM, {bool isDefault = false}) async {
    final response = await http.post(
      Uri.parse('/api/security/keys'),
      headers: authHeaders,
      body: jsonEncode({'name': name, 'public_key_pem': pubPEM, 'is_default': isDefault}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return TrustedKeyModel.fromJson(data['key']);
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Failed to import key');
  }

  /// Deletes a trusted signing key.
  static Future<bool> deleteTrustedKey(String id) async {
    final response = await http.delete(Uri.parse('/api/security/keys/$id'), headers: authHeaders);
    return response.statusCode == 200;
  }

  /// Signs an image with an in-cluster key or manual private key.
  static Future<Map<String, dynamic>> signImage(
    String image, {
    String? keyId,
    String? privateKey,
    String signerName = 'Cluster Admin',
  }) async {
    final payload = <String, dynamic>{
      'image': image,
      'signer_name': signerName,
    };
    if (keyId != null && keyId.isNotEmpty) {
      payload['key_id'] = keyId;
    }
    if (privateKey != null && privateKey.isNotEmpty) {
      payload['private_key'] = privateKey;
    }

    final response = await http.post(
      Uri.parse('/api/security/sign'),
      headers: authHeaders,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Image signing failed');
  }

  /// Revokes/removes the cryptographic signature from an image.
  static Future<bool> unsignImage(String image) async {
    final response = await http.post(
      Uri.parse('/api/security/unsign'),
      headers: authHeaders,
      body: jsonEncode({'image': image}),
    );
    if (response.statusCode == 200) {
      return true;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Failed to revoke image signature');
  }

  /// Fetches cluster admission security policy.
  static Future<SecurityPolicyModel> fetchSecurityPolicy() async {
    final response = await http.get(Uri.parse('/api/security/policy'), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return SecurityPolicyModel.fromJson(data['policy']);
    }
    throw Exception('Failed to fetch security policy: ${response.statusCode}');
  }

  /// Saves cluster admission security policy.
  static Future<SecurityPolicyModel> saveSecurityPolicy(SecurityPolicyModel policy) async {
    final response = await http.post(
      Uri.parse('/api/security/policy'),
      headers: authHeaders,
      body: jsonEncode(policy.toJson()),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return SecurityPolicyModel.fromJson(data['policy']);
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Failed to update policy');
  }

  /// Fetches suggested upgrade versions, affected stacks, and risk analysis for a container image.
  static Future<RemediationPreviewModel> fetchRemediationPreview(String image) async {
    final response = await http.get(
      Uri.parse('/api/security/remediate/preview?image=${Uri.encodeComponent(image)}'),
      headers: authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return RemediationPreviewModel.fromJson(data);
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Failed to fetch remediation preview');
  }

  /// Executes automated image upgrade in a stack with rollback protection and live step logs.
  static Future<RemediationResultModel> executeRemediation({
    required String stackId,
    required String currentImage,
    required String targetImage,
    bool autoRollback = true,
  }) async {
    final response = await http.post(
      Uri.parse('/api/security/remediate'),
      headers: authHeaders,
      body: jsonEncode({
        'stack_id': stackId,
        'current_image': currentImage,
        'target_image': targetImage,
        'auto_rollback': autoRollback,
      }),
    );
    final data = jsonDecode(response.body);
    return RemediationResultModel.fromJson(data);
  }

  /// Deletes a specific image scan report and its CVEs from cluster state.
  static Future<bool> deleteImageScan(String scanIdOrImage) async {
    final response = await http.delete(
      Uri.parse('/api/security/scans/${Uri.encodeComponent(scanIdOrImage)}'),
      headers: authHeaders,
    );
    return response.statusCode == 200;
  }

  /// Prunes all scan reports of images that are no longer used by any active stack.
  static Future<Map<String, dynamic>> pruneOrphanImageScans() async {
    final response = await http.post(
      Uri.parse('/api/security/scans/prune-orphans'),
      headers: authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final scans = (data['scans'] as List? ?? [])
          .map((e) => ImageScanModel.fromJson(e))
          .toList();
      final summary = data['summary'] != null ? SecuritySummaryModel.fromJson(data['summary']) : SecuritySummaryModel();
      return {
        'purged': data['purged'] ?? 0,
        'scans': scans,
        'summary': summary,
      };
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Prune failed');
  }

  // ─── Docker Host Images & Build Forge Services ────────────────────────────

  /// Fetches physical Docker images stored on cluster nodes.
  static Future<List<HostDockerImageModel>> fetchHostDockerImages({String node = 'all'}) async {
    final response = await http.get(
      Uri.parse('/api/images/host-list?node=${Uri.encodeComponent(node)}'),
      headers: authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = (data['images'] as List? ?? [])
          .map((e) => HostDockerImageModel.fromJson(e))
          .toList();
      return list;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Failed to list host images');
  }

  /// Inspects layer history and reconstructed Dockerfile for a Docker image.
  static Future<ImageHistoryModel> fetchImageHistory(String image, {String node = 'manager'}) async {
    final response = await http.get(
      Uri.parse('/api/images/history?image=${Uri.encodeComponent(image)}&node=${Uri.encodeComponent(node)}'),
      headers: authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ImageHistoryModel.fromJson(data);
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Failed to inspect image history');
  }

  /// Deletes a physical Docker image from a specific node or all cluster nodes.
  static Future<Map<String, dynamic>> deleteHostDockerImage(String image, {String node = 'all', bool force = false, bool purgeDb = true}) async {
    final response = await http.delete(
      Uri.parse('/api/images/host-delete?image=${Uri.encodeComponent(image)}&node=${Uri.encodeComponent(node)}&force=$force&purge_db=$purgeDb'),
      headers: authHeaders,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Failed to delete image from host');
  }

  /// Prunes unused and dangling Docker images across cluster nodes to reclaim disk space.
  static Future<ImagePruneResultModel> pruneHostDockerImages({String node = 'all', bool allUnused = true}) async {
    final response = await http.post(
      Uri.parse('/api/images/prune'),
      headers: authHeaders,
      body: jsonEncode({
        'node': node,
        'all_unused': allUnused,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ImagePruneResultModel.fromJson(data);
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Failed to prune host images');
  }

  /// Builds a Docker image on a Centurion node from a Dockerfile in The Imperial Forge.
  static Future<ImageBuildResultModel> buildDockerImage({
    required String tag,
    required String dockerfile,
    String node = 'manager',
    Map<String, String>? buildArgs,
    bool noCache = false,
  }) async {
    final response = await http.post(
      Uri.parse('/api/images/build'),
      headers: authHeaders,
      body: jsonEncode({
        'tag': tag,
        'dockerfile': dockerfile,
        'node_id': node,
        'build_args': buildArgs ?? {},
        'no_cache': noCache,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || data['result'] != null) {
      return ImageBuildResultModel.fromJson(data['result'] ?? data);
    }
    final err = data['error'] ?? 'Build failed';
    throw Exception(err);
  }

  /// Distributes and loads a Docker image across Centurion cluster nodes.
  static Future<ImageDistributeResultModel> distributeDockerImage({
    required String image,
    String targetNode = 'all',
  }) async {
    final response = await http.post(
      Uri.parse('/api/images/distribute'),
      headers: authHeaders,
      body: jsonEncode({
        'image': image,
        'target_node': targetNode,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || data['result'] != null) {
      return ImageDistributeResultModel.fromJson(data['result'] ?? data);
    }
    final err = data['error'] ?? 'Distribution failed';
    throw Exception(err);
  }

  /// Fetches transparent GitHub adoption stats & release metrics.
  static Future<AdoptionStatsModel> fetchAdoptionStats({bool force = false}) async {
    final url = force ? '/api/system/adoption?force=true' : '/api/system/adoption';
    final response = await http.get(Uri.parse(url), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return AdoptionStatsModel.fromJson(data);
    }
    throw Exception('Failed to fetch adoption stats: ${response.statusCode}');
  }

  // ── Esquema Nacional de Seguridad (ENS RD 311/2022) ──────────────────────────

  /// Fetches Spanish ENS (RD 311/2022) compliance evaluation summary.
  static Future<ENSSummaryModel?> fetchENSStatus() async {
    try {
      final response = await http.get(
        Uri.parse('/api/security/ens/status'),
        headers: authHeaders,
      );
      if (response.statusCode == 200) {
        return ENSSummaryModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Downloads the technical ENS compliance and evidence report in Markdown or JSON.
  static Future<String?> fetchENSReport({String format = 'markdown'}) async {
    try {
      final response = await http.get(
        Uri.parse('/api/security/ens/report?format=$format'),
        headers: authHeaders,
      );
      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetches European NIS 2 Directive (EU 2022/2555) compliance evaluation summary.
  static Future<NIS2SummaryModel?> fetchNIS2Status() async {
    try {
      final response = await http.get(
        Uri.parse('/api/security/nis2/status'),
        headers: authHeaders,
      );
      if (response.statusCode == 200) {
        return NIS2SummaryModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Downloads the technical NIS 2 compliance and evidence report in Markdown or JSON.
  static Future<String?> fetchNIS2Report({String format = 'markdown'}) async {
    try {
      final response = await http.get(
        Uri.parse('/api/security/nis2/report?format=$format'),
        headers: authHeaders,
      );
      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetches CIS Docker Benchmark v1.6.0 compliance assessment summary.
  static Future<CISDockerSummaryModel?> fetchCISDockerStatus() async {
    try {
      final response = await http.get(
        Uri.parse('/api/security/cis-docker/status'),
        headers: authHeaders,
      );
      if (response.statusCode == 200) {
        return CISDockerSummaryModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Downloads the technical CIS Docker Benchmark compliance report in Markdown or JSON.
  static Future<String?> fetchCISDockerReport({String format = 'markdown'}) async {
    try {
      final response = await http.get(
        Uri.parse('/api/security/cis-docker/report?format=$format'),
        headers: authHeaders,
      );
      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetches ISO/IEC 27001:2022 Annex A compliance evaluation.
  static Future<ISO27001SummaryModel?> fetchISO27001Status() async {
    try {
      final response = await http.get(
        Uri.parse('/api/security/iso27001/status'),
        headers: authHeaders,
      );
      if (response.statusCode == 200) {
        return ISO27001SummaryModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Downloads the formal ISO/IEC 27001 Statement of Applicability audit report.
  static Future<String?> fetchISO27001Report({String format = 'text'}) async {
    try {
      final response = await http.get(
        Uri.parse('/api/security/iso27001/report?format=$format'),
        headers: authHeaders,
      );
      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetches cluster compliance status against EU DORA (Regulation 2022/2554).
  static Future<DORASummaryModel?> fetchDORAStatus() async {
    try {
      final response = await http.get(
        Uri.parse('/api/security/dora/status'),
        headers: authHeaders,
      );
      if (response.statusCode == 200) {
        return DORASummaryModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Downloads the technical DORA operational resilience audit report.
  static Future<String?> fetchDORAReport({String format = 'markdown'}) async {
    try {
      final response = await http.get(
        Uri.parse('/api/security/dora/report?format=$format'),
        headers: authHeaders,
      );
      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetches the unified Continuous Compliance Overview across all 5 regulatory frameworks.
  static Future<ComplianceOverviewModel?> fetchComplianceOverview() async {
    try {
      final response = await http.get(
        Uri.parse('/api/security/compliance/overview'),
        headers: authHeaders,
      );
      if (response.statusCode == 200) {
        return ComplianceOverviewModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Triggers an immediate, cluster-wide re-evaluation across all 4 regulatory frameworks.
  static Future<ComplianceOverviewModel?> evaluateAllCompliance() async {
    try {
      final response = await http.post(
        Uri.parse('/api/security/compliance/evaluate-all'),
        headers: authHeaders,
      );
      if (response.statusCode == 200) {
        return ComplianceOverviewModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

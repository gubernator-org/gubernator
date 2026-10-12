part of '../api_service.dart';

class ClusterApi {
  static Map<String, String> get authHeaders => ApiService.authHeaders;
  static String? get authToken => ApiService.authToken;
  static set authToken(String? token) => ApiService.authToken = token;

  /// Fetches the full dashboard state from the backend.
  static Future<DashboardState> fetchState() async {
    final response = await http.get(Uri.parse('/api/state'), headers: authHeaders);
    if (response.statusCode == 200) {
      return DashboardState.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch state: ${response.statusCode}');
  }

  /// Fetches all cluster Centurion nodes.
  static Future<List<Node>> fetchNodes() async {
    final state = await fetchState();
    return state.nodes;
  }

  /// Deletes a stack and stops all its containers.
  static Future<bool> deleteStack(String id) async {
    final response = await http.delete(Uri.parse('/api/stack/$id'), headers: authHeaders);
    return response.statusCode == 200;
  }

  /// Stops all containers in a stack without deleting it.
  static Future<bool> stopStack(String id) async {
    final response = await http.post(Uri.parse('/api/stack/$id/stop'), headers: authHeaders);
    return response.statusCode == 200;
  }

  /// Starts all containers in a stopped stack.
  static Future<bool> startStack(String id) async {
    final response = await http.post(Uri.parse('/api/stack/$id/start'), headers: authHeaders);
    return response.statusCode == 200;
  }

  /// Redeploys a stack.
  static Future<bool> redeployStack(String id) async {
    final response = await http.post(Uri.parse('/api/stack/$id/redeploy'), headers: authHeaders);
    return response.statusCode == 200;
  }

  /// Restarts all containers in a stack.
  static Future<bool> restartStack(String id) async {
    final response = await http.post(Uri.parse('/api/stack/$id/restart'), headers: authHeaders);
    return response.statusCode == 200;
  }

  /// Reconciles a single stack, purging dead/stale containers and aligning tasks with desired replicas.
  static Future<Map<String, dynamic>?> reconcileStack(String id) async {
    try {
      final response = await http.post(Uri.parse('/api/stack/$id/reconcile'), headers: authHeaders);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Updates horizontal autoscaling configuration for a specific service.
  static Future<bool> updateServiceAutoscale(String serviceId, Map<String, dynamic> config) async {
    try {
      final response = await http.post(
        Uri.parse('/api/services/$serviceId/autoscale'),
        headers: authHeaders,
        body: jsonEncode(config),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Updates horizontal autoscaling configuration for all services in a stack.
  static Future<bool> updateStackAutoscale(String stackId, Map<String, dynamic> config) async {
    try {
      final response = await http.post(
        Uri.parse('/api/stack/$stackId/autoscale'),
        headers: authHeaders,
        body: jsonEncode(config),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Prunes all dead, duplicate, and orphan containers across the cluster.
  static Future<Map<String, dynamic>?> pruneTasks() async {
    try {
      final response = await http.post(Uri.parse('/api/tasks/prune'), headers: authHeaders);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Deploys a stack with full conflict detection and resolution options.
  static Future<DeployStackResult> deployStackDetailed(
    String name,
    String compose, {
    String? targetNode,
    bool force = false,
    bool autoRemapPorts = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('/api/stack'),
        headers: authHeaders,
        body: jsonEncode({
          'name': name,
          'compose': compose,
          'target_node': targetNode,
          'force': force,
          'auto_remap_ports': autoRemapPorts,
        }),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rawConflicts = (body['remapped_conflicts'] as List<dynamic>?) ?? [];
        final conflicts = rawConflicts
            .map((c) => PortConflictModel.fromJson(c as Map<String, dynamic>))
            .toList();
        return DeployStackResult(
          success: true,
          stackId: body['stack_id'] as String?,
          remappedCompose: body['compose'] as String?,
          conflicts: conflicts,
        );
      } else if (response.statusCode == 409) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rawConflicts = (body['conflicts'] as List<dynamic>?) ?? [];
        final conflicts = rawConflicts
            .map((c) => PortConflictModel.fromJson(c as Map<String, dynamic>))
            .toList();
        return DeployStackResult(
          success: false,
          error: body['message'] as String? ?? 'Host port conflict detected',
          isConflict: true,
          conflicts: conflicts,
        );
      } else {
        try {
          final body = jsonDecode(response.body);
          return DeployStackResult(
            success: false,
            error: body['error'] ?? 'Server error: ${response.statusCode}',
          );
        } catch (_) {
          return DeployStackResult(
            success: false,
            error: 'Server error: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      return DeployStackResult(success: false, error: e.toString());
    }
  }

  static Future<String?> deployStack(
    String name,
    String compose, {
    String? targetNode,
    bool force = false,
    bool autoRemapPorts = false,
  }) async {
    final res = await deployStackDetailed(
      name,
      compose,
      targetNode: targetNode,
      force: force,
      autoRemapPorts: autoRemapPorts,
    );
    return res.success ? null : res.error;
  }

  /// Saves stack compose definition into DB and ~/.gbnt/stacks/ without deploying/launching containers.
  static Future<Map<String, dynamic>> saveStack({
    required String name,
    required String compose,
    String? stackId,
    String? targetNode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('/api/stack/save'),
        headers: authHeaders,
        body: jsonEncode({
          'id': stackId,
          'name': name,
          'compose': compose,
          'target_node': targetNode,
        }),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Lists Compose stack files found on the Master server host.
  static Future<Map<String, dynamic>> fetchServerStackFiles({String? dir}) async {
    final uri = (dir != null && dir.isNotEmpty)
        ? Uri.parse('/api/stacks/server-files?dir=${Uri.encodeQueryComponent(dir)}')
        : Uri.parse('/api/stacks/server-files');
    final response = await http.get(uri, headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final files = (data['files'] as List? ?? [])
          .map((f) => ServerStackFileModel.fromJson(f))
          .toList();
      final subdirs = (data['subdirectories'] as List? ?? [])
          .map((s) => {
                'name': s['name']?.toString() ?? '',
                'path': s['path']?.toString() ?? '',
              })
          .toList();
      return {
        'files': files,
        'current_dir': data['current_dir'] ?? dir ?? '',
        'parent_dir': data['parent_dir'] ?? '',
        'subdirectories': subdirs,
        'stacks_dir': data['stacks_dir'] ?? '',
        'examples_dir': data['examples_dir'] ?? '',
        'total': data['total'] ?? files.length,
      };
    }
    throw Exception('Failed to fetch server stack files: ${response.statusCode}');
  }

  /// Reads a Compose stack file from the Master server filesystem.
  static Future<Map<String, dynamic>> fetchServerStackFile(String path) async {
    final uri = Uri.parse('/api/stacks/server-file?path=${Uri.encodeQueryComponent(path)}');
    final response = await http.get(uri, headers: authHeaders);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to read server stack file: ${response.statusCode}');
  }

  /// Deploys a stack directly from a Master server file path.
  static Future<String?> deployServerStack(String path, {String? name, String? targetNode}) async {
    final response = await http.post(
      Uri.parse('/api/stacks/server-deploy'),
      headers: authHeaders,
      body: jsonEncode({
        'path': path,
        if (name != null && name.isNotEmpty) 'name': name,
        if (targetNode != null && targetNode.isNotEmpty) 'target_node': targetNode,
      }),
    );
    if (response.statusCode == 200) {
      return null;
    }
    try {
      final body = jsonDecode(response.body);
      return body['error'] ?? 'Unknown error';
    } catch (_) {
      return 'Server error: ${response.statusCode}';
    }
  }

  /// Saves or updates a Compose stack file directly on the Master server filesystem.
  static Future<Map<String, dynamic>> saveServerStackFile({
    required String content,
    String? name,
    String? filename,
    String? dir,
  }) async {
    final response = await http.post(
      Uri.parse('/api/stacks/server-save'),
      headers: authHeaders,
      body: jsonEncode({
        'content': content,
        if (name != null && name.isNotEmpty) 'name': name,
        if (filename != null && filename.isNotEmpty) 'filename': filename,
        if (dir != null && dir.isNotEmpty) 'dir': dir,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    try {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Server error ${response.statusCode}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  /// Retrieves the list of built-in POC examples and blueprints.
  static Future<List<POCExampleModel>> fetchPOCExamples() async {
    final response = await http.get(Uri.parse('/api/examples'), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['examples'] as List? ?? [])
          .map((e) => POCExampleModel.fromJson(e))
          .toList();
    }
    throw Exception('Failed to fetch POC examples: ${response.statusCode}');
  }

  /// Deploys one or all POC examples into the cluster.
  static Future<String?> deployPOCExample(String id, {String? targetNode}) async {
    final response = await http.post(
      Uri.parse('/api/examples/deploy'),
      headers: authHeaders,
      body: jsonEncode({
        'id': id,
        if (targetNode != null && targetNode.isNotEmpty) 'target_node': targetNode,
      }),
    );
    if (response.statusCode == 200) {
      return null;
    }
    try {
      final body = jsonDecode(response.body);
      return body['error'] ?? 'Unknown error';
    } catch (_) {
      return 'Server error: ${response.statusCode}';
    }
  }

  /// Stops/removes a single task.
  static Future<bool> deleteTask(String id) async {
    final response = await http.delete(Uri.parse('/api/task/$id'), headers: authHeaders);
    return response.statusCode == 200;
  }

  /// Fetches container output logs or diagnostics for a given task ID.
  static Future<String> getTaskLogs(String taskId) async {
    try {
      final response = await http.get(Uri.parse('/api/task/$taskId/logs'), headers: authHeaders);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['logs'] ?? '';
      }
      return 'Failed to load container logs (HTTP ${response.statusCode})';
    } catch (e) {
      return 'Error loading logs: $e';
    }
  }

  /// Migrates a stack to a target node.
  static Future<bool> migrateStack(String stackId, String targetNode) async {
    final response = await http.post(
      Uri.parse('/api/stack/$stackId/migrate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'target_node': targetNode}),
    );
    return response.statusCode == 200;
  }

  /// Provision and add a remote worker host via SSH.
  static Future<String?> addHost(String host, String user, String password) async {
    final res = await provisionNode(host: host, user: user, password: password);
    return res.success ? null : res.error ?? res.message;
  }

  /// Fetches cluster join info and commands
  static Future<NodeJoinInfo?> fetchJoinInfo() async {
    try {
      final response = await http.get(Uri.parse('/api/node/join-info'));
      if (response.statusCode == 200) {
        return NodeJoinInfo.fromJson(jsonDecode(response.body));
      }
    } catch (_) {}
    return null;
  }

  /// Provision a remote host via SSH with step logs
  static Future<NodeProvisionResult> provisionNode({
    required String host,
    String port = '22',
    required String user,
    String authType = 'password',
    String password = '',
    String privateKey = '',
    bool deploySystemStacks = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('/api/node/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'host': host,
          'port': port,
          'user': user,
          'auth_type': authType,
          'password': password,
          'private_key': privateKey,
          'deploy_system_stacks': deploySystemStacks,
        }),
      );
      final body = jsonDecode(response.body);
      final rawLogs = (body['logs'] as List? ?? [])
          .map((e) => ProvisionStepLog.fromJson(e))
          .toList();
      if (response.statusCode == 200 && (body['success'] == true || body['message'] != null)) {
        return NodeProvisionResult(
          success: true,
          message: body['message'] ?? 'Node provisioned successfully',
          logs: rawLogs,
          node: body['node'] != null ? Node.fromJson(body['node']) : null,
        );
      } else {
        return NodeProvisionResult(
          success: false,
          message: body['error'] ?? 'Provisioning failed',
          error: body['error'] ?? 'Provisioning failed',
          logs: rawLogs,
        );
      }
    } catch (e) {
      return NodeProvisionResult(
        success: false,
        message: e.toString(),
        error: e.toString(),
        logs: [
          ProvisionStepLog(step: 'Connection Error', message: e.toString(), status: 'error'),
        ],
      );
    }
  }

  /// Sends an action (pause, unpause, restart, start, stop) to a task
  static Future<bool> taskAction(String id, String action) async {
    final response = await http.post(
      Uri.parse('/api/task/$id/action'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': action}),
    );
    return response.statusCode == 200;
  }

  /// Gets tail logs for a task
  static Future<String> taskLogs(String id) async {
    final response = await http.get(Uri.parse('/api/task/$id/logs'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['logs'] ?? '';
    }
    throw Exception('Failed to fetch logs: ${response.statusCode}');
  }

  /// Gets inspect JSON for a task
  static Future<String> taskInspect(String id) async {
    final response = await http.get(Uri.parse('/api/task/$id/inspect'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return const JsonEncoder.withIndent('  ').convert(data);
    }
    throw Exception('Failed to fetch inspect data: ${response.statusCode}');
  }

  /// Gets the compose YAML for a specific stack.
  static Future<String> getStackCompose(String id) async {
    final response = await http.get(Uri.parse('/api/stack/$id/compose'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['compose'] ?? '';
    }
    throw Exception('Failed to fetch compose');
  }

  /// Saves updated compose YAML for a stack.
  static Future<bool> updateStackCompose(String id, String compose) async {
    final response = await http.put(
      Uri.parse('/api/stack/$id/compose'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'compose': compose}),
    );
    return response.statusCode == 200;
  }

  /// Fetches user settings from the backend.
  static Future<Map<String, dynamic>> getSettings() async {
    final response = await http.get(Uri.parse('/api/settings'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {};
  }

  /// Updates user settings on the backend.
  static Future<bool> updateSettings(Map<String, dynamic> settings) async {
    final response = await http.put(
      Uri.parse('/api/settings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(settings),
    );
    return response.statusCode == 200;
  }

  /// Changes the web dashboard password.
  static Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    final response = await http.put(
      Uri.parse('/api/settings/password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    return response.statusCode == 200;
  }

  /// Updates a node's role (promote/demote). Deprecated in single-manager architecture.
  @Deprecated('Deprecated in single-manager architecture')
  static Future<bool> updateNodeRole(String id, String role) async {
    final response = await http.post(
      Uri.parse('/api/node/$id/role'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'role': role}),
    );
    return response.statusCode == 200;
  }

  /// Updates a node's availability status. Returns parsed response Map.
  static Future<Map<String, dynamic>> updateNodeAvailability(String id, String availability) async {
    try {
      final response = await http.post(
        Uri.parse('/api/node/$id/availability'),
        headers: authHeaders,
        body: jsonEncode({'availability': availability}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Failed with status ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Synchronizes the active authentication token to the remote worker node via SSH.
  static Future<Map<String, dynamic>> syncNodeToken(String id) async {
    try {
      final response = await http.post(Uri.parse('/api/node/$id/sync-token'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      final body = jsonDecode(response.body);
      return {'error': body['error'] ?? 'Failed to sync token'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Commands the node to leave the cluster.
  static Future<bool> leaveNode(String id) async {
    final response = await http.post(Uri.parse('/api/node/$id/leave'));
    return response.statusCode == 200;
  }

  /// Triggers a reboot for the node.
  static Future<bool> rebootNode(String id) async {
    final response = await http.post(Uri.parse('/api/node/$id/reboot'));
    return response.statusCode == 200;
  }

  /// Updates a node's labels.
  static Future<bool> updateNodeLabels(String id, Map<String, String> labels) async {
    final response = await http.post(
      Uri.parse('/api/node/$id/labels'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'labels': labels}),
    );
    return response.statusCode == 200;
  }

  /// Gets the CoreDNS configuration (Corefile).
  static Future<String> getCoreDNSConfig() async {
    final response = await http.get(Uri.parse('/api/coredns/config'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['config'] ?? '';
    }
    throw Exception('Failed to fetch CoreDNS config');
  }

  /// Updates the CoreDNS configuration (Corefile).
  static Future<bool> updateCoreDNSConfig(String config) async {
    final response = await http.put(
      Uri.parse('/api/coredns/config'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'config': config}),
    );
    return response.statusCode == 200;
  }

  /// Fetches CoreDNS status and memory usage.
  static Future<CoreDNSStatusInfo> fetchCoreDNSStatusInfo() async {
    final response = await http.get(Uri.parse('/api/coredns/status'));
    if (response.statusCode == 200) {
      return CoreDNSStatusInfo.fromJson(jsonDecode(response.body));
    }
    return CoreDNSStatusInfo(status: 'stopped', uptimeSeconds: 0, memBytes: 0, listeningPort: 5354, forwarders: [], totalRecords: 0);
  }

  /// Fetches custom static DNS records.
  static Future<List<CustomDNSRecord>> fetchCustomDNSRecords() async {
    final response = await http.get(Uri.parse('/api/coredns/custom-records'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map((e) => CustomDNSRecord.fromJson(e)).toList();
      }
    }
    return [];
  }

  /// Creates a custom static DNS record.
  static Future<bool> createCustomDNSRecord({
    required String domain,
    required String ip,
    String recordType = 'A',
    int ttl = 60,
  }) async {
    final response = await http.post(
      Uri.parse('/api/coredns/custom-records'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'domain': domain,
        'ip': ip,
        'record_type': recordType,
        'ttl': ttl,
      }),
    );
    return response.statusCode == 201;
  }

  /// Deletes a custom static DNS record.
  static Future<bool> deleteCustomDNSRecord(String id) async {
    final response = await http.delete(Uri.parse('/api/coredns/custom-records/$id'));
    return response.statusCode == 200;
  }

  /// Performs an interactive DNS query test (Dig / Nslookup).
  static Future<DNSDigResult> performDNSDig({
    required String domain,
    String recordType = 'A',
  }) async {
    final response = await http.post(
      Uri.parse('/api/coredns/dig'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'domain': domain,
        'record_type': recordType,
      }),
    );
    if (response.statusCode == 200) {
      return DNSDigResult.fromJson(jsonDecode(response.body));
    }
    return DNSDigResult(domain: domain, recordType: recordType, status: 'ERROR', queryTimeMs: 0.0, server: '127.0.0.1:5354', answers: [], rawOutput: 'Error connecting to server');
  }

  /// Performs an HTTP/HTTPS curl resolution test from the manager against a domain/host.
  static Future<DNSCurlResult> performDNSCurl({
    required String hostname,
    String ip = '',
    String protocol = 'http',
    int port = 0,
    String path = '/',
    String method = 'GET',
    bool followRedirect = true,
    bool insecure = true,
    int timeoutSeconds = 5,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('/api/coredns/curl'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hostname': hostname,
          'ip': ip,
          'protocol': protocol,
          'port': port,
          'path': path,
          'method': method,
          'follow_redirect': followRedirect,
          'insecure': insecure,
          'timeout_seconds': timeoutSeconds,
        }),
      );
      if (response.statusCode == 200) {
        return DNSCurlResult.fromJson(jsonDecode(response.body));
      }
      return DNSCurlResult(
        command: 'curl $protocol://$hostname$path',
        statusCode: response.statusCode,
        statusText: 'Server Error (${response.statusCode})',
        latencyMs: 0.0,
        headers: '',
        body: response.body,
        rawOutput: response.body,
        targetIp: ip,
        success: false,
        error: 'HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      return DNSCurlResult(
        command: 'curl $protocol://$hostname$path',
        statusCode: 0,
        statusText: 'Request Failed',
        latencyMs: 0.0,
        headers: '',
        body: e.toString(),
        rawOutput: 'Network exception connecting to Gubernator API: $e',
        targetIp: ip,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Performs an ICMP reachability / latency ping test against a domain or IP.
  static Future<DNSPingResult> performDNSPing({
    required String hostname,
    String ip = '',
    int count = 3,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('/api/coredns/ping'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hostname': hostname,
          'ip': ip,
          'count': count,
        }),
      );
      if (response.statusCode == 200) {
        return DNSPingResult.fromJson(jsonDecode(response.body));
      }
      return DNSPingResult(
        command: 'ping -c $count ${ip.isNotEmpty ? ip : hostname}',
        target: ip.isNotEmpty ? ip : hostname,
        packetsSent: count,
        packetsRecv: 0,
        packetLoss: 100.0,
        minLatency: 0.0,
        avgLatency: 0.0,
        maxLatency: 0.0,
        rawOutput: response.body,
        success: false,
        error: 'HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      return DNSPingResult(
        command: 'ping -c $count ${ip.isNotEmpty ? ip : hostname}',
        target: ip.isNotEmpty ? ip : hostname,
        packetsSent: count,
        packetsRecv: 0,
        packetLoss: 100.0,
        minLatency: 0.0,
        avgLatency: 0.0,
        maxLatency: 0.0,
        rawOutput: 'Network exception connecting to Gubernator API: $e',
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Fetches the configured base cluster domain.
  static Future<String> fetchClusterDomain() async {
    try {
      final response = await http.get(Uri.parse('/api/cluster/domain'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['cluster_domain'] ?? 'gbnt.local';
      }
    } catch (_) {}
    return 'gbnt.local';
  }

  /// Updates the base cluster domain.
  static Future<bool> updateClusterDomain(String domain) async {
    final response = await http.put(
      Uri.parse('/api/cluster/domain'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'cluster_domain': domain}),
    );
    return response.statusCode == 200;
  }

  /// Fetches status of Weave Scope Network Topology superpower.
  static Future<Map<String, dynamic>> fetchScopeStatus() async {
    final response = await http.get(Uri.parse('/api/scope/status'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'enabled': false, 'status': 'stopped'};
  }

  /// Enables Weave Scope container.
  static Future<bool> enableScope() async {
    final response = await http.post(
      Uri.parse('/api/scope/enable'),
      headers: authHeaders,
    );
    return response.statusCode == 200;
  }

  /// Disables Weave Scope container.
  static Future<bool> disableScope() async {
    final response = await http.post(
      Uri.parse('/api/scope/disable'),
      headers: authHeaders,
    );
    return response.statusCode == 200;
  }

  /// Updates and pulls latest Weave Scope container image from Docker Hub.
  static Future<Map<String, dynamic>> updateScopeImage() async {
    final response = await http.post(
      Uri.parse('/api/scope/update'),
      headers: authHeaders,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'error': 'Failed to update Scope image'};
  }

  /// Triggers cluster auto-update.
  static Future<bool> applyUpdate(String targetVersion) async {
    final response = await http.post(
      Uri.parse('/api/update/apply'),
      headers: authHeaders,
      body: jsonEncode({'target_version': targetVersion}),
    );
    return response.statusCode == 200;
  }

  /// Fetches latest release check from backend /api/system/update/check with optional force refresh.
  static Future<Map<String, dynamic>> fetchUpdateCheck({bool force = false}) async {
    try {
      final url = force ? '/api/update/check?force=true' : '/api/update/check';
      final response = await http.get(Uri.parse(url), headers: authHeaders);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return {'update_available': false, 'latest_version': 'unknown'};
  }

  /// Fetches live status of an ongoing or recent update.
  static Future<Map<String, dynamic>> fetchUpdateStatus() async {
    try {
      final response = await http.get(Uri.parse('/api/update/status'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return {'status': 'unknown'};
  }
}

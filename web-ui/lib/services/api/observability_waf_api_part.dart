part of '../api_service.dart';

class ObservabilityWafApi {
  static Map<String, String> get authHeaders => ApiService.authHeaders;
  static String? get authToken => ApiService.authToken;
  static set authToken(String? token) => ApiService.authToken = token;

  /// Fetches active SLO definitions and error budgets.
  static Future<List<SLOItem>> fetchSLOs() async {
    final response = await http.get(Uri.parse('/api/slo'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map((e) => SLOItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    return [];
  }

  /// Force syncs SLO rules with Prometheus.
  static Future<bool> syncSLOs() async {
    final response = await http.post(Uri.parse('/api/slo/sync'));
    return response.statusCode == 200;
  }

  /// Fetches aggregated User Journeys.
  static Future<List<UserJourney>> fetchUserJourneys() async {
    final response = await http.get(Uri.parse('/api/slo/journeys'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map((e) => UserJourney.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    return [];
  }

  /// Fetches deployment events correlation.
  static Future<List<SLOCorrelationEvent>> fetchSLOCorrelations() async {
    final response = await http.get(Uri.parse('/api/slo/correlation'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map((e) => SLOCorrelationEvent.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    return [];
  }

  /// Validates Compose YAML and runs PromQL backtest.
  static Future<List<SLOValidationItem>> validateSLO(String composeRaw) async {
    final response = await http.post(
      Uri.parse('/api/slo/validate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'compose_raw': composeRaw}),
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map((e) => SLOValidationItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    return [];
  }

  /// Fetches historical trend points for an SLO.
  static Future<List<SLOHistoryPoint>> fetchSLOHistory(String serviceId, String timeRange) async {
    final response = await http.get(Uri.parse('/api/slo/history?service_id=$serviceId&range=$timeRange'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map((e) => SLOHistoryPoint.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    return [];
  }

  /// Fetches RED metrics for a service.
  static Future<SLOREDMetrics> fetchSLOREDMetrics(String serviceId) async {
    final response = await http.get(Uri.parse('/api/slo/red?service_id=$serviceId'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return SLOREDMetrics.fromJson(decoded);
      }
    }
    return SLOREDMetrics(rps: 0, errorRps: 0, p99LatencyMs: 0);
  }

  /// Creates or updates an SLO configuration for a service.
  static Future<bool> editSLO({
    required String serviceId,
    required bool enable,
    required double target,
    required String window,
    String indicator = 'ratio',
    String latencyThreshold = '',
    String template = '',
    String journey = '',
    String errorQuery = '',
    String totalQuery = '',
  }) async {
    final response = await http.post(
      Uri.parse('/api/slo/edit'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id': serviceId,
        'enable': enable,
        'target': target,
        'window': window,
        'indicator': indicator,
        'latency_threshold': latencyThreshold,
        'template': template,
        'journey': journey,
        'error_query': errorQuery,
        'total_query': totalQuery,
      }),
    );
    return response.statusCode == 200;
  }

  /// Disables/deletes an SLO configuration for a service.
  static Future<bool> deleteSLO(String serviceId) async {
    final response = await http.delete(Uri.parse('/api/slo/$serviceId'));
    return response.statusCode == 200;
  }

  /// Fetches SLO notification configuration (Email, Webhook).
  static Future<Map<String, dynamic>> fetchSLONotifyConfig() async {
    final response = await http.get(Uri.parse('/api/slo/notify/config'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {};
  }

  /// Saves SLO notification configuration (Email, Webhook).
  static Future<bool> saveSLONotifyConfig(Map<String, dynamic> config) async {
    final response = await http.post(
      Uri.parse('/api/slo/notify/config'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(config),
    );
    return response.statusCode == 200;
  }

  /// Dispatches a test SLO alert notification (email or webhook).
  static Future<Map<String, dynamic>> testSLONotify(String channel) async {
    final response = await http.post(
      Uri.parse('/api/slo/notify/test'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'channel': channel}),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Fetches all deployed services from state.
  static Future<List<Service>> fetchServices() async {
    final state = await ApiService.fetchState();
    return state.services;
  }

  /// Caddy: Fetches Caddy status and stats for a given node.
  static Future<Map<String, dynamic>> fetchCaddyStatus({String? nodeId}) async {
    final uri = Uri.parse('/api/caddy/status${nodeId != null ? '?node_id=$nodeId' : ''}');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {};
  }

  /// Caddy: Fetches dynamic routes matrix.
  static Future<List<dynamic>> fetchCaddyRoutes({String? nodeId}) async {
    final uri = Uri.parse('/api/caddy/routes${nodeId != null ? '?node_id=$nodeId' : ''}');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['routes'] ?? [];
    }
    return [];
  }

  /// Caddy: Fetches TLS certs list.
  static Future<List<dynamic>> fetchCaddyCerts({String? nodeId}) async {
    final uri = Uri.parse('/api/caddy/certs${nodeId != null ? '?node_id=$nodeId' : ''}');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['certificates'] ?? [];
    }
    return [];
  }

  /// Caddy: Fetches tail logs.
  static Future<List<String>> fetchCaddyLogs({String? nodeId}) async {
    final uri = Uri.parse('/api/caddy/logs${nodeId != null ? '?node_id=$nodeId' : ''}');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List raw = data['logs'] ?? [];
      return raw.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// Caddy: Fetches Prometheus metrics.
  static Future<Map<String, dynamic>> fetchCaddyMetrics({String? nodeId}) async {
    final uri = Uri.parse('/api/caddy/metrics${nodeId != null ? '?node_id=$nodeId' : ''}');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {};
  }

  /// Caddy: Formats Caddyfile content via caddy fmt.
  static Future<String> formatCaddyfile(String caddyfile) async {
    final response = await http.post(
      Uri.parse('/api/caddy/fmt'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'caddyfile': caddyfile}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['formatted'] ?? caddyfile;
    }
    return caddyfile;
  }

  /// Caddy: Inspects full X.509 certificate details for a domain.
  static Future<Map<String, dynamic>?> inspectCaddyCert(String domain, {String? nodeId}) async {
    final uri = Uri.parse('/api/caddy/certs/inspect?domain=${Uri.encodeComponent(domain)}${nodeId != null ? '&node_id=$nodeId' : ''}');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['certificate'];
    }
    return null;
  }

  /// Caddy: Forces certificate renewal/rotation for a domain.
  static Future<Map<String, dynamic>> renewCaddyCert(String domain, {String? nodeId}) async {
    final uri = Uri.parse('/api/caddy/certs/renew${nodeId != null ? '?node_id=$nodeId' : ''}');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'domain': domain}),
    );
    return jsonDecode(response.body);
  }

  /// Caddy: Installs a custom TLS certificate and private key.
  static Future<Map<String, dynamic>> uploadCustomCaddyCert(
    String domain,
    String certPem,
    String keyPem, {
    String? nodeId,
  }) async {
    final uri = Uri.parse('/api/caddy/certs/custom${nodeId != null ? '?node_id=$nodeId' : ''}');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'domain': domain,
        'cert_pem': certPem,
        'key_pem': keyPem,
      }),
    );
    return jsonDecode(response.body);
  }

  /// Caddy: Prunes orphaned certificates no longer referenced in Caddyfile.
  static Future<Map<String, dynamic>> pruneOrphanedCaddyCerts({String? nodeId}) async {
    final uri = Uri.parse('/api/caddy/certs/orphaned${nodeId != null ? '?node_id=$nodeId' : ''}');
    final response = await http.delete(uri);
    return jsonDecode(response.body);
  }

  /// Caddy: Synchronizes all TLS certificates across all active cluster nodes.
  static Future<Map<String, dynamic>> syncCaddyCerts() async {
    final response = await http.post(Uri.parse('/api/caddy/certs/sync'), headers: authHeaders);
    return jsonDecode(response.body);
  }

  // ─────────────────────────────────────────────────────────────
  // Caddy Ingress WAF & Threat Shield APIs (v2.94.0)
  // ─────────────────────────────────────────────────────────────

  /// WAF: Fetches global Threat Shield configuration.
  static Future<Map<String, dynamic>> fetchWAFConfig() async {
    final response = await http.get(Uri.parse('/api/caddy/waf/config'), headers: authHeaders);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {};
  }

  /// WAF: Updates global Threat Shield configuration.
  static Future<Map<String, dynamic>> updateWAFConfig(Map<String, dynamic> config) async {
    final response = await http.post(
      Uri.parse('/api/caddy/waf/config'),
      headers: authHeaders,
      body: jsonEncode(config),
    );
    return jsonDecode(response.body);
  }

  /// WAF: Fetches cluster-wide Threat Shield aggregate statistics.
  static Future<Map<String, dynamic>> fetchWAFStats() async {
    final response = await http.get(Uri.parse('/api/caddy/waf/stats'), headers: authHeaders);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {};
  }

  /// WAF: Fetches per-route WAF rules and overrides.
  static Future<List<dynamic>> fetchWAFRoutes() async {
    final response = await http.get(Uri.parse('/api/caddy/waf/routes'), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['routes'] ?? [];
    }
    return [];
  }

  /// WAF: Toggles WAF state and mode for a specific ingress route ("A Mano").
  static Future<Map<String, dynamic>> toggleRouteWAF(String host, bool enabled, String mode) async {
    final response = await http.post(
      Uri.parse('/api/caddy/waf/routes/toggle'),
      headers: authHeaders,
      body: jsonEncode({
        'host': host,
        'enabled': enabled,
        'mode': mode,
      }),
    );
    return jsonDecode(response.body);
  }

  /// WAF: Clears manual route override, restoring cluster default.
  static Future<Map<String, dynamic>> deleteRouteWAF(String host) async {
    final response = await http.delete(
      Uri.parse('/api/caddy/waf/routes/${Uri.encodeComponent(host)}'),
      headers: authHeaders,
    );
    return jsonDecode(response.body);
  }

  /// WAF: Fetches intercepted security threat events.
  static Future<List<dynamic>> fetchWAFEvents({int limit = 50, String? type, String? host}) async {
    var url = '/api/caddy/waf/events?limit=$limit';
    if (type != null && type.isNotEmpty && type != 'ALL') {
      url += '&type=${Uri.encodeComponent(type)}';
    }
    if (host != null && host.isNotEmpty && host != 'ALL') {
      url += '&host=${Uri.encodeComponent(host)}';
    }
    final response = await http.get(Uri.parse(url), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['events'] ?? [];
    }
    return [];
  }

  /// WAF: Adds an IP or CIDR to the Threat Shield blacklist.
  static Future<Map<String, dynamic>> blockWAFIP(String ip, String reason) async {
    final response = await http.post(
      Uri.parse('/api/caddy/waf/ip/block'),
      headers: authHeaders,
      body: jsonEncode({
        'ip': ip,
        'reason': reason,
      }),
    );
    return jsonDecode(response.body);
  }

  /// WAF: Removes an IP or CIDR from the Threat Shield blacklist.
  static Future<Map<String, dynamic>> unblockWAFIP(String ip) async {
    final response = await http.post(
      Uri.parse('/api/caddy/waf/ip/unblock'),
      headers: authHeaders,
      body: jsonEncode({
        'ip': ip,
      }),
    );
    return jsonDecode(response.body);
  }

  /// WAF: Simulates a penetration test probe through Threat Shield.
  static Future<Map<String, dynamic>> simulateWAFThreat(String host, String vector) async {
    final response = await http.post(
      Uri.parse('/api/caddy/waf/test'),
      headers: authHeaders,
      body: jsonEncode({
        'host': host,
        'vector': vector,
      }),
    );
    return jsonDecode(response.body);
  }

  /// Checks status and readiness of Loki aggregator.
  static Future<Map<String, dynamic>> fetchLokiStatus() async {
    try {
      final response = await http.get(Uri.parse("/api/logs/status"), headers: authHeaders);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return {"active": false, "driver": "docker_fallback"};
  }

  /// Fetches available containers, nodes, stacks, and streams for Loki filters.
  static Future<LokiLabelsResponse> fetchLokiLogLabels() async {
    try {
      final response = await http.get(Uri.parse("/api/logs/labels"), headers: authHeaders);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LokiLabelsResponse.fromJson(data);
      }
    } catch (_) {}
    return LokiLabelsResponse(containers: [], nodes: [], stacks: [], streams: [], levels: []);
  }

  /// Queries logs with multi-dimensional filtering.
  static Future<Map<String, dynamic>> queryLokiLogs({
    String query = "",
    String container = "",
    String node = "",
    String stack = "",
    String stream = "",
    String level = "",
    String timeRange = "1h",
    int limit = 200,
  }) async {
    try {
      List<String> params = [];
      if (query.isNotEmpty) params.add("query=${Uri.encodeQueryComponent(query)}");
      if (container.isNotEmpty) params.add("container=${Uri.encodeQueryComponent(container)}");
      if (node.isNotEmpty) params.add("node=${Uri.encodeQueryComponent(node)}");
      if (stack.isNotEmpty) params.add("stack=${Uri.encodeQueryComponent(stack)}");
      if (stream.isNotEmpty) params.add("stream=${Uri.encodeQueryComponent(stream)}");
      if (level.isNotEmpty) params.add("level=${Uri.encodeQueryComponent(level)}");
      params.add("range=$timeRange");
      params.add("limit=$limit");

      var url = "/api/logs/query";
      if (params.isNotEmpty) {
        url += "?${params.join("&")}";
      }

      final response = await http.get(Uri.parse(url), headers: authHeaders);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data["logs"] as List? ?? [])
            .map((e) => LokiLogEntry.fromJson(e))
            .toList();
        return {
          "status": data["status"] ?? "success",
          "driver": data["driver"] ?? "loki",
          "total": data["total"] ?? list.length,
          "logs": list,
        };
      }
    } catch (_) {}
    return {"status": "error", "driver": "none", "total": 0, "logs": <LokiLogEntry>[]};
  }

  /// Fetches SRE Observability architecture profiles.
  static Future<Map<String, dynamic>> getMonitorProfiles() async {
    final response = await http.get(
      Uri.parse('/api/monitor/profiles'),
      headers: authHeaders,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load monitor profiles: ${response.statusCode}');
  }

  /// Switches active SRE Observability stack architecture profile.
  static Future<Map<String, dynamic>> switchMonitorProfile(String profileId) async {
    final response = await http.post(
      Uri.parse('/api/monitor/profiles/switch'),
      headers: authHeaders,
      body: jsonEncode({'profile': profileId}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Failed to switch SRE profile');
  }

  // ── eBPF Live Hub & Kernel Network Observability ───────────────────────────

  /// Fetches global eBPF kernel stats and telemetry counters.
  static Future<EbpfStats> fetchEbpfStats() async {
    final response = await http.get(Uri.parse('/api/ebpf/stats'), headers: authHeaders);
    if (response.statusCode == 200) {
      return EbpfStats.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch eBPF stats: ${response.statusCode}');
  }

  /// Fetches recent captured L4/L7 network flows.
  static Future<List<EbpfFlow>> fetchEbpfFlows({
    int limit = 50,
    String? protocol,
    String? status,
    String? query,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (protocol != null && protocol.isNotEmpty && protocol != 'ALL') {
      params['protocol'] = protocol;
    }
    if (status != null && status.isNotEmpty && status != 'ALL') {
      params['status'] = status;
    }
    if (query != null && query.isNotEmpty) {
      params['q'] = query;
    }
    final uri = Uri.parse('/api/ebpf/flows').replace(queryParameters: params);
    final response = await http.get(uri, headers: authHeaders);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map((item) => EbpfFlow.fromJson(item)).toList();
      }
      return [];
    }
    throw Exception('Failed to fetch eBPF flows: ${response.statusCode}');
  }

  /// Fetches synthesized eBPF service mesh topology graph.
  static Future<EbpfTopology> fetchEbpfTopology() async {
    final response = await http.get(Uri.parse('/api/ebpf/topology'), headers: authHeaders);
    if (response.statusCode == 200) {
      return EbpfTopology.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch eBPF topology: ${response.statusCode}');
  }

  /// Triggers on-demand eBPF traffic simulation.
  static Future<bool> simulateEbpfTraffic({
    String pattern = 'burst',
    int rate = 15,
    int durationS = 10,
    double errorPct = 0.0,
  }) async {
    final response = await http.post(
      Uri.parse('/api/ebpf/simulate'),
      headers: authHeaders,
      body: jsonEncode({
        'pattern': pattern,
        'rate': rate,
        'duration_s': durationS,
        'error_pct': errorPct,
      }),
    );
    return response.statusCode == 200;
  }
}

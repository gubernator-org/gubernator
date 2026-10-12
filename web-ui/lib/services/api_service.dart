import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import '../models/models.dart';


part 'api/cluster_api_part.dart';
part 'api/observability_waf_api_part.dart';
part 'api/auth_security_api_part.dart';
part 'api/storage_gluster_api_part.dart';
part 'api/image_compliance_api_part.dart';

/// Service class to communicate with the Gubernator backend API.
class ApiService {
  static String? _authToken;

  static String? get authToken {
    if (_authToken != null && _authToken!.isNotEmpty) {
      return _authToken;
    }
    try {
      _authToken = html.window.localStorage['gbnt_token'];
    } catch (_) {}
    return _authToken;
  }

  static set authToken(String? token) {
    _authToken = token;
    try {
      if (token != null && token.isNotEmpty) {
        html.window.localStorage['gbnt_token'] = token;
      } else {
        html.window.localStorage.remove('gbnt_token');
      }
    } catch (_) {}
  }

  static Map<String, String> get authHeaders {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = authToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }


  /// Fetches the full dashboard state from the backend.
  static Future<DashboardState> fetchState() => ClusterApi.fetchState();

  /// Fetches all cluster Centurion nodes.
  static Future<List<Node>> fetchNodes() => ClusterApi.fetchNodes();

  /// Deletes a stack and stops all its containers.
  static Future<bool> deleteStack(String id) => ClusterApi.deleteStack(id);

  /// Stops all containers in a stack without deleting it.
  static Future<bool> stopStack(String id) => ClusterApi.stopStack(id);

  /// Starts all containers in a stopped stack.
  static Future<bool> startStack(String id) => ClusterApi.startStack(id);

  /// Redeploys a stack.
  static Future<bool> redeployStack(String id) => ClusterApi.redeployStack(id);

  /// Restarts all containers in a stack.
  static Future<bool> restartStack(String id) => ClusterApi.restartStack(id);

  /// Reconciles a single stack, purging dead/stale containers and aligning tasks with desired replicas.
  static Future<Map<String, dynamic>?> reconcileStack(String id) => ClusterApi.reconcileStack(id);

  /// Updates horizontal autoscaling configuration for a specific service.
  static Future<bool> updateServiceAutoscale(String serviceId, Map<String, dynamic> config) => ClusterApi.updateServiceAutoscale(serviceId, config);

  /// Updates horizontal autoscaling configuration for all services in a stack.
  static Future<bool> updateStackAutoscale(String stackId, Map<String, dynamic> config) => ClusterApi.updateStackAutoscale(stackId, config);

  /// Prunes all dead, duplicate, and orphan containers across the cluster.
  static Future<Map<String, dynamic>?> pruneTasks() => ClusterApi.pruneTasks();

  /// Deploys a stack with full conflict detection and resolution options.
  static Future<DeployStackResult> deployStackDetailed(
    String name,
    String compose, {
    String? targetNode,
    bool force = false,
    bool autoRemapPorts = false,
  }) => ClusterApi.deployStackDetailed(name, compose, targetNode: targetNode, force: force, autoRemapPorts: autoRemapPorts);

  static Future<String?> deployStack(
    String name,
    String compose, {
    String? targetNode,
    bool force = false,
    bool autoRemapPorts = false,
  }) => ClusterApi.deployStack(name, compose, targetNode: targetNode, force: force, autoRemapPorts: autoRemapPorts);

  /// Saves stack compose definition into DB and ~/.gbnt/stacks/ without deploying/launching containers.
  static Future<Map<String, dynamic>> saveStack({
    required String name,
    required String compose,
    String? stackId,
    String? targetNode,
  }) => ClusterApi.saveStack(name: name, compose: compose, stackId: stackId, targetNode: targetNode);

  /// Lists Compose stack files found on the Master server host.
  static Future<Map<String, dynamic>> fetchServerStackFiles({String? dir}) => ClusterApi.fetchServerStackFiles(dir: dir);

  /// Reads a Compose stack file from the Master server filesystem.
  static Future<Map<String, dynamic>> fetchServerStackFile(String path) => ClusterApi.fetchServerStackFile(path);

  /// Deploys a stack directly from a Master server file path.
  static Future<String?> deployServerStack(String path, {String? name, String? targetNode}) => ClusterApi.deployServerStack(path, name: name, targetNode: targetNode);

  /// Saves or updates a Compose stack file directly on the Master server filesystem.
  static Future<Map<String, dynamic>> saveServerStackFile({
    required String content,
    String? name,
    String? filename,
    String? dir,
  }) => ClusterApi.saveServerStackFile(content: content, name: name, filename: filename, dir: dir);

  /// Retrieves the list of built-in POC examples and blueprints.
  static Future<List<POCExampleModel>> fetchPOCExamples() => ClusterApi.fetchPOCExamples();

  /// Deploys one or all POC examples into the cluster.
  static Future<String?> deployPOCExample(String id, {String? targetNode}) => ClusterApi.deployPOCExample(id, targetNode: targetNode);

  /// Stops/removes a single task.
  static Future<bool> deleteTask(String id) => ClusterApi.deleteTask(id);

  /// Fetches container output logs or diagnostics for a given task ID.
  static Future<String> getTaskLogs(String taskId) => ClusterApi.getTaskLogs(taskId);

  /// Migrates a stack to a target node.
  static Future<bool> migrateStack(String stackId, String targetNode) => ClusterApi.migrateStack(stackId, targetNode);

  /// Provision and add a remote worker host via SSH.
  static Future<String?> addHost(String host, String user, String password) => ClusterApi.addHost(host, user, password);

  /// Fetches cluster join info and commands
  static Future<NodeJoinInfo?> fetchJoinInfo() => ClusterApi.fetchJoinInfo();

  /// Provision a remote host via SSH with step logs
  static Future<NodeProvisionResult> provisionNode({
    required String host,
    String port = '22',
    required String user,
    String authType = 'password',
    String password = '',
    String privateKey = '',
    bool deploySystemStacks = true,
  }) => ClusterApi.provisionNode(host: host, port: port, user: user, authType: authType, password: password, privateKey: privateKey, deploySystemStacks: deploySystemStacks);

  /// Sends an action (pause, unpause, restart, start, stop) to a task
  static Future<bool> taskAction(String id, String action) => ClusterApi.taskAction(id, action);

  /// Gets tail logs for a task
  static Future<String> taskLogs(String id) => ClusterApi.taskLogs(id);

  /// Gets inspect JSON for a task
  static Future<String> taskInspect(String id) => ClusterApi.taskInspect(id);

  /// Gets the compose YAML for a specific stack.
  static Future<String> getStackCompose(String id) => ClusterApi.getStackCompose(id);

  /// Saves updated compose YAML for a stack.
  static Future<bool> updateStackCompose(String id, String compose) => ClusterApi.updateStackCompose(id, compose);

  /// Fetches user settings from the backend.
  static Future<Map<String, dynamic>> getSettings() => ClusterApi.getSettings();

  /// Updates user settings on the backend.
  static Future<bool> updateSettings(Map<String, dynamic> settings) => ClusterApi.updateSettings(settings);

  /// Changes the web dashboard password.
  static Future<bool> changePassword(
      String currentPassword, String newPassword) => ClusterApi.changePassword(currentPassword, newPassword);

  /// Updates a node's role (promote/demote). Deprecated in single-manager architecture.
  @Deprecated('Deprecated in single-manager architecture')
  static Future<bool> updateNodeRole(String id, String role) => ClusterApi.updateNodeRole(id, role);

  /// Updates a node's availability status. Returns parsed response Map.
  static Future<Map<String, dynamic>> updateNodeAvailability(String id, String availability) => ClusterApi.updateNodeAvailability(id, availability);

  /// Synchronizes the active authentication token to the remote worker node via SSH.
  static Future<Map<String, dynamic>> syncNodeToken(String id) => ClusterApi.syncNodeToken(id);

  /// Commands the node to leave the cluster.
  static Future<bool> leaveNode(String id) => ClusterApi.leaveNode(id);

  /// Triggers a reboot for the node.
  static Future<bool> rebootNode(String id) => ClusterApi.rebootNode(id);

  /// Updates a node's labels.
  static Future<bool> updateNodeLabels(String id, Map<String, String> labels) => ClusterApi.updateNodeLabels(id, labels);

  /// Gets the CoreDNS configuration (Corefile).
  static Future<String> getCoreDNSConfig() => ClusterApi.getCoreDNSConfig();

  /// Updates the CoreDNS configuration (Corefile).
  static Future<bool> updateCoreDNSConfig(String config) => ClusterApi.updateCoreDNSConfig(config);

  /// Fetches CoreDNS status and memory usage.
  static Future<CoreDNSStatusInfo> fetchCoreDNSStatusInfo() => ClusterApi.fetchCoreDNSStatusInfo();

  /// Fetches custom static DNS records.
  static Future<List<CustomDNSRecord>> fetchCustomDNSRecords() => ClusterApi.fetchCustomDNSRecords();

  /// Creates a custom static DNS record.
  static Future<bool> createCustomDNSRecord({
    required String domain,
    required String ip,
    String recordType = 'A',
    int ttl = 60,
  }) => ClusterApi.createCustomDNSRecord(domain: domain, ip: ip, recordType: recordType, ttl: ttl);

  /// Deletes a custom static DNS record.
  static Future<bool> deleteCustomDNSRecord(String id) => ClusterApi.deleteCustomDNSRecord(id);

  /// Performs an interactive DNS query test (Dig / Nslookup).
  static Future<DNSDigResult> performDNSDig({
    required String domain,
    String recordType = 'A',
  }) => ClusterApi.performDNSDig(domain: domain, recordType: recordType);

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
  }) => ClusterApi.performDNSCurl(hostname: hostname, ip: ip, protocol: protocol, port: port, path: path, method: method, followRedirect: followRedirect, insecure: insecure, timeoutSeconds: timeoutSeconds);

  /// Performs an ICMP reachability / latency ping test against a domain or IP.
  static Future<DNSPingResult> performDNSPing({
    required String hostname,
    String ip = '',
    int count = 3,
  }) => ClusterApi.performDNSPing(hostname: hostname, ip: ip, count: count);

  /// Fetches the configured base cluster domain.
  static Future<String> fetchClusterDomain() => ClusterApi.fetchClusterDomain();

  /// Updates the base cluster domain.
  static Future<bool> updateClusterDomain(String domain) => ClusterApi.updateClusterDomain(domain);

  /// Fetches status of Weave Scope Network Topology superpower.
  static Future<Map<String, dynamic>> fetchScopeStatus() => ClusterApi.fetchScopeStatus();

  /// Enables Weave Scope container.
  static Future<bool> enableScope() => ClusterApi.enableScope();

  /// Disables Weave Scope container.
  static Future<bool> disableScope() => ClusterApi.disableScope();

  /// Updates and pulls latest Weave Scope container image from Docker Hub.
  static Future<Map<String, dynamic>> updateScopeImage() => ClusterApi.updateScopeImage();

  /// Triggers cluster auto-update.
  static Future<bool> applyUpdate(String targetVersion) => ClusterApi.applyUpdate(targetVersion);

  /// Fetches latest release check from backend /api/system/update/check with optional force refresh.
  static Future<Map<String, dynamic>> fetchUpdateCheck({bool force = false}) => ClusterApi.fetchUpdateCheck(force: force);

  /// Fetches live status of an ongoing or recent update.
  static Future<Map<String, dynamic>> fetchUpdateStatus() => ClusterApi.fetchUpdateStatus();

  /// Fetches active SLO definitions and error budgets.
  static Future<List<SLOItem>> fetchSLOs() => ObservabilityWafApi.fetchSLOs();

  /// Force syncs SLO rules with Prometheus.
  static Future<bool> syncSLOs() => ObservabilityWafApi.syncSLOs();

  /// Fetches aggregated User Journeys.
  static Future<List<UserJourney>> fetchUserJourneys() => ObservabilityWafApi.fetchUserJourneys();

  /// Fetches deployment events correlation.
  static Future<List<SLOCorrelationEvent>> fetchSLOCorrelations() => ObservabilityWafApi.fetchSLOCorrelations();

  /// Validates Compose YAML and runs PromQL backtest.
  static Future<List<SLOValidationItem>> validateSLO(String composeRaw) => ObservabilityWafApi.validateSLO(composeRaw);

  /// Fetches historical trend points for an SLO.
  static Future<List<SLOHistoryPoint>> fetchSLOHistory(String serviceId, String timeRange) => ObservabilityWafApi.fetchSLOHistory(serviceId, timeRange);

  /// Fetches RED metrics for a service.
  static Future<SLOREDMetrics> fetchSLOREDMetrics(String serviceId) => ObservabilityWafApi.fetchSLOREDMetrics(serviceId);

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
  }) => ObservabilityWafApi.editSLO(serviceId: serviceId, enable: enable, target: target, window: window, indicator: indicator, latencyThreshold: latencyThreshold, template: template, journey: journey, errorQuery: errorQuery, totalQuery: totalQuery);

  /// Disables/deletes an SLO configuration for a service.
  static Future<bool> deleteSLO(String serviceId) => ObservabilityWafApi.deleteSLO(serviceId);

  /// Fetches SLO notification configuration (Email, Webhook).
  static Future<Map<String, dynamic>> fetchSLONotifyConfig() => ObservabilityWafApi.fetchSLONotifyConfig();

  /// Saves SLO notification configuration (Email, Webhook).
  static Future<bool> saveSLONotifyConfig(Map<String, dynamic> config) => ObservabilityWafApi.saveSLONotifyConfig(config);

  /// Dispatches a test SLO alert notification (email or webhook).
  static Future<Map<String, dynamic>> testSLONotify(String channel) => ObservabilityWafApi.testSLONotify(channel);

  /// Fetches all deployed services from state.
  static Future<List<Service>> fetchServices() => ObservabilityWafApi.fetchServices();

  /// Caddy: Fetches Caddy status and stats for a given node.
  static Future<Map<String, dynamic>> fetchCaddyStatus({String? nodeId}) => ObservabilityWafApi.fetchCaddyStatus(nodeId: nodeId);

  /// Caddy: Fetches dynamic routes matrix.
  static Future<List<dynamic>> fetchCaddyRoutes({String? nodeId}) => ObservabilityWafApi.fetchCaddyRoutes(nodeId: nodeId);

  /// Caddy: Fetches TLS certs list.
  static Future<List<dynamic>> fetchCaddyCerts({String? nodeId}) => ObservabilityWafApi.fetchCaddyCerts(nodeId: nodeId);

  /// Caddy: Fetches tail logs.
  static Future<List<String>> fetchCaddyLogs({String? nodeId}) => ObservabilityWafApi.fetchCaddyLogs(nodeId: nodeId);

  /// Caddy: Fetches Prometheus metrics.
  static Future<Map<String, dynamic>> fetchCaddyMetrics({String? nodeId}) => ObservabilityWafApi.fetchCaddyMetrics(nodeId: nodeId);

  /// Caddy: Formats Caddyfile content via caddy fmt.
  static Future<String> formatCaddyfile(String caddyfile) => ObservabilityWafApi.formatCaddyfile(caddyfile);

  /// Caddy: Inspects full X.509 certificate details for a domain.
  static Future<Map<String, dynamic>?> inspectCaddyCert(String domain, {String? nodeId}) => ObservabilityWafApi.inspectCaddyCert(domain, nodeId: nodeId);

  /// Caddy: Forces certificate renewal/rotation for a domain.
  static Future<Map<String, dynamic>> renewCaddyCert(String domain, {String? nodeId}) => ObservabilityWafApi.renewCaddyCert(domain, nodeId: nodeId);

  /// Caddy: Installs a custom TLS certificate and private key.
  static Future<Map<String, dynamic>> uploadCustomCaddyCert(
    String domain,
    String certPem,
    String keyPem, {
    String? nodeId,
  }) => ObservabilityWafApi.uploadCustomCaddyCert(domain, certPem, keyPem, nodeId: nodeId);

  /// Caddy: Prunes orphaned certificates no longer referenced in Caddyfile.
  static Future<Map<String, dynamic>> pruneOrphanedCaddyCerts({String? nodeId}) => ObservabilityWafApi.pruneOrphanedCaddyCerts(nodeId: nodeId);

  /// Caddy: Synchronizes all TLS certificates across all active cluster nodes.
  static Future<Map<String, dynamic>> syncCaddyCerts() => ObservabilityWafApi.syncCaddyCerts();

  /// WAF: Fetches global Threat Shield configuration.
  static Future<Map<String, dynamic>> fetchWAFConfig() => ObservabilityWafApi.fetchWAFConfig();

  /// WAF: Updates global Threat Shield configuration.
  static Future<Map<String, dynamic>> updateWAFConfig(Map<String, dynamic> config) => ObservabilityWafApi.updateWAFConfig(config);

  /// WAF: Fetches cluster-wide Threat Shield aggregate statistics.
  static Future<Map<String, dynamic>> fetchWAFStats() => ObservabilityWafApi.fetchWAFStats();

  /// WAF: Fetches per-route WAF rules and overrides.
  static Future<List<dynamic>> fetchWAFRoutes() => ObservabilityWafApi.fetchWAFRoutes();

  /// WAF: Toggles WAF state and mode for a specific ingress route ("A Mano").
  static Future<Map<String, dynamic>> toggleRouteWAF(String host, bool enabled, String mode) => ObservabilityWafApi.toggleRouteWAF(host, enabled, mode);

  /// WAF: Clears manual route override, restoring cluster default.
  static Future<Map<String, dynamic>> deleteRouteWAF(String host) => ObservabilityWafApi.deleteRouteWAF(host);

  /// WAF: Fetches intercepted security threat events.
  static Future<List<dynamic>> fetchWAFEvents({int limit = 50, String? type, String? host}) => ObservabilityWafApi.fetchWAFEvents(limit: limit, type: type, host: host);

  /// WAF: Adds an IP or CIDR to the Threat Shield blacklist.
  static Future<Map<String, dynamic>> blockWAFIP(String ip, String reason) => ObservabilityWafApi.blockWAFIP(ip, reason);

  /// WAF: Removes an IP or CIDR from the Threat Shield blacklist.
  static Future<Map<String, dynamic>> unblockWAFIP(String ip) => ObservabilityWafApi.unblockWAFIP(ip);

  /// WAF: Simulates a penetration test probe through Threat Shield.
  static Future<Map<String, dynamic>> simulateWAFThreat(String host, String vector) => ObservabilityWafApi.simulateWAFThreat(host, vector);

  /// Fetches available identity providers (Local Admin + Active Directory/LDAP).
  static Future<List<AuthProvider>> fetchAuthProviders() => AuthSecurityApi.fetchAuthProviders();

  /// Logs in against Local Admin or an Active Directory/LDAP provider.
  static Future<Map<String, dynamic>> login(
    String username,
    String password, {
    String? provider,
  }) => AuthSecurityApi.login(username, password, provider: provider);

  /// Sends a client time beacon to the server to detect and correct VM sleep clock drift.
  static Future<Map<String, dynamic>?> sendTimeBeacon() => AuthSecurityApi.sendTimeBeacon();

  /// Completes MFA login verification using TOTP 6-digit code or recovery code.
  static Future<Map<String, dynamic>> verifyMFA({
    required String mfaToken,
    required String code,
  }) => AuthSecurityApi.verifyMFA(mfaToken: mfaToken, code: code);

  /// Completes initial MFA setup during login when MFA is enforced (ENS op.acc.6)
  static Future<Map<String, dynamic>> completeEnforcedMFASetup({
    required String mfaToken,
    required String secret,
    required String code,
    List<String>? backupCodes,
  }) => AuthSecurityApi.completeEnforcedMFASetup(mfaToken: mfaToken, secret: secret, code: code, backupCodes: backupCodes);

  /// Initiates MFA setup for current user or admin target user.
  static Future<Map<String, dynamic>> setupMFA({String? userId}) => AuthSecurityApi.setupMFA(userId: userId);

  /// Confirms and enables MFA with the first generated TOTP code.
  static Future<Map<String, dynamic>> enableMFA({
    String? userId,
    required String secret,
    required String code,
    List<String>? backupCodes,
  }) => AuthSecurityApi.enableMFA(userId: userId, secret: secret, code: code, backupCodes: backupCodes);

  /// Disables MFA for user.
  static Future<Map<String, dynamic>> disableMFA({
    String? userId,
    String? code,
  }) => AuthSecurityApi.disableMFA(userId: userId, code: code);

  /// Fetches the currently authenticated user profile and permissions.
  static Future<UserSession?> fetchMe() => AuthSecurityApi.fetchMe();

  /// Logs out the user and clears stored session tokens.
  static Future<void> logout({String? reason}) => AuthSecurityApi.logout(reason: reason);

  /// Fetches all configured LDAP / Active Directory servers (Admin only).
  static Future<List<LDAPConfig>> fetchLDAPConfigs() => AuthSecurityApi.fetchLDAPConfigs();

  /// Creates or updates an LDAP / Active Directory configuration.
  static Future<Map<String, dynamic>> saveLDAPConfig(LDAPConfig config) => AuthSecurityApi.saveLDAPConfig(config);

  /// Deletes an LDAP / Active Directory configuration.
  static Future<bool> deleteLDAPConfig(String id) => AuthSecurityApi.deleteLDAPConfig(id);

  /// Tests connectivity and optional user credentials against an LDAP configuration.
  static Future<LDAPTestResult> testLDAPConfig(
    LDAPConfig config, {
    String testUsername = '',
    String testPassword = '',
  }) => AuthSecurityApi.testLDAPConfig(config, testUsername: testUsername, testPassword: testPassword);

  /// Fetches all configured OIDC / SSO providers (Admin only).
  static Future<List<OIDCConfig>> fetchOIDCConfigs() => AuthSecurityApi.fetchOIDCConfigs();

  /// Fetches built-in OIDC provider presets (Keycloak, Google, Azure, etc.).
  static Future<List<OIDCProviderPreset>> fetchOIDCPresets() => AuthSecurityApi.fetchOIDCPresets();

  /// Creates or updates an OIDC provider configuration.
  static Future<Map<String, dynamic>> saveOIDCConfig(OIDCConfig config) => AuthSecurityApi.saveOIDCConfig(config);

  /// Deletes an OIDC provider configuration.
  static Future<bool> deleteOIDCConfig(String id) => AuthSecurityApi.deleteOIDCConfig(id);

  /// Tests connectivity to an OIDC provider's discovery endpoint and JWKS.
  static Future<OIDCTestResult> testOIDCConfig(OIDCConfig config) => AuthSecurityApi.testOIDCConfig(config);

  /// Requests an OAuth2 authorization URL to begin the SSO login flow.
  /// Returns the auth_url to open in the browser and the state token.
  static Future<Map<String, dynamic>> getOIDCAuthorizeUrl(String providerId) => AuthSecurityApi.getOIDCAuthorizeUrl(providerId);

  /// Fetches all local user accounts.
  static Future<List<LocalUser>> fetchLocalUsers() => AuthSecurityApi.fetchLocalUsers();

  /// Creates a new local user.
  static Future<Map<String, dynamic>> createLocalUser({
    required String username,
    required String password,
    required String displayName,
    required String email,
    required String role,
    required bool enabled,
  }) => AuthSecurityApi.createLocalUser(username: username, password: password, displayName: displayName, email: email, role: role, enabled: enabled);

  /// Updates an existing local user.
  static Future<Map<String, dynamic>> updateLocalUser(LocalUser user) => AuthSecurityApi.updateLocalUser(user);

  /// Toggles suspension status of a local user account.
  static Future<Map<String, dynamic>> toggleLocalUserStatus(String id, {bool? enabled}) => AuthSecurityApi.toggleLocalUserStatus(id, enabled: enabled);

  /// Resets a local user password.
  static Future<Map<String, dynamic>> resetLocalUserPassword(String id, String newPassword) => AuthSecurityApi.resetLocalUserPassword(id, newPassword);

  /// Administratively unlocks a locked local user account (ENS op.acc.2).
  static Future<Map<String, dynamic>> unlockLocalUser(String id) => AuthSecurityApi.unlockLocalUser(id);

  /// Deletes a local user account.
  static Future<bool> deleteLocalUser(String id) => AuthSecurityApi.deleteLocalUser(id);

  /// Fetches access and audit logs.
  static Future<List<AuditLog>> fetchAuditLogs({String provider = "", String action = ""}) => AuthSecurityApi.fetchAuditLogs(provider: provider, action: action);

  /// Fetches cluster SIEM and ENS security configuration.
  static Future<SIEMConfig?> fetchSIEMConfig() => AuthSecurityApi.fetchSIEMConfig();

  /// Fetches cluster SIEM delivery metrics, connection health, and ENS compliance status.
  static Future<SIEMStatusResponse?> fetchSIEMStatus() => AuthSecurityApi.fetchSIEMStatus();

  /// Saves cluster SIEM and ENS security configuration.
  static Future<Map<String, dynamic>> saveSIEMConfig(SIEMConfig config) => AuthSecurityApi.saveSIEMConfig(config);

  /// Sends a live SIEM test syslog/CEF probe.
  static Future<Map<String, dynamic>> testSIEMConnection(SIEMConfig config) => AuthSecurityApi.testSIEMConnection(config);

  /// Verifies cryptographic SHA-256 integrity of the audit trail (ENS op.mon.1).
  static Future<AuditVerificationResult> verifyAuditChain() => AuthSecurityApi.verifyAuditChain();

  /// Downloads export file of the forensic audit trail (CSV, JSON, LOG).
  static Future<void> downloadAuditLogsExport(String format) => AuthSecurityApi.downloadAuditLogsExport(format);

  /// Checks status and readiness of Loki aggregator.
  static Future<Map<String, dynamic>> fetchLokiStatus() => ObservabilityWafApi.fetchLokiStatus();

  /// Fetches available containers, nodes, stacks, and streams for Loki filters.
  static Future<LokiLabelsResponse> fetchLokiLogLabels() => ObservabilityWafApi.fetchLokiLogLabels();

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
  }) => ObservabilityWafApi.queryLokiLogs(query: query, container: container, node: node, stack: stack, stream: stream, level: level, timeRange: timeRange, limit: limit);

  /// Fetches all cluster persistent volumes, docker volumes, and bind mounts.
  static Future<List<StorageVolumeModel>> fetchStorageVolumes({String? targetNode}) => StorageGlusterApi.fetchStorageVolumes(targetNode: targetNode);

  /// Creates a new Docker named volume on target nodes.
  static Future<String> createDockerVolume({
    required String name,
    required String targetNode,
    String driver = 'local',
    Map<String, String>? driverOpts,
    Map<String, String>? labels,
  }) => StorageGlusterApi.createDockerVolume(name: name, targetNode: targetNode, driver: driver, driverOpts: driverOpts, labels: labels);

  /// Deletes a Docker volume from target node(s).
  static Future<String> deleteDockerVolume({
    required String name,
    String? targetNode,
    bool force = false,
  }) => StorageGlusterApi.deleteDockerVolume(name: name, targetNode: targetNode, force: force);

  /// Prunes unused / dangling Docker volumes on target node(s).
  static Future<String> pruneDockerVolumes({String? targetNode}) => StorageGlusterApi.pruneDockerVolumes(targetNode: targetNode);

  /// Inspects a Docker volume and returns JSON metadata.
  static Future<Map<String, dynamic>> inspectDockerVolume({
    required String name,
    String? targetNode,
  }) => StorageGlusterApi.inspectDockerVolume(name: name, targetNode: targetNode);

  /// Creates a new storage directory on target nodes.
  static Future<bool> createStorageDirectory({
    required String path,
    required String targetNode,
    String permissions = '0777',
  }) => StorageGlusterApi.createStorageDirectory(path: path, targetNode: targetNode, permissions: permissions);

  /// Lists files and subdirectories within a given path on a specific node.
  static Future<List<DirectoryEntryModel>> listDirectoryContents({
    required String path,
    String? targetNode,
  }) => StorageGlusterApi.listDirectoryContents(path: path, targetNode: targetNode);

  /// Fetches shared storage pool health and capacity diagnostics.
  static Future<PoolHealthModel> fetchStoragePoolHealth({String path = '/var/contenedores'}) => StorageGlusterApi.fetchStoragePoolHealth(path: path);

  /// Fetches all backup archives.
  static Future<List<BackupModel>> fetchBackups() => StorageGlusterApi.fetchBackups();

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
  }) => StorageGlusterApi.createBackup(name: name, stackId: stackId, volumeName: volumeName, sourcePath: sourcePath, destinationPath: destinationPath, pauseContainers: pauseContainers, encrypted: encrypted, encryptionPassphrase: encryptionPassphrase);

  /// Restores a backup archive to target directory (with optional AES-256-GCM decryption).
  static Future<bool> restoreBackup({
    required String backupId,
    String targetPath = '',
    String encryptionPassphrase = '',
  }) => StorageGlusterApi.restoreBackup(backupId: backupId, targetPath: targetPath, encryptionPassphrase: encryptionPassphrase);

  /// Deletes a backup archive.
  static Future<bool> deleteBackup(String id) => StorageGlusterApi.deleteBackup(id);

  /// Fetches all automated backup schedules.
  static Future<List<BackupScheduleModel>> fetchBackupSchedules() => StorageGlusterApi.fetchBackupSchedules();

  /// Creates or updates a backup schedule.
  static Future<BackupScheduleModel> saveBackupSchedule(BackupScheduleModel schedule) => StorageGlusterApi.saveBackupSchedule(schedule);

  /// Deletes a backup schedule.
  static Future<bool> deleteBackupSchedule(String id) => StorageGlusterApi.deleteBackupSchedule(id);

  /// Fetches all network storage mounts (NFS, S3, Samba, /etc/fstab).
  static Future<List<StorageMountModel>> fetchStorageMounts() => StorageGlusterApi.fetchStorageMounts();

  /// Creates and mounts a new network storage entry.
  static Future<StorageMountModel> createStorageMount(Map<String, dynamic> req) => StorageGlusterApi.createStorageMount(req);

  /// Tests connectivity and R/W access for a remote mount.
  static Future<TestMountResultModel> testStorageMount(Map<String, dynamic> req) => StorageGlusterApi.testStorageMount(req);

  /// Mounts an existing configured entry on target node(s).
  static Future<bool> mountStorageEntry(String id, {String? targetNode}) => StorageGlusterApi.mountStorageEntry(id, targetNode: targetNode);

  /// Unmounts an existing entry from target node(s).
  static Future<bool> unmountStorageEntry(String id, {String? targetNode}) => StorageGlusterApi.unmountStorageEntry(id, targetNode: targetNode);

  /// Deletes a mount and cleans up /etc/fstab across target nodes.
  /// If deleteGluster is true, also deletes the underlying GlusterFS volume.
  static Future<bool> deleteStorageMount(String id, {bool deleteGluster = false}) => StorageGlusterApi.deleteStorageMount(id, deleteGluster: deleteGluster);

  /// Executes mount -a on host or all cluster nodes.
  static Future<String> mountAllStorageEntries({String? targetNode}) => StorageGlusterApi.mountAllStorageEntries(targetNode: targetNode);

  /// Fetches raw /etc/fstab contents from a specific host or local manager.
  static Future<Map<String, dynamic>> fetchRawFstab({String? node}) => StorageGlusterApi.fetchRawFstab(node: node);

  /// Saves and safely writes raw /etc/fstab on target node(s) with automated backup.
  static Future<String> saveRawFstab(String content, {String? node}) => StorageGlusterApi.saveRawFstab(content, node: node);

  /// Fetches the status and configuration of /etc/docker/daemon.json across nodes.
  static Future<Map<String, dynamic>> fetchDockerDaemonConfig({String? scope, String? node}) => StorageGlusterApi.fetchDockerDaemonConfig(scope: scope, node: node);

  /// Saves, backs up, and applies /etc/docker/daemon.json to target nodes.
  static Future<Map<String, dynamic>> saveDockerDaemonConfig({
    required String targetScope,
    String? nodeId,
    required String rawJson,
    required String action,
    bool backup = true,
  }) => StorageGlusterApi.saveDockerDaemonConfig(targetScope: targetScope, nodeId: nodeId, rawJson: rawJson, action: action, backup: backup);

  /// Fetches all image vulnerability scans and cluster security summary.
  static Future<Map<String, dynamic>> fetchImageScans() => ImageComplianceApi.fetchImageScans();

  /// Fetches details and CVEs for a specific scan ID.
  static Future<Map<String, dynamic>> fetchScanDetails(String scanId) => ImageComplianceApi.fetchScanDetails(scanId);

  /// Triggers an immediate vulnerability scan for an image.
  static Future<Map<String, dynamic>> triggerImageScan(String image) => ImageComplianceApi.triggerImageScan(image);

  /// Forces a complete re-scan and sync of all cluster images across all hosts.
  static Future<Map<String, dynamic>> syncAllImageScans() => ImageComplianceApi.syncAllImageScans();

  /// Fetches trusted public signing keys.
  static Future<List<TrustedKeyModel>> fetchTrustedKeys() => ImageComplianceApi.fetchTrustedKeys();

  /// Generates a new Cosign ECDSA keypair.
  static Future<Map<String, dynamic>> generateTrustedKey(String name, {bool isDefault = false}) => ImageComplianceApi.generateTrustedKey(name, isDefault: isDefault);

  /// Saves or imports an existing public key.
  static Future<TrustedKeyModel> saveTrustedKey(String name, String pubPEM, {bool isDefault = false}) => ImageComplianceApi.saveTrustedKey(name, pubPEM, isDefault: isDefault);

  /// Deletes a trusted signing key.
  static Future<bool> deleteTrustedKey(String id) => ImageComplianceApi.deleteTrustedKey(id);

  /// Signs an image with an in-cluster key or manual private key.
  static Future<Map<String, dynamic>> signImage(
    String image, {
    String? keyId,
    String? privateKey,
    String signerName = 'Cluster Admin',
  }) => ImageComplianceApi.signImage(image, keyId: keyId, privateKey: privateKey, signerName: signerName);

  /// Revokes/removes the cryptographic signature from an image.
  static Future<bool> unsignImage(String image) => ImageComplianceApi.unsignImage(image);

  /// Fetches cluster admission security policy.
  static Future<SecurityPolicyModel> fetchSecurityPolicy() => ImageComplianceApi.fetchSecurityPolicy();

  /// Saves cluster admission security policy.
  static Future<SecurityPolicyModel> saveSecurityPolicy(SecurityPolicyModel policy) => ImageComplianceApi.saveSecurityPolicy(policy);

  /// Fetches suggested upgrade versions, affected stacks, and risk analysis for a container image.
  static Future<RemediationPreviewModel> fetchRemediationPreview(String image) => ImageComplianceApi.fetchRemediationPreview(image);

  /// Executes automated image upgrade in a stack with rollback protection and live step logs.
  static Future<RemediationResultModel> executeRemediation({
    required String stackId,
    required String currentImage,
    required String targetImage,
    bool autoRollback = true,
  }) => ImageComplianceApi.executeRemediation(stackId: stackId, currentImage: currentImage, targetImage: targetImage, autoRollback: autoRollback);

  /// Deletes a specific image scan report and its CVEs from cluster state.
  static Future<bool> deleteImageScan(String scanIdOrImage) => ImageComplianceApi.deleteImageScan(scanIdOrImage);

  /// Prunes all scan reports of images that are no longer used by any active stack.
  static Future<Map<String, dynamic>> pruneOrphanImageScans() => ImageComplianceApi.pruneOrphanImageScans();

  /// Fetches physical Docker images stored on cluster nodes.
  static Future<List<HostDockerImageModel>> fetchHostDockerImages({String node = 'all'}) => ImageComplianceApi.fetchHostDockerImages(node: node);

  /// Inspects layer history and reconstructed Dockerfile for a Docker image.
  static Future<ImageHistoryModel> fetchImageHistory(String image, {String node = 'manager'}) => ImageComplianceApi.fetchImageHistory(image, node: node);

  /// Deletes a physical Docker image from a specific node or all cluster nodes.
  static Future<Map<String, dynamic>> deleteHostDockerImage(String image, {String node = 'all', bool force = false, bool purgeDb = true}) => ImageComplianceApi.deleteHostDockerImage(image, node: node, force: force, purgeDb: purgeDb);

  /// Prunes unused and dangling Docker images across cluster nodes to reclaim disk space.
  static Future<ImagePruneResultModel> pruneHostDockerImages({String node = 'all', bool allUnused = true}) => ImageComplianceApi.pruneHostDockerImages(node: node, allUnused: allUnused);

  /// Builds a Docker image on a Centurion node from a Dockerfile in The Imperial Forge.
  static Future<ImageBuildResultModel> buildDockerImage({
    required String tag,
    required String dockerfile,
    String node = 'manager',
    Map<String, String>? buildArgs,
    bool noCache = false,
  }) => ImageComplianceApi.buildDockerImage(tag: tag, dockerfile: dockerfile, node: node, buildArgs: buildArgs, noCache: noCache);

  /// Distributes and loads a Docker image across Centurion cluster nodes.
  static Future<ImageDistributeResultModel> distributeDockerImage({
    required String image,
    String targetNode = 'all',
  }) => ImageComplianceApi.distributeDockerImage(image: image, targetNode: targetNode);

  /// Fetches transparent GitHub adoption stats & release metrics.
  static Future<AdoptionStatsModel> fetchAdoptionStats({bool force = false}) => ImageComplianceApi.fetchAdoptionStats(force: force);

  /// Fetches all peers in the GlusterFS trusted storage pool.
  static Future<List<GlusterPeerModel>> fetchGlusterPeers() => StorageGlusterApi.fetchGlusterPeers();

  /// Probes a new node into the trusted storage pool.
  static Future<void> probeGlusterPeer(String hostname) => StorageGlusterApi.probeGlusterPeer(hostname);

  /// Detaches a peer from the trusted storage pool.
  static Future<void> detachGlusterPeer(String hostname, {bool force = false}) => StorageGlusterApi.detachGlusterPeer(hostname, force: force);

  /// Fetches all GlusterFS volumes.
  static Future<List<GlusterVolumeModel>> fetchGlusterVolumes() => StorageGlusterApi.fetchGlusterVolumes();

  /// Creates and tunes a new GlusterFS volume.
  static Future<void> createGlusterVolume(Map<String, dynamic> payload) => StorageGlusterApi.createGlusterVolume(payload);

  /// Deletes a GlusterFS volume and optionally unmounts from /etc/fstab across cluster nodes.
  static Future<void> deleteGlusterVolume(String name, {bool unmount = true}) => StorageGlusterApi.deleteGlusterVolume(name, unmount: unmount);

  /// Deletes all GlusterFS volumes across the cluster.
  static Future<void> deleteAllGlusterVolumes({bool unmount = true}) => StorageGlusterApi.deleteAllGlusterVolumes(unmount: unmount);

  /// Starts a GlusterFS volume.
  static Future<void> startGlusterVolume(String name) => StorageGlusterApi.startGlusterVolume(name);

  /// Stops a GlusterFS volume.
  static Future<void> stopGlusterVolume(String name, {bool force = false}) => StorageGlusterApi.stopGlusterVolume(name, force: force);

  /// Fetches self-healing & split-brain diagnostics for a volume.
  static Future<GlusterHealModel> fetchGlusterHealReport(String name) => StorageGlusterApi.fetchGlusterHealReport(name);

  /// Triggers a manual self-heal cycle.
  static Future<void> triggerGlusterSelfHeal(String name) => StorageGlusterApi.triggerGlusterSelfHeal(name);

  /// Auto-mounts volume to /var/contenedores across cluster hosts or specific target nodes.
  static Future<void> mountGlusterCluster(String name, {String mountPoint = '/var/contenedores', List<String>? targetNodes}) => StorageGlusterApi.mountGlusterCluster(name, mountPoint: mountPoint, targetNodes: targetNodes);

  /// Fetches cluster diagnostics for GlusterFS.
  static Future<GlusterClusterDiagnosticsModel> fetchGlusterDiagnostics() => StorageGlusterApi.fetchGlusterDiagnostics();

  /// Fetches real-time dedicated storage network traffic and interface discovery.
  static Future<StorageNetworkReportModel> fetchStorageNetworkReport() => StorageGlusterApi.fetchStorageNetworkReport();

  /// Fetches real-time I/O performance and FOP profiling for a volume.
  static Future<GlusterProfileReportModel> fetchGlusterVolumeProfile(String name) => StorageGlusterApi.fetchGlusterVolumeProfile(name);

  /// Starts volume profiling.
  static Future<void> startGlusterVolumeProfile(String name) => StorageGlusterApi.startGlusterVolumeProfile(name);

  /// Stops volume profiling.
  static Future<void> stopGlusterVolumeProfile(String name) => StorageGlusterApi.stopGlusterVolumeProfile(name);

  /// Fetches directory path quotas for a volume.
  static Future<GlusterQuotasReportModel> fetchGlusterQuotas(String name) => StorageGlusterApi.fetchGlusterQuotas(name);

  /// Sets or updates a directory quota limit on a volume.
  static Future<void> setGlusterQuota(String name, String path, String hardLimit) => StorageGlusterApi.setGlusterQuota(name, path, hardLimit);

  /// Disables quotas on a volume.
  static Future<void> disableGlusterQuota(String name) => StorageGlusterApi.disableGlusterQuota(name);

  /// Fetches volume snapshots.
  static Future<List<GlusterSnapshotModel>> fetchGlusterSnapshots({String? volumeName}) => StorageGlusterApi.fetchGlusterSnapshots(volumeName: volumeName);

  /// Creates a point-in-time snapshot.
  static Future<void> createGlusterSnapshot(String name, String volumeName, {String description = ''}) => StorageGlusterApi.createGlusterSnapshot(name, volumeName, description: description);

  /// Restores a snapshot (rollback).
  static Future<void> restoreGlusterSnapshot(String name) => StorageGlusterApi.restoreGlusterSnapshot(name);

  /// Deletes a snapshot.
  static Future<void> deleteGlusterSnapshot(String name) => StorageGlusterApi.deleteGlusterSnapshot(name);

  /// Starts or stops volume rebalance.
  static Future<Map<String, dynamic>> rebalanceGlusterVolume(String name, {String action = 'start'}) => StorageGlusterApi.rebalanceGlusterVolume(name, action: action);

  /// Sets or resets an advanced volume tuning option.
  static Future<void> setGlusterVolumeOption(String name, String key, String value, {bool reset = false}) => StorageGlusterApi.setGlusterVolumeOption(name, key, value, reset: reset);

  /// Fetches SRE Observability architecture profiles.
  static Future<Map<String, dynamic>> getMonitorProfiles() => ObservabilityWafApi.getMonitorProfiles();

  /// Switches active SRE Observability stack architecture profile.
  static Future<Map<String, dynamic>> switchMonitorProfile(String profileId) => ObservabilityWafApi.switchMonitorProfile(profileId);

  /// Fetches global eBPF kernel stats and telemetry counters.
  static Future<EbpfStats> fetchEbpfStats() => ObservabilityWafApi.fetchEbpfStats();

  /// Fetches recent captured L4/L7 network flows.
  static Future<List<EbpfFlow>> fetchEbpfFlows({
    int limit = 50,
    String? protocol,
    String? status,
    String? query,
  }) => ObservabilityWafApi.fetchEbpfFlows(limit: limit, protocol: protocol, status: status, query: query);

  /// Fetches synthesized eBPF service mesh topology graph.
  static Future<EbpfTopology> fetchEbpfTopology() => ObservabilityWafApi.fetchEbpfTopology();

  /// Triggers on-demand eBPF traffic simulation.
  static Future<bool> simulateEbpfTraffic({
    String pattern = 'burst',
    int rate = 15,
    int durationS = 10,
    double errorPct = 0.0,
  }) => ObservabilityWafApi.simulateEbpfTraffic(pattern: pattern, rate: rate, durationS: durationS, errorPct: errorPct);

  /// Fetches Spanish ENS (RD 311/2022) compliance evaluation summary.
  static Future<ENSSummaryModel?> fetchENSStatus() => ImageComplianceApi.fetchENSStatus();

  /// Downloads the technical ENS compliance and evidence report in Markdown or JSON.
  static Future<String?> fetchENSReport({String format = 'markdown'}) => ImageComplianceApi.fetchENSReport(format: format);

  /// Fetches European NIS 2 Directive (EU 2022/2555) compliance evaluation summary.
  static Future<NIS2SummaryModel?> fetchNIS2Status() => ImageComplianceApi.fetchNIS2Status();

  /// Downloads the technical NIS 2 compliance and evidence report in Markdown or JSON.
  static Future<String?> fetchNIS2Report({String format = 'markdown'}) => ImageComplianceApi.fetchNIS2Report(format: format);

  /// Fetches CIS Docker Benchmark v1.6.0 compliance assessment summary.
  static Future<CISDockerSummaryModel?> fetchCISDockerStatus() => ImageComplianceApi.fetchCISDockerStatus();

  /// Downloads the technical CIS Docker Benchmark compliance report in Markdown or JSON.
  static Future<String?> fetchCISDockerReport({String format = 'markdown'}) => ImageComplianceApi.fetchCISDockerReport(format: format);

  /// Fetches ISO/IEC 27001:2022 Annex A compliance evaluation.
  static Future<ISO27001SummaryModel?> fetchISO27001Status() => ImageComplianceApi.fetchISO27001Status();

  /// Downloads the formal ISO/IEC 27001 Statement of Applicability audit report.
  static Future<String?> fetchISO27001Report({String format = 'text'}) => ImageComplianceApi.fetchISO27001Report(format: format);

  /// Fetches cluster compliance status against EU DORA (Regulation 2022/2554).
  static Future<DORASummaryModel?> fetchDORAStatus() => ImageComplianceApi.fetchDORAStatus();

  /// Downloads the technical DORA operational resilience audit report.
  static Future<String?> fetchDORAReport({String format = 'markdown'}) => ImageComplianceApi.fetchDORAReport(format: format);

  /// Fetches the unified Continuous Compliance Overview across all 5 regulatory frameworks.
  static Future<ComplianceOverviewModel?> fetchComplianceOverview() => ImageComplianceApi.fetchComplianceOverview();

  /// Triggers an immediate, cluster-wide re-evaluation across all 4 regulatory frameworks.
  static Future<ComplianceOverviewModel?> evaluateAllCompliance() => ImageComplianceApi.evaluateAllCompliance();
}

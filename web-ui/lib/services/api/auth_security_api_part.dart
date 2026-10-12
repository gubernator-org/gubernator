part of '../api_service.dart';

class AuthSecurityApi {
  static Map<String, String> get authHeaders => ApiService.authHeaders;
  static String? get authToken => ApiService.authToken;
  static set authToken(String? token) => ApiService.authToken = token;

  // ─────────────────────────────────────────────────────────────
  // Enterprise Authentication & Active Directory / LDAP APIs
  // ─────────────────────────────────────────────────────────────

  /// Fetches available identity providers (Local Admin + Active Directory/LDAP).
  static Future<List<AuthProvider>> fetchAuthProviders() async {
    final response = await http.get(Uri.parse('/api/auth/providers'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['providers'] as List? ?? [])
          .map((e) => AuthProvider.fromJson(e))
          .toList();
    }
    return [const AuthProvider(id: 'local', name: 'Local Administrator', type: 'local')];
  }

  /// Logs in against Local Admin or an Active Directory/LDAP provider.
  static Future<Map<String, dynamic>> login(
    String username,
    String password, {
    String? provider,
  }) async {
    final response = await http.post(
      Uri.parse('/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'provider': provider ?? 'local',
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      if (data['mfa_required'] == true) {
        return {
          'success': true,
          'mfa_required': true,
          'mfa_token': data['mfa_token'],
          'username': data['username'],
          'mfa_configured': data['mfa_configured'] ?? true,
          'secret': data['secret'],
          'otpauth_uri': data['otpauth_uri'],
          'qr_data_uri': data['qr_data_uri'],
          'backup_codes': (data['backup_codes'] as List?)?.map((e) => e.toString()).toList(),
        };
      }
      if (data['token'] != null) {
        authToken = data['token'];
        return {'success': true, 'user': UserSession.fromJson(data['user'])};
      }
    }
    return {'success': false, 'error': data['error'] ?? 'Login failed (${response.statusCode})'};
  }

  /// Sends a client time beacon to the server to detect and correct VM sleep clock drift.
  static Future<Map<String, dynamic>?> sendTimeBeacon() async {
    try {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final response = await http.post(
        Uri.parse('/api/system/time-beacon'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'client_timestamp': nowSec}),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Completes MFA login verification using TOTP 6-digit code or recovery code.
  static Future<Map<String, dynamic>> verifyMFA({
    required String mfaToken,
    required String code,
  }) async {
    final cleanCode = code.trim().replaceAll(' ', '').replaceAll('-', '');
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final response = await http.post(
      Uri.parse('/api/auth/mfa/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'mfa_token': mfaToken,
        'code': cleanCode,
        'client_timestamp': nowSec,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['token'] != null) {
      authToken = data['token'];
      return {'success': true, 'user': UserSession.fromJson(data['user'])};
    }
    return {'success': false, 'error': data['error'] ?? 'MFA verification failed (${response.statusCode})'};
  }

  /// Completes initial MFA setup during login when MFA is enforced (ENS op.acc.6)
  static Future<Map<String, dynamic>> completeEnforcedMFASetup({
    required String mfaToken,
    required String secret,
    required String code,
    List<String>? backupCodes,
  }) async {
    final cleanCode = code.trim().replaceAll(' ', '').replaceAll('-', '');
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final response = await http.post(
      Uri.parse('/api/auth/mfa/setup-complete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'mfa_token': mfaToken,
        'secret': secret.trim().replaceAll(' ', '').replaceAll('-', ''),
        'code': cleanCode,
        'backup_codes': backupCodes ?? [],
        'client_timestamp': nowSec,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['token'] != null) {
      authToken = data['token'];
      return {'success': true, 'user': UserSession.fromJson(data['user'])};
    }
    return {'success': false, 'error': data['error'] ?? 'MFA mandatory setup failed (${response.statusCode})'};
  }

  /// Initiates MFA setup for current user or admin target user.
  static Future<Map<String, dynamic>> setupMFA({String? userId}) async {
    final response = await http.post(
      Uri.parse('/api/auth/mfa/setup'),
      headers: authHeaders,
      body: jsonEncode({
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['error'] ?? 'Failed to setup MFA');
  }

  /// Confirms and enables MFA with the first generated TOTP code.
  static Future<Map<String, dynamic>> enableMFA({
    String? userId,
    required String secret,
    required String code,
    List<String>? backupCodes,
  }) async {
    final cleanCode = code.trim().replaceAll(' ', '').replaceAll('-', '');
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final response = await http.post(
      Uri.parse('/api/auth/mfa/enable'),
      headers: authHeaders,
      body: jsonEncode({
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
        'secret': secret.trim().replaceAll(' ', '').replaceAll('-', ''),
        'code': cleanCode,
        'backup_codes': backupCodes ?? [],
        'client_timestamp': nowSec,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    return {'error': data['error'] ?? 'Failed to activate MFA'};
  }

  /// Disables MFA for user.
  static Future<Map<String, dynamic>> disableMFA({
    String? userId,
    String? code,
  }) async {
    final response = await http.post(
      Uri.parse('/api/auth/mfa/disable'),
      headers: authHeaders,
      body: jsonEncode({
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
        if (code != null && code.isNotEmpty) 'code': code.trim(),
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    return {'error': data['error'] ?? 'Failed to disable MFA'};
  }

  /// Fetches the currently authenticated user profile and permissions.
  static Future<UserSession?> fetchMe() async {
    try {
      final response = await http.get(Uri.parse('/api/auth/me'), headers: authHeaders);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserSession.fromJson(data['user']);
      }
    } catch (_) {}
    return null;
  }

  /// Logs out the user and clears stored session tokens.
  static Future<void> logout({String? reason}) async {
    try {
      final body = reason != null ? jsonEncode({'reason': reason}) : null;
      await http.post(Uri.parse('/api/auth/logout'), headers: authHeaders, body: body);
    } catch (_) {}
    authToken = null;
  }

  /// Fetches all configured LDAP / Active Directory servers (Admin only).
  static Future<List<LDAPConfig>> fetchLDAPConfigs() async {
    final response = await http.get(Uri.parse('/api/auth/ldap'), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['configs'] as List? ?? [])
          .map((e) => LDAPConfig.fromJson(e))
          .toList();
    }
    return [];
  }

  /// Creates or updates an LDAP / Active Directory configuration.
  static Future<Map<String, dynamic>> saveLDAPConfig(LDAPConfig config) async {
    final response = await http.post(
      Uri.parse('/api/auth/ldap'),
      headers: authHeaders,
      body: jsonEncode(config.toJson()),
    );
    return jsonDecode(response.body);
  }

  /// Deletes an LDAP / Active Directory configuration.
  static Future<bool> deleteLDAPConfig(String id) async {
    final response = await http.delete(Uri.parse('/api/auth/ldap/$id'), headers: authHeaders);
    return response.statusCode == 200;
  }

  /// Tests connectivity and optional user credentials against an LDAP configuration.
  static Future<LDAPTestResult> testLDAPConfig(
    LDAPConfig config, {
    String testUsername = '',
    String testPassword = '',
  }) async {
    final response = await http.post(
      Uri.parse('/api/auth/ldap/test'),
      headers: authHeaders,
      body: jsonEncode({
        'config': config.toJson(),
        'test_username': testUsername,
        'test_password': testPassword,
      }),
    );

    final data = jsonDecode(response.body);
    if (data['result'] != null) {
      return LDAPTestResult.fromJson(data['result']);
    }
    return LDAPTestResult(
      connected: false,
      tlsActive: false,
      bindSuccessful: false,
      userFound: false,
      message: data['error'] ?? 'Connection test failed',
      latencyMs: 0,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OIDC / OAuth2 SSO APIs
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches all configured OIDC / SSO providers (Admin only).
  static Future<List<OIDCConfig>> fetchOIDCConfigs() async {
    try {
      final response = await http.get(Uri.parse('/api/auth/oidc'), headers: authHeaders);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['configs'] as List? ?? [])
            .map((e) => OIDCConfig.fromJson(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Fetches built-in OIDC provider presets (Keycloak, Google, Azure, etc.).
  static Future<List<OIDCProviderPreset>> fetchOIDCPresets() async {
    try {
      final response = await http.get(Uri.parse('/api/auth/oidc/presets'), headers: authHeaders);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['presets'] as List? ?? [])
            .map((e) => OIDCProviderPreset.fromJson(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Creates or updates an OIDC provider configuration.
  static Future<Map<String, dynamic>> saveOIDCConfig(OIDCConfig config) async {
    try {
      final response = await http.post(
        Uri.parse('/api/auth/oidc'),
        headers: authHeaders,
        body: jsonEncode(config.toJson()),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Deletes an OIDC provider configuration.
  static Future<bool> deleteOIDCConfig(String id) async {
    try {
      final response = await http.delete(Uri.parse('/api/auth/oidc/$id'), headers: authHeaders);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Tests connectivity to an OIDC provider's discovery endpoint and JWKS.
  static Future<OIDCTestResult> testOIDCConfig(OIDCConfig config) async {
    try {
      final response = await http.post(
        Uri.parse('/api/auth/oidc/${config.id}/test'),
        headers: authHeaders,
        body: jsonEncode(config.toJson()),
      );
      final data = jsonDecode(response.body);
      return OIDCTestResult.fromJson(data);
    } catch (e) {
      return OIDCTestResult(
        connected: false,
        issuerReachable: false,
        discoveryOk: false,
        jwksReachable: false,
        message: e.toString(),
      );
    }
  }

  /// Requests an OAuth2 authorization URL to begin the SSO login flow.
  /// Returns the auth_url to open in the browser and the state token.
  static Future<Map<String, dynamic>> getOIDCAuthorizeUrl(String providerId) async {
    try {
      final response = await http.get(
        Uri.parse('/api/auth/oidc/$providerId/authorize'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'error': 'Failed to get authorization URL (${response.statusCode})'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Fetches all local user accounts.
  static Future<List<LocalUser>> fetchLocalUsers() async {
    final response = await http.get(Uri.parse("/api/security/users"), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data["users"] as List? ?? [])
          .map((e) => LocalUser.fromJson(e))
          .toList();
    }
    return [];
  }

  /// Creates a new local user.
  static Future<Map<String, dynamic>> createLocalUser({
    required String username,
    required String password,
    required String displayName,
    required String email,
    required String role,
    required bool enabled,
  }) async {
    final response = await http.post(
      Uri.parse("/api/security/users"),
      headers: authHeaders,
      body: jsonEncode({
        "username": username,
        "password": password,
        "display_name": displayName,
        "email": email,
        "role": role,
        "enabled": enabled,
      }),
    );
    return jsonDecode(response.body);
  }

  /// Updates an existing local user.
  static Future<Map<String, dynamic>> updateLocalUser(LocalUser user) async {
    final response = await http.put(
      Uri.parse("/api/security/users/${user.id}"),
      headers: authHeaders,
      body: jsonEncode(user.toJson()),
    );
    return jsonDecode(response.body);
  }

  /// Toggles suspension status of a local user account.
  static Future<Map<String, dynamic>> toggleLocalUserStatus(String id, {bool? enabled}) async {
    final body = enabled != null ? jsonEncode({"enabled": enabled}) : "{}";
    final response = await http.post(
      Uri.parse("/api/security/users/$id/toggle-status"),
      headers: authHeaders,
      body: body,
    );
    return jsonDecode(response.body);
  }

  /// Resets a local user password.
  static Future<Map<String, dynamic>> resetLocalUserPassword(String id, String newPassword) async {
    final response = await http.post(
      Uri.parse("/api/security/users/$id/password"),
      headers: authHeaders,
      body: jsonEncode({"new_password": newPassword}),
    );
    return jsonDecode(response.body);
  }

  /// Administratively unlocks a locked local user account (ENS op.acc.2).
  static Future<Map<String, dynamic>> unlockLocalUser(String id) async {
    final response = await http.post(
      Uri.parse("/api/security/users/$id/unlock"),
      headers: authHeaders,
    );
    return jsonDecode(response.body);
  }

  /// Deletes a local user account.
  static Future<bool> deleteLocalUser(String id) async {
    final response = await http.delete(Uri.parse("/api/security/users/$id"), headers: authHeaders);
    return response.statusCode == 200;
  }

  /// Fetches access and audit logs.
  static Future<List<AuditLog>> fetchAuditLogs({String provider = "", String action = ""}) async {
    var url = "/api/security/audit-logs";
    List<String> queryParams = [];
    if (provider.isNotEmpty) queryParams.add("provider=$provider");
    if (action.isNotEmpty) queryParams.add("action=$action");
    if (queryParams.isNotEmpty) {
      url += "?${queryParams.join("&")}";
    }
    final response = await http.get(Uri.parse(url), headers: authHeaders);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data["audit_logs"] as List? ?? [])
          .map((e) => AuditLog.fromJson(e))
          .toList();
    }
    return [];
  }

  /// Fetches cluster SIEM and ENS security configuration.
  static Future<SIEMConfig?> fetchSIEMConfig() async {
    try {
      final response = await http.get(Uri.parse('/api/security/siem'), headers: authHeaders);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SIEMConfig.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Fetches cluster SIEM delivery metrics, connection health, and ENS compliance status.
  static Future<SIEMStatusResponse?> fetchSIEMStatus() async {
    try {
      final response = await http.get(Uri.parse('/api/security/siem/status'), headers: authHeaders);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SIEMStatusResponse.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Saves cluster SIEM and ENS security configuration.
  static Future<Map<String, dynamic>> saveSIEMConfig(SIEMConfig config) async {
    try {
      final response = await http.post(
        Uri.parse('/api/security/siem'),
        headers: authHeaders,
        body: jsonEncode(config.toJson()),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          if (!data.containsKey('success')) {
            data['success'] = true;
          }
          return data;
        }
        return {'success': true};
      }
      try {
        final err = jsonDecode(response.body);
        if (err is Map<String, dynamic>) {
          return {
            'success': false,
            'error': err['error'] ?? err['message'] ?? 'Error HTTP ${response.statusCode}',
          };
        }
      } catch (_) {}
      return {'success': false, 'error': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Sends a live SIEM test syslog/CEF probe.
  static Future<Map<String, dynamic>> testSIEMConnection(SIEMConfig config) async {
    try {
      final response = await http.post(
        Uri.parse('/api/security/siem/test'),
        headers: authHeaders,
        body: jsonEncode(config.toJson()),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          if (!data.containsKey('success')) {
            data['success'] = true;
          }
          return data;
        }
        return {'success': true};
      }
      try {
        final err = jsonDecode(response.body);
        if (err is Map<String, dynamic>) {
          return {
            'success': false,
            'error': err['error'] ?? err['message'] ?? 'Error HTTP ${response.statusCode}',
          };
        }
      } catch (_) {}
      return {'success': false, 'error': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Verifies cryptographic SHA-256 integrity of the audit trail (ENS op.mon.1).
  static Future<AuditVerificationResult> verifyAuditChain() async {
    try {
      final response = await http.get(Uri.parse('/api/security/audit-logs/verify'), headers: authHeaders);
      if (response.statusCode == 200) {
        return AuditVerificationResult.fromJson(jsonDecode(response.body));
      }
      return AuditVerificationResult(
        valid: false,
        totalRecords: 0,
        verifiedRecords: 0,
        lastHash: '',
        error: 'Failed to verify chain: ${response.statusCode}',
      );
    } catch (e) {
      return AuditVerificationResult(
        valid: false,
        totalRecords: 0,
        verifiedRecords: 0,
        lastHash: '',
        error: e.toString(),
      );
    }
  }

  /// Downloads export file of the forensic audit trail (CSV, JSON, LOG).
  static Future<void> downloadAuditLogsExport(String format) async {
    try {
      final res = await http.get(
        Uri.parse('/api/security/audit-logs/export?format=$format'),
        headers: authHeaders,
      );
      if (res.statusCode == 200) {
        final bytes = res.bodyBytes;
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', 'audit-trail-${DateTime.now().millisecondsSinceEpoch}.$format')
          ..click();
        html.Url.revokeObjectUrl(url);
      }
    } catch (_) {}
  }
}

/// Authentication, RBAC, Local Users, LDAP, OIDC, Audit Logs, and SIEM models.
library;

class UserPermissions {
  final bool canDeployStacks;
  final bool canDeleteStacks;
  final bool canRestartTasks;
  final bool canDeleteTasks;
  final bool canExecuteShell;
  final bool canManageNodes;
  final bool canManageCaddy;
  final bool canManageCoreDNS;
  final bool canManageSecurity;
  final bool canViewObservability;
  final bool canViewAuditLogs;
  final bool canExportAuditLogs;

  const UserPermissions({
    this.canDeployStacks = true,
    this.canDeleteStacks = true,
    this.canRestartTasks = true,
    this.canDeleteTasks = true,
    this.canExecuteShell = true,
    this.canManageNodes = true,
    this.canManageCaddy = true,
    this.canManageCoreDNS = true,
    this.canManageSecurity = true,
    this.canViewObservability = true,
    this.canViewAuditLogs = true,
    this.canExportAuditLogs = true,
  });

  factory UserPermissions.fromJson(Map<String, dynamic> json) {
    return UserPermissions(
      canDeployStacks: json['can_deploy_stacks'] ?? true,
      canDeleteStacks: json['can_delete_stacks'] ?? true,
      canRestartTasks: json['can_restart_tasks'] ?? true,
      canDeleteTasks: json['can_delete_tasks'] ?? true,
      canExecuteShell: json['can_execute_shell'] ?? true,
      canManageNodes: json['can_manage_nodes'] ?? true,
      canManageCaddy: json['can_manage_caddy'] ?? true,
      canManageCoreDNS: json['can_manage_coredns'] ?? true,
      canManageSecurity: json['can_manage_security'] ?? true,
      canViewObservability: json['can_view_observability'] ?? true,
      canViewAuditLogs: json['can_view_audit_logs'] ?? true,
      canExportAuditLogs: json['can_export_audit_logs'] ?? true,
    );
  }
}

class UserSession {
  final String username;
  final String displayName;
  final String email;
  final String role; // "admin", "operator", "readonly", "auditor"
  final String provider;
  final UserPermissions permissions;

  const UserSession({
    required this.username,
    required this.displayName,
    this.email = '',
    this.role = 'admin',
    this.provider = 'local',
    this.permissions = const UserPermissions(),
  });

  bool get isAdmin => role == 'admin';
  bool get isOperator => role == 'operator';
  bool get isReadOnly => role == 'readonly';
  bool get isAuditor => role == 'auditor';

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['username'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'admin',
      provider: json['provider'] ?? 'local',
      permissions: json['permissions'] != null
          ? UserPermissions.fromJson(json['permissions'])
          : const UserPermissions(),
    );
  }
}

class AuthProvider {
  final String id;
  final String name;
  final String type; // "local", "ldap", "oidc"
  final String providerType; // for oidc: "keycloak", "google", "github", "azure", "okta", "generic"

  const AuthProvider({
    required this.id,
    required this.name,
    required this.type,
    this.providerType = 'generic',
  });

  factory AuthProvider.fromJson(Map<String, dynamic> json) {
    return AuthProvider(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'local',
      providerType: json['provider_type'] ?? 'generic',
    );
  }

  bool get isOIDC => type == 'oidc';
  bool get isLDAP => type == 'ldap';
  bool get isLocal => type == 'local';
}

class LDAPConfig {
  final String id;
  final String name;
  final bool enabled;
  final String host;
  final int port;
  final String security; // "none", "tls", "starttls"
  final bool insecureSkipVerify;
  final String bindDn;
  final String bindPassword;
  final String baseDn;
  final String userFilter;
  final String userAttr;
  final String groupBaseDn;
  final String groupFilter;
  final String adminGroupDn;
  final String operatorGroupDn;
  final String readOnlyGroupDn;
  final String defaultRole;

  LDAPConfig({
    required this.id,
    required this.name,
    this.enabled = true,
    required this.host,
    this.port = 389,
    this.security = 'none',
    this.insecureSkipVerify = false,
    this.bindDn = '',
    this.bindPassword = '',
    required this.baseDn,
    this.userFilter = '(&(objectClass=user)(sAMAccountName=%s))',
    this.userAttr = 'sAMAccountName',
    this.groupBaseDn = '',
    this.groupFilter = '(&(objectClass=group)(member=%s))',
    this.adminGroupDn = '',
    this.operatorGroupDn = '',
    this.readOnlyGroupDn = '',
    this.defaultRole = 'readonly',
  });

  factory LDAPConfig.fromJson(Map<String, dynamic> json) {
    return LDAPConfig(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      enabled: json['enabled'] ?? true,
      host: json['host'] ?? '',
      port: (json['port'] as num?)?.toInt() ?? 389,
      security: json['security'] ?? 'none',
      insecureSkipVerify: json['insecure_skip_verify'] == true,
      bindDn: json['bind_dn'] ?? '',
      bindPassword: json['bind_password'] ?? '',
      baseDn: json['base_dn'] ?? '',
      userFilter: json['user_filter'] ?? '(&(objectClass=user)(sAMAccountName=%s))',
      userAttr: json['user_attr'] ?? 'sAMAccountName',
      groupBaseDn: json['group_base_dn'] ?? '',
      groupFilter: json['group_filter'] ?? '(&(objectClass=group)(member=%s))',
      adminGroupDn: json['admin_group_dn'] ?? '',
      operatorGroupDn: json['operator_group_dn'] ?? '',
      readOnlyGroupDn: json['readonly_group_dn'] ?? '',
      defaultRole: json['default_role'] ?? 'readonly',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'host': host,
        'port': port,
        'security': security,
        'insecure_skip_verify': insecureSkipVerify,
        'bind_dn': bindDn,
        'bind_password': bindPassword,
        'base_dn': baseDn,
        'user_filter': userFilter,
        'user_attr': userAttr,
        'group_base_dn': groupBaseDn,
        'group_filter': groupFilter,
        'admin_group_dn': adminGroupDn,
        'operator_group_dn': operatorGroupDn,
        'readonly_group_dn': readOnlyGroupDn,
        'default_role': defaultRole,
      };
}

class LDAPTestResult {
  final bool connected;
  final bool tlsActive;
  final bool bindSuccessful;
  final bool userFound;
  final String message;
  final int latencyMs;
  final String? assignedRole;

  LDAPTestResult({
    required this.connected,
    required this.tlsActive,
    required this.bindSuccessful,
    required this.userFound,
    required this.message,
    required this.latencyMs,
    this.assignedRole,
  });

  factory LDAPTestResult.fromJson(Map<String, dynamic> json) {
    final authRes = json['auth_result'] as Map<String, dynamic>?;
    return LDAPTestResult(
      connected: json['connected'] == true,
      tlsActive: json['tls_active'] == true,
      bindSuccessful: json['bind_successful'] == true,
      userFound: json['user_found'] == true,
      message: json['message'] ?? '',
      latencyMs: (json['latency_ms'] as num?)?.toInt() ?? 0,
      assignedRole: authRes?['role']?.toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OIDC / OAuth2 SSO Models
// ─────────────────────────────────────────────────────────────────────────────

class OIDCConfig {
  final String id;
  final String name;
  final String providerType; // generic, keycloak, google, github, azure, okta
  final bool enabled;
  final String issuerUrl;
  final String clientId;
  final String clientSecret;
  final String redirectUri;
  final String scopes;
  final String roleClaimPath;
  final String adminClaim;
  final String operatorClaim;
  final String readonlyClaim;
  final String defaultRole;
  final bool insecureSkipVerify;

  OIDCConfig({
    this.id = '',
    required this.name,
    this.providerType = 'generic',
    this.enabled = true,
    required this.issuerUrl,
    required this.clientId,
    this.clientSecret = '',
    this.redirectUri = '',
    this.scopes = 'openid profile email',
    this.roleClaimPath = 'groups',
    this.adminClaim = '',
    this.operatorClaim = '',
    this.readonlyClaim = '',
    this.defaultRole = 'readonly',
    this.insecureSkipVerify = false,
  });

  factory OIDCConfig.fromJson(Map<String, dynamic> json) {
    return OIDCConfig(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      providerType: json['provider_type'] ?? 'generic',
      enabled: json['enabled'] ?? true,
      issuerUrl: json['issuer_url'] ?? '',
      clientId: json['client_id'] ?? '',
      clientSecret: json['client_secret'] ?? '',
      redirectUri: json['redirect_uri'] ?? '',
      scopes: json['scopes'] ?? 'openid profile email',
      roleClaimPath: json['role_claim_path'] ?? 'groups',
      adminClaim: json['admin_claim'] ?? '',
      operatorClaim: json['operator_claim'] ?? '',
      readonlyClaim: json['readonly_claim'] ?? '',
      defaultRole: json['default_role'] ?? 'readonly',
      insecureSkipVerify: json['insecure_skip_verify'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'provider_type': providerType,
        'enabled': enabled,
        'issuer_url': issuerUrl,
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
        'scopes': scopes,
        'role_claim_path': roleClaimPath,
        'admin_claim': adminClaim,
        'operator_claim': operatorClaim,
        'readonly_claim': readonlyClaim,
        'default_role': defaultRole,
        'insecure_skip_verify': insecureSkipVerify,
      };
}

class OIDCTestResult {
  final bool connected;
  final bool issuerReachable;
  final bool discoveryOk;
  final bool jwksReachable;
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String jwksUri;
  final int keyCount;
  final String message;
  final int latencyMs;

  OIDCTestResult({
    required this.connected,
    required this.issuerReachable,
    required this.discoveryOk,
    required this.jwksReachable,
    this.authorizationEndpoint = '',
    this.tokenEndpoint = '',
    this.jwksUri = '',
    this.keyCount = 0,
    required this.message,
    this.latencyMs = 0,
  });

  factory OIDCTestResult.fromJson(Map<String, dynamic> json) {
    return OIDCTestResult(
      connected: json['connected'] == true,
      issuerReachable: json['issuer_reachable'] == true,
      discoveryOk: json['discovery_ok'] == true,
      jwksReachable: json['jwks_reachable'] == true,
      authorizationEndpoint: json['authorization_endpoint'] ?? '',
      tokenEndpoint: json['token_endpoint'] ?? '',
      jwksUri: json['jwks_uri'] ?? '',
      keyCount: (json['key_count'] as num?)?.toInt() ?? 0,
      message: json['message'] ?? '',
      latencyMs: (json['latency_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

class OIDCProviderPreset {
  final String type;
  final String name;
  final String issuerUrl;
  final String scopes;
  final String roleClaimPath;
  final String description;
  final String docsUrl;

  OIDCProviderPreset({
    required this.type,
    required this.name,
    required this.issuerUrl,
    required this.scopes,
    required this.roleClaimPath,
    required this.description,
    required this.docsUrl,
  });

  factory OIDCProviderPreset.fromJson(Map<String, dynamic> json) {
    return OIDCProviderPreset(
      type: json['type'] ?? 'generic',
      name: json['name'] ?? '',
      issuerUrl: json['issuer_url'] ?? '',
      scopes: json['scopes'] ?? 'openid profile email',
      roleClaimPath: json['role_claim_path'] ?? 'groups',
      description: json['description'] ?? '',
      docsUrl: json['docs_url'] ?? '',
    );
  }
}

class LocalUser {
  final String id;
  final String username;
  final String displayName;
  final String email;
  final String role;
  final bool enabled;
  final bool mfaEnabled;
  final int failedLoginAttempts;
  final String? lockedUntil;
  final String? passwordChangedAt;
  final String? lastLogin;
  final String createdAt;
  final String updatedAt;

  LocalUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    required this.role,
    required this.enabled,
    this.mfaEnabled = false,
    this.failedLoginAttempts = 0,
    this.lockedUntil,
    this.passwordChangedAt,
    this.lastLogin,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLocked {
    if (lockedUntil == null || lockedUntil!.isEmpty) return false;
    try {
      final lockTime = DateTime.parse(lockedUntil!);
      return DateTime.now().toUtc().isBefore(lockTime.toUtc());
    } catch (_) {
      return false;
    }
  }

  int get lockRemainingMinutes {
    if (!isLocked) return 0;
    try {
      final lockTime = DateTime.parse(lockedUntil!);
      final diff = lockTime.toUtc().difference(DateTime.now().toUtc()).inMinutes;
      return diff <= 0 ? 1 : diff + 1;
    } catch (_) {
      return 0;
    }
  }

  factory LocalUser.fromJson(Map<String, dynamic> json) {
    return LocalUser(
      id: json["id"] ?? "",
      username: json["username"] ?? "",
      displayName: json["display_name"] ?? "",
      email: json["email"] ?? "",
      role: json["role"] ?? "readonly",
      enabled: json["enabled"] ?? true,
      mfaEnabled: json["mfa_enabled"] == true,
      failedLoginAttempts: (json["failed_login_attempts"] as num?)?.toInt() ?? 0,
      lockedUntil: json["locked_until"],
      passwordChangedAt: json["password_changed_at"],
      lastLogin: json["last_login"],
      createdAt: json["created_at"] ?? "",
      updatedAt: json["updated_at"] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "username": username,
      "display_name": displayName,
      "email": email,
      "role": role,
      "enabled": enabled,
      "mfa_enabled": mfaEnabled,
      "failed_login_attempts": failedLoginAttempts,
      "locked_until": lockedUntil,
      "password_changed_at": passwordChangedAt,
    };
  }
}

class AuditLog {
  final String id;
  final String timestamp;
  final String username;
  final String provider;
  final String ipAddress;
  final String action;
  final String status;
  final String details;
  final String prevHash;
  final String hash;

  AuditLog({
    required this.id,
    required this.timestamp,
    required this.username,
    required this.provider,
    required this.ipAddress,
    required this.action,
    required this.status,
    required this.details,
    this.prevHash = "",
    this.hash = "",
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json["id"] ?? "",
      timestamp: json["timestamp"] ?? "",
      username: json["username"] ?? "",
      provider: json["provider"] ?? "LOCAL",
      ipAddress: json["ip_address"] ?? "",
      action: json["action"] ?? "",
      status: json["status"] ?? "SUCCESS",
      details: json["details"] ?? "",
      prevHash: json["prev_hash"] ?? "",
      hash: json["hash"] ?? "",
    );
  }
}

class SIEMConfig {
  final bool mfaEnforced;
  final bool mfaEnforcePrivileged;
  final int maxFailedLogins;
  final int lockoutDurationMinutes;
  final int passwordMinLength;
  final bool passwordRequireComplexity;
  final int sessionTimeoutMinutes;
  final bool siemEnabled;
  final String siemHost;
  final int siemPort;
  final String siemProtocol;
  final String siemFormat;
  final String updatedAt;

  SIEMConfig({
    this.mfaEnforced = false,
    this.mfaEnforcePrivileged = false,
    this.maxFailedLogins = 5,
    this.lockoutDurationMinutes = 15,
    this.passwordMinLength = 12,
    this.passwordRequireComplexity = true,
    this.sessionTimeoutMinutes = 15,
    this.siemEnabled = false,
    this.siemHost = '',
    this.siemPort = 514,
    this.siemProtocol = 'UDP',
    this.siemFormat = 'RFC5424',
    this.updatedAt = '',
  });

  factory SIEMConfig.fromJson(Map<String, dynamic> json) {
    return SIEMConfig(
      mfaEnforced: json['mfa_enforced'] == true,
      mfaEnforcePrivileged: json['mfa_enforce_privileged'] == true,
      maxFailedLogins: (json['max_failed_logins'] as num?)?.toInt() ?? 5,
      lockoutDurationMinutes: (json['lockout_duration_minutes'] as num?)?.toInt() ?? 15,
      passwordMinLength: (json['password_min_length'] as num?)?.toInt() ?? 12,
      passwordRequireComplexity: json['password_require_complexity'] != false,
      sessionTimeoutMinutes: (json['session_timeout_minutes'] as num?)?.toInt() ?? 15,
      siemEnabled: json['siem_enabled'] == true,
      siemHost: json['siem_host'] ?? '',
      siemPort: (json['siem_port'] as num?)?.toInt() ?? 514,
      siemProtocol: json['siem_protocol'] ?? 'UDP',
      siemFormat: json['siem_format'] ?? 'RFC5424',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mfa_enforced': mfaEnforced,
      'mfa_enforce_privileged': mfaEnforcePrivileged,
      'max_failed_logins': maxFailedLogins,
      'lockout_duration_minutes': lockoutDurationMinutes,
      'password_min_length': passwordMinLength,
      'password_require_complexity': passwordRequireComplexity,
      'session_timeout_minutes': sessionTimeoutMinutes,
      'siem_enabled': siemEnabled,
      'siem_host': siemHost,
      'siem_port': siemPort,
      'siem_protocol': siemProtocol,
      'siem_format': siemFormat,
    };
  }

  SIEMConfig copyWith({
    bool? mfaEnforced,
    bool? mfaEnforcePrivileged,
    int? maxFailedLogins,
    int? lockoutDurationMinutes,
    int? passwordMinLength,
    bool? passwordRequireComplexity,
    int? sessionTimeoutMinutes,
    bool? siemEnabled,
    String? siemHost,
    int? siemPort,
    String? siemProtocol,
    String? siemFormat,
    String? updatedAt,
  }) {
    return SIEMConfig(
      mfaEnforced: mfaEnforced ?? this.mfaEnforced,
      mfaEnforcePrivileged: mfaEnforcePrivileged ?? this.mfaEnforcePrivileged,
      maxFailedLogins: maxFailedLogins ?? this.maxFailedLogins,
      lockoutDurationMinutes: lockoutDurationMinutes ?? this.lockoutDurationMinutes,
      passwordMinLength: passwordMinLength ?? this.passwordMinLength,
      passwordRequireComplexity: passwordRequireComplexity ?? this.passwordRequireComplexity,
      sessionTimeoutMinutes: sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      siemEnabled: siemEnabled ?? this.siemEnabled,
      siemHost: siemHost ?? this.siemHost,
      siemPort: siemPort ?? this.siemPort,
      siemProtocol: siemProtocol ?? this.siemProtocol,
      siemFormat: siemFormat ?? this.siemFormat,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SIEMStats {
  final int totalDispatched;
  final int totalFailed;
  final int intrusionAlerts;
  final String? lastDispatchedAt;
  final String? lastFailedAt;
  final String lastError;
  final String status;

  SIEMStats({
    this.totalDispatched = 0,
    this.totalFailed = 0,
    this.intrusionAlerts = 0,
    this.lastDispatchedAt,
    this.lastFailedAt,
    this.lastError = '',
    this.status = 'DISABLED',
  });

  factory SIEMStats.fromJson(Map<String, dynamic> json) {
    return SIEMStats(
      totalDispatched: (json['total_dispatched'] as num?)?.toInt() ?? 0,
      totalFailed: (json['total_failed'] as num?)?.toInt() ?? 0,
      intrusionAlerts: (json['intrusion_alerts'] as num?)?.toInt() ?? 0,
      lastDispatchedAt: json['last_dispatched_at'],
      lastFailedAt: json['last_failed_at'],
      lastError: json['last_error'] ?? '',
      status: json['status'] ?? 'DISABLED',
    );
  }
}

class SIEMStatusResponse {
  final SIEMConfig config;
  final SIEMStats stats;
  final bool ensCompliant;
  final String ensMeasure;

  SIEMStatusResponse({
    required this.config,
    required this.stats,
    required this.ensCompliant,
    required this.ensMeasure,
  });

  factory SIEMStatusResponse.fromJson(Map<String, dynamic> json) {
    return SIEMStatusResponse(
      config: SIEMConfig.fromJson(json['config'] ?? {}),
      stats: SIEMStats.fromJson(json['stats'] ?? {}),
      ensCompliant: json['ens_compliant'] == true,
      ensMeasure: json['ens_measure'] ?? 'op.mon.2',
    );
  }
}

class AuditVerificationResult {
  final bool valid;
  final int totalRecords;
  final int verifiedRecords;
  final String lastHash;
  final String error;

  AuditVerificationResult({
    required this.valid,
    required this.totalRecords,
    required this.verifiedRecords,
    required this.lastHash,
    this.error = '',
  });

  factory AuditVerificationResult.fromJson(Map<String, dynamic> json) {
    return AuditVerificationResult(
      valid: json['valid'] == true,
      totalRecords: (json['total_records'] as num?)?.toInt() ?? 0,
      verifiedRecords: (json['verified_records'] as num?)?.toInt() ?? 0,
      lastHash: json['last_hash'] ?? '',
      error: json['error'] ?? '',
    );
  }
}

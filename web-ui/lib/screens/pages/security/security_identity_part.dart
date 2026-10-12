part of '../security_page.dart';

extension _SecurityIdentityExt on _SecurityPageState {
  // ---------------------------------------------------------------------------
  // LOCAL USER DIALOGS & ACTIONS
  // ---------------------------------------------------------------------------
  void _openUserDialog([LocalUser? user]) {
    final isEdit = user != null;
    final usernameCtrl = TextEditingController(text: user?.username ?? "");
    final passwordCtrl = TextEditingController();
    final displayNameCtrl = TextEditingController(text: user?.displayName ?? "");
    final emailCtrl = TextEditingController(text: user?.email ?? "");

    String role = user?.role ?? "operator";
    bool enabled = user?.enabled ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isEdit ? Icons.manage_accounts : Icons.person_add_alt_1,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(isEdit ? "Edit Local User account" : "Create New Local User"),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: usernameCtrl,
                      enabled: !isEdit,
                      decoration: const InputDecoration(
                        labelText: "Username *",
                        hintText: "e.g. operator_sec",
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!isEdit) ...[
                      TextField(
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Password *",
                          hintText: "Enter password",
                          helperText: "ENS op.acc.2: Min. 12 characters (uppercase, lowercase, numbers, and symbols)",
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: displayNameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Display Name",
                        hintText: "e.g. Security Specialist",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: "Email Address",
                        hintText: "user@company.local",
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(labelText: "Assigned Role"),
                      items: const [
                        DropdownMenuItem(value: "admin", child: Text("👑 Administrator")),
                        DropdownMenuItem(value: "operator", child: Text("⚡ Operator")),
                        DropdownMenuItem(value: "readonly", child: Text("👁️ Read-Only")),
                        DropdownMenuItem(value: "auditor", child: Text("🛡️ Security Auditor (ENS org.2)")),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => role = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: enabled ? Colors.green.withValues(alpha: 0.08) : Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: enabled ? Colors.green.withValues(alpha: 0.35) : Colors.amber.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            enabled ? Icons.check_circle_outline : Icons.pause_circle_outline,
                            color: enabled ? Colors.green : Colors.amber.shade800,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      enabled ? "Active Account" : "Suspended Account",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: enabled ? Colors.green.shade800 : Colors.amber.shade900,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (enabled ? Colors.green : Colors.amber).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        enabled ? "Access Allowed" : "Access Blocked",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: enabled ? Colors.green.shade800 : Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  enabled
                                      ? "The user can authenticate and operate normally."
                                      : "The user will NOT be able to sign in to Gubernator until reactivated.",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tooltip(
                            message: (user?.username.toLowerCase() == "admin")
                                ? "Primary 'admin' account cannot be suspended"
                                : (enabled ? "Temporarily suspend access" : "Activate account"),
                            child: Switch(
                              value: enabled,
                              activeThumbColor: Colors.green,
                              inactiveThumbColor: Colors.amber.shade800,
                              inactiveTrackColor: Colors.amber.withValues(alpha: 0.35),
                              onChanged: (user?.username.toLowerCase() == "admin")
                                  ? null
                                  : (v) => setDialogState(() => enabled = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () async {
                  final username = usernameCtrl.text.trim();
                  if (username.isEmpty) {
                    _showSnackBar("Username is required", isError: true);
                    return;
                  }

                  if (!isEdit) {
                    final pass = passwordCtrl.text;
                    if (pass.isEmpty) {
                      _showSnackBar("Password is required", isError: true);
                      return;
                    }
                    final res = await ApiService.createLocalUser(
                      username: username,
                      password: pass,
                      displayName: displayNameCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      role: role,
                      enabled: enabled,
                    );
                    if (res["error"] != null) {
                      _showSnackBar("Failed to create user: ${res['error']}", isError: true);
                      return;
                    }
                  } else {
                    final updatedUser = LocalUser(
                      id: user.id,
                      username: username,
                      displayName: displayNameCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      role: role,
                      enabled: enabled,
                      mfaEnabled: user.mfaEnabled,
                      createdAt: user.createdAt,
                      updatedAt: DateTime.now().toIso8601String(),
                    );
                    final res = await ApiService.updateLocalUser(updatedUser);
                    if (res["error"] != null) {
                      _showSnackBar("Failed to update user: ${res['error']}", isError: true);
                      return;
                    }
                  }

                  if (mounted) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    _showSnackBar(isEdit ? "User '$username' updated successfully" : "User '$username' created successfully");
                    _loadLocalUsers();
                  }
                },
                child: Text(isEdit ? "Save Changes" : "Create User"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openResetPasswordDialog(LocalUser user) {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.key, color: Colors.orange),
            const SizedBox(width: 10),
            Text("Reset Password - ${user.username}"),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "New Password",
                  hintText: "Enter new password",
                  helperText: "ENS op.acc.2: Min. 12 characters (uppercase, lowercase, numbers, and symbols)",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirm New Password",
                  hintText: "Confirm new password",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              final newPass = newPassCtrl.text;
              if (newPass.isEmpty) {
                _showSnackBar("New password cannot be empty", isError: true);
                return;
              }
              if (newPass != confirmPassCtrl.text) {
                _showSnackBar("Passwords do not match", isError: true);
                return;
              }
              final res = await ApiService.resetLocalUserPassword(user.id, newPass);
              if (res["error"] != null) {
                _showSnackBar("Failed: ${res["error"]}", isError: true);
                return;
              }
              if (mounted) {
                if (ctx.mounted) Navigator.pop(ctx);
                _showSnackBar("Password updated successfully for '${user.username}'");
              }
            },
            child: const Text("Reset Password"),
          ),
        ],
      ),
    );
  }

  void _unlockUser(LocalUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.lock_open, color: Colors.green),
            SizedBox(width: 10),
            Text("Unlock Account (ENS op.acc.2)"),
          ],
        ),
        content: Text("Do you want to unlock account '${user.username}' and reset its ${user.failedLoginAttempts} failed attempts?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Unlock Account"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService.unlockLocalUser(user.id);
      if (res["error"] != null) {
        _showSnackBar("Error unlocking account: ${res['error']}", isError: true);
      } else {
        _showSnackBar("Account '${user.username}' unlocked successfully (ENS op.acc.2)");
        _loadLocalUsers();
      }
    }
  }

  Future<void> _toggleUserStatus(LocalUser user, bool targetState) async {
    if (user.username.toLowerCase() == "admin" && !targetState) {
      _showSnackBar("Primary administrator account 'admin' cannot be suspended", isError: true);
      return;
    }

    if (!targetState) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.pause_circle_filled, color: Colors.amber, size: 24),
              SizedBox(width: 10),
              Text("Temporarily Suspend User"),
            ],
          ),
          content: Text(
            "Are you sure you want to temporarily suspend access for user '${user.username}'?\n\n"
            "The user will not be able to authenticate or access Gubernator services until reactivated.\n"
            "Data, roles, and configurations will remain intact.",
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Suspend Access"),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final res = await ApiService.toggleLocalUserStatus(user.id, enabled: targetState);
    if (res["error"] != null) {
      _showSnackBar("Error updating account status: ${res['error']}", isError: true);
    } else {
      _showSnackBar(
        targetState
            ? "Account '${user.username}' reactivated successfully"
            : "Account '${user.username}' temporarily suspended",
      );
      _loadLocalUsers();
    }
  }

  Future<void> _deleteUser(LocalUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Local User"),
        content: Text("Are you sure you want to delete user account '${user.username}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await ApiService.deleteLocalUser(user.id);
      if (ok) {
        if (mounted) {
          _showSnackBar("User account '${user.username}' removed");
          _loadLocalUsers();
        }
      } else {
        if (mounted) {
          _showSnackBar("Failed to remove user account", isError: true);
        }
      }
    }
  }

  void _openSetupMFADialog(LocalUser user) async {
    try {
      final res = await ApiService.setupMFA(userId: user.id);
      final secret = res['secret'] as String? ?? '';
      final qrDataUri = res['qr_data_uri'] as String? ?? '';
      final backupCodes = (res['backup_codes'] as List? ?? []).map((e) => e.toString()).toList();
      final codeCtrl = TextEditingController();
      bool enabling = false;
      String? error;
      bool showManualKey = false;

      Uint8List? qrImageBytes;
      if (qrDataUri.isNotEmpty) {
        try {
          final cleanBase64 = qrDataUri.contains(',') ? qrDataUri.split(',')[1] : qrDataUri;
          qrImageBytes = base64Decode(cleanBase64);
        } catch (_) {}
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.phonelink_lock, color: Color(0xFF0EA5E9)),
                  const SizedBox(width: 10),
                  Text("Configurar MFA (ENS op.acc.2) — ${user.username}"),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Step 1: Scan the QR code with Google Authenticator",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Open Google Authenticator (or any compatible TOTP app) on your mobile device and scan this QR code:",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      if (qrImageBytes != null) ...[
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    qrImageBytes,
                                    width: 180,
                                    height: 180,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.qr_code_scanner, size: 15, color: Color(0xFF0EA5E9)),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Google Authenticator",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      InkWell(
                        onTap: () {
                          setDialogState(() => showManualKey = !showManualKey);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          child: Row(
                            children: [
                              Icon(
                                showManualKey ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                                size: 18,
                                color: const Color(0xFF0EA5E9),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                showManualKey ? "Hide manual Base32 key" : "Can't scan? View manual Base32 key",
                                style: const TextStyle(fontSize: 12, color: Color(0xFF0EA5E9), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (showManualKey) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  secret,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                tooltip: "Copy secret key",
                                onPressed: () {
                                  html.window.navigator.clipboard?.writeText(secret);
                                  _showSnackBar("Secret key copied to clipboard");
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      const Text(
                        "Step 2: Save your recovery backup codes (Single use)",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "If you lose your device, you can sign in using any of these recovery codes:",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: backupCodes.map((c) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                ),
                                child: Text(c, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
                              )).toList(),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.copy, size: 14),
                                label: const Text("Copy all codes", style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  html.window.navigator.clipboard?.writeText(backupCodes.join("\n"));
                                  _showSnackBar("Backup recovery codes copied");
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Step 3: Enter the 6-digit verification code to activate:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: codeCtrl,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          hintText: "000000",
                          labelText: "TOTP Code (6 digits)",
                          prefixIcon: Icon(Icons.pin),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancelar"),
                ),
                FilledButton(
                  onPressed: enabling ? null : () async {
                    final code = codeCtrl.text.trim();
                    if (code.isEmpty) {
                      setDialogState(() => error = "Enter the 6-digit code generated by your app");
                      return;
                    }
                    setDialogState(() {
                      enabling = true;
                      error = null;
                    });
                    final result = await ApiService.enableMFA(
                      userId: user.id,
                      secret: secret,
                      code: code,
                      backupCodes: backupCodes,
                    );
                    if (result['error'] != null) {
                      setDialogState(() {
                        enabling = false;
                        error = result['error'].toString();
                      });
                      return;
                    }
                    if (mounted) {
                      if (ctx.mounted) Navigator.pop(ctx);
                      _showSnackBar("MFA enabled successfully for '${user.username}' (ENS op.acc.2)");
                      _loadLocalUsers();
                    }
                  },
                  child: enabling ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Verify & Enable MFA"),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      _showSnackBar("Error starting MFA setup: $e", isError: true);
    }
  }

  void _disableMFA(LocalUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text("Disable MFA"),
          ],
        ),
        content: Text("Are you sure you want to disable Multi-Factor Authentication for user '${user.username}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await ApiService.disableMFA(userId: user.id);
              if (res['error'] != null) {
                _showSnackBar("Error disabling MFA: ${res['error']}", isError: true);
              } else {
                _showSnackBar("MFA disabled for '${user.username}'");
                _loadLocalUsers();
                _loadComplianceOverview();
                _loadENSStatus();
              }
            },
            child: const Text("Disable"),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LDAP DIALOG & ACTIONS (Preserved)
  // ---------------------------------------------------------------------------
  void _openLDAPDialog([LDAPConfig? config]) {
    final isEdit = config != null;
    final nameCtrl = TextEditingController(text: config?.name ?? "Corporate Active Directory");
    final hostCtrl = TextEditingController(text: config?.host ?? "");
    final portCtrl = TextEditingController(text: (config?.port ?? 389).toString());
    final baseDnCtrl = TextEditingController(text: config?.baseDn ?? "DC=corp,DC=local");
    final bindDnCtrl = TextEditingController(text: config?.bindDn ?? "");
    final bindPassCtrl = TextEditingController(text: config?.bindPassword ?? "");
    final userFilterCtrl = TextEditingController(text: config?.userFilter ?? "(&(objectClass=user)(sAMAccountName=%s))");
    final userAttrCtrl = TextEditingController(text: config?.userAttr ?? "sAMAccountName");
    final groupBaseDnCtrl = TextEditingController(text: config?.groupBaseDn ?? "");
    final adminGroupCtrl = TextEditingController(text: config?.adminGroupDn ?? "CN=Gubernator_Admins,OU=Groups,DC=corp,DC=local");
    final operatorGroupCtrl = TextEditingController(text: config?.operatorGroupDn ?? "CN=Gubernator_Operators,OU=Groups,DC=corp,DC=local");
    final readOnlyGroupCtrl = TextEditingController(text: config?.readOnlyGroupDn ?? "CN=Gubernator_Viewers,OU=Groups,DC=corp,DC=local");

    String security = config?.security ?? "none";
    bool insecureSkipVerify = config?.insecureSkipVerify ?? false;
    bool enabled = config?.enabled ?? true;
    String defaultRole = config?.defaultRole ?? "readonly";

    bool testing = false;
    LDAPTestResult? testResult;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isEdit ? Icons.edit_note : Icons.add_moderator,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(isEdit ? "Edit Directory Server" : "Add Active Directory / LDAP Server"),
              ],
            ),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: "Display Name *",
                              hintText: "e.g. Corporate Active Directory",
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SwitchListTile(
                            title: const Text("Enabled", style: TextStyle(fontSize: 13)),
                            value: enabled,
                            onChanged: (v) => setDialogState(() => enabled = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: hostCtrl,
                            decoration: const InputDecoration(
                              labelText: "LDAP Host / IP *",
                              hintText: "dc1.company.local",
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: portCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Port",
                              hintText: "389 / 636",
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: security,
                            decoration: const InputDecoration(labelText: "Security Mode"),
                            items: const [
                              DropdownMenuItem(value: "none", child: Text("None (389)")),
                              DropdownMenuItem(value: "tls", child: Text("LDAPS / TLS (636)")),
                              DropdownMenuItem(value: "starttls", child: Text("StartTLS")),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() {
                                  security = v;
                                  if (v == "tls" && portCtrl.text == "389") {
                                    portCtrl.text = "636";
                                  } else if (v == "none" && portCtrl.text == "636") {
                                    portCtrl.text = "389";
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Insecure Skip Verify (Accept self-signed domain certificates)", style: TextStyle(fontSize: 12.5)),
                      value: insecureSkipVerify,
                      onChanged: (v) => setDialogState(() => insecureSkipVerify = v ?? false),
                    ),
                    const Divider(height: 24),
                    const Text("Search Credentials (Service Account)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: baseDnCtrl,
                      decoration: const InputDecoration(
                        labelText: "Base DN (Search Base) *",
                        hintText: "DC=company,DC=local",
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: bindDnCtrl,
                            decoration: const InputDecoration(
                              labelText: "Bind DN / Service User",
                              hintText: "CN=svc_gubernator,OU=ServiceAccounts,DC=company,DC=local",
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: bindPassCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: "Bind Password",
                              hintText: "Enter bind password",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text("User Search Filter", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: userFilterCtrl,
                            decoration: const InputDecoration(
                              labelText: "User Filter Query",
                              hintText: "(&(objectClass=user)(sAMAccountName=%s))",
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: userAttrCtrl,
                            decoration: const InputDecoration(
                              labelText: "User Attribute",
                              hintText: "sAMAccountName",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text("Group to Role Mappings (RBAC)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: groupBaseDnCtrl,
                      decoration: const InputDecoration(
                        labelText: "Group Base DN (Optional)",
                        hintText: "OU=Groups,DC=company,DC=local",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: adminGroupCtrl,
                      decoration: const InputDecoration(
                        labelText: "Administrator Group DN",
                        hintText: "CN=Gubernator_Admins,OU=Groups,DC=company,DC=local",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: operatorGroupCtrl,
                      decoration: const InputDecoration(
                        labelText: "Operator Group DN",
                        hintText: "CN=Gubernator_Operators,OU=Groups,DC=company,DC=local",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: readOnlyGroupCtrl,
                      decoration: const InputDecoration(
                        labelText: "Read-Only Group DN",
                        hintText: "CN=Gubernator_Viewers,OU=Groups,DC=company,DC=local",
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: defaultRole,
                      decoration: const InputDecoration(labelText: "Fallback Default Role (Unmapped Users)"),
                      items: const [
                        DropdownMenuItem(value: "admin", child: Text("👑 Administrator")),
                        DropdownMenuItem(value: "operator", child: Text("⚡ Operator")),
                        DropdownMenuItem(value: "readonly", child: Text("👁️ Read-Only")),
                        DropdownMenuItem(value: "auditor", child: Text("🛡️ Security Auditor (ENS org.2)")),
                        DropdownMenuItem(value: "none", child: Text("🚫 Deny Access (No Role)")),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => defaultRole = v);
                      },
                    ),

                    if (testing) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 4),
                      const Text("Testing connection to LDAP server...", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    ],

                    if (testResult != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: testResult!.connected ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: testResult!.connected ? Colors.green : Colors.red),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  testResult!.connected ? Icons.check_circle : Icons.error,
                                  color: testResult!.connected ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  testResult!.message,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: testResult!.connected ? Colors.green.shade800 : Colors.red.shade800,
                                  ),
                                ),
                                const Spacer(),
                                Text("${testResult!.latencyMs} ms", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton.icon(
                icon: const Icon(Icons.bolt, size: 16),
                label: const Text("Test Connection"),
                onPressed: testing
                    ? null
                    : () async {
                        final host = hostCtrl.text.trim();
                        final baseDn = baseDnCtrl.text.trim();
                        if (host.isEmpty || baseDn.isEmpty) {
                          _showSnackBar("Host and Base DN are required for testing", isError: true);
                          return;
                        }
                        setDialogState(() {
                          testing = true;
                          testResult = null;
                        });

                        final cfg = LDAPConfig(
                          id: config?.id ?? "",
                          name: nameCtrl.text.trim(),
                          enabled: enabled,
                          host: host,
                          port: int.tryParse(portCtrl.text) ?? 389,
                          security: security,
                          insecureSkipVerify: insecureSkipVerify,
                          bindDn: bindDnCtrl.text.trim(),
                          bindPassword: bindPassCtrl.text,
                          baseDn: baseDn,
                          userFilter: userFilterCtrl.text.trim(),
                          userAttr: userAttrCtrl.text.trim(),
                          groupBaseDn: groupBaseDnCtrl.text.trim(),
                          adminGroupDn: adminGroupCtrl.text.trim(),
                          operatorGroupDn: operatorGroupCtrl.text.trim(),
                          readOnlyGroupDn: readOnlyGroupCtrl.text.trim(),
                          defaultRole: defaultRole,
                        );

                        final res = await ApiService.testLDAPConfig(cfg);
                        setDialogState(() {
                          testing = false;
                          testResult = res;
                        });
                      },
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final host = hostCtrl.text.trim();
                  final baseDn = baseDnCtrl.text.trim();

                  if (name.isEmpty || host.isEmpty || baseDn.isEmpty) {
                    _showSnackBar("Please fill all required fields (*)", isError: true);
                    return;
                  }

                  final cfg = LDAPConfig(
                    id: config?.id ?? "",
                    name: name,
                    enabled: enabled,
                    host: host,
                    port: int.tryParse(portCtrl.text) ?? 389,
                    security: security,
                    insecureSkipVerify: insecureSkipVerify,
                    bindDn: bindDnCtrl.text.trim(),
                    bindPassword: bindPassCtrl.text,
                    baseDn: baseDn,
                    userFilter: userFilterCtrl.text.trim(),
                    userAttr: userAttrCtrl.text.trim(),
                    groupBaseDn: groupBaseDnCtrl.text.trim(),
                    adminGroupDn: adminGroupCtrl.text.trim(),
                    operatorGroupDn: operatorGroupCtrl.text.trim(),
                    readOnlyGroupDn: readOnlyGroupCtrl.text.trim(),
                    defaultRole: defaultRole,
                  );

                  final res = await ApiService.saveLDAPConfig(cfg);
                  if (res["error"] != null) {
                    _showSnackBar("Failed to save directory config: ${res["error"]}", isError: true);
                    return;
                  }

                  if (mounted) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    _showSnackBar("Directory server configuration saved");
                    _loadLDAPConfigs();
                  }
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteLDAP(LDAPConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Directory Server"),
        content: Text("Are you sure you want to remove '${config.name}'? Users from this domain will no longer be able to authenticate."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await ApiService.deleteLDAPConfig(config.id);
      if (ok) {
        if (mounted) {
          _showSnackBar("Directory server removed");
          _loadLDAPConfigs();
        }
      } else {
        if (mounted) {
          _showSnackBar("Failed to remove directory server", isError: true);
        }
      }
    }
  }


  // ---------------------------------------------------------------------------
  // TAB 1: LOCAL USERS
  // ---------------------------------------------------------------------------
  Widget _buildLocalUsersTab(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Configured Local Users",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text("Add Local User"),
                onPressed: () => _openUserDialog(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_usersLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_usersError != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text("Error loading local users: ${_usersError!}", style: const TextStyle(color: Colors.red)),
            )
          else if (_localUsers.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Icon(Icons.no_accounts, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text("No local user accounts configured", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text("Create a local account to manage emergency cluster access.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2)),
              ),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text("Username")),
                  DataColumn(label: Text("Display Name")),
                  DataColumn(label: Text("Email")),
                  DataColumn(label: Text("Role")),
                  DataColumn(label: Text("Status")),
                  DataColumn(label: Text("MFA (ENS)")),
                  DataColumn(label: Text("Last Login")),
                  DataColumn(label: Text("Actions")),
                ],
                rows: _localUsers.map((usr) {
                  return DataRow(
                    cells: [
                      DataCell(Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: primaryColor.withValues(alpha: 0.2),
                            child: Text(usr.username.substring(0, 1).toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor)),
                          ),
                          const SizedBox(width: 8),
                          Text(usr.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )),
                      DataCell(Text(usr.displayName.isEmpty ? "-" : usr.displayName)),
                      DataCell(Text(usr.email.isEmpty ? "-" : usr.email)),
                      DataCell(_buildRoleBadgeLabel(usr.role)),
                      DataCell(
                        usr.isLocked
                            ? Tooltip(
                                message: "Locked due to ${usr.failedLoginAttempts} failed attempts until ${usr.lockedUntil} (ENS op.acc.2)",
                                child: Chip(
                                  avatar: const Icon(Icons.lock, size: 14, color: Colors.deepOrange),
                                  label: Text("Locked (${usr.lockRemainingMinutes}m)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrange.shade800)),
                                  backgroundColor: Colors.deepOrange.withValues(alpha: 0.15),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(
                                    avatar: Icon(
                                      usr.enabled ? Icons.check_circle : Icons.pause_circle_filled,
                                      size: 14,
                                      color: usr.enabled ? Colors.green : Colors.amber.shade800,
                                    ),
                                    label: Text(
                                      usr.enabled ? "Active" : "Suspended",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: usr.enabled ? Colors.green.shade800 : Colors.amber.shade900,
                                      ),
                                    ),
                                    backgroundColor: (usr.enabled ? Colors.green : Colors.amber).withValues(alpha: 0.14),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  const SizedBox(width: 8),
                                  Tooltip(
                                    message: usr.username.toLowerCase() == "admin"
                                        ? "Primary administrator 'admin' cannot be suspended"
                                        : (usr.enabled ? "Click to temporarily suspend" : "Click to reactivate user"),
                                    child: Transform.scale(
                                      scale: 0.8,
                                      child: Switch(
                                        value: usr.enabled,
                                        activeThumbColor: Colors.green,
                                        inactiveThumbColor: Colors.amber.shade800,
                                        inactiveTrackColor: Colors.amber.withValues(alpha: 0.3),
                                        onChanged: usr.username.toLowerCase() == "admin"
                                            ? null
                                            : (bool val) => _toggleUserStatus(usr, val),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      DataCell(
                        Builder(builder: (ctx) {
                          final isPrivileged = usr.role.toLowerCase() == "admin" || usr.role.toLowerCase() == "operator";
                          final isEnforced = (_siemConfig?.mfaEnforcePrivileged == true && isPrivileged) || (_siemConfig?.mfaEnforced == true);
                          if (usr.mfaEnabled) {
                            return Chip(
                              avatar: Icon(Icons.shield, size: 14, color: Colors.tealAccent.shade700),
                              label: Text("MFA Active", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
                              backgroundColor: Colors.teal.withValues(alpha: 0.12),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            );
                          } else if (isEnforced) {
                            return Tooltip(
                              message: "MFA mandatory under ENS op.acc.6 policy. Enrollment will be enforced on next login.",
                              child: Chip(
                                avatar: const Icon(Icons.shield_outlined, size: 14, color: Colors.amber),
                                label: const Text("Pending (ENS)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber)),
                                backgroundColor: Colors.amber.withValues(alpha: 0.15),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            );
                          } else {
                            return Chip(
                              avatar: const Icon(Icons.shield_outlined, size: 14, color: Colors.grey),
                              label: Text("Off", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                              backgroundColor: Colors.grey.withValues(alpha: 0.12),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            );
                          }
                        }),
                      ),
                      DataCell(Text(usr.lastLogin != null ? usr.lastLogin!.split("T")[0] : "Never")),
                      DataCell(Row(
                        children: [
                          if (usr.isLocked)
                            IconButton(
                              icon: const Icon(Icons.lock_open, size: 18, color: Colors.green),
                              tooltip: "Unlock Account (ENS op.acc.2)",
                              onPressed: () => _unlockUser(usr),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            tooltip: "Edit User",
                            onPressed: () => _openUserDialog(usr),
                          ),
                          if (usr.username.toLowerCase() != "admin")
                            IconButton(
                              icon: Icon(
                                usr.enabled ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                size: 18,
                                color: usr.enabled ? Colors.amber.shade800 : Colors.green,
                              ),
                              tooltip: usr.enabled ? "Suspend User" : "Reactivate User",
                              onPressed: () => _toggleUserStatus(usr, !usr.enabled),
                            ),
                          IconButton(
                            icon: Icon(
                              usr.mfaEnabled ? Icons.phonelink_erase : Icons.phonelink_lock,
                              size: 18,
                              color: usr.mfaEnabled ? Colors.purple : Colors.teal,
                            ),
                            tooltip: usr.mfaEnabled ? "Disable MFA (ENS)" : "Setup MFA / TOTP (ENS)",
                            onPressed: () {
                              if (usr.mfaEnabled) {
                                _disableMFA(usr);
                              } else {
                                _openSetupMFADialog(usr);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.key, size: 18, color: Colors.orange),
                            tooltip: "Reset Password",
                            onPressed: () => _openResetPasswordDialog(usr),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            tooltip: "Delete User",
                            onPressed: () => _deleteUser(usr),
                          ),
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: ACTIVE DIRECTORY / LDAP
  // ---------------------------------------------------------------------------
  Widget _buildLDAPTab(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Connected Active Directory / LDAP Servers",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add Directory Server"),
                onPressed: () => _openLDAPDialog(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_ldapLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_ldapError != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text("Error loading directory servers: ${_ldapError!}", style: const TextStyle(color: Colors.red)),
            )
          else if (_ldapConfigs.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Icon(Icons.dns, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text("No Active Directory / LDAP servers configured", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text("Connect an Active Directory domain or OpenLDAP server to enable SSO and group RBAC.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ldapConfigs.length,
              itemBuilder: (ctx, idx) {
                final cfg = _ldapConfigs[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cfg.enabled ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                      child: Icon(Icons.lan, color: cfg.enabled ? Colors.green : Colors.grey),
                    ),
                    title: Text(cfg.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${cfg.host}:${cfg.port} | Security: ${cfg.security.toUpperCase()} | Base DN: ${cfg.baseDn}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _openLDAPDialog(cfg),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => _deleteLDAP(cfg),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: SSO / OIDC PROVIDERS
  // ---------------------------------------------------------------------------
  Widget _buildOIDCTab(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SSO / OIDC Identity Providers",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "OAuth2 / OpenID Connect providers for Single Sign-On authentication.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add_link, size: 18),
                label: const Text("Add SSO Provider"),
                onPressed: () => _openOIDCDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // OIDC info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF8B5CF6), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "OIDC/OAuth2 providers appear as SSO buttons on the login page. "
                    "Supported: Keycloak, Google Workspace, Microsoft Azure AD, GitHub, Okta, "
                    "and any generic OpenID Connect 1.0 server. "
                    "Uses PKCE (Proof Key for Code Exchange) for secure authorization.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Provider cards / loading / error / empty
          if (_oidcLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_oidcError != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text("Error: $_oidcError", style: const TextStyle(color: Colors.red)),
            )
          else if (_oidcConfigs.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.vpn_key_outlined, size: 52, color: Color(0xFF8B5CF6)),
                  const SizedBox(height: 14),
                  const Text(
                    "No SSO providers configured",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Add a Keycloak, Google, Azure AD, GitHub, or Okta provider\nto enable Single Sign-On on the login screen.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_link, size: 18),
                    label: const Text("Add Your First SSO Provider"),
                    onPressed: () => _openOIDCDialog(),
                  ),
                ],
              ),
            )
          else
            ...(_oidcConfigs.map((cfg) => _buildOIDCProviderCard(cfg, isDark, primaryColor))),
        ],
      ),
    );
  }

  Widget _buildOIDCProviderCard(OIDCConfig cfg, bool isDark, Color primaryColor) {
    final meta = _oidcProviderMeta(cfg.providerType, cfg.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Provider icon badge
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: meta.color.withValues(alpha: 0.3)),
            ),
            child: Icon(meta.icon, color: meta.color, size: 24),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      cfg.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    _oidcBadge(cfg.providerType, meta.color),
                    const SizedBox(width: 8),
                    if (!cfg.enabled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "DISABLED",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  cfg.issuerUrl,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.key, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      "Client: ${cfg.clientId.length > 20 ? '${cfg.clientId.substring(0, 20)}…' : cfg.clientId}",
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    const SizedBox(width: 14),
                    Icon(Icons.manage_accounts, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      "Default role: ${cfg.defaultRole}",
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          IconButton(
            icon: const Icon(Icons.wifi_find_outlined, size: 20),
            tooltip: "Test Connection",
            onPressed: () => _testOIDCConfig(cfg),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: "Edit",
            onPressed: () => _openOIDCDialog(cfg),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            tooltip: "Delete",
            onPressed: () => _deleteOIDCConfig(cfg),
          ),
        ],
      ),
    );
  }

  Widget _oidcBadge(String providerType, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        providerType.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  /// Maps provider type to icon + color + label (shared with login screen concept)
  ({IconData icon, Color color}) _oidcProviderMeta(String providerType, String name) {
    switch (providerType) {
      case 'keycloak': return (icon: Icons.lock_open, color: const Color(0xFF00B8D9));
      case 'google':   return (icon: Icons.g_mobiledata, color: const Color(0xFF4285F4));
      case 'github':   return (icon: Icons.code, color: const Color(0xFF6E5494));
      case 'azure':    return (icon: Icons.cloud, color: const Color(0xFF0089D6));
      case 'okta':     return (icon: Icons.shield_outlined, color: const Color(0xFF007DC1));
      default:         return (icon: Icons.vpn_key_outlined, color: const Color(0xFF8B5CF6));
    }
  }

  void _openOIDCDialog([OIDCConfig? existing]) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final issuerCtrl = TextEditingController(text: existing?.issuerUrl ?? '');
    final clientIdCtrl = TextEditingController(text: existing?.clientId ?? '');
    final clientSecretCtrl = TextEditingController(text: existing?.clientSecret ?? '');
    final redirectUriCtrl = TextEditingController(text: existing?.redirectUri ?? '');
    final scopesCtrl = TextEditingController(text: existing?.scopes ?? 'openid profile email');
    final roleClaimCtrl = TextEditingController(text: existing?.roleClaimPath ?? 'groups');
    final adminClaimCtrl = TextEditingController(text: existing?.adminClaim ?? '');
    final operatorClaimCtrl = TextEditingController(text: existing?.operatorClaim ?? '');
    final readonlyClaimCtrl = TextEditingController(text: existing?.readonlyClaim ?? '');

    String providerType = existing?.providerType ?? 'generic';
    String defaultRole = existing?.defaultRole ?? 'readonly';
    bool enabled = existing?.enabled ?? true;
    bool insecureSkipVerify = existing?.insecureSkipVerify ?? false;
    bool isTesting = false;
    OIDCTestResult? testResult;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          void applyPreset(OIDCProviderPreset preset) {
            setDialogState(() {
              providerType = preset.type;
              issuerCtrl.text = preset.issuerUrl;
              scopesCtrl.text = preset.scopes;
              roleClaimCtrl.text = preset.roleClaimPath;
              if (nameCtrl.text.isEmpty) nameCtrl.text = preset.name;
            });
          }

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isEdit ? Icons.edit_outlined : Icons.add_link,
                  color: const Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 10),
                Text(isEdit ? "Edit SSO / OIDC Provider" : "Add SSO / OIDC Provider"),
              ],
            ),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Provider type preset picker
                    if (!isEdit && _oidcPresets.isNotEmpty) ...[
                      const Text(
                        "Quick Start — Select a provider template:",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _oidcPresets.map((p) {
                          final meta = _oidcProviderMeta(p.type, p.name);
                          final isSelected = providerType == p.type;
                          return InkWell(
                            onTap: () => applyPreset(p),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? meta.color.withValues(alpha: 0.15)
                                    : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? meta.color : Colors.grey.withValues(alpha: 0.25),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(meta.icon, color: meta.color, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    p.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? meta.color : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const Divider(height: 28),
                    ],

                    // Provider type dropdown (for edit or manual)
                    DropdownButtonFormField<String>(
                      key: ValueKey(providerType),
                      initialValue: providerType,
                      decoration: const InputDecoration(labelText: "Provider Type *"),
                      items: const [
                        DropdownMenuItem(value: 'generic', child: Text("Generic OpenID Connect")),
                        DropdownMenuItem(value: 'keycloak', child: Text("Keycloak")),
                        DropdownMenuItem(value: 'google', child: Text("Google Workspace")),
                        DropdownMenuItem(value: 'github', child: Text("GitHub")),
                        DropdownMenuItem(value: 'azure', child: Text("Microsoft Azure AD")),
                        DropdownMenuItem(value: 'okta', child: Text("Okta")),
                      ],
                      onChanged: (v) => setDialogState(() => providerType = v ?? 'generic'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Display Name *",
                        hintText: "e.g. Corporate Keycloak",
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: issuerCtrl,
                      decoration: const InputDecoration(
                        labelText: "Issuer URL *",
                        hintText: "https://auth.company.com/realms/corporate",
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: clientIdCtrl,
                            decoration: const InputDecoration(
                              labelText: "Client ID *",
                              hintText: "gubernator",
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: clientSecretCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: "Client Secret",
                              hintText: "Leave blank to keep existing",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: redirectUriCtrl,
                      decoration: const InputDecoration(
                        labelText: "Redirect URI (optional)",
                        hintText: "Auto-detected if empty — https://gbnt.company.com/api/auth/oidc/callback",
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: scopesCtrl,
                            decoration: const InputDecoration(
                              labelText: "Scopes",
                              hintText: "openid profile email groups",
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: roleClaimCtrl,
                            decoration: const InputDecoration(
                              labelText: "Role Claim Path",
                              hintText: "groups",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      "RBAC Group/Claim Mapping",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Map claim values from the token to Gubernator roles. Leave empty to use the default role.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: adminClaimCtrl,
                            decoration: const InputDecoration(
                              labelText: "Admin Claim Value",
                              hintText: "gbnt-admins",
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: operatorClaimCtrl,
                            decoration: const InputDecoration(
                              labelText: "Operator Claim Value",
                              hintText: "gbnt-operators",
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: readonlyClaimCtrl,
                            decoration: const InputDecoration(
                              labelText: "Read-Only Claim Value",
                              hintText: "gbnt-viewers",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: ValueKey(defaultRole),
                      initialValue: defaultRole,
                      decoration: const InputDecoration(labelText: "Default Role"),
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text("👑 Administrator")),
                        DropdownMenuItem(value: 'operator', child: Text("⚡ Operator")),
                        DropdownMenuItem(value: 'readonly', child: Text("👁️ Read-Only")),
                        DropdownMenuItem(value: 'auditor', child: Text("🛡️ Security Auditor (ENS org.2)")),
                      ],
                      onChanged: (v) => setDialogState(() => defaultRole = v ?? 'readonly'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Provider Enabled", style: TextStyle(fontSize: 13)),
                            value: enabled,
                            onChanged: (v) => setDialogState(() => enabled = v),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Skip TLS Verify", style: TextStyle(fontSize: 13, color: Colors.orange)),
                            value: insecureSkipVerify,
                            onChanged: (v) => setDialogState(() => insecureSkipVerify = v),
                          ),
                        ),
                      ],
                    ),

                    // Test result
                    if (isTesting) ...[
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text("Testing OIDC discovery endpoint...", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ] else if (testResult != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: testResult!.connected
                              ? Colors.green.withValues(alpha: 0.08)
                              : Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: testResult!.connected
                                ? Colors.green.withValues(alpha: 0.3)
                                : Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  testResult!.connected ? Icons.check_circle : Icons.error_outline,
                                  color: testResult!.connected ? Colors.green : Colors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  testResult!.connected ? "Connection Successful" : "Connection Failed",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: testResult!.connected ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _testRow("Issuer Reachable", testResult!.issuerReachable),
                            _testRow("Discovery OK", testResult!.discoveryOk),
                            _testRow("JWKS Reachable", testResult!.jwksReachable),
                            if (testResult!.keyCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  "✓ ${testResult!.keyCount} signing key(s) found",
                                  style: const TextStyle(fontSize: 12, color: Colors.green),
                                ),
                              ),
                            if (testResult!.authorizationEndpoint.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  "Auth: ${testResult!.authorizationEndpoint}",
                                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (testResult!.message.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  testResult!.message,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: testResult!.connected ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              // Test connection
              OutlinedButton.icon(
                icon: const Icon(Icons.wifi_find_outlined, size: 16),
                label: const Text("Test Connection"),
                onPressed: isTesting
                    ? null
                    : () async {
                        final cfg = OIDCConfig(
                          id: existing?.id ?? '',
                          name: nameCtrl.text.trim(),
                          providerType: providerType,
                          issuerUrl: issuerCtrl.text.trim(),
                          clientId: clientIdCtrl.text.trim(),
                          clientSecret: clientSecretCtrl.text,
                          redirectUri: redirectUriCtrl.text.trim(),
                          scopes: scopesCtrl.text.trim(),
                          roleClaimPath: roleClaimCtrl.text.trim(),
                          adminClaim: adminClaimCtrl.text.trim(),
                          operatorClaim: operatorClaimCtrl.text.trim(),
                          readonlyClaim: readonlyClaimCtrl.text.trim(),
                          defaultRole: defaultRole,
                          insecureSkipVerify: insecureSkipVerify,
                        );
                        setDialogState(() {
                          isTesting = true;
                          testResult = null;
                        });
                        final res = await ApiService.testOIDCConfig(cfg);
                        setDialogState(() {
                          isTesting = false;
                          testResult = res;
                        });
                      },
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final issuer = issuerCtrl.text.trim();
                  final clientId = clientIdCtrl.text.trim();
                  if (name.isEmpty || issuer.isEmpty || clientId.isEmpty) {
                    _showSnackBar("Name, Issuer URL, and Client ID are required", isError: true);
                    return;
                  }
                  final cfg = OIDCConfig(
                    id: existing?.id ?? '',
                    name: name,
                    providerType: providerType,
                    enabled: enabled,
                    issuerUrl: issuer,
                    clientId: clientId,
                    clientSecret: clientSecretCtrl.text,
                    redirectUri: redirectUriCtrl.text.trim(),
                    scopes: scopesCtrl.text.trim(),
                    roleClaimPath: roleClaimCtrl.text.trim(),
                    adminClaim: adminClaimCtrl.text.trim(),
                    operatorClaim: operatorClaimCtrl.text.trim(),
                    readonlyClaim: readonlyClaimCtrl.text.trim(),
                    defaultRole: defaultRole,
                    insecureSkipVerify: insecureSkipVerify,
                  );
                  final res = await ApiService.saveOIDCConfig(cfg);
                  if (res['error'] != null) {
                    if (mounted) _showSnackBar("Failed: ${res['error']}", isError: true);
                    return;
                  }
                  if (mounted) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    _showSnackBar(isEdit
                        ? "SSO provider '${cfg.name}' updated successfully"
                        : "SSO provider '${cfg.name}' added — it will appear on the login screen");
                    _loadOIDCConfigs();
                  }
                },
                child: Text(isEdit ? "Save Changes" : "Add Provider"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _testRow(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(ok ? Icons.check : Icons.close, size: 14, color: ok ? Colors.green : Colors.red),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _testOIDCConfig(OIDCConfig cfg) async {
    _showSnackBar("Testing connection to ${cfg.name}...");
    final result = await ApiService.testOIDCConfig(cfg);
    if (!mounted) return;
    final msg = result.connected
        ? "✓ ${cfg.name} — OIDC discovery OK (${result.keyCount} signing keys, ${result.latencyMs}ms)"
        : "✗ ${cfg.name} — ${result.message}";
    _showSnackBar(msg, isError: !result.connected);
  }

  Future<void> _deleteOIDCConfig(OIDCConfig cfg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove SSO Provider"),
        content: Text(
          "Remove '${cfg.name}'?\n\nThe SSO button will disappear from the login screen immediately.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await ApiService.deleteOIDCConfig(cfg.id);
      if (ok) {
        if (mounted) {
          _showSnackBar("SSO provider '${cfg.name}' removed");
          _loadOIDCConfigs();
        }
      } else {
        if (mounted) _showSnackBar("Failed to remove provider", isError: true);
      }
    }
  }


  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  Widget _buildRoleBadgeLabel(String role) {
    switch (role.toLowerCase()) {
      case "admin":
        return const Chip(
          avatar: Text("👑", style: TextStyle(fontSize: 10)),
          label: Text("Administrator", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber)),
          backgroundColor: Color(0x33FFC107),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      case "operator":
        return const Chip(
          avatar: Text("⚡", style: TextStyle(fontSize: 10)),
          label: Text("Operator", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
          backgroundColor: Color(0x332196F3),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      case "auditor":
        return const Chip(
          avatar: Text("🛡️", style: TextStyle(fontSize: 10)),
          label: Text("Auditor (ENS org.2)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
          backgroundColor: Color(0x3314B8A6),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      default:
        return const Chip(
          avatar: Text("👁️", style: TextStyle(fontSize: 10)),
          label: Text("Read-Only", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
          backgroundColor: Color(0x334CAF50),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
    }
  }

}

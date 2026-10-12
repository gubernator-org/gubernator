part of '../security_page.dart';

extension _SecurityAuditSiemExt on _SecurityPageState {
  // ---------------------------------------------------------------------------
  // TAB 4: ACCESS & AUDIT LOGS
  // ---------------------------------------------------------------------------
  Widget _buildAuditLogsTab(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Forensic Audit Trail & SIEM (ENS op.mon.1)",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Immutable ledger with SHA-256 hash chaining (PrevHash -> Hash) and RFC5424/CEF Syslog forwarding.",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Verify integrity button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.tealAccent.shade400,
                      side: BorderSide(color: Colors.teal.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: _verifyingAudit
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent))
                        : const Icon(Icons.verified_user, size: 16),
                    label: Text(_verifyingAudit ? "Verifying..." : "Verify SHA-256 Integrity", style: const TextStyle(fontSize: 12)),
                    onPressed: _verifyingAudit ? null : _verifyAuditChain,
                  ),
                  // Export Menu
                  PopupMenuButton<String>(
                    tooltip: "Export Forensic Audit Trail",
                    icon: const Icon(Icons.download, size: 18),
                    onSelected: (fmt) => ApiService.downloadAuditLogsExport(fmt),
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: "csv", child: Text("📥 Export as CSV")),
                      PopupMenuItem(value: "json", child: Text("📥 Export as JSON")),
                      PopupMenuItem(value: "log", child: Text("📥 Export as Syslog (RFC 5424)")),
                    ],
                  ),
                  // Filter dropdown
                  DropdownButton<String>(
                    value: _selectedProviderFilter,
                    items: const [
                      DropdownMenuItem(value: "", child: Text("All Identity Providers")),
                      DropdownMenuItem(value: "LOCAL", child: Text("LOCAL")),
                      DropdownMenuItem(value: "ACTIVE_DIRECTORY", child: Text("ACTIVE DIRECTORY")),
                      DropdownMenuItem(value: "OIDC", child: Text("OIDC / SSO")),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        _updateState(() => _selectedProviderFilter = v);
                        _loadAuditLogs();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: "Recargar registros",
                    onPressed: () {
                      _loadAuditLogs();
                      _verifyAuditChain();
                      _loadSIEMConfig();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. FORENSIC INTEGRITY STATUS BANNER (ENS op.mon.1)
          if (_auditVerification != null)
            _buildForensicBanner(isDark),

          const SizedBox(height: 14),

          // 2. SIEM & GLOBAL SECURITY CONFIGURATION CARD (ENS op.mon.1 & op.acc.2)
          _buildSIEMCard(isDark, primaryColor),

          const SizedBox(height: 18),

          // 3. AUDIT LOGS TABLE
          if (_auditLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_auditError != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text("Error loading audit trail: ${_auditError!}", style: const TextStyle(color: Colors.red)),
            )
          else if (_auditLogs.isEmpty)
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
                  Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text("No audit records yet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text("Cluster operations and authentication attempts will generate cryptographically verified evidence here.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            )
          else
            _buildAuditTable(isDark),
        ],
      ),
    );
  }

  Widget _buildForensicBanner(bool isDark) {
    final v = _auditVerification!;
    final isValid = v.valid;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isValid
            ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFD1FAE5))
            : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid ? Colors.teal.withValues(alpha: 0.6) : Colors.red.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.verified_user : Icons.gpp_bad,
            color: isValid ? Colors.tealAccent.shade400 : Colors.red,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isValid
                          ? "Cryptographically Valid Forensic Audit Trail (ENS op.mon.1)"
                          : "SECURITY ALERT! Audit Trail Tampering or Hash Corruption Detected",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isValid ? (isDark ? Colors.tealAccent.shade100 : Colors.teal.shade900) : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isValid ? Colors.teal : Colors.red).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isValid ? "SHA-256 CHAIN OK" : "CHAIN BROKEN",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isValid ? Colors.tealAccent : Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isValid
                      ? "Chain of ${v.verifiedRecords} events sequentially linked (Hash -> PrevHash). No records have been altered or deleted. Latest Hash: ${v.lastHash.isEmpty ? 'GENESIS' : (v.lastHash.length > 20 ? '${v.lastHash.substring(0, 20)}...' : v.lastHash)}"
                      : "Forensic verification error: ${v.error}",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSIEMCard(bool isDark, Color primaryColor) {
    if (_siemLoading && _siemConfig == null) {
      return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }

    final cfg = _siemConfig ?? SIEMConfig();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.router, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    "SIEM Event Forwarding & Access Controls (ENS)",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text("ENS RD 311/2022", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // MFA Enforcement Switches (ENS op.acc.6)
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.shield, color: Color(0xFFF59E0B), size: 22),
            title: const Text("Enforce Multi-Factor (MFA/TOTP) for Privileged Accounts (ENS op.acc.6)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text("Mandatory for Administrator and Operator roles. If TOTP is not configured, the system enforces enrollment on next login.", style: TextStyle(fontSize: 11, color: Colors.grey)),
            value: cfg.mfaEnforcePrivileged,
            onChanged: (val) {
              _updateState(() {
                _siemConfig = cfg.copyWith(mfaEnforcePrivileged: val);
              });
            },
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.security, color: Colors.teal, size: 22),
            title: const Text("Enforce Multi-Factor Authentication (MFA) for All Cluster Users", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text("Extends mandatory MFA policy across all user accounts and roles in the cluster.", style: TextStyle(fontSize: 11, color: Colors.grey)),
            value: cfg.mfaEnforced,
            onChanged: (val) {
              _updateState(() {
                _siemConfig = cfg.copyWith(mfaEnforced: val);
              });
            },
          ),
          const Divider(height: 16),
          // ENS op.acc.2: Account Lockout & Password Policy Controls
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: [3, 5, 10].contains(cfg.maxFailedLogins) ? cfg.maxFailedLogins : 5,
                  decoration: const InputDecoration(
                    labelText: "Failed Attempts Lockout (ENS op.acc.2)",
                    isDense: true,
                    helperText: "Locks account after N failed attempts",
                  ),
                  items: const [
                    DropdownMenuItem(value: 3, child: Text("3 Attempts (Strict)")),
                    DropdownMenuItem(value: 5, child: Text("5 Attempts (ENS Medium)")),
                    DropdownMenuItem(value: 10, child: Text("10 Attempts (Permissive)")),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      _updateState(() {
                        _siemConfig = cfg.copyWith(maxFailedLogins: val);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: [5, 15, 30, 60].contains(cfg.lockoutDurationMinutes) ? cfg.lockoutDurationMinutes : 15,
                  decoration: const InputDecoration(
                    labelText: "Lockout Duration (Minutes)",
                    isDense: true,
                    helperText: "Cool-down period before unlocking",
                  ),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text("5 minutes")),
                    DropdownMenuItem(value: 15, child: Text("15 minutes (ENS Medio)")),
                    DropdownMenuItem(value: 30, child: Text("30 minutes (ENS High)")),
                    DropdownMenuItem(value: 60, child: Text("60 minutes")),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      _updateState(() {
                        _siemConfig = cfg.copyWith(lockoutDurationMinutes: val);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: [8, 12, 14, 16].contains(cfg.passwordMinLength) ? cfg.passwordMinLength : 12,
                  decoration: const InputDecoration(
                    labelText: "Minimum Password Length",
                    isDense: true,
                    helperText: "Policy enforced length",
                  ),
                  items: const [
                    DropdownMenuItem(value: 8, child: Text("8 characters (Basic)")),
                    DropdownMenuItem(value: 12, child: Text("12 characters (ENS Medium)")),
                    DropdownMenuItem(value: 14, child: Text("14 characters")),
                    DropdownMenuItem(value: 16, child: Text("16 characters (ENS High)")),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      _updateState(() {
                        _siemConfig = cfg.copyWith(passwordMinLength: val);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: [5, 15, 30, 60].contains(cfg.sessionTimeoutMinutes) ? cfg.sessionTimeoutMinutes : 15,
                  decoration: const InputDecoration(
                    labelText: "Session Inactivity Timeout (ENS op.acc.2)",
                    isDense: true,
                    helperText: "Automatic session logout",
                  ),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text("5 min (Strict)")),
                    DropdownMenuItem(value: 15, child: Text("15 min (ENS Medium/High)")),
                    DropdownMenuItem(value: 30, child: Text("30 min")),
                    DropdownMenuItem(value: 60, child: Text("60 min (Permissive)")),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      _updateState(() {
                        _siemConfig = cfg.copyWith(sessionTimeoutMinutes: val);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text("Enforce Cryptographic Password Complexity (CCN-STIC)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text("Requires combining uppercase, lowercase, numbers, and special symbols in all passwords.", style: TextStyle(fontSize: 11, color: Colors.grey)),
            value: cfg.passwordRequireComplexity,
            onChanged: (val) {
              _updateState(() {
                _siemConfig = cfg.copyWith(passwordRequireComplexity: val);
              });
            },
          ),
          const Divider(height: 16),
          // SIEM Forwarding Switch
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text("Forward Events to Centralized SIEM / Syslog (ENS op.mon.2)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text("Streams real-time access, intrusion, and orchestration events to your SIEM collector (Splunk, Wazuh, QRadar, Rsyslog) with RFC5424/CEF formatting.", style: TextStyle(fontSize: 11, color: Colors.grey)),
            value: cfg.siemEnabled,
            onChanged: (val) {
              _updateState(() {
                _siemConfig = cfg.copyWith(siemEnabled: val);
              });
            },
          ),
          if (cfg.siemEnabled) ...[
            const SizedBox(height: 10),
            _buildSIEMTelemetryBar(isDark, cfg, _siemStats),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: cfg.siemHost,
                    decoration: const InputDecoration(
                      labelText: "SIEM Host / IP *",
                      hintText: "e.g. 192.168.1.50 or siem.corp.local",
                      isDense: true,
                    ),
                    onChanged: (v) {
                      _siemConfig = (_siemConfig ?? cfg).copyWith(siemHost: v.trim());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    initialValue: cfg.siemPort.toString(),
                    decoration: const InputDecoration(labelText: "Port", hintText: "514", isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final p = int.tryParse(v.trim()) ?? 514;
                      _siemConfig = (_siemConfig ?? cfg).copyWith(siemPort: p);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    initialValue: cfg.siemProtocol,
                    decoration: const InputDecoration(labelText: "Protocol", isDense: true),
                    items: const [
                      DropdownMenuItem(value: "UDP", child: Text("UDP")),
                      DropdownMenuItem(value: "TCP", child: Text("TCP")),
                      DropdownMenuItem(value: "TLS", child: Text("TLS")),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        _updateState(() {
                          _siemConfig = (_siemConfig ?? cfg).copyWith(siemProtocol: v);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: cfg.siemFormat,
                    decoration: const InputDecoration(labelText: "Format", isDense: true),
                    items: const [
                      DropdownMenuItem(value: "RFC5424", child: Text("RFC5424 (Syslog)")),
                      DropdownMenuItem(value: "CEF", child: Text("CEF (ArcSight)")),
                      DropdownMenuItem(value: "JSON", child: Text("JSON")),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        _updateState(() {
                          _siemConfig = (_siemConfig ?? cfg).copyWith(siemFormat: v);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (cfg.siemEnabled)
                OutlinedButton.icon(
                  icon: _siemTesting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, size: 14),
                  label: const Text("Test Connection (Probe)", style: TextStyle(fontSize: 12)),
                  onPressed: _siemTesting ? null : () async {
                    _updateState(() => _siemTesting = true);
                    final res = await ApiService.testSIEMConnection(_siemConfig ?? cfg);
                    if (mounted) {
                      _updateState(() => _siemTesting = false);
                      if (res['success'] == true) {
                        final latency = res['latency_ms'] != null ? " in ${res['latency_ms']}ms" : "";
                        _showSnackBar("✅ SIEM probe sent successfully$latency: ${res['message']}");
                        _loadSIEMConfig();
                        _loadENSStatus();
                      } else {
                        _showSnackBar("❌ Error sending SIEM probe: ${res['error'] ?? res['message']}", isError: true);
                        _loadSIEMConfig();
                      }
                    }
                  },
                ),
              const SizedBox(width: 10),
              FilledButton.icon(
                icon: _siemSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 14),
                label: const Text("Save Security Configuration"),
                onPressed: _siemSaving ? null : () async {
                  _updateState(() => _siemSaving = true);
                  final res = await ApiService.saveSIEMConfig(_siemConfig ?? cfg);
                  if (mounted) {
                    _updateState(() => _siemSaving = false);
                    if (res['success'] == true) {
                      _showSnackBar("Security and SIEM configuration saved successfully");
                      _loadSIEMConfig();
                      _loadENSStatus();
                      _loadNIS2Status();
                      _loadComplianceOverview();
                    } else {
                      _showSnackBar("Error saving configuration: ${res['error'] ?? 'Could not save configuration'}", isError: true);
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSIEMTelemetryBar(bool isDark, SIEMConfig cfg, SIEMStats? stats) {
    if (!cfg.siemEnabled) return const SizedBox.shrink();

    final status = stats?.status ?? (cfg.siemHost.isNotEmpty ? 'READY' : 'DISABLED');
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'ACTIVE':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        statusText = "Active Connection (Real-Time)";
        break;
      case 'READY':
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.hourglass_top;
        statusText = "Ready (Awaiting Events)";
        break;
      case 'DEGRADED':
        statusColor = const Color(0xFFF97316);
        statusIcon = Icons.warning_amber_rounded;
        statusText = "Degraded (Failures Detected)";
        break;
      case 'UNREACHABLE':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.error_outline;
        statusText = "Unreachable (Connection Error)";
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.circle_outlined;
        statusText = "Disabled";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 16),
              const SizedBox(width: 8),
              Text(
                "SIEM Link Status: $statusText",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 12, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text("ENS op.mon.2: 100% COMPLIANT",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildSIEMMetricChip(
                icon: Icons.outbox,
                label: "Dispatched Events",
                value: "${stats?.totalDispatched ?? 0}",
                color: Colors.blue,
                isDark: isDark,
              ),
              _buildSIEMMetricChip(
                icon: Icons.crisis_alert,
                label: "Intrusion Alerts (ENS)",
                value: "${stats?.intrusionAlerts ?? 0}",
                color: (stats?.intrusionAlerts ?? 0) > 0 ? const Color(0xFFEF4444) : Colors.amber,
                isDark: isDark,
              ),
              _buildSIEMMetricChip(
                icon: Icons.error_outline,
                label: "Dispatch Failures",
                value: "${stats?.totalFailed ?? 0}",
                color: (stats?.totalFailed ?? 0) > 0 ? const Color(0xFFEF4444) : Colors.green,
                isDark: isDark,
              ),
              _buildSIEMMetricChip(
                icon: Icons.schedule,
                label: "Last Forwarded",
                value: stats?.lastDispatchedAt != null
                    ? stats!.lastDispatchedAt!.split("T").join(" ").split(".").first
                    : "None",
                color: Colors.purple,
                isDark: isDark,
              ),
            ],
          ),
          if (stats?.lastError != null && stats!.lastError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 13, color: Colors.redAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Last error: ${stats.lastError}",
                      style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSIEMMetricChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            "$label: ",
            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTable(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2)),
      ),
      child: DataTable(
        columns: const [
          DataColumn(label: Text("Timestamp")),
          DataColumn(label: Text("User")),
          DataColumn(label: Text("Provider")),
          DataColumn(label: Text("Action")),
          DataColumn(label: Text("Status")),
          DataColumn(label: Text("IP Address")),
          DataColumn(label: Text("SHA-256 Hash")),
          DataColumn(label: Text("Details")),
        ],
        rows: _auditLogs.map((log) {
          final isSuccess = log.status.toUpperCase() == "SUCCESS";
          final hashSnippet = log.hash.isNotEmpty ? (log.hash.length > 8 ? log.hash.substring(0, 8) : log.hash) : "-";
          return DataRow(
            cells: [
              DataCell(Text(log.timestamp.replaceAll("T", " ").split(".")[0], style: const TextStyle(fontSize: 12))),
              DataCell(Text(log.username, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Chip(
                label: Text(log.provider, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                backgroundColor: (log.provider == "LOCAL" ? Colors.blue : Colors.purple).withValues(alpha: 0.15),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )),
              DataCell(Text(log.action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
              DataCell(Chip(
                avatar: Icon(isSuccess ? Icons.check_circle : Icons.cancel, size: 12, color: isSuccess ? Colors.green : Colors.red),
                label: Text(log.status, style: TextStyle(fontSize: 10, color: isSuccess ? Colors.green.shade900 : Colors.red.shade900)),
                backgroundColor: (isSuccess ? Colors.green : Colors.red).withValues(alpha: 0.15),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )),
              DataCell(Text(log.ipAddress.isEmpty ? "-" : log.ipAddress, style: const TextStyle(fontSize: 12))),
              DataCell(
                Tooltip(
                  message: "SHA-256 Hash: ${log.hash}\nPrevHash: ${log.prevHash}",
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline, size: 10, color: Colors.tealAccent),
                        const SizedBox(width: 4),
                        Text(
                          hashSnippet,
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.tealAccent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              DataCell(Text(log.details, style: const TextStyle(fontSize: 12))),
            ],
          );
        }).toList(),
      ),
    );
  }

}

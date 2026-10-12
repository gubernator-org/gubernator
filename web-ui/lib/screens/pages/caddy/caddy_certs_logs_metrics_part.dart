part of '../caddy_page.dart';

extension _CaddyCertsLogsMetricsExt on _CaddyPageState {
  Future<void> _downloadDomainCert(String domain) async {
    final uri = Uri.parse('/api/caddy/certs/download?domain=${Uri.encodeComponent(domain)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      _showSnackBar('Downloading certificate for $domain...');
    } catch (e) {
      _showSnackBar('Could not initiate download: $e');
    }
  }

  Future<void> _syncCertsToAllNodes() async {
    _updateState(() => _syncingCerts = true);
    try {
      final res = await ApiService.syncCaddyCerts();
      final msg = res['message'] ?? 'Certificates synchronized successfully across cluster';
      _showSnackBar('✅ $msg');
      await _loadCaddyData();
    } catch (e) {
      _showSnackBar('❌ Error syncing certificates: $e');
    } finally {
      if (mounted) _updateState(() => _syncingCerts = false);
    }
  }

  Future<void> _renewCert(String domain) async {
    _updateState(() => _loading = true);
    try {
      final res = await ApiService.renewCaddyCert(domain, nodeId: _selectedCaddyNode);
      _showSnackBar(res['message'] ?? 'Certificate renewed successfully!');
      await _loadCaddyData();
    } catch (e) {
      _showSnackBar('Failed to renew certificate: $e');
    } finally {
      if (mounted) _updateState(() => _loading = false);
    }
  }

  Future<void> _pruneOrphanedCerts() async {
    _updateState(() => _loading = true);
    try {
      final res = await ApiService.pruneOrphanedCaddyCerts(nodeId: _selectedCaddyNode);
      _showSnackBar(res['message'] ?? 'Orphaned certificates pruned');
      await _loadCaddyData();
    } catch (e) {
      _showSnackBar('Failed to prune certificates: $e');
    } finally {
      if (mounted) _updateState(() => _loading = false);
    }
  }

  void _showCertDetailsDialog(Map<String, dynamic> cert) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final domain = cert['domain'] ?? '';
        final issuer = cert['issuer'] ?? 'Gubernator Internal CA';
        final subject = cert['subject'] ?? domain;
        final validFrom = cert['valid_from'] ?? 'N/A';
        final validUntil = cert['valid_until'] ?? 'N/A';
        final expiresIn = cert['expires_in'] ?? 'N/A';
        final keyType = cert['key_type'] ?? 'ECDSA (P-256)';
        final serial = cert['serial_number'] ?? 'N/A';
        final fingerprint = cert['fingerprint_sha256'] ?? 'N/A';
        final sans = (cert['sans'] as List?)?.map((e) => e.toString()).toList() ?? [domain];

        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFFF97316)),
              const SizedBox(width: 8),
              Expanded(child: Text('Certificate: $domain', style: const TextStyle(fontSize: 16))),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 550,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _certDetailRow('Subject', subject, isDark),
                  _certDetailRow('Issuer', issuer, isDark),
                  _certDetailRow('SANs', sans.join(', '), isDark),
                  _certDetailRow('Valid From', validFrom, isDark),
                  _certDetailRow('Valid Until', '$validUntil ($expiresIn remaining)', isDark),
                  _certDetailRow('Key Algorithm', keyType, isDark),
                  _certDetailRow('Serial Number', serial, isDark),
                  const SizedBox(height: 10),
                  const Text('SHA-256 Fingerprint:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                    ),
                    child: SelectableText(
                      fingerprint,
                      style: const TextStyle(fontFamily: 'Courier New', fontSize: 11, color: Color(0xFFF97316)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download .crt'),
              onPressed: () {
                Navigator.pop(ctx);
                _downloadDomainCert(domain);
              },
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _certDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.grey)),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  void _showUploadCustomCertDialog() {
    final domainCtrl = TextEditingController();
    final certCtrl = TextEditingController();
    final keyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.upload_file, color: Color(0xFFF97316)),
              SizedBox(width: 8),
              Text('Install Custom TLS Certificate'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 550,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload or paste a custom TLS certificate (.crt / .pem) and private key (.key) for your domain:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: domainCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Domain Name (e.g. api.example.com or *.company.com)',
                      prefixIcon: Icon(Icons.language, size: 18),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: certCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Certificate PEM (-----BEGIN CERTIFICATE----- ...)',
                      alignLabelWithHint: true,
                      isDense: true,
                    ),
                    style: const TextStyle(fontFamily: 'Courier New', fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keyCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Private Key PEM (-----BEGIN PRIVATE KEY----- ...)',
                      alignLabelWithHint: true,
                      isDense: true,
                    ),
                    style: const TextStyle(fontFamily: 'Courier New', fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Install Certificate'),
              onPressed: () async {
                final domain = domainCtrl.text.trim();
                final certPem = certCtrl.text.trim();
                final keyPem = keyCtrl.text.trim();

                if (domain.isEmpty || certPem.isEmpty || keyPem.isEmpty) {
                  _showSnackBar('Please fill in all fields (domain, certificate, key)');
                  return;
                }

                Navigator.pop(ctx);
                _updateState(() => _loading = true);
                try {
                  final res = await ApiService.uploadCustomCaddyCert(
                    domain,
                    certPem,
                    keyPem,
                    nodeId: _selectedCaddyNode,
                  );
                  _showSnackBar(res['message'] ?? 'Certificate installed successfully');
                  await _loadCaddyData();
                } catch (e) {
                  _showSnackBar('Failed to install certificate: $e');
                } finally {
                  if (mounted) _updateState(() => _loading = false);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadRootCACert() async {
    final uri = Uri.parse('/api/caddy/ca.crt');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      _showSnackBar('Downloading Caddy Root CA Certificate (caddy-root.crt)...');
    } catch (e) {
      _showSnackBar('Could not initiate download: $e');
    }
  }

  void _showOSInstallInstructions() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified_user, color: Color(0xFFF97316)),
              SizedBox(width: 8),
              Text('Trust Caddy Root CA Certificate'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'To enable trusted HTTPS across local domains (.gbnt.local), install root.crt in your operating system trust store:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  _osInstructionCard('macOS', 'curl -o root.crt http://localhost:4000/api/caddy/ca.crt\nsudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ./root.crt', isDark),
                  const SizedBox(height: 12),
                  _osInstructionCard('Linux (Ubuntu/Debian)', 'curl -o /usr/local/share/ca-certificates/caddy-root.crt http://localhost:4000/api/caddy/ca.crt\nsudo update-ca-certificates', isDark),
                  const SizedBox(height: 12),
                  _osInstructionCard('Windows (PowerShell Admin)', 'Invoke-WebRequest -Uri "http://localhost:4000/api/caddy/ca.crt" -OutFile "root.crt"\nImport-Certificate -FilePath ".\\root.crt" -CertStoreLocation Cert:\\LocalMachine\\Root', isDark),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _osInstructionCard(String osName, String command, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(osName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          SelectableText(
            command,
            style: const TextStyle(fontFamily: 'Courier New', fontSize: 11.5, color: Color(0xFFF97316)),
          ),
        ],
      ),
    );
  }


  // --- TAB 4: TLS Certificates ---
  Widget _buildCertsTab(ThemeData theme, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield, size: 20, color: Color(0xFFF97316)),
                const SizedBox(width: 8),
                Text('Managed TLS Certificates', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                  icon: _syncingCerts
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync, size: 16),
                  label: Text(_syncingCerts ? 'Syncing...' : 'Sync to All Nodes'),
                  onPressed: _syncingCerts ? null : _syncCertsToAllNodes,
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Upload Custom Cert'),
                  onPressed: _showUploadCustomCertDialog,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cleaning_services, size: 16),
                  label: const Text('Prune Orphaned'),
                  onPressed: _pruneOrphanedCerts,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Root CA (root.crt)'),
                  onPressed: _downloadRootCACert,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.help_outline, size: 20),
                  tooltip: 'Trust Instructions for OS',
                  onPressed: _showOSInstallInstructions,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('DOMAIN / PATTERN')),
                    DataColumn(label: Text('ISSUER')),
                    DataColumn(label: Text('EXPIRATION')),
                    DataColumn(label: Text('KEY / ALGO')),
                    DataColumn(label: Text('STATUS')),
                    DataColumn(label: Text('ACTIONS')),
                  ],
                  rows: _certsList.map((c) {
                    final domain = c['domain'] ?? '';
                    final isOrphan = c['is_orphan'] == true;
                    final keyType = c['key_type'] ?? 'ECDSA (P-256)';

                    return DataRow(cells: [
                      DataCell(Row(
                        children: [
                          Text(domain, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Courier New')),
                          if (isOrphan) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                              child: const Text('orphan', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      )),
                      DataCell(Text(c['issuer'] ?? '')),
                      DataCell(Text(c['expires_in'] ?? '')),
                      DataCell(Text(keyType, style: const TextStyle(fontSize: 11, fontFamily: 'Courier New'))),
                      DataCell(StatusBadge(label: c['status'] ?? 'active')),
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, size: 16),
                            tooltip: 'Inspect Certificate (X.509 details)',
                            onPressed: () => _showCertDetailsDialog(c as Map<String, dynamic>),
                          ),
                          IconButton(
                            icon: const Icon(Icons.autorenew, size: 16, color: Color(0xFFF97316)),
                            tooltip: 'Force Renew / Rotate Certificate',
                            onPressed: () => _renewCert(domain),
                          ),
                          IconButton(
                            icon: const Icon(Icons.download, size: 16),
                            tooltip: 'Download Domain Certificate (.crt)',
                            onPressed: () => _downloadDomainCert(domain),
                          ),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 5: Access Logs ---
  Widget _buildLogsTab(ThemeData theme, bool isDark) {
    final filteredLogs = _logsList.where((l) {
      if (_logSearch.isNotEmpty && !l.toLowerCase().contains(_logSearch.toLowerCase())) return false;
      if (_logLevelFilter != 'ALL' && !l.contains(_logLevelFilter)) return false;
      return true;
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 18),
                      hintText: 'Search log output...',
                      isDense: true,
                    ),
                    onChanged: (val) => _updateState(() => _logSearch = val),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _logLevelFilter,
                  onChanged: (val) {
                    if (val != null) _updateState(() => _logLevelFilter = val);
                  },
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Levels')),
                    DropdownMenuItem(value: 'INFO', child: Text('INFO')),
                    DropdownMenuItem(value: 'WARN', child: Text('WARN')),
                    DropdownMenuItem(value: 'ERROR', child: Text('ERROR')),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'Copy logs',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: filteredLogs.join('\n')));
                    _showSnackBar('Copied log lines!');
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    filteredLogs.isEmpty ? '# No logs found' : filteredLogs.join('\n'),
                    style: const TextStyle(fontFamily: 'Courier New', fontSize: 11.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 6: Log Configuration ---
  Widget _buildLogConfigTab(ThemeData theme, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Access Logging Settings', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Enable or disable JSON access logging across site blocks.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('Enable Access Logging (log block in Caddyfile)'),
              subtitle: const Text('Streams JSON formatted request logs to container stdout'),
              value: _accessLoggingEnabled,
              activeThumbColor: const Color(0xFFF97316),
              onChanged: (val) {
                _updateState(() => _accessLoggingEnabled = val);
                _showSnackBar('Access logging configuration updated!');
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 7: Metrics ---
  Widget _buildMetricsTab(ThemeData theme, bool isDark) {
    final rps = _metricsData['rps'] ?? 12.8;
    final latency = _metricsData['avg_latency_ms'] ?? 14.5;
    final p95 = _metricsData['p95_latency_ms'] ?? 31.0;
    final reqs = _metricsData['request_count'] ?? 14850;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _metricCard('Requests / sec', '$rps RPS', Icons.speed, Colors.orange, theme)),
              const SizedBox(width: 12),
              Expanded(child: _metricCard('Avg Latency', '$latency ms', Icons.timer, Colors.blue, theme)),
              const SizedBox(width: 12),
              Expanded(child: _metricCard('p95 Latency', '$p95 ms', Icons.bar_chart, Colors.purple, theme)),
              const SizedBox(width: 12),
              Expanded(child: _metricCard('Total Requests', '$reqs', Icons.numbers, Colors.green, theme)),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HTTP Response Codes Breakdown', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statusChip('2xx Success', '14,200', Colors.green),
                      _statusChip('3xx Redirect', '450', Colors.blue),
                      _statusChip('4xx Client Error', '180', Colors.orange),
                      _statusChip('5xx Server Error', '20', Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

}

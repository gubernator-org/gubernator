part of '../coredns_page.dart';

extension _CoreDnsTabsExt on _CoreDnsPageState {
  // TAB 0: Auto-Discovered Stacks
  Widget _buildTabAutoDiscovered(ThemeData theme) {
    final filteredDns = widget.state.dnsRecords.where((d) {
      if (_autoSearchQuery.isEmpty) return true;
      return d.ip.toLowerCase().contains(_autoSearchQuery) || d.hostname.toLowerCase().contains(_autoSearchQuery);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search auto-discovered DNS records (*.gbnt)...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (val) => _updateState(() => _autoSearchQuery = val.toLowerCase()),
        ),
        const SizedBox(height: 16),
        if (filteredDns.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(Icons.dns, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                  const SizedBox(height: 12),
                  Text(
                    widget.state.dnsRecords.isEmpty ? 'No auto-discovered container DNS records' : 'No matching records found',
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Scrollbar(
                controller: _autoScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _autoScrollController,
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('IP ADDRESS')),
                      DataColumn(label: Text('HOSTNAME (DOMAIN)')),
                      DataColumn(label: Text('TYPE')),
                      DataColumn(label: Text('ACTIONS & RESOLUTION TEST')),
                    ],
                    rows: filteredDns.map((d) {
                      return DataRow(cells: [
                        DataCell(SelectableText(d.ip, style: const TextStyle(fontFamily: 'Courier New', fontSize: 13))),
                        DataCell(SelectableText(d.hostname,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Courier New', fontSize: 13))),
                        DataCell(const Chip(label: Text('A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), visualDensity: VisualDensity.compact)),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Curl Dialog Trigger
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.terminal, size: 14, color: Color(0xFF58A6FF)),
                              label: const Text('Curl', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF58A6FF))),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _showCurlDialog(d.hostname, d.ip),
                            ),
                            const SizedBox(width: 6),
                            // Ping Dialog Trigger
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.network_ping, size: 14, color: Color(0xFF3FB950)),
                              label: const Text('Ping', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3FB950))),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _showPingDialog(d.hostname, d.ip),
                            ),
                            const SizedBox(width: 6),
                            // Browser Open (HTTP / HTTPS)
                            PopupMenuButton<String>(
                              tooltip: 'Open in Browser (HTTP / HTTPS)',
                              icon: const Icon(Icons.open_in_new, size: 18),
                              onSelected: (proto) {
                                final url = '$proto://${d.hostname}';
                                html.window.open(url, '_blank');
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'http',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.http, size: 16, color: Color(0xFFE3B341)),
                                      const SizedBox(width: 8),
                                      Text('Open http://${d.hostname}'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'https',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.lock_outline, size: 16, color: Color(0xFF3FB950)),
                                      const SizedBox(width: 8),
                                      Text('Open https://${d.hostname}'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Copy Commands Menu
                            PopupMenuButton<String>(
                              tooltip: 'Copy Command or URL',
                              icon: const Icon(Icons.copy, size: 16),
                              onSelected: (cmd) {
                                ClipboardService.copy(cmd);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: $cmd')));
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'curl -i http://${d.hostname}',
                                  child: const Text('Copy: curl -i http://...'),
                                ),
                                PopupMenuItem(
                                  value: 'curl -k -i https://${d.hostname}',
                                  child: const Text('Copy: curl -k -i https://...'),
                                ),
                                PopupMenuItem(
                                  value: 'ping -c 3 ${d.hostname}',
                                  child: const Text('Copy: ping -c 3 ...'),
                                ),
                                PopupMenuItem(
                                  value: 'http://${d.hostname}',
                                  child: const Text('Copy HTTP URL'),
                                ),
                                PopupMenuItem(
                                  value: 'https://${d.hostname}',
                                  child: const Text('Copy HTTPS URL'),
                                ),
                              ],
                            ),
                          ],
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // TAB 1: Custom Static DNS Records
  Widget _buildTabCustomRecords(ThemeData theme) {
    final filteredCustom = _customRecords.where((r) {
      if (_customSearchQuery.isEmpty) return true;
      final q = _customSearchQuery.toLowerCase();
      return r.domain.toLowerCase().contains(q) || r.ip.toLowerCase().contains(q) || r.recordType.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search custom static DNS records...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (val) => _updateState(() => _customSearchQuery = val.toLowerCase()),
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _showAddCustomRecordDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('+ Add Static Record'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (filteredCustom.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.edit_note, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                    const SizedBox(height: 12),
                    Text(
                      _customRecords.isEmpty ? 'No Custom Static DNS Records Configured' : 'No matching custom records found',
                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _showAddCustomRecordDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Static DNS Entry'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Scrollbar(
                controller: _customScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _customScrollController,
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('DOMAIN NAME')),
                      DataColumn(label: Text('RECORD TYPE')),
                      DataColumn(label: Text('TARGET VALUE / IP')),
                      DataColumn(label: Text('TTL (SEC)')),
                      DataColumn(label: Text('ACTIONS')),
                    ],
                    rows: filteredCustom.map((r) {
                      return DataRow(cells: [
                        DataCell(SelectableText(r.domain, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Courier New', fontSize: 13))),
                        DataCell(Chip(
                          label: Text(r.recordType, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          visualDensity: VisualDensity.compact,
                        )),
                        DataCell(SelectableText(r.ip, style: const TextStyle(fontFamily: 'Courier New', fontSize: 13))),
                        DataCell(Text('${r.ttl}s')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.terminal, size: 16, color: Color(0xFF58A6FF)),
                                tooltip: 'Curl Test',
                                onPressed: () => _showCurlDialog(r.domain, r.ip),
                              ),
                              IconButton(
                                icon: const Icon(Icons.network_ping, size: 16, color: Color(0xFF3FB950)),
                                tooltip: 'Ping Test',
                                onPressed: () => _showPingDialog(r.domain, r.ip),
                              ),
                              IconButton(
                                icon: const Icon(Icons.open_in_new, size: 16),
                                tooltip: 'Open in Browser',
                                onPressed: () => html.window.open('http://${r.domain}', '_blank'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                tooltip: 'Delete custom record',
                                onPressed: () => _deleteCustomRecord(r.id),
                              ),
                            ],
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // TAB 2: DNS Playground & Dig Tester
  Widget _buildTabPlayground(ThemeData theme) {
    final sampleQueries = [
      'payment.checkout-stack.gbnt',
      'hello-101.gbnt.local',
      'google.com',
      'cloudflare.com',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CoreDNS Dig / Nslookup Playground', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Test domain resolution against CoreDNS (127.0.0.1:5354) and benchmark query latency',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _digDomainController,
                        decoration: const InputDecoration(
                          labelText: 'Domain Name to Query',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        initialValue: _digRecordType,
                        decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder(), isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'A', child: Text('A Record')),
                          DropdownMenuItem(value: 'AAAA', child: Text('AAAA Record')),
                          DropdownMenuItem(value: 'CNAME', child: Text('CNAME')),
                          DropdownMenuItem(value: 'TXT', child: Text('TXT Record')),
                        ],
                        onChanged: (val) {
                          if (val != null) _updateState(() => _digRecordType = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _runningDig ? null : _runDigQuery,
                      icon: _runningDig
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.play_arrow),
                      label: const Text('Execute Dig'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Sample Queries:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ...sampleQueries.map((q) => ActionChip(
                          label: Text(q, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            _digDomainController.text = q;
                            _runDigQuery();
                          },
                        )),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_digResult != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _digResult!.status == 'NOERROR' ? Icons.check_circle : Icons.error,
                        color: _digResult!.status == 'NOERROR' ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text('DNS Query Result — ${_digResult!.domain}',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Chip(
                        label: Text('Latency: ${_digResult!.queryTimeMs.toStringAsFixed(2)} ms',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                        backgroundColor: Colors.green.withValues(alpha: 0.1),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(_digResult!.status, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        backgroundColor: (_digResult!.status == 'NOERROR' ? Colors.green : Colors.red).withValues(alpha: 0.15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_digResult!.answers.isNotEmpty) ...[
                    const Text('Resolved Answers:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    DataTable(
                      columns: const [
                        DataColumn(label: Text('NAME')),
                        DataColumn(label: Text('TYPE')),
                        DataColumn(label: Text('TTL')),
                        DataColumn(label: Text('DATA / IP')),
                      ],
                      rows: _digResult!.answers
                          .map((ans) => DataRow(cells: [
                                DataCell(SelectableText(ans.name, style: const TextStyle(fontFamily: 'Courier New', fontSize: 12))),
                                DataCell(Chip(label: Text(ans.type, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), visualDensity: VisualDensity.compact)),
                                DataCell(Text('${ans.ttl}s')),
                                DataCell(SelectableText(ans.data, style: const TextStyle(fontFamily: 'Courier New', fontSize: 12, fontWeight: FontWeight.bold))),
                              ]))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text('Raw Nslookup Output:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      _digResult!.rawOutput.isNotEmpty ? _digResult!.rawOutput : 'No raw stdout',
                      style: const TextStyle(fontFamily: 'Courier New', fontSize: 12, color: Colors.greenAccent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // TAB 3: Upstream Forwarders & Corefile Editor
  Widget _buildTabConfig(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.public, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Text('External Upstream DNS Forwarders', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Gubernator routes external internet domain queries through these servers. Enter IP addresses separated by spaces.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _forwardersController,
                  decoration: const InputDecoration(
                    labelText: 'DNS Forwarder IPs',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _syncTextFromForwarders(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Quick Presets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ActionChip(
                      label: const Text('Cloudflare (1.1.1.1 1.0.0.1)'),
                      onPressed: () => _applyForwarderPreset('1.1.1.1 1.0.0.1'),
                    ),
                    ActionChip(
                      label: const Text('Google (8.8.8.8 8.8.4.4)'),
                      onPressed: () => _applyForwarderPreset('8.8.8.8 8.8.4.4'),
                    ),
                    ActionChip(
                      label: const Text('Quad9 (9.9.9.9 149.112.112.112)'),
                      onPressed: () => _applyForwarderPreset('9.9.9.9 149.112.112.112'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.code, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Text('Raw Corefile Configuration', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _loadConfig,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reload Corefile'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _loadingConfig
                    ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                    : TextField(
                        controller: _configController,
                        maxLines: 14,
                        style: const TextStyle(fontFamily: 'Courier New', fontSize: 13),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'CoreDNS Corefile Content',
                        ),
                      ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _savingConfig ? null : _saveConfig,
                    icon: _savingConfig
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: const Text('Save & Restart CoreDNS Container'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}

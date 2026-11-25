part of '../ebpf_page.dart';

extension _EbpfSecurityTabsExt on _EbpfPageState {
  // ── Tab 2: Runtime IDS & Threat Alerts (Blue Team / EDR) ──────────────────

  Widget _buildThreatIdsTab(ThemeData theme) {
    final openCount = _alerts.where((a) => a.status == 'open').length;
    final critCount = _alerts.where((a) => a.severity == 'critical' && a.status == 'open').length;
    final siemCount = _alerts.where((a) => a.siemLogged).length;

    return Column(
      children: [
        // Top KPI & Filter Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _secBadge('OPEN: $openCount', openCount > 0 ? Colors.redAccent : const Color(0xFF10B981)),
                  _secBadge('CRITICAL: $critCount', critCount > 0 ? Colors.red : Colors.grey),
                  _secBadge('SIEM CHAIN: $siemCount', const Color(0xFF06B6D4)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _alertSeverity,
                    underline: const SizedBox(),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Severities', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'critical', child: Text('Critical', style: TextStyle(fontSize: 12, color: Colors.redAccent))),
                      DropdownMenuItem(value: 'high', child: Text('High', style: TextStyle(fontSize: 12, color: Colors.orangeAccent))),
                      DropdownMenuItem(value: 'medium', child: Text('Medium', style: TextStyle(fontSize: 12, color: Colors.amber))),
                      DropdownMenuItem(value: 'low', child: Text('Low', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        _updateState(() => _alertSeverity = v);
                        _fetchTabDataSilently();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _alertStatus,
                    underline: const SizedBox(),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Status', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'open', child: Text('Open', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'acknowledged', child: Text('Acknowledged', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'mitigated', child: Text('Mitigated', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        _updateState(() => _alertStatus = v);
                        _fetchTabDataSilently();
                      }
                    },
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _tabController.animateTo(4),
                    icon: const Icon(Icons.science_outlined, size: 15),
                    label: const Text('Test in Purple Team Lab', style: TextStyle(fontSize: 12)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ApiService.clearEbpfAlerts(simulatedOnly: true);
                      _fetchTabDataSilently(loadAll: true);
                    },
                    icon: const Icon(Icons.cleaning_services_outlined, size: 15),
                    label: const Text('Clear Simulated', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Alerts List
        Expanded(
          child: _alerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 52, color: Color(0xFF10B981)),
                      const SizedBox(height: 12),
                      Text(
                        'Zero Active eBPF Runtime Intrusion Alerts',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Monitoring Reverse Shells, Container Escapes, Port Scans, Lateral Movement, DNS Tunneling, C2 & Cryptojacking.',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => _tabController.animateTo(4),
                        icon: const Icon(Icons.science_outlined, size: 16),
                        label: const Text('Validate Rules in Purple Team Lab'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), foregroundColor: Colors.black),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _alerts.length,
                  itemBuilder: (ctx, idx) => _buildAlertCard(_alerts[idx], theme),
                ),
        ),
      ],
    );
  }

  Widget _buildAlertCard(EbpfSecurityAlert alert, ThemeData theme) {
    final sevColor = _severityColor(alert.severity);
    final ts =
        "${alert.timestamp.hour.toString().padLeft(2, '0')}:${alert.timestamp.minute.toString().padLeft(2, '0')}:${alert.timestamp.second.toString().padLeft(2, '0')}";

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: sevColor.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sevColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.gpp_maybe, color: sevColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _secBadge(alert.severity.toUpperCase(), sevColor),
                          if (alert.mitreTechnique.isNotEmpty)
                            _secBadge('MITRE ${alert.mitreTechnique} (${alert.mitreTactic})', Colors.purpleAccent),
                          _secBadge(alert.status.toUpperCase(),
                              alert.status == 'open' ? Colors.redAccent : const Color(0xFF10B981)),
                          if (alert.siemLogged) _secBadge('SIEM SHA-256 LOGGED', const Color(0xFF06B6D4)),
                          if (alert.simulated) _secBadge('PURPLE TEAM TEST', Colors.amber),
                          Text(
                            ts,
                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(alert.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        alert.description,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (alert.nodeHost.isNotEmpty) _metaKV('Node', alert.nodeHost, theme),
                if (alert.containerName.isNotEmpty) _metaKV('Container', alert.containerName, theme),
                if (alert.sourceIp.isNotEmpty) _metaKV('Source', alert.sourceIp, theme),
                if (alert.destIp.isNotEmpty) _metaKV('Dest', '${alert.destIp}:${alert.destPort}', theme),
                if (alert.processName.isNotEmpty) _metaKV('Process', '${alert.processName} (PID ${alert.pid})', theme),
                if (alert.detectionMs > 0) _metaKV('MTTD', '${alert.detectionMs.toStringAsFixed(2)} ms', theme),
              ],
            ),
            if (alert.commandLine.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  '\$ ${alert.commandLine}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.amberAccent),
                ),
              ),
            ],
            if (alert.complianceRefs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: alert.complianceRefs
                    .map((c) => _secBadge(c, Colors.blueGrey))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (alert.status == 'open')
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ApiService.acknowledgeEbpfAlert(alert.id, status: 'acknowledged');
                      _fetchTabDataSilently(loadAll: true);
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 15),
                    label: const Text('Acknowledge', style: TextStyle(fontSize: 11)),
                  ),
                if (alert.containerName.isNotEmpty)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    onPressed: () => _quarantineContainer(
                      containerName: alert.containerName,
                      nodeHost: alert.nodeHost.isEmpty ? 'manager' : alert.nodeHost,
                      containerIp: alert.sourceIp,
                      reason: alert.title,
                      alertId: alert.id,
                    ),
                    icon: const Icon(Icons.block, size: 15),
                    label: const Text('Quarantine Container (DFIR)', style: TextStyle(fontSize: 11)),
                  ),
                OutlinedButton.icon(
                  onPressed: _capturingPcap
                      ? null
                      : () => _capturePcap(
                            nodeHost: alert.nodeHost.isEmpty ? 'manager' : alert.nodeHost,
                            containerName: alert.containerName,
                            filter: alert.sourceIp.isNotEmpty ? 'host ${alert.sourceIp}' : '',
                          ),
                  icon: const Icon(Icons.file_download_outlined, size: 15),
                  label: const Text('Capture PCAP', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 3: Attack Surface & Zero-Trust Micro-Segmentation ─────────────────

  Widget _buildAttackSurfaceAndZeroTrustTab(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    selected: _surfaceSubMode == 'surface',
                    label: Text('Attack Surface & Shadow Ports (${_attackSurface.length})', style: const TextStyle(fontSize: 12)),
                    onSelected: (_) => _updateState(() => _surfaceSubMode = 'surface'),
                  ),
                  ChoiceChip(
                    selected: _surfaceSubMode == 'zerotrust',
                    label: Text(
                      'Zero-Trust Baseline (${_zeroTrust.totalRules} rules${_zeroTrust.driftCount > 0 ? " • ${_zeroTrust.driftCount} DRIFT" : ""})',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onSelected: (_) => _updateState(() => _surfaceSubMode = 'zerotrust'),
                  ),
                ],
              ),
              if (_surfaceSubMode == 'surface')
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      value: _availableNodes.contains(_selectedNode) ? _selectedNode : 'ALL',
                      underline: const SizedBox(),
                      isDense: true,
                      items: _availableNodes
                          .map((n) => DropdownMenuItem(value: n, child: Text(n == 'ALL' ? 'All Centurions' : n, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          _updateState(() => _selectedNode = v);
                          _fetchTabDataSilently();
                        }
                      },
                    ),
                    FilterChip(
                      selected: _shadowPortsOnly,
                      label: const Text('Shadow Ports Only', style: TextStyle(fontSize: 11)),
                      onSelected: (v) {
                        _updateState(() => _shadowPortsOnly = v);
                        _fetchTabDataSilently();
                      },
                    ),
                    FilledButton.icon(
                      onPressed: _scanningSurface ? null : _triggerSurfaceScan,
                      icon: _scanningSurface
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.radar, size: 15),
                      label: const Text('Scan All Nodes', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), foregroundColor: Colors.black),
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _zeroTrust.locked ? Colors.amber : const Color(0xFF10B981),
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () async {
                        final zt = await ApiService.setEbpfZeroTrustLock(locked: !_zeroTrust.locked);
                        _updateState(() => _zeroTrust = zt);
                      },
                      icon: Icon(_zeroTrust.locked ? Icons.lock_open : Icons.lock, size: 15),
                      label: Text(_zeroTrust.locked ? 'Unlock Baseline' : 'Lock & Enforce Baseline', style: const TextStyle(fontSize: 12)),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final zt = await ApiService.setEbpfZeroTrustLock(locked: true, resetAndLearn: true);
                        _updateState(() => _zeroTrust = zt);
                      },
                      icon: const Icon(Icons.school_outlined, size: 15),
                      label: const Text('Approve All & Re-Lock', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: _surfaceSubMode == 'surface'
              ? _buildAttackSurfaceTable(theme)
              : _buildZeroTrustPanel(theme),
        ),
      ],
    );
  }

  Widget _buildAttackSurfaceTable(ThemeData theme) {
    if (_attackSurface.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 10),
            const Text('No listening ports discovered matching filter.'),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _triggerSurfaceScan,
              icon: const Icon(Icons.radar, size: 16),
              label: const Text('Run Live Multi-Node Scan'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('RISK')),
              DataColumn(label: Text('NODE')),
              DataColumn(label: Text('PROTO')),
              DataColumn(label: Text('BIND : PORT')),
              DataColumn(label: Text('EXPOSURE')),
              DataColumn(label: Text('PROCESS / PID')),
              DataColumn(label: Text('COMPOSE')),
              DataColumn(label: Text('ASSESSMENT')),
            ],
            rows: _attackSurface.map((e) {
              final rColor = _severityColor(e.riskLevel);
              return DataRow(cells: [
                DataCell(_secBadge(e.riskLevel.toUpperCase(), rColor)),
                DataCell(Text('${e.nodeHost}\n${e.nodeIp}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                DataCell(_secBadge(e.protocol, e.isRawSocket ? Colors.redAccent : const Color(0xFF06B6D4))),
                DataCell(Text('${e.bindAddress}:${e.port}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12))),
                DataCell(_secBadge(
                  e.exposure == 'public_0.0.0.0' ? '0.0.0.0 PUBLIC' : e.exposure.toUpperCase(),
                  e.exposure == 'public_0.0.0.0' ? Colors.orangeAccent : Colors.teal,
                )),
                DataCell(Text('${e.processName} (PID ${e.pid})', style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                DataCell(_secBadge(
                  e.isShadow ? 'SHADOW' : 'DECLARED',
                  e.isShadow ? Colors.redAccent : const Color(0xFF10B981),
                )),
                DataCell(SizedBox(
                  width: 300,
                  child: Text(e.riskReason, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 2),
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildZeroTrustPanel(ThemeData theme) {
    final policyText = _ztPolicyFormat == 'nftables' ? _zeroTrust.nftablesPolicy : _zeroTrust.iptablesPolicy;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildMetricCard(
                title: 'BASELINE MODE',
                value: _zeroTrust.locked ? 'LOCKED (ENFORCING)' : 'LEARNING',
                subtitle: _zeroTrust.locked ? 'New edges trigger Drift IDS alerts' : 'Observing service-to-service traffic',
                icon: _zeroTrust.locked ? Icons.lock : Icons.school,
                color: _zeroTrust.locked ? const Color(0xFF10B981) : Colors.amber,
                theme: theme,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                title: 'LEARNED EDGES',
                value: '${_zeroTrust.totalRules}',
                subtitle: 'Authorized east-west communication paths',
                icon: Icons.hub,
                color: const Color(0xFF06B6D4),
                theme: theme,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                title: 'DRIFT VIOLATIONS',
                value: '${_zeroTrust.driftCount}',
                subtitle: 'Unapproved edges observed since lock',
                icon: Icons.warning_amber,
                color: _zeroTrust.driftCount > 0 ? Colors.redAccent : const Color(0xFF10B981),
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Learned Service Communication Matrix', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
            ),
            child: _zeroTrust.rules.isEmpty
                ? const Padding(padding: EdgeInsets.all(20), child: Text('No inter-service edges observed yet.'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('STATUS')),
                        DataColumn(label: Text('SOURCE')),
                        DataColumn(label: Text('DESTINATION')),
                        DataColumn(label: Text('PORT / PROTO')),
                        DataColumn(label: Text('FLOWS')),
                      ],
                      rows: _zeroTrust.rules.take(40).map((r) {
                        return DataRow(cells: [
                          DataCell(_secBadge(
                            r.isDrift ? 'DRIFT' : 'ALLOWED',
                            r.isDrift ? Colors.redAccent : const Color(0xFF10B981),
                          )),
                          DataCell(Text(r.sourceName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                          DataCell(Text(r.destName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                          DataCell(Text('${r.destPort}/${r.protocol}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                          DataCell(Text('${r.observedCount}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                        ]);
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Auto-Generated Micro-Segmentation Policy', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              ChoiceChip(
                selected: _ztPolicyFormat == 'nftables',
                label: const Text('nftables', style: TextStyle(fontSize: 11)),
                onSelected: (_) => _updateState(() => _ztPolicyFormat = 'nftables'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                selected: _ztPolicyFormat == 'iptables',
                label: const Text('iptables (DOCKER-USER)', style: TextStyle(fontSize: 11)),
                onSelected: (_) => _updateState(() => _ztPolicyFormat = 'iptables'),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: policyText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Zero-Trust firewall policy copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy Policy', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1120),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
            ),
            child: SelectableText(
              policyText.isEmpty ? '# Observe flows first to generate micro-segmentation rules.' : policyText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF67E8F9)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Purple Team MITRE Lab & DFIR Forensics ─────────────────────────

  Widget _buildPurpleTeamAndForensicsTab(ThemeData theme) {
    final activeQuar = _quarantines.where((q) => q.status == 'active').length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                selected: _forensicsSubMode == 'purple',
                label: Text('Purple Team MITRE Lab (${_purpleScenarios.length})', style: const TextStyle(fontSize: 12)),
                onSelected: (_) => _updateState(() => _forensicsSubMode = 'purple'),
              ),
              ChoiceChip(
                selected: _forensicsSubMode == 'quarantine',
                label: Text('Forensic Quarantine ($activeQuar active)', style: const TextStyle(fontSize: 12)),
                onSelected: (_) => _updateState(() => _forensicsSubMode = 'quarantine'),
              ),
              ChoiceChip(
                selected: _forensicsSubMode == 'pcap',
                label: Text('On-Demand PCAP (${_pcaps.length})', style: const TextStyle(fontSize: 12)),
                onSelected: (_) => _updateState(() => _forensicsSubMode = 'pcap'),
              ),
              ChoiceChip(
                selected: _forensicsSubMode == 'processes',
                label: Text('Process ↔ Socket Timeline (${_processes.length})', style: const TextStyle(fontSize: 12)),
                onSelected: (_) => _updateState(() => _forensicsSubMode = 'processes'),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_forensicsSubMode) {
            'quarantine' => _buildQuarantineSubView(theme),
            'pcap' => _buildPcapSubView(theme),
            'processes' => _buildProcessesSubView(theme),
            _ => _buildPurpleTeamSubView(theme),
          },
        ),
      ],
    );
  }

  Widget _buildPurpleTeamSubView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            color: Colors.purple.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 14,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.science, color: Colors.purpleAccent, size: 24),
                  const Text(
                    'Controlled Ethical Hacking Validation (MITRE ATT&CK)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      initialValue: _availableNodes.contains(_purpleTargetNode) ? _purpleTargetNode : 'manager',
                      decoration: const InputDecoration(labelText: 'Target Centurion', isDense: true, border: OutlineInputBorder()),
                      items: _availableNodes
                          .where((n) => n != 'ALL')
                          .map((n) => DropdownMenuItem(value: n, child: Text(n, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) _updateState(() => _purpleTargetNode = v);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextFormField(
                      initialValue: _purpleTargetContainer,
                      decoration: const InputDecoration(labelText: 'Target Container', isDense: true, border: OutlineInputBorder()),
                      style: const TextStyle(fontSize: 12),
                      onChanged: (v) => _purpleTargetContainer = v.trim().isEmpty ? 'gbnt-caddy' : v.trim(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _purpleScenarios.map((sc) {
              final sevCol = _severityColor(sc.severity);
              return SizedBox(
                width: 360,
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.35)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _secBadge(sc.mitreTechnique, Colors.purpleAccent),
                            _secBadge(sc.mitreTactic, Colors.blueAccent),
                            _secBadge(sc.severity.toUpperCase(), sevCol),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(sc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          sc.description,
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                sc.complianceRefs.join(' • '),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _runningPurple ? null : () => _runPurpleScenario(sc),
                              icon: const Icon(Icons.play_arrow, size: 15),
                              label: const Text('Run Test', style: TextStyle(fontSize: 11)),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.purpleAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_purpleRuns.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Purple Team Verification Scorecards & MTTD', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ..._purpleRuns.map((r) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: (r.detected ? const Color(0xFF10B981) : Colors.redAccent).withValues(alpha: 0.4)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _secBadge(r.detected ? 'DETECTED' : 'MISSED', r.detected ? const Color(0xFF10B981) : Colors.redAccent),
                            _secBadge('SCORE ${r.score}/100', const Color(0xFF06B6D4)),
                            _secBadge('MTTD ${r.mttdMs.toStringAsFixed(2)} ms', Colors.amber),
                            _secBadge(r.mitreTechnique, Colors.purpleAccent),
                            Text('${r.scenarioName} (${r.targetNode}/${r.targetContainer})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...r.steps.map((st) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    st.status == 'failed' ? Icons.cancel : Icons.check_circle,
                                    size: 14,
                                    color: st.status == 'failed' ? Colors.redAccent : const Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text('${st.name}: ${st.detail}', style: const TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildQuarantineSubView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Forensic Container Quarantine ("Kill Switch")',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                onPressed: _openManualQuarantineDialog,
                icon: const Icon(Icons.block, size: 16),
                label: const Text('Quarantine Container'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Disconnects compromised workloads from cluster networks without destroying memory or live processes for DFIR evidence preservation.',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 16),
          if (_quarantines.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No containers currently quarantined.')),
              ),
            )
          else
            ..._quarantines.map((q) {
              final active = q.status == 'active';
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: (active ? Colors.redAccent : Colors.grey).withValues(alpha: 0.4)),
                ),
                child: ListTile(
                  leading: Icon(active ? Icons.block : Icons.lock_open, color: active ? Colors.redAccent : const Color(0xFF10B981)),
                  title: Row(
                    children: [
                      Text(q.containerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      _secBadge(q.status.toUpperCase(), active ? Colors.redAccent : const Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      _secBadge(q.method, const Color(0xFF06B6D4)),
                    ],
                  ),
                  subtitle: Text('${q.nodeHost} • ${q.reason}\n${q.details}', style: const TextStyle(fontSize: 11)),
                  trailing: active
                      ? OutlinedButton.icon(
                          onPressed: () => _releaseQuarantine(q.id, q.containerName),
                          icon: const Icon(Icons.restore, size: 15),
                          label: const Text('Release'),
                        )
                      : null,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPcapSubView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('On-Demand Forensic PCAP Sniffer (Wireshark Compatible)',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), foregroundColor: Colors.black),
                onPressed: _capturingPcap ? null : _openPcapCaptureDialog,
                icon: _capturingPcap
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.fiber_manual_record, size: 15),
                label: const Text('New PCAP Capture'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_pcaps.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No PCAP captures recorded yet. Click "New PCAP Capture" to collect packets.')),
              ),
            )
          else
            ..._pcaps.map((cap) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.35)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.network_check, color: Color(0xFF06B6D4), size: 18),
                            const SizedBox(width: 8),
                            Text('${cap.id} (${cap.nodeHost})', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            _secBadge(cap.source, Colors.purpleAccent),
                            const SizedBox(width: 6),
                            _secBadge('${cap.packetCount} pkts • ${_formatBytes(cap.sizeBytes)}', const Color(0xFF10B981)),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: () => ApiService.downloadEbpfPcap(cap.id),
                              icon: const Icon(Icons.download, size: 15),
                              label: const Text('Download .pcap', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                        if (cap.summaryLines.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B1120),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: SelectableText(
                              cap.summaryLines.take(10).join('\n'),
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: Color(0xFFA5F3FC)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildProcessesSubView(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _processSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search PID, binary, container, node or remote IP...',
                      prefixIcon: const Icon(Icons.search, size: 16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _fetchTabDataSilently(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _triggerSurfaceScan,
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('Refresh Timeline'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _processes.isEmpty
              ? const Center(child: Text('No process-to-socket correlations captured yet.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Card(
                    elevation: 0,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('NODE')),
                          DataColumn(label: Text('CONTAINER')),
                          DataColumn(label: Text('PID / UID')),
                          DataColumn(label: Text('PROCESS')),
                          DataColumn(label: Text('PROTO')),
                          DataColumn(label: Text('LOCAL -> REMOTE')),
                          DataColumn(label: Text('FLAG')),
                        ],
                        rows: _processes.take(80).map((p) {
                          return DataRow(cells: [
                            DataCell(Text(p.nodeHost, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                            DataCell(Text(p.containerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                            DataCell(Text('${p.pid} / ${p.uid}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                            DataCell(Text(p.processName, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                            DataCell(_secBadge(p.protocol, _getProtocolColor(p.protocol))),
                            DataCell(Text('${p.localAddr} -> ${p.remoteAddr}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                            DataCell(p.suspicious
                                ? _secBadge(p.suspicionNote.isEmpty ? 'SUSPICIOUS' : p.suspicionNote, Colors.redAccent)
                                : _secBadge('NORMAL', const Color(0xFF10B981))),
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

  void _openManualQuarantineDialog() {
    final nameCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'Manual forensic isolation');
    String selectedNode = 'manager';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Quarantine Container (DFIR)'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Container Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _availableNodes.contains(selectedNode) ? selectedNode : 'manager',
                decoration: const InputDecoration(labelText: 'Centurion Node', border: OutlineInputBorder()),
                items: _availableNodes
                    .where((n) => n != 'ALL')
                    .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) selectedNode = v;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Incident Reason', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              final cname = nameCtrl.text.trim();
              if (cname.isEmpty) return;
              Navigator.of(ctx).pop();
              _quarantineContainer(containerName: cname, nodeHost: selectedNode, reason: reasonCtrl.text.trim());
            },
            child: const Text('Isolate Network'),
          ),
        ],
      ),
    );
  }

  void _openPcapCaptureDialog() {
    final containerCtrl = TextEditingController();
    final filterCtrl = TextEditingController();
    String selectedNode = 'manager';
    int duration = 5;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.network_check, color: Color(0xFF06B6D4)),
              SizedBox(width: 8),
              Text('On-Demand Forensic PCAP Capture'),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _availableNodes.contains(selectedNode) ? selectedNode : 'manager',
                  decoration: const InputDecoration(labelText: 'Centurion Node', border: OutlineInputBorder()),
                  items: _availableNodes
                      .where((n) => n != 'ALL')
                      .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) selectedNode = v;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: containerCtrl,
                  decoration: const InputDecoration(labelText: 'Container Name (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: filterCtrl,
                  decoration: const InputDecoration(
                    labelText: 'BPF Filter (optional, e.g. tcp port 443)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Capture Window: $duration seconds', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Slider(
                  value: duration.toDouble(),
                  min: 3,
                  max: 30,
                  divisions: 9,
                  onChanged: (v) => setDlgState(() => duration = v.toInt()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _capturePcap(
                  nodeHost: selectedNode,
                  containerName: containerCtrl.text.trim(),
                  filter: filterCtrl.text.trim(),
                  durationS: duration,
                );
              },
              child: const Text('Start Capture'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, fontFamily: 'monospace'),
      ),
    );
  }

  Widget _metaKV(String k, String v, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$k: ', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
        Text(v, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
      ],
    );
  }

  Color _severityColor(String sev) {
    switch (sev.toLowerCase()) {
      case 'critical':
        return Colors.redAccent;
      case 'high':
        return Colors.orangeAccent;
      case 'medium':
        return Colors.amber;
      default:
        return const Color(0xFF10B981);
    }
  }
}

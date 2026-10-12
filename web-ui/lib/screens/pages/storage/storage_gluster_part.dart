part of '../storage_page.dart';

extension _StorageGlusterExt on _StoragePageState {
  // ═══════════════════════════════════════════════════════════════════════════
  // 6. GLUSTERFS CLUSTER STORAGE TAB (3-Way Mirror / Replica 3 / Arbiter)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildGlusterTab(bool isDark) {
    final diag = _glusterDiag;
    final isHealthy = (diag?.healthScore ?? 100) >= 80;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Diagnostics & Actions Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHealthy
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : Colors.orangeAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isHealthy
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : Colors.orangeAccent.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.hub,
                        color: isHealthy ? const Color(0xFF10B981) : Colors.orangeAccent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'GlusterFS Multi-Node Storage Mesh',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (diag?.daemonRunning == true ? const Color(0xFF10B981) : Colors.orange)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                diag?.daemonRunning == true ? 'DAEMON ACTIVE' : 'DAEMON INACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: diag?.daemonRunning == true ? const Color(0xFF10B981) : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dedicated Storage Network (enp0s2: 10.10.100.0/24) • CoreDNS (*.storage.gbnt.local) • Cockpit Total Management Suite',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'Refresh GlusterFS Storage Mesh',
                      onPressed: _loadAllData,
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_add_outlined, size: 16),
                      label: const Text('Probe Peer'),
                      onPressed: _showProbePeerDialog,
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Create Cluster Volume'),
                      onPressed: _showCreateGlusterVolumeDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // KPI Status Badges
                Row(
                  children: [
                    _buildGlusterKpi('Health Score', '${diag?.healthScore ?? 100}%', isHealthy ? const Color(0xFF10B981) : Colors.orange, Icons.health_and_safety_outlined),
                    const SizedBox(width: 16),
                    _buildGlusterKpi('Storage Pool Peers', '${_glusterPeers.length} Nodes', const Color(0xFF3B82F6), Icons.group_work_outlined),
                    const SizedBox(width: 16),
                    _buildGlusterKpi('Replicated Volumes', '${_glusterVolumes.length} Volumes', const Color(0xFF8B5CF6), Icons.layers_outlined),
                    const SizedBox(width: 16),
                    _buildGlusterKpi('Storage Network', '10.10.100.0/24 (enp0s2)', const Color(0xFF10B981), Icons.settings_ethernet),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Cockpit Sub-Navigation Bar ─────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildGlusterSubTabItem(0, 'Volumes & Peers', Icons.layers_outlined, isDark),
                const SizedBox(width: 8),
                _buildGlusterSubTabItem(1, 'Performance & I/O (Cockpit)', Icons.speed, isDark),
                const SizedBox(width: 8),
                _buildGlusterSubTabItem(2, 'Storage Network (Dual NIC)', Icons.settings_ethernet, isDark),
                const SizedBox(width: 8),
                _buildGlusterSubTabItem(3, 'Quotas & Directory Limits', Icons.data_usage_outlined, isDark),
                const SizedBox(width: 8),
                _buildGlusterSubTabItem(4, 'Volume Snapshots', Icons.camera_alt_outlined, isDark),
                const SizedBox(width: 8),
                _buildGlusterSubTabItem(5, 'Advanced Tuning Options', Icons.tune, isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Render Selected Sub-View
          if (_glusterSubTab == 0)
            _buildGlusterOverviewSubTab(isDark)
          else if (_glusterSubTab == 1)
            _buildGlusterPerformanceSubTab(isDark)
          else if (_glusterSubTab == 2)
            _buildGlusterNetworkSubTab(isDark)
          else if (_glusterSubTab == 3)
            _buildGlusterQuotasSubTab(isDark)
          else if (_glusterSubTab == 4)
            _buildGlusterSnapshotsSubTab(isDark)
          else
            _buildGlusterOptionsSubTab(isDark),
        ],
      ),
    );
  }

  Widget _buildGlusterSubTabItem(int index, String label, IconData icon, bool isDark) {
    final isSelected = _glusterSubTab == index;
    return InkWell(
      onTap: () {
        _updateState(() => _glusterSubTab = index);
        if (index == 1 && _selectedGlusterVolumeForProfile.isNotEmpty) {
          _fetchProfileData(_selectedGlusterVolumeForProfile);
        } else if (index == 3 && _selectedGlusterVolumeForProfile.isNotEmpty) {
          _fetchQuotasData(_selectedGlusterVolumeForProfile);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981).withValues(alpha: 0.18)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981)
                : (isDark ? const Color(0xFF334155) : Colors.grey[300]!),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF10B981) : (isDark ? Colors.grey[300] : Colors.grey[700])),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF10B981) : (isDark ? Colors.grey[300] : Colors.grey[800]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlusterOverviewSubTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Trusted Storage Pool Peers Section ─────────────────────────────
        Row(
          children: [
            const Icon(Icons.people_outline, size: 18, color: Color(0xFF3B82F6)),
            const SizedBox(width: 8),
            const Text(
              'Trusted Storage Pool Peers (Centurions)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              '${_glusterPeers.where((p) => p.connected).length}/${_glusterPeers.length} Peers Connected',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Peer Cards Grid
        if (_glusterPeers.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('No GlusterFS peers found. Use "Probe Peer" or run ansible/glusterfs.yml to initialize.'),
          )
        else
          Row(
            children: _glusterPeers.map((p) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: p.connected
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            p.isLocal ? Icons.security : Icons.dns_outlined,
                            size: 16,
                            color: const Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              p.hostname,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (p.connected ? const Color(0xFF10B981) : Colors.redAccent)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p.connected ? 'CONNECTED' : 'DISCONNECTED',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: p.connected ? const Color(0xFF10B981) : Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.uuid.isNotEmpty ? 'UUID: ${p.uuid.substring(0, 13)}...' : 'Local Manager Node',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.speed, size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            p.pingMs > 0 ? '${p.pingMs} ms latency' : '0.4 ms (Storage mesh)',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 24),

        // ── GlusterFS Volumes Section ─────────────────────────────────────
        Row(
          children: [
            const Icon(Icons.layers_outlined, size: 18, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            const Text(
              'Replicated Storage Volumes',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (_glusterVolumes.isNotEmpty) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('Delete All Volumes'),
                onPressed: _showDeleteAllGlusterVolumesDialog,
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Volume', style: TextStyle(fontSize: 12)),
                onPressed: _showCreateGlusterVolumeDialog,
              ),
              const SizedBox(width: 12),
            ],
            Text(
              '${_glusterVolumes.length} Managed Volumes',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_glusterVolumes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
            ),
            child: Column(
              children: [
                const Icon(Icons.hub_outlined, size: 48, color: Color(0xFF10B981)),
                const SizedBox(height: 12),
                const Text(
                  'No GlusterFS Cluster Volumes Configured',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create a 3-way replicated volume across your Centurions over the dedicated storage network (10.10.100.0/24).',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Replicated Volume (Replica 3)'),
                  onPressed: _showCreateGlusterVolumeDialog,
                ),
              ],
            ),
          )
        else
          Column(
            children: _glusterVolumes.map((vol) => _buildVolumeCard(vol, isDark)).toList(),
          ),
      ],
    );
  }

  // ── Cockpit-Storaged I/O Performance & Profiling Sub-Tab ──────────────────
  Widget _buildGlusterPerformanceSubTab(bool isDark) {
    final report = _activeProfileReport;
    final isProfiling = report?.isProfiling ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              const Text('Volume I/O Profiling (Cockpit Storaged Engine)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              if (_glusterVolumes.isNotEmpty)
                DropdownButton<String>(
                  value: _selectedGlusterVolumeForProfile.isNotEmpty ? _selectedGlusterVolumeForProfile : _glusterVolumes.first.name,
                  items: _glusterVolumes.map((v) => DropdownMenuItem(value: v.name, child: Text('Volume: ${v.name}'))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      _updateState(() => _selectedGlusterVolumeForProfile = val);
                      _fetchProfileData(val);
                    }
                  },
                ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: Icon(isProfiling ? Icons.stop : Icons.play_arrow, size: 16, color: isProfiling ? Colors.redAccent : const Color(0xFF10B981)),
                label: Text(isProfiling ? 'Stop Profiling' : 'Start Profiling', style: TextStyle(color: isProfiling ? Colors.redAccent : const Color(0xFF10B981))),
                onPressed: () async {
                  if (_selectedGlusterVolumeForProfile.isEmpty) return;
                  try {
                    if (isProfiling) {
                      await ApiService.stopGlusterVolumeProfile(_selectedGlusterVolumeForProfile);
                      _showSnackBar('Profiling stopped for $_selectedGlusterVolumeForProfile');
                    } else {
                      await ApiService.startGlusterVolumeProfile(_selectedGlusterVolumeForProfile);
                      _showSnackBar('Profiling started for $_selectedGlusterVolumeForProfile');
                    }
                    _fetchProfileData(_selectedGlusterVolumeForProfile);
                  } catch (e) {
                    _showSnackBar('Failed to toggle profiling: $e', isError: true);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Speedometer KPIs
          Row(
            children: [
              _buildGlusterMetricCard('Total IOPS', '${report?.totalIOPS ?? 0} IOPS', const Color(0xFF10B981), Icons.bolt, isDark),
              const SizedBox(width: 12),
              _buildGlusterMetricCard('Read Throughput', '${(report?.totalReadMBs ?? 0).toStringAsFixed(1)} MB/s', const Color(0xFF3B82F6), Icons.download, isDark),
              const SizedBox(width: 12),
              _buildGlusterMetricCard('Write Throughput', '${(report?.totalWriteMBs ?? 0).toStringAsFixed(1)} MB/s', const Color(0xFF8B5CF6), Icons.upload, isDark),
              const SizedBox(width: 12),
              _buildGlusterMetricCard('Average Latency', '${(report?.avgLatencyMs ?? 0).toStringAsFixed(2)} ms', Colors.amber, Icons.timer_outlined, isDark),
            ],
          ),
          const SizedBox(height: 20),

          // FOP Operations Breakdown Table
          const Text('File Operations (FOP) Breakdown:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 8),
          if (report == null || report.topOperations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No profiling data collected yet. Click "Start Profiling" to begin sampling block operations.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
                4: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                  children: const [
                    Padding(padding: EdgeInsets.all(8), child: Text('OPERATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                    Padding(padding: EdgeInsets.all(8), child: Text('HITS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                    Padding(padding: EdgeInsets.all(8), child: Text('% OF I/O', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                    Padding(padding: EdgeInsets.all(8), child: Text('AVG LATENCY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                    Padding(padding: EdgeInsets.all(8), child: Text('MAX LATENCY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  ],
                ),
                ...report.topOperations.map((fop) {
                  return TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.all(8), child: Text(fop.operation, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: const EdgeInsets.all(8), child: Text('${fop.hits}', style: const TextStyle(fontSize: 12))),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: (fop.percentage / 100).clamp(0.0, 1.0),
                                color: const Color(0xFF10B981),
                                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('${fop.percentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      Padding(padding: const EdgeInsets.all(8), child: Text('${fop.avgLatencyUs.toStringAsFixed(1)} μs', style: const TextStyle(fontSize: 12))),
                      Padding(padding: const EdgeInsets.all(8), child: Text('${fop.maxLatencyUs.toStringAsFixed(1)} μs', style: const TextStyle(fontSize: 12))),
                    ],
                  );
                }),
              ],
            ),
          const SizedBox(height: 20),

          // Block Size Distribution
          const Text('Block Size Distribution Histogram:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 8),
          if (report != null && report.blockSizeProfile.isNotEmpty)
            Row(
              children: report.blockSizeProfile.map((b) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.range, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('Reads: ${b.readHits} | Writes: ${b.writeHits}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Dedicated Storage Network (Dual NIC & CoreDNS) Sub-Tab ────────────────
  Widget _buildGlusterNetworkSubTab(bool isDark) {
    final net = _storageNetworkReport;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Network Overview Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings_ethernet, color: Color(0xFF10B981), size: 22),
                  const SizedBox(width: 10),
                  const Text('Dedicated Storage Network (Dual-NIC Architecture)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('SUBNET: ${net.dedicatedSubnet}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF10B981))),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('DNS: ${net.corednsSuffix}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF3B82F6))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Centurion nodes use a dedicated virtual network interface (enp0s2) exclusively for GlusterFS replication streams, brick communication, and FUSE mount transport to prevent interference with application traffic on enp0s1.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildGlusterMetricCard('Cluster Storage Rx Rate', '${net.totalRxRateMBs.toStringAsFixed(2)} MB/s', const Color(0xFF10B981), Icons.arrow_downward, isDark),
                  const SizedBox(width: 12),
                  _buildGlusterMetricCard('Cluster Storage Tx Rate', '${net.totalTxRateMBs.toStringAsFixed(2)} MB/s', const Color(0xFF3B82F6), Icons.arrow_upward, isDark),
                  const SizedBox(width: 12),
                  _buildGlusterMetricCard('Dedicated NIC Status', 'enp0s2 (UP & Active)', const Color(0xFF8B5CF6), Icons.check_circle_outline, isDark),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Node Cards Grid
        const Text('Centurion Storage Interfaces & Live Traffic:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),

        ...net.nodes.map((node) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(node.nodeRole == 'manager' ? Icons.security : Icons.computer, size: 18, color: const Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    Text('${node.nodeRole.toUpperCase()}: ${node.nodeId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('STORAGE IP: ${node.storageIp.isNotEmpty ? node.storageIp : "10.10.100.x"}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('DNS: ${node.storageDns}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                    ),
                    const Spacer(),
                    Text('Management IP: ${node.hostIp}', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Interface rows
                ...node.interfaces.map((iface) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(iface.isStorage ? Icons.star : Icons.alt_route, size: 14, color: iface.isStorage ? const Color(0xFF10B981) : Colors.grey),
                        const SizedBox(width: 6),
                        Text(iface.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Courier New')),
                        const SizedBox(width: 8),
                        if (iface.isStorage)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: const Text('DEDICATED STORAGE NIC', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                          ),
                        const Spacer(),
                        Text('Rx: ${iface.rxRateMBs.toStringAsFixed(2)} MB/s', style: const TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                        const SizedBox(width: 14),
                        Text('Tx: ${iface.txRateMBs.toStringAsFixed(2)} MB/s', style: const TextStyle(fontSize: 11.5, color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                        const SizedBox(width: 14),
                        Text('Total: ${_formatBytes(iface.rxBytes + iface.txBytes)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Quotas & Directory Limits Sub-Tab ─────────────────────────────────────
  Widget _buildGlusterQuotasSubTab(bool isDark) {
    final quotasReport = _activeQuotasReport;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.data_usage_outlined, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              const Text('Volume Quotas & Path Limits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              if (_glusterVolumes.isNotEmpty)
                DropdownButton<String>(
                  value: _selectedGlusterVolumeForProfile.isNotEmpty ? _selectedGlusterVolumeForProfile : _glusterVolumes.first.name,
                  items: _glusterVolumes.map((v) => DropdownMenuItem(value: v.name, child: Text('Volume: ${v.name}'))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      _updateState(() => _selectedGlusterVolumeForProfile = val);
                      _fetchQuotasData(val);
                    }
                  },
                ),
              const SizedBox(width: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Set Path Quota'),
                onPressed: () => _showSetQuotaDialog(_selectedGlusterVolumeForProfile),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (quotasReport == null || quotasReport.quotas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No path quotas configured for this volume. Click "Set Path Quota" to restrict directory disk consumption.', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
            )
          else
            Column(
              children: quotasReport.quotas.map((q) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder, size: 18, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 8),
                      Text(q.path, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Courier New')),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text('LIMIT: ${q.hardLimit}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                      ),
                      const Spacer(),
                      Text('${q.usedMB.toStringAsFixed(1)} MB used', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Snapshots & Rollback Sub-Tab ──────────────────────────────────────────
  Widget _buildGlusterSnapshotsSubTab(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt_outlined, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              const Text('Volume Point-in-Time Snapshots', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                label: const Text('Create Snapshot'),
                onPressed: () => _showCreateSnapshotDialog(_selectedGlusterVolumeForProfile.isNotEmpty ? _selectedGlusterVolumeForProfile : (_glusterVolumes.isNotEmpty ? _glusterVolumes.first.name : '')),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_glusterSnapshots.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No volume snapshots found. Take a snapshot to enable instantaneous rollback and disaster recovery.', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
                4: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                  children: const [
                    Padding(padding: EdgeInsets.all(8), child: Text('SNAPSHOT NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                    Padding(padding: EdgeInsets.all(8), child: Text('VOLUME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                    Padding(padding: EdgeInsets.all(8), child: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                    Padding(padding: EdgeInsets.all(8), child: Text('CREATED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                    Padding(padding: EdgeInsets.all(8), child: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  ],
                ),
                ..._glusterSnapshots.map((s) {
                  return TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.all(8), child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(s.volumeName, style: const TextStyle(fontSize: 12))),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(s.status, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ),
                      Padding(padding: const EdgeInsets.all(8), child: Text(s.createdAt, style: const TextStyle(fontSize: 11.5, color: Colors.grey))),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.history, size: 16, color: Color(0xFF3B82F6)),
                              tooltip: 'Rollback to Snapshot',
                              onPressed: () async {
                                try {
                                  await ApiService.restoreGlusterSnapshot(s.name);
                                  _showSnackBar('Snapshot ${s.name} restored successfully');
                                  _loadAllData();
                                } catch (e) {
                                  _showSnackBar('Failed to restore snapshot: $e', isError: true);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                              tooltip: 'Delete Snapshot',
                              onPressed: () async {
                                try {
                                  await ApiService.deleteGlusterSnapshot(s.name);
                                  _showSnackBar('Snapshot ${s.name} deleted');
                                  _loadAllData();
                                } catch (e) {
                                  _showSnackBar('Failed to delete snapshot: $e', isError: true);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  // ── Advanced Tuning Options Sub-Tab ───────────────────────────────────────
  // ── Advanced Tuning Options Sub-Tab ───────────────────────────────────────
  Widget _buildGlusterOptionsSubTab(bool isDark) {
    final activeVolName = _selectedGlusterVolumeForProfile.isNotEmpty
        ? _selectedGlusterVolumeForProfile
        : (_glusterVolumes.isNotEmpty ? _glusterVolumes.first.name : 'gv_contenedores');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              const Text('Volume Tuning & Network Access Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              if (_glusterVolumes.isNotEmpty)
                DropdownButton<String>(
                  value: activeVolName,
                  items: _glusterVolumes.map((v) => DropdownMenuItem(value: v.name, child: Text('Volume: ${v.name}'))).toList(),
                  onChanged: (val) {
                    if (val != null) _updateState(() => _selectedGlusterVolumeForProfile = val);
                  },
                ),
              const SizedBox(width: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Set Custom Option', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => _showSetOptionDialog(activeVolName),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 1: Storage Network & Access Security Isolation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.security, size: 16, color: Color(0xFF0284C7)),
                    SizedBox(width: 6),
                    Text(
                      'Storage Network & Security Isolation',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildOptionToggleTile(
                  'auth.allow',
                  'Restricts volume access strictly to dedicated storage subnet (e.g. 10.10.100.*, 10.0.1.* or *)',
                  '10.10.100.*',
                  activeVolName,
                  isDark,
                  icon: Icons.lan,
                  isNetwork: true,
                ),
                _buildOptionToggleTile(
                  'auth.reject',
                  'Subnet / IP Deny List: Rejects connections from unwanted public/management subnets',
                  'NONE',
                  activeVolName,
                  isDark,
                  icon: Icons.block,
                  isNetwork: true,
                ),
                _buildOptionToggleTile(
                  'network.ping-timeout',
                  'Failover network timeout (seconds) before marking an unreachable node/brick disconnected',
                  '10',
                  activeVolName,
                  isDark,
                  icon: Icons.timer,
                  isNetwork: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Section 2: Container Workload & Performance Acceleration
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.speed, size: 16, color: Color(0xFF10B981)),
                    SizedBox(width: 6),
                    Text(
                      'Container Performance & Cache Acceleration',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildOptionToggleTile(
                  'performance.write-behind',
                  'Asynchronous write aggregation and background flush for container storage workloads',
                  'on',
                  activeVolName,
                  isDark,
                ),
                _buildOptionToggleTile(
                  'performance.stat-prefetch',
                  'Aggressive directory traversal and POSIX metadata caching',
                  'on',
                  activeVolName,
                  isDark,
                ),
                _buildOptionToggleTile(
                  'performance.quick-read',
                  'Inlines small container file reads directly in directory lookups',
                  'on',
                  activeVolName,
                  isDark,
                ),
                _buildOptionToggleTile(
                  'cluster.favorite-child-policy',
                  'Automatic conflict resolution based on modified timestamp (mtime)',
                  'mtime',
                  activeVolName,
                  isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionToggleTile(
    String key,
    String description,
    String value,
    String volumeName,
    bool isDark, {
    IconData? icon,
    bool isNetwork = false,
  }) {
    final badgeColor = isNetwork ? const Color(0xFF0284C7) : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: badgeColor),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Courier New')),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('VALUE: $value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: badgeColor)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(60, 30),
              side: BorderSide(color: badgeColor.withValues(alpha: 0.5)),
            ),
            onPressed: () => _showSetOptionDialog(volumeName, key, value),
            child: Text('Configure', style: TextStyle(fontSize: 11, color: badgeColor)),
          ),
        ],
      ),
    );
  }

  void _showSetOptionDialog(String volumeName, [String? initialKey, String? initialVal]) {
    final keyCtrl = TextEditingController(text: initialKey ?? 'auth.allow');
    final valCtrl = TextEditingController(text: initialVal ?? '10.10.100.*');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.tune, color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 8),
            Text('Configure Option: $volumeName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configure storage network isolation, subnet access restrictions or container performance parameters on this volume.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: keyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Option Key',
                  hintText: 'e.g. auth.allow, auth.reject, network.ping-timeout',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valCtrl,
                decoration: const InputDecoration(
                  labelText: 'Option Value',
                  hintText: 'e.g. 10.10.100.*, on, off, 10, mtime',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.data_object, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ActionChip(
                    label: const Text('auth.allow (10.10.100.*)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      keyCtrl.text = 'auth.allow';
                      valCtrl.text = '10.10.100.*';
                    },
                  ),
                  ActionChip(
                    label: const Text('auth.allow (*)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      keyCtrl.text = 'auth.allow';
                      valCtrl.text = '*';
                    },
                  ),
                  ActionChip(
                    label: const Text('network.ping-timeout (10)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      keyCtrl.text = 'network.ping-timeout';
                      valCtrl.text = '10';
                    },
                  ),
                  ActionChip(
                    label: const Text('write-behind (on)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      keyCtrl.text = 'performance.write-behind';
                      valCtrl.text = 'on';
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.amber),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.setGlusterVolumeOption(volumeName, keyCtrl.text.trim(), '', reset: true);
                _showSnackBar('Option ${keyCtrl.text.trim()} reset to default on $volumeName');
                _loadAllData();
              } catch (e) {
                _showSnackBar('Failed to reset option: $e', isError: true);
              }
            },
            child: const Text('Reset to Default'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.setGlusterVolumeOption(volumeName, keyCtrl.text.trim(), valCtrl.text.trim());
                _showSnackBar('Option ${keyCtrl.text.trim()}=${valCtrl.text.trim()} applied successfully on $volumeName');
                _loadAllData();
              } catch (e) {
                _showSnackBar('Failed to set option: $e', isError: true);
              }
            },
            child: const Text('Apply Option'),
          ),
        ],
      ),
    );
  }

  Widget _buildGlusterMetricCard(String label, String value, Color color, IconData icon, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchProfileData(String volumeName) async {
    try {
      final rep = await ApiService.fetchGlusterVolumeProfile(volumeName);
      if (mounted) _updateState(() => _activeProfileReport = rep);
    } catch (_) {}
  }

  Future<void> _fetchQuotasData(String volumeName) async {
    try {
      final rep = await ApiService.fetchGlusterQuotas(volumeName);
      if (mounted) _updateState(() => _activeQuotasReport = rep);
    } catch (_) {}
  }

  void _showSetQuotaDialog(String volumeName) {
    final pathCtrl = TextEditingController(text: '/');
    final limitCtrl = TextEditingController(text: '50GB');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set Quota: $volumeName'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: pathCtrl, decoration: const InputDecoration(labelText: 'Directory Path', hintText: '/app-data', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: limitCtrl, decoration: const InputDecoration(labelText: 'Hard Limit', hintText: '50GB, 100GB, 1TB', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.setGlusterQuota(volumeName, pathCtrl.text.trim(), limitCtrl.text.trim());
                _showSnackBar('Quota configured successfully');
                _fetchQuotasData(volumeName);
              } catch (e) {
                _showSnackBar('Failed to set quota: $e', isError: true);
              }
            },
            child: const Text('Set Limit'),
          ),
        ],
      ),
    );
  }

  void _showCreateSnapshotDialog(String volumeName) {
    final nameCtrl = TextEditingController(text: 'snap_${volumeName}_${DateTime.now().millisecondsSinceEpoch % 10000}');
    final descCtrl = TextEditingController(text: 'Pre-deployment backup');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Create Snapshot: $volumeName'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Snapshot Name', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.createGlusterSnapshot(nameCtrl.text.trim(), volumeName, description: descCtrl.text.trim());
                _showSnackBar('Snapshot created successfully');
                _loadAllData();
              } catch (e) {
                _showSnackBar('Failed to create snapshot: $e', isError: true);
              }
            },
            child: const Text('Create Snapshot'),
          ),
        ],
      ),
    );
  }

  Widget _buildGlusterKpi(String label, String value, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildVolumeCard(GlusterVolumeModel vol, bool isDark) {
    final isStarted = vol.status == 'Started';
    final hasRegisteredMount = _mounts.any((m) => m.fsType == 'glusterfs' && (m.device.contains(vol.name) || m.name.contains(vol.name)));
    final matchingMount = _mounts.firstWhere(
      (m) => m.fsType == 'glusterfs' && (m.device.contains(vol.name) || m.name.contains(vol.name)),
      orElse: () => StorageMountModel.empty(),
    );
    final isMounted = vol.isMounted || hasRegisteredMount;
    final displayMountPoint = matchingMount.mountPoint.isNotEmpty ? matchingMount.mountPoint : (vol.mountPoint.isNotEmpty ? vol.mountPoint : '/var/contenedores');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isStarted
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Volume Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.layers, color: isStarted ? const Color(0xFF10B981) : Colors.orange, size: 20),
                const SizedBox(width: 10),
                Text(
                  vol.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Replica ${vol.replicaCount}${vol.arbiterCount > 0 ? ' (Arbiter 1)' : ''}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isStarted ? const Color(0xFF10B981) : Colors.orange).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    vol.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isStarted ? const Color(0xFF10B981) : Colors.orange,
                    ),
                  ),
                ),
                if (isMounted) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.link, size: 12, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          'fstab: $displayMountPoint',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link_off, size: 12, color: Colors.amber),
                        SizedBox(width: 4),
                        Text(
                          'Unmounted in fstab',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),

                // Prominent Mount Action Button
                OutlinedButton.icon(
                  icon: Icon(isMounted ? Icons.sync : Icons.add_link, size: 14, color: const Color(0xFF3B82F6)),
                  label: Text(
                    isMounted ? 'Remount / fstab' : 'Mount to fstab',
                    style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _showMountClusterDialog(vol.name),
                ),
                const SizedBox(width: 6),

                // Action Buttons
                IconButton(
                  icon: const Icon(Icons.medical_services_outlined, size: 18, color: Color(0xFF10B981)),
                  tooltip: 'Self-Heal & Split-Brain Diagnostics',
                  onPressed: () => _showGlusterHealDialog(vol.name),
                ),
                if (isStarted)
                  IconButton(
                    icon: const Icon(Icons.stop_circle_outlined, size: 18, color: Colors.orange),
                    tooltip: 'Stop Volume',
                    onPressed: () => _stopGlusterVolume(vol.name),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline, size: 18, color: Color(0xFF10B981)),
                    tooltip: 'Start Volume',
                    onPressed: () => _startGlusterVolume(vol.name),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  tooltip: 'Delete Volume',
                  onPressed: () => _showDeleteGlusterVolumeDialog(vol),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Capacity Bar
                if (vol.capacityTotal > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Disk Capacity Usage', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                      Text(
                        '${vol.capacityPercent.toStringAsFixed(1)}% (${_formatBytes(vol.capacityUsed)} / ${_formatBytes(vol.capacityTotal)})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: vol.capacityPercent / 100.0,
                      backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        vol.capacityPercent > 85 ? Colors.redAccent : const Color(0xFF10B981),
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Bricks Table
                Text(
                  'Storage Bricks (${vol.bricks.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2.5),
                      1: FlexColumnWidth(3.5),
                      2: FlexColumnWidth(1.2),
                      3: FlexColumnWidth(1.5),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                        ),
                        children: const [
                          Padding(padding: EdgeInsets.all(8), child: Text('CENTURION HOST', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(8), child: Text('BRICK STORAGE PATH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(8), child: Text('PORT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(8), child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      ...vol.bricks.map((b) {
                        return TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  const Icon(Icons.dns_outlined, size: 14, color: Color(0xFF3B82F6)),
                                  const SizedBox(width: 6),
                                  Text(b.host, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: SelectableText(b.path, style: const TextStyle(fontFamily: 'Courier New', fontSize: 11.5)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text('${b.port}', style: const TextStyle(fontSize: 12)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  Icon(
                                    b.online ? Icons.check_circle : Icons.error,
                                    size: 14,
                                    color: b.online ? const Color(0xFF10B981) : Colors.redAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    b.online ? 'Online' : 'Offline',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: b.online ? const Color(0xFF10B981) : Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Dialogs & Action Handlers for GlusterFS ───────────────────────────────

  void _showCreateGlusterVolumeDialog() {
    final existingNames = _glusterVolumes.map((v) => v.name).toSet();
    String defaultName = 'gv_data';
    if (!existingNames.contains('gv_contenedores')) {
      defaultName = 'gv_contenedores';
    } else if (existingNames.contains('gv_data')) {
      defaultName = 'gv_storage';
    }
    final nameCtrl = TextEditingController(text: defaultName);
    final brickDirCtrl = TextEditingController(text: '/data/glusterfs/brick1');
    final mountPointCtrl = TextEditingController(
      text: defaultName == 'gv_contenedores' ? '/var/contenedores' : '/mnt/gluster/$defaultName',
    );
    final customHostsCtrl = TextEditingController(text: '');
    int replicaCount = 3;
    bool autoMount = true;
    bool forceRecreate = false;
    String networkMode = 'storage'; // 'storage', 'management', 'custom'

    // Node selection tracking: default to first 3 nodes if >= 3, or all nodes
    final clusterNodes = widget.state.nodes;
    final Set<String> selectedNodeIds = <String>{};
    if (clusterNodes.length >= 3) {
      for (int i = 0; i < 3; i++) {
        selectedNodeIds.add(clusterNodes[i].id);
      }
      replicaCount = 3;
    } else if (clusterNodes.length == 2) {
      for (final n in clusterNodes) {
        selectedNodeIds.add(n.id);
      }
      replicaCount = 2;
    } else {
      for (final n in clusterNodes) {
        selectedNodeIds.add(n.id);
      }
      replicaCount = 2;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final totalSelected = selectedNodeIds.length;
            final isDivisible = totalSelected >= 2 && (totalSelected % replicaCount == 0);
            final isValid = totalSelected >= 2 && isDivisible;

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.hub, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text('Create GlusterFS Replicated Volume'),
                ],
              ),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        onChanged: (val) {
                          setDlgState(() {
                            final trimmed = val.trim();
                            if (mountPointCtrl.text.isEmpty ||
                                mountPointCtrl.text == '/var/contenedores' ||
                                mountPointCtrl.text.startsWith('/mnt/gluster/')) {
                              mountPointCtrl.text = trimmed == 'gv_contenedores'
                                  ? '/var/contenedores'
                                  : (trimmed.isNotEmpty ? '/mnt/gluster/$trimmed' : '');
                            }
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Volume Name',
                          hintText: 'e.g. gv_data, gv_mysql',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.folder_shared, size: 20),
                        ),
                      ),
                      if (existingNames.contains(nameCtrl.text.trim())) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFEF4444)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Volume "${nameCtrl.text.trim()}" already exists in the cluster. Choose another name, or enable "Force Recreate / Purge Ghost Volume" below.',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Replication Strategy with clear explanation
                      DropdownButtonFormField<int>(
                        initialValue: replicaCount,
                        decoration: const InputDecoration(
                          labelText: 'Replication Strategy (Mirror Multiplier)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.copy_all, size: 20),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 3,
                            child: Text('Replica 3 — 3-Way Mirror (Requires multiple of 3 nodes: 3, 6)'),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text('Replica 2 — 2-Way Mirror (Requires multiple of 2 nodes: 2, 4)'),
                          ),
                          DropdownMenuItem(
                            value: 4,
                            child: Text('Replica 4 — 4-Way Mirror (Requires 4 nodes)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDlgState(() => replicaCount = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Storage Network Interface Selector
                      DropdownButtonFormField<String>(
                        initialValue: networkMode,
                        decoration: const InputDecoration(
                          labelText: 'Storage Network Interface / Subnet',
                          helperText: 'Select which network GlusterFS binds its bricks and replication traffic to.',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.settings_ethernet, size: 20),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'storage',
                            child: Text('🌐 Dedicated Storage Network (Dual-NIC / 10.10.100.0/24)'),
                          ),
                          DropdownMenuItem(
                            value: 'management',
                            child: Text('🏢 Management / Primary Network (192.168.x.x)'),
                          ),
                          DropdownMenuItem(
                            value: 'custom',
                            child: Text('🛠️ Custom Host Storage IPs (Specify manually)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setDlgState(() => networkMode = val);
                        },
                      ),
                      if (networkMode == 'custom') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: customHostsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Custom Node Storage IPs (Comma-separated)',
                            hintText: 'e.g. 10.10.100.27, 10.10.100.25, 10.10.100.26',
                            helperText: 'Enter specific storage IPs for the manager and worker bricks.',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lan, size: 20),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Granular Centurion Node Selection Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: isValid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              width: 4,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.dns, size: 18, color: Color(0xFF10B981)),
                                const SizedBox(width: 8),
                                Text(
                                  'Target Centurion Nodes ($totalSelected of ${clusterNodes.length} Selected)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const Spacer(),
                                // Preset Quick Select Chips
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    ActionChip(
                                      visualDensity: VisualDensity.compact,
                                      avatar: const Icon(Icons.select_all, size: 14),
                                      label: const Text('All Nodes', style: TextStyle(fontSize: 11)),
                                      onPressed: () {
                                        setDlgState(() {
                                          selectedNodeIds.clear();
                                          for (final n in clusterNodes) {
                                            selectedNodeIds.add(n.id);
                                          }
                                          if (selectedNodeIds.length == 4) {
                                            replicaCount = 2; // Auto-tune 4 nodes to Replica 2
                                          } else if (selectedNodeIds.length % 3 == 0) {
                                            replicaCount = 3;
                                          }
                                        });
                                      },
                                    ),
                                    if (clusterNodes.length >= 3)
                                      ActionChip(
                                        visualDensity: VisualDensity.compact,
                                        avatar: const Icon(Icons.filter_3, size: 14),
                                        label: const Text('3 Nodes (R3)', style: TextStyle(fontSize: 11)),
                                        onPressed: () {
                                          setDlgState(() {
                                            selectedNodeIds.clear();
                                            for (int i = 0; i < 3 && i < clusterNodes.length; i++) {
                                              selectedNodeIds.add(clusterNodes[i].id);
                                            }
                                            replicaCount = 3;
                                          });
                                        },
                                      ),
                                    if (clusterNodes.length >= 2)
                                      ActionChip(
                                        visualDensity: VisualDensity.compact,
                                        avatar: const Icon(Icons.filter_2, size: 14),
                                        label: const Text('2 Nodes (R2)', style: TextStyle(fontSize: 11)),
                                        onPressed: () {
                                          setDlgState(() {
                                            selectedNodeIds.clear();
                                            for (int i = 0; i < 2 && i < clusterNodes.length; i++) {
                                              selectedNodeIds.add(clusterNodes[i].id);
                                            }
                                            replicaCount = 2;
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Select the physical hosts where GlusterFS will place volume bricks. The total number of selected hosts must be divisible by the replica multiplier.',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),

                            // Node Checkbox List
                            ...clusterNodes.map((node) {
                              final isSelected = selectedNodeIds.contains(node.id);
                              final isMgr = node.role.toLowerCase() == 'manager';
                              return CheckboxListTile(
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                activeColor: const Color(0xFF10B981),
                                value: isSelected,
                                title: Row(
                                  children: [
                                    Icon(
                                      isMgr ? Icons.security : Icons.memory,
                                      size: 16,
                                      color: isMgr ? Colors.amber : const Color(0xFF3B82F6),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${node.role.toUpperCase()}: ${node.labels['gbnt.node.hostname'] ?? node.id}',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'IP: ${node.ip}',
                                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                                onChanged: (val) {
                                  setDlgState(() {
                                    if (val == true) {
                                      selectedNodeIds.add(node.id);
                                    } else {
                                      selectedNodeIds.remove(node.id);
                                    }
                                    // Automatic smart suggestion of replica count
                                    if (selectedNodeIds.length == 3) {
                                      replicaCount = 3;
                                    } else if (selectedNodeIds.length == 2 || selectedNodeIds.length == 4) {
                                      replicaCount = 2;
                                    }
                                  });
                                },
                              );
                            }),

                            const SizedBox(height: 8),

                            // Dynamic Validation Banner
                            if (isValid)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, size: 16, color: Color(0xFF10B981)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Valid Topology: $totalSelected bricks with Replica $replicaCount ($totalSelected ÷ $replicaCount = ${totalSelected ~/ replicaCount} subvolume${totalSelected ~/ replicaCount > 1 ? 's' : ''}). GlusterFS create will succeed.',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFEF4444)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        totalSelected < 2
                                            ? 'Please select at least 2 Centurion nodes to form a cluster volume.'
                                            : 'Divisibility Error: $totalSelected selected nodes is not divisible by Replica $replicaCount ($totalSelected % $replicaCount = ${totalSelected % replicaCount}). Please select ${totalSelected - (totalSelected % replicaCount)} or ${(totalSelected - (totalSelected % replicaCount)) + replicaCount} nodes, or change Replica Strategy to Replica ${totalSelected == 4 ? '2' : (totalSelected % 2 == 0 ? '2' : '3')}.',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: brickDirCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Brick Storage Directory on Nodes',
                          hintText: 'e.g. /data/glusterfs/brick1',
                          helperText: 'Residual metadata and xattrs will be cleaned automatically.',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.storage, size: 20),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: mountPointCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Target Mount Point for Containers',
                          hintText: 'e.g. /var/contenedores',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Auto-Mount to Cluster Nodes'),
                        subtitle: const Text('Automatically writes /etc/fstab and mounts on selected nodes on creation'),
                        value: autoMount,
                        activeThumbColor: const Color(0xFF10B981),
                        onChanged: (val) => setDlgState(() => autoMount = val),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Force Recreate / Purge Ghost Volume'),
                        subtitle: const Text('If a volume with this name already exists or is in an inconsistent state, automatically stop, purge, and recreate it cleanly'),
                        value: forceRecreate,
                        activeThumbColor: const Color(0xFF10B981),
                        onChanged: (val) => setDlgState(() => forceRecreate = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: isValid ? const Color(0xFF10B981) : Colors.grey,
                  ),
                  onPressed: !isValid
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          try {
                            List<String>? targetNodes;
                            if (selectedNodeIds.length == clusterNodes.length) {
                              targetNodes = ['all'];
                            } else {
                              targetNodes = selectedNodeIds.toList();
                            }
                            List<String>? customHosts;
                            if (networkMode == 'custom' && customHostsCtrl.text.trim().isNotEmpty) {
                              customHosts = customHostsCtrl.text
                                  .split(',')
                                  .map((s) => s.trim())
                                  .where((s) => s.isNotEmpty)
                                  .toList();
                            }

                            await ApiService.createGlusterVolume({
                              'name': nameCtrl.text.trim(),
                              'replica_count': replicaCount,
                              'brick_dir': brickDirCtrl.text.trim(),
                              'network_mode': networkMode,
                              'custom_hosts': customHosts,
                              'mount_point': mountPointCtrl.text.trim(),
                              'auto_mount': autoMount,
                              'target_nodes': targetNodes,
                              'force': false,
                              'force_recreate': forceRecreate,
                            });
                            _showSnackBar('GlusterFS volume ${nameCtrl.text} created and tuned successfully');
                            _loadAllData();
                          } catch (e) {
                            _showErrorDialog('Volume Creation Failed', 'Failed to create GlusterFS volume ${nameCtrl.text.trim()}:\n\n$e');
                            _showSnackBar('Failed to create volume: $e', isError: true);
                          }
                        },
                  child: const Text('Create & Optimize Volume'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMountClusterDialog(String volumeName) {
    String selectedTarget = 'all';
    final matchingMount = _mounts.firstWhere(
      (m) => m.fsType == 'glusterfs' && (m.device.contains(volumeName) || m.name.contains(volumeName)),
      orElse: () => StorageMountModel.empty(),
    );
    final initialPath = matchingMount.mountPoint.isNotEmpty ? matchingMount.mountPoint : '/var/contenedores';
    final mountPointCtrl = TextEditingController(text: initialPath);
    bool isMounting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.folder_shared_outlined, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text('Mount / Recreate Mount Point: $volumeName'),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (matchingMount.id.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Currently mapped to: ${matchingMount.mountPoint} (Target: ${matchingMount.targetNode})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextField(
                      controller: mountPointCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mount Directory Point',
                        hintText: '/var/contenedores',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.folder_open, size: 20),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        const Text('Quick targets: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ...['/var/contenedores', '/mnt/gluster', '/data/gluster', '/var/shared'].map((p) {
                          return ActionChip(
                            label: Text(p, style: const TextStyle(fontSize: 10.5)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              setDlgState(() => mountPointCtrl.text = p);
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTarget,
                      decoration: const InputDecoration(
                        labelText: 'Target Centurion Node(s)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.computer, size: 20),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('🌐 All Centurions (Whole Cluster Mobility)'),
                        ),
                        ...widget.state.nodes.map(
                          (node) => DropdownMenuItem(
                            value: node.id,
                            child: Text('💻 ${node.role.toUpperCase()}: ${node.ip} (${node.id})'),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => selectedTarget = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Automates directory creation (0777), updates /etc/fstab, executes mount -a, and syncs cluster storage.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  icon: isMounting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.link, size: 16),
                  label: Text(matchingMount.id.isNotEmpty ? 'Remount / Update fstab' : 'Mount Volume to fstab'),
                  onPressed: isMounting
                      ? null
                      : () async {
                          setDlgState(() => isMounting = true);
                          try {
                            List<String>? targetNodes;
                            if (selectedTarget != 'all') {
                              targetNodes = [selectedTarget];
                            }
                            await ApiService.mountGlusterCluster(
                              volumeName,
                              mountPoint: mountPointCtrl.text.trim(),
                              targetNodes: targetNodes,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showSnackBar('✅ Volume $volumeName mounted successfully on target: $selectedTarget');
                            _loadAllData();
                          } catch (e) {
                            setDlgState(() => isMounting = false);
                            _showSnackBar('❌ Failed to mount volume: $e', isError: true);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteGlusterVolumeDialog(GlusterVolumeModel vol) {
    bool unmountCluster = true;
    final matchingMount = _mounts.firstWhere(
      (m) => m.fsType == 'glusterfs' && (m.device.contains(vol.name) || m.name.contains(vol.name)),
      orElse: () => StorageMountModel.empty(),
    );
    final isMounted = vol.isMounted || matchingMount.id.isNotEmpty;
    final mountPoint = matchingMount.mountPoint.isNotEmpty ? matchingMount.mountPoint : (vol.mountPoint.isNotEmpty ? vol.mountPoint : '/var/contenedores');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.delete_forever, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Text('Delete GlusterFS Volume: ${vol.name}'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you sure you want to delete GlusterFS volume "${vol.name}" (${vol.type}, ${vol.bricks.length} bricks)?',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    if (isMounted)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.link, size: 18, color: Colors.amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Active Mount Point: $mountPoint across cluster hosts in /etc/fstab.',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                              ),
                            ),
                          ],
                        ),
                      ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: unmountCluster,
                      activeColor: const Color(0xFF10B981),
                      title: const Text(
                        'Unmount and clean /etc/fstab across cluster nodes',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Safely unmounts filesystem and cleans mount entries on all Centurion hosts.',
                        style: TextStyle(fontSize: 11),
                      ),
                      onChanged: (val) => setDlgState(() => unmountCluster = val ?? true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await ApiService.deleteGlusterVolume(vol.name, unmount: unmountCluster);
                      _showSnackBar('Volume ${vol.name} deleted successfully');
                      _loadAllData();
                    } catch (e) {
                      _showErrorDialog('Delete Volume Failed', 'Failed to delete volume ${vol.name}:\n\n$e');
                      _showSnackBar('Failed to delete volume: $e', isError: true);
                    }
                  },
                  child: const Text('Delete Volume'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteAllGlusterVolumesDialog() {
    bool unmountAll = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Delete ALL GlusterFS Volumes'),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you sure you want to delete ALL ${_glusterVolumes.length} GlusterFS cluster volumes (${_glusterVolumes.map((v) => v.name).join(', ')})?',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This action will permanently stop and remove all GlusterFS distributed volumes across all Centurion nodes.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: unmountAll,
                      activeColor: Colors.redAccent,
                      title: const Text(
                        'Unmount all GlusterFS filesystems and clean /etc/fstab across all hosts',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Safely unmounts and removes all GlusterFS mount records from cluster nodes.',
                        style: TextStyle(fontSize: 11),
                      ),
                      onChanged: (val) => setDlgState(() => unmountAll = val ?? true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await ApiService.deleteAllGlusterVolumes(unmount: unmountAll);
                      _showSnackBar('All GlusterFS volumes deleted successfully');
                      _loadAllData();
                    } catch (e) {
                      _showSnackBar('Failed to delete all volumes: $e', isError: true);
                    }
                  },
                  child: const Text('Delete All Volumes'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  void _showProbePeerDialog() {
    final hostCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Color(0xFF3B82F6)),
              SizedBox(width: 8),
              Text('Probe GlusterFS Peer Node'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: TextField(
              controller: hostCtrl,
              decoration: const InputDecoration(
                labelText: 'Target Node IP or Hostname',
                hintText: 'e.g. 192.168.252.28',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
              onPressed: () async {
                final host = hostCtrl.text.trim();
                if (host.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await ApiService.probeGlusterPeer(host);
                  _showSnackBar('Successfully probed peer $host');
                  _loadAllData();
                } catch (e) {
                  _showSnackBar('Failed to probe peer: $e', isError: true);
                }
              },
              child: const Text('Probe Peer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showGlusterHealDialog(String volumeName) async {
    try {
      final report = await ApiService.fetchGlusterHealReport(volumeName);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.medical_services_outlined, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Text('Self-Heal Diagnostics: $volumeName'),
              ],
            ),
            content: SizedBox(
              width: 550,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: report.inSplitBrain
                          ? Colors.redAccent.withValues(alpha: 0.15)
                          : const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: report.inSplitBrain ? Colors.redAccent : const Color(0xFF10B981),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          report.inSplitBrain ? Icons.error : Icons.check_circle,
                          color: report.inSplitBrain ? Colors.redAccent : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report.statusSummary,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pending files to heal: ${report.totalPending} | Split-Brain: ${report.inSplitBrain ? "YES" : "NO"}',
                                style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Brick Health & Entry Queue:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (report.bricksHealInfo.isEmpty)
                    const Text('All 3 bricks report 0 pending entries (100% in sync).')
                  else
                    ...report.bricksHealInfo.map((b) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.dns, size: 14, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(b.brickSpec, style: const TextStyle(fontSize: 12, fontFamily: 'Courier New'))),
                            Text('${b.numberOfEntries} pending', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            actions: [
              OutlinedButton.icon(
                icon: const Icon(Icons.healing, size: 16),
                label: const Text('Trigger Self-Heal Now'),
                onPressed: () async {
                  try {
                    await ApiService.triggerGlusterSelfHeal(volumeName);
                    _showSnackBar('Self-heal cycle initiated for $volumeName');
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    _showSnackBar('Failed to trigger self-heal: $e', isError: true);
                  }
                },
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          );
        },
      );
    } catch (e) {
      _showSnackBar('Failed to fetch heal report: $e', isError: true);
    }
  }

  Future<void> _startGlusterVolume(String name) async {
    try {
      await ApiService.startGlusterVolume(name);
      _showSnackBar('Volume $name started');
      _loadAllData();
    } catch (e) {
      _showErrorDialog('Start Volume Failed', 'Failed to start volume $name:\n\n$e');
      _showSnackBar('Failed to start volume: $e', isError: true);
    }
  }

  Future<void> _stopGlusterVolume(String name) async {
    try {
      await ApiService.stopGlusterVolume(name, force: true);
      _showSnackBar('Volume $name stopped');
      _loadAllData();
    } catch (e) {
      _showErrorDialog('Stop Volume Failed', 'Failed to stop volume $name:\n\n$e');
      _showSnackBar('Failed to stop volume: $e', isError: true);
    }
  }

}

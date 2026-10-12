part of '../storage_page.dart';

extension _StorageMountsFstabExt on _StoragePageState {
  // ── Tab 5: Network Mounts & /etc/fstab ─────────────────────────────

  Widget _buildMountsTab(bool isDark) {
    final filtered = _mounts.where((m) {
      final matchesSearch = _mountSearch.isEmpty ||
          m.name.toLowerCase().contains(_mountSearch.toLowerCase()) ||
          m.device.toLowerCase().contains(_mountSearch.toLowerCase()) ||
          m.mountPoint.toLowerCase().contains(_mountSearch.toLowerCase()) ||
          m.description.toLowerCase().contains(_mountSearch.toLowerCase());
      final matchesType = _mountTypeFilter == 'ALL' ||
          m.fsType.toLowerCase().contains(_mountTypeFilter.toLowerCase());
      return matchesSearch && matchesType;
    }).toList();

    final mountedCount = _mounts.where((m) => m.status == 'mounted').length;
    final fstabCount = _mounts.where((m) => m.autoMount).length;
    final isMobilityActive = _mounts.any((m) => m.mountPoint == '/var/contenedores' && m.status == 'mounted');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Metric Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  isDark,
                  'Active Mounts',
                  '$mountedCount / ${_mounts.length}',
                  mountedCount > 0 ? '🟢 All connected' : '⚪ No active network shares',
                  Icons.dns_outlined,
                  const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  isDark,
                  '/var/contenedores Mobility',
                  isMobilityActive ? 'SHARED NETWORK' : 'LOCAL ATTACHED',
                  isMobilityActive ? '🟢 Multi-node mobility active' : '🟡 Data bound to single host',
                  Icons.folder_special_outlined,
                  isMobilityActive ? const Color(0xFF10B981) : Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  isDark,
                  '/etc/fstab Managed Entries',
                  '$fstabCount Entries',
                  'Persistence on reboot enabled',
                  Icons.save_outlined,
                  const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action & Filter Toolbar
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search mounts by device, path, or name...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) => _updateState(() => _mountSearch = val),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _mountTypeFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Protocols')),
                  DropdownMenuItem(value: 'nfs', child: Text('NFS (v3/v4)')),
                  DropdownMenuItem(value: 'cifs', child: Text('Samba / CIFS')),
                  DropdownMenuItem(value: 's3', child: Text('S3 Object Storage')),
                  DropdownMenuItem(value: 'ext', child: Text('Local / POSIX')),
                ],
                onChanged: (val) {
                  if (val != null) _updateState(() => _mountTypeFilter = val);
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh Mounts Data',
                onPressed: _loadAllData,
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_note, size: 16),
                label: const Text('Edit /etc/fstab'),
                onPressed: _showFstabViewerDialog,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Mount All (mount -a)'),
                onPressed: _showMountAllDialog,
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Network Mount'),
                onPressed: () => _showAddMountDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Mounts Table
          if (filtered.isEmpty)
            Card(
              elevation: 0,
              color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.dns_outlined, size: 48, color: Colors.grey[500]),
                      const SizedBox(height: 12),
                      Text(
                        _mounts.isEmpty
                            ? 'No network mounts configured yet.'
                            : 'No mounts match your search filter.',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mount remote NFS shares, Windows Samba folders, or S3 buckets to /var/contenedores for container data mobility.',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Configure First Mount (NFS / S3 / Samba)'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                        onPressed: () => _showAddMountDialog(),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
              ),
              clipBehavior: Clip.antiAlias,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('PROTOCOL')),
                  DataColumn(label: Text('NAME & DESCRIPTION')),
                  DataColumn(label: Text('TARGET HOST')),
                  DataColumn(label: Text('REMOTE DEVICE / SHARE')),
                  DataColumn(label: Text('LOCAL MOUNT POINT')),
                  DataColumn(label: Text('AUTO-BOOT')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: filtered.map((m) {
                  Color typeColor = const Color(0xFF3B82F6);
                  String typeLabel = m.fsType.toUpperCase();
                  if (m.fsType.contains('cifs')) {
                    typeColor = const Color(0xFFF59E0B);
                    typeLabel = 'SAMBA / CIFS';
                  } else if (m.fsType.contains('s3')) {
                    typeColor = const Color(0xFF10B981);
                    typeLabel = 'S3 BUCKET';
                  } else if (m.fsType.contains('nfs')) {
                    typeColor = const Color(0xFF3B82F6);
                    typeLabel = 'NFS';
                  }

                  Color statusColor = Colors.orange;
                  if (m.status == 'mounted') {
                    statusColor = const Color(0xFF10B981);
                  } else if (m.status == 'error') {
                    statusColor = Colors.redAccent;
                  }

                  return DataRow(
                    cells: [
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(color: typeColor, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (m.description.isNotEmpty)
                              Text(m.description, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                          ],
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: m.targetNode == 'all'
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : (isDark ? Colors.grey[800] : Colors.grey[200]),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: m.targetNode == 'all'
                                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                m.targetNode == 'all' ? Icons.public : Icons.computer,
                                size: 13,
                                color: m.targetNode == 'all' ? const Color(0xFF10B981) : (isDark ? Colors.grey[300] : Colors.grey[700]),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                m.targetNode == 'all'
                                    ? 'All Nodes (Cluster)'
                                    : (widget.state.nodes.firstWhere((n) => n.id == m.targetNode, orElse: () => Node(id: m.targetNode, ip: m.targetNode, role: 'node', status: 'active')).ip),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: m.targetNode == 'all' ? const Color(0xFF10B981) : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              m.device.length > 32 ? '${m.device.substring(0, 32)}...' : m.device,
                              style: const TextStyle(fontFamily: 'Courier New', fontSize: 12),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 14),
                              tooltip: 'Copy device path: ${m.device}',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: m.device));
                                _showSnackBar('Copied remote device path to clipboard');
                              },
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: m.mountPoint == '/var/contenedores'
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : (isDark ? Colors.grey[800] : Colors.grey[200]),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                m.mountPoint,
                                style: TextStyle(
                                  fontFamily: 'Courier New',
                                  fontSize: 12,
                                  fontWeight: m.mountPoint == '/var/contenedores' ? FontWeight.bold : FontWeight.normal,
                                  color: m.mountPoint == '/var/contenedores' ? const Color(0xFF10B981) : null,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 14),
                              tooltip: 'Copy mount point',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: m.mountPoint));
                                _showSnackBar('Copied mount point');
                              },
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              m.autoMount ? Icons.check_circle : Icons.cancel_outlined,
                              size: 16,
                              color: m.autoMount ? const Color(0xFF10B981) : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(m.autoMount ? '/etc/fstab' : 'Manual', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      DataCell(
                        Tooltip(
                          message: m.errorMessage ?? (m.status == 'mounted' ? 'Filesystem is live and mounted' : 'Unmounted'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  m.status.toUpperCase(),
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (m.status == 'mounted')
                              IconButton(
                                icon: const Icon(Icons.eject_outlined, size: 18, color: Colors.orange),
                                tooltip: 'Unmount (${m.mountPoint})',
                                onPressed: () async {
                                  try {
                                    _showSnackBar('Unmounting ${m.mountPoint}...');
                                    await ApiService.unmountStorageEntry(m.id);
                                    _showSnackBar('Unmounted successfully');
                                    _loadAllData();
                                  } catch (e) {
                                    _showSnackBar('Failed to unmount: $e', isError: true);
                                  }
                                },
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.play_arrow, size: 18, color: Color(0xFF10B981)),
                                tooltip: 'Mount (${m.mountPoint})',
                                onPressed: () async {
                                  try {
                                    _showSnackBar('Mounting ${m.mountPoint}...');
                                    await ApiService.mountStorageEntry(m.id);
                                    _showSnackBar('Mounted successfully');
                                    _loadAllData();
                                  } catch (e) {
                                    _showSnackBar('Failed to mount: $e', isError: true);
                                  }
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.speed, size: 18, color: Color(0xFF3B82F6)),
                              tooltip: 'Test Connection & Latency',
                              onPressed: () async {
                                try {
                                  _showSnackBar('Testing remote share connectivity...');
                                  final res = await ApiService.testStorageMount({
                                    'name': m.name,
                                    'device': m.device,
                                    'mount_point': m.mountPoint,
                                    'fs_type': m.fsType,
                                    'options': m.options,
                                  });
                                  if (res.success) {
                                    _showSnackBar('✅ Connected! Latency: ${res.latencyMs}ms | Writable: ${res.isWritable ? "Yes" : "Read-Only"}');
                                  } else {
                                    _showSnackBar('❌ Test Failed: ${res.errorMessage}', isError: true);
                                  }
                                } catch (e) {
                                  _showSnackBar('Test error: $e', isError: true);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              tooltip: 'Delete Mount & Clean /etc/fstab',
                              onPressed: () => _showDeleteMountDialog(m),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ── Dialogs: Mount Wizard & fstab Inspector ────────────────────────

  void _showAddMountDialog() {
    String protocol = 'nfs'; // nfs, cifs, s3, custom
    final nameCtrl = TextEditingController(text: 'nfs-var-contenedores');
    final deviceCtrl = TextEditingController(text: '192.168.1.50:/volume1/contenedores');
    final mountPointCtrl = TextEditingController(text: '/var/contenedores');
    final optionsCtrl = TextEditingController(text: 'rw,hard,intr,noatime,rsize=1048576,wsize=1048576,_netdev');
    final descCtrl = TextEditingController(text: 'Primary shared NFS pool for multi-node container mobility');
    bool autoMount = true;
    String selectedTargetNode = 'all';

    // Protocol specifics
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final domainCtrl = TextEditingController();
    final s3EndpointCtrl = TextEditingController(text: 'https://s3.amazonaws.com');
    final s3AccessKeyCtrl = TextEditingController();
    final s3SecretKeyCtrl = TextEditingController();

    TestMountResultModel? testResult;
    bool isTesting = false;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.dns, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text('Add Network Filesystem / Mount'),
                ],
              ),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Protocol Selector
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'nfs', label: Text('NFS v3/v4'), icon: Icon(Icons.storage, size: 16)),
                          ButtonSegment(value: 'glusterfs', label: Text('GlusterFS'), icon: Icon(Icons.hub, size: 16)),
                          ButtonSegment(value: 'cifs', label: Text('Samba / CIFS'), icon: Icon(Icons.folder_shared, size: 16)),
                          ButtonSegment(value: 's3', label: Text('S3 Object'), icon: Icon(Icons.cloud_queue, size: 16)),
                          ButtonSegment(value: 'custom', label: Text('POSIX'), icon: Icon(Icons.settings, size: 16)),
                        ],
                        selected: {protocol},
                        onSelectionChanged: (newSet) {
                          final selected = newSet.first;
                          setDlgState(() {
                            protocol = selected;
                            if (protocol == 'nfs') {
                              nameCtrl.text = 'nfs-var-contenedores';
                              deviceCtrl.text = '192.168.1.50:/volume1/contenedores';
                              mountPointCtrl.text = '/var/contenedores';
                              optionsCtrl.text = 'rw,hard,intr,noatime,rsize=1048576,wsize=1048576,_netdev';
                              descCtrl.text = 'Shared NFS volume for container mobility';
                            } else if (protocol == 'glusterfs') {
                              final defaultVol = _glusterVolumes.isNotEmpty ? _glusterVolumes.first.name : 'gv_contenedores';
                              nameCtrl.text = 'gluster-$defaultVol';
                              deviceCtrl.text = 'localhost:$defaultVol';
                              mountPointCtrl.text = '/var/contenedores';
                              optionsCtrl.text = 'defaults,_netdev';
                              descCtrl.text = 'GlusterFS 3-way replicated cluster volume';
                            } else if (protocol == 'cifs') {
                              nameCtrl.text = 'samba-shared-data';
                              deviceCtrl.text = '//192.168.1.50/docker_share';
                              mountPointCtrl.text = '/var/contenedores';
                              optionsCtrl.text = 'rw,_netdev,uid=1000,gid=1000';
                              descCtrl.text = 'Windows / TrueNAS Samba network share';
                            } else if (protocol == 's3') {
                              nameCtrl.text = 's3-bucket-data';
                              deviceCtrl.text = 's3fs#my-gubernator-bucket';
                              mountPointCtrl.text = '/var/contenedores/s3-data';
                              optionsCtrl.text = '_netdev,allow_other,use_cache=/tmp,uid=1000,gid=1000';
                              descCtrl.text = 'S3 FUSE object storage bucket mount';
                            } else {
                              nameCtrl.text = 'block-device-mount';
                              deviceCtrl.text = '/dev/sdb1';
                              mountPointCtrl.text = '/var/contenedores';
                              optionsCtrl.text = 'defaults,_netdev';
                              descCtrl.text = 'Direct block device mount';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Common Fields
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Mount Identifier / Name', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: selectedTargetNode,
                        decoration: const InputDecoration(
                          labelText: 'Target Centurion Host',
                          helperText: 'Select "All Centurions" for cluster-wide container mobility, or target a specific node.',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.computer, size: 20),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('🌐 All Centurions (Cluster-Wide Swarm Mobility)'),
                          ),
                          ...widget.state.nodes.map(
                            (node) => DropdownMenuItem(
                              value: node.id,
                              child: Text('💻 ${node.role.toUpperCase()}: ${node.ip} (${node.id})'),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setDlgState(() => selectedTargetNode = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: deviceCtrl,
                        decoration: InputDecoration(
                          labelText: protocol == 'nfs'
                              ? 'NFS Server & Export Path'
                              : (protocol == 'cifs' ? 'Samba Share Path' : (protocol == 's3' ? 'S3 Bucket Name (e.g. s3fs#my-bucket)' : 'Device / Source Path')),
                          hintText: protocol == 'nfs' ? '192.168.1.50:/volume1/contenedores' : (protocol == 'cifs' ? '//192.168.1.50/share' : 'my-bucket'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: mountPointCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Destination Mount Point',
                          hintText: '/var/contenedores',
                          helperText: 'Default /var/contenedores enables instant multi-node container mobility.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Protocol Specific Credentials
                      if (protocol == 'cifs') ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: userCtrl,
                                decoration: const InputDecoration(labelText: 'Samba Username', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: passCtrl,
                                obscureText: true,
                                decoration: const InputDecoration(labelText: 'Samba Password', border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: domainCtrl,
                          decoration: const InputDecoration(labelText: 'Workgroup / Domain (optional)', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                      ] else if (protocol == 's3') ...[
                        TextField(
                          controller: s3EndpointCtrl,
                          decoration: const InputDecoration(
                            labelText: 'S3 API Endpoint (AWS, MinIO, Wasabi, Cloudflare R2)',
                            hintText: 'https://s3.amazonaws.com or https://minio.internal.lan:9000',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: s3AccessKeyCtrl,
                                decoration: const InputDecoration(labelText: 'Access Key ID', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: s3SecretKeyCtrl,
                                obscureText: true,
                                decoration: const InputDecoration(labelText: 'Secret Access Key', border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      TextField(
                        controller: optionsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Mount Options String',
                          hintText: 'rw,_netdev,rsize=1048576',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Description / Notes', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),

                      SwitchListTile(
                        title: const Text('Persist in /etc/fstab'),
                        subtitle: const Text('Automatically mount on Centurion boot'),
                        value: autoMount,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setDlgState(() => autoMount = val),
                      ),

                      if (testResult != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: testResult!.success ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: testResult!.success ? Colors.green : Colors.redAccent),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(testResult!.success ? Icons.check_circle : Icons.error, color: testResult!.success ? Colors.green : Colors.redAccent, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    testResult!.success ? 'Test Successful (Latency: ${testResult!.latencyMs}ms)' : 'Mount Test Failed',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: testResult!.success ? Colors.green : Colors.redAccent),
                                  ),
                                ],
                              ),
                              if (testResult!.success) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '• Writable: ${testResult!.isWritable ? "Yes (R/W Verified)" : "Read-Only"}\n• Available Capacity: ${(testResult!.freeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ] else ...[
                                const SizedBox(height: 4),
                                Text(testResult!.errorMessage ?? 'Unknown error', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                              ],
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
                  icon: isTesting ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.speed, size: 16),
                  label: const Text('Test Connection'),
                  onPressed: isTesting
                      ? null
                      : () async {
                          setDlgState(() => isTesting = true);
                          try {
                            String fst = protocol;
                            if (protocol == 's3') fst = 'fuse.s3fs';
                            final res = await ApiService.testStorageMount({
                              'name': nameCtrl.text.trim(),
                              'device': deviceCtrl.text.trim(),
                              'mount_point': mountPointCtrl.text.trim(),
                              'fs_type': fst,
                              'options': optionsCtrl.text.trim(),
                              'username': userCtrl.text.trim(),
                              'password': passCtrl.text.trim(),
                              'domain': domainCtrl.text.trim(),
                              's3_endpoint': s3EndpointCtrl.text.trim(),
                              's3_access_key': s3AccessKeyCtrl.text.trim(),
                              's3_secret_key': s3SecretKeyCtrl.text.trim(),
                            });
                            setDlgState(() {
                              testResult = res;
                              isTesting = false;
                            });
                          } catch (e) {
                            setDlgState(() {
                              testResult = TestMountResultModel(success: false, errorMessage: e.toString());
                              isTesting = false;
                            });
                          }
                        },
                ),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  icon: isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save, size: 16),
                  label: const Text('Save & Mount'),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDlgState(() => isSaving = true);
                          try {
                            String fst = protocol;
                            if (protocol == 's3') fst = 'fuse.s3fs';
                            await ApiService.createStorageMount({
                              'name': nameCtrl.text.trim(),
                              'device': deviceCtrl.text.trim(),
                              'mount_point': mountPointCtrl.text.trim(),
                              'fs_type': fst,
                              'options': optionsCtrl.text.trim(),
                              'target_node': selectedTargetNode,
                              'auto_mount': autoMount,
                              'description': descCtrl.text.trim(),
                              'username': userCtrl.text.trim(),
                              'password': passCtrl.text.trim(),
                              'domain': domainCtrl.text.trim(),
                              's3_endpoint': s3EndpointCtrl.text.trim(),
                              's3_access_key': s3AccessKeyCtrl.text.trim(),
                              's3_secret_key': s3SecretKeyCtrl.text.trim(),
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showSnackBar('✅ Network mount created and mounted successfully!');
                            _loadAllData();
                          } catch (e) {
                            setDlgState(() => isSaving = false);
                            _showSnackBar('❌ Failed to create mount: $e', isError: true);
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

  void _showMountAllDialog() {
    String selectedNode = 'all';
    bool isExecuting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.sync, color: Color(0xFF3B82F6)),
                  SizedBox(width: 8),
                  Text('Execute mount -a (Mount All Entries)'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select target Centurion host(s) on which to execute "mount -a":'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedNode,
                      decoration: const InputDecoration(
                        labelText: 'Target Centurion Host',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.computer, size: 20),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('🌐 All Centurions (Execute across whole cluster)'),
                        ),
                        ...widget.state.nodes.map(
                          (node) => DropdownMenuItem(
                            value: node.id,
                            child: Text('💻 ${node.role.toUpperCase()}: ${node.ip} (${node.id})'),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => selectedNode = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This executes "mount -a" to reload and mount all filesystems described in /etc/fstab on the selected host(s).',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                  icon: isExecuting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Execute mount -a'),
                  onPressed: isExecuting
                      ? null
                      : () async {
                          setDlgState(() => isExecuting = true);
                          try {
                            final out = await ApiService.mountAllStorageEntries(targetNode: selectedNode);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showMountAllResultDialog(out);
                            _loadAllData();
                          } catch (e) {
                            setDlgState(() => isExecuting = false);
                            _showSnackBar('Failed to execute mount -a: $e', isError: true);
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

  void _showMountAllResultDialog(String output) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('mount -a Execution Results'),
            ],
          ),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: SelectableText(
                output,
                style: const TextStyle(fontFamily: 'Courier New', fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        );
      },
    );
  }

  void _showFstabViewerDialog() {
    String selectedNode = 'all';
    final contentCtrl = TextEditingController();
    bool isLoading = true;
    bool isSaving = false;
    String filePath = '/etc/fstab';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            void loadFstabForNode(String node) async {
              setDlgState(() => isLoading = true);
              try {
                final fstabData = await ApiService.fetchRawFstab(node: node);
                filePath = fstabData['path'] ?? '/etc/fstab';
                contentCtrl.text = fstabData['raw'] ?? '';
                setDlgState(() => isLoading = false);
              } catch (e) {
                setDlgState(() => isLoading = false);
                _showSnackBar('Failed to read /etc/fstab from $node: $e', isError: true);
              }
            }

            // Initial load
            if (isLoading && contentCtrl.text.isEmpty) {
              loadFstabForNode(selectedNode);
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.tune, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  const Text('Host Configuration Editor: /etc/fstab'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Target: $selectedNode',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 750,
                height: 520,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Node selector bar
                    Row(
                      children: [
                        const Text('Centurion Node:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedNode,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('🌐 All Centurions (Sync across all cluster nodes)'),
                              ),
                              ...widget.state.nodes.map(
                                (node) => DropdownMenuItem(
                                  value: node.id,
                                  child: Text('💻 ${node.role.toUpperCase()}: ${node.ip} (${node.id})'),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                selectedNode = val;
                                loadFstabForNode(val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: 'Reload from host',
                          onPressed: () => loadFstabForNode(selectedNode),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Live configuration file path: $filePath (Automatic timestamped backups generated on save)',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
                              ),
                              child: TextField(
                                controller: contentCtrl,
                                maxLines: null,
                                expands: true,
                                style: TextStyle(
                                  fontFamily: 'Courier New',
                                  fontSize: 12.5,
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(4),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Content'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: contentCtrl.text));
                    _showSnackBar('Copied /etc/fstab content to clipboard');
                  },
                ),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  icon: isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save, size: 16),
                  label: Text('Save & Apply to ${selectedNode == "all" ? "All Nodes" : selectedNode}'),
                  onPressed: isSaving || isLoading
                      ? null
                      : () async {
                          setDlgState(() => isSaving = true);
                          try {
                            final msg = await ApiService.saveRawFstab(contentCtrl.text, node: selectedNode);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showSnackBar('✅ $msg');
                            _loadAllData();
                          } catch (e) {
                            setDlgState(() => isSaving = false);
                            _showSnackBar('❌ Failed to save /etc/fstab: $e', isError: true);
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


  void _showDeleteMountDialog(StorageMountModel m) {
    final isGluster = m.fsType == 'glusterfs' || m.name.contains('gluster') || m.device.contains('localhost:');
    String glusterVolName = m.name.replaceFirst('gluster-', '');
    if (m.device.startsWith('localhost:')) {
      glusterVolName = m.device.replaceFirst('localhost:', '');
    }
    bool deleteUnderlyingGluster = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(isGluster ? Icons.warning_amber_rounded : Icons.delete_outline,
                      color: isGluster ? Colors.orange : Colors.redAccent),
                  const SizedBox(width: 8),
                  Text(isGluster ? 'Delete GlusterFS Mount: ${m.name}' : 'Delete Mount Entry: ${m.name}'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you sure you want to delete mount "${m.name}" (${m.mountPoint}) on target hosts (${m.targetNode})?\n\nThis will unmount the filesystem and remove its entry from /etc/fstab.',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (isGluster) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: deleteUnderlyingGluster,
                          activeColor: Colors.redAccent,
                          title: Text(
                            'Also permanently STOP & DELETE underlying GlusterFS volume "$glusterVolName"',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.redAccent),
                          ),
                          subtitle: const Text(
                            'If unchecked, the volume stays intact in GlusterFS and only the fstab mount point is unmounted and removed.',
                            style: TextStyle(fontSize: 11),
                          ),
                          onChanged: (val) => setDlgState(() => deleteUnderlyingGluster = val ?? false),
                        ),
                      ),
                    ],
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
                      await ApiService.deleteStorageMount(m.id, deleteGluster: deleteUnderlyingGluster);
                      _showSnackBar(deleteUnderlyingGluster
                          ? 'Mount and GlusterFS volume "$glusterVolName" deleted successfully'
                          : 'Mount removed from fstab');
                      _loadAllData();
                    } catch (e) {
                      _showSnackBar('Failed to delete mount: $e', isError: true);
                    }
                  },
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

}

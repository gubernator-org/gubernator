part of '../legions_page.dart';

extension _LegionsUnmanagedPart on _LegionsPageState {
  Future<void> _loadUnmanagedContainers() async {
    if (_loadingUnmanaged) return;
    _setStateSafe(() {
      _loadingUnmanaged = true;
      _unmanagedError = null;
    });
    try {
      final data = await ApiService.fetchUnmanagedContainers();
      final groups = (data['groups'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final containers = (data['containers'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final nodeErrors = data['node_errors'] is Map
          ? Map<String, String>.from(
              (data['node_errors'] as Map)
                  .map((k, v) => MapEntry(k.toString(), v.toString())),
            )
          : <String, String>{};
      _setStateSafe(() {
        _unmanagedGroups = groups;
        _unmanagedContainers = containers;
        _unmanagedNodeErrors = nodeErrors;
        _unmanagedLoadedOnce = true;
        _loadingUnmanaged = false;
        // Prune selected keys that no longer exist
        final validKeys = containers
            .map((c) => '${c['node_id']}::${c['name']}')
            .toSet();
        _selectedUnmanagedKeys.removeWhere((k) => !validKeys.contains(k));
      });
    } catch (e) {
      _setStateSafe(() {
        _loadingUnmanaged = false;
        _unmanagedLoadedOnce = true;
        _unmanagedError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _runUnmanagedContainerAction(
    String nodeId,
    String containerName,
    String action,
  ) async {
    final key = '$nodeId::$containerName';
    _setStateSafe(() => _processingUnmanagedKeys.add(key));
    try {
      await ApiService.unmanagedContainerAction(
        nodeId: nodeId,
        containerName: containerName,
        action: action,
      );
      _showSnackBar('Action "$action" succeeded on "$containerName".');
      await _loadUnmanagedContainers();
    } catch (e) {
      _showSnackBar(
        'Action "$action" failed on "$containerName": ${e.toString().replaceFirst('Exception: ', '')}',
        isError: true,
      );
    } finally {
      _setStateSafe(() => _processingUnmanagedKeys.remove(key));
    }
  }

  Future<void> _openAdoptDialog({
    required String nodeId,
    required List<String> containerNames,
    required String initialStackName,
    String? hostConfigFile,
  }) async {
    if (containerNames.isEmpty) return;

    final adopted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AdoptStackDialog(
        nodeId: nodeId,
        containerNames: containerNames,
        initialStackName: initialStackName,
        hostConfigFile: hostConfigFile,
      ),
    );

    if (adopted == true) {
      widget.onRefresh();
      await _loadUnmanagedContainers();
      widget.onSwitchToManaged?.call();
    }
  }

  void _adoptSelectedUnmanaged() {
    if (_selectedUnmanagedKeys.isEmpty) return;
    final selected = _unmanagedContainers
        .where((c) => _selectedUnmanagedKeys.contains('${c['node_id']}::${c['name']}'))
        .toList();
    if (selected.isEmpty) return;

    final nodeIds = selected.map((c) => (c['node_id'] ?? '').toString()).toSet();
    if (nodeIds.length > 1) {
      _showSnackBar(
        'Select containers from a single Centurion node to adopt into one stack.',
        isError: true,
      );
      return;
    }

    final nodeId = nodeIds.first;
    final names = selected.map((c) => (c['name'] ?? '').toString()).toList();
    final firstProj = (selected.first['compose_project'] ?? '').toString();
    final initialName = firstProj.isNotEmpty
        ? firstProj
        : (names.length == 1 ? names.first : 'adopted-stack');
    final hostCfg = (selected.first['compose_config_files'] ?? '').toString();

    _openAdoptDialog(
      nodeId: nodeId,
      containerNames: names,
      initialStackName: initialName,
      hostConfigFile: hostCfg.isNotEmpty ? hostCfg : null,
    );
  }

  Widget _buildUnmanagedView(ThemeData theme, bool isDark) {
    if (!_unmanagedLoadedOnce && !_loadingUnmanaged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_unmanagedLoadedOnce && !_loadingUnmanaged) {
          _loadUnmanagedContainers();
        }
      });
    }

    final query = _unmanagedSearch.trim().toLowerCase();
    final filteredGroups = _unmanagedGroups.where((g) {
      if (_unmanagedNodeFilter != 'ALL' &&
          (g['node_id'] ?? '').toString() != _unmanagedNodeFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final gName = (g['group_name'] ?? '').toString().toLowerCase();
      if (gName.contains(query)) return true;
      final cs = (g['containers'] as List? ?? []);
      return cs.any((c) {
        final m = c as Map;
        return (m['name'] ?? '').toString().toLowerCase().contains(query) ||
            (m['image'] ?? '').toString().toLowerCase().contains(query);
      });
    }).toList();

    final composeProjectCount = _unmanagedGroups
        .where((g) => g['source_type'] == 'compose')
        .length;
    final standaloneCount = _unmanagedContainers
        .where((c) => c['source_type'] != 'compose')
        .length;
    final runningCount = _unmanagedContainers
        .where((c) => (c['state'] ?? '').toString().toLowerCase() == 'running')
        .length;

    final availableNodes = <String>{
      'ALL',
      ...widget.state.nodes.map((n) => n.id),
      ..._unmanagedContainers.map((c) => (c['node_id'] ?? '').toString()),
    }..removeWhere((e) => e.isEmpty);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header Banner ─────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.travel_explore,
                  color: Color(0xFFF97316),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unmanaged & Discovered Containers',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pre-existing Docker containers running outside Gubernator. Inspect, reverse-engineer docker-compose.yml, and adopt with zero downtime.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedUnmanagedKeys.isNotEmpty) ...[
                FilledButton.icon(
                  onPressed: _adoptSelectedUnmanaged,
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: Text(
                    'Adopt Selected (${_selectedUnmanagedKeys.length})',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              FilledButton.tonalIcon(
                onPressed: _loadingUnmanaged ? null : _loadUnmanagedContainers,
                icon: _loadingUnmanaged
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.radar, size: 18),
                label: const Text('Scan Cluster'),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ─── Summary KPI Row ───────────────────────────────────
          Row(
            children: [
              _unmanagedKpiCard(
                theme,
                isDark,
                'Discovered Containers',
                '${_unmanagedContainers.length}',
                '$runningCount running',
                Icons.view_in_ar_outlined,
                const Color(0xFFF97316),
              ),
              const SizedBox(width: 12),
              _unmanagedKpiCard(
                theme,
                isDark,
                'Compose Projects',
                '$composeProjectCount',
                'Auto-grouped by label',
                Icons.layers_outlined,
                const Color(0xFF6366F1),
              ),
              const SizedBox(width: 12),
              _unmanagedKpiCard(
                theme,
                isDark,
                'Standalone (docker run)',
                '$standaloneCount',
                'Ready to adopt',
                Icons.terminal,
                const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ─── Search & Node Filter Bar ──────────────────────────
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Filter by container, image, or compose project...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (v) => _setStateSafe(() => _unmanagedSearch = v),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: availableNodes.contains(_unmanagedNodeFilter)
                      ? _unmanagedNodeFilter
                      : 'ALL',
                  decoration: InputDecoration(
                    labelText: 'Centurion Node',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: availableNodes
                      .map((id) => DropdownMenuItem(
                            value: id,
                            child: Text(
                              id == 'ALL' ? 'All Centurions' : id,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      _setStateSafe(() => _unmanagedNodeFilter = v ?? 'ALL'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ─── Node Errors Banner (if any worker unreachable) ────
          if (_unmanagedNodeErrors.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.amber, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Some nodes could not be scanned: ${_unmanagedNodeErrors.entries.map((e) => '${e.key} (${e.value})').join(' · ')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ─── Content Area ──────────────────────────────────────
          Expanded(
            child: _loadingUnmanaged && !_unmanagedLoadedOnce
                ? const Center(child: CircularProgressIndicator())
                : _unmanagedError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: theme.colorScheme.error),
                            const SizedBox(height: 12),
                            Text('Failed to scan cluster: $_unmanagedError'),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _loadUnmanagedContainers,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry Scan'),
                            ),
                          ],
                        ),
                      )
                    : filteredGroups.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_outlined,
                                  size: 56,
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.75),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'All containers are managed by Gubernator',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'No unmanaged external containers were found on the selected Centurions.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredGroups.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 14),
                            itemBuilder: (ctx, idx) => _buildUnmanagedGroupCard(
                              filteredGroups[idx],
                              theme,
                              isDark,
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _unmanagedKpiCard(
    ThemeData theme,
    bool isDark,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnmanagedGroupCard(
    Map<String, dynamic> group,
    ThemeData theme,
    bool isDark,
  ) {
    final groupName = (group['group_name'] ?? 'standalone').toString();
    final nodeId = (group['node_id'] ?? 'node-local-manager').toString();
    final nodeIp = (group['node_ip'] ?? '').toString();
    final isCompose = group['source_type'] == 'compose';
    final hostConfig = (group['compose_config_files'] ?? '').toString();
    final containers = (group['containers'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final allNames =
        containers.map((c) => (c['name'] ?? '').toString()).toList();
    final runningCount = group['running_count'] ?? 0;
    final totalCount = group['total_count'] ?? containers.length;

    final accentColor =
        isCompose ? const Color(0xFF6366F1) : const Color(0xFFF59E0B);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.09)
              : Colors.grey.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Group Header
            Row(
              children: [
                Icon(
                  isCompose ? Icons.layers : Icons.terminal,
                  color: accentColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  isCompose ? groupName : 'Standalone Containers',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isCompose ? 'COMPOSE PROJECT' : 'DOCKER RUN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    nodeIp.isNotEmpty ? '$nodeId ($nodeIp)' : nodeId,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$runningCount/$totalCount running',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: runningCount > 0
                        ? const Color(0xFF10B981)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _openAdoptDialog(
                    nodeId: nodeId,
                    containerNames: allNames,
                    initialStackName: isCompose
                        ? groupName
                        : (allNames.length == 1
                            ? allNames.first
                            : 'adopted-$nodeId'),
                    hostConfigFile: hostConfig.isNotEmpty ? hostConfig : null,
                  ),
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: Text(
                    isCompose ? 'Adopt Project as Stack' : 'Adopt All as Stack',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
            if (hostConfig.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.description_outlined,
                      size: 13,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Host compose file detected: $hostConfig',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'Courier New',
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 6),

            // Containers List
            for (final c in containers)
              _buildUnmanagedContainerRow(c, theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildUnmanagedContainerRow(
    Map<String, dynamic> c,
    ThemeData theme,
    bool isDark,
  ) {
    final name = (c['name'] ?? '').toString();
    final nodeId = (c['node_id'] ?? 'node-local-manager').toString();
    final image = (c['image'] ?? '').toString();
    final state = (c['state'] ?? '').toString().toLowerCase();
    final status = (c['status'] ?? '').toString();
    final ports = (c['ports'] ?? '').toString();
    final hostCfg = (c['compose_config_files'] ?? '').toString();
    final isRunning = state == 'running';
    final key = '$nodeId::$name';
    final isChecked = _selectedUnmanagedKeys.contains(key);
    final isBusy = _processingUnmanagedKeys.contains(key);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Checkbox(
            value: isChecked,
            onChanged: (v) {
              _setStateSafe(() {
                if (v == true) {
                  _selectedUnmanagedKeys.add(key);
                } else {
                  _selectedUnmanagedKeys.remove(key);
                }
              });
            },
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isRunning ? const Color(0xFF10B981) : Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  image,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'Courier New',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color: isRunning
                        ? const Color(0xFF10B981)
                        : Colors.redAccent,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (ports.isNotEmpty)
                  Text(
                    ports,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (isBusy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            if (!isRunning)
              IconButton(
                tooltip: 'Start container',
                icon: const Icon(Icons.play_arrow,
                    size: 19, color: Color(0xFF10B981)),
                onPressed: () =>
                    _runUnmanagedContainerAction(nodeId, name, 'start'),
              )
            else
              IconButton(
                tooltip: 'Stop container',
                icon: const Icon(Icons.stop,
                    size: 19, color: Color(0xFFF59E0B)),
                onPressed: () =>
                    _runUnmanagedContainerAction(nodeId, name, 'stop'),
              ),
            IconButton(
              tooltip: 'Restart container',
              icon: const Icon(Icons.restart_alt, size: 19),
              onPressed: () =>
                  _runUnmanagedContainerAction(nodeId, name, 'restart'),
            ),
            const SizedBox(width: 4),
            OutlinedButton.icon(
              onPressed: () => _openAdoptDialog(
                nodeId: nodeId,
                containerNames: [name],
                initialStackName: name,
                hostConfigFile: hostCfg.isNotEmpty ? hostCfg : null,
              ),
              icon: const Icon(Icons.add_task, size: 15),
              label: const Text('Adopt'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Interactive dialog that reverse-engineers docker-compose.yml via `docker inspect`
/// and lets the user review/edit before adopting containers into a Gubernator Stack.
class _AdoptStackDialog extends StatefulWidget {
  final String nodeId;
  final List<String> containerNames;
  final String initialStackName;
  final String? hostConfigFile;

  const _AdoptStackDialog({
    required this.nodeId,
    required this.containerNames,
    required this.initialStackName,
    this.hostConfigFile,
  });

  @override
  State<_AdoptStackDialog> createState() => _AdoptStackDialogState();
}

class _AdoptStackDialogState extends State<_AdoptStackDialog> {
  late final TextEditingController _nameController;
  final TextEditingController _yamlController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  bool _preferHostFile = false;
  String _source = 'inspect';
  String? _detectedHostFile;
  List<String> _warnings = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialStackName);
    _detectedHostFile = widget.hostConfigFile;
    _generateCompose();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yamlController.dispose();
    super.dispose();
  }

  Future<void> _generateCompose() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.generateUnmanagedCompose(
        nodeId: widget.nodeId,
        containerNames: widget.containerNames,
        stackName: _nameController.text.trim(),
        preferHostFile: _preferHostFile,
      );
      if (!mounted) return;
      setState(() {
        _yamlController.text = (res['compose_yaml'] ?? '').toString();
        _source = (res['source'] ?? 'inspect').toString();
        final cfg = (res['config_file_path'] ?? '').toString();
        if (cfg.isNotEmpty) _detectedHostFile = cfg;
        _warnings = (res['warnings'] as List? ?? [])
            .map((e) => e.toString())
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _adopt({required bool redeployAfter}) async {
    final stackName = _nameController.text.trim();
    final composeYaml = _yamlController.text.trim();
    if (stackName.isEmpty) {
      setState(() => _error = 'Please enter a Stack Name.');
      return;
    }
    if (composeYaml.isEmpty) {
      setState(() => _error = 'Compose YAML cannot be empty.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final res = await ApiService.adoptUnmanagedStack(
        stackName: stackName,
        nodeId: widget.nodeId,
        containerNames: widget.containerNames,
        composeYaml: composeYaml,
      );
      final stackId = (res['stack_id'] ?? '').toString();
      if (redeployAfter && stackId.isNotEmpty) {
        await ApiService.redeployStack(stackId);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 740),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.auto_fix_high,
                      color: Color(0xFFF97316), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adopt Containers as Managed Stack',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Node: ${widget.nodeId} · ${widget.containerNames.length} container(s): ${widget.containerNames.join(', ')}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.65),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stack Name + Host File Toggle
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Gubernator Stack Name',
                        prefixIcon: const Icon(Icons.layers_outlined, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (_source == 'host-file'
                              ? const Color(0xFF10B981)
                              : const Color(0xFF6366F1))
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _source == 'host-file'
                          ? 'Source: Host Compose File'
                          : 'Source: docker inspect',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _source == 'host-file'
                            ? const Color(0xFF10B981)
                            : const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ],
              ),

              if (_detectedHostFile != null && _detectedHostFile!.isNotEmpty) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Use original host docker-compose.yml instead of docker inspect',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    _detectedHostFile!,
                    style: const TextStyle(
                        fontSize: 11, fontFamily: 'Courier New'),
                  ),
                  value: _preferHostFile,
                  onChanged: _loading
                      ? null
                      : (v) {
                          setState(() => _preferHostFile = v);
                          _generateCompose();
                        },
                ),
              ],

              if (_warnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _warnings.join(' '),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // YAML Editor
              Expanded(
                child: _loading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text(
                                'Inspecting containers and reconstructing docker-compose.yml...'),
                          ],
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0B1120)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.25),
                          ),
                        ),
                        child: TextField(
                          controller: _yamlController,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(
                            fontFamily: 'Courier New',
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.all(14),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _loading
                        ? null
                        : () async {
                            await ClipboardService.copy(_yamlController.text);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Compose YAML copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy YAML'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: (_loading || _submitting)
                        ? null
                        : () => _adopt(redeployAfter: true),
                    icon: const Icon(Icons.rocket_launch_outlined, size: 16),
                    label: const Text('Adopt & Redeploy'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: (_loading || _submitting)
                        ? null
                        : () => _adopt(redeployAfter: false),
                    icon: _submitting
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified, size: 17),
                    label: const Text('Adopt (Zero-Downtime)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

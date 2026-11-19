part of '../legions_page.dart';

/// Data model for a single ingress route displayed in the Cluster Topology canvas.
class _TopoIngressNode {
  final String id;
  final String host;
  final String upstream;
  final String targetService;
  final String targetStackId;
  final String nodeId;
  final bool isTls;
  Rect rect = Rect.zero;

  _TopoIngressNode({
    required this.id,
    required this.host,
    required this.upstream,
    required this.targetService,
    required this.targetStackId,
    required this.nodeId,
    required this.isTls,
  });
}

/// Data model for a container card rendered inside a Centurion host box.
class _TopoContainerNode {
  final String id;
  final String name;
  final String serviceName;
  final String stackId;
  final String stackName;
  final String nodeId;
  final String image;
  final String status;
  final String ip;
  final List<String> ports;
  final double cpuPercent;
  final int memUsedBytes;
  final bool isBase;
  final bool isUnmanaged;
  Rect rect = Rect.zero;

  _TopoContainerNode({
    required this.id,
    required this.name,
    required this.serviceName,
    required this.stackId,
    required this.stackName,
    required this.nodeId,
    required this.image,
    required this.status,
    required this.ip,
    required this.ports,
    required this.cpuPercent,
    required this.memUsedBytes,
    this.isBase = false,
    this.isUnmanaged = false,
  });

  bool get isRunning => status.toLowerCase() == 'running';
}

/// Data model for a Centurion host container box on the canvas.
class _TopoHostBox {
  final Node node;
  final List<_TopoContainerNode> containers;
  Rect rect = Rect.zero;

  _TopoHostBox({
    required this.node,
    required this.containers,
  });
}

/// Directed edge between two topology nodes (Ingress -> Container or Container -> Container).
class _TopoEdge {
  final String fromId;
  final String toId;
  final Offset from;
  final Offset to;
  final Color color;
  final String label;
  final bool dashed;
  final String kind; // 'ingress', 'service', 'cross-host'

  const _TopoEdge({
    required this.fromId,
    required this.toId,
    required this.from,
    required this.to,
    required this.color,
    this.label = '',
    this.dashed = false,
    required this.kind,
  });
}

extension _LegionsTopologyPart on _LegionsPageState {
  Widget _buildTopologyView(ThemeData theme, bool isDark) {
    return _ClusterTopologyDashboard(
      state: widget.state,
      isBaseStackFn: _isBaseStack,
      onRefresh: widget.onRefresh,
      onViewContainerLogs: widget.onViewContainerLogs,
      onViewStackContainers: widget.onViewStackContainers,
    );
  }
}

class _ClusterTopologyDashboard extends StatefulWidget {
  final DashboardState state;
  final bool Function(StackModel) isBaseStackFn;
  final VoidCallback onRefresh;
  final ValueChanged<String>? onViewContainerLogs;
  final ValueChanged<String>? onViewStackContainers;

  const _ClusterTopologyDashboard({
    required this.state,
    required this.isBaseStackFn,
    required this.onRefresh,
    this.onViewContainerLogs,
    this.onViewStackContainers,
  });

  @override
  State<_ClusterTopologyDashboard> createState() =>
      _ClusterTopologyDashboardState();
}

class _ClusterTopologyDashboardState extends State<_ClusterTopologyDashboard> {
  final TransformationController _transformController =
      TransformationController();

  bool _showBaseStacks = false;
  bool _showUnmanaged = true;
  bool _showServiceLinks = true;
  String _selectedStackFilter = 'ALL';
  String? _selectedNodeId; // Selected ingress or container ID for highlighting
  double _currentScale = 1.0;

  bool _loadingExtras = false;
  List<Map<String, dynamic>> _caddyRoutes = [];
  List<Map<String, dynamic>> _unmanagedContainers = [];

  @override
  void initState() {
    super.initState();
    _loadTopologyExtras();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadTopologyExtras() async {
    if (_loadingExtras) return;
    setState(() => _loadingExtras = true);
    try {
      final results = await Future.wait([
        ApiService.fetchCaddyRoutes().catchError((_) => <dynamic>[]),
        ApiService.fetchUnmanagedContainers()
            .catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      final routesRaw = results[0] as List<dynamic>;
      final unmanagedRaw = results[1] as Map<String, dynamic>;
      setState(() {
        _caddyRoutes = routesRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _unmanagedContainers = (unmanagedRaw['containers'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loadingExtras = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingExtras = false);
    }
  }

  void _zoomBy(double factor) {
    final next = (_currentScale * factor).clamp(0.45, 2.0);
    setState(() {
      _currentScale = next;
      _transformController.value = Matrix4.identity()..scale(next);
    });
  }

  void _resetZoom() {
    setState(() {
      _currentScale = 1.0;
      _transformController.value = Matrix4.identity();
    });
  }

  /// Parses `depends_on` and service-to-service references from a stack's compose YAML.
  List<(String, String)> _extractServiceDependencies(
    StackModel stack,
    List<Service> stackServices,
  ) {
    final deps = <(String, String)>[];
    if (stack.rawComposeFile.trim().isEmpty || stackServices.length < 2) {
      return deps;
    }

    final serviceNames = stackServices.map((s) => s.name).toSet();
    final lines = stack.rawComposeFile.split('\n');

    String? currentService;
    bool inServices = false;
    bool inDependsOn = false;
    int serviceIndent = -1;
    int dependsIndent = -1;

    for (final rawLine in lines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final indent = rawLine.length - rawLine.trimLeft().length;

      if (indent == 0) {
        inServices = trimmed == 'services:';
        currentService = null;
        inDependsOn = false;
        serviceIndent = -1;
        continue;
      }
      if (!inServices) continue;

      if (serviceIndent == -1 && trimmed.endsWith(':')) {
        final candidate = trimmed.substring(0, trimmed.length - 1).trim();
        if (serviceNames.contains(candidate)) {
          serviceIndent = indent;
          currentService = candidate;
          inDependsOn = false;
          continue;
        }
      } else if (indent == serviceIndent && trimmed.endsWith(':')) {
        final candidate = trimmed.substring(0, trimmed.length - 1).trim();
        currentService = serviceNames.contains(candidate) ? candidate : null;
        inDependsOn = false;
        continue;
      }

      if (currentService == null) continue;

      if (trimmed.startsWith('depends_on:')) {
        inDependsOn = true;
        dependsIndent = indent;
        continue;
      }

      if (inDependsOn) {
        if (indent <= dependsIndent) {
          inDependsOn = false;
        } else {
          var target = trimmed;
          if (target.startsWith('-')) {
            target = target.substring(1).trim();
          } else if (target.endsWith(':')) {
            target = target.substring(0, target.length - 1).trim();
          }
          if (serviceNames.contains(target) && target != currentService) {
            deps.add((currentService, target));
          }
        }
      }

      // Also detect URL/host references inside environment lines (e.g. http://api:5678 or REDIS_HOST=cache)
      for (final other in serviceNames) {
        if (other == currentService || other.length < 2) continue;
        final pattern = RegExp(
          '(://|=)${RegExp.escape(other)}(:|/|\\s|\$)',
          caseSensitive: false,
        );
        if (pattern.hasMatch(trimmed)) {
          deps.add((currentService, other));
        }
      }
    }

    // Deduplicate
    final seen = <String>{};
    return deps.where((e) => seen.add('${e.$1}->${e.$2}')).toList();
  }

  /// Extracts `ingress.host` or `gbnt.caddy.host` rules from compose YAML & service constraints.
  List<_TopoIngressNode> _collectIngressNodes(
    List<StackModel> visibleStacks,
    List<Service> allServices,
    List<_TopoContainerNode> allContainers,
  ) {
    final nodes = <_TopoIngressNode>[];
    final seenHosts = <String>{};

    // 1. Live Caddy routes from API
    for (int i = 0; i < _caddyRoutes.length; i++) {
      final r = _caddyRoutes[i];
      final host = (r['host'] ?? r['domain'] ?? r['match'] ?? '').toString().trim();
      final upstream = (r['upstream'] ?? r['dial'] ?? r['target'] ?? '').toString().trim();
      if (host.isEmpty || host == ':80' || host == ':443') continue;
      if (!seenHosts.add(host.toLowerCase())) continue;

      // Try matching upstream to a visible container (by IP, port, or service/container name)
      String matchedSvc = '';
      String matchedStack = '';
      String matchedNode = '';
      for (final c in allContainers) {
        final upstreamLower = upstream.toLowerCase();
        final matchesIp = c.ip.isNotEmpty && upstreamLower.contains(c.ip.toLowerCase());
        final matchesName = upstreamLower.contains(c.name.toLowerCase()) ||
            upstreamLower.contains(c.serviceName.toLowerCase());
        final matchesPort = c.ports.any((p) {
          final hostPort = p.split(':').first.trim();
          return hostPort.isNotEmpty && upstreamLower.endsWith(':$hostPort');
        });
        if (matchesIp || matchesName || matchesPort) {
          matchedSvc = c.id;
          matchedStack = c.stackId;
          matchedNode = c.nodeId;
          break;
        }
      }

      if (_selectedStackFilter != 'ALL' &&
          matchedStack.isNotEmpty &&
          matchedStack != _selectedStackFilter) {
        continue;
      }

      nodes.add(_TopoIngressNode(
        id: 'ingress-caddy-$i',
        host: host,
        upstream: upstream.isNotEmpty ? upstream : 'caddy-proxy',
        targetService: matchedSvc,
        targetStackId: matchedStack,
        nodeId: matchedNode,
        isTls: !host.startsWith('http://'),
      ));
    }

    // 2. Compose labels (`ingress.host` / `gbnt.caddy.host`) on visible stacks
    final hostRegex = RegExp(
      r'''(?:ingress\.host|gbnt\.caddy\.host)\s*[:=]\s*["']?([a-zA-Z0-9._:-]+)["']?''',
    );
    for (final stack in visibleStacks) {
      final matches = hostRegex.allMatches(stack.rawComposeFile);
      for (final m in matches) {
        final host = (m.group(1) ?? '').trim();
        if (host.isEmpty || !seenHosts.add(host.toLowerCase())) continue;

        final targetContainer = allContainers.firstWhere(
          (c) => c.stackId == stack.id,
          orElse: () => _TopoContainerNode(
            id: '',
            name: '',
            serviceName: '',
            stackId: stack.id,
            stackName: stack.name,
            nodeId: stack.nodeId,
            image: '',
            status: '',
            ip: '',
            ports: const [],
            cpuPercent: 0,
            memUsedBytes: 0,
          ),
        );

        nodes.add(_TopoIngressNode(
          id: 'ingress-label-${stack.id}-$host',
          host: host,
          upstream: targetContainer.ports.isNotEmpty
              ? targetContainer.ports.first
              : targetContainer.name,
          targetService: targetContainer.id,
          targetStackId: stack.id,
          nodeId: targetContainer.nodeId,
          isTls: true,
        ));
      }
    }

    return nodes;
  }

  Future<void> _openHostUrl(String host) async {
    var clean = host.trim();
    if (clean.isEmpty) return;
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'https://$clean';
    }
    final uri = Uri.tryParse(clean);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 1. Filter visible stacks
    final allStacks = widget.state.stacks;
    final stackById = {for (final s in allStacks) s.id: s};
    final serviceById = {for (final s in widget.state.services) s.id: s};

    final visibleStacks = allStacks.where((s) {
      if (!_showBaseStacks && widget.isBaseStackFn(s)) return false;
      if (_selectedStackFilter != 'ALL' && s.id != _selectedStackFilter) {
        return false;
      }
      return true;
    }).toList();
    final visibleStackIds = visibleStacks.map((s) => s.id).toSet();

    // 2. Build container nodes from managed tasks
    final containers = <_TopoContainerNode>[];
    for (final task in widget.state.tasks) {
      final svc = serviceById[task.serviceId];
      if (svc == null) continue;
      final stack = stackById[svc.stackId];
      if (stack == null) continue;
      if (!visibleStackIds.contains(stack.id)) continue;

      containers.add(_TopoContainerNode(
        id: 'task-${task.id}',
        name: task.containerName.isNotEmpty ? task.containerName : svc.name,
        serviceName: svc.name,
        stackId: stack.id,
        stackName: stack.name,
        nodeId: task.nodeId.isNotEmpty ? task.nodeId : 'node-local-manager',
        image: svc.image,
        status: task.status,
        ip: task.containerIp,
        ports: svc.ports,
        cpuPercent: task.cpuPercent,
        memUsedBytes: task.memUsedBytes,
        isBase: widget.isBaseStackFn(stack),
      ));
    }

    // 3. Optionally include Unmanaged / Discovered containers
    if (_showUnmanaged && _selectedStackFilter == 'ALL') {
      for (final u in _unmanagedContainers) {
        final name = (u['name'] ?? '').toString();
        final nodeId = (u['node_id'] ?? 'node-local-manager').toString();
        final groupName = (u['group_name'] ?? 'standalone').toString();
        final portsStr = (u['ports'] ?? '').toString();
        containers.add(_TopoContainerNode(
          id: 'unmanaged-$nodeId-$name',
          name: name,
          serviceName: (u['compose_service'] ?? name).toString(),
          stackId: 'unmanaged::$groupName',
          stackName: groupName == 'standalone'
              ? 'Unmanaged (Standalone)'
              : 'Unmanaged · $groupName',
          nodeId: nodeId,
          image: (u['image'] ?? '').toString(),
          status: (u['state'] ?? 'unknown').toString(),
          ip: '',
          ports: portsStr.isNotEmpty ? [portsStr] : const [],
          cpuPercent: 0,
          memUsedBytes: 0,
          isUnmanaged: true,
        ));
      }
    }

    // 4. Collect Ingress nodes
    final ingressNodes = _collectIngressNodes(
      visibleStacks,
      widget.state.services,
      containers,
    );

    // 5. Group containers into Centurion Host boxes
    final nodesList = widget.state.nodes.isNotEmpty
        ? widget.state.nodes
        : [Node(id: 'node-local-manager', ip: '127.0.0.1', role: 'manager', status: 'active')];

    final hostBoxes = <_TopoHostBox>[];
    for (final n in nodesList) {
      final hostContainers = containers.where((c) => c.nodeId == n.id).toList()
        ..sort((a, b) {
          final cmp = a.stackName.compareTo(b.stackName);
          return cmp != 0 ? cmp : a.name.compareTo(b.name);
        });
      hostBoxes.add(_TopoHostBox(node: n, containers: hostContainers));
    }

    // 6. Compute deterministic layout coordinates for canvas
    const double leftMargin = 28;
    const double topMargin = 28;
    const double ingressColX = leftMargin;
    const double ingressCardW = 240;
    const double ingressCardH = 74;
    const double ingressGapY = 16;

    const double hostColX = ingressColX + ingressCardW + 130;
    const double hostWidth = 620;
    const double hostHeaderH = 68;
    const double containerCardW = 276;
    const double containerCardH = 88;
    const double containerGapX = 18;
    const double containerGapY = 14;
    const double hostPadX = 24;
    const double hostPadBottom = 20;
    const double hostGapY = 28;

    // Layout Ingress cards (left column)
    double ingressY = topMargin + 56;
    for (final ing in ingressNodes) {
      ing.rect = Rect.fromLTWH(ingressColX, ingressY, ingressCardW, ingressCardH);
      ingressY += ingressCardH + ingressGapY;
    }

    // Layout Host boxes & their containers (right area)
    double hostY = topMargin;
    for (final box in hostBoxes) {
      final count = box.containers.length;
      final rows = count == 0 ? 1 : ((count + 1) ~/ 2);
      final boxH = hostHeaderH +
          (count == 0
              ? 64.0
              : rows * containerCardH + (rows - 1) * containerGapY) +
          hostPadBottom;

      box.rect = Rect.fromLTWH(hostColX, hostY, hostWidth, boxH);

      for (int i = 0; i < count; i++) {
        final col = i % 2;
        final row = i ~/ 2;
        final cx = hostColX + hostPadX + col * (containerCardW + containerGapX);
        final cy = hostY + hostHeaderH + row * (containerCardH + containerGapY);
        box.containers[i].rect =
            Rect.fromLTWH(cx, cy, containerCardW, containerCardH);
      }

      hostY += boxH + hostGapY;
    }

    final canvasWidth = hostColX + hostWidth + 48;
    final canvasHeight = (hostY > ingressY ? hostY : ingressY) + 48;

    // 7. Build topology edges
    final edges = <_TopoEdge>[];
    final containerById = {for (final c in containers) c.id: c};

    // Ingress -> Container edges
    for (final ing in ingressNodes) {
      final target = containerById[ing.targetService];
      if (target != null) {
        edges.add(_TopoEdge(
          fromId: ing.id,
          toId: target.id,
          from: Offset(ing.rect.right, ing.rect.center.dy),
          to: Offset(target.rect.left, target.rect.center.dy),
          color: const Color(0xFFF97316),
          label: ing.isTls ? 'HTTPS' : 'HTTP',
          kind: 'ingress',
        ));
      } else if (hostBoxes.isNotEmpty) {
        // Connect to Manager host header if upstream is a system/host route
        final mgrBox = hostBoxes.first;
        edges.add(_TopoEdge(
          fromId: ing.id,
          toId: 'host-${mgrBox.node.id}',
          from: Offset(ing.rect.right, ing.rect.center.dy),
          to: Offset(mgrBox.rect.left, mgrBox.rect.top + 34),
          color: const Color(0xFFF97316).withValues(alpha: 0.65),
          label: 'PROXY',
          dashed: true,
          kind: 'ingress',
        ));
      }
    }

    // Inter-service dependency edges (parsed from Compose depends_on & env URLs)
    if (_showServiceLinks) {
      for (final stack in visibleStacks) {
        final stackServices = widget.state.services
            .where((s) => s.stackId == stack.id)
            .toList();
        final deps = _extractServiceDependencies(stack, stackServices);
        for (final (fromSvc, toSvc) in deps) {
          final fromContainers = containers
              .where((c) => c.stackId == stack.id && c.serviceName == fromSvc);
          final toContainers = containers
              .where((c) => c.stackId == stack.id && c.serviceName == toSvc);
          for (final fc in fromContainers) {
            for (final tc in toContainers) {
              final crossHost = fc.nodeId != tc.nodeId;
              edges.add(_TopoEdge(
                fromId: fc.id,
                toId: tc.id,
                from: Offset(fc.rect.right, fc.rect.center.dy),
                to: Offset(tc.rect.left, tc.rect.center.dy),
                color: crossHost
                    ? const Color(0xFFA855F7)
                    : const Color(0xFF38BDF8),
                label: crossHost ? 'MESH' : 'NET',
                dashed: crossHost,
                kind: crossHost ? 'cross-host' : 'service',
              ));
            }
          }
        }
      }
    }

    // Selected container or ingress for inspector side panel
    final selectedContainer =
        _selectedNodeId != null ? containerById[_selectedNodeId] : null;
    final selectedIngress = _selectedNodeId != null
        ? ingressNodes.where((e) => e.id == _selectedNodeId).firstOrNull
        : null;

    final runningContainers = containers.where((c) => c.isRunning).length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Top Header & Controls ──────────────────────────────
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_tree_outlined,
                      color: Color(0xFFF97316),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cluster Stack & Ingress Topology',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${nodesList.length} Centurions · ${visibleStacks.length} Stacks · $runningContainers/${containers.length} Containers · ${ingressNodes.length} Ingress Routes · ${edges.length} Links',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Stack selector
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedStackFilter,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: 'Focus Stack',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: 'ALL', child: Text('All Stacks')),
                        ...allStacks.map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        _selectedStackFilter = v ?? 'ALL';
                        _selectedNodeId = null;
                      }),
                    ),
                  ),
                  FilterChip(
                    label: const Text('Base Stacks', style: TextStyle(fontSize: 12)),
                    selected: _showBaseStacks,
                    onSelected: (v) => setState(() => _showBaseStacks = v),
                  ),
                  FilterChip(
                    label: const Text('Unmanaged', style: TextStyle(fontSize: 12)),
                    selected: _showUnmanaged,
                    onSelected: (v) => setState(() => _showUnmanaged = v),
                  ),
                  FilterChip(
                    label: const Text('Service Links', style: TextStyle(fontSize: 12)),
                    selected: _showServiceLinks,
                    onSelected: (v) => setState(() => _showServiceLinks = v),
                  ),
                  IconButton(
                    tooltip: 'Zoom Out',
                    icon: const Icon(Icons.zoom_out, size: 20),
                    onPressed: () => _zoomBy(0.85),
                  ),
                  Text(
                    '${(_currentScale * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    tooltip: 'Zoom In',
                    icon: const Icon(Icons.zoom_in, size: 20),
                    onPressed: () => _zoomBy(1.15),
                  ),
                  IconButton(
                    tooltip: 'Reset View',
                    icon: const Icon(Icons.center_focus_strong, size: 20),
                    onPressed: _resetZoom,
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      widget.onRefresh();
                      _loadTopologyExtras();
                    },
                    icon: _loadingExtras
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 17),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ─── Legend Bar ─────────────────────────────────────────
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _legendDot(const Color(0xFFF97316), 'Load Balancing / Ingress Route'),
              _legendDot(const Color(0xFF38BDF8), 'Internal Stack Network Link'),
              _legendDot(const Color(0xFFA855F7), 'Cross-Host Mesh Link'),
              _legendDot(const Color(0xFF10B981), 'Running Container'),
              _legendDot(const Color(0xFFF59E0B), 'Unmanaged Container'),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Interactive Canvas + Optional Inspector Panel ──────
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF070C16)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.withValues(alpha: 0.25),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedNodeId = null),
                        child: InteractiveViewer(
                          transformationController: _transformController,
                          constrained: false,
                          boundaryMargin: const EdgeInsets.all(200),
                          minScale: 0.4,
                          maxScale: 2.2,
                          onInteractionEnd: (_) {
                            setState(() {
                              _currentScale = _transformController.value
                                  .getMaxScaleOnAxis();
                            });
                          },
                          child: SizedBox(
                            width: canvasWidth,
                            height: canvasHeight < 520 ? 520 : canvasHeight,
                            child: Stack(
                              children: [
                                // Subtle grid + curved topology edges
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _ClusterTopologyPainter(
                                      edges: edges,
                                      selectedId: _selectedNodeId,
                                      isDark: isDark,
                                    ),
                                  ),
                                ),

                                // Ingress column title
                                Positioned(
                                  left: ingressColX,
                                  top: topMargin,
                                  width: ingressCardW,
                                  child: _buildColumnHeader(
                                    icon: Icons.alt_route,
                                    title: 'LOAD BALANCING / INGRESS',
                                    subtitle:
                                        '${ingressNodes.length} routes · ${widget.state.dnsRecords.length} DNS',
                                    color: const Color(0xFFF97316),
                                    isDark: isDark,
                                  ),
                                ),

                                // Empty ingress placeholder
                                if (ingressNodes.isEmpty)
                                  Positioned(
                                    left: ingressColX,
                                    top: topMargin + 56,
                                    width: ingressCardW,
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF111827)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.08)
                                              : Colors.grey
                                                  .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Text(
                                        'No active Ingress routes detected for the selected filter.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.55),
                                        ),
                                      ),
                                    ),
                                  ),

                                // Ingress Route Cards
                                for (final ing in ingressNodes)
                                  Positioned.fromRect(
                                    rect: ing.rect,
                                    child: _buildIngressCard(
                                        ing, theme, isDark),
                                  ),

                                // Centurion Host Enclosure Boxes
                                for (final box in hostBoxes)
                                  Positioned.fromRect(
                                    rect: box.rect,
                                    child:
                                        _buildHostEnclosure(box, theme, isDark),
                                  ),

                                // Container Cards inside Hosts
                                for (final c in containers)
                                  Positioned.fromRect(
                                    rect: c.rect,
                                    child:
                                        _buildContainerCard(c, theme, isDark),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Right-side Inspector Panel when a node is selected
                if (selectedContainer != null || selectedIngress != null) ...[
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 300,
                    child: _buildInspectorPanel(
                      theme: theme,
                      isDark: isDark,
                      container: selectedContainer,
                      ingress: selectedIngress,
                      edges: edges,
                      containerById: containerById,
                      ingressNodes: ingressNodes,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11.5)),
      ],
    );
  }

  Widget _buildColumnHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngressCard(
    _TopoIngressNode ing,
    ThemeData theme,
    bool isDark,
  ) {
    final isSelected = _selectedNodeId == ing.id;
    const accent = Color(0xFFF97316);

    return GestureDetector(
      onTap: () => setState(() {
        _selectedNodeId = isSelected ? null : ing.id;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? accent
                : accent.withValues(alpha: isDark ? 0.4 : 0.35),
            width: isSelected ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isSelected ? 0.25 : 0.08),
              blurRadius: isSelected ? 12 : 6,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(
                  ing.isTls ? Icons.lock : Icons.public,
                  size: 14,
                  color: ing.isTls ? const Color(0xFF10B981) : accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ing.host,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => _openHostUrl(ing.host),
                  child: const Icon(Icons.open_in_new, size: 13, color: accent),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '→ ${ing.upstream}',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Courier New',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHostEnclosure(
    _TopoHostBox box,
    ThemeData theme,
    bool isDark,
  ) {
    final node = box.node;
    final isManager = node.role.toLowerCase() == 'manager';
    final isActive = node.status.toLowerCase() == 'active';
    final accent =
        isManager ? const Color(0xFFF97316) : const Color(0xFF38BDF8);

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.35 : 0.3),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Host Header Bar
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(
                bottom: BorderSide(
                  color: accent.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF10B981) : Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.dns, size: 18, color: accent),
                const SizedBox(width: 8),
                Text(
                  node.id,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    node.role.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  node.ip,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'Courier New',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const Spacer(),
                Text(
                  'CPU ${node.cpuPercent.toStringAsFixed(0)}% · RAM ${node.memPercent.toStringAsFixed(0)}% · ${box.containers.length} ctrs',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (box.containers.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No matching containers on this Centurion host',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContainerCard(
    _TopoContainerNode c,
    ThemeData theme,
    bool isDark,
  ) {
    final isSelected = _selectedNodeId == c.id;
    final statusColor = c.isUnmanaged
        ? const Color(0xFFF59E0B)
        : (c.isRunning ? const Color(0xFF10B981) : Colors.redAccent);

    return GestureDetector(
      onTap: () => setState(() {
        _selectedNodeId = isSelected ? null : c.id;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF97316)
                : statusColor.withValues(alpha: isDark ? 0.4 : 0.35),
            width: isSelected ? 2 : 1.1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFF97316).withValues(alpha: 0.25),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    c.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: (c.isUnmanaged
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF6366F1))
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    c.stackName,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: c.isUnmanaged
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF818CF8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              c.image,
              style: TextStyle(
                fontSize: 10.5,
                fontFamily: 'Courier New',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                if (c.ip.isNotEmpty) ...[
                  Icon(Icons.lan_outlined,
                      size: 11,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                  const SizedBox(width: 3),
                  Text(
                    c.ip,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Courier New',
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (c.ports.isNotEmpty)
                  Expanded(
                    child: Text(
                      c.ports.join(', '),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF38BDF8),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Spacer(),
                if (c.cpuPercent > 0)
                  Text(
                    '${c.cpuPercent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectorPanel({
    required ThemeData theme,
    required bool isDark,
    _TopoContainerNode? container,
    _TopoIngressNode? ingress,
    required List<_TopoEdge> edges,
    required Map<String, _TopoContainerNode> containerById,
    required List<_TopoIngressNode> ingressNodes,
  }) {
    final relatedEdges = edges.where((e) {
      final id = container?.id ?? ingress?.id;
      return e.fromId == id || e.toId == id;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                container != null ? Icons.view_in_ar : Icons.alt_route,
                color: const Color(0xFFF97316),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  container != null ? 'Container Inspector' : 'Ingress Inspector',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _selectedNodeId = null),
              ),
            ],
          ),
          const Divider(),
          if (container != null) ...[
            _inspectorRow('Container', container.name),
            _inspectorRow('Stack', container.stackName),
            _inspectorRow('Host (Centurion)', container.nodeId),
            _inspectorRow('Status', container.status.toUpperCase()),
            _inspectorRow('Image', container.image),
            if (container.ip.isNotEmpty) _inspectorRow('Internal IP', container.ip),
            if (container.ports.isNotEmpty)
              _inspectorRow('Ports', container.ports.join('\n')),
            _inspectorRow('Type', container.isUnmanaged ? 'Unmanaged' : 'Managed'),
            const SizedBox(height: 10),
            if (!container.isUnmanaged && widget.onViewContainerLogs != null)
              FilledButton.tonalIcon(
                onPressed: () => widget.onViewContainerLogs!(container.name),
                icon: const Icon(Icons.receipt_long, size: 16),
                label: const Text('View Container Logs'),
              ),
            if (!container.isUnmanaged && widget.onViewStackContainers != null) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () =>
                    widget.onViewStackContainers!(container.stackName),
                icon: const Icon(Icons.layers_outlined, size: 16),
                label: const Text('Open Stack Containers'),
              ),
            ],
          ] else if (ingress != null) ...[
            _inspectorRow('Domain / Host', ingress.host),
            _inspectorRow('Protocol', ingress.isTls ? 'HTTPS (TLS)' : 'HTTP'),
            _inspectorRow('Upstream', ingress.upstream),
            if (ingress.nodeId.isNotEmpty)
              _inspectorRow('Target Host', ingress.nodeId),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _openHostUrl(ingress.host),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open Endpoint'),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Connections (${relatedEdges.length})',
            style: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: relatedEdges.isEmpty
                ? Text(
                    'No direct edges detected.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  )
                : ListView.separated(
                    itemCount: relatedEdges.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, idx) {
                      final e = relatedEdges[idx];
                      final fromLabel = containerById[e.fromId]?.name ??
                          ingressNodes
                              .where((i) => i.id == e.fromId)
                              .map((i) => i.host)
                              .firstOrNull ??
                          e.fromId;
                      final toLabel =
                          containerById[e.toId]?.name ?? e.toId;
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: e.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: e.color.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '$fromLabel  →  $toLabel (${e.label})',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _inspectorRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter drawing the subtle architectural grid and curved Bézier topology connections.
class _ClusterTopologyPainter extends CustomPainter {
  final List<_TopoEdge> edges;
  final String? selectedId;
  final bool isDark;

  _ClusterTopologyPainter({
    required this.edges,
    required this.selectedId,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Subtle dot/grid background
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Curved Bézier connection edges
    for (final edge in edges) {
      final isHighlighted = selectedId == null ||
          edge.fromId == selectedId ||
          edge.toId == selectedId;
      final alpha = isHighlighted ? 0.88 : 0.16;
      final strokeWidth =
          (selectedId != null && isHighlighted) ? 2.6 : 1.8;

      final paint = Paint()
        ..color = edge.color.withValues(alpha: alpha)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final dx = (edge.to.dx - edge.from.dx).abs();
      final controlOffset = dx < 60 ? 60.0 : dx * 0.45;
      final c1 = Offset(edge.from.dx + controlOffset, edge.from.dy);
      final c2 = Offset(edge.to.dx - controlOffset, edge.to.dy);

      final path = Path()
        ..moveTo(edge.from.dx, edge.from.dy)
        ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, edge.to.dx, edge.to.dy);

      if (edge.dashed) {
        _drawDashedPath(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }

      // Draw arrowhead at target
      final arrowPaint = Paint()
        ..color = edge.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      final arrowPath = Path()
        ..moveTo(edge.to.dx, edge.to.dy)
        ..lineTo(edge.to.dx - 8, edge.to.dy - 4.5)
        ..lineTo(edge.to.dx - 8, edge.to.dy + 4.5)
        ..close();
      canvas.drawPath(arrowPath, arrowPaint);

      // Draw origin dot
      canvas.drawCircle(edge.from, 3.2, arrowPaint);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLen = 6.0;
    const gapLen = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashLen).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ClusterTopologyPainter oldDelegate) {
    return oldDelegate.edges != edges ||
        oldDelegate.selectedId != selectedId ||
        oldDelegate.isDark != isDark;
  }
}

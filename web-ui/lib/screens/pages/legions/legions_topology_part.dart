part of '../legions_page.dart';

/// Deterministic accent palette for visually pairing each Stack with its containers & edges.
const List<Color> _kStackPalette = [
  Color(0xFF6366F1), // Indigo
  Color(0xFF0EA5E9), // Sky
  Color(0xFF10B981), // Emerald
  Color(0xFFEC4899), // Pink
  Color(0xFF8B5CF6), // Violet
  Color(0xFF14B8A6), // Teal
  Color(0xFFF59E0B), // Amber
  Color(0xFFEF4444), // Red
];

/// Data model for a single ingress route displayed in Column 1 of the Cluster Topology canvas.
class _TopoIngressNode {
  final String id;
  final String host;
  final String cleanHost;
  final List<String> upstreams;
  final List<String> targetContainerIds;
  final Set<String> targetStackIds;
  final String targetHostNodeId;
  final bool isTls;
  Rect rect = Rect.zero;

  _TopoIngressNode({
    required this.id,
    required this.host,
    required this.cleanHost,
    required this.upstreams,
    required this.targetContainerIds,
    required this.targetStackIds,
    required this.targetHostNodeId,
    required this.isTls,
  });

  String get upstream =>
      upstreams.isNotEmpty ? upstreams.join(', ') : 'caddy-proxy';
}

/// Data model for a Stack (Legion) card displayed in Column 2 of the Cluster Topology canvas.
class _TopoStackNode {
  final String id;
  final String stackId;
  final String name;
  final Color accentColor;
  final int totalServices;
  final int runningContainers;
  final int totalContainers;
  final List<String> hostNodeIds;
  final List<String> containerIds;
  final bool isBase;
  final bool isUnmanaged;
  Rect rect = Rect.zero;

  _TopoStackNode({
    required this.id,
    required this.stackId,
    required this.name,
    required this.accentColor,
    required this.totalServices,
    required this.runningContainers,
    required this.totalContainers,
    required this.hostNodeIds,
    required this.containerIds,
    this.isBase = false,
    this.isUnmanaged = false,
  });
}

/// Data model for a container (or stopped/unscheduled service) card rendered inside a Centurion host box (Column 3).
class _TopoContainerNode {
  final String id;
  final String name;
  final String serviceId;
  final String serviceName;
  final String stackId;
  final String stackName;
  final Color stackColor;
  final String nodeId;
  final String image;
  final String status;
  final String ip;
  final List<String> ports;
  final double cpuPercent;
  final int memUsedBytes;
  final bool isBase;
  final bool isUnmanaged;
  final bool isPlaceholder;
  Rect rect = Rect.zero;

  _TopoContainerNode({
    required this.id,
    required this.name,
    this.serviceId = '',
    required this.serviceName,
    required this.stackId,
    required this.stackName,
    required this.stackColor,
    required this.nodeId,
    required this.image,
    required this.status,
    required this.ip,
    required this.ports,
    required this.cpuPercent,
    required this.memUsedBytes,
    this.isBase = false,
    this.isUnmanaged = false,
    this.isPlaceholder = false,
  });

  bool get isRunning => status.toLowerCase() == 'running';
}

/// Data model for a Centurion host container box on the canvas (Column 3).
class _TopoHostBox {
  final Node node;
  final List<_TopoContainerNode> containers;
  final bool isSynthetic;
  final String? discoveryWarning;
  Rect rect = Rect.zero;

  _TopoHostBox({
    required this.node,
    required this.containers,
    this.isSynthetic = false,
    this.discoveryWarning,
  });
}

/// Directed edge between two topology nodes:
/// - Ingress -> Stack (or fallback Host/Container)
/// - Stack -> Container (inside Manager / Worker Centurion hosts)
/// - Container -> Container (same-host NET or cross-host MESH)
class _TopoEdge {
  final String fromId;
  final String toId;
  final Offset from;
  final Offset to;
  final Offset c1;
  final Offset c2;
  final Color color;
  final String label;
  final bool dashed;
  final String kind; // 'ingress', 'stack', 'service', 'cross-host'

  const _TopoEdge({
    required this.fromId,
    required this.toId,
    required this.from,
    required this.to,
    required this.c1,
    required this.c2,
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
  bool _showUnmanaged = false; // Default OFF so count matches Legions -> Deployed 1:1
  bool _showServiceLinks = true;
  String _selectedStackFilter = 'ALL';
  String? _selectedNodeId; // Selected ingress, stack, or container ID for highlighting
  double _currentScale = 1.0;

  bool _loadingExtras = false;
  List<Map<String, dynamic>> _caddyRoutes = [];
  List<Map<String, dynamic>> _unmanagedContainers = [];
  Map<String, String> _unmanagedNodeErrors = {};

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
      final rawErrors = unmanagedRaw['node_errors'];
      final parsedErrors = <String, String>{};
      if (rawErrors is Map) {
        rawErrors.forEach((k, v) {
          final msg = v?.toString().trim() ?? '';
          if (msg.isNotEmpty) parsedErrors[k.toString()] = msg;
        });
      }
      setState(() {
        _caddyRoutes = routesRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _unmanagedContainers = (unmanagedRaw['containers'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _unmanagedNodeErrors = parsedErrors;
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

  /// Resolves a raw node identifier (ID, hostname label, IP, or empty manager default)
  /// to the canonical `Node.id` in `nodesList` so containers are never orphaned with `Rect.zero`.
  String _resolveNodeId(String rawNodeId, List<Node> nodesList) {
    final trimmed = rawNodeId.trim();
    if (nodesList.isEmpty) {
      return trimmed.isNotEmpty ? trimmed : 'node-local-manager';
    }

    final managerNode = nodesList.firstWhere(
      (n) =>
          n.role.toLowerCase() == 'manager' ||
          n.id.toLowerCase() == 'node-local-manager',
      orElse: () => nodesList.first,
    );

    if (trimmed.isEmpty || trimmed == 'node-local-manager') {
      for (final n in nodesList) {
        if (n.id == trimmed) return n.id;
      }
      return managerNode.id;
    }

    // 1. Exact ID match
    for (final n in nodesList) {
      if (n.id == trimmed) return n.id;
    }

    final lower = trimmed.toLowerCase();
    // 2. Case-insensitive ID or IP match
    for (final n in nodesList) {
      if (n.id.toLowerCase() == lower ||
          (n.ip.isNotEmpty && n.ip.toLowerCase() == lower)) {
        return n.id;
      }
    }

    // 3. Label hostname / alias match
    for (final n in nodesList) {
      final hostLabel = (n.labels['hostname'] ??
              n.labels['gbnt.node.hostname'] ??
              n.labels['node.hostname'] ??
              '')
          .toString()
          .trim()
          .toLowerCase();
      if (hostLabel.isNotEmpty && hostLabel == lower) {
        return n.id;
      }
    }

    return trimmed;
  }

  /// Infers the intended Centurion host for a service that currently has 0 tasks
  /// using placement constraints, `stack.nodeId`, or falling back to Manager.
  String _inferNodeIdForService(
    Service svc,
    StackModel stack,
    List<Node> nodesList,
  ) {
    for (final c in svc.constraints) {
      final trimmed = c.trim();
      String key = '';
      String val = '';
      if (trimmed.contains('==')) {
        final parts = trimmed.split('==');
        if (parts.length == 2) {
          key = parts[0].trim().toLowerCase();
          val = parts[1].trim().replaceAll('"', '').replaceAll("'", '');
        }
      } else if (trimmed.contains('=')) {
        final idx = trimmed.indexOf('=');
        key = trimmed.substring(0, idx).trim().toLowerCase();
        val = trimmed
            .substring(idx + 1)
            .trim()
            .replaceAll('"', '')
            .replaceAll("'", '');
      }
      if (val.isEmpty) continue;
      if (key == 'node.hostname' ||
          key == 'gbnt.node.hostname' ||
          key == 'node.id' ||
          key == 'gbnt.node.id') {
        return _resolveNodeId(val, nodesList);
      }
      if (key == 'node.role' || key == 'gbnt.node.role') {
        final roleTarget = nodesList
            .where((n) => n.role.toLowerCase() == val.toLowerCase())
            .firstOrNull;
        if (roleTarget != null) return roleTarget.id;
      }
    }

    if (stack.nodeId.trim().isNotEmpty) {
      return _resolveNodeId(stack.nodeId, nodesList);
    }
    return _resolveNodeId('', nodesList);
  }

  /// Extracts published host ports from Compose (`8080:80`, `0.0.0.0:8080:80/tcp`)
  /// and `docker ps` (`0.0.0.0:8080->80/tcp, [::]:8080->80/tcp`) port strings.
  Set<String> _extractHostPorts(List<String> ports) {
    final result = <String>{};
    for (final raw in ports) {
      for (final segment in raw.split(',')) {
        var s = segment.trim();
        if (s.isEmpty) continue;
        final slashIdx = s.indexOf('/');
        if (slashIdx != -1) s = s.substring(0, slashIdx).trim();

        if (s.contains('->')) {
          final left = s.split('->').first.trim();
          final lastColon = left.lastIndexOf(':');
          final hp =
              lastColon != -1 ? left.substring(lastColon + 1).trim() : left;
          if (RegExp(r'^\d+$').hasMatch(hp)) result.add(hp);
        } else {
          final parts = s.split(':');
          if (parts.length == 2) {
            final hp = parts[0].trim();
            if (RegExp(r'^\d+$').hasMatch(hp)) result.add(hp);
          } else if (parts.length == 3) {
            final hp = parts[1].trim();
            if (RegExp(r'^\d+$').hasMatch(hp)) result.add(hp);
          }
        }
      }
    }
    return result;
  }

  /// Strips inline YAML comments and surrounding quotes from a YAML key/value token.
  String _cleanYamlToken(String raw) {
    var s = raw.trim();
    final hashIdx = s.indexOf(' #');
    if (hashIdx != -1) s = s.substring(0, hashIdx).trim();
    if ((s.startsWith('"') && s.endsWith('"')) ||
        (s.startsWith("'") && s.endsWith("'"))) {
      if (s.length >= 2) s = s.substring(1, s.length - 1).trim();
    }
    return s;
  }

  /// Parses `depends_on`, `links`, and service-to-service URL/host references from a stack's compose YAML.
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
    bool inLinks = false;
    int serviceIndent = -1;
    int listIndent = -1;

    for (final rawLine in lines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final indent = rawLine.length - rawLine.trimLeft().length;

      if (indent == 0) {
        inServices = trimmed.startsWith('services:');
        currentService = null;
        inDependsOn = false;
        inLinks = false;
        serviceIndent = -1;
        continue;
      }
      if (!inServices) continue;

      final keyToken = _cleanYamlToken(trimmed);
      if (serviceIndent == -1 && keyToken.endsWith(':')) {
        final candidate =
            _cleanYamlToken(keyToken.substring(0, keyToken.length - 1));
        if (serviceNames.contains(candidate)) {
          serviceIndent = indent;
          currentService = candidate;
          inDependsOn = false;
          inLinks = false;
          continue;
        }
      } else if (indent == serviceIndent && keyToken.endsWith(':')) {
        final candidate =
            _cleanYamlToken(keyToken.substring(0, keyToken.length - 1));
        currentService = serviceNames.contains(candidate) ? candidate : null;
        inDependsOn = false;
        inLinks = false;
        continue;
      }

      if (currentService == null) continue;

      if (trimmed.startsWith('depends_on:')) {
        inDependsOn = true;
        inLinks = false;
        listIndent = indent;
        continue;
      }
      if (trimmed.startsWith('links:')) {
        inLinks = true;
        inDependsOn = false;
        listIndent = indent;
        continue;
      }

      if (inDependsOn || inLinks) {
        if (indent <= listIndent) {
          inDependsOn = false;
          inLinks = false;
        } else {
          var target = _cleanYamlToken(trimmed);
          if (target.startsWith('-')) {
            target = _cleanYamlToken(target.substring(1));
          } else if (target.endsWith(':')) {
            target = _cleanYamlToken(target.substring(0, target.length - 1));
          }
          if (inLinks && target.contains(':')) {
            target = target.split(':').first.trim();
          }
          if (serviceNames.contains(target) && target != currentService) {
            deps.add((currentService, target));
          }
        }
      }

      for (final other in serviceNames) {
        if (other == currentService || other.length < 2) continue;
        final pattern = RegExp(
          '(://|=|@)${RegExp.escape(other)}(:|/|\\s|"|\'|\$)',
          caseSensitive: false,
        );
        if (pattern.hasMatch(trimmed)) {
          deps.add((currentService, other));
        }
      }
    }

    final seen = <String>{};
    return deps.where((e) => seen.add('${e.$1}->${e.$2}')).toList();
  }

  /// Extracts a mapping of normalized `ingressHost -> List<Service>` across stacks
  /// by inspecting both `Service.constraints` (the exact source used by `GenerateCaddyfile()`)
  /// and per-service sections of `StackModel.rawComposeFile`.
  Map<String, List<Service>> _buildHostToServicesMap(
    List<StackModel> stacks,
    List<Service> allServices,
  ) {
    final map = <String, List<Service>>{};
    final stackIds = stacks.map((s) => s.id).toSet();

    void addMapping(String rawHost, Service svc) {
      for (final part in rawHost.split(',')) {
        final clean = _stripScheme(part).toLowerCase();
        if (clean.isEmpty) continue;
        final list = map.putIfAbsent(clean, () => <Service>[]);
        if (!list.any((s) => s.id == svc.id)) {
          list.add(svc);
        }
      }
    }

    // 1. Authoritative Service.constraints (same keys as internal/aqueducts/ingress.go)
    for (final svc in allServices) {
      if (!stackIds.contains(svc.stackId)) continue;
      for (final constraint in svc.constraints) {
        String key = '';
        String val = '';
        if (constraint.contains('==')) {
          final parts = constraint.split('==');
          if (parts.length == 2) {
            key = parts[0].trim().toLowerCase();
            val = parts[1].trim();
          }
        } else if (constraint.contains('=')) {
          final idx = constraint.indexOf('=');
          key = constraint.substring(0, idx).trim().toLowerCase();
          val = constraint.substring(idx + 1).trim();
        }
        val = val.replaceAll('"', '').replaceAll("'", '').trim();
        if (val.isEmpty) continue;
        if (key == 'ingress.host' ||
            key == 'gbnt.ingress.host' ||
            key == 'gbnt.caddy.host' ||
            key == 'node.labels.gbnt.ingress.host') {
          addMapping(val, svc);
        }
      }
    }

    // 2. Per-service compose YAML scan for ingress labels
    final hostRegex = RegExp(
      r'''(?:ingress\.host|gbnt\.caddy\.host|gbnt\.ingress\.host|node\.labels\.gbnt\.ingress\.host)\s*(?:==|=|:)\s*["']?([a-zA-Z0-9._:/-]+)["']?''',
      caseSensitive: false,
    );

    for (final stack in stacks) {
      if (stack.rawComposeFile.trim().isEmpty) continue;
      final stackServices =
          allServices.where((s) => s.stackId == stack.id).toList();
      if (stackServices.isEmpty) continue;
      final svcByName = {for (final s in stackServices) s.name: s};

      final lines = stack.rawComposeFile.split('\n');
      bool inServices = false;
      int serviceIndent = -1;
      Service? currentSvc;

      for (final rawLine in lines) {
        final trimmed = rawLine.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final indent = rawLine.length - rawLine.trimLeft().length;

        if (indent == 0) {
          inServices = trimmed.startsWith('services:');
          currentSvc = null;
          serviceIndent = -1;
          continue;
        }
        if (!inServices) continue;

        final token = _cleanYamlToken(trimmed);
        if (serviceIndent == -1 && token.endsWith(':')) {
          final candidate =
              _cleanYamlToken(token.substring(0, token.length - 1));
          if (svcByName.containsKey(candidate)) {
            serviceIndent = indent;
            currentSvc = svcByName[candidate];
            continue;
          }
        } else if (indent == serviceIndent && token.endsWith(':')) {
          final candidate =
              _cleanYamlToken(token.substring(0, token.length - 1));
          currentSvc = svcByName[candidate];
          continue;
        }

        if (currentSvc != null) {
          for (final m in hostRegex.allMatches(trimmed)) {
            final host = (m.group(1) ?? '').trim();
            if (host.isNotEmpty) {
              addMapping(host, currentSvc);
            }
          }
        }
      }
    }

    return map;
  }

  String _stripScheme(String raw) {
    var s = raw.trim();
    if (s.startsWith('https://')) {
      s = s.substring('https://'.length);
    } else if (s.startsWith('http://')) {
      s = s.substring('http://'.length);
    }
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s.trim();
  }

  /// Normalizes a Caddy site block header (which may be comma-separated like
  /// `http://app.gbnt.local, app.gbnt.local`) into a list of clean hostnames.
  List<String> _extractRouteHosts(String rawHost, String cleanHostRaw) {
    final source = cleanHostRaw.isNotEmpty ? cleanHostRaw : rawHost;
    final hosts = <String>[];
    for (final part in source.split(',')) {
      var h = _stripScheme(part);
      // Strip trailing :80 or :443 port if present on hostname
      if (h.endsWith(':80')) h = h.substring(0, h.length - 3);
      if (h.endsWith(':443')) h = h.substring(0, h.length - 4);
      h = h.trim();
      if (h.isEmpty || h == ':80' || h == ':443') continue;
      if (!hosts.any((e) => e.toLowerCase() == h.toLowerCase())) {
        hosts.add(h);
      }
    }
    return hosts;
  }

  bool _isSystemBaseHost(String hostLower) {
    const prefixes = [
      'grafana.',
      'jaeger.',
      'prometheus.',
      'loki.',
      'scope.',
      'cadvisor.',
      'alertmanager.',
      'opensearch.',
    ];
    return prefixes.any((p) => hostLower.startsWith(p));
  }

  /// Splits an upstream address like `http://192.168.1.51:8080` or `172.18.0.5:80`
  /// into `(host, port)`.
  (String, String) _parseUpstreamHostPort(String raw) {
    var clean = _stripScheme(raw);
    final slashIdx = clean.indexOf('/');
    if (slashIdx != -1) clean = clean.substring(0, slashIdx);
    final lastColon = clean.lastIndexOf(':');
    if (lastColon > 0 && !clean.endsWith(']')) {
      return (
        clean.substring(0, lastColon).trim().toLowerCase(),
        clean.substring(lastColon + 1).trim(),
      );
    }
    return (clean.toLowerCase(), '');
  }

  /// Collects live Caddy routes + compose-declared ingress routes, filtering out hidden Base Stack
  /// routes when `Base Stacks` is OFF, and linking each route to its owning Stack(s) & Container(s).
  List<_TopoIngressNode> _collectIngressNodes({
    required List<StackModel> allStacks,
    required List<StackModel> visibleStacks,
    required List<Service> allServices,
    required List<_TopoContainerNode> allContainers,
    required List<Node> nodesList,
  }) {
    final nodes = <_TopoIngressNode>[];
    final seenHosts = <String>{};
    final nodeById = {for (final n in nodesList) n.id: n};
    final visibleStackIds = visibleStacks.map((s) => s.id).toSet();

    // Build host->services map across ALL stacks so we know when a route belongs to a hidden Base Stack
    final allHostToServices = _buildHostToServicesMap(allStacks, allServices);
    final visibleHostToServices =
        _buildHostToServicesMap(visibleStacks, allServices);

    final containerHostPorts = {
      for (final c in allContainers) c.id: _extractHostPorts(c.ports),
    };

    // 1. Live Caddy routes from /api/caddy/routes
    for (int i = 0; i < _caddyRoutes.length; i++) {
      final r = _caddyRoutes[i];
      final rawHost =
          (r['host'] ?? r['domain'] ?? r['match'] ?? '').toString().trim();
      final cleanHostRaw = (r['clean_host'] ?? '').toString().trim();
      final routeHosts = _extractRouteHosts(rawHost, cleanHostRaw);
      if (routeHosts.isEmpty) continue;

      final primaryHost = routeHosts.first;
      final hostKey = primaryHost.toLowerCase();
      if (!seenHosts.add(hostKey)) continue;

      // Read plural `upstreams` array (actual backend format) with fallback to singular fields
      final upstreams = <String>[];
      final rawUpstreams = r['upstreams'];
      if (rawUpstreams is List) {
        for (final item in rawUpstreams) {
          final s = item?.toString().trim() ?? '';
          if (s.isNotEmpty) upstreams.add(s);
        }
      } else {
        final single =
            (r['upstream'] ?? r['dial'] ?? r['target'] ?? '').toString().trim();
        if (single.isNotEmpty) {
          upstreams.addAll(
            single.split(RegExp(r'[\s,]+')).where((e) => e.isNotEmpty),
          );
        }
      }

      // Check if this route belongs strictly to hidden Base Stacks
      final allDeclaredForHost = <Service>[];
      final visibleDeclaredForHost = <Service>[];
      for (final rh in routeHosts) {
        final k = rh.toLowerCase();
        allDeclaredForHost.addAll(allHostToServices[k] ?? const <Service>[]);
        visibleDeclaredForHost
            .addAll(visibleHostToServices[k] ?? const <Service>[]);
      }
      if (allDeclaredForHost.isNotEmpty && visibleDeclaredForHost.isEmpty) {
        // Route belongs exclusively to a filtered-out stack (e.g. Base Stack when Base Stacks is OFF)
        continue;
      }

      final matchedContainerIds = <String>[];
      final matchedStackIds = <String>{};
      String matchedHostNodeId = '';

      void addContainerMatch(_TopoContainerNode c) {
        if (!matchedContainerIds.contains(c.id)) {
          matchedContainerIds.add(c.id);
        }
        if (c.stackId.isNotEmpty) matchedStackIds.add(c.stackId);
        if (matchedHostNodeId.isEmpty) matchedHostNodeId = c.nodeId;
      }

      // Strategy A (Authoritative): Match via Service.constraints & Compose ingress.host
      for (final svc in visibleDeclaredForHost) {
        matchedStackIds.add(svc.stackId);
        for (final c in allContainers) {
          if ((c.serviceId.isNotEmpty && c.serviceId == svc.id) ||
              (c.stackId == svc.stackId && c.serviceName == svc.name)) {
            addContainerMatch(c);
          }
        }
      }

      // Strategy B: Match each Caddy upstream (IP:port or host:port) against containers & Centurion nodes
      for (final u in upstreams) {
        final (uHost, uPort) = _parseUpstreamHostPort(u);
        if (uHost.isEmpty) continue;

        for (final n in nodesList) {
          if (n.ip.isNotEmpty && n.ip.toLowerCase() == uHost) {
            if (matchedHostNodeId.isEmpty) matchedHostNodeId = n.id;
          }
        }

        for (final c in allContainers) {
          final matchesContainerIp =
              c.ip.isNotEmpty && c.ip.toLowerCase() == uHost;
          final nodeIp = nodeById[c.nodeId]?.ip.toLowerCase() ?? '';
          final hostPorts = containerHostPorts[c.id] ?? const <String>{};
          final matchesNodeIpAndPort = nodeIp.isNotEmpty &&
              nodeIp == uHost &&
              uPort.isNotEmpty &&
              hostPorts.contains(uPort);
          final matchesName = uHost == c.name.toLowerCase() ||
              uHost == c.serviceName.toLowerCase();

          if (matchesContainerIp || matchesNodeIpAndPort || matchesName) {
            addContainerMatch(c);
          }
        }
      }

      // Strategy C: DNS record fallback
      if (matchedContainerIds.isEmpty) {
        for (final dns in widget.state.dnsRecords) {
          final dnsHost = dns.hostname.trim().toLowerCase();
          if (!routeHosts.any((rh) => rh.toLowerCase() == dnsHost)) continue;
          final dnsIp = dns.ip.trim().toLowerCase();
          if (dnsIp.isEmpty) continue;
          for (final c in allContainers) {
            if (c.ip.toLowerCase() == dnsIp) {
              addContainerMatch(c);
            }
          }
          if (matchedHostNodeId.isEmpty) {
            for (final n in nodesList) {
              if (n.ip.toLowerCase() == dnsIp) {
                matchedHostNodeId = n.id;
                break;
              }
            }
          }
        }
      }

      // Hide unmatched system/observability Caddy routes when Base Stacks filter is OFF
      if (!_showBaseStacks &&
          _selectedStackFilter == 'ALL' &&
          matchedStackIds.isEmpty &&
          _isSystemBaseHost(hostKey)) {
        continue;
      }

      // Respect Focus Stack filter
      if (_selectedStackFilter != 'ALL') {
        if (!matchedStackIds.contains(_selectedStackFilter)) continue;
      } else {
        // Keep only stackIds that are actually visible in Column 2
        matchedStackIds.retainWhere((sid) =>
            visibleStackIds.contains(sid) || sid.startsWith('unmanaged::'));
      }

      final scheme = (r['scheme'] ?? '').toString().toLowerCase();
      final isTls = scheme.isNotEmpty
          ? scheme == 'https'
          : (!rawHost.startsWith('http://') && !rawHost.endsWith(':80'));

      nodes.add(_TopoIngressNode(
        id: 'ingress-caddy-$i',
        host: primaryHost,
        cleanHost: primaryHost,
        upstreams: upstreams,
        targetContainerIds: matchedContainerIds,
        targetStackIds: matchedStackIds,
        targetHostNodeId: matchedHostNodeId,
        isTls: isTls,
      ));
    }

    // 2. Compose/Constraint-declared ingress hosts on visible stacks not yet in live Caddy routes
    for (final entry in visibleHostToServices.entries) {
      final hostKey = entry.key;
      if (!seenHosts.add(hostKey)) continue;

      final matchedContainerIds = <String>[];
      final matchedStackIds = <String>{};
      String matchedHostNodeId = '';
      final derivedUpstreams = <String>[];

      for (final svc in entry.value) {
        matchedStackIds.add(svc.stackId);
        for (final c in allContainers) {
          if ((c.serviceId.isNotEmpty && c.serviceId == svc.id) ||
              (c.stackId == svc.stackId && c.serviceName == svc.name)) {
            if (!matchedContainerIds.contains(c.id)) {
              matchedContainerIds.add(c.id);
            }
            if (matchedHostNodeId.isEmpty) matchedHostNodeId = c.nodeId;
            if (c.ip.isNotEmpty) {
              derivedUpstreams.add(c.ip);
            } else if (c.ports.isNotEmpty) {
              derivedUpstreams.add(c.ports.first);
            }
          }
        }
      }

      if (_selectedStackFilter != 'ALL' &&
          !matchedStackIds.contains(_selectedStackFilter)) {
        continue;
      }

      nodes.add(_TopoIngressNode(
        id: 'ingress-label-$hostKey',
        host: hostKey,
        cleanHost: hostKey,
        upstreams: derivedUpstreams.toSet().toList(),
        targetContainerIds: matchedContainerIds,
        targetStackIds: matchedStackIds,
        targetHostNodeId: matchedHostNodeId,
        isTls: true,
      ));
    }

    return nodes;
  }

  /// Computes smart anchor points and Bézier control points between two rects
  /// so edges connect cleanly regardless of relative position.
  _TopoEdge _buildSmartEdge({
    required String fromId,
    required String toId,
    required Rect fromRect,
    required Rect toRect,
    required Color color,
    required String label,
    required bool dashed,
    required String kind,
    bool forceHorizontalRightToLeft = false,
  }) {
    late final Offset from;
    late final Offset to;
    late final Offset c1;
    late final Offset c2;

    if (forceHorizontalRightToLeft) {
      from = Offset(fromRect.right, fromRect.center.dy);
      to = Offset(toRect.left, toRect.center.dy);
      final dx = (to.dx - from.dx).abs();
      final ctrl = math.max(44.0, dx * 0.44);
      c1 = Offset(from.dx + ctrl, from.dy);
      c2 = Offset(to.dx - ctrl, to.dy);
    } else if (toRect.left >= fromRect.right - 8) {
      from = Offset(fromRect.right, fromRect.center.dy);
      to = Offset(toRect.left, toRect.center.dy);
      final dx = (to.dx - from.dx).abs();
      final ctrl = math.max(36.0, dx * 0.45);
      c1 = Offset(from.dx + ctrl, from.dy);
      c2 = Offset(to.dx - ctrl, to.dy);
    } else if (fromRect.left >= toRect.right - 8) {
      from = Offset(fromRect.left, fromRect.center.dy);
      to = Offset(toRect.right, toRect.center.dy);
      final dx = (from.dx - to.dx).abs();
      final ctrl = math.max(36.0, dx * 0.45);
      c1 = Offset(from.dx - ctrl, from.dy);
      c2 = Offset(to.dx + ctrl, to.dy);
    } else if (toRect.top >= fromRect.bottom - 8) {
      from = Offset(fromRect.center.dx, fromRect.bottom);
      to = Offset(toRect.center.dx, toRect.top);
      final dy = (to.dy - from.dy).abs();
      final ctrl = math.max(32.0, dy * 0.42);
      c1 = Offset(from.dx, from.dy + ctrl);
      c2 = Offset(to.dx, to.dy - ctrl);
    } else {
      from = Offset(fromRect.center.dx, fromRect.top);
      to = Offset(toRect.center.dx, toRect.bottom);
      final dy = (from.dy - to.dy).abs();
      final ctrl = math.max(32.0, dy * 0.42);
      c1 = Offset(from.dx, from.dy - ctrl);
      c2 = Offset(to.dx, to.dy + ctrl);
    }

    return _TopoEdge(
      fromId: fromId,
      toId: toId,
      from: from,
      to: to,
      c1: c1,
      c2: c2,
      color: color,
      label: label,
      dashed: dashed,
      kind: kind,
    );
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

    // 1. Prepare canonical Centurion node list
    final nodesList = widget.state.nodes.isNotEmpty
        ? widget.state.nodes
        : [
            Node(
              id: 'node-local-manager',
              ip: '127.0.0.1',
              role: 'manager',
              status: 'active',
            ),
          ];

    // 2. Filter visible stacks (matches Legions -> Deployed 1:1 when Base Stacks is OFF)
    final allStacks = widget.state.stacks;
    final baseStackCount = allStacks.where(widget.isBaseStackFn).length;
    final stackById = {for (final s in allStacks) s.id: s};
    final serviceById = {for (final s in widget.state.services) s.id: s};

    final visibleStacks = allStacks.where((s) {
      if (_selectedStackFilter != 'ALL') {
        return s.id == _selectedStackFilter;
      }
      if (!_showBaseStacks && widget.isBaseStackFn(s)) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final visibleStackIds = visibleStacks.map((s) => s.id).toSet();

    // Assign a deterministic accent color per visible stack
    final stackColorById = <String, Color>{};
    for (int i = 0; i < visibleStacks.length; i++) {
      stackColorById[visibleStacks[i].id] =
          _kStackPalette[i % _kStackPalette.length];
    }

    // 3. Build container nodes from managed tasks
    final containers = <_TopoContainerNode>[];
    final representedServiceIds = <String>{};
    final representedStackIds = <String>{};

    for (final task in widget.state.tasks) {
      final svc = serviceById[task.serviceId];
      if (svc == null) continue;
      final stack = stackById[svc.stackId];
      if (stack == null) continue;
      if (!visibleStackIds.contains(stack.id)) continue;

      final resolvedNodeId = _resolveNodeId(task.nodeId, nodesList);
      representedServiceIds.add(svc.id);
      representedStackIds.add(stack.id);

      containers.add(_TopoContainerNode(
        id: 'task-${task.id}',
        name: task.containerName.isNotEmpty ? task.containerName : svc.name,
        serviceId: svc.id,
        serviceName: svc.name,
        stackId: stack.id,
        stackName: stack.name,
        stackColor: stackColorById[stack.id] ?? _kStackPalette.first,
        nodeId: resolvedNodeId,
        image: svc.image,
        status: task.status,
        ip: task.containerIp,
        ports: svc.ports,
        cpuPercent: task.cpuPercent,
        memUsedBytes: task.memUsedBytes,
        isBase: widget.isBaseStackFn(stack),
      ));
    }

    // 3b. Ensure EVERY visible stack & service appears even if it currently has 0 tasks
    for (final stack in visibleStacks) {
      final color = stackColorById[stack.id] ?? _kStackPalette.first;
      final stackServices =
          widget.state.services.where((s) => s.stackId == stack.id).toList();
      if (stackServices.isNotEmpty) {
        for (final svc in stackServices) {
          if (representedServiceIds.contains(svc.id)) continue;
          final targetNodeId = _inferNodeIdForService(svc, stack, nodesList);
          representedStackIds.add(stack.id);
          containers.add(_TopoContainerNode(
            id: 'svc-placeholder-${svc.id}',
            name: svc.name,
            serviceId: svc.id,
            serviceName: svc.name,
            stackId: stack.id,
            stackName: stack.name,
            stackColor: color,
            nodeId: targetNodeId,
            image: svc.image.isNotEmpty ? svc.image : 'No active container',
            status: 'stopped',
            ip: '',
            ports: svc.ports,
            cpuPercent: 0,
            memUsedBytes: 0,
            isBase: widget.isBaseStackFn(stack),
            isPlaceholder: true,
          ));
        }
      } else if (!representedStackIds.contains(stack.id)) {
        final targetNodeId = _resolveNodeId(stack.nodeId, nodesList);
        containers.add(_TopoContainerNode(
          id: 'stack-placeholder-${stack.id}',
          name: stack.name,
          serviceName: stack.name,
          stackId: stack.id,
          stackName: stack.name,
          stackColor: color,
          nodeId: targetNodeId,
          image: 'No services/tasks deployed',
          status: 'stopped',
          ip: '',
          ports: const [],
          cpuPercent: 0,
          memUsedBytes: 0,
          isBase: widget.isBaseStackFn(stack),
          isPlaceholder: true,
        ));
      }
    }

    // 4. Optionally include Unmanaged / Discovered containers (when Unmanaged chip is ON)
    final unmanagedGroupNames = <String, String>{};
    if (_showUnmanaged && _selectedStackFilter == 'ALL') {
      for (final u in _unmanagedContainers) {
        final name = (u['name'] ?? '').toString();
        final rawNodeId = (u['node_id'] ?? u['node_ip'] ?? '').toString();
        final resolvedNodeId = _resolveNodeId(rawNodeId, nodesList);
        final groupName = (u['group_name'] ?? 'standalone').toString();
        final groupStackId = 'unmanaged::$groupName';
        final displayGroupName = groupName == 'standalone'
            ? 'Unmanaged (Standalone)'
            : 'Unmanaged · $groupName';
        unmanagedGroupNames[groupStackId] = displayGroupName;
        final portsStr = (u['ports'] ?? '').toString();
        containers.add(_TopoContainerNode(
          id: 'unmanaged-$resolvedNodeId-$name',
          name: name,
          serviceName: (u['compose_service'] ?? name).toString(),
          stackId: groupStackId,
          stackName: displayGroupName,
          stackColor: const Color(0xFFF59E0B),
          nodeId: resolvedNodeId,
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

    // 5. Build Stack Nodes for Column 2 (exact match to visibleStacks + optional unmanaged groups)
    final stackNodes = <_TopoStackNode>[];
    for (final stack in visibleStacks) {
      final stackCtrs = containers.where((c) => c.stackId == stack.id).toList();
      final stackSvcs =
          widget.state.services.where((s) => s.stackId == stack.id).toList();
      final hosts = stackCtrs.map((c) => c.nodeId).toSet().toList()..sort();
      stackNodes.add(_TopoStackNode(
        id: 'stack-${stack.id}',
        stackId: stack.id,
        name: stack.name,
        accentColor: stackColorById[stack.id] ?? _kStackPalette.first,
        totalServices: stackSvcs.length,
        runningContainers: stackCtrs.where((c) => c.isRunning).length,
        totalContainers: stackCtrs.length,
        hostNodeIds: hosts,
        containerIds: stackCtrs.map((c) => c.id).toList(),
        isBase: widget.isBaseStackFn(stack),
      ));
    }
    for (final entry in unmanagedGroupNames.entries) {
      final groupCtrs =
          containers.where((c) => c.stackId == entry.key).toList();
      final hosts = groupCtrs.map((c) => c.nodeId).toSet().toList()..sort();
      stackNodes.add(_TopoStackNode(
        id: 'stack-${entry.key}',
        stackId: entry.key,
        name: entry.value,
        accentColor: const Color(0xFFF59E0B),
        totalServices: groupCtrs.length,
        runningContainers: groupCtrs.where((c) => c.isRunning).length,
        totalContainers: groupCtrs.length,
        hostNodeIds: hosts,
        containerIds: groupCtrs.map((c) => c.id).toList(),
        isUnmanaged: true,
      ));
    }

    // 6. Collect Ingress nodes (Column 1)
    final ingressNodes = _collectIngressNodes(
      allStacks: allStacks,
      visibleStacks: visibleStacks,
      allServices: widget.state.services,
      allContainers: containers,
      nodesList: nodesList,
    );

    // 7. Group containers into Centurion Host boxes (Column 3, zero orphaned containers)
    final hostBoxes = <_TopoHostBox>[];
    final knownNodeIds = <String>{};
    for (final n in nodesList) {
      knownNodeIds.add(n.id);
      final hostContainers = containers.where((c) => c.nodeId == n.id).toList()
        ..sort((a, b) {
          final cmp = a.stackName.compareTo(b.stackName);
          return cmp != 0 ? cmp : a.name.compareTo(b.name);
        });
      hostBoxes.add(_TopoHostBox(
        node: n,
        containers: hostContainers,
        discoveryWarning: _unmanagedNodeErrors[n.id],
      ));
    }

    final orphanNodeIds = containers
        .map((c) => c.nodeId)
        .where((nid) => !knownNodeIds.contains(nid))
        .toSet();
    for (final orphanId in orphanNodeIds) {
      final orphanContainers =
          containers.where((c) => c.nodeId == orphanId).toList()
            ..sort((a, b) {
              final cmp = a.stackName.compareTo(b.stackName);
              return cmp != 0 ? cmp : a.name.compareTo(b.name);
            });
      hostBoxes.add(_TopoHostBox(
        node: Node(
          id: orphanId.isNotEmpty ? orphanId : 'unknown-node',
          ip: 'Unregistered host',
          role: 'worker',
          status: 'offline',
        ),
        containers: orphanContainers,
        isSynthetic: true,
      ));
    }

    // 8. Compute deterministic 3-column layout coordinates
    const double leftMargin = 28;
    const double topMargin = 28;

    // Column 1: Ingress Routes
    const double ingressColX = leftMargin;
    const double ingressCardW = 236;
    const double ingressCardH = 74;
    const double ingressGapY = 16;

    // Column 2: Legions (Stacks)
    const double stackColX = ingressColX + ingressCardW + 96;
    const double stackCardW = 240;
    const double stackCardH = 84;
    const double stackGapY = 18;

    // Column 3: Centurion Hosts & Containers
    const double hostColX = stackColX + stackCardW + 108;
    const double hostWidth = 636;
    const double hostHeaderH = 68;
    const double containerCardW = 284;
    const double containerCardH = 88;
    const double containerGapX = 20;
    const double containerGapY = 18;
    const double hostPadX = 24;
    const double hostPadBottom = 22;
    const double hostGapY = 32;

    // Layout Column 1: Ingress cards
    double ingressY = topMargin + 56;
    for (final ing in ingressNodes) {
      ing.rect =
          Rect.fromLTWH(ingressColX, ingressY, ingressCardW, ingressCardH);
      ingressY += ingressCardH + ingressGapY;
    }

    // Layout Column 2: Stack cards
    double stackY = topMargin + 56;
    for (final st in stackNodes) {
      st.rect = Rect.fromLTWH(stackColX, stackY, stackCardW, stackCardH);
      stackY += stackCardH + stackGapY;
    }

    // Layout Column 3: Host boxes & their containers
    double hostY = topMargin + 56;
    final hostBoxByNodeId = <String, _TopoHostBox>{};
    for (final box in hostBoxes) {
      final count = box.containers.length;
      final rows = count == 0 ? 1 : ((count + 1) ~/ 2);
      final boxH = hostHeaderH +
          (count == 0
              ? 64.0
              : rows * containerCardH + (rows - 1) * containerGapY) +
          hostPadBottom;

      box.rect = Rect.fromLTWH(hostColX, hostY, hostWidth, boxH);
      hostBoxByNodeId[box.node.id] = box;

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
    final maxColY = math.max(hostY, math.max(stackY, ingressY));
    final canvasHeight = maxColY + 48;

    // 9. Build 3-tier topology edges
    final edges = <_TopoEdge>[];
    final containerById = {for (final c in containers) c.id: c};
    final stackNodeByStackId = {for (final s in stackNodes) s.stackId: s};
    final stackNodeById = {for (final s in stackNodes) s.id: s};

    // 9a. Column 1 -> Column 2: Ingress -> Stack(s) (or fallback to Centurion Host if unmatched)
    for (final ing in ingressNodes) {
      final matchedStackNodes = ing.targetStackIds
          .map((sid) => stackNodeByStackId[sid])
          .whereType<_TopoStackNode>()
          .toList();

      if (matchedStackNodes.isNotEmpty) {
        for (final stNode in matchedStackNodes) {
          edges.add(_buildSmartEdge(
            fromId: ing.id,
            toId: stNode.id,
            fromRect: ing.rect,
            toRect: stNode.rect,
            color: const Color(0xFFF97316),
            label: ing.isTls ? 'HTTPS' : 'HTTP',
            dashed: false,
            kind: 'ingress',
            forceHorizontalRightToLeft: true,
          ));
        }
      } else if (hostBoxes.isNotEmpty) {
        final targetBox =
            hostBoxByNodeId[ing.targetHostNodeId] ?? hostBoxes.first;
        final headerAnchorRect = Rect.fromLTWH(
          targetBox.rect.left,
          targetBox.rect.top + 10,
          targetBox.rect.width,
          44,
        );
        edges.add(_buildSmartEdge(
          fromId: ing.id,
          toId: 'host-${targetBox.node.id}',
          fromRect: ing.rect,
          toRect: headerAnchorRect,
          color: const Color(0xFFF97316).withValues(alpha: 0.7),
          label: 'PROXY',
          dashed: true,
          kind: 'ingress',
          forceHorizontalRightToLeft: true,
        ));
      }
    }

    // 9b. Column 2 -> Column 3: Stack -> EVERY Container belonging to that Stack (across Manager & Workers!)
    for (final stNode in stackNodes) {
      for (final cid in stNode.containerIds) {
        final target = containerById[cid];
        if (target == null) continue;
        edges.add(_buildSmartEdge(
          fromId: stNode.id,
          toId: target.id,
          fromRect: stNode.rect,
          toRect: target.rect,
          color: stNode.accentColor,
          label: target.nodeId,
          dashed: target.isPlaceholder,
          kind: 'stack',
          forceHorizontalRightToLeft: true,
        ));
      }
    }

    // 9c. Column 3 -> Column 3: Inter-service dependency edges (NET / MESH)
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
              if (fc.id == tc.id) continue;
              final crossHost = fc.nodeId != tc.nodeId;
              edges.add(_buildSmartEdge(
                fromId: fc.id,
                toId: tc.id,
                fromRect: fc.rect,
                toRect: tc.rect,
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

    // Compute transitive highlight set when a node is selected (so clicking Ingress highlights Stack + Containers too!)
    final highlightedNodeIds = <String>{};
    if (_selectedNodeId != null) {
      highlightedNodeIds.add(_selectedNodeId!);
      // Direct neighbors
      for (final e in edges) {
        if (e.fromId == _selectedNodeId) highlightedNodeIds.add(e.toId);
        if (e.toId == _selectedNodeId) highlightedNodeIds.add(e.fromId);
      }
      // If an Ingress was selected, also highlight its Stack -> Container edges
      if (ingressNodes.any((i) => i.id == _selectedNodeId)) {
        final stackNeighbors = highlightedNodeIds
            .where((id) => stackNodeById.containsKey(id))
            .toList();
        for (final sid in stackNeighbors) {
          for (final e in edges) {
            if (e.fromId == sid) highlightedNodeIds.add(e.toId);
          }
        }
      }
    }

    // Selected node for inspector side panel
    final selectedContainer =
        _selectedNodeId != null ? containerById[_selectedNodeId] : null;
    final selectedStack =
        _selectedNodeId != null ? stackNodeById[_selectedNodeId] : null;
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
                        '${hostBoxes.length} Centurions · ${visibleStacks.length} Stacks · $runningContainers/${containers.length} Containers · ${ingressNodes.length} Ingress Routes · ${edges.length} Links',
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
                    label: Text(
                      baseStackCount > 0
                          ? 'Base Stacks ($baseStackCount)'
                          : 'Base Stacks',
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: _showBaseStacks,
                    onSelected: (v) => setState(() => _showBaseStacks = v),
                  ),
                  FilterChip(
                    label: Text(
                      _unmanagedContainers.isNotEmpty
                          ? 'Unmanaged (${_unmanagedContainers.length})'
                          : 'Unmanaged',
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: _showUnmanaged,
                    onSelected: (v) => setState(() => _showUnmanaged = v),
                  ),
                  FilterChip(
                    label: const Text('Service Links',
                        style: TextStyle(fontSize: 12)),
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
              _legendDot(const Color(0xFFF97316), 'Ingress ➔ Stack Route'),
              _legendDot(const Color(0xFF6366F1), 'Stack ➔ Container Placement'),
              _legendDot(const Color(0xFF38BDF8), 'Internal Stack Network Link'),
              _legendDot(const Color(0xFFA855F7), 'Cross-Host Mesh Link'),
              _legendDot(const Color(0xFF10B981), 'Running Container'),
              _legendDot(const Color(0xFF94A3B8), 'Stopped / No Active Task'),
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
                                // Layer 1: Subtle architectural grid background
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _TopologyGridPainter(
                                      isDark: isDark,
                                    ),
                                  ),
                                ),

                                // Layer 2: Centurion Host Enclosure Boxes (Column 3)
                                for (final box in hostBoxes)
                                  Positioned.fromRect(
                                    rect: box.rect,
                                    child: _buildHostEnclosure(
                                        box, theme, isDark),
                                  ),

                                // Layer 3: Curved Topology Edges (drawn ABOVE host enclosures)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _ClusterTopologyEdgesPainter(
                                        edges: edges,
                                        selectedId: _selectedNodeId,
                                        highlightedNodeIds: highlightedNodeIds,
                                        isDark: isDark,
                                      ),
                                    ),
                                  ),
                                ),

                                // Layer 4: Column Headers, Ingress Cards, Stack Cards & Container Cards
                                // Column 1 Header: Ingress
                                Positioned(
                                  left: ingressColX,
                                  top: topMargin,
                                  width: ingressCardW,
                                  child: _buildColumnHeader(
                                    icon: Icons.alt_route,
                                    title: '1. INGRESS / CADDY',
                                    subtitle:
                                        '${ingressNodes.length} routes · ${widget.state.dnsRecords.length} DNS',
                                    color: const Color(0xFFF97316),
                                    isDark: isDark,
                                  ),
                                ),

                                // Column 2 Header: Stacks
                                Positioned(
                                  left: stackColX,
                                  top: topMargin,
                                  width: stackCardW,
                                  child: _buildColumnHeader(
                                    icon: Icons.layers_outlined,
                                    title: '2. LEGIONS (STACKS)',
                                    subtitle:
                                        '${visibleStacks.length} deployed${_showUnmanaged && unmanagedGroupNames.isNotEmpty ? ' + ${unmanagedGroupNames.length} unmanaged' : ''}',
                                    color: const Color(0xFF6366F1),
                                    isDark: isDark,
                                  ),
                                ),

                                // Column 3 Header: Centurion Hosts
                                Positioned(
                                  left: hostColX,
                                  top: topMargin,
                                  width: hostWidth,
                                  child: _buildColumnHeader(
                                    icon: Icons.dns_outlined,
                                    title: '3. CENTURION HOSTS & CONTAINERS',
                                    subtitle:
                                        '${hostBoxes.length} nodes · $runningContainers/${containers.length} containers running',
                                    color: const Color(0xFF38BDF8),
                                    isDark: isDark,
                                  ),
                                ),

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
                                        'No active Ingress routes for the visible stacks.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.55),
                                        ),
                                      ),
                                    ),
                                  ),

                                // Column 1: Ingress Route Cards
                                for (final ing in ingressNodes)
                                  Positioned.fromRect(
                                    rect: ing.rect,
                                    child: _buildIngressCard(
                                      ing,
                                      theme,
                                      isDark,
                                      highlightedNodeIds,
                                    ),
                                  ),

                                // Column 2: Stack Cards
                                for (final st in stackNodes)
                                  Positioned.fromRect(
                                    rect: st.rect,
                                    child: _buildStackCard(
                                      st,
                                      theme,
                                      isDark,
                                      highlightedNodeIds,
                                    ),
                                  ),

                                // Column 3: Container Cards inside Hosts
                                for (final box in hostBoxes)
                                  for (final c in box.containers)
                                    Positioned.fromRect(
                                      rect: c.rect,
                                      child: _buildContainerCard(
                                        c,
                                        theme,
                                        isDark,
                                        highlightedNodeIds,
                                      ),
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
                if (selectedContainer != null ||
                    selectedStack != null ||
                    selectedIngress != null) ...[
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 300,
                    child: _buildInspectorPanel(
                      theme: theme,
                      isDark: isDark,
                      container: selectedContainer,
                      stackNode: selectedStack,
                      ingress: selectedIngress,
                      edges: edges,
                      containerById: containerById,
                      stackNodeById: stackNodeById,
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
                  overflow: TextOverflow.ellipsis,
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
    Set<String> highlightedNodeIds,
  ) {
    final isSelected = _selectedNodeId == ing.id;
    final isDimmed =
        _selectedNodeId != null && !highlightedNodeIds.contains(ing.id);
    const accent = Color(0xFFF97316);
    final linkedCount = ing.targetContainerIds.length;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: isDimmed ? 0.32 : 1.0,
      child: GestureDetector(
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
                  : accent.withValues(alpha: isDark ? 0.45 : 0.35),
              width: isSelected ? 2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isSelected ? 0.28 : 0.08),
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
                  if (linkedCount > 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${linkedCount}x',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                  InkWell(
                    onTap: () => _openHostUrl(ing.host),
                    child:
                        const Icon(Icons.open_in_new, size: 13, color: accent),
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
      ),
    );
  }

  Widget _buildStackCard(
    _TopoStackNode st,
    ThemeData theme,
    bool isDark,
    Set<String> highlightedNodeIds,
  ) {
    final isSelected = _selectedNodeId == st.id;
    final isDimmed =
        _selectedNodeId != null && !highlightedNodeIds.contains(st.id);
    final accent = st.accentColor;
    final allRunning =
        st.totalContainers > 0 && st.runningContainers == st.totalContainers;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: isDimmed ? 0.32 : 1.0,
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedNodeId = isSelected ? null : st.id;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? accent
                  : accent.withValues(alpha: isDark ? 0.55 : 0.45),
              width: isSelected ? 2.2 : 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isSelected ? 0.28 : 0.08),
                blurRadius: isSelected ? 12 : 6,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      st.isUnmanaged ? Icons.inventory_2_outlined : Icons.layers,
                      size: 13,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      st.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: allRunning
                          ? const Color(0xFF10B981)
                          : (st.runningContainers > 0
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF94A3B8)),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${st.runningContainers}/${st.totalContainers} ctrs',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      st.hostNodeIds.isNotEmpty
                          ? st.hostNodeIds.join(', ')
                          : 'unassigned',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'Courier New',
                        color: accent.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
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

  Widget _buildHostEnclosure(
    _TopoHostBox box,
    ThemeData theme,
    bool isDark,
  ) {
    final node = box.node;
    final isManager = node.role.toLowerCase() == 'manager';
    final isActive = !box.isSynthetic && node.status.toLowerCase() == 'active';
    final accent = box.isSynthetic
        ? const Color(0xFF94A3B8)
        : (isManager ? const Color(0xFFF97316) : const Color(0xFF38BDF8));

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
                    color:
                        isActive ? const Color(0xFF10B981) : Colors.redAccent,
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
                    box.isSynthetic ? 'OFFLINE' : node.role.toUpperCase(),
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
                if (box.discoveryWarning != null) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message:
                        'Unmanaged container scan error on ${node.id}: ${box.discoveryWarning}',
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ],
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
    Set<String> highlightedNodeIds,
  ) {
    final isSelected = _selectedNodeId == c.id;
    final isDimmed =
        _selectedNodeId != null && !highlightedNodeIds.contains(c.id);
    final statusColor = c.isUnmanaged
        ? const Color(0xFFF59E0B)
        : (c.isPlaceholder
            ? const Color(0xFF94A3B8)
            : (c.isRunning ? const Color(0xFF10B981) : Colors.redAccent));

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: isDimmed ? 0.3 : 1.0,
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedNodeId = isSelected ? null : c.id;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isDark
                ? (c.isPlaceholder
                    ? const Color(0xFF172033)
                    : const Color(0xFF1E293B))
                : (c.isPlaceholder
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? c.stackColor
                  : c.stackColor.withValues(alpha: isDark ? 0.5 : 0.4),
              width: isSelected ? 2.2 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: c.stackColor.withValues(alpha: 0.28),
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
                  const SizedBox(width: 6),
                  Flexible(
                    flex: 0,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 112),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: c.stackColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          c.stackName,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: c.stackColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
                  if (c.isPlaceholder) ...[
                    const Icon(Icons.pause_circle_outline,
                        size: 11, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    const Text(
                      'STOPPED',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else if (c.ip.isNotEmpty) ...[
                    Icon(Icons.lan_outlined,
                        size: 11,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55)),
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
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
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

  Widget _buildInspectorPanel({
    required ThemeData theme,
    required bool isDark,
    _TopoContainerNode? container,
    _TopoStackNode? stackNode,
    _TopoIngressNode? ingress,
    required List<_TopoEdge> edges,
    required Map<String, _TopoContainerNode> containerById,
    required Map<String, _TopoStackNode> stackNodeById,
    required List<_TopoIngressNode> ingressNodes,
  }) {
    final selectedId = container?.id ?? stackNode?.id ?? ingress?.id;
    final relatedEdges = edges.where((e) {
      return e.fromId == selectedId || e.toId == selectedId;
    }).toList();

    String resolveLabel(String id) {
      if (containerById.containsKey(id)) return containerById[id]!.name;
      if (stackNodeById.containsKey(id)) return stackNodeById[id]!.name;
      final ing = ingressNodes.where((i) => i.id == id).firstOrNull;
      if (ing != null) return ing.host;
      return id;
    }

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
                container != null
                    ? Icons.view_in_ar
                    : (stackNode != null ? Icons.layers : Icons.alt_route),
                color: stackNode?.accentColor ?? const Color(0xFFF97316),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  container != null
                      ? 'Container Inspector'
                      : (stackNode != null
                          ? 'Stack Inspector'
                          : 'Ingress Inspector'),
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
            _inspectorRow(
              'Status',
              container.isPlaceholder
                  ? 'STOPPED (NO ACTIVE TASK)'
                  : container.status.toUpperCase(),
            ),
            _inspectorRow('Image', container.image),
            if (container.ip.isNotEmpty)
              _inspectorRow('Internal IP', container.ip),
            if (container.ports.isNotEmpty)
              _inspectorRow('Ports', container.ports.join('\n')),
            _inspectorRow(
              'Type',
              container.isUnmanaged
                  ? 'Unmanaged'
                  : (container.isPlaceholder ? 'Managed (Stopped)' : 'Managed'),
            ),
            const SizedBox(height: 10),
            if (!container.isUnmanaged &&
                !container.isPlaceholder &&
                widget.onViewContainerLogs != null)
              FilledButton.tonalIcon(
                onPressed: () => widget.onViewContainerLogs!(container.name),
                icon: const Icon(Icons.receipt_long, size: 16),
                label: const Text('View Container Logs'),
              ),
            if (!container.isUnmanaged &&
                widget.onViewStackContainers != null) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () =>
                    widget.onViewStackContainers!(container.stackName),
                icon: const Icon(Icons.layers_outlined, size: 16),
                label: const Text('Open Stack Containers'),
              ),
            ],
          ] else if (stackNode != null) ...[
            _inspectorRow('Stack Name', stackNode.name),
            _inspectorRow('Services', '${stackNode.totalServices}'),
            _inspectorRow(
              'Containers',
              '${stackNode.runningContainers} running / ${stackNode.totalContainers} total',
            ),
            _inspectorRow(
              'Deployed On Hosts',
              stackNode.hostNodeIds.isNotEmpty
                  ? stackNode.hostNodeIds.join(', ')
                  : 'Unassigned',
            ),
            if (!stackNode.isUnmanaged &&
                widget.onViewStackContainers != null) ...[
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () => widget.onViewStackContainers!(stackNode.name),
                icon: const Icon(Icons.layers_outlined, size: 16),
                label: const Text('Open Stack Containers'),
              ),
            ],
          ] else if (ingress != null) ...[
            _inspectorRow('Domain / Host', ingress.host),
            _inspectorRow('Protocol', ingress.isTls ? 'HTTPS (TLS)' : 'HTTP'),
            _inspectorRow(
              'Upstreams',
              ingress.upstreams.isNotEmpty
                  ? ingress.upstreams.join('\n')
                  : 'caddy-proxy',
            ),
            if (ingress.targetHostNodeId.isNotEmpty)
              _inspectorRow('Target Host', ingress.targetHostNodeId),
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
                      final fromLabel = resolveLabel(e.fromId);
                      final toLabel = resolveLabel(e.toId);
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

/// CustomPainter for Layer 1: subtle architectural grid background.
class _TopologyGridPainter extends CustomPainter {
  final bool isDark;

  _TopologyGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
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
  }

  @override
  bool shouldRepaint(covariant _TopologyGridPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

/// CustomPainter for Layer 3: curved Bézier topology connections drawn ABOVE host enclosures
/// with true tangent-aligned arrowheads and transitive selection highlighting.
class _ClusterTopologyEdgesPainter extends CustomPainter {
  final List<_TopoEdge> edges;
  final String? selectedId;
  final Set<String> highlightedNodeIds;
  final bool isDark;

  _ClusterTopologyEdgesPainter({
    required this.edges,
    required this.selectedId,
    required this.highlightedNodeIds,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final isHighlighted = selectedId == null ||
          (highlightedNodeIds.contains(edge.fromId) &&
              highlightedNodeIds.contains(edge.toId));
      final alpha = isHighlighted ? 0.88 : 0.12;
      final strokeWidth = (selectedId != null && isHighlighted) ? 2.6 : 1.8;

      final paint = Paint()
        ..color = edge.color.withValues(alpha: alpha)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path()
        ..moveTo(edge.from.dx, edge.from.dy)
        ..cubicTo(
          edge.c1.dx,
          edge.c1.dy,
          edge.c2.dx,
          edge.c2.dy,
          edge.to.dx,
          edge.to.dy,
        );

      if (edge.dashed) {
        _drawDashedPath(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }

      // Draw directional arrowhead aligned to arrival tangent (c2 -> to)
      final angle = math.atan2(
        edge.to.dy - edge.c2.dy,
        edge.to.dx - edge.c2.dx,
      );
      const arrowLen = 8.5;
      const arrowSpread = 0.5;
      final p1 = Offset(
        edge.to.dx - arrowLen * math.cos(angle - arrowSpread),
        edge.to.dy - arrowLen * math.sin(angle - arrowSpread),
      );
      final p2 = Offset(
        edge.to.dx - arrowLen * math.cos(angle + arrowSpread),
        edge.to.dy - arrowLen * math.sin(angle + arrowSpread),
      );

      final arrowPaint = Paint()
        ..color = edge.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      final arrowPath = Path()
        ..moveTo(edge.to.dx, edge.to.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
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
  bool shouldRepaint(covariant _ClusterTopologyEdgesPainter oldDelegate) {
    return oldDelegate.edges != edges ||
        oldDelegate.selectedId != selectedId ||
        oldDelegate.highlightedNodeIds != highlightedNodeIds ||
        oldDelegate.isDark != isDark;
  }
}

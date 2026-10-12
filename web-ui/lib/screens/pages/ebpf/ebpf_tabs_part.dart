part of '../ebpf_page.dart';

extension _EbpfTabsExt on _EbpfPageState {

  // ── Tab 0: Flows Stream ───────────────────────────────────────────────────

  Widget _buildFlowsTab(ThemeData theme) {
    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              // Protocol Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _protocols.map((p) {
                    final selected = _selectedProtocol == p;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: selected,
                        label: Text(p, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.bold : null)),
                        selectedColor: const Color(0xFF06B6D4).withValues(alpha: 0.25),
                        checkmarkColor: const Color(0xFF06B6D4),
                        onSelected: (val) {
                          _updateState(() {
                            _selectedProtocol = val ? p : 'ALL';
                          });
                          _fetchFlowsAndStatsSilently();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(width: 12),
              Container(width: 1, height: 24, color: theme.dividerColor),
              const SizedBox(width: 12),

              // Status Dropdown
              DropdownButton<String>(
                value: _selectedStatus,
                underline: const SizedBox(),
                isDense: true,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Health', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'healthy', child: Text('Healthy 🟢', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'warning', child: Text('Warning 🟡', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'error', child: Text('Errors 🔴', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'ERRORS', child: Text('Any Issues ⚠️', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    _updateState(() => _selectedStatus = val);
                    _fetchFlowsAndStatsSilently();
                  }
                },
              ),

              const SizedBox(width: 16),

              // Search Text Field
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search container, IP, method or path...',
                      hintStyle: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () {
                                _searchCtrl.clear();
                                _fetchFlowsAndStatsSilently();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _fetchFlowsAndStatsSilently(),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Limit Dropdown
              DropdownButton<int>(
                value: _limit,
                underline: const SizedBox(),
                isDense: true,
                items: const [
                  DropdownMenuItem(value: 25, child: Text('25 rows', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 50, child: Text('50 rows', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 100, child: Text('100 rows', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 200, child: Text('200 rows', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    _updateState(() => _limit = val);
                    _fetchFlowsAndStatsSilently();
                  }
                },
              ),
            ],
          ),
        ),

        // Flows Table
        Expanded(
          child: _flows.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.radar, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(
                        'No captured network flows matching criteria.',
                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _openSimulationDialog,
                        icon: const Icon(Icons.bolt, size: 16),
                        label: const Text('Inject Test Traffic'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _flows.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.2)),
                  itemBuilder: (ctx, idx) {
                    final flow = _flows[idx];
                    return _buildFlowRow(flow, theme);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFlowRow(EbpfFlow flow, ThemeData theme) {
    final timeStr = "${flow.timestamp.hour.toString().padLeft(2, '0')}:${flow.timestamp.minute.toString().padLeft(2, '0')}:${flow.timestamp.second.toString().padLeft(2, '0')}";
    final protoColor = _getProtocolColor(flow.protocol);
    final isErr = flow.status == 'error';
    final isWarn = flow.status == 'warning';

    Color statusColor = const Color(0xFF10B981);
    String statusLabel = 'HEALTHY';
    if (isErr) {
      statusColor = const Color(0xFFEF4444);
      statusLabel = flow.statusCode > 0 ? '${flow.statusCode} ERR' : 'DROPPED';
    } else if (isWarn) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = flow.statusCode > 0 ? '${flow.statusCode} WARN' : 'SLOW';
    } else if (flow.statusCode > 0) {
      statusLabel = '${flow.statusCode} OK';
    }

    return InkWell(
      onTap: () => _openFlowDetails(flow),
      hoverColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            // Time
            Text(
              timeStr,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 14),

            // Protocol Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: protoColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: protoColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                flow.protocol,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: protoColor),
              ),
            ),
            const SizedBox(width: 14),

            // Source Container & IP
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          flow.sourceName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          "${flow.sourceIp}:${flow.sourcePort}",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
            ),

            // Destination Container & IP
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Icon(Icons.cloud_download_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          flow.destName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          "${flow.destIp}:${flow.destPort}",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Target Method / Path
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    if (flow.method.isNotEmpty) ...[
                      Text(
                        flow.method,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: flow.method == 'POST' ? Colors.blueAccent : Colors.tealAccent,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        flow.path.isNotEmpty ? flow.path : '${flow.destPort}/tcp',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Latency (RTT)
            SizedBox(
              width: 75,
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 13,
                    color: flow.latencyMs > 50 ? Colors.amber : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${flow.latencyMs.toStringAsFixed(1)} ms',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: flow.latencyMs > 100
                          ? Colors.redAccent
                          : (flow.latencyMs > 30 ? Colors.amber : null),
                    ),
                  ),
                ],
              ),
            ),

            // Bandwidth Rate
            SizedBox(
              width: 85,
              child: Text(
                _formatBytesRate(flow.throughputBps),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),

            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Service Mesh Topology ──────────────────────────────────────────

  Widget _buildTopologyTab(ThemeData theme) {
    if (_topology == null || _topology!.nodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_outlined, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'No active topology nodes registered yet.',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    final nodes = _topology!.nodes;
    final edges = _topology!.edges;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topology KPI Banner
          Row(
            children: [
              _buildMetricCard(
                title: 'MESH NODES',
                value: '${nodes.length}',
                subtitle: 'Discovered services & containers',
                icon: Icons.device_hub,
                color: const Color(0xFF06B6D4),
                theme: theme,
              ),
              const SizedBox(width: 14),
              _buildMetricCard(
                title: 'ACTIVE EDGES',
                value: '${edges.length}',
                subtitle: 'Inter-service communication links',
                icon: Icons.linear_scale,
                color: Colors.purpleAccent,
                theme: theme,
              ),
              const SizedBox(width: 14),
              _buildMetricCard(
                title: 'AGGREGATE RATE',
                value: _formatBytesRate(_stats?.bytesPerSec ?? 0.0),
                subtitle: 'Throughput across all mesh edges',
                icon: Icons.speed,
                color: Colors.tealAccent,
                theme: theme,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Topology View Mode Selector Header
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _topologyViewMode == 'canvas'
                        ? 'Interactive Service Mesh Canvas (Directional Vectors & Particles)'
                        : 'Active Service Communication Matrix',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _topologyViewMode == 'canvas'
                        ? 'Drag blocks to reposition. Directional Bézier curves animate real-time data flow with deep Jaeger trace correlation.'
                        : 'Real-time traffic flow matrix monitored by kernel socket filters and eBPF probes.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
              const Spacer(),

              // View Mode Segmented Switcher
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTopologyModeButton(
                      mode: 'canvas',
                      label: '2D Vector Graph',
                      icon: Icons.auto_awesome_motion,
                      theme: theme,
                    ),
                    const SizedBox(width: 4),
                    _buildTopologyModeButton(
                      mode: 'matrix',
                      label: 'Edges Table',
                      icon: Icons.table_chart_outlined,
                      theme: theme,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Render 2D Vector Canvas or Edges Table based on _topologyViewMode
          if (_topologyViewMode == 'canvas') ...[
            SizedBox(
              height: 560,
              child: EbpfAnimatedMeshCanvas(
                topology: _topology!,
                onSelectEdge: (edge) {
                  // Optionally open flow details or jaeger
                },
                onSelectNode: (node) {
                  // Node selected in canvas
                },
              ),
            ),
          ] else ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: edges.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.2)),
              itemBuilder: (ctx, idx) {
                final e = edges[idx];
                final protoColor = _getProtocolColor(e.protocol);
                final hasErrors = e.errorRate > 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Source
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(e.sourceId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),

                      // Direction Arrow with Protocol
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: protoColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(e.protocol, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: protoColor)),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_right_alt, size: 20, color: Color(0xFF06B6D4)),
                          ],
                        ),
                      ),

                      // Target
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(e.targetId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),

                      const Spacer(),

                      // Latency (RTT)
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('${e.rttMs.toStringAsFixed(1)} ms', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                        ],
                      ),
                      const SizedBox(width: 20),

                      // Throughput
                      Row(
                        children: [
                          const Icon(Icons.swap_vert, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(_formatBytesRate(e.throughputBps), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                        ],
                      ),
                      const SizedBox(width: 20),

                      // Active flows count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${e.activeFlows} flows', style: const TextStyle(fontSize: 10, color: Colors.blueAccent)),
                      ),

                      const SizedBox(width: 14),

                      // Error Rate badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: hasErrors ? Colors.red.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: hasErrors ? Colors.red.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          hasErrors ? '${e.errorRate.toStringAsFixed(1)}% ERR' : 'HEALTHY 100%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: hasErrors ? Colors.redAccent : Colors.green,
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Jaeger Action Button
                      Tooltip(
                        message: 'Inspect Edge Distributed Trace in Jaeger (:16686)',
                        child: IconButton(
                          iconSize: 16,
                          icon: const Icon(Icons.timeline, color: Colors.purpleAccent),
                          onPressed: () {
                            final host = html.window.location.hostname ?? '127.0.0.1';
                            final url = e.traceId.isNotEmpty
                                ? 'http://$host:16686/trace/${e.traceId}'
                                : 'http://$host:16686/';
                            html.window.open(url, '_blank');
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],

          const SizedBox(height: 24),

          // Mesh Nodes Cards Grid
          Text(
            'Service Mesh Nodes & Container Endpoints',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 380,
              mainAxisExtent: 135,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: nodes.length,
            itemBuilder: (ctx, idx) {
              final n = nodes[idx];
              final isDb = n.type == 'database';
              final isIngress = n.type == 'ingress';
              final isDns = n.type == 'dns';

              IconData icon = Icons.apps;
              Color iconColor = const Color(0xFF06B6D4);
              if (isDb) {
                icon = Icons.storage;
                iconColor = Colors.orangeAccent;
              } else if (isIngress) {
                icon = Icons.alt_route;
                iconColor = Colors.purpleAccent;
              } else if (isDns) {
                icon = Icons.manage_search;
                iconColor = Colors.tealAccent;
              }

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(icon, color: iconColor, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  n.ip.isNotEmpty ? n.ip : n.type.toUpperCase(),
                                  style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('RUNNING', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green)),
                          ),
                        ],
                      ),

                      Divider(height: 12, color: theme.dividerColor.withValues(alpha: 0.2)),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('INBOUND', style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                              Text(_formatBytesRate(n.inboundBps), style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('OUTBOUND', style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                              Text(_formatBytesRate(n.outboundBps), style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('FLOWS', style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                              Text('${n.activeFlows}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF06B6D4))),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Kernel Diagnostics & Probes ────────────────────────────────────

  Widget _buildDiagnosticsTab(ThemeData theme) {
    final stats = _stats;
    final probes = stats?.probesList ?? [];
    final ifaces = stats?.interfaces ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kernel & BPF Capabilities Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security, color: Color(0xFF06B6D4), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Kernel Subsystem & eBPF Capabilities',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildDetailRow('Host OS / Kernel', stats?.kernelVersion ?? 'Unknown', theme),
                      _buildDetailRow('Operational Mode', (stats?.mode ?? 'kernel').toUpperCase(), theme),
                      _buildDetailRow('Total Probes', '${stats?.activeProbes ?? 0}', theme),
                      _buildDetailRow('Dropped Packets', '${stats?.droppedPackets ?? 0}', theme),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Active eBPF Probes / Tracepoints
          Text(
            'Active Probes & Tracing Attach Points',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: probes.map((p) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Text(
                      p,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Protocol Breakdown Cards
          if (stats != null && stats.protocolCounts.isNotEmpty) ...[
            Text(
              'Protocol Distribution (Recent 30s)',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: stats.protocolCounts.entries.map((entry) {
                final protoColor = _getProtocolColor(entry.key);
                return Expanded(
                  child: Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(right: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: protoColor),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${entry.value}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'captured flows',
                            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Network Devices Table
          if (ifaces.isNotEmpty) ...[
            Text(
              'Host Network Interfaces (/proc/net/dev)',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
              ),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('INTERFACE')),
                  DataColumn(label: Text('RX BYTES')),
                  DataColumn(label: Text('TX BYTES')),
                  DataColumn(label: Text('RX PACKETS')),
                  DataColumn(label: Text('TX PACKETS')),
                  DataColumn(label: Text('PACKET DROPS')),
                ],
                rows: ifaces.map((i) {
                  return DataRow(cells: [
                    DataCell(Text(i.name, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                    DataCell(Text(_formatBytes(i.rxBytes), style: const TextStyle(fontFamily: 'monospace'))),
                    DataCell(Text(_formatBytes(i.txBytes), style: const TextStyle(fontFamily: 'monospace'))),
                    DataCell(Text('${i.rxPackets}', style: const TextStyle(fontFamily: 'monospace'))),
                    DataCell(Text('${i.txPackets}', style: const TextStyle(fontFamily: 'monospace'))),
                    DataCell(Text('${i.rxDrops + i.txDrops}', style: const TextStyle(fontFamily: 'monospace'))),
                  ]);
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Simulation Launcher Quick Card
          Card(
            elevation: 0,
            color: const Color(0xFF06B6D4).withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Color(0xFF06B6D4), size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'On-Demand eBPF Flow Generator & Test Suite',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Generate real-time synthetic traffic across cluster services to benchmark latency, test SLO multi-window alerts, or simulate upstream 502/504 faults.',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _openSimulationDialog,
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Open Simulator'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.black,
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Color _getProtocolColor(String proto) {
    switch (proto.toUpperCase()) {
      case 'HTTP':
        return Colors.blueAccent;
      case 'GRPC':
        return Colors.purpleAccent;
      case 'DNS':
        return Colors.greenAccent;
      case 'REDIS':
        return Colors.orangeAccent;
      case 'POSTGRES':
        return Colors.tealAccent;
      case 'TCP':
        return const Color(0xFF06B6D4);
      case 'UDP':
        return Colors.amberAccent;
      default:
        return Colors.cyanAccent;
    }
  }

  String _formatBytesRate(double bps) {
    if (bps >= 1024 * 1024) {
      return "${(bps / (1024 * 1024)).toStringAsFixed(2)} MB/s";
    } else if (bps >= 1024) {
      return "${(bps / 1024).toStringAsFixed(1)} KB/s";
    }
    return "${bps.toStringAsFixed(0)} B/s";
  }

  String _formatBytes(int b) {
    if (b >= 1024 * 1024 * 1024) {
      return "${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
    } else if (b >= 1024 * 1024) {
      return "${(b / (1024 * 1024)).toStringAsFixed(1)} MB";
    } else if (b >= 1024) {
      return "${(b / 1024).toStringAsFixed(1)} KB";
    }
    return "$b B";
  }

  Widget _buildTopologyModeButton({
    required String mode,
    required String label,
    required IconData icon,
    required ThemeData theme,
  }) {
    final active = _topologyViewMode == mode;
    return InkWell(
      onTap: () => _updateState(() => _topologyViewMode = mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF06B6D4) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? Colors.black : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? Colors.black : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

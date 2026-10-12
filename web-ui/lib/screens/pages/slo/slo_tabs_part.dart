part of '../slo_page.dart';

extension _SloTabsExt on _SloPageState {
  // TAB 1: Overview & Error Budgets
  Widget _buildTabOverview(ThemeData theme) {
    final filteredSLOs = _getFilteredAndSortedSLOs();

    if (_slos.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.query_stats, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text(
                  'No Active SLOs Configured',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Click "+ Configure / Add SLO" below or add gbnt.slo.* labels to your Compose services.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _showAddEditSLODialog(),
                  icon: const Icon(Icons.add_chart),
                  label: const Text('+ Configure / Add SLO'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls Bar: Search, Sort, View Toggle, Add SLO Button
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 20),
                      hintText: 'Search by service, template, or journey...',
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onChanged: (val) => _updateState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _sortBy,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.sort, size: 18),
                  items: const [
                    DropdownMenuItem(value: 'lowest_budget', child: Text('Sort: Lowest Budget')),
                    DropdownMenuItem(value: 'highest_burn', child: Text('Sort: Highest Burn')),
                    DropdownMenuItem(value: 'name', child: Text('Sort: Name (A-Z)')),
                    DropdownMenuItem(value: 'target', child: Text('Sort: Target %')),
                  ],
                  onChanged: (val) {
                    if (val != null) _updateState(() => _sortBy = val);
                  },
                ),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: _isTableView ? 'Switch to Cards View' : 'Switch to Data Table View',
                  icon: Icon(_isTableView ? Icons.grid_view : Icons.table_rows),
                  onPressed: () => _updateState(() => _isTableView = !_isTableView),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => _showSLONotificationsDialog(),
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('Alert Channels'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _showAddEditSLODialog(),
                  icon: const Icon(Icons.add_chart, size: 18),
                  label: const Text('+ Add SLO'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (filteredSLOs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No SLOs match your search filter.')),
          )
        else if (_isTableView)
          // Data Table View
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                columns: const [
                  DataColumn(label: Text('Service')),
                  DataColumn(label: Text('Target')),
                  DataColumn(label: Text('Budget Remaining')),
                  DataColumn(label: Text('Burn Rate')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: filteredSLOs.map((item) {
                  final budgetColor = _getBudgetColor(item.errorBudgetRemaining);
                  return DataRow(
                    onSelectChanged: (_) => _showSLODetailModal(item),
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            Text(item.serviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (item.template.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _updateState(() => _searchQuery = item.template),
                                child: Chip(
                                  label: Text(item.template, style: const TextStyle(fontSize: 10)),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      DataCell(Text('${item.target}% (${item.window})')),
                      DataCell(
                        Text('${item.errorBudgetRemaining.toStringAsFixed(2)}%',
                            style: TextStyle(fontWeight: FontWeight.bold, color: budgetColor)),
                      ),
                      DataCell(
                        Text('${item.burnRate.toStringAsFixed(2)}x',
                            style: TextStyle(
                              color: item.burnRate > 1.0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                      DataCell(StatusBadge(label: item.status)),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'View Detail Metrics & Charts',
                              icon: const Icon(Icons.analytics, size: 18),
                              onPressed: () => _showSLODetailModal(item),
                            ),
                            IconButton(
                              tooltip: 'Edit SLO Settings',
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _showAddEditSLODialog(item),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          )
        else
          // Cards View
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredSLOs.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 16),
            itemBuilder: (ctx, idx) {
              final item = filteredSLOs[idx];
              final budgetColor = _getBudgetColor(item.errorBudgetRemaining);

              return Card(
                child: InkWell(
                  onTap: () => _showSLODetailModal(item),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.api, size: 24, color: theme.colorScheme.primary),
                            const SizedBox(width: 10),
                            Text(
                              item.serviceName,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 12),
                            Chip(
                              label: Text('${item.target}% Target (${item.window})',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              backgroundColor: theme.colorScheme.secondaryContainer,
                              visualDensity: VisualDensity.compact,
                            ),
                            if (item.template.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _updateState(() => _searchQuery = item.template),
                                child: Chip(
                                  avatar: const Icon(Icons.dashboard_customize, size: 14),
                                  label: Text(item.template, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  backgroundColor: theme.colorScheme.tertiaryContainer,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                            if (item.journey.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _updateState(() => _searchQuery = item.journey),
                                child: Chip(
                                  avatar: const Icon(Icons.route, size: 14),
                                  label: Text(item.journey, style: const TextStyle(fontSize: 11)),
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                            const Spacer(),
                            IconButton(
                              tooltip: 'Edit SLO Settings',
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showAddEditSLODialog(item),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text('${item.burnRate.toStringAsFixed(2)}x Burn Rate',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: item.burnRate > 1.0 ? Colors.red : Colors.green,
                                  )),
                              backgroundColor: (item.burnRate > 1.0 ? Colors.red : Colors.green).withValues(alpha: 0.1),
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(label: item.status),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'Error Budget Remaining: ',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${item.errorBudgetRemaining.toStringAsFixed(2)}%',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: budgetColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (item.errorBudgetRemaining / 100.0).clamp(0.0, 1.0),
                            minHeight: 12,
                            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                            color: budgetColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text('SLI Queries', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                          children: [
                            if (item.errorQuery.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Error Query: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    Expanded(
                                      child: SelectableText(
                                        item.errorQuery,
                                        style: const TextStyle(fontFamily: 'Courier New', fontSize: 12, color: Colors.redAccent),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (item.totalQuery.isNotEmpty)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Query: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Expanded(
                                    child: SelectableText(
                                      item.totalQuery,
                                      style: const TextStyle(fontFamily: 'Courier New', fontSize: 12, color: Colors.blueAccent),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // TAB 2: User Journeys (Composite SLOs)
  Widget _buildTabJourneys(ThemeData theme) {
    if (_journeys.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Center(
            child: Text(
              'No User Journeys Defined\nAdd label "gbnt.slo.journey=My Journey Name" to Compose services to aggregate composite SLOs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _journeys.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 16),
      itemBuilder: (ctx, idx) {
        final j = _journeys[idx];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.route, size: 24, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(j.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Chip(
                      label: Text('${j.compositeTarget.toStringAsFixed(2)}% Avg Target',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      backgroundColor: theme.colorScheme.secondaryContainer,
                    ),
                    const Spacer(),
                    StatusBadge(label: j.status),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Average Error Budget', style: theme.textTheme.bodySmall),
                          Text('${j.avgErrorBudget.toStringAsFixed(2)}%',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _getBudgetColor(j.avgErrorBudget),
                              )),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bottleneck Service', style: theme.textTheme.bodySmall),
                          Text('${j.bottleneckService} (${j.bottleneckBudget.toStringAsFixed(2)}% Budget)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orangeAccent,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Services in Journey:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: j.services
                      .map((s) => Chip(
                            avatar: Icon(Icons.api, size: 14, color: _getBudgetColor(s.errorBudgetRemaining)),
                            label: Text('${s.serviceName} (${s.errorBudgetRemaining.toStringAsFixed(1)}%)'),
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // TAB 3: Deployment Events Correlation
  Widget _buildTabCorrelation(ThemeData theme) {
    if (_correlations.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Center(
            child: Text(
              'No recent stack deployment events recorded.',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SLO Burn Rate vs Deployment Correlation Timeline',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Cross-references stack updates and restarts with service burn rates',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 20),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _correlations.length,
              separatorBuilder: (ctx, idx) => const Divider(),
              itemBuilder: (ctx, idx) {
                final ev = _correlations[idx];
                final isSpike = ev.burnRate > 1.0;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSpike ? Colors.red.withValues(alpha: 0.2) : theme.colorScheme.primaryContainer,
                    child: Icon(
                      isSpike ? Icons.warning_amber : Icons.rocket_launch,
                      color: isSpike ? Colors.red : theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text('${ev.stackName} / ${ev.serviceName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${ev.description} • ${ev.timestamp}'),
                  trailing: Chip(
                    label: Text('Burn Rate: ${ev.burnRate.toStringAsFixed(2)}x',
                        style: TextStyle(
                          color: isSpike ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        )),
                    backgroundColor: (isSpike ? Colors.red : Colors.green).withValues(alpha: 0.1),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // TAB 4: SLI Templates & PromQL Generator
  Widget _buildTabTemplates(ThemeData theme) {
    final templates = [
      {
        'id': 'caddy-http',
        'title': 'Caddy HTTP Status Code Rate',
        'desc': 'Reverse proxy HTTP 5xx error rate from Caddy access metrics.',
        'error': 'sum(rate(caddy_http_response_status_code_total{status=~"5.."}[{{.window}}]))',
        'total': 'sum(rate(caddy_http_response_status_code_total[{{.window}}]))',
        'label': 'gbnt.slo.template: "caddy-http"',
      },
      {
        'id': 'http-status',
        'title': 'Generic HTTP Container Status',
        'desc': 'Application container HTTP 5xx error rate.',
        'error': 'sum(rate(http_requests_total{status=~"5.."}[{{.window}}]))',
        'total': 'sum(rate(http_requests_total[{{.window}}]))',
        'label': 'gbnt.slo.template: "http-status"',
      },
      {
        'id': 'latency-p99',
        'title': 'P99 Latency Histogram',
        'desc': 'Proportion of requests completed in under 500ms.',
        'error': 'sum(rate(http_request_duration_seconds_bucket{le="0.5"}[{{.window}}]))',
        'total': 'sum(rate(http_request_duration_seconds_count[{{.window}}]))',
        'label': 'gbnt.slo.template: "latency-p99"',
      },
      {
        'id': 'grpc',
        'title': 'gRPC Server Handled Errors',
        'desc': 'gRPC error codes (Internal, Unavailable, DataLoss).',
        'error': 'sum(rate(grpc_server_handled_total{grpc_code=~"Unknown|Internal|Unavailable|DataLoss"}[{{.window}}]))',
        'total': 'sum(rate(grpc_server_handled_total[{{.window}}]))',
        'label': 'gbnt.slo.template: "grpc"',
      },
      {
        'id': 'host-disk',
        'title': 'Host Disk & Filesystem Capacity',
        'desc': 'Triggers when Centurion node filesystem drops below 15% free capacity.',
        'error': 'sum(rate(node_filesystem_avail_bytes{mountpoint="/"}[{{.window}}]) < bool 0.15 * node_filesystem_size_bytes{mountpoint="/"})',
        'total': 'count(node_filesystem_size_bytes{mountpoint="/"})',
        'label': 'gbnt.slo.template: "host-disk"',
      },
      {
        'id': 'gluster-storage',
        'title': 'GlusterFS Distributed Cluster Storage',
        'desc': 'Tracks replicated cluster storage pools and alerts on low volume capacity.',
        'error': 'sum(rate(gbnt_gluster_volume_capacity_bytes{kind="free"}[{{.window}}]) < bool 0.15 * gbnt_gluster_volume_capacity_bytes{kind="total"})',
        'total': 'count(gbnt_gluster_volume_status)',
        'label': 'gbnt.slo.template: "gluster-storage"',
      },
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: templates.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 16),
      itemBuilder: (ctx, idx) {
        final tmpl = templates[idx];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.dashboard_customize, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(tmpl['title'] ?? '', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Chip(
                      label: Text(tmpl['label'] ?? '', style: const TextStyle(fontFamily: 'Courier New', fontSize: 12, fontWeight: FontWeight.bold)),
                      backgroundColor: theme.colorScheme.secondaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(tmpl['desc'] ?? '', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText('Error Query: ${tmpl['error'] ?? ''}',
                          style: const TextStyle(fontFamily: 'Courier New', fontSize: 12, color: Colors.redAccent)),
                      const SizedBox(height: 4),
                      SelectableText('Total Query: ${tmpl['total'] ?? ''}',
                          style: const TextStyle(fontFamily: 'Courier New', fontSize: 12, color: Colors.blueAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // TAB 5: Backtest & Dry-Run Validator
  Widget _buildTabBacktest(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Backtest & Validate Compose SLO Labels',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Paste your docker-compose.yml to dry-run PromQL queries and validate SLO configuration.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 16),
                TextField(
                  controller: _composeController,
                  maxLines: 10,
                  style: const TextStyle(fontFamily: 'Courier New', fontSize: 13),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _validating ? null : _runBacktest,
                  icon: _validating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.science),
                  label: const Text('Run SLO Backtest & Syntax Validation'),
                ),
              ],
            ),
          ),
        ),
        if (_validations.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Backtest & Validation Results', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _validations.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
            itemBuilder: (ctx, idx) {
              final v = _validations[idx];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        v.valid ? Icons.check_circle : Icons.error,
                        color: v.valid ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(
                              v.valid ? 'Target: ${v.target}% (${v.window}) • Template: ${v.template.isEmpty ? 'Custom' : v.template}' : v.error,
                              style: TextStyle(color: v.valid ? theme.colorScheme.onSurface.withValues(alpha: 0.7) : Colors.red),
                            ),
                            const SizedBox(height: 4),
                            Text('Backtest: ${v.backtestDetails}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(v.backtestStatus.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        backgroundColor: v.backtestStatus == 'passed'
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.amber.withValues(alpha: 0.15),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

}

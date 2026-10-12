import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/compose_editor.dart';
import '../../widgets/new_stack_dialog.dart';
import '../../widgets/stack_diagram_dialog.dart';
import '../../widgets/server_stack_picker_dialog.dart';
import '../../widgets/poc_examples_dialog.dart';
import '../../widgets/port_conflict_dialog.dart';
import '../../widgets/autoscale_dialog.dart';
import '../../widgets/save_server_stack_dialog.dart';
import '../../widgets/save_pc_stack_dialog.dart';
import '../../utils/clipboard_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/shell_dialog.dart';
import '../../widgets/common_widgets.dart';

part 'legions/legions_actions_dialogs_part.dart';
part 'legions/stack_diagnostics_dialog_part.dart';

/// Legions page — full-width stacks table with all actions.
class LegionsPage extends StatefulWidget {
  final DashboardState state;
  final VoidCallback onRefresh;
  final ValueChanged<String>? onViewContainerLogs;
  final ValueChanged<String>? onViewStackContainers;

  const LegionsPage({
    super.key,
    required this.state,
    required this.onRefresh,
    this.onViewContainerLogs,
    this.onViewStackContainers,
  });

  @override
  State<LegionsPage> createState() => _LegionsPageState();
}

class _LegionsPageState extends State<LegionsPage> {
  String _searchQuery = '';
  String _selectedGroup = 'deployed'; // 'deployed', 'base', 'all'
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final Set<String> _processingStackIds = {};
  final Set<String> _expandedStackIds = {};

  bool _isBaseStack(StackModel s) {
    final id = s.id.toLowerCase();
    final name = s.name.toLowerCase();
    return id == 'core-gbnt-stack' ||
        id == 'sre-monitor-stack' ||
        id == 'super-net-topology-mgr' ||
        id.startsWith('core-') ||
        id.startsWith('sre-') ||
        id.startsWith('super-') ||
        name.contains('core-gbnt') ||
        name == 'core' ||
        name.contains('monitor') ||
        name.contains('[sre]') ||
        name == 'sre' ||
        name.contains('topology') ||
        name.contains('[super]') ||
        name.contains('[base]') ||
        name.contains('scope');
  }

  Future<void> _stopStack(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.stop_circle_outlined, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            Expanded(child: Text('Stop Stack: $name')),
          ],
        ),
        content: Text(
          'Stop all running containers for stack "$name"?\n\n'
          'The stack definition and service configuration will remain saved in Gubernator and can be started again at any time.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
            child: const Text('Stop Stack'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processingStackIds.add(id));
    _showSnackBar('Stopping stack "$name"...');
    final ok = await ApiService.stopStack(id);
    if (mounted) {
      setState(() => _processingStackIds.remove(id));
    }
    if (ok) {
      _showSnackBar('Stack "$name" stopped successfully.');
      widget.onRefresh();
    } else {
      _showSnackBar('Failed to stop stack "$name".', isError: true);
    }
  }

  Future<void> _startStack(String id, String name) async {
    setState(() => _processingStackIds.add(id));
    _showSnackBar('Starting stack "$name"...');
    final ok = await ApiService.startStack(id);
    if (mounted) {
      setState(() => _processingStackIds.remove(id));
    }
    if (ok) {
      _showSnackBar('Stack "$name" started successfully.');
      widget.onRefresh();
    } else {
      _showSnackBar('Failed to start stack "$name".', isError: true);
    }
  }

  Future<void> _restartStack(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.refresh, color: Color(0xFF3B82F6)),
            const SizedBox(width: 8),
            Expanded(child: Text('Restart Stack: $name')),
          ],
        ),
        content: Text(
          'Restart all containers for stack "$name"?\n\n'
          'All running workloads will be restarted and container health will be re-verified.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text('Restart Stack'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processingStackIds.add(id));
    _showSnackBar('Restarting stack "$name"...');
    final ok = await ApiService.restartStack(id);
    if (mounted) {
      setState(() => _processingStackIds.remove(id));
    }
    if (ok) {
      _showSnackBar('Stack "$name" restarted successfully.');
      widget.onRefresh();
    } else {
      _showSnackBar('Failed to restart stack "$name".', isError: true);
    }
  }

  Future<void> _reconcileStack(String id, String name) async {
    setState(() => _processingStackIds.add(id));
    _showSnackBar('Reconciling stack "$name" and purging stale containers...');
    final res = await ApiService.reconcileStack(id);
    if (mounted) {
      setState(() => _processingStackIds.remove(id));
    }
    if (res != null) {
      final msg = res['message'] ?? 'Stack "$name" reconciled successfully.';
      _showSnackBar(msg.toString());
      widget.onRefresh();
    } else {
      _showSnackBar('Failed to reconcile stack "$name".', isError: true);
    }
  }

  Future<void> _pruneAllTasks() async {
    _showSnackBar('Reconciling cluster stacks and pruning stale containers...');
    final res = await ApiService.pruneTasks();
    if (res != null) {
      final msg = res['message'] ?? 'Cluster reconciliation complete.';
      _showSnackBar(msg.toString());
      widget.onRefresh();
    } else {
      _showSnackBar('Failed to reconcile cluster tasks.', isError: true);
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _timeAgo(String iso) {
    if (iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return 'Up ${diff.inDays} days';
      if (diff.inHours > 0) return 'Up ${diff.inHours} hours';
      if (diff.inMinutes > 0) return 'Up ${diff.inMinutes} mins';
      return 'Up ${diff.inSeconds} secs';
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allMatching = widget.state.stacks.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.id.toLowerCase().contains(_searchQuery) ||
          s.name.toLowerCase().contains(_searchQuery);
    }).toList();

    final deployedCount = widget.state.stacks.where((s) => !_isBaseStack(s)).length;
    final baseCount = widget.state.stacks.where((s) => _isBaseStack(s)).length;

    List<StackModel> filteredStacks;
    if (_selectedGroup == 'deployed') {
      filteredStacks = allMatching.where((s) => !_isBaseStack(s)).toList();
    } else if (_selectedGroup == 'base') {
      filteredStacks = allMatching.where((s) => _isBaseStack(s)).toList();
    } else {
      filteredStacks = allMatching;
    }

    // Apply sorting
    if (_sortColumnIndex != null) {
      Comparable Function(StackModel s) getField;
      switch (_sortColumnIndex) {
        case 1: getField = (s) => s.id; break;
        case 2: getField = (s) => s.name; break;
        case 4: getField = (s) => s.nodeId; break;
        case 5: getField = (s) => s.createdAt; break;
        default: getField = (s) => s.id;
      }
      filteredStacks.sort((a, b) {
        final aVal = getField(_sortAscending ? a : b);
        final bVal = getField(_sortAscending ? b : a);
        return Comparable.compare(aVal, bVal);
      });
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.layers, size: 22, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text('Legions (Stacks)',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Tooltip(
                    message: 'Reconcile all stacks and purge dead/stale containers across the cluster',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cleaning_services_outlined, size: 16, color: Color(0xFF06B6D4)),
                      label: const Text('Reconcile & Prune', style: TextStyle(color: Color(0xFF06B6D4))),
                      onPressed: _pruneAllTasks,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.dns, size: 16, color: Color(0xFF58A6FF)),
                    label: const Text('Master Server File', style: TextStyle(color: Color(0xFF58A6FF))),
                    onPressed: _showServerStackPicker,
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.rocket_launch, size: 16, color: Color(0xFFE3B341)),
                    label: const Text('POC Blueprints', style: TextStyle(color: Color(0xFFE3B341), fontWeight: FontWeight.bold)),
                    onPressed: _showPOCExamples,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Deploy Stack'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _showNewStackDialog,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'deployed',
                        icon: const Icon(Icons.rocket_launch, size: 15, color: Color(0xFF38BDF8)),
                        label: Text('Deployed Apps ($deployedCount)'),
                      ),
                      ButtonSegment(
                        value: 'base',
                        icon: const Icon(Icons.foundation, size: 15, color: Color(0xFF8B5CF6)),
                        label: Text('Base Stacks ($baseCount)'),
                      ),
                      ButtonSegment(
                        value: 'all',
                        icon: const Icon(Icons.layers_outlined, size: 15),
                        label: Text('All (${widget.state.stacks.length})'),
                      ),
                    ],
                    selected: {_selectedGroup},
                    onSelectionChanged: (newSelection) {
                      setState(() => _selectedGroup = newSelection.first);
                    },
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search stacks by name or ID...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filteredStacks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.layers_clear, size: 48,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                            const SizedBox(height: 12),
                            Text(
                              widget.state.stacks.isEmpty
                                  ? 'No stacks deployed yet'
                                  : 'No matching stacks found in this group',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Scrollbar(
                        controller: _verticalScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          scrollDirection: Axis.vertical,
                          child: Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                            sortColumnIndex: _sortColumnIndex,
                            sortAscending: _sortAscending,
                            columns: [
                              DataColumn(
                                label: Tooltip(
                                  message: _expandedStackIds.isEmpty ? 'Expand all stacks' : 'Collapse all stacks',
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (_expandedStackIds.length >= filteredStacks.length && filteredStacks.isNotEmpty) {
                                          _expandedStackIds.clear();
                                        } else {
                                          _expandedStackIds.addAll(filteredStacks.map((s) => s.id));
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                      ),
                                      child: Icon(
                                        _expandedStackIds.isEmpty ? Icons.unfold_more : Icons.unfold_less,
                                        size: 15,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: const Text('ID'),
                                onSort: (col, asc) => setState(() {
                                  _sortColumnIndex = col;
                                  _sortAscending = asc;
                                }),
                              ),
                              DataColumn(
                                label: const Text('NAME'),
                                onSort: (col, asc) => setState(() {
                                  _sortColumnIndex = col;
                                  _sortAscending = asc;
                                }),
                              ),
                              const DataColumn(label: Text('AUTOSCALE')),
                              DataColumn(
                                label: const Text('HOST NODE'),
                                onSort: (col, asc) => setState(() {
                                  _sortColumnIndex = col;
                                  _sortAscending = asc;
                                }),
                              ),
                              DataColumn(
                                label: const Text('CREATED'),
                                onSort: (col, asc) => setState(() {
                                  _sortColumnIndex = col;
                                  _sortAscending = asc;
                                }),
                              ),
                              const DataColumn(label: Text('CONTAINERS')),
                              const DataColumn(label: Text('ACTIONS')),
                            ],
                            rows: [
                              for (final s in filteredStacks) ...[
                                _buildStackRow(s, theme),
                                if (_expandedStackIds.contains(s.id))
                                  ..._buildContainerRowsForStack(s, theme),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _buildStackRow(StackModel s, ThemeData theme) {
    final isExpanded = _expandedStackIds.contains(s.id);
    final isBase = _isBaseStack(s);
    final stackTasks = widget.state.tasks.where((t) {
      final svc = widget.state.services.where((sv) => sv.id == t.serviceId).firstOrNull;
      return svc?.stackId == s.id;
    }).toList();
    final runningCount = stackTasks.where((t) => t.status == 'running').length;

    return DataRow(
      key: ValueKey('stack-${s.id}'),
      cells: [
        // 0. EXPAND TOGGLE (matching user screenshot)
        DataCell(
          Tooltip(
            message: isExpanded
                ? 'Collapse containers for ${s.name}'
                : 'Expand containers (${stackTasks.length}) for ${s.name}',
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedStackIds.remove(s.id);
                  } else {
                    _expandedStackIds.add(s.id);
                  }
                });
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isExpanded
                        ? const Color(0xFF38BDF8)
                        : theme.colorScheme.primary.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  color: isExpanded
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.12)
                      : Colors.transparent,
                ),
                child: Center(
                  child: AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: isExpanded ? const Color(0xFF38BDF8) : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // 1. Stack ID
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              s.id.length > 8 ? s.id.substring(0, 8) : s.id,
              style: const TextStyle(fontFamily: 'Courier New', fontSize: 13),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.copy, size: 14),
              tooltip: 'Copy full ID',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                ClipboardService.copy(s.id);
                _showSnackBar('Copied Stack ID to clipboard!');
              },
            ),
          ],
        )),
        // 2. NAME (with green dot + icon + badge + name)
        DataCell(
          InkWell(
            onTap: () => widget.onViewStackContainers?.call(s.name),
            borderRadius: BorderRadius.circular(4),
            child: Tooltip(
              message: isBase
                  ? 'Base Infrastructure Stack: ${s.name}'
                  : 'Deployed Application: ${s.name}',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: runningCount > 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        boxShadow: [
                          BoxShadow(
                            color: (runningCount > 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isBase ? Icons.foundation : Icons.rocket_launch,
                      size: 16,
                      color: isBase ? const Color(0xFF8B5CF6) : const Color(0xFF38BDF8),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: (isBase ? const Color(0xFF8B5CF6) : const Color(0xFF38BDF8)).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: (isBase ? const Color(0xFF8B5CF6) : const Color(0xFF38BDF8)).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        isBase ? 'BASE' : 'APP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isBase ? const Color(0xFF8B5CF6) : const Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dotted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 3. AUTOSCALE
        DataCell(
          Builder(builder: (context) {
            final autoSvc = s.primaryAutoscaleService(widget.state.services);
            if (autoSvc == null || !autoSvc.isAutoscalingEnabled) {
              return Tooltip(
                message: 'Autoscaling: Disabled\nClick to configure & enable horizontal autoscaling (GPU/CPU)',
                child: InkWell(
                  onTap: () => _showAutoscaleDialog(s),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 12, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          'Off',
                          style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final isGPU = autoSvc.autoscaleMetric == 'gpu';
            final isCluster = autoSvc.autoscaleScope == 'cluster';
            final color = isGPU ? const Color(0xFFA855F7) : const Color(0xFF06B6D4);
            final icon = isGPU ? Icons.developer_board : Icons.speed;
            final metricLabel = isGPU ? 'GPU' : 'CPU';
            final scopeLabel = isCluster ? 'Cluster' : 'Host';

            final tooltipMsg = 'Autoscaling Enabled (Service: ${autoSvc.name})\n'
                '• Metric: $metricLabel (Target: ${autoSvc.autoscaleTarget.toStringAsFixed(0)}%)\n'
                '• Scope: ${isCluster ? "All Nodes (Cluster)" : "Single Host (Local)"}\n'
                '• Replicas: Min ${autoSvc.autoscaleMin} / Max ${autoSvc.autoscaleMax}'
                '${isGPU ? "\n• Hardware Affinity: Centurions with NVIDIA GPU" : ""}\n'
                'Click to manage & adjust autoscaling settings';

            return Tooltip(
              message: tooltipMsg,
              child: InkWell(
                onTap: () => _showAutoscaleDialog(s),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, size: 13, color: color),
                      const SizedBox(width: 3),
                      Icon(icon, size: 13, color: color),
                      const SizedBox(width: 4),
                      Text(
                        '$metricLabel • $scopeLabel',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontFamily: 'Courier New',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        // 4. HOST NODE
        DataCell(
          Builder(builder: (context) {
            final hostNode = widget.state.nodes.where((n) => n.id == s.nodeId || (s.nodeId.isNotEmpty && n.ip == s.nodeId)).firstOrNull;
            final isMgr = hostNode != null ? hostNode.role.toLowerCase() == 'manager' : false;
            final hostLabel = hostNode != null
                ? (hostNode.labels['gbnt.node.hostname'] ?? hostNode.id)
                : (s.nodeId.isNotEmpty ? s.nodeId : 'Auto / Cluster');
            final hostIp = hostNode?.ip ?? '';
            final color = isMgr ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8);

            return Tooltip(
              message: hostNode != null
                  ? 'Running on ${hostNode.role.toUpperCase()} ($hostLabel - $hostIp)\nClick to migrate to another host'
                  : 'Click to migrate to a specific Centurion host',
              child: InkWell(
                onTap: () => _showMigrateStackDialog(s),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMgr ? Icons.shield : Icons.computer,
                        size: 13,
                        color: color,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        hostLabel,
                        style: TextStyle(
                          fontFamily: 'Courier New',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.swap_horiz, size: 12, color: color.withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        // 5. CREATED
        DataCell(Text(_formatDate(s.createdAt))),
        // 6. CONTAINERS
        DataCell(
          InkWell(
            onTap: () => widget.onViewStackContainers?.call(s.name),
            borderRadius: BorderRadius.circular(10),
            child: Tooltip(
              message: runningCount > 0
                  ? 'Running $runningCount/${stackTasks.length} containers for ${s.name}'
                  : 'Stopped (0/${stackTasks.length} containers) for ${s.name}',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: runningCount > 0
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: runningCount > 0
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      runningCount > 0 ? Icons.play_arrow : Icons.stop,
                      size: 12,
                      color: runningCount > 0
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      runningCount > 0
                          ? '$runningCount/${stackTasks.length}'
                          : 'Stopped (${stackTasks.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: runningCount > 0
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.visibility_outlined,
                      size: 12,
                      color: runningCount > 0
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 7. ACTIONS
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dynamic Stop / Start Button
            if (_processingStackIds.contains(s.id))
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (runningCount > 0)
              _actionBtn(
                Icons.stop_circle_outlined,
                'Stop Stack (Stop all containers)',
                const Color(0xFFF59E0B),
                () => _stopStack(s.id, s.name),
              )
            else
              _actionBtn(
                Icons.play_circle_filled,
                'Start Stack (Start compose)',
                const Color(0xFF10B981),
                () => _startStack(s.id, s.name),
              ),
            _actionBtn(Icons.receipt_long, 'View Stack Logs & Placement Errors',
                const Color(0xFF8B5CF6), () => _showStackLogsDialog(s)),
            _actionBtn(Icons.schema_outlined, 'View Schema',
                const Color(0xFFFB923C), () => _showStackDiagramDialog(s)),
            _actionBtn(Icons.code, 'Edit YAML',
                const Color(0xFFF97316), () => _openComposeEditor(s)),
            _actionBtn(Icons.download, 'Download docker-compose.yml to local PC',
                const Color(0xFF388BFD), () => _downloadStackYaml(s)),
            _actionBtn(Icons.dns_outlined, 'Save to Master Server (~/.gbnt/stacks/)',
                const Color(0xFF2EA043), () => _saveStackToServer(s)),
            isBase
                ? const SizedBox(width: 36)
                : _actionBtn(Icons.copy, 'Duplicate',
                    const Color(0xFF10B981), () => _duplicateStack(s)),
            _actionBtn(Icons.refresh, 'Restart Stack (Restart all containers)',
                const Color(0xFF3B82F6), () => _restartStack(s.id, s.name)),
            _actionBtn(Icons.rocket_launch, 'Redeploy Stack (Recreate containers)',
                const Color(0xFFD29922), () => _redeployStack(s.id)),
            _actionBtn(Icons.auto_fix_high, 'Reconcile Stack (Purge dead containers & align replicas)',
                const Color(0xFF06B6D4), () => _reconcileStack(s.id, s.name)),
            _actionBtn(Icons.bolt, 'Autoscale Settings (GPU / CPU)',
                const Color(0xFFA855F7), () => _showAutoscaleDialog(s)),
            if (!isBase)
              _actionBtn(Icons.swap_horiz, 'Change Target Host',
                  const Color(0xFF3B82F6), () => _showMigrateStackDialog(s)),
            _actionBtn(
              Icons.delete,
              (s.id == 'core-gbnt-stack' || s.name.toLowerCase().contains('core-gbnt'))
                  ? 'Restart Core (Does not delete)'
                  : (s.id == 'sre-monitor-stack' || s.name.toLowerCase().contains('monitor'))
                      ? 'Stop Monitor (Keeps stack)'
                      : 'Delete',
              const Color(0xFFEF4444),
              () => _deleteStack(s.id, s.name),
            ),
          ],
        )),
      ],
    );
  }

  List<DataRow> _buildContainerRowsForStack(StackModel s, ThemeData theme) {
    final stackTasks = widget.state.tasks.where((t) {
      final svc = widget.state.services.where((sv) => sv.id == t.serviceId).firstOrNull;
      return svc?.stackId == s.id;
    }).toList();

    if (stackTasks.isEmpty) {
      return [
        DataRow(
          key: ValueKey('stack-${s.id}-empty'),
          color: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1)),
          cells: [
            const DataCell(SizedBox.shrink()),
            const DataCell(Text('-')),
            DataCell(
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'No active containers running for this stack',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            ),
            const DataCell(Text('-')),
            const DataCell(Text('-')),
            const DataCell(Text('-')),
            const DataCell(Text('-')),
            const DataCell(Text('-')),
          ],
        )
      ];
    }

    return stackTasks.map((t) {
      final svc = widget.state.services.where((sv) => sv.id == t.serviceId).firstOrNull;
      final node = widget.state.nodes.where((n) => n.id == t.nodeId).firstOrNull;
      final isRunning = t.status == 'running';
      final isPaused = t.status == 'paused';
      final isDead = t.status == 'dead' || t.status == 'exited';

      final statusDotColor = isRunning
          ? const Color(0xFF10B981)
          : (isPaused ? const Color(0xFFF59E0B) : (isDead ? const Color(0xFFEF4444) : Colors.grey));

      final containerDisplayName = t.containerName.isNotEmpty ? t.containerName : (svc?.name ?? 'container');

      return DataRow(
        key: ValueKey('container-${t.id}'),
        color: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.hovered)) {
            return theme.colorScheme.primary.withValues(alpha: 0.08);
          }
          return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.14);
        }),
        cells: [
          // 0. Blank space under parent toggle column (matching screenshot)
          const DataCell(SizedBox.shrink()),
          // 1. ID
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.view_in_ar, size: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 4),
                SelectableText(
                  t.id.length > 8 ? t.id.substring(0, 8) : t.id,
                  style: const TextStyle(fontFamily: 'Courier New', fontSize: 12),
                ),
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.copy, size: 12),
                  tooltip: 'Copy Container ID',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    ClipboardService.copy(t.id);
                    _showSnackBar('Copied Container ID!');
                  },
                ),
              ],
            ),
          ),
          // 2. NAME (Indented with green dot + container/service name, exactly like screenshot)
          DataCell(
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusDotColor,
                      boxShadow: [
                        BoxShadow(
                          color: statusDotColor.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        containerDisplayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (svc?.image != null && svc!.image.isNotEmpty)
                        Text(
                          svc.image,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'Courier New',
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 3. AUTOSCALE
          DataCell(
            Builder(builder: (context) {
              if (svc == null || !svc.isAutoscalingEnabled) {
                return Tooltip(
                  message: 'Autoscaling: Disabled\nClick to configure autoscaling',
                  child: InkWell(
                    onTap: () => _showTaskAutoscaleDialog(t),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, size: 10, color: Colors.grey),
                          SizedBox(width: 2),
                          Text('Off', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                );
              }
              final isGPU = svc.autoscaleMetric == 'gpu';
              final isCluster = svc.autoscaleScope == 'cluster';
              final color = isGPU ? const Color(0xFFA855F7) : const Color(0xFF06B6D4);
              return Tooltip(
                message: 'Autoscaling (${svc.name}): ${isGPU ? "GPU" : "CPU"} • ${isCluster ? "Cluster" : "Host"}\nClick to manage',
                child: InkWell(
                  onTap: () => _showTaskAutoscaleDialog(t),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 10, color: color),
                        const SizedBox(width: 2),
                        Text(
                          '${isGPU ? "GPU" : "CPU"} • ${isCluster ? "Cluster" : "Host"}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, fontFamily: 'Courier New'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          // 4. HOST NODE
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  node?.role.toLowerCase() == 'manager' ? Icons.shield : Icons.computer,
                  size: 13,
                  color: node?.role.toLowerCase() == 'manager' ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                ),
                const SizedBox(width: 4),
                Text(
                  node != null ? (node.labels['gbnt.node.hostname'] ?? node.id) : t.nodeId,
                  style: const TextStyle(fontFamily: 'Courier New', fontSize: 11),
                ),
                if (node != null && node.ip.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(${node.ip})',
                    style: TextStyle(fontSize: 10, fontFamily: 'Courier New', color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ],
            ),
          ),
          // 5. CREATED / UPTIME
          DataCell(
            Text(
              _timeAgo(t.createdAt),
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
            ),
          ),
          // 6. CONTAINERS / PORTS & STATUS
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusBadge(label: t.status),
                if (svc != null && svc.ports.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _buildPortsCell(svc, node),
                ],
              ],
            ),
          ),
          // 7. ACTIONS
          DataCell(_buildTaskActions(t)),
        ],
      );
    }).toList();
  }
}

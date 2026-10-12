part of '../legions_page.dart';

class _StackDiagnosticsDialog extends StatefulWidget {
  final StackModel stack;
  final DashboardState state;
  final VoidCallback onRefreshState;
  final ValueChanged<String>? onViewContainerLogs;

  const _StackDiagnosticsDialog({
    required this.stack,
    required this.state,
    required this.onRefreshState,
    this.onViewContainerLogs,
  });

  @override
  State<_StackDiagnosticsDialog> createState() => _StackDiagnosticsDialogState();
}

class _StackDiagnosticsDialogState extends State<_StackDiagnosticsDialog> {
  final Map<String, String> _taskLogs = {};
  final Map<String, bool> _loadingLogs = {};
  final Set<String> _expandedLogs = {};
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadAllLogs();
  }

  Future<void> _loadAllLogs() async {
    final tasks = _getStackTasks();
    for (final t in tasks) {
      _fetchLogsForTask(t.id);
    }
  }

  List<Task> _getStackTasks() {
    return widget.state.tasks.where((t) {
      final svc = widget.state.services.where((sv) => sv.id == t.serviceId).firstOrNull;
      return svc?.stackId == widget.stack.id;
    }).toList();
  }

  Future<void> _fetchLogsForTask(String taskId) async {
    setState(() {
      _loadingLogs[taskId] = true;
    });
    try {
      final logs = await ApiService.getTaskLogs(taskId);
      if (mounted) {
        setState(() {
          _taskLogs[taskId] = logs;
          _loadingLogs[taskId] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _taskLogs[taskId] = 'Failed to load logs: $e';
          _loadingLogs[taskId] = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    widget.onRefreshState();
    await Future.delayed(const Duration(milliseconds: 600));
    await _loadAllLogs();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stackTasks = _getStackTasks();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.receipt_long, color: Color(0xFF8B5CF6)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stack Logs & Diagnostics: ${widget.stack.name}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Real-time container output logs, image download progress, and placement diagnostics',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bolt, size: 20, color: Color(0xFFA855F7)),
            tooltip: 'Horizontal Autoscaling Settings (GPU / CPU)',
            onPressed: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (ctx) => AutoscaleControlDialog(
                  stack: widget.stack,
                  stackServices: widget.state.services.where((s) => s.stackId == widget.stack.id).toList(),
                  onSaved: widget.onRefreshState,
                ),
              );
            },
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh Diagnostics & Logs',
            onPressed: _isRefreshing ? null : _refresh,
          ),
        ],
      ),
      content: SizedBox(
        width: 820,
        height: 540,
        child: stackTasks.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox, size: 48, color: Colors.grey.shade600),
                    const SizedBox(height: 12),
                    Text(
                      'No container tasks currently registered for stack "${widget.stack.name}".',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: stackTasks.length,
                itemBuilder: (context, index) {
                  final task = stackTasks[index];
                  final service = widget.state.services.where((sv) => sv.id == task.serviceId).firstOrNull;
                  final statusLower = task.status.toLowerCase();
                  final isRunning = statusLower == 'running';
                  final isPulling = statusLower == 'pulling';
                  final isStarting = statusLower == 'starting';
                  final isDead = statusLower == 'dead' || statusLower == 'failed';
                  final isExpanded = _expandedLogs.contains(task.id);
                  final logs = _taskLogs[task.id];
                  final isLoading = _loadingLogs[task.id] == true;

                  Color statusColor = Colors.orangeAccent;
                  IconData statusIcon = Icons.sync;
                  if (isRunning) {
                    statusColor = const Color(0xFF10B981);
                    statusIcon = Icons.check_circle;
                  } else if (isPulling) {
                    statusColor = const Color(0xFF3B82F6);
                    statusIcon = Icons.cloud_download;
                  } else if (isStarting) {
                    statusColor = const Color(0xFFF59E0B);
                    statusIcon = Icons.play_circle_outline;
                  } else if (isDead) {
                    statusColor = Colors.redAccent;
                    statusIcon = Icons.error_outline;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: isDead ? Colors.red.withValues(alpha: 0.06) : const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isDead
                            ? Colors.red.withValues(alpha: 0.3)
                            : (isRunning ? const Color(0xFF10B981).withValues(alpha: 0.25) : Colors.white10),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(statusIcon, color: statusColor, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Service: ${service?.name ?? task.serviceId}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isPulling || isStarting) ...[
                                      SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: statusColor,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      task.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Host: ${task.nodeId}',
                                  style: const TextStyle(fontSize: 11, fontFamily: 'Courier New', color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                          if (task.containerName.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  'Container: ${task.containerName}',
                                  style: const TextStyle(fontSize: 11, fontFamily: 'Courier New', color: Colors.white70),
                                ),
                                const Spacer(),
                                if (widget.onViewContainerLogs != null)
                                  InkWell(
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      widget.onViewContainerLogs!(task.containerName);
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFF8B5CF6)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.receipt_long, size: 12, color: Color(0xFF8B5CF6)),
                                          SizedBox(width: 4),
                                          Text(
                                            'Loki Stream Explorer',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF8B5CF6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (service != null) ...[
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AutoscaleControlDialog(
                                          stack: widget.stack,
                                          service: service,
                                          stackServices: widget.state.services.where((s) => s.stackId == widget.stack.id).toList(),
                                          onSaved: widget.onRefreshState,
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFA855F7).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFA855F7)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.bolt, size: 12, color: Color(0xFFA855F7)),
                                          const SizedBox(width: 4),
                                          Text(
                                            service.isAutoscalingEnabled
                                                ? 'Autoscale (${service.autoscaleMetric.toUpperCase()} • ${service.autoscaleScope})'
                                                : 'Autoscale Settings',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFA855F7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                          if (task.error.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDead
                                    ? Colors.red.withValues(alpha: 0.12)
                                    : const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isDead
                                      ? Colors.red.withValues(alpha: 0.3)
                                      : const Color(0xFF3B82F6).withValues(alpha: 0.3),
                                ),
                              ),
                              child: SelectableText(
                                isDead ? '⚠️ Error: ${task.error}' : '⏳ ${task.error}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Courier New',
                                  color: isDead ? Colors.redAccent : const Color(0xFF60A5FA),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          // Collapsible Terminal Logs Section
                          Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedLogs.remove(task.id);
                                    } else {
                                      _expandedLogs.add(task.id);
                                      if (_taskLogs[task.id] == null) {
                                        _fetchLogsForTask(task.id);
                                      }
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                                        size: 16,
                                        color: const Color(0xFF8B5CF6),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isExpanded ? 'Hide Output Logs' : 'View Container Logs (stdout/stderr)',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (isExpanded) ...[
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 14),
                                  tooltip: 'Reload Container Logs',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                  onPressed: () => _fetchLogsForTask(task.id),
                                ),
                                if (logs != null && logs.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 14),
                                    tooltip: 'Copy Output Logs',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                    onPressed: () async {
                                      await ClipboardService.copy(logs);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Container logs copied to clipboard'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ],
                          ),
                          if (isExpanded) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxHeight: 180),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: isLoading
                                  ? const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : SingleChildScrollView(
                                      child: SelectableText(
                                        (logs != null && logs.trim().isNotEmpty)
                                            ? logs
                                            : '(No stdout/stderr logs produced yet)',
                                        style: const TextStyle(
                                          fontFamily: 'Courier New',
                                          fontSize: 11,
                                          color: Color(0xFFE2E8F0),
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}


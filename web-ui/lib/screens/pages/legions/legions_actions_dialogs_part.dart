part of '../legions_page.dart';

extension _LegionsActionsDialogsExt on _LegionsPageState {

  Future<void> _taskAction(String id, String action) async {
    final ok = await ApiService.taskAction(id, action);
    if (ok) {
      _showSnackBar('Container $action executed successfully.');
      widget.onRefresh();
    } else {
      _showSnackBar('Failed to $action container.', isError: true);
    }
  }

  Future<void> _stopTask(String id) async {
    final ok = await ApiService.taskAction(id, 'stop');
    if (ok) {
      _showSnackBar('Container stopped successfully.');
      widget.onRefresh();
    } else {
      _showSnackBar('Failed to stop container.', isError: true);
    }
  }

  Future<void> _deleteTask(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Container'),
        content: const Text('Are you sure you want to remove this container?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ApiService.deleteTask(id);
    if (ok) {
      _showSnackBar('Container removed successfully.');
      widget.onRefresh();
    } else {
      _showSnackBar('Failed to remove container.', isError: true);
    }
  }

  Future<void> _viewTaskLogs(String id) async {
    try {
      final logs = await ApiService.taskLogs(id);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Container Logs'),
          content: Container(
            width: double.maxFinite,
            height: 400,
            color: Colors.black,
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              child: Text(
                logs.isEmpty ? 'No logs available.' : logs,
                style: const TextStyle(fontFamily: 'Courier New', color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    }
  }

  Future<void> _viewTaskInspect(String id) async {
    try {
      final inspectData = await ApiService.taskInspect(id);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Container Details (Inspect)'),
          content: Container(
            width: double.maxFinite,
            height: 400,
            color: Colors.grey[900],
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              child: SelectableText(
                inspectData,
                style: const TextStyle(fontFamily: 'Courier New', color: Colors.greenAccent, fontSize: 12),
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    }
  }

  void _viewTaskShell(String id, String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ShellDialog(taskId: id, containerName: name),
    );
  }

  void _showTaskAutoscaleDialog(Task t) {
    final svc = widget.state.services.where((s) => s.id == t.serviceId).firstOrNull;
    final stack = widget.state.stacks.where((st) => st.id == svc?.stackId).firstOrNull;
    showDialog(
      context: context,
      builder: (ctx) => AutoscaleControlDialog(
        stack: stack,
        service: svc,
        onSaved: widget.onRefresh,
      ),
    );
  }

  Widget _buildPortsCell(Service? svc, Node? node) {
    if (svc == null || svc.ports.isEmpty) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    }
    final nodeIp = (node != null && node.ip.isNotEmpty) ? node.ip : 'localhost';
    final host = (nodeIp == '127.0.0.1') ? 'localhost' : nodeIp;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: svc.ports.map((portMapping) {
        final hostPort = portMapping.split(':').first;
        final url = 'http://$host:$hostPort';
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ActionChip(
            avatar: Icon(Icons.open_in_new, size: 13, color: Theme.of(context).colorScheme.primary),
            label: Text(portMapping,
                style: TextStyle(fontSize: 11, fontFamily: 'Courier New', fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
            tooltip: url,
            onPressed: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                _showSnackBar('Could not open $url', isError: true);
              }
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTaskActions(Task t) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      tooltip: 'Container Actions',
      onSelected: (value) {
        switch (value) {
          case 'autoscale': _showTaskAutoscaleDialog(t); break;
          case 'shell': _viewTaskShell(t.id, t.containerName); break;
          case 'logs': _viewTaskLogs(t.id); break;
          case 'inspect': _viewTaskInspect(t.id); break;
          case 'pause': _taskAction(t.id, 'pause'); break;
          case 'unpause': _taskAction(t.id, 'unpause'); break;
          case 'restart': _taskAction(t.id, 'restart'); break;
          case 'start': _taskAction(t.id, 'start'); break;
          case 'stop': _stopTask(t.id); break;
          case 'delete': _deleteTask(t.id); break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'autoscale',
          child: ListTile(
            leading: Icon(Icons.bolt, size: 18, color: Color(0xFFA855F7)),
            title: Text('Autoscale Settings'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        if (t.status == 'running')
          const PopupMenuItem<String>(value: 'shell', child: ListTile(leading: Icon(Icons.terminal, size: 18), title: Text('Shell'), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem<String>(value: 'logs', child: ListTile(leading: Icon(Icons.notes, size: 18), title: Text('Logs'), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem<String>(value: 'inspect', child: ListTile(leading: Icon(Icons.info_outline, size: 18), title: Text('View Details'), contentPadding: EdgeInsets.zero)),
        const PopupMenuDivider(),
        if (t.status == 'running')
          const PopupMenuItem<String>(value: 'pause', child: ListTile(leading: Icon(Icons.pause, size: 18), title: Text('Pause'), contentPadding: EdgeInsets.zero))
        else if (t.status == 'paused')
          const PopupMenuItem<String>(value: 'unpause', child: ListTile(leading: Icon(Icons.play_arrow, size: 18), title: Text('Resume'), contentPadding: EdgeInsets.zero))
        else
          const PopupMenuItem<String>(value: 'start', child: ListTile(leading: Icon(Icons.play_arrow, size: 18), title: Text('Start'), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem<String>(value: 'restart', child: ListTile(leading: Icon(Icons.refresh, size: 18), title: Text('Restart'), contentPadding: EdgeInsets.zero)),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: 'stop', child: ListTile(leading: Icon(Icons.stop_circle, size: 18, color: Colors.orange), title: Text('Stop', style: TextStyle(color: Colors.orange)), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem<String>(value: 'delete', child: ListTile(leading: Icon(Icons.delete, size: 18, color: Colors.red), title: Text('Remove', style: TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero)),
      ],
    );
  }

  Future<void> _deleteStack(String id, String name) async {
    final isCore = id == 'core-gbnt-stack' || name.toLowerCase().contains('core-gbnt');
    final isMonitor = id == 'sre-monitor-stack' || name.toLowerCase().contains('monitor');

    final title = isCore ? 'Restart Core Stack'
        : isMonitor ? 'Stop Monitor Stack' : 'Delete Stack';
    final content = isCore
        ? 'Restart all core containers? This will not delete the stack or stop it permanently.'
        : isMonitor
            ? 'Stop and remove all monitor containers? The stack will remain in the dashboard for redeployment.'
            : 'Delete this stack and stop all its containers?';
    final actionText = isCore ? 'Restart' : isMonitor ? 'Stop' : 'Delete';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(actionText),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ApiService.deleteStack(id);
    final successMsg = isCore ? 'Core services restarted successfully!'
        : isMonitor ? 'Monitor containers stopped.' : 'Stack deleted and containers stopped.';
    final failMsg = isCore ? 'Failed to restart core services.'
        : isMonitor ? 'Failed to stop monitor.' : 'Failed to delete stack.';
    _showSnackBar(ok ? successMsg : failMsg, isError: !ok);
    widget.onRefresh();
  }

  Future<void> _redeployStack(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Redeploy Stack'),
        content: const Text('Stop existing containers and redeploy this stack?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Redeploy')),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ApiService.redeployStack(id);
    _showSnackBar(ok ? 'Stack redeployed!' : 'Redeploy failed.', isError: !ok);
    widget.onRefresh();
  }

  Future<void> _duplicateStack(StackModel stack) async {
    try {
      final yaml = await ApiService.getStackCompose(stack.id);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => NewStackDialog(
          initialName: '${stack.name}-copy',
          initialYaml: yaml,
          nodes: widget.state.nodes,
          onDeploy: (name, compose, targetNode) async {
            final res = await deployWithConflictResolution(
              context: ctx,
              stackName: name,
              compose: compose,
              targetNode: targetNode,
            );
            if (res.success) {
              _showSnackBar('Stack duplicated and deployed successfully!');
              widget.onRefresh();
              return null;
            }
            return res.error;
          },
        ),
      );
    } catch (e) {
      _showSnackBar('Failed to load original stack compose file', isError: true);
    }
  }

  Future<void> _openComposeEditor(StackModel stack) async {
    try {
      final yaml = await ApiService.getStackCompose(stack.id);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => ComposeEditorDialog(
          stackName: stack.name,
          composeYaml: yaml,
          nodes: widget.state.nodes,
          onSave: (y) => ApiService.updateStackCompose(stack.id, y),
          onRedeploy: (_) async {
            final ok = await ApiService.redeployStack(stack.id);
            widget.onRefresh();
            return ok;
          },
        ),
      );
    } catch (e) {
      _showSnackBar('Failed to load compose file', isError: true);
    }
  }

  Future<void> _downloadStackYaml(StackModel s) async {
    try {
      final yaml = await ApiService.getStackCompose(s.id);
      if (!mounted) return;
      await showSavePcStackDialog(
        context: context,
        initialName: s.name,
        yamlContent: yaml,
      );
    } catch (e) {
      _showSnackBar('Failed to download compose file: $e', isError: true);
    }
  }

  Future<void> _saveStackToServer(StackModel s) async {
    try {
      final yaml = await ApiService.getStackCompose(s.id);
      if (!mounted) return;
      final savedPath = await showSaveServerStackDialog(
        context: context,
        initialName: s.name,
        yamlContent: yaml,
      );
      if (savedPath != null && mounted) {
        _showSnackBar('Saved "${s.name}" to Master server: $savedPath');
      }
    } catch (e) {
      _showSnackBar('Failed to load compose file: $e', isError: true);
    }
  }

  Future<void> _showStackLogsDialog(StackModel s) async {
    showDialog(
      context: context,
      builder: (ctx) => _StackDiagnosticsDialog(
        stack: s,
        state: widget.state,
        onRefreshState: widget.onRefresh,
        onViewContainerLogs: widget.onViewContainerLogs,
      ),
    );
  }

  void _showMigrateStackDialog(StackModel s) {
    final activeNodes = widget.state.nodes
        .where((n) => n.status == 'active' || n.status == 'ready')
        .toList();
    if (activeNodes.isEmpty) {
      _showSnackBar('No active nodes available to migrate stack', isError: true);
      return;
    }
    String selectedNodeId = activeNodes.first.id;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.swap_horiz, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text('Migrate Stack: ${s.name}'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select the target host to move this stack to. All containers for "${s.name}" '
                'will be removed from their current host and redeployed on the selected target node.',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text('Target Node:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedNodeId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: activeNodes.map((n) {
                  final label = '${n.id} (${n.ip}) [${n.role.toUpperCase()}]';
                  return DropdownMenuItem<String>(
                    value: n.id,
                    child: Text(label, style: const TextStyle(fontSize: 13, fontFamily: 'Courier New')),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedNodeId = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton.icon(
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Migrate Stack'),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final ok = await ApiService.migrateStack(s.id, selectedNodeId);
                if (ok) {
                  _showSnackBar('Stack "${s.name}" successfully migrated to $selectedNodeId');
                  widget.onRefresh();
                } else {
                  _showSnackBar('Failed to migrate stack "${s.name}"', isError: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAutoscaleDialog(StackModel s) {
    final stackServices = widget.state.services.where((svc) => svc.stackId == s.id).toList();
    showDialog(
      context: context,
      builder: (ctx) => AutoscaleControlDialog(
        stack: s,
        stackServices: stackServices,
        onSaved: widget.onRefresh,
      ),
    );
  }

  void _showNewStackDialog() {
    showDialog(
      context: context,
      builder: (ctx) => NewStackDialog(
        nodes: widget.state.nodes,
        onDeploy: (name, yaml, targetNode) async {
          final res = await deployWithConflictResolution(
            context: ctx,
            stackName: name,
            compose: yaml,
            targetNode: targetNode,
          );
          if (res.success) {
            _showSnackBar('Stack deployed successfully!');
            widget.onRefresh();
            return null;
          }
          return res.error;
        },
      ),
    );
  }

  void _showServerStackPicker() {
    showDialog(
      context: context,
      builder: (ctx) => ServerStackPickerDialog(
        onSelect: (name, yaml) {
          showDialog(
            context: context,
            builder: (ctx2) => NewStackDialog(
              nodes: widget.state.nodes,
              initialName: name,
              initialYaml: yaml,
              onDeploy: (n, y, target) async {
                final res = await deployWithConflictResolution(
                  context: ctx2,
                  stackName: n,
                  compose: y,
                  targetNode: target,
                );
                if (res.success) {
                  _showSnackBar('Stack deployed successfully!');
                  widget.onRefresh();
                  return null;
                }
                return res.error;
              },
            ),
          );
        },
        onDirectDeploy: (path, name) async {
          final err = await ApiService.deployServerStack(path, name: name);
          if (err == null) {
            _showSnackBar('🚀 Stack "$name" deployed from Master server ($path)!');
            widget.onRefresh();
          } else {
            _showSnackBar('Failed: $err');
          }
        },
      ),
    );
  }

  void _showPOCExamples() {
    showDialog(
      context: context,
      builder: (ctx) => POCExamplesDialog(
        nodes: widget.state.nodes,
        onOpenInStudio: (name, yaml) {
          showDialog(
            context: context,
            builder: (ctx2) => NewStackDialog(
              nodes: widget.state.nodes,
              initialName: name,
              initialYaml: yaml,
              onDeploy: (n, y, target) async {
                final res = await deployWithConflictResolution(
                  context: ctx2,
                  stackName: n,
                  compose: y,
                  targetNode: target,
                );
                if (res.success) {
                  _showSnackBar('POC Blueprint "$n" deployed successfully!');
                  widget.onRefresh();
                  return null;
                }
                return res.error;
              },
            ),
          );
        },
        onStackDeployed: widget.onRefresh,
      ),
    );
  }

  void _showStackDiagramDialog(StackModel s) {
    showDialog(
      context: context,
      builder: (ctx) => StackDiagramDialog(
        stack: s,
        services: widget.state.services,
        tasks: widget.state.tasks,
        nodes: widget.state.nodes,
      ),
    );
  }

  Widget _actionBtn(IconData icon, String tooltip, Color color, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: color,
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
        splashRadius: 18,
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

}

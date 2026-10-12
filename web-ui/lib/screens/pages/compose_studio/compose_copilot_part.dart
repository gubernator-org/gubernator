part of '../compose_studio_page.dart';

extension _ComposeCopilotExt on _ComposeStudioPageState {

  Widget _buildTargetServiceHeader(ThemeData theme, bool isDark) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _codeController,
      builder: (context, val, _) {
        final services = ComposeSmartMerger.getServiceNames(val.text);
        final currentTarget = _effectiveTargetService;
        final labelsRange = currentTarget.isNotEmpty ? ComposeSmartMerger.getLabelsLineRange(val.text, currentTarget) : null;

        if (services.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF1F5F9),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.orange.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No se detectaron servicios en el YAML. Escribe "services:" para habilitar las opciones.',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141923) : const Color(0xFFF0FDF4),
            border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFBBF7D0))),
          ),
          child: Row(
            children: [
              Icon(Icons.alt_route, size: 14, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
              const SizedBox(width: 6),
              Text(
                'SERVICIO DESTINO:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(width: 8),
              // Dropdown selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFF38BDF8).withValues(alpha: 0.5) : const Color(0xFF0284C7).withValues(alpha: 0.4),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: services.contains(currentTarget) ? currentTarget : services.first,
                    isDense: true,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    ),
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    items: services.map((s) {
                      final range = ComposeSmartMerger.getServiceLineRange(val.text, s);
                      final rangeStr = range != null ? ' (L${range.startLine}-L${range.endLine})' : '';
                      return DropdownMenuItem<String>(
                        value: s,
                        child: Text('$s$rangeStr'),
                      );
                    }).toList(),
                    onChanged: (newService) {
                      if (newService != null) {
                        _updateState(() {
                          _selectedTargetService = newService;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (labelsRange != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '🏷️ labels: L${labelsRange.startLine}-L${labelsRange.endLine}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '🏷️ sin labels',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCopilotPanel(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: _copilotWidth,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(left: BorderSide(color: theme.dividerColor)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Copilot Header with Width Presets
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Gubernator Copilot',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  // Width Presets
                  Tooltip(
                    message: 'Standard Width (460px)',
                    child: InkWell(
                      onTap: () => _updateState(() => _copilotWidth = 460.0),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _copilotWidth == 460.0
                              ? theme.colorScheme.primary.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _copilotWidth == 460.0
                                ? theme.colorScheme.primary
                                : (isDark ? Colors.white12 : Colors.black12),
                          ),
                        ),
                        child: Text(
                          '460px',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _copilotWidth == 460.0 ? theme.colorScheme.primary : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Wide Width (680px)',
                    child: InkWell(
                      onTap: () => _updateState(() => _copilotWidth = 680.0),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _copilotWidth == 680.0
                              ? theme.colorScheme.primary.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _copilotWidth == 680.0
                                ? theme.colorScheme.primary
                                : (isDark ? Colors.white12 : Colors.black12),
                          ),
                        ),
                        child: Text(
                          '680px',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _copilotWidth == 680.0 ? theme.colorScheme.primary : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'SMART WIZARD',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Adaptive Tabs Bar (Responsive Wrap so all options fit without clipping)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _codeController,
              builder: (context, val, _) {
                final blocks = _detectComposeBlocks(val.text);
                final blocksMap = {for (var b in blocks) b.id: b};

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF14181F) : const Color(0xFFF8FAFC),
                    border: Border(bottom: BorderSide(color: theme.dividerColor)),
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildAdaptiveTabPill('Docker', 'docker', Icons.view_in_ar, const Color(0xFF38BDF8), blocksMap['docker']?.isPresent ?? false, theme, isDark),
                      _buildAdaptiveTabPill('Resources', 'resources', Icons.speed, const Color(0xFF10B981), blocksMap['resources']?.isPresent ?? false, theme, isDark),
                      _buildAdaptiveTabPill('Autoscale', 'autoscale', Icons.bolt, const Color(0xFFA855F7), blocksMap['autoscale']?.isPresent ?? false, theme, isDark),
                      _buildAdaptiveTabPill('Caddy', 'caddy', Icons.public, const Color(0xFF8B5CF6), blocksMap['caddy']?.isPresent ?? false, theme, isDark),
                      _buildAdaptiveTabPill('CoreDNS', 'coredns', Icons.dns, const Color(0xFF0D9488), blocksMap['coredns']?.isPresent ?? false, theme, isDark),
                      _buildAdaptiveTabPill('SLO', 'slo', Icons.show_chart, const Color(0xFFF59E0B), blocksMap['slo']?.isPresent ?? false, theme, isDark),
                      _buildAdaptiveTabPill('Security & WAF', 'security', Icons.security, const Color(0xFFEC4899), blocksMap['security']?.isPresent ?? false, theme, isDark),
                      _buildAdaptiveTabPill('Placement & LB', 'nodes', Icons.alt_route, const Color(0xFF06B6D4), blocksMap['nodes']?.isPresent ?? false, theme, isDark),
                      _buildAdaptiveTabPill('Storage', 'storage', Icons.storage, const Color(0xFFF97316), blocksMap['storage']?.isPresent ?? false, theme, isDark),
                      _buildAdaptiveTabPill('Templates', 'templates', Icons.dashboard_customize, const Color(0xFFEAB308), false, theme, isDark),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 1),

            // Target Service Header (Shows currently targeted service and line range)
            _buildTargetServiceHeader(theme, isDark),
            const Divider(height: 1),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_activeCopilotTab == 'autoscale') ...[
                  const Text('Autoscaling Engine (GPU & CPU)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Configure declarative horizontal autoscaling. Metrics are evaluated every 15s with automatic hardware affinity.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  _buildSnippetCard(
                    title: '⚡ GPU AI/Inference Cluster Autoscale',
                    subtitle: 'Target 80% GPU utilization across GPU Centurions (Min: 1, Max: 4)',
                    icon: Icons.developer_board,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.autoscaling.metric', 'gpu', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.autoscaling.metric', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          MapEntry('gbnt.autoscaling.enable', 'true'),
                          MapEntry('gbnt.autoscaling.metric', 'gpu'),
                          MapEntry('gbnt.autoscaling.scope', 'cluster'),
                          MapEntry('gbnt.autoscaling.target', '80'),
                          MapEntry('gbnt.autoscaling.min', '1'),
                          MapEntry('gbnt.autoscaling.max', '4'),
                          MapEntry('gbnt.autoscaling.cooldown', '45s'),
                        ],
                        categoryTitle: 'GPU Cluster Autoscaling',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          'gbnt.autoscaling.enable',
                          'gbnt.autoscaling.metric',
                          'gbnt.autoscaling.scope',
                          'gbnt.autoscaling.target',
                          'gbnt.autoscaling.min',
                          'gbnt.autoscaling.max',
                          'gbnt.autoscaling.cooldown',
                        ],
                        categoryTitle: 'GPU Cluster Autoscaling',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: '🚀 CPU High-Load Web Autoscale (Cluster)',
                    subtitle: 'Target 75% CPU load distributed across active cluster nodes (Min: 2, Max: 8)',
                    icon: Icons.speed,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.autoscaling.metric', 'cpu', _effectiveTargetService) &&
                        ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.autoscaling.scope', 'cluster', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.autoscaling.metric', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          MapEntry('gbnt.autoscaling.enable', 'true'),
                          MapEntry('gbnt.autoscaling.metric', 'cpu'),
                          MapEntry('gbnt.autoscaling.scope', 'cluster'),
                          MapEntry('gbnt.autoscaling.target', '75'),
                          MapEntry('gbnt.autoscaling.min', '2'),
                          MapEntry('gbnt.autoscaling.max', '8'),
                          MapEntry('gbnt.autoscaling.cooldown', '60s'),
                        ],
                        categoryTitle: 'CPU Cluster Autoscaling',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          'gbnt.autoscaling.enable',
                          'gbnt.autoscaling.metric',
                          'gbnt.autoscaling.scope',
                          'gbnt.autoscaling.target',
                          'gbnt.autoscaling.min',
                          'gbnt.autoscaling.max',
                          'gbnt.autoscaling.cooldown',
                        ],
                        categoryTitle: 'CPU Cluster Autoscaling',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: '💻 Single-Host CPU Autoscale (Local Host)',
                    subtitle: 'Target 85% CPU load strictly on the same host node (Min: 1, Max: 3)',
                    icon: Icons.computer,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.autoscaling.metric', 'cpu', _effectiveTargetService) &&
                        ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.autoscaling.scope', 'host', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.autoscaling.metric', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          MapEntry('gbnt.autoscaling.enable', 'true'),
                          MapEntry('gbnt.autoscaling.metric', 'cpu'),
                          MapEntry('gbnt.autoscaling.scope', 'host'),
                          MapEntry('gbnt.autoscaling.target', '85'),
                          MapEntry('gbnt.autoscaling.min', '1'),
                          MapEntry('gbnt.autoscaling.max', '3'),
                          MapEntry('gbnt.autoscaling.cooldown', '60s'),
                        ],
                        categoryTitle: 'Single-Host Autoscaling',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          'gbnt.autoscaling.enable',
                          'gbnt.autoscaling.metric',
                          'gbnt.autoscaling.scope',
                          'gbnt.autoscaling.target',
                          'gbnt.autoscaling.min',
                          'gbnt.autoscaling.max',
                          'gbnt.autoscaling.cooldown',
                        ],
                        categoryTitle: 'Single-Host Autoscaling',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                ],
                if (_activeCopilotTab == 'resources') ...[
                  const Text('CPU & RAM Resources', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Configure hard upper limits (limits) to prevent host starvation and minimum guaranteed reservations (reservations) for priority placement.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  
                  const Text('1-Click Production Presets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildSnippetCard(
                    title: '⚡ Micro Service',
                    subtitle: 'Limit: 0.25 CPU / 128MB • Reserve: 0.05 CPU / 32MB',
                    icon: Icons.bolt,
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.mergeResources(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        cpuLimit: '0.25',
                        memLimit: '128M',
                        cpuReserve: '0.05',
                        memReserve: '32M',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: '🌐 Standard Web / API App',
                    subtitle: 'Limit: 1.0 CPU / 512MB • Reserve: 0.25 CPU / 128MB',
                    icon: Icons.web,
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.mergeResources(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        cpuLimit: '1.0',
                        memLimit: '512M',
                        cpuReserve: '0.25',
                        memReserve: '128M',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: '🗄️ Database & Cache',
                    subtitle: 'Limit: 2.0 CPU / 2GB • Reserve: 0.5 CPU / 512MB',
                    icon: Icons.storage,
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.mergeResources(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        cpuLimit: '2.0',
                        memLimit: '2G',
                        cpuReserve: '0.5',
                        memReserve: '512M',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: '🧠 Data Science & ML',
                    subtitle: 'Limit: 4.0 CPU / 4GB • Reserve: 1.0 CPU / 1GB',
                    icon: Icons.science,
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.mergeResources(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        cpuLimit: '4.0',
                        memLimit: '4G',
                        cpuReserve: '1.0',
                        memReserve: '1G',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: '🤖 AI / LLM Model Serving (GPU)',
                    subtitle: 'Limit: 4.0 CPU / 8GB • Reserve: 2.0 CPU / 2GB',
                    icon: Icons.smart_toy,
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.mergeResources(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        cpuLimit: '4.0',
                        memLimit: '8G',
                        cpuReserve: '2.0',
                        memReserve: '2G',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),

                  const Divider(height: 24),
                  const Text('Custom Resources Builder:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MAX LIMITS (Hard Caps)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Max CPU:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    initialValue: _customLimitCpu,
                                    isDense: true,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: ['0.25', '0.5', '1.0', '1.5', '2.0', '4.0', '8.0'].map((v) => DropdownMenuItem(value: v, child: Text('$v Core', style: const TextStyle(fontSize: 11)))).toList(),
                                    onChanged: (val) => _updateState(() => _customLimitCpu = val ?? '1.0'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Max RAM:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    initialValue: _customLimitRam,
                                    isDense: true,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: ['128M', '256M', '512M', '1G', '2G', '4G', '8G', '16G', '32G'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 11)))).toList(),
                                    onChanged: (val) => _updateState(() => _customLimitRam = val ?? '512M'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('MIN RESERVATIONS (Guaranteed)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Min CPU:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    initialValue: _customReserveCpu,
                                    isDense: true,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: ['0.05', '0.1', '0.25', '0.5', '1.0', '2.0'].map((v) => DropdownMenuItem(value: v, child: Text('$v Core', style: const TextStyle(fontSize: 11)))).toList(),
                                    onChanged: (val) => _updateState(() => _customReserveCpu = val ?? '0.25'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Min RAM:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    initialValue: _customReserveRam,
                                    isDense: true,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: ['32M', '64M', '128M', '256M', '512M', '1G', '2G', '4G'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 11)))).toList(),
                                    onChanged: (val) => _updateState(() => _customReserveRam = val ?? '128M'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.sync, size: 16),
                            label: const Text('Apply / Update Resources in YAML', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              _applySmartMerge(ComposeSmartMerger.mergeResources(
                                _codeController.text,
                                _codeController.selection.baseOffset,
                                cpuLimit: _customLimitCpu,
                                memLimit: _customLimitRam,
                                cpuReserve: _customReserveCpu,
                                memReserve: _customReserveRam,
                                targetServiceName: _effectiveTargetService,
                              ));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_activeCopilotTab == 'docker') ...[
                  const Text('Docker Copilot Options', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Inject essential Docker Compose blocks: ports, volumes, resource limits, restart policies, and environment overrides.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  _buildSnippetCard(
                    title: 'HTTP & HTTPS Ports (80, 443)',
                    subtitle: 'Standard web ingress port bindings',
                    icon: Icons.input,
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.mergePorts(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        ['80:80', '443:443'],
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Database Port 5432 (Postgres)',
                    subtitle: 'Expose PostgreSQL database port',
                    icon: Icons.storage,
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.mergePorts(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        ['5432:5432'],
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Persistent Volume Mount',
                    subtitle: '/var/contenedores/\${STACK_NAME}/data:/data',
                    icon: Icons.folder_special,
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.mergeVolumeMount(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        r'/var/contenedores/${STACK_NAME}/data:/data',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Read-Only Config Mount',
                    subtitle: './config.yml:/etc/app/config.yml:ro',
                    icon: Icons.insert_drive_file,
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.mergeVolumeMount(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        './config.yml:/etc/app/config.yml:ro',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Resource Limits (RAM 1GB / CPU 1.5)',
                    subtitle: 'Prevent container from starving host resources',
                    icon: Icons.speed,
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.mergeResources(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        cpuLimit: '1.5',
                        memLimit: '1G',
                        cpuReserve: '0.5',
                        memReserve: '256M',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Restart Policy: unless-stopped',
                    subtitle: 'Auto-restart container on host reboot',
                    icon: Icons.autorenew,
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.mergeRestartPolicy(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        'unless-stopped',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Environment Variables Block',
                    subtitle: 'Define NODE_ENV, LOG_LEVEL, and credentials',
                    icon: Icons.tune,
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.mergeEnvironment(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          MapEntry('NODE_ENV', 'production'),
                          MapEntry('LOG_LEVEL', 'info'),
                          MapEntry('DB_HOST', 'db'),
                        ],
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Container Healthcheck Probe',
                    subtitle: 'HTTP healthcheck every 10 seconds',
                    icon: Icons.favorite,
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.mergeHealthcheck(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        testCmd: 'http://localhost:8080/health',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                ],

                if (_activeCopilotTab == 'caddy') ...[
                  const Text('Caddy Ingress Suite & WAF', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Expose your service via Caddy proxy with CoreDNS automatic resolution and Layer 7 Threat Shield.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  _buildSnippetCard(
                    title: 'Standard HTTP Ingress',
                    subtitle: 'ingress.host=app.gbnt.local & port=80',
                    icon: Icons.public,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'ingress.host', null, _effectiveTargetService) &&
                        !ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.waf.enabled', 'true', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'ingress.host', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          MapEntry('ingress.host', 'app.gbnt.local'),
                          MapEntry('gbnt.caddy.port', '80'),
                        ],
                        categoryTitle: 'Caddy HTTP Ingress',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['ingress.host', 'gbnt.caddy.port'],
                        categoryTitle: 'Caddy HTTP Ingress',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Ingress + Threat Shield WAF (Enforce)',
                    subtitle: 'Expose host with active L7 WAF blocking OWASP attacks (403)',
                    icon: Icons.shield,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.waf.mode', 'enforce', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.waf.mode', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          MapEntry('ingress.host', 'app.gbnt.local'),
                          MapEntry('gbnt.caddy.port', '80'),
                          MapEntry('gbnt.waf.enabled', 'true'),
                          MapEntry('gbnt.waf.mode', 'enforce'),
                        ],
                        categoryTitle: 'Caddy WAF Ingress',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['ingress.host', 'gbnt.caddy.port', 'gbnt.waf.enabled', 'gbnt.waf.mode'],
                        categoryTitle: 'Caddy WAF Ingress',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Threat Shield WAF (Detection / Audit)',
                    subtitle: 'gbnt.waf.enabled=true & gbnt.waf.mode=detection (Log & inspect only)',
                    icon: Icons.remove_red_eye_outlined,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.waf.mode', 'detection', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.waf.mode', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          MapEntry('gbnt.waf.enabled', 'true'),
                          MapEntry('gbnt.waf.mode', 'detection'),
                        ],
                        categoryTitle: 'WAF Detection Mode',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['gbnt.waf.enabled', 'gbnt.waf.mode'],
                        categoryTitle: 'WAF Detection Mode',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Internal TLS Ingress',
                    subtitle: 'Automatic Caddy internal certificate',
                    icon: Icons.lock,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.caddy.tls', 'internal', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.caddy.tls', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          MapEntry('ingress.host', 'secure.gbnt.local'),
                          MapEntry('gbnt.caddy.port', '443'),
                          MapEntry('gbnt.caddy.tls', 'internal'),
                        ],
                        categoryTitle: 'Caddy TLS Ingress',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['ingress.host', 'gbnt.caddy.port', 'gbnt.caddy.tls'],
                        categoryTitle: 'Caddy TLS Ingress',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                ],

                if (_activeCopilotTab == 'coredns') ...[
                  Row(
                    children: [
                      const Icon(Icons.dns, size: 20, color: Color(0xFF0D9488)),
                      const SizedBox(width: 8),
                      const Text('CoreDNS Resolver & DNS Suite', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text(
                              _clusterCoreDnsIp,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Inyecta el servidor CoreDNS de Gubernator ($_clusterCoreDnsIp:53) para resolución de nombres interna entre servicios (*.$_clusterDomain) y clúster multi-nodo.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  _buildSnippetCard(
                    title: 'Inyectar CoreDNS (Servicio Actual)',
                    subtitle: 'dns: [$_clusterCoreDnsIp] & dns_search: [$_clusterDomain, gbnt]',
                    icon: Icons.dns,
                    onTap: () => _injectCoreDNS(allServices: false),
                  ),
                  _buildSnippetCard(
                    title: 'Inyectar CoreDNS en Todos los Servicios',
                    subtitle: 'Aplica el resolver CoreDNS a todos los contenedores de este Compose',
                    icon: Icons.hub,
                    onTap: () => _injectCoreDNS(allServices: true),
                  ),
                  _buildSnippetCard(
                    title: 'Inyectar CoreDNS + Upstream Fallback',
                    subtitle: 'dns: [$_clusterCoreDnsIp, 8.8.8.8, 1.1.1.1] con redundancia externa',
                    icon: Icons.alt_route,
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.mergeDNS(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        dnsServers: [_clusterCoreDnsIp, '8.8.8.8', '1.1.1.1'],
                        searchDomains: [_clusterDomain, 'gbnt'],
                        allServices: false,
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Solo Search Domains ($_clusterDomain, gbnt)',
                    subtitle: 'dns_search: [$_clusterDomain, gbnt] para autocompletado de dominios cortos',
                    icon: Icons.domain,
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.mergeDNS(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        dnsServers: [],
                        searchDomains: [_clusterDomain, 'gbnt'],
                        allServices: false,
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                ],

                if (_activeCopilotTab == 'slo') ...[
                  const Text('SLO Engine (Sloth Alerts)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Inject Google SRE Multi-Burn-Rate alerting rules and error budgets.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  _buildSnippetCard(
                    title: '99.9% High Availability SLO',
                    subtitle: '30-day window availability budget',
                    icon: Icons.speed,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.slo.target', '99.9', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.slo.target', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          MapEntry('gbnt.slo.enable', 'true'),
                          MapEntry('gbnt.slo.target', '99.9'),
                          MapEntry('gbnt.slo.window', '30d'),
                        ],
                        categoryTitle: '99.9% Availability SLO',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['gbnt.slo.enable', 'gbnt.slo.target', 'gbnt.slo.window'],
                        categoryTitle: '99.9% Availability SLO',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Latency < 200ms Threshold',
                    subtitle: 'Triggers multi-burn alerts on slow requests',
                    icon: Icons.timer,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.slo.indicator', 'latency', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.slo.indicator', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          MapEntry('gbnt.slo.enable', 'true'),
                          MapEntry('gbnt.slo.target', '99.0'),
                          MapEntry('gbnt.slo.indicator', 'latency'),
                          MapEntry('gbnt.slo.latency.threshold', '200ms'),
                        ],
                        categoryTitle: 'Latency SLO',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['gbnt.slo.enable', 'gbnt.slo.target', 'gbnt.slo.indicator', 'gbnt.slo.latency.threshold'],
                        categoryTitle: 'Latency SLO',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                ],

                if (_activeCopilotTab == 'security') ...[
                  const Text('Security Gatekeeper, Cosign & Threat Shield WAF', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Enforce cryptographic signatures, CVE policies and Layer 7 Threat Shield WAF.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  _buildSnippetCard(
                    title: 'Threat Shield WAF (Enforce Mode)',
                    subtitle: 'gbnt.waf.enabled=true & gbnt.waf.mode=enforce (Blocks SQLi, XSS, RCE with 403)',
                    icon: Icons.shield,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.waf.mode', 'enforce', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.waf.mode', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          MapEntry('gbnt.waf.enabled', 'true'),
                          MapEntry('gbnt.waf.mode', 'enforce'),
                        ],
                        categoryTitle: 'Threat Shield WAF',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['gbnt.waf.enabled', 'gbnt.waf.mode'],
                        categoryTitle: 'Threat Shield WAF',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Threat Shield WAF (Detection / Audit)',
                    subtitle: 'gbnt.waf.enabled=true & gbnt.waf.mode=detection (Non-blocking SIEM logs)',
                    icon: Icons.policy_outlined,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.waf.mode', 'detection', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.waf.mode', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          MapEntry('gbnt.waf.enabled', 'true'),
                          MapEntry('gbnt.waf.mode', 'detection'),
                        ],
                        categoryTitle: 'WAF Audit Mode',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['gbnt.waf.enabled', 'gbnt.waf.mode'],
                        categoryTitle: 'WAF Audit Mode',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Enforce Cryptographic Signatures',
                    subtitle: 'Blocks deployment if image is not Cosign-signed (Zero-Trust)',
                    icon: Icons.verified_user,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.security.require-signature', 'true', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.security.require-signature', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          MapEntry('gbnt.security.require-signature', 'true'),
                        ],
                        categoryTitle: 'Signature Gatekeeper',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['gbnt.security.require-signature'],
                        categoryTitle: 'Signature Gatekeeper',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Block Critical CVE Vulnerabilities',
                    subtitle: 'Rejects images with unpatched critical CVEs (CVSS >= 9.0)',
                    icon: Icons.security,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.security.max-cve-severity', 'critical', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.security.max-cve-severity', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          MapEntry('gbnt.security.max-cve-severity', 'critical'),
                        ],
                        categoryTitle: 'Critical CVE Policy',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['gbnt.security.max-cve-severity'],
                        categoryTitle: 'Critical CVE Policy',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Block High & Critical CVEs',
                    subtitle: 'Stricter threshold rejecting both High and Critical CVEs',
                    icon: Icons.shield_outlined,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.security.max-cve-severity', 'high', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.security.max-cve-severity', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          MapEntry('gbnt.security.max-cve-severity', 'high'),
                        ],
                        categoryTitle: 'High CVE Policy',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['gbnt.security.max-cve-severity'],
                        categoryTitle: 'High CVE Policy',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Full Zero-Trust & WAF Shield Suite',
                    subtitle: 'Signature check + critical CVE block + Threat Shield WAF enforce',
                    icon: Icons.verified,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.security.require-signature', 'true', _effectiveTargetService) &&
                        ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.waf.enabled', 'true', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.security.require-signature', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          MapEntry('gbnt.security.require-signature', 'true'),
                          MapEntry('gbnt.security.max-cve-severity', 'critical'),
                          MapEntry('gbnt.security.allow-unfixed-cve', 'false'),
                          MapEntry('gbnt.waf.enabled', 'true'),
                          MapEntry('gbnt.waf.mode', 'enforce'),
                        ],
                        categoryTitle: 'Zero-Trust & WAF Suite',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          'gbnt.security.require-signature',
                          'gbnt.security.max-cve-severity',
                          'gbnt.security.allow-unfixed-cve',
                          'gbnt.waf.enabled',
                          'gbnt.waf.mode',
                        ],
                        categoryTitle: 'Zero-Trust & WAF Suite',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                ],

                if (_activeCopilotTab == 'nodes') ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.hub, color: Color(0xFF06B6D4), size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Multi-Host Placement & LB (Labels-First)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Distribute replicas across nodes & balance HTTP traffic via labels.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Color(0xFF06B6D4)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'En Gubernator v3.0+, todas las reglas de afinidad, roles y balanceo se configuran limpiamente como labels (gbnt.node.*, gbnt.placement.*), sin anidaciones profundas.',
                            style: TextStyle(fontSize: 11, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Distribution Strategy & Anti-Affinity:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildSnippetCard(
                    title: 'Anti-Affinity Spread Strategy',
                    subtitle: 'gbnt.placement.strategy=spread (Multi-Host)',
                    icon: Icons.alt_route,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.placement.strategy', 'spread', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.placement.strategy', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [MapEntry('gbnt.placement.strategy', 'spread')],
                        categoryTitle: 'Spread Strategy',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['gbnt.placement.strategy', 'gbnt.placement'],
                        categoryTitle: 'Spread Strategy',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Caddy Ingress Dynamic Load Balancing:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildSnippetCard(
                    title: 'Round Robin Policy (Default)',
                    subtitle: 'gbnt.caddy.lb=round_robin',
                    icon: Icons.balance,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.caddy.lb', 'round_robin', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.caddy.lb', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [MapEntry('gbnt.caddy.lb', 'round_robin')],
                        categoryTitle: 'Caddy Load Balancing',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['gbnt.caddy.lb'],
                        categoryTitle: 'Caddy Load Balancing',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Least Connections Policy',
                    subtitle: 'gbnt.caddy.lb=least_conn',
                    icon: Icons.speed,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.caddy.lb', 'least_conn', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.caddy.lb', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [MapEntry('gbnt.caddy.lb', 'least_conn')],
                        categoryTitle: 'Caddy Load Balancing',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['gbnt.caddy.lb'],
                        categoryTitle: 'Caddy Load Balancing',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'IP Hash (Sticky Sessions)',
                    subtitle: 'gbnt.caddy.lb=ip_hash',
                    icon: Icons.pin_drop,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.caddy.lb', 'ip_hash', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.caddy.lb', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [MapEntry('gbnt.caddy.lb', 'ip_hash')],
                        categoryTitle: 'Caddy Load Balancing',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['gbnt.caddy.lb'],
                        categoryTitle: 'Caddy Load Balancing',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Active Health Check Probe',
                    subtitle: 'gbnt.caddy.health_uri=/health (5s interval)',
                    icon: Icons.health_and_safety,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.caddy.health_uri', null, _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.caddy.health_uri', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [
                          MapEntry('gbnt.caddy.health_uri', '/health'),
                          MapEntry('gbnt.caddy.health_interval', '5s'),
                        ],
                        categoryTitle: 'Caddy Health Check',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['gbnt.caddy.health_uri', 'gbnt.caddy.health_interval'],
                        categoryTitle: 'Caddy Health Check',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Hardware Affinity & Node Roles:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildSnippetCard(
                    title: 'Worker Nodes Only',
                    subtitle: 'gbnt.node.role=worker (Labels-First)',
                    icon: Icons.group_work,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.node.role', 'worker', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.node.role', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [MapEntry('gbnt.node.role', 'worker')],
                        categoryTitle: 'Worker Role Affinity',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['gbnt.node.role', 'node.role'],
                        categoryTitle: 'Worker Role Affinity',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Manager Node Only',
                    subtitle: 'gbnt.node.role=manager (Labels-First)',
                    icon: Icons.star,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.node.role', 'manager', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.node.role', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [MapEntry('gbnt.node.role', 'manager')],
                        categoryTitle: 'Manager Role Affinity',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['gbnt.node.role', 'node.role'],
                        categoryTitle: 'Manager Role Affinity',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'NVIDIA GPU Accelerated Node',
                    subtitle: 'gbnt.node.gpu=nvidia (Labels-First)',
                    icon: Icons.developer_board,
                    isActive: ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.node.gpu', 'nvidia', _effectiveTargetService),
                    activeLine: ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.node.gpu', targetServiceName: _effectiveTargetService),
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.toggleLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const [MapEntry('gbnt.node.gpu', 'nvidia')],
                        categoryTitle: 'GPU Affinity',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                    onRemove: () {
                      _applySmartMerge(ComposeSmartMerger.removeLabels(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        const ['gbnt.node.gpu', 'node.gpu'],
                        categoryTitle: 'GPU Affinity',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  const Divider(height: 24),
                  const Text('Active Cluster Nodes (Pinning via Labels):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...widget.state.nodes.map((node) {
                    final isPinned = ComposeSmartMerger.hasLabel(_codeController.text, _codeController.selection.baseOffset, 'gbnt.node.hostname', node.id, _effectiveTargetService);
                    final pinLine = ComposeSmartMerger.getLabelLine(_codeController.text, 'gbnt.node.hostname', targetServiceName: _effectiveTargetService);
                    final pinLineStr = pinLine != null ? ' • L$pinLine' : '';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isPinned ? const Color(0xFF10B981) : Theme.of(context).dividerColor,
                          width: isPinned ? 1.5 : 1.0,
                        ),
                      ),
                      color: isPinned ? const Color(0xFF10B981).withValues(alpha: 0.05) : null,
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          node.role == 'manager' ? Icons.star : Icons.dns,
                          color: isPinned ? const Color(0xFF10B981) : (node.status == 'active' ? Colors.green : Colors.grey),
                          size: 20,
                        ),
                        title: Row(
                          children: [
                            Text(node.id, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            if (isPinned) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('ANCLADO$pinLineStr', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text('${node.ip} • ${node.role.toUpperCase()}', style: const TextStyle(fontSize: 10)),
                        trailing: IconButton(
                          icon: Icon(
                            isPinned ? Icons.check_circle : Icons.add_circle_outline,
                            color: isPinned ? const Color(0xFF10B981) : Theme.of(context).colorScheme.primary,
                            size: 18,
                          ),
                          tooltip: isPinned ? 'Desanclar de ${node.id}$pinLineStr' : 'Anclar a ${node.id}',
                          onPressed: () {
                            if (isPinned) {
                              _applySmartMerge(ComposeSmartMerger.removeLabels(
                                _codeController.text,
                                _codeController.selection.baseOffset,
                                const ['gbnt.node.hostname', 'node.hostname'],
                                categoryTitle: 'Node Pinning',
                                targetServiceName: _effectiveTargetService,
                              ));
                            } else {
                              _applySmartMerge(ComposeSmartMerger.mergeLabels(
                                _codeController.text,
                                _codeController.selection.baseOffset,
                                [MapEntry('gbnt.node.hostname', node.id)],
                                categoryTitle: 'Pin to ${node.id}',
                                targetServiceName: _effectiveTargetService,
                              ));
                            }
                          },
                        ),
                      ),
                    );
                  }),
                ],

                if (_activeCopilotTab == 'storage') ...[
                  const Text('Storage Granaries (/var/contenedores)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Deploy shared storage mounts compatible with cluster-wide backups.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  _buildSnippetCard(
                    title: 'App Data Shared Mount',
                    subtitle: '/var/contenedores/\${STACK_NAME}/data:/data',
                    icon: Icons.storage,
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.mergeVolumeMount(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        r'/var/contenedores/${STACK_NAME}/data:/data',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                  _buildSnippetCard(
                    title: 'Database Storage Pool',
                    subtitle: '/var/contenedores/\${STACK_NAME}/db:/var/lib/db',
                    icon: Icons.inventory_2,
                    onTap: () {
                      _applySmartMerge(ComposeSmartMerger.mergeVolumeMount(
                        _codeController.text,
                        _codeController.selection.baseOffset,
                        r'/var/contenedores/${STACK_NAME}/db:/var/lib/db',
                        targetServiceName: _effectiveTargetService,
                      ));
                    },
                  ),
                ],

                if (_activeCopilotTab == 'templates') ...[
                  const Text('Starter Templates', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Click a template to load a production-ready Docker Compose blueprint.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ..._starterTemplates.keys.map((tName) => _buildSnippetCard(
                    title: tName,
                    subtitle: 'Load complete $tName compose file',
                    icon: Icons.layers,
                    onTap: () => _applyTemplate(tName),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSnippetCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
    VoidCallback? onRemove,
    int? activeLine,
  }) {
    final theme = Theme.of(context);
    const activeColor = Color(0xFF10B981);
    final lineStr = activeLine != null ? ' • L$activeLine' : '';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isActive ? activeColor.withValues(alpha: 0.7) : theme.dividerColor,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      color: isActive ? activeColor.withValues(alpha: 0.04) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Left & Center Area: Tappable card body
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isActive ? activeColor : theme.colorScheme.primary).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(icon, size: 18, color: isActive ? activeColor : theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                ),
                                if (isActive) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: activeColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check, size: 10, color: activeColor),
                                        const SizedBox(width: 2),
                                        Text('ACTIVO$lineStr', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: activeColor)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(subtitle, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Trailing Action Area: Completely separate from the card's InkWell
            if (isActive && onRemove != null) ...[
              Tooltip(
                message: 'Quitar configuración del YAML$lineStr',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1),
                      ),
                      child: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],

            Tooltip(
              message: isActive ? 'Ya configurado en el YAML$lineStr (Click para alternar)' : 'Añadir configuración al YAML',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (isActive ? activeColor : theme.colorScheme.primary).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isActive ? Icons.check_circle : Icons.add_circle_outline,
                      size: 16,
                      color: isActive ? activeColor : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

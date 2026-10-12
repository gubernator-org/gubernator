part of '../compose_studio_page.dart';

extension _ComposeBlocksNavigatorExt on _ComposeStudioPageState {

  List<_ComposeBlockSegment> _detectComposeBlocks(String yaml) {
    final lines = yaml.split('\n');
    final blockLines = <String, List<int>>{
      'docker': [],
      'resources': [],
      'autoscale': [],
      'caddy': [],
      'coredns': [],
      'slo': [],
      'security': [],
      'nodes': [],
      'storage': [],
    };

    final summaries = <String, String>{
      'docker': '',
      'resources': '',
      'autoscale': '',
      'caddy': '',
      'coredns': '',
      'slo': '',
      'security': '',
      'nodes': '',
      'storage': '',
    };

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      final lineNum = i + 1; // 1-indexed

      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      // Docker Core
      if (trimmed.startsWith('services:') ||
          trimmed.startsWith('image:') ||
          trimmed.startsWith('container_name:') ||
          trimmed.startsWith('ports:') ||
          trimmed.startsWith('environment:') ||
          trimmed.startsWith('command:') ||
          trimmed.startsWith('restart:') ||
          trimmed.startsWith('networks:') ||
          trimmed.startsWith('build:')) {
        blockLines['docker']!.add(lineNum);
        if (trimmed.startsWith('image:') && summaries['docker']!.isEmpty) {
          summaries['docker'] = trimmed.replaceFirst('image:', '').trim();
        }
      }

      // Resources
      if (trimmed.startsWith('resources:') ||
          trimmed.startsWith('limits:') ||
          trimmed.startsWith('reservations:') ||
          trimmed.startsWith('cpus:') ||
          trimmed.startsWith('memory:') ||
          trimmed.startsWith('mem_limit:') ||
          trimmed.startsWith('mem_reservation:')) {
        blockLines['resources']!.add(lineNum);
        if (trimmed.startsWith('cpus:') && summaries['resources']!.isEmpty) {
          summaries['resources'] = trimmed.replaceAll('"', '').trim();
        }
      }

      // Autoscaling
      if (trimmed.contains('gbnt.autoscaling')) {
        blockLines['autoscale']!.add(lineNum);
        if (trimmed.contains('metric=gpu') || trimmed.contains('metric: gpu') || trimmed.contains('gpu')) {
          summaries['autoscale'] = 'GPU Autoscale';
        } else if (summaries['autoscale']!.isEmpty) {
          summaries['autoscale'] = 'Autoscale';
        }
      }

      // Caddy Ingress
      if (trimmed.contains('ingress.host') ||
          trimmed.contains('gbnt.caddy') ||
          trimmed.contains('gbnt.waf') ||
          trimmed.contains('caddy.port') ||
          trimmed.contains('caddy_route') ||
          trimmed.contains('caddy_tls') ||
          trimmed.contains('caddyfile')) {
        blockLines['caddy']!.add(lineNum);
        if (trimmed.contains('ingress.host=') && summaries['caddy']!.isEmpty) {
          final parts = trimmed.split('ingress.host=');
          if (parts.length > 1) {
            summaries['caddy'] = parts[1].replaceAll('"', '').replaceAll("'", "").trim();
          }
        } else if (trimmed.contains('gbnt.waf') && summaries['caddy']!.isEmpty) {
          summaries['caddy'] = trimmed.contains('detection') ? 'WAF Detection' : 'WAF Shield';
        }
      }

      // CoreDNS & DNS Resolution
      if (trimmed.startsWith('dns:') ||
          trimmed.startsWith('dns_search:') ||
          trimmed.contains('gbnt-coredns') ||
          (trimmed.startsWith('- ') && trimmed.contains('gbnt.local') && !trimmed.contains('ingress.host'))) {
        blockLines['coredns']!.add(lineNum);
        if (summaries['coredns']!.isEmpty) {
          summaries['coredns'] = 'CoreDNS';
        }
      }

      // SLO
      if (trimmed.contains('gbnt.slo')) {
        blockLines['slo']!.add(lineNum);
        if (trimmed.contains('gbnt.slo.objective=') && summaries['slo']!.isEmpty) {
          final parts = trimmed.split('gbnt.slo.objective=');
          if (parts.length > 1) {
            summaries['slo'] = 'SLO ${parts[1].replaceAll('"', '').replaceAll("'", "").trim()}%';
          }
        }
      }

      // Security & WAF
      if (trimmed.contains('gbnt.security') ||
          trimmed.contains('gbnt.waf') ||
          trimmed.contains('cosign') ||
          trimmed.contains('max_severity')) {
        blockLines['security']!.add(lineNum);
        if (trimmed.contains('gbnt.waf.enabled=true') && summaries['security']!.isEmpty) {
          summaries['security'] = 'WAF Shield';
        } else if (trimmed.contains('gbnt.security.signed=') && summaries['security']!.isEmpty) {
          summaries['security'] = 'Signed';
        }
      }

      // Nodes & Placement
      if (trimmed.startsWith('placement:') ||
          trimmed.startsWith('constraints:') ||
          trimmed.startsWith('preferences:') ||
          trimmed.contains('spread:') ||
          trimmed.contains('node.role') ||
          trimmed.contains('gbnt.node.') ||
          trimmed.contains('gbnt.placement.') ||
          trimmed.contains('gbnt.caddy.lb')) {
        blockLines['nodes']!.add(lineNum);
        if ((trimmed.contains('spread:') || trimmed.contains('gbnt.caddy.lb') || trimmed.contains('node.role')) && summaries['nodes']!.isEmpty) {
          summaries['nodes'] = trimmed.replaceAll('"', '').replaceAll("'", "").replaceAll('- ', '').trim();
        }
      }

      // Storage
      if (trimmed.startsWith('volumes:') ||
          trimmed.contains('/var/contenedores') ||
          trimmed.contains('driver: local')) {
        blockLines['storage']!.add(lineNum);
        if (trimmed.contains('/var/contenedores') && summaries['storage']!.isEmpty) {
          summaries['storage'] = 'Granaries';
        }
      }
    }

    final configs = [
      ('docker', 'Docker Core', Icons.view_in_ar, const Color(0xFF38BDF8)),
      ('resources', 'Resources', Icons.speed, const Color(0xFF10B981)),
      ('autoscale', 'Autoscale', Icons.bolt, const Color(0xFFA855F7)),
      ('caddy', 'Caddy Ingress', Icons.public, const Color(0xFF8B5CF6)),
      ('coredns', 'CoreDNS (DNS)', Icons.dns, const Color(0xFF0D9488)),
      ('slo', 'Sloth SLO', Icons.show_chart, const Color(0xFFF59E0B)),
      ('security', 'Security & WAF', Icons.security, const Color(0xFFEC4899)),
      ('nodes', 'Placement & LB', Icons.alt_route, const Color(0xFF06B6D4)),
      ('storage', 'Storage', Icons.storage, const Color(0xFFF97316)),
    ];

    return configs.map((c) {
      final list = blockLines[c.$1]!;
      final isPresent = list.isNotEmpty;
      final start = isPresent ? list.reduce((a, b) => a < b ? a : b) : 0;
      final end = isPresent ? list.reduce((a, b) => a > b ? a : b) : 0;
      return _ComposeBlockSegment(
        id: c.$1,
        title: c.$2,
        icon: c.$3,
        color: c.$4,
        startLine: start,
        endLine: end,
        isPresent: isPresent,
        summary: summaries[c.$1] ?? '',
      );
    }).toList();
  }

  void _jumpToBlock(_ComposeBlockSegment block) {
    if (!block.isPresent) {
      _updateState(() {
        _activeCopilotTab = block.id;
        if (!_copilotExpanded) _copilotExpanded = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ Opened Smart Wizard: ${block.title}. Choose a preset to insert it!'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          width: 420,
        ),
      );
      return;
    }

    final text = _codeController.text;
    final lines = text.split('\n');
    int offset = 0;
    for (int i = 0; i < block.startLine - 1 && i < lines.length; i++) {
      offset += lines[i].length + 1;
    }
    offset = offset.clamp(0, text.length);

    int endOffset = offset;
    if (block.startLine - 1 < lines.length) {
      endOffset = (offset + lines[block.startLine - 1].length).clamp(0, text.length);
    }

    _codeController.selection = TextSelection(
      baseOffset: offset,
      extentOffset: endOffset,
    );
    _editorFocusNode.requestFocus();

    _updateState(() {
      _activeCopilotTab = block.id;
      if (!_copilotExpanded) _copilotExpanded = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 Jumped to ${block.title} block (Line ${block.startLine})'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 320,
      ),
    );
  }

  Widget _buildAdaptiveTabPill(
    String title,
    String id,
    IconData icon,
    Color color,
    bool isConfiguredInYaml,
    ThemeData theme,
    bool isDark,
  ) {
    final active = _activeCopilotTab == id;

    return InkWell(
      onTap: () => _updateState(() => _activeCopilotTab = id),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? color : (isDark ? Colors.white12 : Colors.black12),
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? color : (isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? color : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            if (isConfiguredInYaml) ...[
              const SizedBox(width: 5),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildBlocksNavigatorBar(ThemeData theme, bool isDark) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _codeController,
      builder: (context, val, _) {
        final blocks = _detectComposeBlocks(val.text);
        final activeCount = blocks.where((b) => b.isPresent).length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
            border: Border(
              bottom: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.dashboard_outlined, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'BLOCKS:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: blocks.map((b) {
                      final isCurrentActive = _activeCopilotTab == b.id;
                      if (b.isPresent) {
                        final lineText = b.startLine == b.endLine ? 'L${b.startLine}' : 'L${b.startLine}-${b.endLine}';
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => _jumpToBlock(b),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: b.color.withValues(alpha: isDark ? 0.18 : 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isCurrentActive ? b.color : b.color.withValues(alpha: 0.4),
                                  width: isCurrentActive ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(b.icon, size: 12, color: b.color),
                                  const SizedBox(width: 5),
                                  Text(
                                    b.title,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isCurrentActive ? FontWeight.bold : FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: b.color.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      lineText,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        color: b.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else {
                        // Not present in YAML
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => _jumpToBlock(b),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, size: 11, color: isDark ? Colors.white54 : Colors.black45),
                                  const SizedBox(width: 4),
                                  Text(
                                    b.title,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: activeCount >= 4
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$activeCount/7 Configured',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: activeCount >= 4 ? const Color(0xFF10B981) : theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBlockGutterStrip(ThemeData theme, bool isDark) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _codeController,
      builder: (context, value, _) {
        final blocks = _detectComposeBlocks(value.text).where((b) => b.isPresent).toList();
        if (blocks.isEmpty) return const SizedBox.shrink();

        return Container(
          width: 34,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B2028) : const Color(0xFFF1F5F9),
            border: Border(
              right: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              ...blocks.map((b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Tooltip(
                  message: '${b.title} (Lines ${b.startLine}-${b.endLine})\nClick to jump to block in YAML',
                  child: InkWell(
                    onTap: () => _jumpToBlock(b),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: b.color.withValues(alpha: isDark ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: b.color, width: 1.2),
                      ),
                      child: Center(
                        child: Icon(b.icon, size: 13, color: b.color),
                      ),
                    ),
                  ),
                ),
              )),
              const Spacer(),
              Tooltip(
                message: 'Active Architecture Blocks in YAML',
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${blocks.length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResizableDivider(ThemeData theme, bool isDark) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => _updateState(() => _isDraggingDivider = true),
        onHorizontalDragEnd: (_) => _updateState(() => _isDraggingDivider = false),
        onDoubleTap: () {
          _updateState(() {
            _copilotWidth = _copilotWidth > 550 ? 460.0 : 680.0;
          });
        },
        onHorizontalDragUpdate: (details) {
          _updateState(() {
            _copilotWidth = (_copilotWidth - details.delta.dx).clamp(320.0, 920.0);
          });
        },
        child: Container(
          width: 12,
          color: isDark ? const Color(0xFF1E2228) : const Color(0xFFE2E8F0),
          child: Center(
            child: Container(
              width: 4,
              height: 54,
              decoration: BoxDecoration(
                color: _isDraggingDivider
                    ? theme.colorScheme.primary
                    : (isDark ? Colors.white38 : Colors.black26),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditorActionBar(ThemeData theme, bool isDark) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2228) : const Color(0xFFE2E8F0),
        border: Border(
          bottom: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? Colors.black38 : Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: const Row(
              children: [
                Icon(Icons.code, size: 13, color: Colors.cyanAccent),
                SizedBox(width: 6),
                Text(
                  'YAML Editor',
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Copy Selection button
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              visualDensity: VisualDensity.compact,
              backgroundColor: Colors.cyan.withValues(alpha: 0.2),
              foregroundColor: Colors.cyanAccent,
            ),
            icon: const Icon(Icons.content_copy, size: 14),
            label: const Text('Copy Selection (Ctrl+C)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () => _handleCopy(forceAll: false),
          ),
          const SizedBox(width: 6),

          // Copy All YAML
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.copy_all, size: 14),
            label: const Text('Copy All YAML', style: TextStyle(fontSize: 11)),
            onPressed: () => _handleCopy(forceAll: true),
          ),
          const SizedBox(width: 4),

          // Paste
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.paste, size: 14),
            label: const Text('Paste (Ctrl+V)', style: TextStyle(fontSize: 11)),
            onPressed: _handlePaste,
          ),
          const SizedBox(width: 4),

          // Select All
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.select_all, size: 14),
            label: const Text('Select All (Ctrl+A)', style: TextStyle(fontSize: 11)),
            onPressed: _handleSelectAll,
          ),
          const SizedBox(width: 4),

          // Inyectar CoreDNS
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
              foregroundColor: const Color(0xFF10B981),
            ),
            icon: const Icon(Icons.dns, size: 14),
            label: const Text('Inyectar CoreDNS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () => _injectCoreDNS(allServices: true),
          ),
          const SizedBox(width: 4),

          // Save on Disk (Download YAML)
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
              foregroundColor: const Color(0xFF58A6FF),
            ),
            icon: const Icon(Icons.download, size: 14),
            label: const Text('Save on Disk', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: _saveOnDisk,
          ),
          const SizedBox(width: 4),

          // Save to Master Server
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
              foregroundColor: const Color(0xFF2EA043),
            ),
            icon: const Icon(Icons.dns_outlined, size: 14),
            label: const Text('Save Server', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: _saveToServer,
          ),
          const SizedBox(width: 4),

          // Toggle Block Gutter Markers Strip
          IconButton(
            tooltip: _showBlockGutter ? 'Hide Block Markers Strip' : 'Show Block Markers Strip',
            icon: Icon(
              Icons.view_sidebar_outlined,
              size: 16,
              color: _showBlockGutter ? theme.colorScheme.primary : (isDark ? Colors.white54 : Colors.black45),
            ),
            onPressed: () => _updateState(() => _showBlockGutter = !_showBlockGutter),
          ),
        ],
      ),
    );
  }
}

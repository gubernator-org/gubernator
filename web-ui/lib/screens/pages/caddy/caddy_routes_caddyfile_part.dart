part of '../caddy_page.dart';

extension _CaddyRoutesCaddyfileExt on _CaddyPageState {

  // ── Caddyfile Ingress Block Model & Parser ──────────────────────────────
  List<CaddyParsedBlock> _parseCaddyfile(String caddyfile) {
    final List<CaddyParsedBlock> blocks = [];
    final lines = caddyfile.split('\n');
    String? curHost;
    List<String> curUpstreams = [];
    String tls = 'Automated (ACME/Internal)';
    bool waf = false;
    String wafMode = 'enforce';
    String lbPolicy = '';
    String healthUri = '';
    List<String> rawLines = [];
    List<String> otherDirectives = [];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Site block header: e.g. "grafana.gbnt.local {" or ":80 {"
      if (!line.startsWith(' ') && !line.startsWith('\t') && trimmed.endsWith('{')) {
        final candidate = trimmed.substring(0, trimmed.length - 1).trim();
        if (candidate.isNotEmpty && !candidate.startsWith('#') && !candidate.startsWith('@')) {
          curHost = candidate;
          curUpstreams = [];
          tls = 'Automated (ACME)';
          waf = false;
          wafMode = 'enforce';
          lbPolicy = '';
          healthUri = '';
          rawLines = [line];
          otherDirectives = [];
        }
      } else if (curHost != null) {
        rawLines.add(line);
        if (trimmed == '}') {
          String scheme = 'https';
          String cleanHost = curHost;
          if (curHost.startsWith('http://')) {
            scheme = 'http';
            cleanHost = curHost.substring(7);
          } else if (curHost.startsWith('https://')) {
            scheme = 'https';
            cleanHost = curHost.substring(8);
          } else if (curHost.endsWith(':80')) {
            scheme = 'http';
          }
          final url = '$scheme://$cleanHost';

          blocks.add(CaddyParsedBlock(
            host: curHost,
            cleanHost: cleanHost,
            scheme: scheme,
            url: url,
            upstreams: List.from(curUpstreams),
            tls: tls,
            wafEnabled: waf,
            wafMode: wafMode,
            lbPolicy: lbPolicy,
            healthUri: healthUri,
            directives: List.from(otherDirectives),
            raw: rawLines.join('\n'),
          ));

          curHost = null;
        } else {
          if (trimmed.startsWith('reverse_proxy')) {
            final parts = trimmed.split(RegExp(r'\s+'));
            for (var p in parts) {
              if (p != 'reverse_proxy' && p != '{' && p != '}' && !p.startsWith('@')) {
                curUpstreams.add(p);
              }
            }
          } else if (trimmed.startsWith('tls')) {
            tls = trimmed;
          } else if (trimmed.contains('threat_shield') || trimmed.contains('waf')) {
            waf = true;
            if (trimmed.contains('detection')) wafMode = 'detection';
          } else if (trimmed.startsWith('lb_policy')) {
            lbPolicy = trimmed.replaceFirst('lb_policy', '').trim();
          } else if (trimmed.startsWith('health_uri')) {
            healthUri = trimmed.replaceFirst('health_uri', '').trim();
          } else if (!trimmed.startsWith('#')) {
            otherDirectives.add(trimmed);
          }
        }
      }
    }

    // Fallback: If Caddyfile had no parsed blocks but _routesList has items, populate from _routesList
    if (blocks.isEmpty && _routesList.isNotEmpty) {
      for (var r in _routesList) {
        final host = (r['host'] ?? '').toString();
        if (host.isEmpty) continue;
        final rawUrl = r['url']?.toString();
        final scheme = r['scheme']?.toString() ?? (host.startsWith('http://') ? 'http' : 'https');
        final cleanHost = r['clean_host']?.toString() ?? host.replaceAll('http://', '').replaceAll('https://', '');
        final url = rawUrl ?? '$scheme://$cleanHost';
        final upstreams = (r['upstreams'] as List?)?.map((e) => e.toString()).toList() ?? [];

        blocks.add(CaddyParsedBlock(
          host: host,
          cleanHost: cleanHost,
          scheme: scheme,
          url: url,
          upstreams: upstreams,
          tls: r['tls']?.toString() ?? 'Automated (ACME)',
          wafEnabled: r['waf_enabled'] == true,
          wafMode: r['waf_mode']?.toString() ?? 'enforce',
          lbPolicy: '',
          healthUri: '',
          directives: (r['directives'] as List?)?.map((e) => e.toString()).toList() ?? [],
          raw: '$host {\n  reverse_proxy ${upstreams.join(' ')}\n}',
        ));
      }
    }

    return blocks;
  }

  // --- TAB 2: Routes ---
  Widget _buildRoutesTab(ThemeData theme, bool isDark) {
    final filtered = _routesList.where((r) {
      if (_routeFilter.isEmpty) return true;
      final host = (r['host'] ?? '').toString().toLowerCase();
      final url = (r['url'] ?? '').toString().toLowerCase();
      final up = ((r['upstreams'] as List?)?.join(' ') ?? '').toLowerCase();
      final q = _routeFilter.toLowerCase();
      return host.contains(q) || url.contains(q) || up.contains(q);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 18),
                      hintText: 'Filtrar rutas por origen o destino...',
                      isDense: true,
                    ),
                    onChanged: (val) => _updateState(() => _routeFilter = val),
                  ),
                ),
                const SizedBox(width: 14),
                if (filtered.isNotEmpty) ...[
                  const Icon(Icons.touch_app, size: 16, color: Color(0xFFF97316)),
                  const SizedBox(width: 4),
                  const Text('Clic en cualquier host o destino para abrir en nueva pestaña', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
                const Spacer(),
                Text('${filtered.length} rutas activas', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.alt_route, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                          const SizedBox(height: 8),
                          const Text('No hay rutas Ingress activas coincidentes', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('INGRESS HOST / ORIGEN')),
                            DataColumn(label: Text('DESTINO (UPSTREAMS)')),
                            DataColumn(label: Text('THREAT SHIELD (WAF)')),
                            DataColumn(label: Text('HEALTH')),
                            DataColumn(label: Text('UPTIME %')),
                            DataColumn(label: Text('ACCIONES / ENLACE')),
                          ],
                          rows: filtered.map((r) {
                            final host = r['host'] ?? '';
                            final rawUrl = r['url']?.toString();
                            final String scheme;
                            final String cleanHost;
                            final String fullUrl;

                            if (rawUrl != null && rawUrl.isNotEmpty) {
                              fullUrl = rawUrl;
                              scheme = r['scheme']?.toString() ?? (rawUrl.startsWith('https://') ? 'https' : 'http');
                              cleanHost = r['clean_host']?.toString() ?? host.replaceAll('http://', '').replaceAll('https://', '');
                            } else {
                              if (host.startsWith('http://')) {
                                scheme = 'http';
                                cleanHost = host.substring(7);
                              } else if (host.startsWith('https://')) {
                                scheme = 'https';
                                cleanHost = host.substring(8);
                              } else if (host.endsWith(':80')) {
                                scheme = 'http';
                                cleanHost = host;
                              } else {
                                scheme = 'https';
                                cleanHost = host;
                              }
                              fullUrl = '$scheme://$cleanHost';
                            }

                            final upstreams = (r['upstreams'] as List?)?.map((e) => e.toString()).toList() ?? [];
                            final curlCmd = 'curl -H "Host: $cleanHost" http://localhost';
                            final wafEnabled = r['waf_enabled'] == true;
                            final wafMode = r['waf_mode'] ?? 'enforce';
                            final wafOrigin = r['waf_origin'] ?? 'global';

                            return DataRow(cells: [
                              // INGRESS HOST / ORIGEN (Clickable link with scheme badge and open icon)
                              DataCell(
                                InkWell(
                                  onTap: () => _openUrl(fullUrl),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: scheme == 'https'
                                                ? Colors.green.withValues(alpha: 0.15)
                                                : Colors.blue.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: scheme == 'https'
                                                  ? Colors.green.withValues(alpha: 0.4)
                                                  : Colors.blue.withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Text(
                                            scheme.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: scheme == 'https' ? Colors.green : Colors.blue,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          cleanHost,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Courier New',
                                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                            decoration: TextDecoration.underline,
                                            decorationStyle: TextDecorationStyle.dotted,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.open_in_new,
                                          size: 14,
                                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // DESTINO (UPSTREAMS) with clickable targets
                              DataCell(
                                upstreams.isEmpty
                                    ? const Text('—', style: TextStyle(color: Colors.grey))
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.arrow_forward, size: 14, color: Color(0xFFF97316)),
                                          const SizedBox(width: 6),
                                          ...upstreams.map((u) {
                                            final upUrl = u.startsWith('http://') || u.startsWith('https://')
                                                ? u
                                                : (u.contains(':443') ? 'https://$u' : 'http://$u');
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 6),
                                              child: InkWell(
                                                onTap: () => _openUrl(upUrl),
                                                borderRadius: BorderRadius.circular(4),
                                                child: Tooltip(
                                                  message: 'Abrir destino $upUrl en nueva pestaña',
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          u,
                                                          style: const TextStyle(fontFamily: 'Courier New', fontSize: 12),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        const Icon(Icons.open_in_new, size: 11, color: Colors.grey),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                              ),

                              // THREAT SHIELD (WAF)
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: wafEnabled
                                          ? (wafMode == 'detection' ? Colors.amber.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15))
                                          : Colors.grey.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: wafEnabled
                                            ? (wafMode == 'detection' ? Colors.amber : Colors.green)
                                            : Colors.grey.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          wafEnabled ? Icons.shield : Icons.shield_outlined,
                                          size: 14,
                                          color: wafEnabled
                                              ? (wafMode == 'detection' ? Colors.amber : Colors.green)
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          wafEnabled ? (wafMode == 'detection' ? 'DETECT' : 'ENFORCE') : 'OFF',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: wafEnabled
                                                ? (wafMode == 'detection' ? Colors.amber : Colors.green)
                                                : Colors.grey,
                                          ),
                                        ),
                                        if (wafOrigin == 'manual') ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF97316).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('a mano', style: TextStyle(fontSize: 9, color: Color(0xFFF97316), fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: Icon(
                                      wafEnabled ? Icons.power_settings_new : Icons.play_arrow,
                                      size: 16,
                                      color: wafEnabled ? Colors.redAccent : Colors.green,
                                    ),
                                    tooltip: wafEnabled ? 'Disable WAF for $host (a mano)' : 'Enable WAF for $host (a mano)',
                                    onPressed: () async {
                                      final res = await ApiService.toggleRouteWAF(host, !wafEnabled, wafMode);
                                      _showSnackBar(res['message'] ?? 'Route WAF toggled');
                                      await _loadCaddyData();
                                    },
                                  ),
                                ],
                              )),

                              // HEALTH
                              DataCell(StatusBadge(label: r['health'] ?? 'healthy')),

                              // UPTIME %
                              DataCell(Text('${r['uptime_percent'] ?? 99.98}%', style: const TextStyle(fontWeight: FontWeight.bold))),

                              // ACTIONS / ENLACE
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.open_in_new, size: 18, color: Color(0xFFF97316)),
                                    tooltip: 'Abrir $fullUrl en nueva pestaña',
                                    onPressed: () => _openUrl(fullUrl),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.link, size: 18),
                                    tooltip: 'Copiar URL ($fullUrl)',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: fullUrl));
                                      _showSnackBar('URL copiada: $fullUrl');
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.terminal, size: 18),
                                    tooltip: 'Copiar comando cURL de prueba',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: curlCmd));
                                      _showSnackBar('Copied test command: $curlCmd');
                                    },
                                  ),
                                ],
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 3: Caddyfile ---
  Widget _buildCaddyfileTab(String caddyfile, ThemeData theme, bool isDark) {
    final blocks = _parseCaddyfile(caddyfile);
    final filteredBlocks = blocks.where((b) {
      if (_caddyfileFilter.isEmpty) return true;
      final q = _caddyfileFilter.toLowerCase();
      return b.host.toLowerCase().contains(q) ||
          b.url.toLowerCase().contains(q) ||
          b.upstreams.any((u) => u.toLowerCase().contains(q));
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Control Bar
            Row(
              children: [
                const Icon(Icons.description, size: 22, color: Color(0xFFF97316)),
                const SizedBox(width: 8),
                Text('Caddyfile & Ingress Inspection', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 20),

                // View Mode Switcher
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _caddyfileViewButton('table', Icons.table_chart, 'Filas y Columnas', isDark),
                      _caddyfileViewButton('json', Icons.data_object, 'Formato JSON', isDark),
                      _caddyfileViewButton('raw', Icons.code, 'Caddyfile Raw', isDark),
                    ],
                  ),
                ),

                const Spacer(),

                if (_caddyfileViewMode == 'table') ...[
                  SizedBox(
                    width: 220,
                    height: 36,
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 16),
                        hintText: 'Filtrar reglas...',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: (val) => _updateState(() => _caddyfileFilter = val),
                    ),
                  ),
                ],

                if (_caddyfileViewMode == 'raw') ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.format_indent_increase, size: 16),
                    label: const Text('caddy fmt'),
                    onPressed: () async {
                      await ApiService.formatCaddyfile(caddyfile);
                      _showSnackBar('Formatted Caddyfile via caddy fmt!');
                      _loadCaddyData();
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: 'Copiar Caddyfile',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: caddyfile));
                      _showSnackBar('Copied Caddyfile!');
                    },
                  ),
                ],

                if (_caddyfileViewMode == 'json') ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copiar JSON'),
                    onPressed: () {
                      final jsonStr = const JsonEncoder.withIndent('  ').convert(blocks.map((b) => b.toJson()).toList());
                      Clipboard.setData(ClipboardData(text: jsonStr));
                      _showSnackBar('JSON de rutas copiado al portapapeles!');
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // Quick Ingress URLs bar (Click to open directly in a new tab!)
            if (blocks.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.open_in_new, size: 16, color: Color(0xFFF97316)),
                    const SizedBox(width: 8),
                    const Text('Ingress URLs detectadas:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: blocks.map((b) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                avatar: Icon(
                                  b.scheme == 'https' ? Icons.lock : Icons.lock_open,
                                  size: 13,
                                  color: b.scheme == 'https' ? Colors.green : Colors.blue,
                                ),
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      b.url,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_outward, size: 11, color: Color(0xFFF97316)),
                                  ],
                                ),
                                tooltip: 'Abrir ${b.url} en nueva pestaña del navegador',
                                onPressed: () => _openUrl(b.url),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Active View Mode Body
            Expanded(
              child: _caddyfileViewMode == 'table'
                  ? _buildCaddyfileTableView(filteredBlocks, theme, isDark)
                  : (_caddyfileViewMode == 'json'
                      ? _buildCaddyfileJsonView(blocks, theme, isDark)
                      : _buildCaddyfileRawView(caddyfile, theme, isDark)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _caddyfileViewButton(String mode, IconData icon, String label, bool isDark) {
    final isSelected = _caddyfileViewMode == mode;
    return InkWell(
      onTap: () => _updateState(() => _caddyfileViewMode = mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF97316) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700])),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaddyfileTableView(List<CaddyParsedBlock> blocks, ThemeData theme, bool isDark) {
    if (blocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            const Text('No se detectaron bloques de configuración Ingress en el Caddyfile', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('INGRESS HOST / ORIGEN')),
            DataColumn(label: Text('DESTINO (UPSTREAMS / PROXY)')),
            DataColumn(label: Text('TLS / CERTIFICADO')),
            DataColumn(label: Text('DIRECTIVAS / SEGURIDAD')),
            DataColumn(label: Text('ACCIONES')),
          ],
          rows: blocks.map((b) {
            return DataRow(cells: [
              // Ingress Host / Origin with link
              DataCell(
                InkWell(
                  onTap: () => _openUrl(b.url),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: b.scheme == 'https'
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: b.scheme == 'https'
                                  ? Colors.green.withValues(alpha: 0.4)
                                  : Colors.blue.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            b.scheme.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: b.scheme == 'https' ? Colors.green : Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          b.cleanHost,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Courier New',
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                            decoration: TextDecoration.underline,
                            decorationStyle: TextDecorationStyle.dotted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.open_in_new,
                          size: 14,
                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Destino (Upstreams / Proxy)
              DataCell(
                b.upstreams.isEmpty
                    ? const Text('—', style: TextStyle(color: Colors.grey))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_forward, size: 14, color: Color(0xFFF97316)),
                          const SizedBox(width: 6),
                          ...b.upstreams.map((u) {
                            final upUrl = u.startsWith('http://') || u.startsWith('https://')
                                ? u
                                : (u.contains(':443') ? 'https://$u' : 'http://$u');
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: () => _openUrl(upUrl),
                                borderRadius: BorderRadius.circular(4),
                                child: Tooltip(
                                  message: 'Abrir destino $upUrl en nueva pestaña',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          u,
                                          style: const TextStyle(fontFamily: 'Courier New', fontSize: 12),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.open_in_new, size: 11, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
              ),

              // TLS / Certificado
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      b.tls.contains('internal') ? Icons.shield : Icons.lock,
                      size: 14,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      b.tls,
                      style: const TextStyle(fontFamily: 'Courier New', fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Directivas / Seguridad
              DataCell(
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (b.wafEnabled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: b.wafMode == 'detection'
                              ? Colors.amber.withValues(alpha: 0.15)
                              : Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: b.wafMode == 'detection' ? Colors.amber : Colors.green,
                          ),
                        ),
                        child: Text(
                          'WAF: ${b.wafMode.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: b.wafMode == 'detection' ? Colors.amber : Colors.green,
                          ),
                        ),
                      ),
                    if (b.lbPolicy.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'LB: ${b.lbPolicy}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                    if (b.healthUri.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'Health: ${b.healthUri}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ),
                  ],
                ),
              ),

              // Acciones
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 18, color: Color(0xFFF97316)),
                      tooltip: 'Abrir ${b.url} en el navegador',
                      onPressed: () => _openUrl(b.url),
                    ),
                    IconButton(
                      icon: const Icon(Icons.link, size: 18),
                      tooltip: 'Copiar URL (${b.url})',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: b.url));
                        _showSnackBar('URL copiada: ${b.url}');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copiar bloque Caddyfile',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: b.raw));
                        _showSnackBar('Bloque Caddyfile copiado');
                      },
                    ),
                  ],
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCaddyfileJsonView(List<CaddyParsedBlock> blocks, ThemeData theme, bool isDark) {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(blocks.map((b) => b.toJson()).toList());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          jsonStr.isEmpty ? '[]' : jsonStr,
          style: const TextStyle(fontFamily: 'Courier New', fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildCaddyfileRawView(String caddyfile, ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          caddyfile.isEmpty ? '# No configuration loaded' : caddyfile,
          style: const TextStyle(fontFamily: 'Courier New', fontSize: 13),
        ),
      ),
    );
  }

}

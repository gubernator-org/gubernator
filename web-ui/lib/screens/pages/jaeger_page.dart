import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../../main.dart';

/// Jaeger Distributed Tracing page — embeds the Jaeger iframe with keep-alive,
/// reload controls, and external link matching Grafana/Network pages.
class JaegerPage extends StatefulWidget {
  const JaegerPage({super.key});

  @override
  State<JaegerPage> createState() => _JaegerPageState();
}

class _JaegerPageState extends State<JaegerPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        // Top Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
            ),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timeline, color: Color(0xFF06B6D4), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Jaeger Distributed Tracing',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'OTLP :4317 / :4318',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF06B6D4),
                      ),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => reloadIframe('jaeger-iframe'),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reload'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => html.window.open('/jaeger/', '_blank'),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open in New Tab'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Embedded Jaeger Iframe
        const Expanded(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Card(
              clipBehavior: Clip.none,
              child: RepaintBoundary(
                key: ValueKey('jaeger-iframe-repaint-boundary'),
                child: HtmlElementView(
                  key: ValueKey('jaeger-iframe-element-view'),
                  viewType: 'jaeger-iframe',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

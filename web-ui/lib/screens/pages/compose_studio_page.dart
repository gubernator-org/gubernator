import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:highlight/languages/yaml.dart';

import '../../models/models.dart' as models;
import '../../services/api_service.dart';
import '../../utils/clipboard_service.dart';
import '../../utils/compose_smart_merger.dart';
import '../../widgets/compose_autocomplete.dart';
import '../../widgets/server_stack_picker_dialog.dart';
import '../../widgets/poc_examples_dialog.dart';
import '../../widgets/port_conflict_dialog.dart';
import '../../widgets/save_server_stack_dialog.dart';
import '../../widgets/save_pc_stack_dialog.dart';

part 'compose_studio/compose_templates_part.dart';
part 'compose_studio/compose_copilot_part.dart';
part 'compose_studio/compose_blocks_navigator_part.dart';


class _ComposeBlockSegment {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final int startLine;
  final int endLine;
  final bool isPresent;
  final String summary;

  const _ComposeBlockSegment({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.startLine,
    required this.endLine,
    required this.isPresent,
    required this.summary,
  });
}

class ComposeStudioPage extends StatefulWidget {
  final models.DashboardState state;
  final VoidCallback onRefresh;

  const ComposeStudioPage({
    super.key,
    required this.state,
    required this.onRefresh,
  });

  @override
  State<ComposeStudioPage> createState() => _ComposeStudioPageState();
}

/// Enhanced CodeController that suppresses stale Flutter Web DOM/IME text update events
/// during programmatic fullText / smart merge updates, preventing upstream character truncation.
class GbntCodeController extends CodeController {
  GbntCodeController({
    super.text,
    super.language,
    super.namedSectionParser,
    super.readOnlySectionNames,
  });

  bool suppressStaleWebUpdates = false;

  @override
  String get text => fullText;

  @override
  set value(TextEditingValue newValue) {
    if (suppressStaleWebUpdates) {
      // Drop any stale IME / DOM textarea events emitted during programmatic updates
      return;
    }
    super.value = newValue;
  }
}

class _ComposeStudioPageState extends State<ComposeStudioPage> {
  late GbntCodeController _codeController;
  final TextEditingController _nameController = TextEditingController(text: 'my-app');
  String _selectedStackId = 'new'; // 'new' or stack ID
  String _selectedNode = 'auto';
  String _activeCopilotTab = 'caddy';
  bool _saving = false;
  bool _deploying = false;
  bool _loadingYaml = false;
  String _originalYaml = '';
  double _copilotWidth = 480.0;
  bool _isDraggingDivider = false;
  bool _showBlockGutter = true;
  bool _copilotExpanded = true;

  String _customLimitCpu = '1.0';
  String _customLimitRam = '512M';
  String _customReserveCpu = '0.25';
  String _customReserveRam = '128M';



  final FocusNode _editorFocusNode = FocusNode();
  String _lastSelectedText = '';
  TextSelection _lastSelection = const TextSelection.collapsed(offset: -1);
  String? _selectedTargetService;

  /// Returns the current active target service name (or the first service in the document).
  String get _effectiveTargetService {
    final services = ComposeSmartMerger.getServiceNames(_codeController.text);
    if (services.isEmpty) return '';
    if (_selectedTargetService != null && services.contains(_selectedTargetService)) {
      return _selectedTargetService!;
    }
    return services.first;
  }

  models.CoreDNSStatusInfo? _corednsInfo;

  void _loadCoreDNSInfo() async {
    try {
      final info = await ApiService.fetchCoreDNSStatusInfo();
      if (mounted) setState(() => _corednsInfo = info);
    } catch (_) {}
  }

  String get _clusterCoreDnsIp {
    if (_corednsInfo?.corednsIp != null && _corednsInfo!.corednsIp!.isNotEmpty) {
      return _corednsInfo!.corednsIp!;
    }
    for (final n in widget.state.nodes) {
      if (n.role.toLowerCase() == 'manager' && n.ip.isNotEmpty && n.ip != '127.0.0.1') {
        return n.ip;
      }
    }
    return '192.168.252.39';
  }

  String get _clusterDomain {
    return _corednsInfo?.clusterDomain.isNotEmpty == true
        ? _corednsInfo!.clusterDomain
        : 'gbnt.local';
  }

  void _injectCoreDNS({bool allServices = false}) {
    final dnsIp = _clusterCoreDnsIp;
    final domain = _clusterDomain;
    final res = ComposeSmartMerger.mergeDNS(
      _codeController.text,
      _codeController.selection.baseOffset,
      dnsServers: [dnsIp],
      searchDomains: [domain, 'gbnt'],
      allServices: allServices,
      targetServiceName: _effectiveTargetService,
    );
    _applySmartMerge(res);
  }

  // Native browser clipboard event handlers — most reliable approach for HTTP
  html.EventListener? _copyHandler;
  html.EventListener? _cutHandler;
  html.EventListener? _pasteHandler;
  html.EventListener? _keyDownHandler;
  StreamSubscription<html.Event>? _contextMenuSub;

  @override
  void initState() {
    super.initState();
    _loadCoreDNSInfo();
    _originalYaml = _defaultTemplate;
    _codeController = GbntCodeController(
      text: _defaultTemplate,
      language: yaml,
    );
    _codeController.addListener(_onCodeChanged);

    // Intercept native browser 'copy' event — fires when Cmd+C/Ctrl+C is pressed
    // clipboardData.setData() works on HTTP without any permissions
    _copyHandler = (html.Event e) {
      if (e.target is html.TextAreaElement || e.target is html.InputElement) return;
      if (!mounted || !_editorFocusNode.hasFocus) return;
      e.preventDefault();
      final text = _getTextToCopy(forceAll: false);
      if (text.isNotEmpty) {
        (e as html.ClipboardEvent).clipboardData?.setData('text/plain', text);
        _showCopySnackbar(text);
      }
    };
    html.document.addEventListener('copy', _copyHandler!, true);

    // Intercept native browser 'cut' event
    _cutHandler = (html.Event e) {
      if (e.target is html.TextAreaElement || e.target is html.InputElement) return;
      if (!mounted || !_editorFocusNode.hasFocus) return;
      e.preventDefault();
      _handleCut(fromEvent: e as html.ClipboardEvent);
    };
    html.document.addEventListener('cut', _cutHandler!, true);

    // Intercept native browser 'paste' event — fires when Cmd+V (Mac) or Ctrl+V (Windows/Linux) is pressed
    // clipboardData.getData('text/plain') works directly on plain HTTP without permissions
    _pasteHandler = (html.Event e) {
      if (e.target is html.TextAreaElement || e.target is html.InputElement) return;
      if (!mounted || !_editorFocusNode.hasFocus) return;
      final clipboardEvent = e as html.ClipboardEvent;
      final text = clipboardEvent.clipboardData?.getData('text/plain');
      if (text != null && text.isNotEmpty) {
        e.preventDefault();
        e.stopImmediatePropagation();
        _insertPastedText(text);
      }
    };
    html.document.addEventListener('paste', _pasteHandler!, true);

    // Keep keydown for Ctrl+A / Cmd+A (copy/cut/paste are handled by native clipboard events)
    _keyDownHandler = (html.Event e) => _onBrowserKeyDown(e as html.KeyboardEvent);
    html.document.addEventListener('keydown', _keyDownHandler!, true);

    // Intercept right-click context menu
    _contextMenuSub = html.document.onContextMenu.listen(_onBrowserContextMenu);
  }

  /// Captures selection changes and active service context.
  void _onCodeChanged() {
    final sel = _codeController.selection;
    if (sel.isValid && !sel.isCollapsed && sel.start >= 0 && sel.end <= _codeController.text.length && sel.start < sel.end) {
      _lastSelection = sel;
      _lastSelectedText = _codeController.text.substring(sel.start, sel.end);
    }
    final offset = sel.baseOffset;
    if (offset >= 0) {
      final detected = ComposeSmartMerger.detectServiceAtOffset(_codeController.text, offset);
      if (detected != null && detected != _selectedTargetService) {
        setState(() {
          _selectedTargetService = detected;
        });
      }
    }
  }

  /// Returns the text to copy — current selection or last remembered selection.
  String _getTextToCopy({bool forceAll = false}) {
    if (forceAll) return _codeController.text;
    final sel = _codeController.selection;
    if (sel.isValid && !sel.isCollapsed && sel.start >= 0 && sel.end <= _codeController.text.length && sel.start < sel.end) {
      return _codeController.text.substring(sel.start, sel.end);
    }
    if (_lastSelectedText.isNotEmpty) return _lastSelectedText;
    return _codeController.text;
  }

  void _showCopySnackbar(String text) {
    if (!mounted) return;
    final preview = text.length > 25 ? '${text.substring(0, 25)}...' : text;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(
            text == _codeController.text
                ? '✓ Copied entire YAML (${text.length} chars)'
                : '✓ Copied (${text.length} chars): "$preview"',
            overflow: TextOverflow.ellipsis,
          )),
        ]),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
        width: 440,
      ),
    );
  }

  /// Keydown handler — only handles Ctrl+A / Cmd+A (copy/cut/paste are handled by native clipboard events).
  void _onBrowserKeyDown(html.KeyboardEvent event) {
    if (!mounted || !_editorFocusNode.hasFocus) return;
    final isCtrlOrMeta = event.ctrlKey || event.metaKey;
    if (!isCtrlOrMeta) return;
    final key = event.key?.toLowerCase() ?? '';
    switch (key) {
      case 'a':
        event.preventDefault();
        event.stopImmediatePropagation();
        _handleSelectAll();
        break;
    }
  }

  /// Browser right-click: prevent native context menu and show custom Flutter popup.
  void _onBrowserContextMenu(html.Event event) {
    if (!mounted || !_editorFocusNode.hasFocus) return;
    event.preventDefault();
    final mouseEvent = event as html.MouseEvent;
    _showEditorContextMenu(Offset(
      mouseEvent.client.x.toDouble(),
      mouseEvent.client.y.toDouble(),
    ));
  }

  void _showEditorContextMenu(Offset position) {
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final hasSelection = _lastSelectedText.isNotEmpty ||
        (_codeController.selection.isValid && !_codeController.selection.isCollapsed);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          enabled: hasSelection,
          child: const Row(children: [
            Icon(Icons.content_copy, size: 16),
            SizedBox(width: 8),
            Text('Copy Selection'),
            Spacer(),
            Text('Ctrl+C', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'copy_all',
          child: const Row(children: [
            Icon(Icons.copy_all, size: 16),
            SizedBox(width: 8),
            Text('Copy All YAML'),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'paste',
          child: const Row(children: [
            Icon(Icons.paste, size: 16),
            SizedBox(width: 8),
            Text('Paste'),
            Spacer(),
            Text('Ctrl+V', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'select_all',
          child: const Row(children: [
            Icon(Icons.select_all, size: 16),
            SizedBox(width: 8),
            Text('Select All'),
            Spacer(),
            Text('Ctrl+A', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'copy':
          _handleCopy(forceAll: false);
          break;
        case 'copy_all':
          _handleCopy(forceAll: true);
          break;
        case 'paste':
          _handlePaste();
          break;
        case 'select_all':
          _handleSelectAll();
          break;
      }
    });
  }

  void _handleCopy({bool forceAll = false}) {
    final textToCopy = _getTextToCopy(forceAll: forceAll);
    if (textToCopy.isEmpty) return;
    // Toolbar button copy — use DOM execCommand fallback since no clipboard event available
    ClipboardService.copySync(textToCopy);
    ClipboardService.copy(textToCopy);
    _showCopySnackbar(textToCopy);
  }

  void _handleCut({html.ClipboardEvent? fromEvent}) {
    final sel = _codeController.selection;
    TextSelection? targetSel;
    if (sel.isValid && !sel.isCollapsed && sel.start >= 0 && sel.end <= _codeController.text.length && sel.start < sel.end) {
      targetSel = sel;
    } else if (_lastSelection.isValid && !_lastSelection.isCollapsed && _lastSelection.start >= 0 && _lastSelection.end <= _codeController.text.length) {
      targetSel = _lastSelection;
    }

    if (targetSel != null) {
      final selected = _codeController.text.substring(targetSel.start, targetSel.end);
      // If triggered from native cut event, inject into event's clipboardData (works on HTTP)
      if (fromEvent != null) {
        fromEvent.clipboardData?.setData('text/plain', selected);
      } else {
        ClipboardService.copySync(selected);
        ClipboardService.copy(selected);
      }
      final text = _codeController.text;
      final start = targetSel.start <= targetSel.end ? targetSel.start : targetSel.end;
      final end = targetSel.start <= targetSel.end ? targetSel.end : targetSel.start;
      final newText = text.substring(0, start) + text.substring(end);
      _codeController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
      );
      _lastSelectedText = '';
      _lastSelection = const TextSelection.collapsed(offset: -1);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Cut selection to clipboard'),
            duration: Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
            width: 280,
          ),
        );
      }
    }
  }

  void _insertPastedText(String pasted) {
    if (pasted.isEmpty) return;
    final sel = _codeController.selection;
    final text = _codeController.text;
    final rawStart = (sel.isValid && sel.start >= 0) ? sel.start : ((_lastSelection.isValid && _lastSelection.start >= 0) ? _lastSelection.start : text.length);
    final rawEnd = (sel.isValid && sel.end >= 0) ? sel.end : ((_lastSelection.isValid && _lastSelection.end >= 0) ? _lastSelection.end : text.length);
    final start = rawStart <= rawEnd ? rawStart : rawEnd;
    final end = rawStart <= rawEnd ? rawEnd : rawStart;
    final newText = text.substring(0, start) + pasted + text.substring(end);
    _codeController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + pasted.length),
    );
    _lastSelectedText = '';
    _lastSelection = const TextSelection.collapsed(offset: -1);
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '✓ Pasted ${pasted.length} characters into editor',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          width: 320,
        ),
      );
    }
  }

  Future<void> _handlePaste() async {
    final pasted = await ClipboardService.paste();
    if (pasted != null && pasted.isNotEmpty) {
      _insertPastedText(pasted);
      return;
    }

    // Fallback when browser blocks silent reading on plain HTTP
    if (mounted) {
      _showPasteModal();
    }
  }

  void _showPasteModal() {
    final pasteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2228),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.paste, color: Colors.cyanAccent, size: 20),
            SizedBox(width: 8),
            Text('Paste Content', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Direct clipboard reading via button is restricted on HTTP by browser security.\nPress Cmd+V (Mac) / Ctrl+V (Windows) in the box below:',
                style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pasteController,
                autofocus: true,
                maxLines: 8,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Press Cmd+V or Ctrl+V here...',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0D1117),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF30363D)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.cyanAccent),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.cyan),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Insert into Editor'),
            onPressed: () {
              final text = pasteController.text;
              Navigator.of(ctx).pop();
              if (text.isNotEmpty) {
                _insertPastedText(text);
              }
            },
          ),
        ],
      ),
    );
  }

  void _handleSelectAll() {
    _codeController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _codeController.text.length,
    );
    _lastSelection = _codeController.selection;
    _lastSelectedText = _codeController.text;
    _editorFocusNode.requestFocus();
  }

  @override
  void dispose() {
    if (_copyHandler != null) {
      html.document.removeEventListener('copy', _copyHandler!, true);
      _copyHandler = null;
    }
    if (_cutHandler != null) {
      html.document.removeEventListener('cut', _cutHandler!, true);
      _cutHandler = null;
    }
    if (_pasteHandler != null) {
      html.document.removeEventListener('paste', _pasteHandler!, true);
      _pasteHandler = null;
    }
    if (_keyDownHandler != null) {
      html.document.removeEventListener('keydown', _keyDownHandler!, true);
      _keyDownHandler = null;
    }
    _contextMenuSub?.cancel();
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    _nameController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadStackYaml(String stackId) async {
    if (stackId == 'new') {
      setState(() {
        _selectedStackId = 'new';
        _nameController.text = 'my-app';
        _codeController.fullText = _defaultTemplate;
        _originalYaml = _defaultTemplate;
      });
      return;
    }

    final stack = widget.state.stacks.firstWhere((s) => s.id == stackId, orElse: () => widget.state.stacks.first);
    setState(() {
      _selectedStackId = stackId;
      _nameController.text = stack.name;
      _loadingYaml = true;
    });

    try {
      final yamlContent = await ApiService.getStackCompose(stack.id);
      if (mounted) {
        setState(() {
          _codeController.fullText = yamlContent;
          _originalYaml = yamlContent;
          _loadingYaml = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingYaml = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load stack compose: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _applyTemplate(String templateKey) {
    final snippet = _starterTemplates[templateKey];
    if (snippet != null) {
      setState(() {
        _codeController.fullText = snippet;
        _originalYaml = snippet;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Applied template: $templateKey')),
      );
    }
  }

  void _saveOnDisk() {
    showSavePcStackDialog(
      context: context,
      initialName: _nameController.text,
      yamlContent: _codeController.text,
    );
  }

  Future<void> _saveToServer() async {
    final rawName = _nameController.text.trim();
    final savedPath = await showSaveServerStackDialog(
      context: context,
      initialName: rawName,
      yamlContent: _codeController.text,
    );
    if (savedPath != null && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Saved to Master server: $savedPath')),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _importFile() {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = '.yml,.yaml';
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();

        final filename = file.name;
        final dotIdx = filename.indexOf('.');
        final name = dotIdx != -1 ? filename.substring(0, dotIdx) : filename;
        final sanitizedName = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\-]'), '-');

        reader.onLoadEnd.listen((e) {
          final text = reader.result as String;
          setState(() {
            _codeController.fullText = text;
            if (_selectedStackId == 'new') {
              _nameController.text = sanitizedName;
            }
          });
        });

        reader.readAsText(file);
      }
    });
  }

  void _showServerStackPicker() {
    showDialog(
      context: context,
      builder: (ctx) => ServerStackPickerDialog(
        onSelect: (name, yaml) {
          setState(() {
            _codeController.fullText = yaml;
            if (_selectedStackId == 'new') {
              _nameController.text = name;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loaded "$name" from Master server')),
          );
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
          setState(() {
            _codeController.fullText = yaml;
            if (_selectedStackId == 'new') {
              _nameController.text = name;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loaded POC Blueprint "$name" into Studio')),
          );
        },
        onStackDeployed: widget.onRefresh,
      ),
    );
  }

  Future<void> _saveCompose() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Stack Name'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await ApiService.saveStack(
        name: name,
        compose: _codeController.text,
        stackId: _selectedStackId == 'new' ? null : _selectedStackId,
        targetNode: _selectedNode,
      );

      if (res['error'] != null) {
        throw Exception(res['error']);
      }

      final savedId = res['stack_id'] as String?;
      if (savedId != null && savedId.isNotEmpty) {
        setState(() {
          _selectedStackId = savedId;
        });
      }
      _originalYaml = _codeController.text;

      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Stack "$name" saved successfully (Draft mode: containers not deployed).',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAndDeploy() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Stack Name'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _deploying = true);
    try {
      if (_selectedStackId == 'new') {
        final result = await ApiService.deployStackDetailed(name, _codeController.text, targetNode: _selectedNode);
        if (!result.success) {
          if (result.isConflict && result.conflicts.isNotEmpty && mounted) {
            setState(() => _deploying = false);
            final action = await showDialog<PortConflictAction>(
              context: context,
              builder: (ctx) => PortConflictDialog(
                stackName: name,
                conflicts: result.conflicts,
              ),
            );
            if (action == PortConflictAction.autoRemap) {
              setState(() => _deploying = true);
              final remapRes = await ApiService.deployStackDetailed(
                name,
                _codeController.text,
                targetNode: _selectedNode,
                autoRemapPorts: true,
              );
              if (!remapRes.success) throw Exception(remapRes.error);
              if (remapRes.remappedCompose != null && remapRes.remappedCompose!.isNotEmpty) {
                _codeController.fullText = remapRes.remappedCompose!;
              }
            } else if (action == PortConflictAction.force) {
              setState(() => _deploying = true);
              final forceRes = await ApiService.deployStackDetailed(
                name,
                _codeController.text,
                targetNode: _selectedNode,
                force: true,
              );
              if (!forceRes.success) throw Exception(forceRes.error);
            } else {
              return;
            }
          } else {
            throw Exception(result.error);
          }
        }
      } else {
        await ApiService.updateStackCompose(_selectedStackId, _codeController.text);
        final ok = await ApiService.redeployStack(_selectedStackId);
        if (!ok) throw Exception('Failed to redeploy stack');
      }
      _originalYaml = _codeController.text;
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.rocket_launch, color: Colors.greenAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Stack "$name" deployed & containers started!'),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deployment error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _deploying = false);
    }
  }

  void _applySmartMerge(MergeResult result) {
    // 1. Temporarily suppress stale DOM/IME updates from Web platform
    _codeController.suppressStaleWebUpdates = true;
    _editorFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _codeController.fullText = result.newYaml;
      _codeController.selection = const TextSelection.collapsed(offset: -1);
    });

    // 2. Re-enable user input events once the browser event loop has processed the click
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _codeController.suppressStaleWebUpdates = false;
      }
    });

    IconData icon;
    Color color;
    switch (result.action) {
      case MergeActionType.updated:
        icon = Icons.sync;
        color = Colors.cyanAccent;
        break;
      case MergeActionType.added:
        icon = Icons.add_circle;
        color = Colors.greenAccent;
        break;
      case MergeActionType.alreadyExists:
        icon = Icons.info_outline;
        color = Colors.amberAccent;
        break;
      case MergeActionType.inserted:
        icon = Icons.add_task;
        color = Colors.blueAccent;
        break;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(result.message, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _updateState(VoidCallback fn) {
    if (mounted) setState(fn);
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header & Toolbar ──────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.code, color: theme.colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Compose Studio',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF58A6FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'IDE & COPILOT',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF58A6FF)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Author, edit, validate, and deploy Docker Compose stacks with smart suggestions.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Stack Selector Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStackId,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      items: [
                        const DropdownMenuItem(
                          value: 'new',
                          child: Row(
                            children: [
                              Icon(Icons.add_box, size: 16, color: Colors.blueAccent),
                              SizedBox(width: 8),
                              Text('✨ Create New Stack'),
                            ],
                          ),
                        ),
                        ...widget.state.stacks.map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Row(
                            children: [
                              const Icon(Icons.layers, size: 16, color: Colors.orangeAccent),
                              const SizedBox(width: 8),
                              Text('Stack: ${s.name}'),
                            ],
                          ),
                        )),
                      ],
                      onChanged: (val) {
                        if (val != null) _loadStackYaml(val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Reset YAML Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset'),
                  onPressed: () {
                    setState(() {
                      _codeController.fullText = _originalYaml;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('YAML reset to original'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
                const SizedBox(width: 10),

                // Save Stack Button (Draft mode: does not deploy)
                Tooltip(
                  message: 'Save stack definition (Draft mode: does NOT start containers)',
                  child: OutlinedButton.icon(
                    icon: _saving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save, size: 16),
                    label: const Text('Save Stack'),
                    onPressed: _saving ? null : _saveCompose,
                  ),
                ),
                const SizedBox(width: 10),

                // Save & Deploy Button
                Tooltip(
                  message: _selectedStackId == 'new'
                      ? 'Deploy stack and start all containers on cluster nodes'
                      : 'Save compose changes and redeploy containers',
                  child: FilledButton.icon(
                    icon: _deploying
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.rocket_launch, size: 16),
                    label: Text(_selectedStackId == 'new' ? 'Deploy Stack' : 'Save & Redeploy'),
                    onPressed: _deploying ? null : _saveAndDeploy,
                  ),
                ),
              ],
            ),
          ),

          // Secondary Bar: Stack Controls, Files & Templates
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                    width: 220,
                    height: 38,
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Stack Name',
                        prefixIcon: Icon(Icons.label_outline, size: 16),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 280,
                    height: 38,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedNode,
                      decoration: const InputDecoration(
                        labelText: 'Target Placement Node',
                        prefixIcon: Icon(Icons.memory, size: 16),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      ),
                      style: const TextStyle(fontSize: 13),
                      items: [
                        const DropdownMenuItem(value: 'auto', child: Text('Automatic Scheduler (Spread)')),
                        ...widget.state.nodes.where((n) => n.status == 'active').map((n) => DropdownMenuItem(
                          value: n.id,
                          child: Text('${n.id} (${n.ip} - ${n.role.toUpperCase()})'),
                        )),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedNode = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(height: 24, width: 1, color: theme.dividerColor),
                  const SizedBox(width: 14),

                  // Open / Import from Local PC
                  Tooltip(
                    message: 'Upload / Open Compose YAML from your local workstation',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.file_open_outlined, size: 16),
                      label: const Text('Open PC'),
                      onPressed: _importFile,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Inyectar CoreDNS
                  Tooltip(
                    message: 'Inyectar el resolver CoreDNS de Gubernator ($_clusterCoreDnsIp) y dominios de búsqueda en este Compose',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.dns, size: 16, color: Color(0xFF10B981)),
                      label: const Text('Inyectar CoreDNS', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                      onPressed: () => _injectCoreDNS(allServices: true),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Save on Disk (Local Computer)
                  Tooltip(
                    message: 'Save / Download Compose YAML directly to your local computer disk',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.download, size: 16, color: Color(0xFF388BFD)),
                      label: const Text('Save on Disk', style: TextStyle(color: Color(0xFF388BFD), fontWeight: FontWeight.bold)),
                      onPressed: _saveOnDisk,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Load from Master Server Filesystem
                  Tooltip(
                    message: 'Load Compose YAML from Master server filesystem (~/.gbnt/stacks/)',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.dns, size: 16, color: Color(0xFF58A6FF)),
                      label: const Text('Master Server', style: TextStyle(color: Color(0xFF58A6FF))),
                      onPressed: _showServerStackPicker,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Save to Master Server Filesystem
                  Tooltip(
                    message: 'Save Compose YAML directly to Master server filesystem (~/.gbnt/stacks/)',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.save_as_outlined, size: 16, color: Color(0xFF2EA043)),
                      label: const Text('Save Server', style: TextStyle(color: Color(0xFF2EA043), fontWeight: FontWeight.bold)),
                      onPressed: _saveToServer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(height: 24, width: 1, color: theme.dividerColor),
                  const SizedBox(width: 14),

                  // Starters Templates Menu
                  PopupMenuButton<String>(
                    tooltip: 'Load Blueprint Template',
                    onSelected: _applyTemplate,
                    itemBuilder: (context) => _starterTemplates.keys.map((title) => PopupMenuItem(
                      value: title,
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 16, color: Colors.cyanAccent),
                          const SizedBox(width: 8),
                          Text(title),
                        ],
                      ),
                    )).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 16, color: Colors.cyanAccent),
                          SizedBox(width: 6),
                          Text('Templates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Icon(Icons.arrow_drop_down, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Full POC Blueprints Catalog
                  Tooltip(
                    message: 'Browse and deploy built-in POC example blueprints',
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.rocket_launch, size: 16, color: Color(0xFFE3B341)),
                      label: const Text('POC Blueprints', style: TextStyle(color: Color(0xFFE3B341), fontWeight: FontWeight.bold)),
                      onPressed: _showPOCExamples,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Main Editor & Copilot Split ───────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: Editor with Action Bar, Blocks Navigator & Suggestion Bar
                Expanded(
                  child: Column(
                    children: [
                      // Editor Action Bar
                      _buildEditorActionBar(theme, isDark),

                      // Architecture Blocks Navigator Bar (Marks and identifies blocks in YAML)
                      _buildBlocksNavigatorBar(theme, isDark),

                      // Suggestion Bar
                      ComposeSuggestionBar(
                        controller: _codeController,
                        onSnippetInserted: (label) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Inserted $label snippet'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),

                      // CodeField Area with optional Block Markers Gutter Strip
                      Expanded(
                        child: _loadingYaml
                            ? const Center(child: CircularProgressIndicator())
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_showBlockGutter)
                                    _buildBlockGutterStrip(theme, isDark),
                                  Expanded(
                                    child: CodeTheme(
                                      data: CodeThemeData(styles: isDark ? monokaiSublimeTheme : githubTheme),
                                      child: Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        color: isDark ? const Color(0xFF1A1F29) : const Color(0xFFFDFDFE),
                                        child: CodeField(
                                          controller: _codeController,
                                          focusNode: _editorFocusNode,
                                          gutterStyle: GutterStyle(
                                            width: 54.0,
                                            margin: 10.0,
                                            textAlign: TextAlign.right,
                                            background: isDark ? const Color(0xFF13171F) : const Color(0xFFF1F5F9),
                                            textStyle: TextStyle(
                                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                              fontFamily: 'JetBrains Mono',
                                              fontSize: 12,
                                            ),
                                            showLineNumbers: true,
                                            showErrors: true,
                                            showFoldingHandles: true,
                                          ),
                                          textStyle: TextStyle(
                                            fontFamily: 'JetBrains Mono',
                                            fontSize: 13.5,
                                            height: 1.55,
                                            letterSpacing: 0.3,
                                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                                          ),
                                          expands: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),

                // Resizable Vertical Split Divider with Interactive Drag Handle
                _buildResizableDivider(theme, isDark),

                // Right: Copilot Panel (Smart Wizard with Adaptive Options)
                _buildCopilotPanel(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

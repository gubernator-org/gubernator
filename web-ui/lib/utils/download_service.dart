import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Utility service to download files to the user's local workstation/computer from the browser.
class DownloadService {
  /// Checks whether the browser supports the File System Access API (window.showSaveFilePicker).
  static bool get isFileSystemAccessSupported {
    try {
      return globalContext.has('showSaveFilePicker') &&
          globalContext.getProperty('showSaveFilePicker'.toJS) != null;
    } catch (_) {
      return false;
    }
  }

  /// Saves a Compose YAML file using the File System Access API if supported,
  /// opening the native OS File Save picker so the user can browse folders and edit the name.
  /// If not supported or if the picker fails, falls back to standard direct download.
  static Future<bool> saveYamlFile({
    required String content,
    required String filename,
  }) async {
    var fn = filename.trim();
    if (fn.isEmpty) fn = 'docker-compose.yml';
    fn = fn.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '-');
    if (!fn.endsWith('.yml') && !fn.endsWith('.yaml')) {
      fn = '$fn.yml';
    }

    if (isFileSystemAccessSupported) {
      try {
        final options = {
          'suggestedName': fn,
          'types': [
            {
              'description': 'Docker Compose YAML (*.yml, *.yaml)',
              'accept': {
                'application/x-yaml': ['.yml', '.yaml'],
                'text/yaml': ['.yml', '.yaml'],
                'text/plain': ['.txt', '.yml', '.yaml'],
              }
            }
          ]
        }.jsify();

        final fileHandlePromise = globalContext.callMethod<JSPromise<JSObject>>(
          'showSaveFilePicker'.toJS,
          options,
        );
        final fileHandle = await fileHandlePromise.toDart;

        final createWritablePromise = fileHandle.callMethod<JSPromise<JSObject>>(
          'createWritable'.toJS,
        );
        final writable = await createWritablePromise.toDart;

        final writePromise = writable.callMethod<JSPromise<JSAny?>>(
          'write'.toJS,
          content.toJS,
        );
        await writePromise.toDart;

        final closePromise = writable.callMethod<JSPromise<JSAny?>>(
          'close'.toJS,
        );
        await closePromise.toDart;

        return true;
      } catch (e) {
        final err = e.toString().toLowerCase();
        if (err.contains('aborterror') || err.contains('aborted') || err.contains('user aborted')) {
          // User deliberately cancelled the file picker dialog
          return false;
        }
      }
    }

    // Direct browser anchor download
    downloadYaml(content, filename: fn);
    return true;
  }

  /// Triggers a direct browser download of a Compose YAML file.
  static void downloadYaml(String content, {String? filename}) {
    var fn = (filename ?? 'docker-compose.yml').trim();
    if (fn.isEmpty) fn = 'docker-compose.yml';
    fn = fn.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '-');
    if (!fn.endsWith('.yml') && !fn.endsWith('.yaml')) {
      fn = '$fn.yml';
    }

    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], 'application/x-yaml');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fn)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

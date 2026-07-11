import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Download file for web platform
/// Returns null since web downloads go to browser's download folder
Future<String?> downloadFile(String content, String fileName) async {
  final bytes = utf8.encode(content);
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();

  web.URL.revokeObjectURL(url);

  return null; // Web downloads don't have a file path
}

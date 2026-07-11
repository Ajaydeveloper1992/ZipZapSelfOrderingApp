import 'download_helper_mobile.dart'
    if (dart.library.html) 'download_helper_web.dart' as platform;

/// Cross-platform file download
/// For web: triggers browser download
/// For mobile/desktop: saves to downloads directory
Future<String?> downloadFile(String content, String fileName) async {
  final result = await platform.downloadFile(content, fileName);
  return result as String?;
}


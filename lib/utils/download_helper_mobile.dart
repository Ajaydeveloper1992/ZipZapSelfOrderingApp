import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Download file for mobile/desktop platforms
Future<String> downloadFile(String content, String fileName) async {
  Directory? directory;

  if (Platform.isAndroid) {
    directory = Directory('/storage/emulated/0/Download');
    if (!await directory.exists()) {
      directory = await getExternalStorageDirectory();
    }
  } else if (Platform.isIOS) {
    directory = await getApplicationDocumentsDirectory();
  } else {
    directory = await getDownloadsDirectory();
  }

  if (directory == null) {
    throw Exception('Could not access downloads directory');
  }

  final filePath = '${directory.path}/$fileName';
  final file = File(filePath);
  await file.writeAsString(content);

  return directory.path;
}


import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// Returns a safe single-segment filename for use inside the app's download
/// directory. WebView-provided names must never be allowed to influence the
/// directory portion of a local path.
String sanitizeDownloadFileName(String value, {String fallback = 'download'}) {
  final fileName = value
      .trim()
      .split(RegExp(r'[\\/]+'))
      .last
      .replaceAll(RegExp(r'[\x00-\x1F<>:"|?*]'), '_')
      .trim();

  if (fileName.isEmpty || fileName == '.' || fileName == '..') {
    return fallback;
  }

  return fileName;
}

/// Pure service for handling file downloads
/// Contains only business logic, no UI dependencies
class DownloadService {
  Future<String?> downloadFile({
    required String url,
    required String name,
    String? base64Str,
    required Function(String progress) onProgress,
    required StreamController<String> streamController,
  }) async {
    try {
      Dio dio = Dio();
      final urlFileName = Uri.tryParse(url)?.pathSegments.lastOrNull ?? '';
      final fileName = sanitizeDownloadFileName(
        name,
        fallback: sanitizeDownloadFileName(urlFileName),
      );
      String savePath = await _getFilePath(fileName);

      // Handle base64 or URL download
      if (base64Str != null) {
        try {
          final base64Data = base64Str.split(',').last;
          final bytes = base64Decode(base64Data);

          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          streamController.add('100%');
          onProgress('100%');
          print('✅ File saved to ${file.path}');
          savePath = file.path;
          return savePath;
        } catch (e) {
          print('❌ Failed to save file: $e');
          streamController.add('0%');
          return null;
        }
      } else {
        try {
          await dio.download(
            url.toString(),
            savePath,
            onReceiveProgress: (received, total) {
              if (total <= 0) return;
              String pc = (received / total * 100).toStringAsFixed(0);
              if (int.parse(pc) <= 100) {
                final progressStr = '$pc%';
                streamController.add(progressStr);
                onProgress(progressStr);
              }
            },
          );
          return savePath;
        } catch (error) {
          print('❌ Download error: $error');
          streamController.add('0%');
          return null;
        }
      }
    } on Exception catch (e) {
      print('❌ Download exception: $e');
      return null;
    }
  }

  /// Get file path for saving downloaded files
  Future<String> _getFilePath(String uniqueFileName) async {
    String path = '';
    String externalStorageDirPath = '';

    if (Platform.isAndroid) {
      try {
        // For Android 10+, use app-specific directory which doesn't require permissions
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          // Create Downloads folder in app-specific storage
          final downloadDir = Directory('${directory.path}/Download');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
          externalStorageDirPath = downloadDir.path;
        } else {
          // Fallback to internal storage
          final internalDir = await getApplicationDocumentsDirectory();
          externalStorageDirPath = internalDir.path;
        }
      } catch (e) {
        print('Error getting storage directory: $e');
        final directory = await getApplicationDocumentsDirectory();
        externalStorageDirPath = directory.path;
      }
    } else if (Platform.isIOS) {
      externalStorageDirPath =
          (await getApplicationDocumentsDirectory()).absolute.path;
    }

    path = '$externalStorageDirPath/$uniqueFileName';
    return path;
  }

  /// Open downloaded file
  Future<void> openFile(String filePath) async {
    await OpenFile.open(filePath);
  }
}

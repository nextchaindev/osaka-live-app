import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'
    as image_compress;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:light_compressor_v2/light_compressor_v2.dart';
import 'package:path_provider/path_provider.dart';

class NativeChatMediaService {
  NativeChatMediaService._();

  static final NativeChatMediaService instance = NativeChatMediaService._();

  static const int _maxFiles = 5;
  static const int _maxFileBytes = 25 * 1024 * 1024;
  static const int _targetVideoSizeMb = 22;
  static const String _resultEvent = 'osaka-live-chat-media-picker-result';

  final ImagePicker _picker = ImagePicker();
  final LightCompressor _videoCompressor = LightCompressor();
  final Dio _uploadClient = Dio();
  bool _isPicking = false;

  Future<void> pickCompressAndUpload({
    required InAppWebViewController controller,
    required String requestId,
    required String sessionId,
    required int maxFiles,
  }) async {
    if (_isPicking) {
      await _dispatchResult(
        controller,
        requestId: requestId,
        status: 'error',
        errorCode: 'picker_busy',
      );
      return;
    }

    _isPicking = true;
    final uploadedKeys = <String>[];
    final temporaryPaths = <String>[];
    try {
      final files = await _picker.pickMultipleMedia(
        limit: maxFiles.clamp(1, _maxFiles),
        requestFullMetadata: false,
      );
      if (files.isEmpty) {
        await _dispatchResult(
          controller,
          requestId: requestId,
          status: 'cancelled',
        );
        return;
      }

      final uploadedMedia = <Map<String, dynamic>>[];
      for (final source in files.take(maxFiles.clamp(1, _maxFiles))) {
        final prepared = await _prepareMedia(source, temporaryPaths);
        if (prepared.size <= 0 || prepared.size > _maxFileBytes) {
          throw const _NativeChatMediaException('file_too_large');
        }

        final presigned = await _postJsonInPage(
          controller,
          endpoint: '/api/live-sessions/$sessionId/messages/media/presigned',
          payload: {
            'fileName': prepared.fileName,
            'fileSize': prepared.size,
            'mimeType': prepared.mimeType,
            'mediaType': prepared.mediaType,
          },
        );
        final presignedUrl = presigned['presignedUrl']?.toString() ?? '';
        final key = presigned['key']?.toString() ?? '';
        final uploadUri = Uri.tryParse(presignedUrl);
        if (uploadUri == null || uploadUri.scheme != 'https' || key.isEmpty) {
          throw const _NativeChatMediaException('invalid_upload_url');
        }

        final response = await _uploadClient.putUri<void>(
          uploadUri,
          data: prepared.file.openRead(),
          options: Options(
            contentType: prepared.mimeType,
            headers: {Headers.contentLengthHeader: prepared.size},
            validateStatus: (status) => status != null && status < 400,
          ),
        );
        if (response.statusCode == null || response.statusCode! >= 400) {
          throw const _NativeChatMediaException('upload_failed');
        }
        uploadedKeys.add(key);

        final confirmed = await _postJsonInPage(
          controller,
          endpoint: '/api/live-sessions/$sessionId/messages/media/upload',
          payload: {'key': key, 'mediaType': prepared.mediaType},
        );
        final media = confirmed['media'];
        if (media is! Map) {
          throw const _NativeChatMediaException('invalid_upload_response');
        }
        uploadedMedia.add({
          ...Map<String, dynamic>.from(media),
          'fileName': prepared.fileName,
        });
      }

      await _dispatchResult(
        controller,
        requestId: requestId,
        status: 'success',
        media: uploadedMedia,
      );
    } catch (error, stackTrace) {
      debugPrint('[Chat media] native picker/upload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      for (final key in uploadedKeys) {
        try {
          await _deleteUploadedMedia(controller, sessionId, key);
        } catch (_) {}
      }
      await _dispatchResult(
        controller,
        requestId: requestId,
        status: 'error',
        errorCode: error is _NativeChatMediaException
            ? error.code
            : 'native_media_failed',
      );
    } finally {
      for (final path in temporaryPaths) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      _isPicking = false;
    }
  }

  Future<_PreparedChatMedia> _prepareMedia(
    XFile source,
    List<String> temporaryPaths,
  ) async {
    final sourceFile = File(source.path);
    if (!await sourceFile.exists()) {
      throw const _NativeChatMediaException('file_not_found');
    }

    final mimeType = _resolveMimeType(source);
    if (mimeType.startsWith('image/')) {
      final tempDirectory = await getTemporaryDirectory();
      final targetPath =
          '${tempDirectory.path}/chat_image_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final compressed =
          await image_compress.FlutterImageCompress.compressAndGetFile(
        source.path,
        targetPath,
        minWidth: 1920,
        minHeight: 1920,
        quality: 82,
        format: image_compress.CompressFormat.jpeg,
      );
      if (compressed == null) {
        throw const _NativeChatMediaException('image_compression_failed');
      }
      temporaryPaths.add(compressed.path);

      final compressedFile = File(compressed.path);
      final compressedSize = await compressedFile.length();
      final originalSize = await sourceFile.length();
      final canUseOriginal = _isAllowedImageMimeType(mimeType) &&
          originalSize <= _maxFileBytes &&
          originalSize <= compressedSize;
      return _PreparedChatMedia(
        file: canUseOriginal ? sourceFile : compressedFile,
        fileName: canUseOriginal
            ? _safeFileName(source.name, 'image')
            : 'chat-image-${DateTime.now().millisecondsSinceEpoch}.jpg',
        mediaType: 'image',
        mimeType: canUseOriginal ? mimeType : 'image/jpeg',
        size: canUseOriginal ? originalSize : compressedSize,
      );
    }

    if (!mimeType.startsWith('video/')) {
      throw const _NativeChatMediaException('unsupported_media_type');
    }

    final result = await _videoCompressor.compressVideo(
      path: source.path,
      videoQuality: VideoQuality.medium,
      video: Video(
        videoName: 'chat-video-${DateTime.now().millisecondsSinceEpoch}.mp4',
        targetSizeMb: _targetVideoSizeMb,
        videoFps: 30,
      ),
      audio: const AudioConfig(bitrate: 128000),
      android: AndroidConfig(isSharedStorage: false),
      ios: IOSConfig(saveInGallery: false),
      isMinBitrateCheckEnabled: false,
    );
    if (result is! OnSuccess) {
      throw const _NativeChatMediaException('video_compression_failed');
    }
    temporaryPaths.add(result.destinationPath);

    final compressedFile = File(result.destinationPath);
    final compressedSize = await compressedFile.length();
    final originalSize = await sourceFile.length();
    final canUseOriginal = _isAllowedVideoMimeType(mimeType) &&
        originalSize <= _maxFileBytes &&
        originalSize <= compressedSize;
    return _PreparedChatMedia(
      file: canUseOriginal ? sourceFile : compressedFile,
      fileName: canUseOriginal
          ? _safeFileName(source.name, 'video')
          : 'chat-video-${DateTime.now().millisecondsSinceEpoch}.mp4',
      mediaType: 'video',
      mimeType: canUseOriginal ? mimeType : 'video/mp4',
      size: canUseOriginal ? originalSize : compressedSize,
    );
  }

  Future<Map<String, dynamic>> _postJsonInPage(
    InAppWebViewController controller, {
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    final result = await controller.callAsyncJavaScript(
      functionBody: '''
        const response = await fetch(endpoint, {
          method: 'POST',
          credentials: 'include',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify(payload),
        });
        const body = await response.text();
        return JSON.stringify({status: response.status, body});
      ''',
      arguments: {'endpoint': endpoint, 'payload': payload},
    );
    if (result == null || result.error != null || result.value is! String) {
      throw const _NativeChatMediaException('web_request_failed');
    }

    final response = jsonDecode(result.value as String);
    if (response is! Map) {
      throw const _NativeChatMediaException('invalid_web_response');
    }
    final status = (response['status'] as num?)?.toInt() ?? 0;
    if (status < 200 || status >= 300) {
      throw _NativeChatMediaException('http_$status');
    }
    final body = jsonDecode(response['body']?.toString() ?? '');
    if (body is! Map) {
      throw const _NativeChatMediaException('invalid_web_response');
    }
    return Map<String, dynamic>.from(body);
  }

  Future<void> _deleteUploadedMedia(
    InAppWebViewController controller,
    String sessionId,
    String key,
  ) async {
    await controller.callAsyncJavaScript(
      functionBody: '''
        await fetch(endpoint, {
          method: 'DELETE',
          credentials: 'include',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({key}),
        });
      ''',
      arguments: {
        'endpoint': '/api/live-sessions/$sessionId/messages/media',
        'key': key,
      },
    );
  }

  Future<void> _dispatchResult(
    InAppWebViewController controller, {
    required String requestId,
    required String status,
    List<Map<String, dynamic>> media = const [],
    String? errorCode,
  }) async {
    final payload = {
      'requestId': requestId,
      'status': status,
      'media': media,
      if (errorCode != null) 'errorCode': errorCode,
    };
    await controller.evaluateJavascript(
      source: '''
        window.dispatchEvent(new CustomEvent(
          '$_resultEvent',
          {detail: ${jsonEncode(payload)}}
        ));
      ''',
    );
  }

  String _resolveMimeType(XFile file) {
    final explicit = file.mimeType?.toLowerCase();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final nameParts = file.name.toLowerCase().split('.');
    final pathParts = file.path.toLowerCase().split('/').last.split('.');
    final extension = nameParts.length > 1
        ? nameParts.last
        : pathParts.length > 1
            ? pathParts.last
            : '';
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'webm' => 'video/webm',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      _ => 'application/octet-stream',
    };
  }

  bool _isAllowedImageMimeType(String value) =>
      value == 'image/jpeg' || value == 'image/png' || value == 'image/webp';

  bool _isAllowedVideoMimeType(String value) =>
      value == 'video/mp4' ||
      value == 'video/webm' ||
      value == 'video/quicktime' ||
      value == 'video/x-m4v';

  String _safeFileName(String value, String fallback) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final fileName = sanitized.isEmpty
        ? '$fallback-${DateTime.now().millisecondsSinceEpoch}'
        : sanitized;
    return fileName.length <= 100 ? fileName : fileName.substring(0, 100);
  }
}

class _PreparedChatMedia {
  const _PreparedChatMedia({
    required this.file,
    required this.fileName,
    required this.mediaType,
    required this.mimeType,
    required this.size,
  });

  final File file;
  final String fileName;
  final String mediaType;
  final String mimeType;
  final int size;
}

class _NativeChatMediaException implements Exception {
  const _NativeChatMediaException(this.code);

  final String code;

  @override
  String toString() => code;
}

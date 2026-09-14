import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'
    as image_compress;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:light_compressor_v2/light_compressor_v2.dart';
import 'package:path_provider/path_provider.dart';
import 'package:osaka_app/screens/camera/custom_camera_screen.dart';

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
    required BuildContext context,
    required String requestId,
    required String sessionId,
    required int maxFiles,
  }) async {
    if (!context.mounted) {
      await _dispatchResult(
        controller,
        requestId: requestId,
        status: 'error',
        errorCode: 'view_unavailable',
      );
      return;
    }

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
      final files = await _pickMedia(
        context,
        maxFiles.clamp(1, _maxFiles),
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
        final uploadHeaders = _parseUploadHeaders(
          presigned['uploadHeaders'],
          fallbackContentType: prepared.mimeType,
        );
        final uploadUri = Uri.tryParse(presignedUrl);
        if (uploadUri == null || uploadUri.scheme != 'https' || key.isEmpty) {
          throw const _NativeChatMediaException('invalid_upload_url');
        }

        final response = await _uploadClient.putUri<void>(
          uploadUri,
          data: prepared.file.openRead(),
          options: Options(
            headers: {
              ...uploadHeaders,
              Headers.contentLengthHeader: prepared.size,
            },
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

  Future<List<XFile>> _pickMedia(BuildContext context, int maxFiles) async {
    final source = await showModalBottomSheet<_ChatMediaSource>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(
        alpha: Platform.isAndroid ? 0.28 : 0.18,
      ),
      builder: (_) => const _ChatMediaPickerSheet(),
    );
    if (!context.mounted) {
      return [];
    }

    switch (source) {
      case _ChatMediaSource.library:
        return _picker.pickMultipleMedia(
          limit: maxFiles,
          requestFullMetadata: false,
        );
      case _ChatMediaSource.cameraImage:
        return _captureWithCustomCamera(
          context,
          CustomCameraMode.photo,
        );
      case _ChatMediaSource.cameraVideo:
        return _captureWithCustomCamera(
          context,
          CustomCameraMode.video,
        );
      case null:
        return [];
    }
  }

  Future<List<XFile>> _captureWithCustomCamera(
    BuildContext context,
    CustomCameraMode mode,
  ) async {
    final result = await Navigator.of(context, rootNavigator: true)
        .push<CustomCameraCaptureResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CustomCameraScreen(
          mode: mode,
          returnCaptureResult: true,
        ),
      ),
    );
    return result == null ? [] : [result.file];
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
        keepOriginalResolution: true,
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

  Map<String, dynamic> _parseUploadHeaders(
    dynamic value, {
    required String fallbackContentType,
  }) {
    final headers = <String, dynamic>{};
    if (value != null) {
      if (value is! Map) {
        throw const _NativeChatMediaException('invalid_upload_headers');
      }

      for (final entry in value.entries) {
        if (entry.key is! String || entry.value is! String) {
          throw const _NativeChatMediaException('invalid_upload_headers');
        }
        headers[entry.key as String] = entry.value as String;
      }
    }

    final hasContentType = headers.keys.any(
      (header) => header.toLowerCase() == Headers.contentTypeHeader,
    );
    if (!hasContentType) {
      headers[Headers.contentTypeHeader] = fallbackContentType;
    }
    return headers;
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

enum _ChatMediaSource { library, cameraImage, cameraVideo }

class _ChatMediaPickerSheet extends StatelessWidget {
  const _ChatMediaPickerSheet();

  static const _brandColor = Color(0xFFFF4038);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAndroid = Platform.isAndroid;
    final surfaceColor = isAndroid
        ? isDark
            ? const Color(0xE61D1D20)
            : const Color(0xE6FFFFFF)
        : isDark
            ? const Color(0xA61D1D20)
            : const Color(0xB8FFFFFF);
    final cardColor = isAndroid
        ? isDark
            ? const Color(0xE629292D)
            : const Color(0xD9F7F7F9)
        : isDark
            ? const Color(0x8F29292D)
            : const Color(0x99F7F7F9);
    final borderColor =
        isDark ? const Color(0x8AFFFFFF) : const Color(0x70FFFFFF);
    final primaryText = isDark ? Colors.white : const Color(0xFF18181B);
    final secondaryText =
        isDark ? const Color(0xFFA7A7AF) : const Color(0xFF777781);

    const sheetRadius = BorderRadius.vertical(top: Radius.circular(30));

    return Container(
      decoration: BoxDecoration(
        borderRadius: sheetRadius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x29000000),
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: sheetRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: isAndroid ? 20 : 32,
            sigmaY: isAndroid ? 20 : 32,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: sheetRadius,
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.7),
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF505057)
                            : const Color(0xFFD8D8DE),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    '미디어 첨부',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 21,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '사진 또는 동영상을 선택해 주세요',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.15,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _ChatMediaSourceButton(
                          icon: Icons.photo_library_rounded,
                          label: '앨범',
                          iconColor: const Color(0xFF7657E8),
                          iconBackground: const Color(0xFFEDE8FF),
                          cardColor: cardColor,
                          borderColor: borderColor,
                          textColor: primaryText,
                          onTap: () => Navigator.pop(
                            context,
                            _ChatMediaSource.library,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ChatMediaSourceButton(
                          icon: Icons.photo_camera_rounded,
                          label: '사진',
                          iconColor: _brandColor,
                          iconBackground: const Color(0xFFFFE9E7),
                          cardColor: cardColor,
                          borderColor: borderColor,
                          textColor: primaryText,
                          onTap: () => Navigator.pop(
                            context,
                            _ChatMediaSource.cameraImage,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ChatMediaSourceButton(
                          icon: Icons.videocam_rounded,
                          label: '동영상',
                          iconColor: const Color(0xFF2F80ED),
                          iconBackground: const Color(0xFFE5F0FF),
                          cardColor: cardColor,
                          borderColor: borderColor,
                          textColor: primaryText,
                          onTap: () => Navigator.pop(
                            context,
                            _ChatMediaSource.cameraVideo,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: primaryText,
                        backgroundColor: cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMediaSourceButton extends StatelessWidget {
  const _ChatMediaSourceButton({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBackground,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBackground;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 116,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, size: 26, color: iconColor),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NativeChatMediaException implements Exception {
  const _NativeChatMediaException(this.code);

  final String code;

  @override
  String toString() => code;
}

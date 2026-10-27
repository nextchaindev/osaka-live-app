import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:osaka_app/constants/javascript.dart';
import 'package:osaka_app/helpers/webview_helper.dart';
import 'package:osaka_app/models/web_post_message.dart';
import 'package:osaka_app/provider/webview_provider.dart';
import 'package:osaka_app/provider/locale_provider.dart';
import 'package:osaka_app/l10n/generated/app_localizations.dart';
import 'package:osaka_app/repositories/auth_repository.dart';
import 'package:osaka_app/screens/camera/custom_camera_screen.dart';
import 'package:osaka_app/screens/vjw/vjw_prepare_screen.dart';
import 'package:osaka_app/services/analytics/analytics_service.dart';
import 'package:osaka_app/services/auth/social_login_service.dart';
import 'package:osaka_app/services/chat/native_chat_media_service.dart';
import 'package:osaka_app/services/location/location_sync_service.dart';
import 'package:osaka_app/services/permission/permission_service.dart';
import 'package:osaka_app/widgets/common/dialog.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for handling JavaScript communication with WebView
/// Manages route changes, post messages, and contacts access
class JsCommunicationService {
  /// Define JavaScript handler for SPA route changes
  static void defineRouteChangeFunction({
    required InAppWebViewController controller,
    required BuildContext context,
    required AuthRepository authRepository,
    required CookieManager cookieManager,
    required String webViewUrl,
  }) async {
    controller.addJavaScriptHandler(
      handlerName: "onRouteChanged",
      callback: (args) {
        String currentUrl = args[0];
        print("SPA navigated to: $currentUrl");

        authRepository.checkUserLoginStatus(
          cookieManager: cookieManager,
          url: webViewUrl,
          name: "osaka_access",
        );

        context.read<WebViewProvider>().setCurrentUrl(currentUrl);
      },
    );
  }

  /// Handle JavaScript postMessage events from WebView
  static Future<void> handlePostMessage({
    required InAppWebViewController controller,
    required String webViewUrl,
    required Future<void> Function(bool enabled)
        onLiveSessionVideoAutoPlayChanged,
    required Function({
      required String name,
      required String url,
      String? base64Str,
    }) onDownload,
    required BuildContext context,
  }) async {
    print("Setting up WebMessage listener");

    final fToast = FToast();
    fToast.init(context);
    final permissionService = PermissionService();
    final appDialog = AppDialog();
    final locationSyncService = LocationSyncService();
    final analyticsService = AnalyticsService();
    final trustedOrigin = Uri.parse(webViewUrl).origin;

    Future<void> sendLocationPermissionPayload(
      Map<String, dynamic> payload,
    ) async {
      if (!context.mounted) {
        return;
      }

      await context.read<WebViewProvider>().sendLocationPermissionStatus(
            status: payload['status'] as String,
            serviceEnabled: payload['serviceEnabled'] as bool,
            updatedAt: (payload['updatedAt'] as num?)?.toInt(),
          );
    }

    Future<void> startLocationSyncIfAllowed(
      Map<String, dynamic> permissionPayload,
    ) async {
      if (!context.mounted ||
          permissionPayload['status'] != 'granted' ||
          permissionPayload['serviceEnabled'] != true) {
        return;
      }

      final webViewProvider = context.read<WebViewProvider>();
      await locationSyncService.start(
        onPosition: (position) {
          webViewProvider.handleLivePositionChanged(
            lat: position.latitude,
            lng: position.longitude,
            accuracy: position.accuracy,
            updatedAt: position.timestamp.millisecondsSinceEpoch,
          );
        },
      );
    }

    Future<void> openCustomCamera() async {
      if (!context.mounted) {
        return;
      }

      final hasPermission =
          await permissionService.requestCameraAndMicrophonePermission();

      if (!hasPermission) {
        if (!context.mounted) {
          return;
        }

        final strings = AppLocalizations.of(context)!;
        final openSettings = await appDialog.showPermissionDialog(
          context,
          title: strings.cameraPermissionTitle,
          message: strings.cameraPermissionMessage,
          icon: Icons.videocam_outlined,
        );
        if (openSettings) {
          await permissionService.openAppSettings();
        }
        return;
      }

      if (!context.mounted) {
        return;
      }

      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const CustomCameraScreen(),
        ),
      );
    }

    Future<void> acknowledgeVjwHelperOpened() async {
      try {
        await controller.evaluateJavascript(
          source: pushVjwHelperResult('vjw_helper_opened'),
        );
      } on Exception catch (error) {
        debugPrint('Failed to acknowledge VJW helper request: $error');
      }
    }

    Future<void> handleVjwHelper(Map<String, dynamic> message) async {
      final data = message['messageData'];
      final payload = data is Map<String, dynamic>
          ? <String, dynamic>{
              if (data['stayName'] is String) 'stayName': data['stayName'],
              if (data['stayAddress'] is String)
                'stayAddress': data['stayAddress'],
              if (data['stayPhone'] is String) 'stayPhone': data['stayPhone'],
            }
          : null;
      if (!context.mounted) return;
      final pushFuture = Navigator.of(context, rootNavigator: true).push(
        VjwPrepareScreen.route(prefill: payload),
      );
      // Let the first route frames render before starting native WebView and
      // analytics work. Both calls can perform platform work synchronously
      // before their first await.
      unawaited(Future<void>.delayed(const Duration(milliseconds: 180), () {
        unawaited(analyticsService.logEvent(name: 'vjw_helper_open'));
        unawaited(acknowledgeVjwHelperOpened());
      }));
      await pushFuture;
    }

    Future<void> openOfficialVjwExternally(Map<String, dynamic> message) async {
      final url = message['url']?.toString();
      final uri = Uri.tryParse(url ?? '');
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'www.vjw.digital.go.jp') {
        debugPrint('Ignored invalid external VJW URL request');
        return;
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) {
        try {
          await controller.evaluateJavascript(
            source: pushVjwHelperResult('vjw_external_opened'),
          );
        } on Exception catch (error) {
          debugPrint('Failed to acknowledge external VJW launch: $error');
        }
      }
    }

    Future<void> handleSocialLogin(Map<String, dynamic> message) async {
      final provider = message['provider']?.toString() ?? '';
      final requestId = message['requestId']?.toString() ?? '';
      if (provider.isEmpty || requestId.isEmpty) {
        debugPrint(
          '[SNS][Flutter bridge] rejected invalid request '
          'provider=$provider requestId=$requestId',
        );
        return;
      }

      debugPrint(
        '[SNS][Flutter bridge] request received '
        'provider=$provider requestId=$requestId',
      );
      final result = await SocialLoginService.instance.signIn(provider);
      debugPrint(
        '[SNS][Flutter bridge] dispatching result '
        'provider=$provider requestId=$requestId status=${result.status} '
        'errorCode=${result.errorCode ?? '-'} '
        'hasIdToken=${result.idToken?.isNotEmpty == true}',
      );
      try {
        await controller.evaluateJavascript(
          source: pushSocialLoginResult(
            status: result.status,
            provider: result.provider,
            requestId: requestId,
            idToken: result.idToken,
            errorCode: result.errorCode,
          ),
        );
        debugPrint(
          '[SNS][Flutter bridge] result dispatched requestId=$requestId',
        );
      } catch (error, stackTrace) {
        debugPrint(
          '[SNS][Flutter bridge] result dispatch failed '
          'requestId=$requestId error=$error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    if (defaultTargetPlatform != TargetPlatform.android ||
        await WebViewFeature.isFeatureSupported(
            WebViewFeature.WEB_MESSAGE_LISTENER)) {
      await controller.addWebMessageListener(WebMessageListener(
        jsObjectName: "webviewListener",
        onPostMessage: (message, sourceOrigin, isMainFrame, replyProxy) async {
          final sourceUri = Uri.tryParse(sourceOrigin?.toString() ?? '');
          if (isMainFrame != true || sourceUri?.origin != trustedOrigin) {
            debugPrint(
              'Ignored WebView message from untrusted origin: $sourceOrigin',
            );
            return;
          }

          print("message: $message");
          if (message != null && message.data != null) {
            final rawMessage = message.data.toString();
            if (rawMessage == 'record_camera') {
              await openCustomCamera();
              return;
            }

            try {
              final decoded = jsonDecode(rawMessage);
              if (decoded is Map<String, dynamic> &&
                  decoded['type'] == 'set_locale') {
                final locale = decoded['locale'];
                final source = decoded['source'];
                if (locale is String && source == 'user' && context.mounted) {
                  await context.read<LocaleProvider>().setUserLocale(locale);
                } else {
                  debugPrint('Ignored invalid locale update');
                }
                return;
              }

              if (decoded is Map<String, dynamic> &&
                  decoded['type'] == 'record_camera') {
                await openCustomCamera();
                return;
              }

              if (decoded is Map<String, dynamic> &&
                  decoded['type'] == 'social_login') {
                await handleSocialLogin(decoded);
                return;
              }

              if (decoded is Map<String, dynamic> &&
                  decoded['type'] == 'open_vjw_helper') {
                await handleVjwHelper(decoded);
                return;
              }

              if (decoded is Map<String, dynamic> &&
                  decoded['type'] == 'open_external_url') {
                await openOfficialVjwExternally(decoded);
                return;
              }

              if (decoded is Map<String, dynamic> &&
                  decoded['type'] == 'live_session_video_auto_play') {
                final enabled = decoded['enabled'];
                if (enabled is bool) {
                  await onLiveSessionVideoAutoPlayChanged(enabled);
                } else {
                  debugPrint(
                    'Ignored invalid live session video autoplay setting',
                  );
                }
                return;
              }

              if (decoded is Map<String, dynamic> &&
                  decoded['type'] == 'webview_scroll_lock') {
                final locked = decoded['locked'];
                if (locked is bool && context.mounted) {
                  await context
                      .read<WebViewProvider>()
                      .setWebViewScrollLocked(locked);
                } else {
                  debugPrint('Ignored invalid WebView scroll lock request');
                }
                return;
              }

              if (decoded is Map<String, dynamic> &&
                  decoded['type'] == 'pick_chat_media') {
                final requestId = decoded['requestId']?.toString() ?? '';
                final sessionId = decoded['sessionId']?.toString() ?? '';
                final maxFiles = (decoded['maxFiles'] as num?)?.toInt() ?? 1;
                if (requestId.isEmpty || sessionId.isEmpty) {
                  debugPrint('Ignored invalid native chat media request');
                  return;
                }
                await NativeChatMediaService.instance.pickCompressAndUpload(
                  controller: controller,
                  context: context,
                  requestId: requestId,
                  sessionId: sessionId,
                  maxFiles: maxFiles,
                );
                return;
              }

              if (decoded is Map<String, dynamic> &&
                  (decoded['type'] == 'pick_image' ||
                      decoded['type'] == 'pick_avatar')) {
                final requestId = decoded['requestId']?.toString() ?? '';
                if (requestId.isEmpty) {
                  debugPrint('Ignored invalid native image request');
                  return;
                }
                final purpose = decoded['type'] == 'pick_avatar' ||
                        decoded['purpose'] == 'avatar'
                    ? NativeImagePurpose.avatar
                    : decoded['purpose'] == 'venue_thumbnail'
                        ? NativeImagePurpose.venueThumbnail
                        : null;
                if (purpose == null) {
                  debugPrint(
                      'Ignored native image request with invalid purpose');
                  return;
                }
                await NativeChatMediaService.instance.pickImageAndDispatch(
                  controller: controller,
                  context: context,
                  requestId: requestId,
                  purpose: purpose,
                );
                return;
              }

              final postedMessage = WebPostMessage.fromJson(
                decoded as Map<String, dynamic>,
              );
              print('message type: ${postedMessage.type}');

              if (postedMessage.type == 'share') {
                final params = ShareParams(
                  title: postedMessage.messageData?.title ?? '',
                  uri: Uri.parse(postedMessage.messageData?.url ?? ''),
                );
                SharePlus.instance.share(
                  params,
                );
              } else if (postedMessage.type == 'request_location_permission') {
                final permissionPayload =
                    await permissionService.requestLocationPermission();
                await sendLocationPermissionPayload(permissionPayload);
                await startLocationSyncIfAllowed(permissionPayload);
                if (context.mounted &&
                    (permissionPayload['status'] != 'granted' ||
                        permissionPayload['serviceEnabled'] != true)) {
                  final strings = AppLocalizations.of(context)!;
                  final openSettings = await appDialog.showPermissionDialog(
                    context,
                    title: strings.locationPermissionTitle,
                    message: strings.locationPermissionMessage,
                    icon: Icons.location_on_outlined,
                  );
                  if (openSettings) {
                    await permissionService.openAppSettings();
                  }
                }
              } else if (postedMessage.type == 'copy-fcm-token') {
                await WebViewHelper().handleCopyFCMToken(fToast);
              } else if (postedMessage.type == 'download_file') {
                onDownload(
                    name: postedMessage.messageData?.title ?? '',
                    url: postedMessage.messageData?.url ?? '');
              }
            } catch (e) {
              print('Unsupported webview message: $rawMessage');
            }
          }
        },
      ));
      controller.loadUrl(urlRequest: URLRequest(url: WebUri(webViewUrl)));
    }
  }
}

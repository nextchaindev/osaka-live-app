import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:osaka_app/config/env_config.dart';
import 'package:osaka_app/constants/javascript.dart';
import 'package:osaka_app/helpers/webview_helper.dart';
import 'package:osaka_app/provider/navigation_bar_provider.dart';
import 'package:osaka_app/provider/webview_provider.dart';
import 'package:osaka_app/repositories/auth_repository.dart';
import 'package:osaka_app/services/cookies/cookies_services.dart';
import 'package:osaka_app/services/js/js_communication_service.dart';
import 'package:osaka_app/provider/download_provider.dart';
import 'package:osaka_app/services/permission/permission_service.dart';
import 'package:osaka_app/widgets/webview/webview_window.dart';

/// Mixin for WebView lifecycle event handlers
/// Contains business logic for WebView events: onWebViewCreated, onLoadStart, onLoadStop, etc.
///
/// This separates lifecycle handling from UI code
mixin WebViewLifecycleMixin<T extends StatefulWidget> on State<T> {
  final String _webViewUrl = EnvConfig.instance.webviewUrl;

  // ==================== State Variables ====================
  int _previousScrollY = 0;

  // ==================== Controller Setup ====================

  /// Set WebView controller in provider
  void setController({required InAppWebViewController controller}) {
    Provider.of<WebViewProvider>(context, listen: false)
        .setController(controller);
  }

  // ==================== Utility Functions ====================

  /// Validate URL and return whether it's valid
  bool validateUrl(String url) {
    return Uri.tryParse(url)?.isAbsolute ?? false;
  }

  // ==================== Scroll Handling ====================

  /// Handle WebView scroll events
  void onScrollChanged({required int y}) {
    try {
      int currentScrollY = y;

      if (currentScrollY > _previousScrollY) {
        if (!context
            .read<NavigationBarProvider>()
            .animationController
            .isAnimating) {
          context.read<NavigationBarProvider>().animationController.forward();
        }
      } else {
        if (!context
            .read<NavigationBarProvider>()
            .animationController
            .isAnimating) {
          context.read<NavigationBarProvider>().animationController.reverse();
        }
      }
      _previousScrollY = currentScrollY;
    } catch (e) {
      print(e);
    }
  }

  // ==================== WebView Created ====================

  /// Handle WebView creation - setup all listeners and configurations
  Future<void> onWebViewCreated({
    required InAppWebViewController controller,
    required Function(
            {required String name, required String url, String? base64Str})
        onDownload,
    required Function(InAppWebViewController) onControllerInitialized,
    required CookieManager cookieManager,
    required AuthRepository authRepository,
  }) async {
    onControllerInitialized(controller);
    setController(controller: controller);

    await restoreCookies(_webViewUrl, cookieManager);

    JsCommunicationService.defineRouteChangeFunction(
      controller: controller,
      // ignore: use_build_context_synchronously
      context: context,
      authRepository: authRepository,
      cookieManager: cookieManager,
      webViewUrl: _webViewUrl,
    );

    await markAccessByWebview(
      webViewUrl: _webViewUrl,
      cookieManager: cookieManager,
      safeAreaTop:
          // ignore: use_build_context_synchronously
          Provider.of<WebViewProvider>(context, listen: false).safeAreaTop,
      safeAreaBottom:
          // ignore: use_build_context_synchronously
          Provider.of<WebViewProvider>(context, listen: false).safeAreaBottom,
    );

    await JsCommunicationService.handlePostMessage(
      controller: controller,
      webViewUrl: _webViewUrl,
      onDownload: onDownload,
      // ignore: use_build_context_synchronously
      context: context,
    );

    // Load pending deep link after all initialization is complete
    // ignore: use_build_context_synchronously
    final provider = Provider.of<WebViewProvider>(context, listen: false);
    if (provider.pendingDeepLink != null) {
      controller.loadUrl(
          urlRequest: URLRequest(url: WebUri.uri(provider.pendingDeepLink!)));
      provider.clearPendingDeepLink();
    }
  }

  // ==================== Load Start ====================

  /// Handle WebView load start
  void onLoadStart({
    required InAppWebViewController controller,
    required WebUri? url,
    required VoidCallback onUpdate,
    bool isOpenDialog = false,
    BuildContext? dialogContext,
  }) {
    print('----------GET URL: $url');

    // Reset loading state if needed
    final loadingProvider =
        Provider.of<WebViewProvider>(context, listen: false);
    loadingProvider.setWebViewReady(false);
    if (loadingProvider.progress < 1.0) {
      loadingProvider.resetLoading();
    }

    onUpdate();

    context.read<WebViewProvider>().setCurrentUrl(url.toString());

    // Close dialog if open
    if (isOpenDialog == true && dialogContext != null) {
      Navigator.of(dialogContext).pop();
    }
  }

  // ==================== Load Stop ====================

  /// Handle WebView load stop
  Future<void> onLoadStop({
    required InAppWebViewController controller,
    required WebUri? url,
    required InAppWebViewController? webViewController,
    required VoidCallback onUpdate,
    required PullToRefreshController? pullToRefreshController,
  }) async {
    final loadingProvider = context.read<WebViewProvider>();

    // await _authRepository.checkUserLoginStatus(
    //   cookieManager: _cookieManager,
    //   url: _webViewUrl,
    //   name: "USER_INFOR",
    // );

    await controller.evaluateJavascript(source: listenRouterChange);
    if (url?.uriValue.path.startsWith('/sessions/') ?? false) {
      await controller.evaluateJavascript(source: unmuteAutoplayVideos);
    }

    print("stop successful");
    loadingProvider.setWebViewReady(true);
    final locationPermissionPayload =
        await PermissionService().getLocationPermissionPayload();
    await loadingProvider.sendLocationPermissionStatus(
      status: locationPermissionPayload['status'] as String,
      serviceEnabled: locationPermissionPayload['serviceEnabled'] as bool,
      updatedAt: (locationPermissionPayload['updatedAt'] as num?)?.toInt(),
    );
    onUpdate();

    pullToRefreshController?.endRefreshing();
  }

  // ==================== Navigation Policy ====================
  // Get navigation action policy for specific URLs
  // Handles OAuth redirects, intent URLs, and custom schemes
  Future<NavigationActionPolicy> getNavigationPolicy(
      WebUri? uri, WebViewHelper webViewHelper) async {
    // Handle OAuth URLs (Google, Kakao, Naver)
    if (uri != null &&
        (uri
                .toString()
                .contains("https://accounts.google.com/o/oauth2/v2/auth") ||
            uri
                .toString()
                .contains("https://kauth.kakao.com/oauth/authorize") ||
            uri
                .toString()
                .contains("https://nid.naver.com/oauth2.0/authorize"))) {
      print("uri => ${uri.uriValue}");
      try {
        final result =
            await launchUrl(uri.uriValue, mode: LaunchMode.externalApplication);
        if (!result) {
          print("Failed to launch OAuth URL");
        }
      } catch (e) {
        print("Error launching OAuth: $e");
      }
      return NavigationActionPolicy.CANCEL;
    }

    // Handle Naver custom schemes
    if (uri != null &&
        (uri.scheme == "naversearchthirdlogin" || uri.scheme == "nidlogin")) {
      uri.replace(scheme: 'naversearchthirdlogin');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
      return NavigationActionPolicy.CANCEL;
    }

    // Handle intent URLs
    if (uri.toString().contains("intent:")) {
      try {
        Uri appUri = Uri.parse(
            webViewHelper.convertAndAdjustUrl(uri.toString()).toString());
        if (await canLaunchUrl(appUri)) {
          await launchUrl(appUri,
              mode: LaunchMode.externalNonBrowserApplication);
        } else {
          // Try to open Play Store if app is not installed
          String? package = webViewHelper.getIntentPackage(uri.toString());
          if (package != null &&
              await canLaunchUrl(Uri.parse(
                  "https://play.google.com/store/apps/details?id=$package"))) {
            await launchUrl(
                Uri.parse(
                    "https://play.google.com/store/apps/details?id=$package"),
                mode: LaunchMode.externalNonBrowserApplication);
          }
        }
      } catch (e) {
        print("Error handling intent URL: $e");
        return NavigationActionPolicy.CANCEL;
      }
      return NavigationActionPolicy.CANCEL;
    }

    return NavigationActionPolicy.ALLOW;
  }

  // ==================== Error Handling ====================

  /// Handle WebView errors
  Future<void> onReceivedError({
    required InAppWebViewController controller,
    required WebResourceRequest request,
    required WebResourceError error,
    required PullToRefreshController? pullToRefreshController,
    required InAppWebViewController? webViewController,
    required Function(String) onShowError,
    required Function({
      double? progress,
      bool? showNoInternet,
      bool? noInternet,
    }) onUpdateState,
  }) async {
    pullToRefreshController?.endRefreshing();

    onUpdateState(progress: 1);

    final uri = request.url;
    final rawUri = uri.uriValue;

    final appScheme = EnvConfig.instance.appScheme;

    // Handle app custom scheme (e.g., osaka-live-dev://app?url=https://...) by redirecting to the target URL
    if (rawUri.scheme == appScheme &&
        (rawUri.queryParameters['url']?.isNotEmpty ?? false)) {
      final target = Uri.tryParse(rawUri.queryParameters['url']!);
      if (target != null &&
          (target.scheme == 'http' || target.scheme == 'https')) {
        await webViewController?.loadUrl(
            urlRequest: URLRequest(url: WebUri.uri(target)));
        return;
      }
    }

    // Handle specific error codes
    if (error.description ==
        "The operation couldn't be completed. (NSURLErrorDomain error -999.)") {
      webViewController?.loadUrl(
          urlRequest: URLRequest(url: WebUri.uri(Uri.parse(_webViewUrl))));
      return;
    }
    print("onReceivedError ${error.description}");
    if (error.description == "net::ERR_NAME_NOT_RESOLVED") {
      onUpdateState(showNoInternet: true, noInternet: true);
      return;
    }

    // Handle unsupported URL on iOS
    if (Platform.isIOS &&
        error.description == 'unsupported URL' &&
        WebViewHelper.isNonWebsiteUrl(uri.toString())) {
      // Avoid looping when the URL is our own app scheme; it was handled above.
      if (uri.scheme == appScheme) {
        return;
      }
      if (await canLaunchUrl(uri)) {
        print("launch unsupport url $uri");
        await launchUrl(uri);
      } else {
        webViewController?.stopLoading();
        onShowError("The website is not available.");
      }
      return;
    }

    if (Platform.isAndroid) {
      if (error.description == 'net::ERR_UNKNOWN_URL_SCHEME') {
        webViewController?.goBack();
        return;
      }

      if (error.description == 'net::ERR_INTERNET_DISCONNECTED' ||
          error.description == 'net::ERR_TIMED_OUT') {
        onUpdateState(showNoInternet: true, noInternet: true);
        return;
      }
    }

    if (Platform.isIOS &&
        error.description == 'The Internet connection appears to be offline.') {
      onUpdateState(showNoInternet: true, noInternet: true);
      return;
    }
  }

  // ==================== History & Console ====================

  /// Handle visited history update
  void onUpdateVisitedHistory({
    required WebUri? url,
    required Function(String) onUpdateUrl,
  }) {
    onUpdateUrl(url.toString());
  }

  /// Handle console messages
  void onConsoleMessage(ConsoleMessage message) {
    print('------console-log: ${message.message}');
  }

  // ==================== Download Handling ====================

  /// Handle download start request from WebView
  Future<void> onDownloadStartRequest({
    required DownloadStartRequest request,
    required Function({bool? isLoading, double? progress}) onUpdateState,
  }) async {
    onUpdateState(isLoading: false, progress: 1);

    final permissionService = PermissionService();
    final hasPermission = await permissionService.requestStoragePermission();

    if (hasPermission) {
      String url = request.url.toString();
      String fileName = request.suggestedFilename.toString();

      final downloadProvider =
          // ignore: use_build_context_synchronously
          Provider.of<DownloadProvider>(context, listen: false);
      await downloadProvider.startDownload(
        url: url,
        name: fileName,
      );
    } else {
      await permissionService.openAppSettings();
    }
  }

  // ==================== Create Window ====================

  /// Handle create window request (popups)
  Future<bool> onCreateWindow({
    required CreateWindowAction createWindowRequest,
    required WebviewWindow webviewWindow,
    required bool isOpenDialog,
    required bool isNewWindowLoading,
    required bool allowClosePopUp,
    required BuildContext? dialogContext,
    required String url,
    required InAppWebViewSettings options,
    required Function(bool isOpenDialog) setIsOpenDialog,
    required Function(bool isNewWindowLoading) setIsNewWindowLoading,
    required Function(bool allowClosePopUp) setAllowClosePopUp,
  }) async {
    final webUri = createWindowRequest.request.url;

    // Check for file extensions
    if (webUri.toString().contains(
        RegExp(r'\.(pdf|doc|docx|xls|xlsx|ppt|pptx|zip|rar|txt|csv)$'))) {
      print("downloading file");
      // Prevent the webview from loading the URL
      return false;
    }

    // Check for OAuth URLs
    if (webUri != null &&
        (webUri
                .toString()
                .contains("https://accounts.google.com/o/oauth2/v2/auth") ||
            webUri
                .toString()
                .contains("https://kauth.kakao.com/oauth/authorize") ||
            webUri
                .toString()
                .contains("https://nid.naver.com/oauth2.0/authorize"))) {
      return false;
    }

    if (Platform.isAndroid) {
      return false;
    }

    print('onCreateWindow $webUri');
    webviewWindow.createWindow(
        windowId: createWindowRequest.windowId,
        isOpenDialog: isOpenDialog,
        isNewWindowLoading: isNewWindowLoading,
        allowClosePopUp: allowClosePopUp,
        setIsOpenDialog: setIsOpenDialog,
        setIsNewWindowLoading: setIsNewWindowLoading,
        setAllowClosePopUp: setAllowClosePopUp,
        context: context,
        dialogContext: dialogContext,
        url: url,
        options: options,
        webinitialUrl: _webViewUrl);
    return true;
  }
}

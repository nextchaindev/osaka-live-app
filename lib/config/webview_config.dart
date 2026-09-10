import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// WebView configuration settings
class WebViewConfig {
  /// Get default InAppWebView settings
  static InAppWebViewSettings getDefaultSettings() {
    return InAppWebViewSettings(
      useShouldOverrideUrlLoading: true,
      mediaPlaybackRequiresUserGesture: false,
      useOnDownloadStart: true,
      javaScriptEnabled: true,
      javaScriptCanOpenWindowsAutomatically: true,
      cacheEnabled: false,
      isInspectable: true,
      clearCache: false,
      supportZoom: true,
      preferredContentMode: UserPreferredContentMode.MOBILE,
      // userAgent: "random",
      verticalScrollBarEnabled: false,
      horizontalScrollBarEnabled: false,
      transparentBackground: true,
      allowFileAccessFromFileURLs: false,
      allowUniversalAccessFromFileURLs: false,
      thirdPartyCookiesEnabled: true,
      allowFileAccess: false,
      supportMultipleWindows: Platform.isIOS,
      allowsInlineMediaPlayback: true,
    );
  }
}

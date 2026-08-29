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
      // The web app declares `user-scalable=no` / `maximum-scale=1`, because
      // the map does its own pinch handling. Leaving zoom support on here
      // overrides that and puts a second, native pinch recogniser on the same
      // two fingers — on iOS the scroll view's own, on Android the built-in
      // zoom — so a pinch on the map is claimed by both at once.
      supportZoom: false,
      preferredContentMode: UserPreferredContentMode.MOBILE,
      // userAgent: "random",
      verticalScrollBarEnabled: false,
      horizontalScrollBarEnabled: false,
      transparentBackground: true,
      allowFileAccessFromFileURLs: true,
      allowUniversalAccessFromFileURLs: true,
      thirdPartyCookiesEnabled: true,
      allowFileAccess: true,
      supportMultipleWindows: Platform.isIOS,
      allowsInlineMediaPlayback: true,
    );
  }
}

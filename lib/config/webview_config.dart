import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:osaka_app/config/env_config.dart';

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
      // Browser caching stays on. The site's hashed JS, CSS and font assets
      // are served immutable, so re-fetching them on every cold start is
      // wasted mobile data. (On the current plugin `false` here is undone a
      // moment later by the Android `cacheMode` default, so this is stating
      // the intent rather than changing behaviour today — but it is what the
      // setting should say.)
      cacheEnabled: true,
      isInspectable: EnvConfig.instance.isDev,
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

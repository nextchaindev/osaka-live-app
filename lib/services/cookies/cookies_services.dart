import 'dart:convert';
import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:osaka_app/config/env_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Removes cookies persisted by older app versions in plaintext preferences.
Future<void> clearLegacyStoredCookies() async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.remove('cookies');
}

/// Mark that user is accessing the web via WebView
/// Sets a cookie to identify the platform (iOS/Android) for the web application
Future<void> markAccessByWebview({
  required String webViewUrl,
  required CookieManager cookieManager,
  double? safeAreaTop,
  double? safeAreaBottom,
  String? fcmToken,
}) async {
  final expiresDate =
      DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;
  final packageInfo = await PackageInfo.fromPlatform();
  final version = packageInfo.version;
  final appScheme = EnvConfig.instance.appScheme;
  final currentFcmToken =
      fcmToken ?? await FirebaseMessaging.instance.getToken();
  final payload = <String, dynamic>{
    "platform": Platform.isIOS ? "iOS" : "android",
    "version": version,
    "buildNumber": packageInfo.buildNumber,
    if (safeAreaTop != null) "safeAreaTop": safeAreaTop,
    if (safeAreaBottom != null) "safeAreaBottom": safeAreaBottom,
    "appScheme": appScheme,
    "environment": EnvConfig.instance.env.toLowerCase(),
    "fcmToken": currentFcmToken,
  };
  print("payload: $payload");
  await cookieManager.setCookie(
    url: WebUri.uri(Uri.parse(webViewUrl)),
    name: "webview",
    value: jsonEncode(payload),
    expiresDate: expiresDate,
    isHttpOnly: false,
    isSecure: false,
  );
}

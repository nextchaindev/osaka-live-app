import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:osaka_app/config/env_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../provider/saved_cookie_provider.dart';

void checkExistCookie(BuildContext context) async {
  SharedPreferences pref = await SharedPreferences.getInstance();
  if (context.mounted) {
    context
        .read<SavedCookieProvider>()
        .setSavedCookie(pref.getString('cookies'));
  }
}

/// Save cookies to SharedPreferences
Future<void> saveCookies(String url) async {
  try {
    List<Cookie> cookies = await CookieManager.instance().getCookies(
      url: WebUri.uri(Uri.parse(url)),
    );

    List<Map<String, dynamic>> cookiesData = cookies.map((cookie) {
      return {
        "name": cookie.name,
        "value": cookie.value,
        "domain": cookie.domain,
        "path": cookie.path,
        "expiresDate": cookie.expiresDate,
        "isSecure": cookie.isSecure,
        "isHttpOnly": cookie.isHttpOnly,
      };
    }).toList();

    String jsonString = jsonEncode(cookiesData);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('cookies', jsonString);
  } catch (e) {
    print("saving cookie error: $e");
  }
}

/// Restore cookies from SharedPreferences (for iOS)
/// This resolves the issue where iOS doesn't allow saving cookies
Future<void> restoreCookies(String url, CookieManager cookieManager) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? jsonString = prefs.getString('cookies');

  if (Platform.isIOS && jsonString != null) {
    try {
      List<dynamic> cookiesData = jsonDecode(jsonString);

      for (var cookieData in cookiesData) {
        await cookieManager.setCookie(
          url: WebUri.uri(Uri.parse(url)),
          name: cookieData["name"],
          value: cookieData["value"],
          domain: cookieData["domain"],
          path: cookieData["path"],
          expiresDate: cookieData["expiresDate"],
          isSecure: cookieData["isSecure"],
          isHttpOnly: cookieData["isHttpOnly"],
        );
      }
    } catch (e) {
      print("restore cookie error: $e");
    }
  }
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

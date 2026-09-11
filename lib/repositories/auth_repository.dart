import 'package:flutter_app_badge_control/flutter_app_badge_control.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:osaka_app/config/env_config.dart';
import 'package:osaka_app/config/http_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository for user authentication and session management
/// Handles user login state, FCM tokens, and cookie-based authentication
class AuthRepository {
  final env = EnvConfig.instance;

  // ==================== FCM Token Management ====================

  /// Save FCM device token to backend
  ///
  /// Parameters:
  /// - [fcmToken]: The Firebase Cloud Messaging token
  /// - [uidx]: Optional user ID to associate with the token (deprecated, no longer used)
  Future<void> saveDeviceToken({
    required String fcmToken,
    String? uidx,
  }) async {
    // await FcmService().save(fcmToken);
  }

  /// Delete FCM device token from backend
  /// Called when user logs out or token needs to be removed
  Future<void> deleteDeviceToken({required String fcmToken}) async {
    // await FcmService().delete(fcmToken);
  }

  // ==================== User Authentication ====================

  /// Check if user is logged in via website cookie
  /// Manages FCM token registration based on login status
  ///
  /// This method:
  /// 1. Checks for user cookie in the WebView
  /// 2. If user was logged in but cookie is gone → handles logout
  /// 3. If user is logged in → registers FCM token with user ID
  ///
  /// Parameters:
  /// - [cookieManager]: The WebView cookie manager
  /// - [url]: The website URL to check cookies for
  /// - [name]: The name of the user cookie (e.g., "USER_INFOR")
  Future<void> checkUserLoginStatus({
    required CookieManager cookieManager,
    required String url,
    required String name,
  }) async {
    String? myDeviceToken = await getFcmToken();
    if (myDeviceToken == null) return;

    Cookie? accessToken = await cookieManager.getCookie(
        url: WebUri.uri(Uri.parse(url)), name: name);
    SharedPreferences pref = await SharedPreferences.getInstance();
    // User was logged in but cookie is now gone (logged out)
    // print("loginStatus${env.env}: ${pref.get("loginStatus${env.env}")}");
    // print("accessToken: ${accessToken}");
    if (pref.get("loginStatus${env.env}") == "logged-in" &&
        accessToken == null) {
      await handleLogout(fcmToken: myDeviceToken);
      return;
    }
    // User is logged in
    else if (accessToken != null &&
        pref.get("loginStatus${env.env}") != "logged-in") {
      await handleLogin(
        accessToken: accessToken,
        fcmToken: myDeviceToken,
      );
    }
  }

  /// Handle user logout
  /// Removes FCM token, clears badge, and updates login status
  Future<void> handleLogout({required String fcmToken}) async {
    try {
      print("handleLogout");

      await deleteDeviceToken(fcmToken: fcmToken);
    } catch (e) {
      print(e);
    } finally {
      SharedPreferences pref = await SharedPreferences.getInstance();
      pref.setString("loginStatus${env.env}", "logged-out");

      // Clear the access token from HTTP client
      AppHttp.clearAccessToken();

      FlutterAppBadgeControl.isAppBadgeSupported().then((value) {
        FlutterAppBadgeControl.removeBadge();
      });
    }
  }

  /// Handle user login
  /// Registers FCM token with user ID and saves cookies
  Future<void> handleLogin({
    required Cookie accessToken,
    required String fcmToken,
  }) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    AppHttp.setAccessToken(accessToken);

    // Save FCM token with userId into database
    await saveDeviceToken(fcmToken: fcmToken);
    pref.setString("loginStatus${env.env}", "logged-in");
  }

  /// Get current login status
  Future<bool> isLoggedIn() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.get("loginStatus${env.env}") == "logged-in";
  }

  /// Set stored FCM token
  Future<void> setFcmToken({required String fcmToken}) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    if (pref.getString("fcmToken") != fcmToken) {
      pref.setString("fcmToken", fcmToken);
    }
  }

  /// Get stored FCM token
  Future<String?> getFcmToken() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.getString("fcmToken");
  }
}

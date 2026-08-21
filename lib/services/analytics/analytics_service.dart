import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized Firebase Analytics service for app-wide event tracking.
class AnalyticsService {
  factory AnalyticsService() => _instance;

  AnalyticsService._internal();

  static final AnalyticsService _instance = AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  Future<Map<String, Object>>? _deviceContextFuture;

  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      final deviceContext = await _getDeviceContext();
      final enrichedParameters = <String, Object>{
        ...?parameters,
        ...deviceContext,
      };
      await _analytics.logEvent(
        name: name,
        parameters: enrichedParameters,
      );
    } catch (e, stackTrace) {
      debugPrint('[Analytics] $name failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> logBackNavigation({
    required String action,
    String? currentUrl,
    bool? isRoot,
    bool? canGoBack,
    bool? controllerReady,
  }) async {
    final Uri? uri = currentUrl == null ? null : Uri.tryParse(currentUrl);
    final parameters = <String, Object>{
      'action': action,
      'current_path': uri?.path.isNotEmpty == true ? uri!.path : '/',
      if (isRoot != null) 'is_root': isRoot.toString(),
      if (canGoBack != null) 'can_go_back': canGoBack.toString(),
      if (controllerReady != null)
        'controller_ready': controllerReady.toString(),
    };

    await logEvent(name: 'back_navigation', parameters: parameters);
  }

  Future<Map<String, Object>> _getDeviceContext() {
    return _deviceContextFuture ??= _loadDeviceContext();
  }

  Future<Map<String, Object>> _loadDeviceContext() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return {
          'platform': 'android',
          'device_model': info.model,
          'os_version': info.version.release,
          'android_sdk': info.version.sdkInt.toString(),
        };
      }

      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return {
          'platform': 'ios',
          'device_model': info.modelName,
          'device_identifier': info.model,
          'os_version': info.systemVersion,
        };
      }
    } catch (e, stackTrace) {
      debugPrint('[Analytics] device info failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }

    return {
      'platform': defaultTargetPlatform.name,
      'device_model': 'unknown',
      'os_version': 'unknown',
    };
  }
}

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling app permissions
/// Centralizes all permission-related business logic
class PermissionService {
  static const _locationPermissionRequestedKey =
      'location_permission_requested';
  static const _iosLocationPermissionRequestedKey =
      'ios_location_permission_requested_v3';

  permission_handler.Permission get _foregroundLocationPermission =>
      Platform.isIOS
          ? permission_handler.Permission.locationWhenInUse
          : permission_handler.Permission.location;

  // ==================== Storage Permission ====================

  /// Request storage permission for file downloads
  /// Returns true if permission is granted, false otherwise
  ///
  /// Note: Android 13+ (SDK 33+) doesn't require storage permission
  /// for app-specific directories
  Future<bool> requestStoragePermission() async {
    try {
      if (Platform.isIOS) {
        final isGranted = await permission_handler.Permission.storage.isGranted;
        if (!isGranted) {
          final status = await permission_handler.Permission.storage.request();
          return status.isGranted;
        }
        return isGranted;
      }

      // Android
      final deviceInfoPlugin = DeviceInfoPlugin();
      final androidDeviceInfo = await deviceInfoPlugin.androidInfo;

      // Android 13+ (SDK 33+) doesn't require storage permission
      // for app-specific directories
      if (androidDeviceInfo.version.sdkInt >= 33) {
        return true;
      }

      // Android < 13 requires storage permission
      final isGranted = await permission_handler.Permission.storage.isGranted;
      if (!isGranted) {
        final status = await permission_handler.Permission.storage.request();
        return status.isGranted;
      }
      return isGranted;
    } catch (e) {
      print('Error requesting storage permission: $e');
      return false;
    }
  }

  // ==================== Notification Permission ====================

  /// Request FCM notification permission
  /// Returns true if permission is granted, false otherwise
  Future<bool> requestNotificationPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print("FCM Permission: Authorized");
        return true;
      }

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print("FCM Permission: Denied - requesting again");
        // Try once more
        final retrySettings =
            await FirebaseMessaging.instance.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        return retrySettings.authorizationStatus ==
            AuthorizationStatus.authorized;
      }

      // Provisional or other status
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      print('Error requesting notification permission: $e');
      return false;
    }
  }

  // ==================== Utility Methods ====================

  /// Check if storage permission is granted
  Future<bool> isStoragePermissionGranted() async {
    try {
      if (Platform.isIOS) {
        return await permission_handler.Permission.storage.isGranted;
      }

      // Android 13+ doesn't require storage permission
      final deviceInfoPlugin = DeviceInfoPlugin();
      final androidDeviceInfo = await deviceInfoPlugin.androidInfo;
      if (androidDeviceInfo.version.sdkInt >= 33) {
        return true;
      }

      return await permission_handler.Permission.storage.isGranted;
    } catch (e) {
      print('Error checking storage permission: $e');
      return false;
    }
  }

  /// Request camera and microphone permissions for custom video capture
  Future<bool> requestCameraAndMicrophonePermission() async {
    try {
      final cameraStatus = await permission_handler.Permission.camera.request();
      final microphoneStatus =
          await permission_handler.Permission.microphone.request();

      final isGranted = cameraStatus.isGranted && microphoneStatus.isGranted;
      if (isGranted) {
        return true;
      }

      if (cameraStatus.isPermanentlyDenied ||
          microphoneStatus.isPermanentlyDenied) {
        await permission_handler.openAppSettings();
      }

      return false;
    } catch (e) {
      print('Error requesting camera/microphone permission: $e');
      return false;
    }
  }

  // ==================== Location Permission ====================

  Future<Map<String, dynamic>> getLocationPermissionPayload() async {
    final status = await _foregroundLocationPermission.status;
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    return {
      'status': _locationStatusName(status),
      'serviceEnabled': serviceEnabled,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Future<Map<String, dynamic>> requestLocationPermission() async {
    final locationPermission = _foregroundLocationPermission;
    var status = await locationPermission.status;
    debugPrint(
      '[OsakaLive][location][permission] request start status=${_locationStatusName(status)}',
    );

    if (Platform.isIOS && status.isDenied) {
      final preferences = await SharedPreferences.getInstance();
      final hasRequested =
          preferences.getBool(_iosLocationPermissionRequestedKey) ?? false;
      if (hasRequested) {
        await permission_handler.openAppSettings();
      } else {
        await preferences.setBool(_iosLocationPermissionRequestedKey, true);
        status = await locationPermission.request();
      }
    } else if (status.isPermanentlyDenied || status.isRestricted) {
      debugPrint(
        '[OsakaLive][location][permission] opening app settings status=${_locationStatusName(status)}',
      );
      await permission_handler.openAppSettings();
    } else if (status.isDenied) {
      status = await locationPermission.request();
      debugPrint(
        '[OsakaLive][location][permission] request result status=${_locationStatusName(status)}',
      );
    }

    status = await locationPermission.status;
    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (status.isGranted && !serviceEnabled) {
      await Geolocator.openLocationSettings();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    }

    debugPrint(
      '[OsakaLive][location][permission] request complete status=${_locationStatusName(status)} serviceEnabled=$serviceEnabled',
    );
    return {
      'status': _locationStatusName(status),
      'serviceEnabled': serviceEnabled,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Future<Map<String, dynamic>> requestInitialLocationPermission() async {
    final locationPermission = _foregroundLocationPermission;
    final status = await locationPermission.status;
    if (!Platform.isAndroid) {
      if (status.isGranted ||
          status.isPermanentlyDenied ||
          status.isRestricted) {
        return getLocationPermissionPayload();
      }

      final preferences = await SharedPreferences.getInstance();
      final hasRequested =
          preferences.getBool(_iosLocationPermissionRequestedKey) ?? false;
      if (hasRequested) {
        return getLocationPermissionPayload();
      }

      await preferences.setBool(_iosLocationPermissionRequestedKey, true);
      await locationPermission.request();
      return getLocationPermissionPayload();
    }

    final preferences = await SharedPreferences.getInstance();
    final hasRequested =
        preferences.getBool(_locationPermissionRequestedKey) ?? false;
    if (hasRequested) {
      return getLocationPermissionPayload();
    }

    await preferences.setBool(_locationPermissionRequestedKey, true);
    final wasPreviouslyDenied = status.isDenied &&
        await permission_handler.Permission.location.shouldShowRequestRationale;
    if (status.isGranted ||
        status.isPermanentlyDenied ||
        status.isRestricted ||
        wasPreviouslyDenied) {
      return getLocationPermissionPayload();
    }

    return requestLocationPermission();
  }

  String _locationStatusName(permission_handler.PermissionStatus status) {
    if (status.isGranted) {
      return 'granted';
    }
    if (status.isPermanentlyDenied) {
      return 'permanentlyDenied';
    }
    if (status.isRestricted) {
      return 'restricted';
    }
    if (status.isLimited) {
      return 'limited';
    }
    if (status.isDenied) {
      return 'denied';
    }
    if (status.isProvisional) {
      return 'provisional';
    }

    return 'unknown';
  }

  /// Open app settings for manual permission grant
  Future<void> openAppSettings() async {
    await permission_handler.openAppSettings();
  }
}

// ==================== Legacy Functions (Deprecated) ====================
// These functions are kept for backward compatibility
// Consider migrating to PermissionService

@Deprecated('Use PermissionService.requestStoragePermission() instead')
Future<bool?> enableStoragePermision() async {
  final service = PermissionService();
  return await service.requestStoragePermission();
}

@Deprecated('Use PermissionService.requestNotificationPermission() instead')
Future<void> activeRequestPermissionFCM() async {
  final service = PermissionService();
  await service.requestNotificationPermission();
}

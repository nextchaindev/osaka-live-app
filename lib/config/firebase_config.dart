import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:version/version.dart';
import 'package:osaka_app/config/env_config.dart';
import 'package:osaka_app/firebase_options.dart';
import 'package:osaka_app/firebase_options_dev.dart';
import 'package:osaka_app/firebase_options_staging.dart';
import 'package:osaka_app/provider/webview_provider.dart';

class FirebaseConfig {
  FirebaseConfig._internal();
  static final FirebaseConfig instance = FirebaseConfig._internal();

  factory FirebaseConfig() {
    return instance;
  }

  late AndroidNotificationChannel channel;
  bool isFlutterLocalNotificationsInitialized = false;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  String? messId;

  static const _localVersionKey = 'firebase_app_version';
  static const _localBuildKey = 'firebase_app_build';

  /// Initialize Firebase app with environment-specific options
  static const _defaultFirebaseAppName = '[DEFAULT]';

  static Future<void> initializeFirebaseApp(String environment) async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final currentBuild = packageInfo.buildNumber;
    final storedVersion = prefs.getString(_localVersionKey);
    final storedBuild = prefs.getString(_localBuildKey);

    final shouldForceReinit = _shouldReinitializeFirebase(
      currentVersion: currentVersion,
      currentBuild: currentBuild,
      storedVersion: storedVersion,
      storedBuild: storedBuild,
    );

    if (shouldForceReinit) {
      await _deleteFirebaseDefaultAppIfExists();
    } else if (Firebase.apps
        .any((app) => app.name == _defaultFirebaseAppName)) {
      print(
          'Firebase app "$environment" already initialized with saved version.');
      return;
    }

    await Firebase.initializeApp(
      options: environment == 'dev'
          ? DefaultFirebaseDevOptions.currentPlatform
          : environment == 'staging'
              ? DefaultFirebaseStagingOptions.currentPlatform
              : DefaultFirebaseOptions.currentPlatform,
    );

    await prefs.setString(_localVersionKey, currentVersion);
    await prefs.setString(_localBuildKey, currentBuild);

    print('Firebase app initialized with environment: $environment');
    print(
        'Firebase app options  $environment => ${Firebase.app().options.appId}');
  }

  static Future<void> _deleteFirebaseDefaultAppIfExists() async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    try {
      final existing = Firebase.app();
      await existing.delete();
      print('Deleted default Firebase app before reinitialization.');
    } on ArgumentError {
      // App not found, nothing to delete.
    }
  }

  static bool _shouldReinitializeFirebase({
    required String currentVersion,
    required String currentBuild,
    required String? storedVersion,
    required String? storedBuild,
  }) {
    if (storedVersion == null || storedBuild == null) {
      return true;
    }

    final parsedCurrentVersion = _parseVersionSafely(currentVersion);
    final parsedStoredVersion = _parseVersionSafely(storedVersion);
    if (parsedCurrentVersion == null || parsedStoredVersion == null) {
      return true;
    }

    final currentBuildNumber = int.tryParse(currentBuild);
    final storedBuildNumber = int.tryParse(storedBuild);
    if (currentBuildNumber == null || storedBuildNumber == null) {
      return true;
    }

    if (parsedCurrentVersion.compareTo(parsedStoredVersion) != 0) {
      return true;
    }

    return currentBuildNumber != storedBuildNumber;
  }

  static Version? _parseVersionSafely(String value) {
    try {
      return Version.parse(value);
    } on FormatException catch (_) {
      return null;
    }
  }

  /// Initialize Firebase messaging and notifications
  Future<void> initialize(BuildContext context) async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (context.mounted) {
        showFlutterNotification(context, message);
      }
    });
    if (context.mounted) {
      await setupInteractedMessage(context);
    }
    if (context.mounted) {
      await setupFlutterNotifications(context);
    }
  }

  /// Setup message interaction handlers
  Future<void> setupInteractedMessage(BuildContext context) async {
    // Get any messages which caused the application to open from
    // a terminated state.
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    // If the message also contains a data property with a "type" of "chat",
    // navigate to a chat screen
    if (initialMessage != null && context.mounted) {
      await onMessageOpenApp(context, initialMessage);
    }

    // Also handle any interaction when the app is in the background via a
    // Stream listener
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      if (context.mounted) {
        await onMessageOpenApp(context, message);
      }
    });
  }

  /// Handle a notification that opened the app from any lifecycle state.
  Future<void> onMessageOpenApp(
      BuildContext context, RemoteMessage message) async {
    try {
      final target = _resolveRedirectUrl(message.data['redirectUrl']);
      if (target == null) {
        debugPrint(
          '[OsakaLive][notification] ignored invalid redirectUrl: '
          '${message.data['redirectUrl']}',
        );
        return;
      }

      final provider = Provider.of<WebViewProvider>(context, listen: false);
      debugPrint(
        '[OsakaLive][notification] opening ${message.messageId}: $target',
      );
      await provider.openDeepLink(target);
    } catch (e) {
      debugPrint('[OsakaLive][notification] open error: $e');
    }
  }

  Uri? _resolveRedirectUrl(Object? value) {
    final rawUrl = value?.toString().trim() ?? '';
    if (rawUrl.isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(rawUrl);
    if (parsed == null) {
      return null;
    }

    final target = parsed.hasScheme
        ? parsed
        : Uri.parse(EnvConfig.instance.webviewUrl).resolveUri(parsed);
    if (target.scheme != 'http' && target.scheme != 'https') {
      return null;
    }

    return target;
  }

  /// Setup Flutter local notifications
  Future<void> setupFlutterNotifications(BuildContext context) async {
    if (Platform.isIOS) {
      // Request permission for iOS notifications
      NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      print('User granted permission: ${settings.authorizationStatus}');
      await FirebaseMessaging.instance.getAPNSToken();
    }

    channel = const AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInitializationSettings =
        DarwinInitializationSettings();

    final InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: iosInitializationSettings);

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        await handleNotificationTap(context, response);
      },
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: true,
    );
    isFlutterLocalNotificationsInitialized = true;
  }

  /// Handle notification tap
  Future<void> handleNotificationTap(
      BuildContext context, NotificationResponse response) async {
    if (response.payload != null) {
      // Handle the action, like navigating to a specific screen
      print('Notification payload: ${response.payload}');
      try {
        final provider = Provider.of<WebViewProvider>(context, listen: false);
        final target = _resolveRedirectUrl(response.payload);
        if (target != null) {
          await provider.openDeepLink(target);
        }
      } catch (e) {
        print("err => $e");
      }
      // Navigate to a specific screen or perform some action based on the payload
    }
  }

  /// Show Flutter notification
  void showFlutterNotification(
      BuildContext context, RemoteMessage message) async {
    print('Foreground message received, skip notification display');
    // RemoteNotification? notification = message.notification;
    // if (messId == message.messageId) {
    //   return;
    // }
    // if (notification != null) {
    //   print('show notification');

    //   // Only show notification using flutter_local_notifications on Android
    //   // iOS will handle foreground notifications natively via setForegroundNotificationPresentationOptions
    //   if (Platform.isAndroid) {
    //     flutterLocalNotificationsPlugin.show(
    //         notification.hashCode,
    //         notification.title,
    //         notification.body,
    //         NotificationDetails(
    //             android: AndroidNotificationDetails(channel.id, channel.name,
    //                 channelDescription: channel.description,
    //                 icon: 'ic_noti_icon',
    //                 color: const Color(0xff000000))),
    //         payload: message.data['redirectUrl']);
    //   }
    //   messId = message.messageId;
    // }
  }
}

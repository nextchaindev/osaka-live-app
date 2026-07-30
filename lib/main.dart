import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:osaka_app/config/env_config.dart';
import 'package:osaka_app/config/firebase_config.dart';
import 'package:osaka_app/provider/app_global_key.dart';
import 'package:osaka_app/provider/webview_provider.dart';

import 'provider/navigation_bar_provider.dart';
import 'constants/common.dart';
import 'provider/saved_cookie_provider.dart';
import 'provider/download_provider.dart';
import 'provider/theme_provider.dart';

import 'screens/main_screen.dart';
import 'services/cookies/cookies_services.dart';
import 'services/permission/permission_service.dart';
import 'widgets/common/download_snackbar.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message received: ${message.notification?.body}');
  // Handle background message here
}

Future<String> _resolveEnvironment() async {
  const definedEnvironment = String.fromEnvironment('ENVIRONMENT');
  if (definedEnvironment.isNotEmpty) {
    return definedEnvironment;
  }

  final bundleId = (await PackageInfo.fromPlatform()).packageName;
  return switch (bundleId) {
    'live.osaka' => 'prod',
    'live.osaka.staging' || 'live.osaka.dev.staging' => 'staging',
    _ => 'dev',
  };
}

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final environment = await _resolveEnvironment();
    await EnvConfig.initialize(environment);
    await FirebaseConfig.initializeFirebaseApp(environment);
    await FirebaseConfig.instance.captureInitialMessage();

    // Register background message handler (must be top-level function)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request notification permission
    final permissionService = PermissionService();
    await permissionService.requestNotificationPermission();
  } on Exception catch (e) {
    print(e);
  }

  return runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<NavigationBarProvider>(
          create: (_) => NavigationBarProvider()),
      ChangeNotifierProvider(create: (context) => WebViewProvider()),
      ChangeNotifierProvider(create: (context) => SavedCookieProvider()),
      ChangeNotifierProvider(create: (context) => DownloadProvider()),
    ],
    builder: ((providerContext, child) {
      return MyApp();
    }),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    try {
      FirebaseConfig.instance.initialize(context);
      checkExistCookie(context);
    } on Exception catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return MaterialApp(
        onGenerateTitle: (BuildContext context) {
          // Get device locale and return appropriate app name
          final locale = Localizations.maybeLocaleOf(context);
          return getLocalizedAppName(locale?.languageCode);
        },
        // Support Korean and English locales
        supportedLocales: const [
          Locale('en', ''), // English
          Locale('ko', ''), // Korean
        ],
        // Handle locale resolution
        localeResolutionCallback: (locale, supportedLocales) {
          // Check if the device locale is supported
          for (var supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale?.languageCode) {
              return supportedLocale;
            }
          }
          // Default to English if not supported
          return supportedLocales.first;
        },
        debugShowCheckedModeBanner: false,
        theme: AppThemes.lightTheme,
        navigatorKey: navigatorKey,
        onGenerateRoute: null,
        home: DownloadSnackBar(
          child: MyHomePage(),
        ));
  }
}

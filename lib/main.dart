import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:osaka_app/config/env_config.dart';
import 'package:osaka_app/config/firebase_config.dart';
import 'package:osaka_app/provider/app_global_key.dart';
import 'package:osaka_app/provider/webview_provider.dart';
import 'package:osaka_app/provider/locale_provider.dart';
import 'package:osaka_app/l10n/generated/app_localizations.dart';

import 'provider/navigation_bar_provider.dart';
import 'constants/common.dart';
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
    'live.osaka.staging' => 'staging',
    _ => 'dev',
  };
}

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = await _resolveEnvironment();
  await EnvConfig.initialize(environment);
  await clearLegacyStoredCookies();

  late LocaleProvider localeProvider;
  try {
    localeProvider = await LocaleProvider.initialize();
  } on Exception catch (e) {
    print(e);
    localeProvider = await LocaleProvider.initializeFallback();
  }

  try {
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
      ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
      ChangeNotifierProvider<NavigationBarProvider>(
          create: (_) => NavigationBarProvider()),
      ChangeNotifierProvider(create: (context) => WebViewProvider()),
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
  LocaleProvider? _localeProvider;
  String? _lastLocale;

  @override
  void initState() {
    super.initState();
    _localeProvider = context.read<LocaleProvider>();
    _lastLocale = _localeProvider!.effectiveLocale;
    _localeProvider!.addListener(_handleLocaleChanged);
    try {
      FirebaseConfig.instance.initialize(context);
    } on Exception catch (e) {
      print(e);
    }
  }

  void _handleLocaleChanged() {
    final provider = _localeProvider;
    if (provider == null) return;
    final locale = provider.effectiveLocale;
    final shouldReloadWebView =
        locale != _lastLocale && provider.localeSource == 'device';
    _lastLocale = locale;
    if (shouldReloadWebView) {
      final controller = context.read<WebViewProvider>().controller;
      if (controller != null) {
        unawaited(controller.reload());
      }
    }
  }

  @override
  void dispose() {
    _localeProvider?.removeListener(_handleLocaleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    final localeProvider = context.watch<LocaleProvider>();
    return MaterialApp(
        locale: localeProvider.locale,
        onGenerateTitle: (BuildContext context) {
          // Get device locale and return appropriate app name
          final locale = Localizations.maybeLocaleOf(context);
          return getLocalizedAppName(locale?.languageCode);
        },
        // Provides framework strings and semantics for Material, Cupertino,
        // and general widgets in every supported locale below.
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('ko'),
          Locale('ja'),
        ],
        debugShowCheckedModeBanner: false,
        theme: AppThemes.lightTheme,
        navigatorKey: navigatorKey,
        onGenerateRoute: null,
        home: DownloadSnackBar(
          child: MyHomePage(),
        ));
  }
}

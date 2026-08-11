import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:osaka_app/config/env_config.dart';
import 'package:osaka_app/constants/common.dart';
import 'package:osaka_app/config/app_remote_config.dart';
import 'package:osaka_app/extends/colors.dart';
import 'package:osaka_app/helpers/Themes.dart';
import 'package:osaka_app/helpers/icons.dart';
import 'package:osaka_app/provider/webview_provider.dart';
import 'package:osaka_app/repositories/auth_repository.dart';
import 'package:osaka_app/services/location/location_sync_service.dart';
import 'package:osaka_app/services/permission/permission_service.dart';
import 'package:osaka_app/widgets/common/dialog.dart';
import 'package:osaka_app/widgets/splash_overlay/index.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:version/version.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:osaka_app/widgets/webview/index.dart';
import '../provider/navigation_bar_provider.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
  });
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController idleAnimation;
  late AnimationController onSelectedAnimation;
  late AnimationController onChangedAnimation;
  Duration animationDuration = const Duration(milliseconds: 700);
  late AnimationController navigationContainerAnimationController =
      AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500));
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [];
  final AppDialog appDialog = AppDialog();
  final LocationSyncService _locationSyncService = LocationSyncService();

  StreamSubscription<Uri>? _linkSubscription;

  // Track app initialization state locally
  bool _isAppInitialized = false;
  bool _isUpdateRequired = false;
  bool _shouldHideSplash = false;
  Timer? _splashHideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initializeTabs();
    idleAnimation = AnimationController(vsync: this);
    onSelectedAnimation =
        AnimationController(vsync: this, duration: animationDuration);
    onChangedAnimation =
        AnimationController(vsync: this, duration: animationDuration);

    initDeepLinks();

    // Reset loading provider after build phase completes
    // This ensures splash shows on initial load and hot reload
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final loadingProvider =
            Provider.of<WebViewProvider>(context, listen: false);
        // Only reset if not already initialized (for hot reload case)
        // If already initialized and webview loaded, keep it hidden
        if (!_isAppInitialized || loadingProvider.progress < 1.0) {
          loadingProvider.resetLoading();
        }

        unawaited(_requestInitialLocationPermissionAndSync());
      }
    });

    _initializeApp();

    Future.delayed(Duration.zero, () {
      // ignore: use_build_context_synchronously
      context
          .read<NavigationBarProvider>()
          .setAnimationController(navigationContainerAnimationController);
    });
  }

  // Initialize app logic (moved from SplashScreen)
  Future<void> _initializeApp() async {
    try {
      await RemoteConfigManager().initialize();
      _isUpdateRequired = await checkUpdateRequired();
      if (_isUpdateRequired && mounted) {
        _showForceUpdateDialog();
      }
      await FirebaseMessaging.instance.getAPNSToken();
      var fcmToken = await FirebaseMessaging.instance.getToken();

      AuthRepository().setFcmToken(fcmToken: fcmToken ?? '');
      print('--------fcmToken:$fcmToken');
    } on Exception catch (e) {
      print("get fcm err : =>>> $e");
    } finally {
      // Mark app initialization as complete
      print("isUpdateRequired => $_isUpdateRequired");
      setState(() {
        _isAppInitialized = true;
      });

      // Update loading state based on initialization and webview progress
      // _updateSplashVisibility();
    }
  }

  // Check update required when the version from Firebase Remote Config is greater than the current version
  Future<bool> checkUpdateRequired() async {
    try {
      if (EnvConfig.instance.env != 'PROD') return false;
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final remoteVersion = RemoteConfigManager().getString(
          Platform.isAndroid ? androidForceUpdateVerion : iOSForceUpdateVerion);
      if (remoteVersion.isEmpty) return false;
      final current = Version.parse(currentVersion);
      final remote = Version.parse(remoteVersion);
      print('--------currentVersion:$currentVersion');
      print('--------remoteVersion:$remoteVersion');
      return remote > current;
    } catch (e) {
      print(e);
      return false;
    }
  }

  void _startLocationSync() {
    if (!mounted) {
      return;
    }

    final webViewProvider = context.read<WebViewProvider>();
    _locationSyncService.start(
      onPosition: (position) {
        webViewProvider.handleLivePositionChanged(
          lat: position.latitude,
          lng: position.longitude,
          accuracy: position.accuracy,
          updatedAt: position.timestamp.millisecondsSinceEpoch,
        );
      },
    );
  }

  Future<void> _refreshLocationPermissionAndSync() async {
    if (!mounted) {
      return;
    }

    final permissionPayload =
        await PermissionService().getLocationPermissionPayload();
    if (!mounted) {
      return;
    }

    await context.read<WebViewProvider>().sendLocationPermissionStatus(
          status: permissionPayload['status'] as String,
          serviceEnabled: permissionPayload['serviceEnabled'] as bool,
          updatedAt: (permissionPayload['updatedAt'] as num?)?.toInt(),
        );
    _startLocationSync();
  }

  Future<void> _requestInitialLocationPermissionAndSync() async {
    if (!mounted) {
      return;
    }

    final permissionPayload =
        await PermissionService().requestInitialLocationPermission();
    if (!mounted) {
      return;
    }

    await context.read<WebViewProvider>().sendLocationPermissionStatus(
          status: permissionPayload['status'] as String,
          serviceEnabled: permissionPayload['serviceEnabled'] as bool,
          updatedAt: (permissionPayload['updatedAt'] as num?)?.toInt(),
        );
    _startLocationSync();
  }

  void _showForceUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // ignore: deprecated_member_use
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A6CF7), Color(0xFF7D9CFA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1.2),
                    ),
                    child: const Icon(Icons.system_update_alt,
                        size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '업데이트가 필요합니다',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '최신 버전으로 업데이트하고\n더 나은 경험을 누려보세요.',
                    style: TextStyle(
                        fontSize: 14, color: Colors.white70, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF4A6CF7),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        PackageInfo packageInfo =
                            await PackageInfo.fromPlatform();
                        final Uri iosAppStoreUrl = Uri.parse(
                            "https://apps.apple.com/kr/app/osaka-live-real-time-travel/id6795804178");
                        final Uri androidPlayStoreUrl = Uri.parse(
                            "https://play.google.com/store/apps/details?id=${packageInfo.packageName}");
                        final targetUrl = Platform.isAndroid
                            ? androidPlayStoreUrl
                            : iosAppStoreUrl;
                        if (await canLaunchUrl(targetUrl)) {
                          await launchUrl(targetUrl,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      child: const Text(
                        '업데이트하기',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '계속 사용하려면 업데이트가 필요합니다.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> initDeepLinks() async {
    // Handle links
    AppLinks().getInitialLink().then((link) {
      print("link => $link");
      if (link != null) {
        openAppLink(link);
      }
    });
    _linkSubscription = AppLinks().uriLinkStream.listen((uri) {
      debugPrint('onAppLink: $uri');
      openAppLink(uri);
    });
  }

  void openAppLink(Uri uri) {
    // Prefer explicit query param ?url=... for custom schemes
    String url = (uri.queryParameters['url'] ?? '').trim();

    // Fallback: handle legacy format like <scheme>://app?url=...
    if (url.isEmpty) {
      url = uri
          .toString()
          .replaceFirst("${EnvConfig.instance.appScheme}://app?url=", "");
    }

    // If still empty and scheme is already http/https, use directly
    if (url.isEmpty && (uri.scheme == 'http' || uri.scheme == 'https')) {
      url = uri.toString();
    }

    if (url.isEmpty) return;

    final target = Uri.tryParse(url);
    if (target == null ||
        (target.scheme != 'http' && target.scheme != 'https')) {
      return;
    }

    final provider = Provider.of<WebViewProvider>(context, listen: false);
    InAppWebViewController? webViewController = provider.controller;

    if (webViewController != null) {
      webViewController.loadUrl(
          urlRequest: URLRequest(url: WebUri.uri(target)));
    } else {
      provider.setPendingDeepLink(target);
    }
  }

  initializeTabs() {
    _navigatorKeys.add(GlobalKey<NavigatorState>());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    idleAnimation.dispose();
    onSelectedAnimation.dispose();
    onChangedAnimation.dispose();
    navigationContainerAnimationController.dispose();
    _linkSubscription?.cancel();
    _splashHideTimer?.cancel();
    _locationSyncService.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_refreshLocationPermissionAndSync());
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Theme.of(context).cardColor,
      statusBarBrightness: Theme.of(context).brightness == Brightness.dark
          ? Brightness.dark
          : Brightness.light,
      statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
    ));
    final double topPadding = MediaQuery.of(context).padding.top;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final webviewProvider = context.read<WebViewProvider>();
    if (webviewProvider.safeAreaTop != topPadding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          webviewProvider.setSafeAreaTop(topPadding);
          webviewProvider.setSafeAreaBottom(bottomPadding);
        }
      });
    }

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () => _navigateBack(context),
      child: GestureDetector(
        onTap: () =>
            context.read<NavigationBarProvider>().animationController.reverse(),
        child: Container(
            color: Colors.white,
            child: Scaffold(body: Consumer<WebViewProvider>(
              builder: (context, webviewProvider, child) {
                // Update splash visibility when progress changes
                bool isLoaded = _isAppInitialized &&
                    webviewProvider.progress >= 1.0 &&
                    !_isUpdateRequired;

                // Handle delay before hiding splash
                if (isLoaded && !_shouldHideSplash) {
                  _splashHideTimer?.cancel();
                  _splashHideTimer =
                      Timer(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      setState(() {
                        _shouldHideSplash = true;
                      });
                    }
                  });
                } else if (!isLoaded && _shouldHideSplash) {
                  // Reset flag when loading again
                  _splashHideTimer?.cancel();
                  _shouldHideSplash = false;
                }
                  final disableTopSafeArea = 
                  routeNoSafeArea.any((route) =>
                    webviewProvider.currentUrl.contains(route) )||
                    webviewProvider.currentUrl ==
                        EnvConfig.instance.webviewUrl;               
                 return Stack(
                  children: [
                    Opacity(
                      opacity: isLoaded ? 1.0 : 0.0,
                      child: Container(
                        color: Colors.white,
                        child: SafeArea(
                          top: !disableTopSafeArea ,
                          bottom: true,
                          child: Navigator(
                            key: _navigatorKeys[0],
                            onGenerateRoute: (routeSettings) {
                              return MaterialPageRoute(
                                  builder: (_) => WebViewContainer());
                            },
                          ),
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: (!isLoaded || !_shouldHideSplash) ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: (!isLoaded || !_shouldHideSplash)
                          ? SplashOverlay()
                          : SizedBox.shrink(),
                    ),
                    // Splash screen overlay that hides when webview loads
                  ],
                );
              },
            ))),
      ),
    );
  }

  Future<bool> _navigateBack(BuildContext context) async {
    if (Platform.isIOS && Navigator.of(context).userGestureInProgress) {
      return Future.value(true);
    }
    final env = EnvConfig.instance;

    final provider = Provider.of<WebViewProvider>(context, listen: false);
    InAppWebViewController? webViewController = provider.controller;

    if (webViewController == null) {
      return Future.value(true);
    }

    if (await webViewController.canGoBack()) {
      // Check if the URL has specific query parameters
      try {
        WebUri? currentUrl = await webViewController.getUrl();
        if (currentUrl == null) {
          return Future.value(true);
        }
        Map<String, String> params = currentUrl.queryParameters;
        if (params['token_version_id'] != null &&
            params['enc_data'] != null &&
            params['integrity_value'] != null) {
          await webViewController.loadUrl(
              urlRequest:
                  URLRequest(url: WebUri.uri(Uri.parse(env.webviewUrl))));
        } else {
          await webViewController.goBack();
        }
        return Future.value(false);
      } catch (e) {
        print("Error handling navigation: $e");
        await webViewController.goBack();
        return Future.value(false);
      }
    } else {
      showDialog(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (context) => AlertDialog(
                insetPadding: EdgeInsets.all(24), // Remove default padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ), // Optional: Add rounded corners
                title: Container(
                    margin: EdgeInsets.symmetric(horizontal: 24),
                    width: fullWidth(context) - 48,
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          Theme.of(context).colorScheme.exitIcon,
                          width: perWidth(context, 80),
                          colorFilter: ColorFilter.mode(
                              Color(0xff5A4FF3), BlendMode.srcIn),
                        ),
                        SizedBox(
                          height: 24,
                        ),
                        Text(
                          '앱을 종료 하시겠습니까?',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    )),
                actions: <Widget>[
                  SizedBox(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Color(0xffC9CCCF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    4), // Set your desired radius
                              ),
                              minimumSize: Size(100, 40),
                            ),
                            child: const Text(
                              '아니요',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xff1F1F1F),
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              SystemNavigator.pop();
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Color(0xff5A4FF3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    4), // Set your desired radius
                              ),
                              minimumSize: Size(100, 40),
                            ),
                            child: const Text(
                              '네',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ));

      return Future.value(true);
    }
  }
}

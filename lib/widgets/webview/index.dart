import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:osaka_app/config/env_config.dart';
import 'package:osaka_app/config/webview_config.dart';
import 'package:osaka_app/helpers/Colors.dart';
import 'package:osaka_app/helpers/webview_helper.dart';
import 'package:osaka_app/mixins/webview_lifecycle_mixin.dart';
import 'package:osaka_app/provider/download_provider.dart';
import 'package:osaka_app/provider/webview_provider.dart';
import 'package:osaka_app/repositories/auth_repository.dart';
import 'package:osaka_app/widgets/webview/not_found.dart';
import 'package:osaka_app/widgets/webview/webview_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'loading_overlay.dart';
import 'no_internet_widget.dart';

class WebViewContainer extends StatefulWidget {
  const WebViewContainer({super.key});

  @override
  State<WebViewContainer> createState() => _WebViewContainerState();
}

class _WebViewContainerState extends State<WebViewContainer>
    with WebViewLifecycleMixin {
  // Progress States
  double _progress = 0;
  String _currentUrl = '';

  // Error States
  bool _showErrorPage = false;
  bool _slowInternetPage = false;
  bool _noInternet = false;
  bool _showNoInternet = false;
  bool _isValidURL = false;

  // Dialog States
  bool _isDialogLoading = false;
  bool _isOpenDialog = false;
  bool _allowClosePopUp = true;

  late PullToRefreshController _pullToRefreshController;

  final String _initialUrl = EnvConfig.instance.webviewUrl;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final WebviewWindow _webviewWindow = WebviewWindow();
  final _keepAlive = InAppWebViewKeepAlive();
  final InAppWebViewSettings _options = WebViewConfig.getDefaultSettings();
  final WebViewHelper _webViewHelper = WebViewHelper();
  final AuthRepository _authRepository = AuthRepository();

  InAppWebViewController? _webViewController;
  BuildContext? _dialogContext;

  @override
  void initState() {
    super.initState();

    _isValidURL = validateUrl(_initialUrl);
    _initPullToRequest();
  }

  void _initPullToRequest() {
    try {
      _pullToRefreshController = PullToRefreshController(
        settings: PullToRefreshSettings(color: primaryColor),
        onRefresh: () async {
          if (Platform.isAndroid) {
            _webViewController!.reload();
          } else if (Platform.isIOS) {
            _webViewController!.loadUrl(
                urlRequest:
                    URLRequest(url: await _webViewController!.getUrl()));
          }
        },
      );
    } on Exception catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _webViewController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        body: Column(
          children: [
            Expanded(
              child: Padding(
                  padding: EdgeInsets.only(top: 0),
                  child: GestureDetector(
                    onHorizontalDragEnd: (dragEndDetails) async {
                      if (dragEndDetails.primaryVelocity! > 0) {
                        if (await _webViewController?.canGoBack() ?? false) {
                          print(
                              "back to : ${await _webViewController?.getUrl()}");
                          _webViewController?.goBack();
                        }
                      }
                    },
                    // ignore: deprecated_member_use
                    child: Stack(
                      alignment: AlignmentDirectional.topStart,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        _isValidURL
                            ? InAppWebView(
                                initialUrlRequest: URLRequest(
                                    url: WebUri.uri(Uri.parse(_initialUrl))),
                                initialSettings: _options,
                                keepAlive: _keepAlive,
                                pullToRefreshController:
                                    _pullToRefreshController,
                                gestureRecognizers: <Factory<
                                    OneSequenceGestureRecognizer>>{
                                  Factory<OneSequenceGestureRecognizer>(
                                      () => EagerGestureRecognizer()),
                                },
                                onWebViewCreated: (controller) async {
                                  // Delegate to mixin for business logic
                                  _webViewController = controller;
                                  await onWebViewCreated(
                                    controller: controller,
                                    onDownload: (
                                        {required String name,
                                        required String url,
                                        String? base64Str}) async {
                                      final downloadProvider =
                                          Provider.of<DownloadProvider>(context,
                                              listen: false);
                                      await downloadProvider.startDownload(
                                        url: url,
                                        name: name,
                                        base64Str: base64Str,
                                      );
                                    },
                                    onControllerInitialized: (c) {},
                                    cookieManager: CookieManager.instance(),
                                    authRepository: _authRepository,
                                  );
                                },
                                onScrollChanged: (controller, x, y) async {
                                  // Use mixin method with state tracking
                                  super.onScrollChanged(y: y);
                                },
                                onLoadStart: (controller, url) async {
                                  // Delegate to mixin
                                  super.onLoadStart(
                                    controller: controller,
                                    url: url,
                                    isOpenDialog: _isOpenDialog,
                                    dialogContext: _dialogContext,
                                    onUpdate: () {
                                      setState(() {
                                        _noInternet = false;
                                        _showErrorPage = false;
                                        _slowInternetPage = false;
                                        _currentUrl = url.toString();
                                      });
                                    },
                                  );
                                },
                                onLoadStop: (controller, url) async {
                                  // Delegate to mixin
                                  await super.onLoadStop(
                                    controller: controller,
                                    url: url,
                                    webViewController: _webViewController,
                                    pullToRefreshController:
                                        _pullToRefreshController,
                                    onUpdate: () {
                                      setState(() {
                                        _currentUrl = url.toString();
                                        if (!_noInternet && _showNoInternet) {
                                          _showNoInternet = false;
                                        }
                                      });
                                    },
                                  );
                                },
                                onReceivedError: (
                                  controller,
                                  request,
                                  error,
                                ) async {
                                  await onReceivedError(
                                    controller: controller,
                                    request: request,
                                    error: error,
                                    pullToRefreshController:
                                        _pullToRefreshController,
                                    webViewController: _webViewController,
                                    onShowError: (error) {
                                      final downloadProvider =
                                          Provider.of<DownloadProvider>(context,
                                              listen: false);
                                      downloadProvider.showError(error);
                                    },
                                    onUpdateState: ({
                                      progress,
                                      showNoInternet,
                                      noInternet,
                                    }) {
                                      setState(() {
                                        if (progress != null) {
                                          _progress = progress;
                                        }
                                        if (showNoInternet != null) {
                                          _showNoInternet = showNoInternet;
                                        }
                                        if (noInternet != null) {
                                          _noInternet = noInternet;
                                        }
                                      });
                                    },
                                  );
                                },
                                onReceivedHttpError:
                                    (controller, url, statusCode) {
                                  _pullToRefreshController.endRefreshing();
                                  print("onReceivedHttpError $statusCode");
                                  // setState(() {
                                  //   showErrorPage = true;
                                  //   isLoading = false;
                                  // });
                                },
                                onReceivedServerTrustAuthRequest:
                                    (controller, challenge) async {
                                  return ServerTrustAuthResponse(
                                      action: ServerTrustAuthResponseAction
                                          .PROCEED);
                                },
                                onGeolocationPermissionsShowPrompt:
                                    (controller, origin) async {
                                  await Permission.location.request();
                                  return Future.value(
                                      GeolocationPermissionShowPromptResponse(
                                          origin: origin,
                                          allow: true,
                                          retain: true));
                                },
                                onPermissionRequest:
                                    (controller, request) async {
                                  return PermissionResponse(
                                      resources: request.resources,
                                      action: PermissionResponseAction.GRANT);
                                },
                                onProgressChanged: (controller, progress) {
                                  if (progress == 100) {
                                    _pullToRefreshController.endRefreshing();
                                  }
                                  setState(() {
                                    _progress = progress / 100;
                                  });
                                  // Notify loading provider
                                  // The provider will handle preventing progress from going below 1.0
                                  // after initial load completes
                                  Provider.of<WebViewProvider>(context,
                                          listen: false)
                                      .setProgress(progress / 100);

                                  // Trigger splash visibility update in MainScreen
                                  // This will be handled by Consumer's addPostFrameCallback
                                },
                                shouldOverrideUrlLoading:
                                    (controller, navigationAction) async {
                                  return super.getNavigationPolicy(
                                      navigationAction.request.url,
                                      _webViewHelper);
                                },
                                onCreateWindow:
                                    (controller, createWindowRequest) async {
                                  return super.onCreateWindow(
                                    createWindowRequest: createWindowRequest,
                                    webviewWindow: _webviewWindow,
                                    isOpenDialog: _isOpenDialog,
                                    isNewWindowLoading: _isDialogLoading,
                                    allowClosePopUp: _allowClosePopUp,
                                    dialogContext: _dialogContext,
                                    url: _currentUrl,
                                    options: _options,
                                    setIsOpenDialog: (value) =>
                                        setState(() => _isOpenDialog = value),
                                    setIsNewWindowLoading: (value) => setState(
                                        () => _isDialogLoading = value),
                                    setAllowClosePopUp: (value) => setState(
                                        () => _allowClosePopUp = value),
                                  );
                                },
                                onDownloadStartRequest:
                                    (controller, downloadStartRequest) async {
                                  await super.onDownloadStartRequest(
                                    request: downloadStartRequest,
                                    onUpdateState: ({isLoading, progress}) {
                                      setState(() {
                                        if (progress != null) {
                                          _progress = progress;
                                        }
                                      });
                                    },
                                  );
                                },
                                onUpdateVisitedHistory:
                                    (controller, url, androidIsReload) async {
                                  onUpdateVisitedHistory(
                                      url: url,
                                      onUpdateUrl: (newUrl) {
                                        setState(() {
                                          _currentUrl = newUrl;
                                        });
                                      });
                                },
                                onConsoleMessage: (controller, message) {
                                  super.onConsoleMessage(message);
                                },
                              )
                            : Center(
                                child: Text(
                                'Url is not valid',
                                style: Theme.of(context).textTheme.bodyLarge,
                              )),
                        _showNoInternet
                            ? Center(
                                child: NoInternetWidget(reload: () async {
                                  if (Platform.isAndroid) {
                                    _webViewController?.reload();
                                  } else if (Platform.isIOS) {
                                    _webViewController?.loadUrl(
                                        urlRequest: URLRequest(
                                            url: WebUri.uri(
                                                Uri.parse(_currentUrl))));
                                  }
                                }),
                              )
                            : const SizedBox(height: 0, width: 0),
                        _showErrorPage
                            ? Center(
                                child: NotFound(
                                    webViewController: _webViewController!,
                                    url: _currentUrl,
                                    title1: '페이지를 찾을 수 없습니다',
                                    title2:
                                        '페이지를 찾을 수 없습니다. 다시 시도하거나 인터넷 연결을 확인해 주세요'))
                            : const SizedBox(height: 0, width: 0),
                        _slowInternetPage
                            ? Center(
                                child: NotFound(
                                    webViewController: _webViewController!,
                                    url: _currentUrl,
                                    title1: '잘못된 URL',
                                    title2: '잘못된 URL입니다. 다시 시도해 주세요'))
                            : const SizedBox(height: 0, width: 0),
                        // Loading overlay circle
                        _progress < 1.0 && _isValidURL
                            ? LoadingOverlay(
                                progress: _progress,
                              )
                            : const SizedBox.shrink(),

                        // DevToolButton()
                      ],
                    ),
                  )),
            )
          ],
        ));
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:osaka_app/constants/javascript.dart';
import 'package:osaka_app/l10n/generated/app_localizations.dart';
import 'package:osaka_app/models/vjw_helper_values.dart';
import 'package:osaka_app/widgets/vjw/vjw_value_chip_bar.dart';
import 'package:osaka_app/widgets/webview/no_internet_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class VjwWebViewScreen extends StatefulWidget {
  const VjwWebViewScreen({required this.values, super.key});
  final VjwHelperValues values;
  @override
  State<VjwWebViewScreen> createState() => _VjwWebViewScreenState();
}

class _VjwWebViewScreenState extends State<VjwWebViewScreen> {
  static const _officialVjwUrl = 'https://www.vjw.digital.go.jp/';
  InAppWebViewController? _controller;
  bool _loading = true;
  bool _showError = false;
  bool _isAllowedInWebView(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'digital.go.jp' ||
        host.endsWith('.digital.go.jp') ||
        host == 'hcaptcha.com' ||
        host.endsWith('.hcaptcha.com') ||
        host == 'recaptcha.net' ||
        host.endsWith('.recaptcha.net') ||
        host == 'gstatic.com' ||
        host.endsWith('.gstatic.com');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Scaffold(
        resizeToAvoidBottomInset: true,
        extendBodyBehindAppBar: false,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            flexibleSpace: ClipRect(
                child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                  decoration: const BoxDecoration(
                      color: Color.fromRGBO(244, 239, 230, 0.78),
                      border: Border(
                          bottom: BorderSide(
                              color: Color.fromRGBO(23, 35, 31, 0.08),
                              width: 1)))),
            )),
            title: Text(s.vjwPrepareTitle),
            leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop()),
            actions: [
              IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _controller?.reload()),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(s.vjwEdit))
            ]),
        body: Column(children: [
          Expanded(
            child: Stack(children: [
              InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_officialVjwUrl)),
                  initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      useShouldOverrideUrlLoading: true,
                      thirdPartyCookiesEnabled: false),
                  onWebViewCreated: (controller) => _controller = controller,
                  onLoadStart: (_, __) => setState(() {
                        _loading = true;
                        _showError = false;
                      }),
                  onLoadStop: (controller, _) async {
                    setState(() => _loading = false);
                    await controller.evaluateJavascript(
                        source: installVjwFocusTracker);
                  },
                  onReceivedError: (_, request, ___) {
                    if (request.isForMainFrame != true) return;
                    setState(() {
                      _loading = false;
                      _showError = true;
                    });
                  },
                  onReceivedHttpError: (_, request, ___) {
                    if (request.isForMainFrame != true) return;
                    setState(() {
                      _loading = false;
                      _showError = true;
                    });
                  },
                  shouldOverrideUrlLoading: (_, action) async {
                    final uri = action.request.url?.uriValue;
                    // Captcha widgets navigate inside iframes. Never send
                    // subframe navigations to the external browser.
                    if (action.isForMainFrame != true ||
                        uri == null ||
                        _isAllowedInWebView(uri)) {
                      return NavigationActionPolicy.ALLOW;
                    }
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                    return NavigationActionPolicy.CANCEL;
                  }),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (_showError)
                Positioned.fill(
                  child: NoInternetWidget(reload: () {
                    setState(() => _showError = false);
                    _controller?.reload();
                  }),
                ),
            ]),
          ),
          VjwValueChipBar(values: widget.values, controller: _controller),
        ]));
  }
}

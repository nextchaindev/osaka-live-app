import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:osaka_app/provider/webview_provider.dart';
import 'package:provider/provider.dart';

/// Restores a WebView after its native content/renderer process is terminated
/// while the app is in the background.
mixin WebViewRendererRecoveryMixin<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  bool _webContentWasTerminated = false;
  bool _isReloadingTerminatedContent = false;

  InAppWebViewController? get webViewControllerForRecovery;
  void recreateWebViewForRecovery();

  void initWebViewRendererRecovery() {
    WidgetsBinding.instance.addObserver(this);
  }

  void disposeWebViewRendererRecovery() {
    WidgetsBinding.instance.removeObserver(this);
  }

  void onWebViewContentProcessDidTerminate(InAppWebViewController controller) {
    debugPrint('[OsakaLive][webview] content process terminated');
    _webContentWasTerminated = true;
    _startRecovery();

    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _reloadTerminatedContentIfNeeded();
    }
  }

  void onWebViewRenderProcessGone({
    required RenderProcessGoneDetail detail,
  }) {
    debugPrint('[OsakaLive][webview] renderer process gone: $detail');
    _webContentWasTerminated = false;
    _startRecovery();
    recreateWebViewForRecovery();
  }

  void onWebViewRecoveryLoadComplete() {
    _webContentWasTerminated = false;
    context.read<WebViewProvider>().setWebContentRecovery(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadTerminatedContentIfNeeded();
    }
  }

  void _startRecovery() {
    final provider = context.read<WebViewProvider>();
    provider.setWebViewReady(false);
    provider.setWebContentRecovery(true);
  }

  Future<void> _reloadTerminatedContentIfNeeded() async {
    if (!mounted ||
        !_webContentWasTerminated ||
        _isReloadingTerminatedContent) {
      return;
    }

    final controller = webViewControllerForRecovery;
    if (controller == null) return;

    _isReloadingTerminatedContent = true;
    try {
      await controller.reload();
      debugPrint('[OsakaLive][webview] reloaded terminated content process');
    } catch (error) {
      debugPrint('[OsakaLive][webview] reload after termination failed: $error');
      recreateWebViewForRecovery();
    } finally {
      _isReloadingTerminatedContent = false;
    }
  }
}

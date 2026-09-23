import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:osaka_app/config/env_config.dart';
import 'package:osaka_app/constants/javascript.dart';
import 'package:osaka_app/helpers/webview_helper.dart';

/// Unified WebView provider that manages controller, loading state, and URL
///
/// This provider combines functionality from:
/// - WebViewControllerProvider: Controller management and navigation
/// - WebViewLoadingProvider: Loading state and progress tracking
/// - WebviewURLProvider: Current URL tracking
class WebViewProvider extends ChangeNotifier {
  // ==================== Controller State ====================
  InAppWebViewController? _controller;
  Uri? _pendingDeepLink;
  Timer? _livePositionThrottleTimer;
  Map<String, dynamic>? _latestLivePositionPayload;
  Map<String, dynamic>? _pendingLivePositionPayload;
  String? _lastLivePositionJson;
  DateTime? _lastLivePositionSentAt;
  bool _isOpeningDeepLink = false;
  bool _isFlushingLivePosition = false;
  bool _isWebViewReady = false;
  bool _isDisposed = false;
  bool _chatKeyboardOverlayEnabled = false;
  double _latestKeyboardHeight = 0;
  double? _lastSentKeyboardHeight;
  bool _isSendingKeyboardHeight = false;
  Map<String, dynamic>? _latestLocationPermissionPayload;

  static const Duration _livePositionThrottleDuration =
      Duration(milliseconds: 500);

  InAppWebViewController? get controller => _controller;
  bool get chatKeyboardOverlayEnabled => _chatKeyboardOverlayEnabled;

  void setChatKeyboardOverlayEnabled(bool enabled) {
    if (_chatKeyboardOverlayEnabled == enabled) return;
    _chatKeyboardOverlayEnabled = enabled;
    notifyListeners();
  }

  void setPendingDeepLink(Uri? uri) {
    _pendingDeepLink = uri;
    unawaited(_flushPendingDeepLink());
  }

  void setController(InAppWebViewController? controller) {
    if (!identical(_controller, controller)) {
      _chatKeyboardOverlayEnabled = false;
      _lastSentKeyboardHeight = null;
    }
    _controller = controller;
    notifyListeners();
    unawaited(_flushPendingDeepLink());
    _queueLatestLivePosition();
  }

  void clearControllerIfCurrent(InAppWebViewController controller) {
    if (_isDisposed || !identical(_controller, controller)) return;
    _controller = null;
    _isWebViewReady = false;
    _chatKeyboardOverlayEnabled = false;
    notifyListeners();
  }

  void setWebViewReady(bool isReady) {
    _isWebViewReady = isReady;
    if (_isWebViewReady) {
      unawaited(_flushPendingDeepLink());
      _queueLatestLivePosition();
      _sendLatestLocationPermission();
      _sendLatestKeyboardHeight();
    } else {
      setChatKeyboardOverlayEnabled(false);
      _lastSentKeyboardHeight = null;
      _lastLivePositionJson = null;
      _lastLivePositionSentAt = null;
    }
  }

  Future<void> openDeepLink(Uri uri) async {
    _pendingDeepLink = uri;
    await _flushPendingDeepLink();
  }

  Future<void> _flushPendingDeepLink() async {
    final controller = _controller;
    final target = _pendingDeepLink;
    if (_isOpeningDeepLink ||
        !_isWebViewReady ||
        controller == null ||
        target == null) {
      return;
    }

    if (!WebViewHelper.isTrustedWebUri(
      target,
      rootUrl: EnvConfig.instance.webviewUrl,
    )) {
      debugPrint('[OsakaLive][notification] rejected untrusted link: $target');
      _pendingDeepLink = null;
      return;
    }

    _isOpeningDeepLink = true;
    try {
      debugPrint('[OsakaLive][notification] loading pending link: $target');
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri.uri(target)),
      );
      if (_pendingDeepLink == target) {
        _pendingDeepLink = null;
      }
    } catch (error) {
      debugPrint(
        '[OsakaLive][notification] failed to open pending link $target: $error',
      );
    } finally {
      _isOpeningDeepLink = false;
      if (_pendingDeepLink != null && _isWebViewReady) {
        unawaited(_flushPendingDeepLink());
      }
    }
  }

  void handleLivePositionChanged({
    required double lat,
    required double lng,
    double? accuracy,
    int? updatedAt,
  }) {
    final payload = {
      'lat': lat,
      'lng': lng,
      if (accuracy != null) 'accuracy': accuracy,
      'updatedAt': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    };

    _latestLivePositionPayload = payload;
    _pendingLivePositionPayload = payload;
    _scheduleLivePositionFlush();
  }

  void _queueLatestLivePosition() {
    final latestPayload = _latestLivePositionPayload;
    if (latestPayload == null) {
      return;
    }

    _pendingLivePositionPayload = latestPayload;
    _scheduleLivePositionFlush();
  }

  void _scheduleLivePositionFlush() {
    if (!_isWebViewReady) {
      debugPrint(
        '[OsakaLive][location][flutter] waiting to send position: WebView is not ready',
      );
      return;
    }

    if (_controller == null) {
      debugPrint(
        '[OsakaLive][location][flutter] waiting to send position: WebView controller is null',
      );
      return;
    }

    final lastSentAt = _lastLivePositionSentAt;
    if (lastSentAt == null) {
      _flushLivePositionIfNeeded();
      return;
    }

    final elapsed = DateTime.now().difference(lastSentAt);
    if (elapsed >= _livePositionThrottleDuration) {
      _livePositionThrottleTimer?.cancel();
      _livePositionThrottleTimer = null;
      _flushLivePositionIfNeeded();
      return;
    }

    _livePositionThrottleTimer ??= Timer(
      _livePositionThrottleDuration - elapsed,
      () {
        _livePositionThrottleTimer = null;
        _flushLivePositionIfNeeded();
      },
    );
  }

  Future<void> _flushLivePositionIfNeeded() async {
    if (_isFlushingLivePosition) {
      return;
    }

    final controller = _controller;
    final payload = _pendingLivePositionPayload;

    if (!_isWebViewReady) {
      debugPrint(
        '[OsakaLive][location][flutter] skipped send: WebView is not ready',
      );
      return;
    }

    if (controller == null) {
      debugPrint(
        '[OsakaLive][location][flutter] skipped send: WebView controller is null',
      );
      return;
    }

    if (payload == null) {
      return;
    }

    final payloadJson = jsonEncode(payload);
    if (_lastLivePositionJson == payloadJson) {
      _pendingLivePositionPayload = null;
      return;
    }

    _lastLivePositionJson = payloadJson;
    _pendingLivePositionPayload = null;
    _isFlushingLivePosition = true;
    try {
      debugPrint(
        '[OsakaLive][location][flutter] sending to WebView $payloadJson',
      );
      await controller.evaluateJavascript(
        source: pushLivePosition(
          lat: (payload['lat'] as num).toDouble(),
          lng: (payload['lng'] as num).toDouble(),
          accuracy: (payload['accuracy'] as num?)?.toDouble(),
          updatedAt: (payload['updatedAt'] as num?)?.toInt(),
        ),
      );
      _lastLivePositionSentAt = DateTime.now();
    } finally {
      _isFlushingLivePosition = false;
      if (_pendingLivePositionPayload != null) {
        _scheduleLivePositionFlush();
      }
    }
  }

  Future<void> sendLocationPermissionStatus({
    required String status,
    required bool serviceEnabled,
    int? updatedAt,
  }) async {
    final payload = {
      'status': status,
      'serviceEnabled': serviceEnabled,
      'updatedAt': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    };

    _latestLocationPermissionPayload = payload;
    await _sendLatestLocationPermission();
  }

  Future<void> _sendLatestLocationPermission() async {
    final controller = _controller;
    final payload = _latestLocationPermissionPayload;

    if (!_isWebViewReady || controller == null || payload == null) {
      return;
    }

    debugPrint(
      '[OsakaLive][location][flutter] sending permission to WebView ${jsonEncode(payload)}',
    );
    await controller.evaluateJavascript(
      source: pushLocationPermission(
        status: payload['status'] as String,
        serviceEnabled: payload['serviceEnabled'] as bool,
        updatedAt: (payload['updatedAt'] as num?)?.toInt(),
      ),
    );
  }

  /// Sends the system keyboard height in Flutter logical pixels to the WebView.
  Future<void> sendKeyboardHeight(double keyboardHeight) async {
    if (_latestKeyboardHeight == keyboardHeight) {
      return;
    }
    _latestKeyboardHeight = keyboardHeight;
    await _sendLatestKeyboardHeight();
  }

  Future<void> _sendLatestKeyboardHeight() async {
    if (_isSendingKeyboardHeight || !_isWebViewReady || _controller == null) {
      return;
    }

    _isSendingKeyboardHeight = true;
    try {
      while (_isWebViewReady && _controller != null) {
        final keyboardHeight = _latestKeyboardHeight;
        if (_lastSentKeyboardHeight == keyboardHeight) {
          return;
        }

        await _controller!.evaluateJavascript(
          source: pushKeyboardHeight(keyboardHeight: keyboardHeight),
        );
        _lastSentKeyboardHeight = keyboardHeight;
      }
    } finally {
      _isSendingKeyboardHeight = false;
      if (_isWebViewReady &&
          _controller != null &&
          _lastSentKeyboardHeight != _latestKeyboardHeight) {
        unawaited(_sendLatestKeyboardHeight());
      }
    }
  }

  Future<void> sendCameraResult({
    required String status,
    String? filePath,
    int? durationMs,
    String? cameraFacing,
    String? mediaType,
    String? errorMessage,
  }) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    await controller.evaluateJavascript(
      source: pushCameraResult(
        status: status,
        filePath: filePath,
        durationMs: durationMs,
        cameraFacing: cameraFacing,
        mediaType: mediaType,
        errorMessage: errorMessage,
      ),
    );
  }

  Future<void> sendCameraFileTransfer({
    required String transferId,
    required String fileName,
    required String mimeType,
    required List<String> base64Chunks,
    required int sizeBytes,
    int? durationMs,
    String? cameraFacing,
  }) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    await controller.evaluateJavascript(
      source: pushCameraFileStart(
        transferId: transferId,
        fileName: fileName,
        mimeType: mimeType,
        totalChunks: base64Chunks.length,
        sizeBytes: sizeBytes,
        durationMs: durationMs,
        cameraFacing: cameraFacing,
      ),
    );

    for (var i = 0; i < base64Chunks.length; i++) {
      await controller.evaluateJavascript(
        source: pushCameraFileChunk(
          transferId: transferId,
          chunkIndex: i,
          totalChunks: base64Chunks.length,
          chunk: base64Chunks[i],
        ),
      );
    }

    await controller.evaluateJavascript(
      source: pushCameraFileComplete(
        transferId: transferId,
        fileName: fileName,
        mimeType: mimeType,
        totalChunks: base64Chunks.length,
        sizeBytes: sizeBytes,
        durationMs: durationMs,
        cameraFacing: cameraFacing,
      ),
    );
  }

  // ==================== Loading State ====================
  double _progress = 0.0;
  bool _hasInitialLoadCompleted = false;
  double get progress => _progress;
  bool get hasInitialLoadCompleted => _hasInitialLoadCompleted;

  // ==================== Safe Area State ====================
  double _safeAreaTop = 0.0;
  double get safeAreaTop => _safeAreaTop;
  double _safeAreaBottom = 0.0;
  double get safeAreaBottom => _safeAreaBottom;

  void setSafeAreaTop(double value) {
    if (_safeAreaTop != value) {
      _safeAreaTop = value;
      notifyListeners();
    }
  }

  void setSafeAreaBottom(double value) {
    if (_safeAreaBottom != value) {
      _safeAreaBottom = value;
      notifyListeners();
    }
  }

  void setProgress(double progress) {
    // After initial load completes, don't allow progress to go below 1.0
    // This prevents splash screen from showing again on subsequent navigations
    if (_hasInitialLoadCompleted && progress < 1.0) {
      return; // Don't update progress if it would go below 1.0 after initial load
    }
    if (_progress != progress) {
      _progress = progress;
      // Mark initial load as completed when progress reaches 1.0
      if (progress >= 1.0 && !_hasInitialLoadCompleted) {
        _hasInitialLoadCompleted = true;
      }
      notifyListeners();
    }
  }

  void resetLoading() {
    _progress = 0.0;
    _hasInitialLoadCompleted = false;
    notifyListeners();
  }

  // ==================== URL State ====================
  String _currentUrl = "";

  String get currentUrl => _currentUrl;

  void setCurrentUrl(String url) {
    if (_currentUrl != url) {
      _currentUrl = url;
      // A new SPA route must opt in again; the old chat composer may be gone.
      _chatKeyboardOverlayEnabled = false;
      notifyListeners();
    }
  }

  // ==================== Reset All ====================
  /// Reset all WebView state (useful when navigating away or restarting)
  void resetAll() {
    _livePositionThrottleTimer?.cancel();
    _livePositionThrottleTimer = null;
    _latestLivePositionPayload = null;
    _pendingLivePositionPayload = null;
    _lastLivePositionJson = null;
    _lastLivePositionSentAt = null;
    _isFlushingLivePosition = false;
    _latestLocationPermissionPayload = null;
    _latestKeyboardHeight = 0;
    _lastSentKeyboardHeight = null;
    _isSendingKeyboardHeight = false;
    _isWebViewReady = false;
    _controller = null;
    _progress = 0.0;
    _hasInitialLoadCompleted = false;
    _currentUrl = "";
    _chatKeyboardOverlayEnabled = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _livePositionThrottleTimer?.cancel();
    super.dispose();
  }
}

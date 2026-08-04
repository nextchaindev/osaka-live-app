import 'dart:convert';

const listenRouterChange = """
        // Listen for pushState and replaceState events in SPA, guard to avoid duplicate observers.
        (function() {
          if (window.__flutterRouteObserverInstalled) {
            return;
          }
          window.__flutterRouteObserverInstalled = true;

          let lastUrl = location.href;
          new MutationObserver(() => {
            const currentUrl = location.href;
            if (currentUrl !== lastUrl) {
              lastUrl = currentUrl;
              window.flutter_inappwebview.callHandler('onRouteChanged', currentUrl);
            }
          }).observe(document, { subtree: true, childList: true });
        })();
      """;

const unmuteAutoplayVideos = """
        (function() {
          try {
            if (window.__osakaLiveUnmuteVideosInstalled) {
              window.__osakaLiveUnmuteVideos();
              return;
            }

            window.__osakaLiveUnmuteVideosInstalled = true;
            window.__osakaLiveUnmuteVideos = function() {
              var videos = document.querySelectorAll('video');
              videos.forEach(function(video) {
                video.muted = false;
                video.defaultMuted = false;
                video.volume = 1;
                video.setAttribute('playsinline', '');
                video.setAttribute('webkit-playsinline', '');

                if (!video.__osakaLivePauseListenerInstalled) {
                  video.__osakaLivePauseListenerInstalled = true;
                  video.__osakaLiveUserPaused = false;
                  video.addEventListener('pause', function() {
                    video.__osakaLiveUserPaused = true;
                  });
                  video.addEventListener('play', function() {
                    video.__osakaLiveUserPaused = false;
                  });
                }

                if (!video.__osakaLiveAutoplayAttempted && !video.__osakaLiveUserPaused) {
                  video.__osakaLiveAutoplayAttempted = true;
                  var playPromise = video.play && video.play();
                  if (playPromise && playPromise.catch) {
                    playPromise.catch(function() {});
                  }
                }
              });
            };

            window.__osakaLiveUnmuteVideos();

            var observer = new MutationObserver(function() {
              window.__osakaLiveUnmuteVideos();
            });
            observer.observe(document.documentElement, {
              childList: true,
              subtree: true,
              attributes: true,
              attributeFilter: ['muted', 'autoplay']
            });

            var attempts = 0;
            var interval = setInterval(function() {
              window.__osakaLiveUnmuteVideos();
              attempts += 1;
              if (attempts >= 10) {
                clearInterval(interval);
              }
            }, 500);
          } catch (e) {
          }
        })();
      """;

String pushLivePosition({
  required double lat,
  required double lng,
  double? accuracy,
  int? updatedAt,
}) {
  final payload = <String, dynamic>{
    'lat': lat,
    'lng': lng,
    if (accuracy != null) 'accuracy': accuracy,
    'updatedAt': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
  };

  return """
        (function() {
          try {
            var payload = ${jsonEncode(payload)};
            window.__osakaLivePositionLast = payload;
            if (typeof window.__osakaLivePosition === 'function') {
              window.__osakaLivePosition(payload);
            } else {
              window.dispatchEvent(new CustomEvent('osaka-live-position', { detail: payload }));
            }
      } catch (e) {
      }
    })();
  """;
}

String pushLocationPermission({
  required String status,
  required bool serviceEnabled,
  int? updatedAt,
}) {
  final payload = <String, dynamic>{
    'status': status,
    'serviceEnabled': serviceEnabled,
    'updatedAt': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
  };

  return """
        (function() {
          try {
            var payload = ${jsonEncode(payload)};
            window.__osakaLiveLocationPermissionLast = payload;
            window.dispatchEvent(new CustomEvent('osaka-live-location-permission', { detail: payload }));
      } catch (e) {
      }
    })();
  """;
}

String pushCameraResult({
  required String status,
  String? filePath,
  int? durationMs,
  String? cameraFacing,
  String? mediaType,
  String? errorMessage,
  int? capturedAt,
}) {
  final payload = <String, dynamic>{
    'status': status,
    if (filePath != null) 'filePath': filePath,
    if (durationMs != null) 'durationMs': durationMs,
    if (cameraFacing != null) 'cameraFacing': cameraFacing,
    if (mediaType != null) 'mediaType': mediaType,
    if (errorMessage != null) 'errorMessage': errorMessage,
    'capturedAt': capturedAt ?? DateTime.now().millisecondsSinceEpoch,
  };

  return """
        (function() {
          try {
            var payload = ${jsonEncode(payload)};
            window.__osakaLiveCameraResultLast = payload;
            window.dispatchEvent(new CustomEvent('osaka-live-camera-result', { detail: payload }));
      } catch (e) {
      }
    })();
  """;
}

String pushSocialLoginResult({
  required String status,
  required String provider,
  required String requestId,
  String? idToken,
  String? errorCode,
}) {
  final payload = <String, dynamic>{
    'status': status,
    'provider': provider,
    'requestId': requestId,
    if (idToken != null) 'idToken': idToken,
    if (errorCode != null) 'errorCode': errorCode,
  };

  return _dispatchCustomEvent('osaka-live-social-login-result', payload);
}

String pushCameraFileStart({
  required String transferId,
  required String fileName,
  required String mimeType,
  required int totalChunks,
  required int sizeBytes,
  int? durationMs,
  String? cameraFacing,
}) {
  final payload = <String, dynamic>{
    'transferId': transferId,
    'fileName': fileName,
    'mimeType': mimeType,
    'totalChunks': totalChunks,
    'sizeBytes': sizeBytes,
    if (durationMs != null) 'durationMs': durationMs,
    if (cameraFacing != null) 'cameraFacing': cameraFacing,
    'startedAt': DateTime.now().millisecondsSinceEpoch,
  };

  return _dispatchCustomEvent('osaka-live-camera-file-start', payload);
}

String pushCameraFileChunk({
  required String transferId,
  required int chunkIndex,
  required int totalChunks,
  required String chunk,
}) {
  final payload = <String, dynamic>{
    'transferId': transferId,
    'chunkIndex': chunkIndex,
    'totalChunks': totalChunks,
    'chunk': chunk,
  };

  return _dispatchCustomEvent('osaka-live-camera-file-chunk', payload);
}

String pushCameraFileComplete({
  required String transferId,
  required String fileName,
  required String mimeType,
  required int totalChunks,
  required int sizeBytes,
  int? durationMs,
  String? cameraFacing,
}) {
  final payload = <String, dynamic>{
    'transferId': transferId,
    'fileName': fileName,
    'mimeType': mimeType,
    'totalChunks': totalChunks,
    'sizeBytes': sizeBytes,
    if (durationMs != null) 'durationMs': durationMs,
    if (cameraFacing != null) 'cameraFacing': cameraFacing,
    'completedAt': DateTime.now().millisecondsSinceEpoch,
  };

  return _dispatchCustomEvent('osaka-live-camera-file-complete', payload);
}

String _dispatchCustomEvent(String eventName, Map<String, dynamic> payload) {
  return """
        (function() {
          try {
            var payload = ${jsonEncode(payload)};
            window.dispatchEvent(new CustomEvent('$eventName', { detail: payload }));
          } catch (e) {
          }
        })();
      """;
}

String navigate(String path) {
  return """
        (function() {
          try{
              webviewNavigate('$path');
          } catch(e){
              window.location.href = '$path';
          }
        })();
      """;
}

String setContacts(String payload) {
  return """
        (function() {
          setContacts('$payload');
        })();
      """;
}

String handleException(String message) {
  return """
        (function() {
          handleException('$message');
        })();
      """;
}

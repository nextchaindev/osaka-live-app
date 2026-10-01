import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let webViewScrollLock = WebViewScrollLock()
  private var webViewScrollLockChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.osaka.app/webview_scroll_lock",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setWebViewScrollLocked" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let locked = arguments["locked"] as? Bool
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Expected a boolean locked argument",
            details: nil
          )
        )
        return
      }

      DispatchQueue.main.async {
        guard let self else {
          result(
            FlutterError(
              code: "unavailable",
              message: "App delegate is unavailable",
              details: nil
            )
          )
          return
        }

        let lockedWebViewCount =
          self.webViewScrollLock.setLocked(locked)
        print(
          "[OsakaLive][webview][scroll-lock] locked: \(locked), views: \(lockedWebViewCount)"
        )
        result(lockedWebViewCount)
      }
    }
    webViewScrollLockChannel = channel
  }
}

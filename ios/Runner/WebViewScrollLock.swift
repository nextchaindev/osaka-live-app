import UIKit
import WebKit

private final class LockedWebViewScrollState {
  weak var webView: WKWebView?
  let lockedOffsetY: CGFloat
  let previousBounces: Bool
  var isRestoringOffset = false
  var offsetObservation: NSKeyValueObservation?

  init(webView: WKWebView) {
    self.webView = webView
    lockedOffsetY = webView.scrollView.contentOffset.y
    previousBounces = webView.scrollView.bounces
  }

  func lock() {
    guard let scrollView = webView?.scrollView else { return }

    scrollView.bounces = false
    offsetObservation = scrollView.observe(\.contentOffset, options: [.new]) {
      [weak self] scrollView, _ in
      guard let self, !self.isRestoringOffset else { return }
      guard abs(scrollView.contentOffset.y - self.lockedOffsetY) > 0.5 else {
        return
      }

      self.isRestoringOffset = true
      scrollView.layer.removeAllAnimations()
      UIView.performWithoutAnimation {
        scrollView.contentOffset = CGPoint(
          x: scrollView.contentOffset.x,
          y: self.lockedOffsetY
        )
      }
      self.isRestoringOffset = false
    }
  }

  func unlock() {
    offsetObservation?.invalidate()
    offsetObservation = nil
    webView?.scrollView.bounces = previousBounces
  }

  deinit {
    offsetObservation?.invalidate()
  }
}

final class WebViewScrollLock {
  private var lockedWebViews: [ObjectIdentifier: LockedWebViewScrollState] = [:]

  func setLocked(_ locked: Bool) -> Int {
    if !locked {
      lockedWebViews.values.forEach { $0.unlock() }
      lockedWebViews.removeAll()
      return 0
    }

    removeReleasedWebViews()
    for webView in visibleWebViews() {
      let identifier = ObjectIdentifier(webView)
      guard lockedWebViews[identifier] == nil else { continue }

      let state = LockedWebViewScrollState(webView: webView)
      state.lock()
      lockedWebViews[identifier] = state
    }

    return lockedWebViews.count
  }

  private func removeReleasedWebViews() {
    lockedWebViews = lockedWebViews.filter { _, state in
      state.webView != nil
    }
  }

  private func visibleWebViews() -> [WKWebView] {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .filter { !$0.isHidden && $0.alpha > 0 }
      .flatMap { webViews(in: $0) }
      .filter { $0.window != nil && !$0.isHidden && $0.alpha > 0 }
  }

  private func webViews(in view: UIView) -> [WKWebView] {
    var result = view is WKWebView ? [view as! WKWebView] : []
    for subview in view.subviews {
      result.append(contentsOf: webViews(in: subview))
    }
    return result
  }
}

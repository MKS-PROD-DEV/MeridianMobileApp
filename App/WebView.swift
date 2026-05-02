import UIKit
import WebKit

extension MyViewController {
  func configureBridgeScripts(for webView: WKWebView) {
    if let jsPath = Bundle.main.path(forResource: "nativeAssetStore", ofType: "js"),
      let jscript = try? String(contentsOfFile: jsPath, encoding: .utf8) {
      let script = WKUserScript(
        source: jscript,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: false
      )
      webView.configuration.userContentController.addUserScript(script)
    } else {
      print(
        "nativeAssetStore.js not found in app bundle. Make sure it's included in Copy Bundle Resources / App target."
      )
    }

    let bridgeJS = """
      window.openOfflineScorm = function(assetId) {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.openScorm) {
          window.webkit.messageHandlers.openScorm.postMessage({ assetId: assetId });
        } else {
          console.log("openScorm handler not available");
        }
      };
      """

    let bridgeScript = WKUserScript(
      source: bridgeJS,
      injectionTime: .atDocumentStart,
      forMainFrameOnly: false
    )
    webView.configuration.userContentController.addUserScript(bridgeScript)
  }

  func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    guard message.name == "openScorm" else { return }

    if let body = message.body as? [String: Any],
      let assetId = body["assetId"] as? String {
      presentScormLessonList(assetId: assetId)
    } else if let assetId = message.body as? String {
      presentScormLessonList(assetId: assetId)
    } else {
      print("openScorm: invalid message body:", message.body)
    }
  }

  func webView(
    _ webView: WKWebView,
    createWebViewWith configuration: WKWebViewConfiguration,
    for navigationAction: WKNavigationAction,
    windowFeatures: WKWindowFeatures
  ) -> WKWebView? {
    let popupWebView = NoInputAccessoryWebView(frame: .zero, configuration: configuration)
    let popupVC = PopupWebViewController(popupWebView: popupWebView)

    let nav = UINavigationController(rootViewController: popupVC)
    nav.modalPresentationStyle = .pageSheet
    present(nav, animated: true)

    if let url = navigationAction.request.url {
      popupWebView.load(URLRequest(url: url))
    }

    return popupWebView
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    guard webView == self.webView else { return }

    if isWaitingForInitialSiteLoad {
      isWaitingForInitialSiteLoad = false
      didShowInitialWebContent = true
      completeStartupOverlayDismissalIfNeeded()
    }
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    guard webView == self.webView else { return }

    if isWaitingForInitialSiteLoad {
      isWaitingForInitialSiteLoad = false
      completeStartupOverlayDismissalIfNeeded()
    }
  }

  func webView(
    _ webView: WKWebView,
    didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    guard webView == self.webView else { return }

    if isWaitingForInitialSiteLoad {
      isWaitingForInitialSiteLoad = false
      completeStartupOverlayDismissalIfNeeded()
    }
  }

  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    decisionHandler(.allow)
  }
}

final class PopupWebViewController: UIViewController {
  private let popupWebView: WKWebView

  init(popupWebView: WKWebView) {
    self.popupWebView = popupWebView
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .systemBackground

    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close,
      target: self,
      action: #selector(close)
    )

    view.addSubview(popupWebView)
    popupWebView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      popupWebView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      popupWebView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      popupWebView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      popupWebView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    ])
  }

  @objc private func close() {
    dismiss(animated: true)
  }
}

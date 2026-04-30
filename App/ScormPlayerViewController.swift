import UIKit
import WebKit

final class ScormPlayerViewController: UIViewController, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate {
  private lazy var webView: WKWebView = {
    let config = WKWebViewConfiguration()
    config.preferences.javaScriptCanOpenWindowsAutomatically = true

    let ucc = WKUserContentController()
    let script = WKUserScript(
      source: injectedJS,
      injectionTime: .atDocumentStart,
      forMainFrameOnly: false
    )
    ucc.addUserScript(script)
    config.userContentController = ucc

    let wv = WKWebView(frame: .zero, configuration: config)
    wv.allowsBackForwardNavigationGestures = true
    return wv
  }()

  private let injectedJS: String
  private let launchFileURL: URL
  private let readAccessURL: URL
  private let assetId: String
  private let scoId: String

  private var storeKey: String { "scorm.cmi.\(assetId).\(scoId)" }

  init(assetId: String, scoId: String, launchFileURL: URL, readAccessURL: URL, injectedJS: String) {
    self.assetId = assetId
    self.scoId = scoId
    self.launchFileURL = launchFileURL
    self.readAccessURL = readAccessURL
    self.injectedJS = injectedJS
    super.init(nibName: nil, bundle: nil)
    self.title = "SCORM"
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close,
      target: self,
      action: #selector(close)
    )

    webView.uiDelegate = self
    webView.navigationDelegate = self
    webView.configuration.userContentController.add(self, name: "scormStore")

    view.addSubview(webView)
    webView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])

    webView.loadFileURL(launchFileURL, allowingReadAccessTo: readAccessURL)
  }

  @objc private func close() { dismiss(animated: true) }

  func webView(_ webView: WKWebView,
               createWebViewWith configuration: WKWebViewConfiguration,
               for navigationAction: WKNavigationAction,
               windowFeatures: WKWindowFeatures) -> WKWebView? {
    let popupWebView = WKWebView(frame: .zero, configuration: configuration)
    let popupVC = PopupWebViewController(popupWebView: popupWebView)

    let nav = UINavigationController(rootViewController: popupVC)
    nav.modalPresentationStyle = .pageSheet
    present(nav, animated: true)

    if let url = navigationAction.request.url {
      popupWebView.load(URLRequest(url: url))
    }

    return popupWebView
  }

  func webView(_ webView: WKWebView,
               decidePolicyFor navigationAction: WKNavigationAction,
               decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    decisionHandler(.allow)
  }

  func userContentController(_ userContentController: WKUserContentController,
                             didReceive message: WKScriptMessage) {
    guard message.name == "scormStore" else { return }
    guard let body = message.body as? [String: Any],
          let op = body["op"] as? String else { return }

    switch op {
    case "load":
      let json = UserDefaults.standard.string(forKey: storeKey) ?? "{}"
      let js = "window.__scormNativeStoreLoad && window.__scormNativeStoreLoad(\(json));"
      webView.evaluateJavaScript(js, completionHandler: nil)

    case "save":
      if let cmiObj = body["cmi"],
         let data = try? JSONSerialization.data(withJSONObject: cmiObj, options: []),
         let json = String(data: data, encoding: .utf8) {
        UserDefaults.standard.set(json, forKey: storeKey)
      }

    default:
      break
    }
  }
}

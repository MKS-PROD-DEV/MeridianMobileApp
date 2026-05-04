/*
  Native SCORM playback screen.
  - creating and hosting a dedicated `WKWebView`
  - injecting the SCORM API shim JavaScript
  - loading the selected lesson
  - handling JS/native messages for SCORM storage
  - serving SCORM files through a custom URL scheme
  - supporting popup content
  - showing save-state feedback during autosave
  - surfacing save/score-related playback errors to the user
  SCORM content is loaded using:
  scorm://localhost/...
*/
import UIKit
import UniformTypeIdentifiers
import WebKit

private final class ScormURLSchemeHandler: NSObject, WKURLSchemeHandler {
  private let rootDirectoryURL: URL

  init(rootDirectoryURL: URL) {
    self.rootDirectoryURL = rootDirectoryURL.standardizedFileURL
    super.init()
  }

  func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
    let requestURL = urlSchemeTask.request.url

    guard let requestURL else {
      urlSchemeTask.didFailWithError(
        NSError(
          domain: "ScormScheme",
          code: 400,
          userInfo: [NSLocalizedDescriptionKey: L10n.tr("scorm_player.error.missing_request_url")]
        )
      )
      return
    }

    do {
      let fileURL = try resolveFileURL(from: requestURL)

      guard FileManager.default.fileExists(atPath: fileURL.path) else {
        let response = HTTPURLResponse(
          url: requestURL,
          statusCode: 404,
          httpVersion: "HTTP/1.1",
          headerFields: ["Content-Type": "text/plain"]
        )!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(Data(L10n.tr("scorm_player.error.not_found").utf8))
        urlSchemeTask.didFinish()
        return
      }

      let data = try Data(contentsOf: fileURL)
      let mimeType = mimeTypeForFile(at: fileURL) ?? "application/octet-stream"

      let response = URLResponse(
        url: requestURL,
        mimeType: mimeType,
        expectedContentLength: data.count,
        textEncodingName: textEncodingName(for: mimeType)
      )

      urlSchemeTask.didReceive(response)
      urlSchemeTask.didReceive(data)
      urlSchemeTask.didFinish()
    } catch {
      urlSchemeTask.didFailWithError(error)
    }
  }

  func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
    // No-op
  }

  private func resolveFileURL(from url: URL) throws -> URL {
    let relativePath = url.path.removingPercentEncoding ?? url.path
    let trimmedPath = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath

    let resolvedURL = rootDirectoryURL.appendingPathComponent(trimmedPath).standardizedFileURL
    let rootPath = rootDirectoryURL.path
    let resolvedPath = resolvedURL.path

    guard resolvedPath.hasPrefix(rootPath) else {
      throw NSError(
        domain: "ScormScheme",
        code: 403,
        userInfo: [NSLocalizedDescriptionKey: L10n.tr("scorm_player.error.path_escapes_root")]
      )
    }

    return resolvedURL
  }

  private func mimeTypeForFile(at fileURL: URL) -> String? {
    let ext = fileURL.pathExtension
    guard !ext.isEmpty else { return nil }

    if let type = UTType(filenameExtension: ext),
      let mimeType = type.preferredMIMEType {
      return mimeType
    }

    switch ext.lowercased() {
    case "js":
      return "application/javascript"
    case "css":
      return "text/css"
    case "html", "htm":
      return "text/html"
    case "xml":
      return "text/xml"
    case "json":
      return "application/json"
    case "svg":
      return "image/svg+xml"
    default:
      return nil
    }
  }

  private func textEncodingName(for mimeType: String) -> String? {
    if mimeType.hasPrefix("text/")
      || mimeType == "application/javascript"
      || mimeType == "application/json" {
      return "utf-8"
    }
    return nil
  }
}

final class ScormPlayerViewController: UIViewController, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate {
  private let injectedJS: String
  private let launchFileURL: URL
  private let readAccessURL: URL
  private let assetId: String
  private let scoId: String
  private lazy var schemeHandler = ScormURLSchemeHandler(rootDirectoryURL: readAccessURL)

  private var saveStatusButton: UIButton?
  private var hideSaveStatusWorkItem: DispatchWorkItem?
  private var hasShownScoreWarning = false

  private lazy var webView: WKWebView = {
    let config = makeWebViewConfiguration()

    let webView = WKWebView(frame: .zero, configuration: config)
    webView.allowsBackForwardNavigationGestures = true
    webView.uiDelegate = self
    webView.navigationDelegate = self
    return webView
  }()

  init(
    assetId: String,
    scoId: String,
    launchFileURL: URL,
    readAccessURL: URL,
    injectedJS: String
  ) {
    self.assetId = assetId
    self.scoId = scoId
    self.launchFileURL = launchFileURL
    self.readAccessURL = readAccessURL
    self.injectedJS = injectedJS
    super.init(nibName: nil, bundle: nil)
    title = L10n.tr("scorm_player.title")
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func makeWebViewConfiguration() -> WKWebViewConfiguration {
    let config = WKWebViewConfiguration()
    config.preferences.javaScriptCanOpenWindowsAutomatically = true
    config.allowsInlineMediaPlayback = true

    let userContentController = WKUserContentController()

    let injectedScript = WKUserScript(
      source: injectedJS,
      injectionTime: .atDocumentStart,
      forMainFrameOnly: false
    )
    userContentController.addUserScript(injectedScript)
    userContentController.add(self, name: "scormStore")

    config.userContentController = userContentController
    config.setURLSchemeHandler(schemeHandler, forURLScheme: "scorm")

    return config
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close,
      target: self,
      action: #selector(close)
    )

    configureSaveStatusIndicator()

    view.addSubview(webView)
    webView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    ])

    loadScormContent()
  }

    private func configureSaveStatusIndicator() {
      let button = UIButton(type: .system)
      button.setImage(UIImage(systemName: "square.and.arrow.down"), for: .normal)
      button.tintColor = AppTheme.accentColor
      button.alpha = 0
      button.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
      button.isUserInteractionEnabled = false
      saveStatusButton = button
      navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
    }

    private func showAutosaveCompleteIndicator() {
      guard let button = saveStatusButton else { return }

      hideSaveStatusWorkItem?.cancel()

      button.setImage(UIImage(systemName: "square.and.arrow.down"), for: .normal)
      button.tintColor = AppTheme.accentColor
      button.alpha = 0
      button.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)

      UIView.animate(
        withDuration: 0.18,
        delay: 0,
        usingSpringWithDamping: 0.75,
        initialSpringVelocity: 0.5,
        options: [.curveEaseOut]
      ) {
        button.alpha = 1
        button.transform = .identity
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
        UIView.transition(
          with: button,
          duration: 0.2,
          options: .transitionCrossDissolve
        ) {
          button.setImage(UIImage(systemName: "externaldrive.fill.badge.checkmark"), for: .normal)
          button.tintColor = AppTheme.primaryColor
        }
      }

      let workItem = DispatchWorkItem { [weak button] in
        UIView.animate(withDuration: 0.25) {
          button?.alpha = 0
          button?.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
        }
      }

      hideSaveStatusWorkItem = workItem
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.3, execute: workItem)
    }

  private func loadScormContent() {
    if let scormURL = customSchemeURL(for: launchFileURL) {
      print("Loading SCORM via custom scheme URL: \(scormURL.absoluteString)")
      webView.load(URLRequest(url: scormURL))
    } else {
      print("Falling back to loadFileURL for: \(launchFileURL.path)")
      webView.loadFileURL(launchFileURL, allowingReadAccessTo: readAccessURL)
    }
  }

  private func customSchemeURL(for fileURL: URL) -> URL? {
    let standardizedLaunchURL = fileURL.standardizedFileURL
    let standardizedRootURL = readAccessURL.standardizedFileURL

    let rootPath = standardizedRootURL.path
    let filePath = standardizedLaunchURL.path

    guard filePath.hasPrefix(rootPath) else { return nil }

    var relativePath = String(filePath.dropFirst(rootPath.count))
    if relativePath.hasPrefix("/") {
      relativePath.removeFirst()
    }

    let encodedPath = relativePath
      .split(separator: "/", omittingEmptySubsequences: false)
      .map { segment in
        String(segment).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
          ?? String(segment)
      }
      .joined(separator: "/")

    return URL(string: "scorm://localhost/\(encodedPath)")
  }

  private func inspectScoreDataIfNeeded(cmiObject: [String: Any]) {
    guard !hasShownScoreWarning else { return }

    if let rawScore = cmiObject["cmi.core.score.raw"] as? String,
      !rawScore.isEmpty,
      Double(rawScore) == nil {
      hasShownScoreWarning = true
      presentAlert(
        title: L10n.tr("scorm_player.score_unavailable.title"),
        message: L10n.tr("scorm_player.score_unavailable.message")
      )
    }
  }

  private func presentAlert(title: String, message: String) {
    guard presentedViewController == nil else { return }

    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
    present(alert, animated: true)
  }

  @objc private func close() {
    dismiss(animated: true)
  }

  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    print("SCORM didStartProvisionalNavigation:", webView.url?.absoluteString ?? "nil")
  }

  func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    print("SCORM didCommit:", webView.url?.absoluteString ?? "nil")
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    print("SCORM didFinish:", webView.url?.absoluteString ?? "nil")
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    print("SCORM didFail:", error.localizedDescription)
  }

  func webView(
    _ webView: WKWebView,
    didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    print("SCORM didFailProvisionalNavigation:", error.localizedDescription)
    print("SCORM failed URL:", webView.url?.absoluteString ?? "nil")
  }

  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    print("SCORM navigationAction:", navigationAction.request.url?.absoluteString ?? "nil")
    decisionHandler(.allow)
  }

    func webView(
      _ webView: WKWebView,
      createWebViewWith configuration: WKWebViewConfiguration,
      for navigationAction: WKNavigationAction,
      windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
      let popupWebView = WKWebView(frame: .zero, configuration: configuration)
      popupWebView.navigationDelegate = self
      popupWebView.uiDelegate = self

      let popupVC = PopupWebViewController(popupWebView: popupWebView)
      let nav = UINavigationController(rootViewController: popupVC)
      nav.modalPresentationStyle = .pageSheet
      present(nav, animated: true)

      if let url = navigationAction.request.url {
        print("SCORM popup URL:", url.absoluteString)
      }

      return popupWebView
    }

  func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    print("SCORM script message:", message.name)

    guard message.name == "scormStore" else { return }
    guard let body = message.body as? [String: Any],
      let opr = body["op"] as? String
    else {
      print("SCORM message body was invalid")
      return
    }

    print("SCORM operation:", opr)

    switch opr {
    case "load":
      let json = ScormProgressStore.shared.loadCMI(assetId: assetId, scoId: scoId) ?? "{}"
      let jscript = "window.__scormNativeStoreLoad && window.__scormNativeStoreLoad(\(json));"
      webView.evaluateJavaScript(jscript) { _, error in
        if let error = error {
          print("SCORM load JS inject error:", error.localizedDescription)
        } else {
          print("SCORM load JS inject success:", self.assetId, self.scoId)
        }
      }

    case "save":
      print("SCORM save received for asset:", assetId, "sco:", scoId)

      guard let cmiObj = body["cmi"] else {
        print("SCORM save missing cmi payload")
        self.presentAlert(
          title: L10n.tr("scorm_player.progress_save_error.title"),
          message: L10n.tr("scorm_player.progress_save_error.message")
        )
        return
      }

      do {
        let data = try JSONSerialization.data(withJSONObject: cmiObj, options: [])
        guard let json = String(data: data, encoding: .utf8) else {
          print("SCORM save failed to encode JSON string")
          self.presentAlert(
            title: L10n.tr("scorm_player.progress_save_error.title"),
            message: L10n.tr("scorm_player.progress_save_error.message")
          )
          return
        }

        if let cmiDictionary = cmiObj as? [String: Any] {
          inspectScoreDataIfNeeded(cmiObject: cmiDictionary)
        }

        print("SCORM save payload:", json)
        ScormProgressStore.shared.saveCMI(assetId: assetId, scoId: scoId, cmiJSON: json)
        showAutosaveCompleteIndicator()
      } catch {
        print("SCORM save JSON serialization error:", error.localizedDescription)
        self.presentAlert(
          title: L10n.tr("scorm_player.progress_save_error.title"),
          message: L10n.tr("scorm_player.progress_save_error.message")
        )
      }

    default:
      print("SCORM unknown operation:", opr)
    }
  }
}

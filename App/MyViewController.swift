import UIKit
import WebKit
import Capacitor
import Foundation
import Network
import ObjectiveC
import ObjectiveC.runtime

final class HideKeyboardAccessoryWebView: WKWebView {
  override var inputAccessoryView: UIView? { nil }
}

final class NoInputAccessoryWebView: WKWebView {
  override var inputAccessoryView: UIView? { nil }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    removeInputAccessoryView()
  }

  private func removeInputAccessoryView() {
    guard let targetView = scrollView.subviews.first(where: {
      String(describing: type(of: $0)).hasPrefix("WKContent")
    }) else { return }

    let className = "\(type(of: targetView))_NoInputAccessoryView"
    var newClass: AnyClass? = NSClassFromString(className)

    if newClass == nil, let targetClass: AnyClass = object_getClass(targetView) {
      newClass = objc_allocateClassPair(targetClass, className, 0)

      if let newClass = newClass {
        let method = class_getInstanceMethod(NoInputAccessoryWebView.self, #selector(getter: NoInputAccessoryWebView.inputAccessoryView))
        class_addMethod(
          newClass,
          #selector(getter: UIResponder.inputAccessoryView),
          method_getImplementation(method!),
          method_getTypeEncoding(method!)
        )
        objc_registerClassPair(newClass)
      }
    }

    if let newClass = newClass {
      object_setClass(targetView, newClass)
    }
  }
}

final class MyViewController: CAPBridgeViewController,
                              WKUIDelegate,
                              WKNavigationDelegate,
                              WKScriptMessageHandler {

  private let monitor = NWPathMonitor()
  private let monitorQueue = DispatchQueue(label: "MyViewController.NetworkMonitor")

  private var hasResolvedInitialConnectivity = false
  private var isCurrentlyOnline = true
  private var startupSequenceCompleted = false
  private var pendingInitialOnlineState: Bool?
  private var isShowingOfflineMode = false
  private var isShowingConnectivityAlert = false
  private var embeddedOfflineCourseListNavController: UINavigationController?
  private var didShowInitialWebContent = false
  private var isAuthenticatingOfflineMode = false

  private let floatingMenuButton: UIButton = {
    let button = UIButton(type: .custom)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.backgroundColor = .systemBackground
    button.layer.cornerRadius = 28
    button.layer.masksToBounds = false
    button.layer.shadowColor = UIColor.black.cgColor
    button.layer.shadowOpacity = 0.2
    button.layer.shadowRadius = 8
    button.layer.shadowOffset = CGSize(width: 0, height: 4)

      if let icon = AppTheme.logoImage {
        button.setImage(icon, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
      } else {
        button.setTitle(AppTheme.shortText, for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
      }

    button.alpha = 0
    button.isHidden = true
    return button
  }()

  private let startupOverlay: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = .white
    return view
  }()

  override public func webView(with frame: CGRect, configuration: WKWebViewConfiguration) -> WKWebView {
    return NoInputAccessoryWebView(frame: frame, configuration: configuration)
  }

  private let startupLogoButton: UIButton = {
    let button = UIButton(type: .custom)
    button.translatesAutoresizingMaskIntoConstraints = false

      if let icon = AppTheme.logoImage {
        button.setImage(icon, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
      } else {
        button.setTitle(AppTheme.shortText, for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 36)
      }

    return button
  }()

  private let loadingTrackView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = UIColor.systemGray5
    view.layer.cornerRadius = 4
    view.clipsToBounds = true
    return view
  }()

  private let loadingFillView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = AppTheme.primaryColor
    view.layer.cornerRadius = 4
    view.clipsToBounds = true
    return view
  }()

  private let loadingStatusLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "Starting..."
    label.textColor = .darkGray
    label.font = .systemFont(ofSize: 16, weight: .medium)
    label.textAlignment = .center
    return label
  }()

  private let offlineTitleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "Offline Mode"
    label.textColor = .label
    label.font = .systemFont(ofSize: 22, weight: .semibold)
    label.textAlignment = .center
    label.alpha = 0
    label.isHidden = true
    return label
  }()

  private let offlineHelpButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("Help", for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
    button.alpha = 0
    button.isHidden = true
    return button
  }()

  private let offlineGoOnlineButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("Go Online", for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
    button.alpha = 0
    button.isHidden = true
    return button
  }()

  private let offlineSettingsButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("Settings", for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
    button.alpha = 0
    button.isHidden = true
    return button
  }()

  private let offlineCoursesContainerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = .clear
    view.alpha = 0
    view.isHidden = true
    return view
  }()

  private var loadingFillWidthConstraint: NSLayoutConstraint?
  private var startupLogoCenterYConstraint: NSLayoutConstraint?
  private var startupLogoTopConstraint: NSLayoutConstraint?

  override func viewDidLoad() {
    super.viewDidLoad()

    guard let webView = self.webView else {
      print("webView not ready in viewDidLoad")
      return
    }

    if let jsPath = Bundle.main.path(forResource: "nativeAssetStore", ofType: "js"),
       let js = try? String(contentsOfFile: jsPath, encoding: .utf8) {
      let script = WKUserScript(
        source: js,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: false
      )
      webView.configuration.userContentController.addUserScript(script)
    } else {
      print("nativeAssetStore.js not found in app bundle. Make sure it's included in Copy Bundle Resources / App target.")
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

    webView.uiDelegate = self
    webView.navigationDelegate = self
    webView.configuration.userContentController.add(self, name: "openScorm")
    webView.scrollView.contentInsetAdjustmentBehavior = .always

    setupFloatingMenuButton()
    setupStartupOverlay()
    startConnectivityMonitoring()
    runStartupSequence()
  }

  deinit {
    monitor.cancel()
  }

  private func setupFloatingMenuButton() {
    view.addSubview(floatingMenuButton)
    view.bringSubviewToFront(floatingMenuButton)

    NSLayoutConstraint.activate([
      floatingMenuButton.widthAnchor.constraint(equalToConstant: 56),
      floatingMenuButton.heightAnchor.constraint(equalToConstant: 56),
      floatingMenuButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
      floatingMenuButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
    ])

    floatingMenuButton.addTarget(self, action: #selector(showFloatingMenu), for: .touchUpInside)
  }

  private func setupStartupOverlay() {
    view.addSubview(startupOverlay)

    NSLayoutConstraint.activate([
      startupOverlay.topAnchor.constraint(equalTo: view.topAnchor),
      startupOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      startupOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      startupOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    ])

    startupOverlay.addSubview(startupLogoButton)
    startupOverlay.addSubview(loadingTrackView)
    loadingTrackView.addSubview(loadingFillView)
    startupOverlay.addSubview(loadingStatusLabel)
    startupOverlay.addSubview(offlineTitleLabel)
    startupOverlay.addSubview(offlineHelpButton)
    startupOverlay.addSubview(offlineGoOnlineButton)
    startupOverlay.addSubview(offlineSettingsButton)
    startupOverlay.addSubview(offlineCoursesContainerView)

    startupLogoCenterYConstraint = startupLogoButton.centerYAnchor.constraint(equalTo: startupOverlay.centerYAnchor, constant: -40)
    startupLogoTopConstraint = startupLogoButton.topAnchor.constraint(equalTo: startupOverlay.safeAreaLayoutGuide.topAnchor, constant: 20)
    startupLogoTopConstraint?.isActive = false

    startupLogoCenterYConstraint?.isActive = true

    NSLayoutConstraint.activate([
      startupLogoButton.centerXAnchor.constraint(equalTo: startupOverlay.centerXAnchor),
      startupLogoButton.widthAnchor.constraint(equalToConstant: 92),
      startupLogoButton.heightAnchor.constraint(equalToConstant: 92),

      loadingTrackView.topAnchor.constraint(equalTo: startupLogoButton.bottomAnchor, constant: 24),
      loadingTrackView.centerXAnchor.constraint(equalTo: startupOverlay.centerXAnchor),
      loadingTrackView.widthAnchor.constraint(equalToConstant: 220),
      loadingTrackView.heightAnchor.constraint(equalToConstant: 8),

      loadingFillView.leadingAnchor.constraint(equalTo: loadingTrackView.leadingAnchor),
      loadingFillView.topAnchor.constraint(equalTo: loadingTrackView.topAnchor),
      loadingFillView.bottomAnchor.constraint(equalTo: loadingTrackView.bottomAnchor),

      loadingStatusLabel.topAnchor.constraint(equalTo: loadingTrackView.bottomAnchor, constant: 16),
      loadingStatusLabel.centerXAnchor.constraint(equalTo: startupOverlay.centerXAnchor),

      offlineTitleLabel.topAnchor.constraint(equalTo: startupLogoButton.bottomAnchor, constant: 8),
      offlineTitleLabel.centerXAnchor.constraint(equalTo: startupOverlay.centerXAnchor),

      offlineHelpButton.topAnchor.constraint(equalTo: offlineTitleLabel.bottomAnchor, constant: 14),
      offlineHelpButton.leadingAnchor.constraint(equalTo: startupOverlay.safeAreaLayoutGuide.leadingAnchor, constant: 24),

      offlineGoOnlineButton.centerYAnchor.constraint(equalTo: offlineHelpButton.centerYAnchor),
      offlineGoOnlineButton.centerXAnchor.constraint(equalTo: startupOverlay.centerXAnchor),

      offlineSettingsButton.topAnchor.constraint(equalTo: offlineTitleLabel.bottomAnchor, constant: 14),
      offlineSettingsButton.trailingAnchor.constraint(equalTo: startupOverlay.safeAreaLayoutGuide.trailingAnchor, constant: -24),

      offlineCoursesContainerView.topAnchor.constraint(equalTo: offlineHelpButton.bottomAnchor, constant: 18),
      offlineCoursesContainerView.leadingAnchor.constraint(equalTo: startupOverlay.safeAreaLayoutGuide.leadingAnchor),
      offlineCoursesContainerView.trailingAnchor.constraint(equalTo: startupOverlay.safeAreaLayoutGuide.trailingAnchor),
      offlineCoursesContainerView.bottomAnchor.constraint(equalTo: startupOverlay.safeAreaLayoutGuide.bottomAnchor)
    ])

    loadingFillWidthConstraint = loadingFillView.widthAnchor.constraint(equalToConstant: 0)
    loadingFillWidthConstraint?.isActive = true

    startupLogoButton.addTarget(self, action: #selector(offlineLogoTapped), for: .touchUpInside)
    startupLogoButton.isUserInteractionEnabled = false

    offlineHelpButton.addTarget(self, action: #selector(offlineHelpTapped), for: .touchUpInside)
    offlineGoOnlineButton.addTarget(self, action: #selector(offlineGoOnlineTapped), for: .touchUpInside)
    offlineSettingsButton.addTarget(self, action: #selector(offlineSettingsTapped), for: .touchUpInside)

    view.bringSubviewToFront(startupOverlay)
  }

  private func startConnectivityMonitoring() {
    monitor.pathUpdateHandler = { [weak self] path in
      DispatchQueue.main.async {
        guard let self = self else { return }

        let wasOnline = self.isCurrentlyOnline
        let online = path.status == .satisfied
        self.isCurrentlyOnline = online

        if !self.hasResolvedInitialConnectivity {
          self.hasResolvedInitialConnectivity = true
          self.pendingInitialOnlineState = online
          self.finishStartupIfReady()
          return
        }

        if wasOnline && !online && !self.isShowingOfflineMode {
          self.presentLostInternetAlert()
        }
      }
    }

    monitor.start(queue: monitorQueue)
  }

  private func runStartupSequence() {
    loadingStatusLabel.text = "Checking for network..."
    animateLoadingBar(to: 0.45, duration: 1.4)

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      guard let self = self else { return }
      self.loadingStatusLabel.text = "Loading Content..."
      self.animateLoadingBar(to: 1.0, duration: 1.4)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
      guard let self = self else { return }
      self.startupSequenceCompleted = true
      self.finishStartupIfReady()
    }
  }

  private func animateLoadingBar(to progress: CGFloat, duration: TimeInterval) {
    let totalWidth: CGFloat = 220
    loadingFillWidthConstraint?.constant = totalWidth * max(0, min(1, progress))
    UIView.animate(withDuration: duration) {
      self.startupOverlay.layoutIfNeeded()
    }
  }

  private func finishStartupIfReady() {
    guard startupSequenceCompleted, let initialOnlineState = pendingInitialOnlineState else { return }

    if initialOnlineState {
      showOnlineState(reloadWebView: true)
    } else {
      requestOfflineModeAccess()
    }
  }

    private func requestOfflineModeAccess(afterSuccess: (() -> Void)? = nil) {
      if !AppConfiguration.isOfflineModeAuthenticationEnabled {
        showOfflineState()
        afterSuccess?()
        return
      }

      guard !isAuthenticatingOfflineMode else { return }
      isAuthenticatingOfflineMode = true

      runBiometricAuth { [weak self] success in
        guard let self = self else { return }
        self.isAuthenticatingOfflineMode = false

        if success {
          self.showOfflineState()
          afterSuccess?()
        } else {
          self.showLockFailure()
        }
      }
    }

  private func showOnlineState(reloadWebView: Bool = true) {
    isShowingOfflineMode = false
    isShowingConnectivityAlert = false
    startupLogoButton.isUserInteractionEnabled = false
    floatingMenuButton.isHidden = false

    if let webView = self.webView {
      webView.isHidden = false
      view.sendSubviewToBack(webView)

        if reloadWebView {
          webView.load(URLRequest(url: AppConfiguration.launchURL))
        }

      didShowInitialWebContent = true
    }

    UIView.animate(withDuration: 0.3, animations: {
      self.startupOverlay.alpha = 0
      self.floatingMenuButton.alpha = 1
    }, completion: { _ in
      self.startupOverlay.removeFromSuperview()
    })
  }

  private func showOfflineState() {
    isShowingOfflineMode = true

    if startupOverlay.superview == nil {
      startupOverlay.alpha = 1
      view.addSubview(startupOverlay)
      NSLayoutConstraint.activate([
        startupOverlay.topAnchor.constraint(equalTo: view.topAnchor),
        startupOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        startupOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        startupOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor)
      ])
    }

    view.bringSubviewToFront(startupOverlay)

    floatingMenuButton.isHidden = true
    floatingMenuButton.alpha = 0

    loadingTrackView.isHidden = false
    loadingStatusLabel.isHidden = false
    loadingTrackView.alpha = 0
    loadingStatusLabel.alpha = 0

    offlineTitleLabel.isHidden = false
    offlineHelpButton.isHidden = false
    offlineGoOnlineButton.isHidden = false
    offlineSettingsButton.isHidden = false
    offlineCoursesContainerView.isHidden = false

    startupLogoButton.isUserInteractionEnabled = true

    startupLogoCenterYConstraint?.isActive = false
    startupLogoTopConstraint?.isActive = true

    embedOfflineCourseListIfNeeded()
    refreshOfflineCourseList()

    UIView.animate(withDuration: 0.4, animations: {
      self.loadingTrackView.alpha = 0
      self.loadingStatusLabel.alpha = 0
      self.offlineTitleLabel.alpha = 1
      self.offlineHelpButton.alpha = 1
      self.offlineGoOnlineButton.alpha = 1
      self.offlineSettingsButton.alpha = 1
      self.offlineCoursesContainerView.alpha = 1
      self.startupOverlay.layoutIfNeeded()
    }, completion: { _ in
      self.loadingTrackView.isHidden = true
      self.loadingStatusLabel.isHidden = true
    })
  }

    private func embedOfflineCourseListIfNeeded() {
      guard embeddedOfflineCourseListNavController == nil else { return }

      let courses = ScormUtils.loadAllCourses()
      let courseListVC = ScormCourseListViewController(courses: courses)
      let nav = UINavigationController(rootViewController: courseListVC)
      nav.setNavigationBarHidden(false, animated: false)

      addChild(nav)
      offlineCoursesContainerView.addSubview(nav.view)
      nav.view.translatesAutoresizingMaskIntoConstraints = false

      NSLayoutConstraint.activate([
        nav.view.topAnchor.constraint(equalTo: offlineCoursesContainerView.topAnchor),
        nav.view.bottomAnchor.constraint(equalTo: offlineCoursesContainerView.bottomAnchor),
        nav.view.leadingAnchor.constraint(equalTo: offlineCoursesContainerView.leadingAnchor),
        nav.view.trailingAnchor.constraint(equalTo: offlineCoursesContainerView.trailingAnchor)
      ])

      nav.didMove(toParent: self)
      embeddedOfflineCourseListNavController = nav
    }

    private func refreshOfflineCourseList() {
      let courses = ScormUtils.loadAllCourses()
      let courseListVC = ScormCourseListViewController(courses: courses)
      embeddedOfflineCourseListNavController?.setViewControllers([courseListVC], animated: false)
      embeddedOfflineCourseListNavController?.setNavigationBarHidden(false, animated: false)
    }

  private func presentLostInternetAlert() {
    guard !isShowingConnectivityAlert else { return }

    if presentedViewController is UIAlertController {
      return
    }

    isShowingConnectivityAlert = true

    let alert = UIAlertController(
      title: "No Internet Connection",
      message: "No Internet connection available would you like to go to Offline Mode?",
      preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "Offline Mode", style: .default, handler: { [weak self] _ in
      guard let self = self else { return }
      self.isShowingConnectivityAlert = false
      self.dismissPresentedContentIfNeeded {
        self.requestOfflineModeAccess()
      }
    }))

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] _ in
      self?.isShowingConnectivityAlert = false
    }))

    present(alert, animated: true)
  }

  private func dismissPresentedContentIfNeeded(completion: @escaping () -> Void) {
    if let presented = presentedViewController,
       !(presented is UIAlertController) {
      presented.dismiss(animated: true) {
        completion()
      }
    } else {
      completion()
    }
  }

  private func runBiometricAuth(completion: @escaping (Bool) -> Void) {
    authenticateUser { result in
      switch result {
      case .success:
        completion(true)
      case .failure:
        completion(false)
      }
    }
  }

    private func showLockFailure() {
      let alert = UIAlertController(
        title: "Authentication Required",
        message: "You need authentication to enter Offline Mode.",
        preferredStyle: .alert
      )

      alert.addAction(UIAlertAction(title: "Try Again", style: .default, handler: { [weak self] _ in
        self?.requestOfflineModeAccess()
      }))

      alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

      present(alert, animated: true)
    }

  @objc private func offlineLogoTapped() {
    refreshOfflineCourseList()
  }

  @objc private func offlineHelpTapped() {
    presentHelp()
  }

  @objc private func offlineGoOnlineTapped() {
    if isCurrentlyOnline {
      dismissPresentedContentIfNeeded {
        self.showOnlineState(reloadWebView: true)
      }
    } else {
      let alert = UIAlertController(
        title: "No Internet Connection",
        message: "No internet connection is available.",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "OK", style: .default))
      present(alert, animated: true)
    }
  }

  @objc private func offlineSettingsTapped() {
    presentSettings()
  }

  @objc private func showFloatingMenu() {
    let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

    alert.addAction(UIAlertAction(title: "Offline Mode", style: .default, handler: { [weak self] _ in
      self?.requestOfflineModeAccess()
    }))

    alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { [weak self] _ in
      self?.presentSettings()
    }))

    alert.addAction(UIAlertAction(title: "Help", style: .default, handler: { [weak self] _ in
      self?.presentHelp()
    }))

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

    if let popover = alert.popoverPresentationController {
      popover.sourceView = floatingMenuButton
      popover.sourceRect = floatingMenuButton.bounds
    }

    present(alert, animated: true)
  }

    private func presentCourseList() {
      let courses = ScormUtils.loadAllCourses()
      let vc = ScormCourseListViewController(courses: courses)
      let nav = UINavigationController(rootViewController: vc)
      nav.modalPresentationStyle = .formSheet
      present(nav, animated: true)
    }

  private func presentSettings() {
    let vc = SettingsViewController()
    let nav = UINavigationController(rootViewController: vc)
    nav.modalPresentationStyle = .formSheet
    present(nav, animated: true)
  }

  private func presentHelp() {
    let vc = HelpViewController()
    let nav = UINavigationController(rootViewController: vc)
    nav.modalPresentationStyle = .formSheet
    present(nav, animated: true)
  }

  func userContentController(_ userContentController: WKUserContentController,
                             didReceive message: WKScriptMessage) {
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

    private func presentScormLessonList(assetId: String) {
      do {
        let course = try ScormUtils.loadCourse(assetId: assetId)

        let vc = ScormLessonListViewController(
          assetId: course.assetId,
          scormDir: course.scormDir,
          manifest: course.manifest
        )

        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
      } catch {
        print("SCORM error:", error)
      }
    }

  override var prefersStatusBarHidden: Bool { false }
  override var preferredStatusBarStyle: UIStatusBarStyle { .default }

  func webView(_ webView: WKWebView,
               createWebViewWith configuration: WKWebViewConfiguration,
               for navigationAction: WKNavigationAction,
               windowFeatures: WKWindowFeatures) -> WKWebView? {

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

  func webView(_ webView: WKWebView,
               decidePolicyFor navigationAction: WKNavigationAction,
               decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
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

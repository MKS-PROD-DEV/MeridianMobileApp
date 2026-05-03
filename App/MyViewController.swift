/*
  Main Capacitor bridge controller.
  - hosting the main Capacitor webview
  - injecting helper JavaScript into the main webview
  - receiving JavaScript messages from the web app
  - managing online/offline mode
  - handling connectivity changes
  - presenting offline course and SCORM flows
*/
import Capacitor
import Foundation
import Network
import ObjectiveC
import UIKit
import WebKit

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
    guard
      let targetView = scrollView.subviews.first(where: {
        String(describing: type(of: $0)).hasPrefix("WKContent")
      })
    else { return }

    let className = "\(type(of: targetView))_NoInputAccessoryView"
    var newClass: AnyClass? = NSClassFromString(className)

    if newClass == nil, let targetClass: AnyClass = object_getClass(targetView) {
      newClass = objc_allocateClassPair(targetClass, className, 0)

      if let newClass = newClass {
        let method = class_getInstanceMethod(
          NoInputAccessoryWebView.self,
          #selector(getter: NoInputAccessoryWebView.inputAccessoryView)
        )
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

final class MyViewController: CAPBridgeViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
  let monitor = NWPathMonitor()
  let monitorQueue = DispatchQueue(label: "MyViewController.NetworkMonitor")

  var hasResolvedInitialConnectivity = false
  var isCurrentlyOnline = true
  var startupSequenceCompleted = false
  var pendingInitialOnlineState: Bool?
  var isShowingOfflineMode = false
  var isShowingConnectivityAlert = false
  var embeddedOfflineCourseListNavController: UINavigationController?
  var didShowInitialWebContent = false
  var isAuthenticatingOfflineMode = false
  var hasPresentedInitialSiteSelection = false
  var isWaitingForInitialSiteLoad = false
  var isFloatingActionMenuOpen = false

  let floatingMenuButton: UIButton = {
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

  let startupOverlay: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = .systemBackground
    return view
  }()

  let startupLogoButton: UIButton = {
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

  let loadingTrackView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = UIColor.systemGray5
    view.layer.cornerRadius = 4
    view.clipsToBounds = true
    return view
  }()

  let loadingFillView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = AppTheme.primaryColor
    view.layer.cornerRadius = 4
    view.clipsToBounds = true
    return view
  }()

  let loadingStatusLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "Starting..."
    label.textColor = .darkGray
    label.font = .systemFont(ofSize: 16, weight: .medium)
    label.textAlignment = .center
    return label
  }()

  let offlineTitleLabel: UILabel = {
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

  let offlineHelpButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("Help", for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
    button.alpha = 0
    button.isHidden = true
    return button
  }()

  let offlineGoOnlineButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("Go Online", for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
    button.alpha = 0
    button.isHidden = true
    return button
  }()

  let offlineSettingsButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("Settings", for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
    button.alpha = 0
    button.isHidden = true
    return button
  }()

  let offlineCoursesContainerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = .clear
    view.alpha = 0
    view.isHidden = true
    return view
  }()

    let floatingMenuOverlay: UIControl = {
      let view = UIControl()
      view.translatesAutoresizingMaskIntoConstraints = false
      view.backgroundColor = UIColor.black.withAlphaComponent(0.08)
      view.alpha = 0
      view.isHidden = true
      return view
    }()

    let floatingOfflineButton: UIButton = {
      let button = UIButton(type: .custom)
      button.translatesAutoresizingMaskIntoConstraints = false
      button.backgroundColor = .systemBackground
      button.layer.cornerRadius = 26
      button.layer.shadowColor = UIColor.black.cgColor
      button.layer.shadowOpacity = 0.12
      button.layer.shadowRadius = 8
      button.layer.shadowOffset = CGSize(width: 0, height: 4)
      button.setImage(UIImage(named: "MGPlayer"), for: .normal)
      button.imageView?.contentMode = .scaleAspectFit
      return button
    }()

    let floatingSettingsButton: UIButton = {
      let button = UIButton(type: .system)
      button.translatesAutoresizingMaskIntoConstraints = false
      button.backgroundColor = .systemBackground
      button.layer.cornerRadius = 26
      button.layer.shadowColor = UIColor.black.cgColor
      button.layer.shadowOpacity = 0.12
      button.layer.shadowRadius = 8
      button.layer.shadowOffset = CGSize(width: 0, height: 4)
      button.tintColor = AppTheme.primaryColor
      button.setImage(UIImage(systemName: "gearshape.fill"), for: .normal)
      button.imageView?.contentMode = .scaleAspectFit
      return button
    }()

    let floatingHelpButton: UIButton = {
      let button = UIButton(type: .system)
      button.translatesAutoresizingMaskIntoConstraints = false
      button.backgroundColor = .systemBackground
      button.layer.cornerRadius = 26
      button.layer.shadowColor = UIColor.black.cgColor
      button.layer.shadowOpacity = 0.12
      button.layer.shadowRadius = 8
      button.layer.shadowOffset = CGSize(width: 0, height: 4)
      button.tintColor = AppTheme.primaryColor
      button.setImage(UIImage(systemName: "questionmark.circle.fill"), for: .normal)
      button.imageView?.contentMode = .scaleAspectFit
      return button
    }()

  var loadingFillWidthConstraint: NSLayoutConstraint?
  var startupLogoCenterYConstraint: NSLayoutConstraint?
  var startupLogoTopConstraint: NSLayoutConstraint?

  override public func webView(with frame: CGRect, configuration: WKWebViewConfiguration) -> WKWebView {
    return NoInputAccessoryWebView(frame: frame, configuration: configuration)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    guard let webView = self.webView else {
      print("webView not ready in viewDidLoad")
      return
    }

    configureBridgeScripts(for: webView)

    webView.uiDelegate = self
    webView.navigationDelegate = self
    webView.configuration.userContentController.add(self, name: "openScorm")
    webView.scrollView.contentInsetAdjustmentBehavior = .always

    setupFloatingMenuButton()
    setupFloatingActionMenu()
    applyFloatingActionMenuBranding()
    setupStartupOverlay()
    startConnectivityMonitoring()
    runStartupSequence()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    presentInitialSiteSelectionIfNeeded()
    restoreFloatingMenuButtonVisibilityIfNeeded()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    view.bringSubviewToFront(floatingMenuButton)

    if isFloatingActionMenuOpen {
      view.bringSubviewToFront(floatingMenuOverlay)
      view.bringSubviewToFront(floatingOfflineButton)
      view.bringSubviewToFront(floatingSettingsButton)
      view.bringSubviewToFront(floatingHelpButton)
      view.bringSubviewToFront(floatingMenuButton)
    }
  }

  deinit {
    monitor.cancel()
  }

  override var prefersStatusBarHidden: Bool { false }
  override var preferredStatusBarStyle: UIStatusBarStyle { .default }
}

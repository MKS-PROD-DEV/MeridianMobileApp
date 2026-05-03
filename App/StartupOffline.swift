/*
  Loading and Startup Controller.
  - Handles network check
  - Loads files
  - Bridge between modes
*/
import UIKit

extension MyViewController {
  func setupStartupOverlay() {
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

    startupLogoCenterYConstraint = startupLogoButton.centerYAnchor.constraint(
      equalTo: startupOverlay.centerYAnchor,
      constant: -40
    )
    startupLogoTopConstraint = startupLogoButton.topAnchor.constraint(
      equalTo: startupOverlay.safeAreaLayoutGuide.topAnchor,
      constant: 10
    )
    startupLogoTopConstraint?.isActive = false
    startupLogoCenterYConstraint?.isActive = true

    NSLayoutConstraint.activate([
      startupLogoButton.centerXAnchor.constraint(equalTo: startupOverlay.centerXAnchor),
      startupLogoButton.widthAnchor.constraint(equalToConstant: 64),
      startupLogoButton.heightAnchor.constraint(equalToConstant: 64),

      loadingTrackView.topAnchor.constraint(equalTo: startupLogoButton.bottomAnchor, constant: 24),
      loadingTrackView.centerXAnchor.constraint(equalTo: startupOverlay.centerXAnchor),
      loadingTrackView.widthAnchor.constraint(equalToConstant: 220),
      loadingTrackView.heightAnchor.constraint(equalToConstant: 8),

      loadingFillView.leadingAnchor.constraint(equalTo: loadingTrackView.leadingAnchor),
      loadingFillView.topAnchor.constraint(equalTo: loadingTrackView.topAnchor),
      loadingFillView.bottomAnchor.constraint(equalTo: loadingTrackView.bottomAnchor),

      loadingStatusLabel.topAnchor.constraint(equalTo: loadingTrackView.bottomAnchor, constant: 16),
      loadingStatusLabel.centerXAnchor.constraint(equalTo: startupOverlay.centerXAnchor),

      offlineTitleLabel.topAnchor.constraint(equalTo: startupLogoButton.bottomAnchor, constant: 4),
      offlineTitleLabel.centerXAnchor.constraint(equalTo: startupOverlay.centerXAnchor),

      offlineHelpButton.topAnchor.constraint(equalTo: offlineTitleLabel.bottomAnchor, constant: 6),
      offlineHelpButton.leadingAnchor.constraint(
        equalTo: startupOverlay.safeAreaLayoutGuide.leadingAnchor,
        constant: 24
      ),

      offlineGoOnlineButton.centerYAnchor.constraint(equalTo: offlineHelpButton.centerYAnchor),
      offlineGoOnlineButton.centerXAnchor.constraint(equalTo: startupOverlay.centerXAnchor),

      offlineSettingsButton.topAnchor.constraint(equalTo: offlineTitleLabel.bottomAnchor, constant: 6),
      offlineSettingsButton.trailingAnchor.constraint(
        equalTo: startupOverlay.safeAreaLayoutGuide.trailingAnchor,
        constant: -24
      ),

      offlineCoursesContainerView.topAnchor.constraint(equalTo: offlineHelpButton.bottomAnchor, constant: 8),
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

  func startConnectivityMonitoring() {
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

  func runStartupSequence() {
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

  func animateLoadingBar(to progress: CGFloat, duration: TimeInterval) {
    let totalWidth: CGFloat = 220
    loadingFillWidthConstraint?.constant = totalWidth * max(0, min(1, progress))
    UIView.animate(withDuration: duration) {
      self.startupOverlay.layoutIfNeeded()
    }
  }

  func finishStartupIfReady() {
    guard startupSequenceCompleted, let initialOnlineState = pendingInitialOnlineState else { return }

    if initialOnlineState {
      showOnlineState(reloadWebView: true)
    } else {
      requestOfflineModeAccess()
    }
  }

  func requestOfflineModeAccess(afterSuccess: (() -> Void)? = nil) {
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

    func showReturningOnlineLoadingState() {
      startupOverlay.alpha = 1
      view.bringSubviewToFront(startupOverlay)

      loadingTrackView.isHidden = false
      loadingStatusLabel.isHidden = false
      loadingTrackView.alpha = 1
      loadingStatusLabel.alpha = 1

      offlineTitleLabel.alpha = 0
      offlineHelpButton.alpha = 0
      offlineGoOnlineButton.alpha = 0
      offlineSettingsButton.alpha = 0
      offlineCoursesContainerView.alpha = 0

      loadingFillWidthConstraint?.constant = 0
      startupOverlay.layoutIfNeeded()

      loadingStatusLabel.text = "Checking network..."
      animateLoadingBar(to: 0.45, duration: 0.35)

      UIView.animate(withDuration: 0.2) {
        self.offlineTitleLabel.alpha = 0
        self.offlineHelpButton.alpha = 0
        self.offlineGoOnlineButton.alpha = 0
        self.offlineSettingsButton.alpha = 0
        self.offlineCoursesContainerView.alpha = 0
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
        guard let self = self else { return }
        self.loadingStatusLabel.text = "Preparing site..."
        self.animateLoadingBar(to: 0.9, duration: 0.45)
      }
    }

    func showOnlineState(reloadWebView: Bool = true) {
      let isReturningFromOfflineMode = isShowingOfflineMode

      isShowingOfflineMode = false
      isShowingConnectivityAlert = false
      startupLogoButton.isUserInteractionEnabled = false
      floatingMenuButton.isHidden = false

      if let webView = self.webView {
        webView.isHidden = false
        view.sendSubviewToBack(webView)

        if reloadWebView {
          isWaitingForInitialSiteLoad = true

          if isReturningFromOfflineMode {
            showReturningOnlineLoadingState()
          } else {
            loadingStatusLabel.text = "Preparing site..."
            loadingTrackView.isHidden = false
            loadingStatusLabel.isHidden = false
            loadingTrackView.alpha = 1
            loadingStatusLabel.alpha = 1
            startupOverlay.alpha = 1
            view.bringSubviewToFront(startupOverlay)
          }

          webView.load(URLRequest(url: AppConfiguration.launchURL))
        } else {
          didShowInitialWebContent = true
          completeStartupOverlayDismissalIfNeeded()
        }
      }
    }

  func showOfflineState() {
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

    floatingMenuButton.isHidden = false
    floatingMenuButton.alpha = 1
    view.bringSubviewToFront(floatingMenuButton)

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

    UIView.animate(
      withDuration: 0.4,
      animations: {
        self.loadingTrackView.alpha = 0
        self.loadingStatusLabel.alpha = 0
        self.offlineTitleLabel.alpha = 1
        self.offlineHelpButton.alpha = 1
        self.offlineGoOnlineButton.alpha = 1
        self.offlineSettingsButton.alpha = 1
        self.offlineCoursesContainerView.alpha = 1
        self.startupOverlay.layoutIfNeeded()
      },
      completion: { _ in
        self.loadingTrackView.isHidden = true
        self.loadingStatusLabel.isHidden = true
      }
    )
  }

  func embedOfflineCourseListIfNeeded() {
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

  func refreshOfflineCourseList() {
    let courses = ScormUtils.loadAllCourses()
    let courseListVC = ScormCourseListViewController(courses: courses)
    embeddedOfflineCourseListNavController?.setViewControllers([courseListVC], animated: false)
    embeddedOfflineCourseListNavController?.setNavigationBarHidden(false, animated: false)
  }

  func completeStartupOverlayDismissalIfNeeded() {
    guard startupOverlay.superview != nil else { return }

    UIView.animate(
      withDuration: 0.3,
      animations: {
        self.startupOverlay.alpha = 0
        self.floatingMenuButton.alpha = 1
      },
      completion: { _ in
        self.startupOverlay.removeFromSuperview()
      }
    )
  }

  func presentLostInternetAlert() {
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

    alert.addAction(
      UIAlertAction(
        title: "Offline Mode",
        style: .default,
        handler: { [weak self] _ in
          guard let self = self else { return }
          self.isShowingConnectivityAlert = false
          self.dismissPresentedContentIfNeeded {
            self.requestOfflineModeAccess()
          }
        }
      )
    )

    alert.addAction(
      UIAlertAction(
        title: "Cancel",
        style: .cancel,
        handler: { [weak self] _ in
          self?.isShowingConnectivityAlert = false
        }
      )
    )

    present(alert, animated: true)
  }

  func runBiometricAuth(completion: @escaping (Bool) -> Void) {
    authenticateUser { result in
      switch result {
      case .success:
        completion(true)
      case .failure:
        completion(false)
      }
    }
  }

  func showLockFailure() {
    let alert = UIAlertController(
      title: "Authentication Required",
      message: "You need authentication to enter Offline Mode.",
      preferredStyle: .alert
    )

    alert.addAction(
      UIAlertAction(
        title: "Try Again",
        style: .default,
        handler: { [weak self] _ in
          self?.requestOfflineModeAccess()
        }
      )
    )

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    present(alert, animated: true)
  }

  @objc func offlineLogoTapped() {
    refreshOfflineCourseList()
  }

  @objc func offlineHelpTapped() {
    presentHelp()
  }

  @objc func offlineGoOnlineTapped() {
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

  @objc func offlineSettingsTapped() {
    presentSettings()
  }
}

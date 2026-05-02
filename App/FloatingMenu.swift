import UIKit

extension MyViewController {
  func setupFloatingMenuButton() {
    view.addSubview(floatingMenuButton)
    view.bringSubviewToFront(floatingMenuButton)

    NSLayoutConstraint.activate([
      floatingMenuButton.widthAnchor.constraint(equalToConstant: 56),
      floatingMenuButton.heightAnchor.constraint(equalToConstant: 56),
      floatingMenuButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
      floatingMenuButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
    ])

    floatingMenuButton.addTarget(self, action: #selector(showFloatingMenu), for: .touchUpInside)
  }

  func setupFloatingActionMenu() {
    view.addSubview(floatingMenuOverlay)
    view.addSubview(floatingOfflineButton)
    view.addSubview(floatingSettingsButton)
    view.addSubview(floatingHelpButton)

    NSLayoutConstraint.activate([
      floatingMenuOverlay.topAnchor.constraint(equalTo: view.topAnchor),
      floatingMenuOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      floatingMenuOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      floatingMenuOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),

      floatingOfflineButton.widthAnchor.constraint(equalToConstant: 52),
      floatingOfflineButton.heightAnchor.constraint(equalToConstant: 52),
      floatingOfflineButton.centerXAnchor.constraint(equalTo: floatingMenuButton.centerXAnchor),
      floatingOfflineButton.centerYAnchor.constraint(equalTo: floatingMenuButton.centerYAnchor),

      floatingSettingsButton.widthAnchor.constraint(equalToConstant: 52),
      floatingSettingsButton.heightAnchor.constraint(equalToConstant: 52),
      floatingSettingsButton.centerXAnchor.constraint(equalTo: floatingMenuButton.centerXAnchor),
      floatingSettingsButton.centerYAnchor.constraint(equalTo: floatingMenuButton.centerYAnchor),

      floatingHelpButton.widthAnchor.constraint(equalToConstant: 52),
      floatingHelpButton.heightAnchor.constraint(equalToConstant: 52),
      floatingHelpButton.centerXAnchor.constraint(equalTo: floatingMenuButton.centerXAnchor),
      floatingHelpButton.centerYAnchor.constraint(equalTo: floatingMenuButton.centerYAnchor),
    ])

    [floatingOfflineButton, floatingSettingsButton, floatingHelpButton].forEach { button in
      button.alpha = 0
      button.isHidden = true
    }

    floatingMenuOverlay.addTarget(self, action: #selector(hideFloatingActionMenu), for: .touchUpInside)
    floatingOfflineButton.addTarget(self, action: #selector(floatingOfflineTapped), for: .touchUpInside)
    floatingSettingsButton.addTarget(self, action: #selector(floatingSettingsTapped), for: .touchUpInside)
    floatingHelpButton.addTarget(self, action: #selector(floatingHelpTapped), for: .touchUpInside)
  }

  func applyFloatingActionMenuBranding() {
    floatingSettingsButton.tintColor = AppTheme.primaryColor
    floatingHelpButton.tintColor = AppTheme.primaryColor

    floatingSettingsButton.backgroundColor = .systemBackground
    floatingHelpButton.backgroundColor = .systemBackground
    floatingOfflineButton.backgroundColor = .systemBackground

    floatingSettingsButton.layer.cornerRadius = 26
    floatingHelpButton.layer.cornerRadius = 26
    floatingOfflineButton.layer.cornerRadius = 26
  }

  func restoreFloatingMenuButtonVisibilityIfNeeded() {
    floatingMenuButton.isHidden = false
    floatingMenuButton.alpha = 1
    view.bringSubviewToFront(floatingMenuButton)
  }

  @objc func showFloatingMenu() {
    if isFloatingActionMenuOpen {
      hideFloatingActionMenu()
      return
    }

    isFloatingActionMenuOpen = true
    floatingMenuOverlay.isHidden = false
    floatingOfflineButton.isHidden = false
    floatingSettingsButton.isHidden = false
    floatingHelpButton.isHidden = false

    view.bringSubviewToFront(floatingMenuOverlay)
    view.bringSubviewToFront(floatingOfflineButton)
    view.bringSubviewToFront(floatingSettingsButton)
    view.bringSubviewToFront(floatingHelpButton)
    view.bringSubviewToFront(floatingMenuButton)

    floatingMenuOverlay.alpha = 0
    floatingOfflineButton.alpha = 0
    floatingSettingsButton.alpha = 0
    floatingHelpButton.alpha = 0

    floatingOfflineButton.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
    floatingSettingsButton.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
    floatingHelpButton.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)

    UIView.animate(withDuration: 0.18) {
      self.floatingMenuOverlay.alpha = 1
    }

    UIView.animate(
      withDuration: 0.45,
      delay: 0.00,
      usingSpringWithDamping: 0.72,
      initialSpringVelocity: 0.7,
      options: [.curveEaseOut],
      animations: {
        self.floatingOfflineButton.alpha = 1
        self.floatingOfflineButton.transform = CGAffineTransform(translationX: -72, y: 0)
      }
    )

    UIView.animate(
      withDuration: 0.45,
      delay: 0.03,
      usingSpringWithDamping: 0.72,
      initialSpringVelocity: 0.7,
      options: [.curveEaseOut],
      animations: {
        self.floatingSettingsButton.alpha = 1
        self.floatingSettingsButton.transform = CGAffineTransform(translationX: -54, y: -54)
      }
    )

    UIView.animate(
      withDuration: 0.45,
      delay: 0.06,
      usingSpringWithDamping: 0.72,
      initialSpringVelocity: 0.7,
      options: [.curveEaseOut],
      animations: {
        self.floatingHelpButton.alpha = 1
        self.floatingHelpButton.transform = CGAffineTransform(translationX: 0, y: -72)
      }
    )
  }

  @objc func hideFloatingActionMenu() {
    guard isFloatingActionMenuOpen else { return }

    isFloatingActionMenuOpen = false

    UIView.animate(withDuration: 0.16) {
      self.floatingMenuOverlay.alpha = 0
    }

    let buttons = [floatingHelpButton, floatingSettingsButton, floatingOfflineButton]

    for (index, button) in buttons.enumerated() {
      UIView.animate(
        withDuration: 0.18,
        delay: 0.02 * Double(index),
        options: [.curveEaseIn],
        animations: {
          button.alpha = 0
          button.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
        },
        completion: { _ in
          if index == buttons.count - 1 {
            self.floatingMenuOverlay.isHidden = true
            self.floatingOfflineButton.isHidden = true
            self.floatingSettingsButton.isHidden = true
            self.floatingHelpButton.isHidden = true

            self.floatingOfflineButton.transform = .identity
            self.floatingSettingsButton.transform = .identity
            self.floatingHelpButton.transform = .identity
          }
        }
      )
    }
  }

  @objc func floatingOfflineTapped() {
    hideFloatingActionMenu()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
      self.requestOfflineModeAccess()
    }
  }

  @objc func floatingSettingsTapped() {
    hideFloatingActionMenu()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
      self.presentSettings()
    }
  }

  @objc func floatingHelpTapped() {
    hideFloatingActionMenu()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
      self.presentHelp()
    }
  }
}

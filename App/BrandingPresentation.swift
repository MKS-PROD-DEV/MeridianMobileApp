import UIKit
import WebKit

extension MyViewController {
  func presentInitialSiteSelectionIfNeeded() {
    print("hasSelectedBranding:", AppConfiguration.hasSelectedBranding)

    guard !AppConfiguration.hasSelectedBranding else { return }
    guard !hasPresentedInitialSiteSelection else { return }
    guard presentedViewController == nil else { return }

    hasPresentedInitialSiteSelection = true

    let viewController = InitialSiteSelectionViewController { [weak self] branding in
      AppConfiguration.branding = branding
      self?.dismiss(animated: true) {
        self?.handleBrandingSelectionApplied()
      }
    }

    present(viewController, animated: true)
  }

  func handleBrandingSelectionApplied() {
    if let webView = self.webView {
      webView.load(URLRequest(url: AppConfiguration.launchURL))
      AppTheme.applyNavigationBarAppearance(to: navigationController)
      applyFloatingActionMenuBranding()
    }

    floatingMenuButton.backgroundColor = .systemBackground

    if let icon = AppTheme.logoImage {
      floatingMenuButton.setImage(icon, for: .normal)
      floatingMenuButton.setTitle(nil, for: .normal)
    } else {
      floatingMenuButton.setImage(nil, for: .normal)
      floatingMenuButton.setTitle(AppTheme.shortText, for: .normal)
    }

    startupLogoButton.backgroundColor = .clear
    if let icon = AppTheme.logoImage {
      startupLogoButton.setImage(icon, for: .normal)
      startupLogoButton.setTitle(nil, for: .normal)
    } else {
      startupLogoButton.setImage(nil, for: .normal)
      startupLogoButton.setTitle(AppTheme.shortText, for: .normal)
      startupLogoButton.setTitleColor(.black, for: .normal)
    }

    loadingFillView.backgroundColor = AppTheme.primaryColor
  }

  func dismissPresentedContentIfNeeded(completion: @escaping () -> Void) {
    if let presented = presentedViewController,
      !(presented is UIAlertController) {
      presented.dismiss(animated: true) {
        completion()
      }
    } else {
      completion()
    }
  }

  func presentCourseList() {
    let items = ScormUtils.loadOfflineLibraryItems()
    let viewController = ScormCourseListViewController(items: items)
    let nav = UINavigationController(rootViewController: viewController)
    AppTheme.applyNavigationBarAppearance(to: nav)
    nav.modalPresentationStyle = .pageSheet
    present(nav, animated: true)
  }

  func presentSettings() {
    let viewController = SettingsViewController { [weak self] _ in
      self?.handleBrandingSelectionApplied()
    }
    let nav = UINavigationController(rootViewController: viewController)
    AppTheme.applyNavigationBarAppearance(to: nav)
    nav.modalPresentationStyle = .pageSheet
    present(nav, animated: true)
  }

  func presentHelp() {
    let viewController = HelpViewController()
    let nav = UINavigationController(rootViewController: viewController)
    AppTheme.applyNavigationBarAppearance(to: nav)
    nav.modalPresentationStyle = .pageSheet
    present(nav, animated: true)
  }

  func presentScormLessonList(assetId: String) {
    do {
      let course = try ScormUtils.loadCourse(assetId: assetId)

      let viewController = ScormLessonListViewController(
        assetId: course.assetId,
        scormDir: course.scormDir,
        manifest: course.manifest
      )

      let nav = UINavigationController(rootViewController: viewController)
      nav.modalPresentationStyle = .formSheet
      present(nav, animated: true)
    } catch {
      print("SCORM error:", error)
    }
  }
}

/*
  Offline content launcher.
  - Launches content from APP Directory
*/
import UIKit

enum OfflineContentLauncher {
  static func presentContent(_ item: OfflineContentItem, from presenter: UIViewController) {
    let viewController: UIViewController

    switch item.type {
    case .video:
      viewController = OfflineVideoPlayerViewController(fileURL: item.fileURL, title: item.title)

    case .pdf, .document, .web:
      viewController = OfflineDocumentViewController(fileURL: item.fileURL, title: item.title)

    case .scorm, .unsupported:
      let alert = UIAlertController(
        title: L10n.tr("offline_content.unsupported.title"),
        message: L10n.tr("offline_content.unsupported.message"),
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
      presenter.present(alert, animated: true)
      return
    }

    let nav = UINavigationController(rootViewController: viewController)
    nav.modalPresentationStyle = .fullScreen
    presenter.present(nav, animated: true)
  }
}

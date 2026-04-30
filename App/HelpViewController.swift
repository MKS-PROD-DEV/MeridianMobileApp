import UIKit

final class HelpViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()

    title = "Help"
    view.backgroundColor = .systemBackground

    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close,
      target: self,
      action: #selector(close)
    )
  }

  @objc private func close() {
    dismiss(animated: true)
  }
}

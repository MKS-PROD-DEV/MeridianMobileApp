/*
  Offline Document launcher.
  - Launches Documents from APP Directory
*/
import UIKit
import QuickLook
import PDFKit

final class OfflineDocumentViewController: UIViewController, QLPreviewControllerDataSource {
  private let fileURL: URL
  private let displayTitle: String

  init(fileURL: URL, title: String?) {
    self.fileURL = fileURL
    self.displayTitle = title ?? fileURL.lastPathComponent
    super.init(nibName: nil, bundle: nil)
    self.title = self.displayTitle
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
      action: #selector(closeTapped)
    )

    if fileURL.pathExtension.lowercased() == "pdf",
      let pdfDocument = PDFDocument(url: fileURL) {
      let pdfView = PDFView()
      pdfView.translatesAutoresizingMaskIntoConstraints = false
      pdfView.autoScales = true
      pdfView.document = pdfDocument

      view.addSubview(pdfView)
      NSLayoutConstraint.activate([
        pdfView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        pdfView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
      ])
      return
    }

    let previewController = QLPreviewController()
    previewController.dataSource = self

    addChild(previewController)
    view.addSubview(previewController.view)
    previewController.view.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      previewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      previewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      previewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      previewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])

    previewController.didMove(toParent: self)
  }

  func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
    1
  }

  func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
    fileURL as NSURL
  }

  @objc private func closeTapped() {
    dismiss(animated: true)
  }
}

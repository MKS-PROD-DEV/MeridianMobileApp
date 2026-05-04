import UIKit
import AVFoundation

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
  private let onCodeScanned: (String) -> Void
  private let captureSession = AVCaptureSession()
  private var previewLayer: AVCaptureVideoPreviewLayer?
  private var hasScannedCode = false

  init(onCodeScanned: @escaping (String) -> Void) {
    self.onCodeScanned = onCodeScanned
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .fullScreen
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    configureCamera()
    configureOverlay()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    previewLayer?.frame = view.bounds
  }

  private func configureCamera() {
    guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
      presentCameraUnavailableAlert()
      return
    }

    guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
      presentCameraUnavailableAlert()
      return
    }

    if captureSession.canAddInput(videoInput) {
      captureSession.addInput(videoInput)
    } else {
      presentCameraUnavailableAlert()
      return
    }

    let metadataOutput = AVCaptureMetadataOutput()

    if captureSession.canAddOutput(metadataOutput) {
      captureSession.addOutput(metadataOutput)
      metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
      metadataOutput.metadataObjectTypes = [.qr]
    } else {
      presentCameraUnavailableAlert()
      return
    }

    let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer.videoGravity = .resizeAspectFill
    previewLayer.frame = view.layer.bounds
    view.layer.addSublayer(previewLayer)
    self.previewLayer = previewLayer

    DispatchQueue.global(qos: .userInitiated).async {
      self.captureSession.startRunning()
    }
  }

  private func configureOverlay() {
    let closeButton = UIButton(type: .system)
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    closeButton.setTitle(L10n.tr("common.close"), for: .normal)
    closeButton.setTitleColor(.white, for: .normal)
    closeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
    closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

    let instructionLabel = UILabel()
    instructionLabel.translatesAutoresizingMaskIntoConstraints = false
    instructionLabel.text = L10n.tr("site_selection.qr.scan_instruction")
    instructionLabel.textColor = .white
    instructionLabel.font = .systemFont(ofSize: 17, weight: .medium)
    instructionLabel.textAlignment = .center
    instructionLabel.numberOfLines = 0
    instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.35)
    instructionLabel.layer.cornerRadius = 12
    instructionLabel.layer.masksToBounds = true

    view.addSubview(closeButton)
    view.addSubview(instructionLabel)

    NSLayoutConstraint.activate([
      closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

      instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
      instructionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
      instructionLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
    ])
  }

  func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
    guard !hasScannedCode,
          let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
          metadataObject.type == .qr,
          let stringValue = metadataObject.stringValue else {
      return
    }

    hasScannedCode = true
    captureSession.stopRunning()
    dismiss(animated: true) {
      self.onCodeScanned(stringValue)
    }
  }

  @objc private func closeTapped() {
    if captureSession.isRunning {
      captureSession.stopRunning()
    }
    dismiss(animated: true)
  }

  private func presentCameraUnavailableAlert() {
    let alert = UIAlertController(
      title: L10n.tr("site_selection.qr.camera_unavailable.title"),
      message: L10n.tr("site_selection.qr.camera_unavailable.message"),
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default, handler: { [weak self] _ in
      self?.dismiss(animated: true)
    }))
    present(alert, animated: true)
  }
}

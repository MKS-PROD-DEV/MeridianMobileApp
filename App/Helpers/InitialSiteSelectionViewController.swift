/*
  Initial site onboarding controller.
  - QR scan
  - QR image upload
*/
import UIKit
import AVFoundation
import PhotosUI
import CoreImage

final class InitialSiteSelectionViewController: UIViewController, PHPickerViewControllerDelegate {
  private let onConfirm: (Branding) -> Void
  private var selectedBranding: Branding?

  private let detector = CIDetector(
    ofType: CIDetectorTypeQRCode,
    context: nil,
    options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
  )

  private let scrollView: UIScrollView = {
    let view = UIScrollView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.alwaysBounceVertical = true
    view.keyboardDismissMode = .onDrag
    return view
  }()

  private let contentView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private let logoContainerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = AppTheme.secondaryBackgroundColor
    view.layer.cornerRadius = 22
    return view
  }()

  private let logoImageView: UIImageView = {
    let imageView = UIImageView(image: UIImage(named: "MGLogo"))
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.contentMode = .scaleAspectFit
    return imageView
  }()

  private let titleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = L10n.tr("site_selection.qr_only.title")
    label.font = AppTheme.titleFont
    label.textAlignment = .center
    label.textColor = AppTheme.primaryTextColor
    label.numberOfLines = 0
    return label
  }()

  private let subtitleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = L10n.tr("site_selection.qr_only.subtitle")
    label.font = AppTheme.bodyFont
    label.textAlignment = .center
    label.textColor = AppTheme.secondaryTextColor
    label.numberOfLines = 0
    return label
  }()

  private let scanQRButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    AppTheme.stylePrimaryButton(button)
    button.setTitle(L10n.tr("site_selection.qr.scan"), for: .normal)
    return button
  }()

  private let uploadQRButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    AppTheme.styleSecondaryButton(button)
    button.setTitle(L10n.tr("site_selection.qr.upload"), for: .normal)
    return button
  }()

  private let helperLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = L10n.tr("site_selection.qr_only.helper")
    label.font = AppTheme.secondaryFont
    label.textAlignment = .center
    label.textColor = AppTheme.secondaryTextColor
    label.numberOfLines = 0
    return label
  }()

  init(onConfirm: @escaping (Branding) -> Void) {
    self.onConfirm = onConfirm
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .fullScreen
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = AppTheme.groupedBackgroundColor
    configureMeridianBrandingAppearance()
    scanQRButton.addTarget(self, action: #selector(scanQRTapped), for: .touchUpInside)
    uploadQRButton.addTarget(self, action: #selector(uploadQRTapped), for: .touchUpInside)
    setupLayout()
  }

  private func configureMeridianBrandingAppearance() {
    // Intentionally keep this screen on Meridian branding visuals
    // until a QR code is successfully scanned and mapped.
  }

  private func setupLayout() {
    view.addSubview(scrollView)
    scrollView.addSubview(contentView)

    contentView.addSubview(logoContainerView)
    logoContainerView.addSubview(logoImageView)
    contentView.addSubview(titleLabel)
    contentView.addSubview(subtitleLabel)
    contentView.addSubview(scanQRButton)
    contentView.addSubview(uploadQRButton)
    contentView.addSubview(helperLabel)

    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
      contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
      contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

      logoContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 48),
      logoContainerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
      logoContainerView.widthAnchor.constraint(equalToConstant: 112),
      logoContainerView.heightAnchor.constraint(equalToConstant: 112),

      logoImageView.centerXAnchor.constraint(equalTo: logoContainerView.centerXAnchor),
      logoImageView.centerYAnchor.constraint(equalTo: logoContainerView.centerYAnchor),
      logoImageView.widthAnchor.constraint(equalToConstant: 76),
      logoImageView.heightAnchor.constraint(equalToConstant: 76),

      titleLabel.topAnchor.constraint(equalTo: logoContainerView.bottomAnchor, constant: 24),
      titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.screenHorizontalPadding),
      titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.screenHorizontalPadding),

      subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
      subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.screenHorizontalPadding),
      subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.screenHorizontalPadding),

      scanQRButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
      scanQRButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.screenHorizontalPadding),
      scanQRButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.screenHorizontalPadding),
      scanQRButton.heightAnchor.constraint(equalToConstant: 54),

      uploadQRButton.topAnchor.constraint(equalTo: scanQRButton.bottomAnchor, constant: 14),
      uploadQRButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.screenHorizontalPadding),
      uploadQRButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.screenHorizontalPadding),
      uploadQRButton.heightAnchor.constraint(equalToConstant: 54),

      helperLabel.topAnchor.constraint(equalTo: uploadQRButton.bottomAnchor, constant: 18),
      helperLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.screenHorizontalPadding),
      helperLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.screenHorizontalPadding),
      helperLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
    ])
  }

  @objc private func scanQRTapped() {
    let scanner = QRScannerViewController { [weak self] scannedString in
      self?.handleScannedQRCodeString(scannedString)
    }
    present(scanner, animated: true)
  }

  @objc private func uploadQRTapped() {
    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .images
    configuration.selectionLimit = 1

    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    present(picker, animated: true)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    dismiss(animated: true)

    guard let result = results.first else { return }
    guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else {
      presentGenericQRFailureAlert()
      return
    }

    result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
      guard let self = self else { return }

      DispatchQueue.main.async {
        guard let image = object as? UIImage else {
          self.presentGenericQRFailureAlert()
          return
        }

        guard let scannedString = self.extractQRCodeString(from: image) else {
          self.presentInvalidQRCodeAlert()
          return
        }

        self.handleScannedQRCodeString(scannedString)
      }
    }
  }

  private func extractQRCodeString(from image: UIImage) -> String? {
    guard let ciImage = CIImage(image: image),
      let detector else { return nil }

    let features = detector.features(in: ciImage)
    let qrFeature = features.compactMap { $0 as? CIQRCodeFeature }.first
    return qrFeature?.messageString
  }

  private func handleScannedQRCodeString(_ scannedString: String) {
    guard let url = URL(string: scannedString),
      let branding = Branding.from(siteURL: url) else {
      presentUnknownSiteAlert()
      return
    }

    selectedBranding = branding
    AppConfiguration.branding = branding
    onConfirm(branding)
  }

  private func presentUnknownSiteAlert() {
    let alert = UIAlertController(
      title: L10n.tr("site_selection.qr.invalid_site.title"),
      message: L10n.tr("site_selection.qr.invalid_site.message"),
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
    present(alert, animated: true)
  }

  private func presentInvalidQRCodeAlert() {
    let alert = UIAlertController(
      title: L10n.tr("site_selection.qr.invalid_code.title"),
      message: L10n.tr("site_selection.qr.invalid_code.message"),
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
    present(alert, animated: true)
  }

  private func presentGenericQRFailureAlert() {
    let alert = UIAlertController(
      title: L10n.tr("site_selection.qr.read_failed.title"),
      message: L10n.tr("site_selection.qr.read_failed.message"),
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
    present(alert, animated: true)
  }
}

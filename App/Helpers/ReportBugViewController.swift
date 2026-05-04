/*
  Native bug reporting screen.
  - collecting issue details from the user
  - supporting screenshots and diagnostic details
*/
import UIKit
import MessageUI
import PhotosUI

final class ReportBugViewController: UIViewController {

  private let scrollView = UIScrollView()
  private let contentStack = UIStackView()

  private let categoryField = UITextField()
  private let titleField = UITextField()
  private let emailField = UITextField()
  private let descriptionTextView = UITextView()
  private let descriptionPlaceholderLabel = UILabel()
  private let includeDiagnosticsSwitch = UISwitch()
  private let attachLogsSwitch = UISwitch()
  private let submitButton = UIButton(type: .system)

  private let screenshotCard = UIView()
  private let screenshotPreviewImageView = UIImageView()
  private let screenshotTitleLabel = UILabel()
  private let screenshotSubtitleLabel = UILabel()
  private let screenshotButton = UIButton(type: .system)
  private let removeScreenshotButton = UIButton(type: .system)

  private var selectedScreenshot: UIImage? {
    didSet {
      updateScreenshotUI()
    }
  }

  private var categories: [String] {
    [
      L10n.tr("report_bug.category.login_access"),
      L10n.tr("report_bug.category.offline_courses"),
      L10n.tr("report_bug.category.scorm_playback"),
      L10n.tr("report_bug.category.progress_resume"),
      L10n.tr("report_bug.category.downloads"),
      L10n.tr("report_bug.category.performance"),
      L10n.tr("report_bug.category.ui_visual_issue"),
      L10n.tr("report_bug.category.other")
    ]
  }

  private lazy var categoryPicker: UIPickerView = {
    let picker = UIPickerView()
    picker.dataSource = self
    picker.delegate = self
    return picker
  }()

  override func viewDidLoad() {
    super.viewDidLoad()

    configureView()
    configureNavigation()
    configureLayout()
    buildContent()
    applyInitialValues()
    AppTheme.applyNavigationBarAppearance(to: navigationController)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
      categoryPicker.reloadAllComponents()
      if categoryField.isFirstResponder {
        let selectedRow = categoryPicker.selectedRow(inComponent: 0)
        if categories.indices.contains(selectedRow) {
          categoryField.text = categories[selectedRow]
        }
      }
    }

  private func configureView() {
    title = L10n.tr("report_bug.title")
    view.backgroundColor = AppTheme.groupedBackgroundColor

    scrollView.alwaysBounceVertical = true
    scrollView.keyboardDismissMode = .interactive
    scrollView.translatesAutoresizingMaskIntoConstraints = false

    contentStack.axis = .vertical
    contentStack.spacing = 16
    contentStack.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(scrollView)
    scrollView.addSubview(contentStack)

    let tap = UITapGestureRecognizer(target: self, action: #selector(endEditingTapped))
    tap.cancelsTouchesInView = false
    view.addGestureRecognizer(tap)
  }

  private func configureNavigation() {
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close,
      target: self,
      action: #selector(close)
    )
  }

  private func configureLayout() {
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
      contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
      contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
      contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32)
    ])
  }

  private func buildContent() {
    contentStack.addArrangedSubview(makeBrandHeader())
    contentStack.addArrangedSubview(makeIntroCard())
    contentStack.addArrangedSubview(makeFormCard())
    contentStack.addArrangedSubview(makeScreenshotCard())
    contentStack.addArrangedSubview(makeSubmitSection())
  }

  private func applyInitialValues() {
    categoryField.text = categories.first
    includeDiagnosticsSwitch.isOn = true
    attachLogsSwitch.isOn = true
    updateDescriptionPlaceholderVisibility()
    updateScreenshotUI()
  }

  private func makeBrandHeader() -> UIView {
    let card = makeCardView()
    card.backgroundColor = AppTheme.primaryColor.withAlphaComponent(0.08)

    let logoView = UIImageView()
    logoView.translatesAutoresizingMaskIntoConstraints = false
    logoView.contentMode = .scaleAspectFit
    logoView.clipsToBounds = true

    if let logo = AppTheme.logoImage {
      logoView.image = logo
    } else {
      logoView.image = UIImage(systemName: "exclamationmark.bubble.fill")
      logoView.tintColor = AppTheme.primaryColor
      logoView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 40, weight: .bold)
    }

    let titleLabel = UILabel()
    titleLabel.text = L10n.tr("report_bug.title")
    titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
    titleLabel.textColor = AppTheme.primaryTextColor
    titleLabel.textAlignment = .center

    let subtitleLabel = UILabel()
    subtitleLabel.text = L10n.tr("report_bug.subtitle")
    subtitleLabel.font = AppTheme.secondaryFont
    subtitleLabel.textColor = AppTheme.secondaryTextColor
    subtitleLabel.textAlignment = .center
    subtitleLabel.numberOfLines = 0

    let stack = UIStackView(arrangedSubviews: [logoView, titleLabel, subtitleLabel])
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 14
    stack.translatesAutoresizingMaskIntoConstraints = false

    card.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
      stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
      stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
      stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),

      logoView.heightAnchor.constraint(equalToConstant: 72),
      logoView.widthAnchor.constraint(lessThanOrEqualToConstant: 220)
    ])

    return card
  }

  private func makeIntroCard() -> UIView {
    makeInfoCard(
      title: L10n.tr("report_bug.before_submit.title"),
      systemImage: "info.circle.fill",
      body: L10n.tr("report_bug.before_submit.body")
    )
  }

  private func makeFormCard() -> UIView {
    let card = makeCardView()

    let header = makeSectionHeader(title: L10n.tr("report_bug.details.title"), systemImage: "square.and.pencil")

    configureTextField(
      categoryField,
      placeholder: L10n.tr("report_bug.category.placeholder"),
      systemImage: "tag.fill"
    )
    categoryField.inputView = categoryPicker

    let pickerToolbar = UIToolbar()
    pickerToolbar.sizeToFit()
    pickerToolbar.items = [
      UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
      UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(donePickingCategory))
    ]
    categoryField.inputAccessoryView = pickerToolbar

    configureTextField(
      titleField,
      placeholder: L10n.tr("report_bug.summary.placeholder"),
      systemImage: "text.bubble.fill"
    )

    configureTextField(
      emailField,
      placeholder: L10n.tr("report_bug.email.placeholder"),
      systemImage: "envelope.fill"
    )
    emailField.keyboardType = .emailAddress
    emailField.autocapitalizationType = .none
    emailField.autocorrectionType = .no

    let descriptionLabel = UILabel()
    descriptionLabel.text = L10n.tr("report_bug.description.title")
    descriptionLabel.font = .systemFont(ofSize: 15, weight: .semibold)
    descriptionLabel.textColor = AppTheme.primaryTextColor

    let descriptionContainer = UIView()
    descriptionContainer.backgroundColor = AppTheme.secondaryBackgroundColor
    descriptionContainer.layer.cornerRadius = AppTheme.cornerRadius
    descriptionContainer.layer.borderWidth = 1
    descriptionContainer.layer.borderColor = AppTheme.separatorColor.withAlphaComponent(0.15).cgColor

    descriptionTextView.translatesAutoresizingMaskIntoConstraints = false
    descriptionTextView.backgroundColor = .clear
    descriptionTextView.font = AppTheme.bodyFont
    descriptionTextView.textColor = AppTheme.primaryTextColor
    descriptionTextView.delegate = self
    descriptionTextView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)

    descriptionPlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false
    descriptionPlaceholderLabel.text = L10n.tr("report_bug.description.placeholder")
    descriptionPlaceholderLabel.font = AppTheme.bodyFont
    descriptionPlaceholderLabel.textColor = AppTheme.secondaryTextColor
    descriptionPlaceholderLabel.numberOfLines = 0

    descriptionContainer.addSubview(descriptionTextView)
    descriptionContainer.addSubview(descriptionPlaceholderLabel)

    NSLayoutConstraint.activate([
      descriptionTextView.topAnchor.constraint(equalTo: descriptionContainer.topAnchor),
      descriptionTextView.leadingAnchor.constraint(equalTo: descriptionContainer.leadingAnchor),
      descriptionTextView.trailingAnchor.constraint(equalTo: descriptionContainer.trailingAnchor),
      descriptionTextView.bottomAnchor.constraint(equalTo: descriptionContainer.bottomAnchor),
      descriptionTextView.heightAnchor.constraint(equalToConstant: 180),

      descriptionPlaceholderLabel.topAnchor.constraint(equalTo: descriptionContainer.topAnchor, constant: 14),
      descriptionPlaceholderLabel.leadingAnchor.constraint(equalTo: descriptionContainer.leadingAnchor, constant: 18),
      descriptionPlaceholderLabel.trailingAnchor.constraint(equalTo: descriptionContainer.trailingAnchor, constant: -18)
    ])

    let diagnosticsRow = makeSwitchRow(
      title: L10n.tr("report_bug.diagnostics.title"),
      subtitle: L10n.tr("report_bug.diagnostics.subtitle"),
      control: includeDiagnosticsSwitch
    )
    includeDiagnosticsSwitch.onTintColor = AppTheme.accentColor

    let logsRow = makeSwitchRow(
      title: L10n.tr("report_bug.logs.title"),
      subtitle: L10n.tr("report_bug.logs.subtitle"),
      control: attachLogsSwitch
    )
    attachLogsSwitch.onTintColor = AppTheme.accentColor

    let stack = UIStackView(arrangedSubviews: [
      header,
      categoryField,
      titleField,
      emailField,
      descriptionLabel,
      descriptionContainer,
      diagnosticsRow,
      logsRow
    ])
    stack.axis = .vertical
    stack.spacing = 14
    stack.translatesAutoresizingMaskIntoConstraints = false

    card.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
      stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
      stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
      stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
    ])

    return card
  }

  private func makeScreenshotCard() -> UIView {
    screenshotCard.backgroundColor = AppTheme.cardBackgroundColor
    screenshotCard.layer.cornerRadius = AppTheme.largeCornerRadius
    screenshotCard.layer.cornerCurve = .continuous
    screenshotCard.layer.borderWidth = 1
    screenshotCard.layer.borderColor = AppTheme.separatorColor.withAlphaComponent(0.10).cgColor

    let header = makeSectionHeader(title: L10n.tr("report_bug.screenshot.title"), systemImage: "photo.on.rectangle.angled")

    screenshotPreviewImageView.translatesAutoresizingMaskIntoConstraints = false
    screenshotPreviewImageView.contentMode = .scaleAspectFill
    screenshotPreviewImageView.clipsToBounds = true
    screenshotPreviewImageView.layer.cornerRadius = 12
    screenshotPreviewImageView.backgroundColor = AppTheme.secondaryBackgroundColor
    screenshotPreviewImageView.heightAnchor.constraint(equalToConstant: 160).isActive = true

    screenshotTitleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
    screenshotTitleLabel.textColor = AppTheme.primaryTextColor

    screenshotSubtitleLabel.font = AppTheme.secondaryFont
    screenshotSubtitleLabel.textColor = AppTheme.secondaryTextColor
    screenshotSubtitleLabel.numberOfLines = 0

    AppTheme.styleSecondaryButton(screenshotButton)
    screenshotButton.setTitle(L10n.tr("report_bug.screenshot.choose"), for: .normal)
    screenshotButton.translatesAutoresizingMaskIntoConstraints = false
    screenshotButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
    screenshotButton.addTarget(self, action: #selector(selectScreenshotTapped), for: .touchUpInside)

    removeScreenshotButton.setTitle(L10n.tr("common.remove"), for: .normal)
    removeScreenshotButton.setTitleColor(AppTheme.destructiveColor, for: .normal)
    removeScreenshotButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
    removeScreenshotButton.addTarget(self, action: #selector(removeScreenshotTapped), for: .touchUpInside)

    let buttonRow = UIStackView(arrangedSubviews: [screenshotButton, removeScreenshotButton])
    buttonRow.axis = .horizontal
    buttonRow.spacing = 12
    buttonRow.distribution = .fillEqually

    let textStack = UIStackView(arrangedSubviews: [screenshotTitleLabel, screenshotSubtitleLabel])
    textStack.axis = .vertical
    textStack.spacing = 4

    let stack = UIStackView(arrangedSubviews: [header, screenshotPreviewImageView, textStack, buttonRow])
    stack.axis = .vertical
    stack.spacing = 14
    stack.translatesAutoresizingMaskIntoConstraints = false

    screenshotCard.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: screenshotCard.topAnchor, constant: 18),
      stack.leadingAnchor.constraint(equalTo: screenshotCard.leadingAnchor, constant: 18),
      stack.trailingAnchor.constraint(equalTo: screenshotCard.trailingAnchor, constant: -18),
      stack.bottomAnchor.constraint(equalTo: screenshotCard.bottomAnchor, constant: -18)
    ])

    return screenshotCard
  }

  private func makeSubmitSection() -> UIView {
    let container = UIView()

    AppTheme.stylePrimaryButton(submitButton)
    submitButton.setTitle(L10n.tr("report_bug.submit"), for: .normal)
    submitButton.translatesAutoresizingMaskIntoConstraints = false
    submitButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
    submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)

    let noteLabel = UILabel()
    noteLabel.text = L10n.tr("report_bug.submit.note")
    noteLabel.font = AppTheme.secondaryFont
    noteLabel.textColor = AppTheme.secondaryTextColor
    noteLabel.numberOfLines = 0
    noteLabel.textAlignment = .center

    let stack = UIStackView(arrangedSubviews: [submitButton, noteLabel])
    stack.axis = .vertical
    stack.spacing = 10
    stack.translatesAutoresizingMaskIntoConstraints = false

    container.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: container.topAnchor),
      stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])

    return container
  }

  private func makeInfoCard(title: String, systemImage: String, body: String) -> UIView {
    let card = makeCardView()

    let header = makeSectionHeader(title: title, systemImage: systemImage)

    let bodyLabel = UILabel()
    bodyLabel.text = body
    bodyLabel.textColor = AppTheme.secondaryTextColor
    bodyLabel.font = AppTheme.bodyFont
    bodyLabel.numberOfLines = 0

    let stack = UIStackView(arrangedSubviews: [header, bodyLabel])
    stack.axis = .vertical
    stack.spacing = 14
    stack.translatesAutoresizingMaskIntoConstraints = false

    card.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
      stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
      stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
      stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
    ])

    return card
  }

  private func makeSectionHeader(title: String, systemImage: String) -> UIView {
    let imageView = UIImageView(image: UIImage(systemName: systemImage))
    imageView.tintColor = AppTheme.primaryColor
    imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
    imageView.setContentHuggingPriority(.required, for: .horizontal)

    let label = UILabel()
    label.text = title
    label.font = AppTheme.sectionTitleFont
    label.textColor = AppTheme.primaryTextColor
    label.numberOfLines = 0

    let stack = UIStackView(arrangedSubviews: [imageView, label])
    stack.axis = .horizontal
    stack.spacing = 10
    stack.alignment = .center

    return stack
  }

  private func configureTextField(_ textField: UITextField, placeholder: String, systemImage: String) {
    textField.translatesAutoresizingMaskIntoConstraints = false
    textField.backgroundColor = AppTheme.secondaryBackgroundColor
    textField.textColor = AppTheme.primaryTextColor
    textField.font = AppTheme.bodyFont
    textField.attributedPlaceholder = NSAttributedString(
      string: placeholder,
      attributes: [.foregroundColor: AppTheme.secondaryTextColor]
    )
    textField.layer.cornerRadius = AppTheme.cornerRadius
    textField.layer.borderWidth = 1
    textField.layer.borderColor = AppTheme.separatorColor.withAlphaComponent(0.15).cgColor
    textField.heightAnchor.constraint(equalToConstant: 52).isActive = true

    let iconView = UIImageView(image: UIImage(systemName: systemImage))
    iconView.tintColor = AppTheme.primaryColor
    iconView.contentMode = .scaleAspectFit
    iconView.frame = CGRect(x: 0, y: 0, width: 18, height: 18)

    let leftContainer = UIView(frame: CGRect(x: 0, y: 0, width: 42, height: 52))
    iconView.center = CGPoint(x: leftContainer.bounds.midX, y: leftContainer.bounds.midY)
    leftContainer.addSubview(iconView)

    textField.leftView = leftContainer
    textField.leftViewMode = .always
  }

  private func makeSwitchRow(title: String, subtitle: String, control: UISwitch) -> UIView {
    let titleLabel = UILabel()
    titleLabel.text = title
    titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
    titleLabel.textColor = AppTheme.primaryTextColor

    let subtitleLabel = UILabel()
    subtitleLabel.text = subtitle
    subtitleLabel.font = AppTheme.secondaryFont
    subtitleLabel.textColor = AppTheme.secondaryTextColor
    subtitleLabel.numberOfLines = 0

    let labels = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
    labels.axis = .vertical
    labels.spacing = 4

    let row = UIStackView(arrangedSubviews: [labels, control])
    row.axis = .horizontal
    row.spacing = 12
    row.alignment = .center

    return row
  }

  private func makeCardView() -> UIView {
    let card = UIView()
    card.backgroundColor = AppTheme.cardBackgroundColor
    card.layer.cornerRadius = AppTheme.largeCornerRadius
    card.layer.cornerCurve = .continuous
    card.layer.borderWidth = 1
    card.layer.borderColor = AppTheme.separatorColor.withAlphaComponent(0.10).cgColor
    card.layer.shadowColor = UIColor.black.withAlphaComponent(0.04).cgColor
    card.layer.shadowOpacity = 1
    card.layer.shadowRadius = 10
    card.layer.shadowOffset = CGSize(width: 0, height: 4)
    return card
  }

  private func updateScreenshotUI() {
    let hasScreenshot = selectedScreenshot != nil

    screenshotPreviewImageView.image = selectedScreenshot
    screenshotPreviewImageView.isHidden = !hasScreenshot
    removeScreenshotButton.isHidden = !hasScreenshot
    screenshotTitleLabel.text = hasScreenshot
      ? L10n.tr("report_bug.screenshot.attached")
        : L10n.tr("report_bug.screenshot.none")
    screenshotSubtitleLabel.text = hasScreenshot
      ? L10n.tr("report_bug.screenshot.attached_subtitle")
        : L10n.tr("report_bug.screenshot.none_subtitle")
    screenshotButton.setTitle(
      hasScreenshot ? L10n.tr("report_bug.screenshot.change") : L10n.tr("report_bug.screenshot.choose"),
        for: .normal
      )
  }

  @objc private func donePickingCategory() {
    let selected = categoryPicker.selectedRow(inComponent: 0)
    categoryField.text = categories[selected]
    categoryField.resignFirstResponder()
  }

  @objc private func selectScreenshotTapped() {
    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .images
    configuration.selectionLimit = 1

    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    present(picker, animated: true)
  }

  @objc private func removeScreenshotTapped() {
    selectedScreenshot = nil
  }

  @objc private func submitTapped() {
    guard let summary = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
      !summary.isEmpty else {
      presentAlert(title: L10n.tr("report_bug.validation.missing_summary.title"), message: L10n.tr("report_bug.validation.missing_summary.message"))
      return
    }

    let description = descriptionTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !description.isEmpty else {
      presentAlert(title: L10n.tr("report_bug.validation.missing_description.title"), message: L10n.tr("report_bug.validation.missing_description.message"))
      return
    }

    let subject = "[\(AppConfiguration.branding.displayName) iOS Bug] \(summary)"
    let body = buildEmailBody(summary: summary, description: description)

    if MFMailComposeViewController.canSendMail() {
      let composer = MFMailComposeViewController()
      composer.mailComposeDelegate = self
      composer.setToRecipients(["tweerasinghe@meridianks.com"])
      composer.setSubject(subject)
      composer.setMessageBody(body, isHTML: false)

      if attachLogsSwitch.isOn {
        attachLogs(to: composer)
      }

      if let screenshot = selectedScreenshot, let data = screenshot.jpegData(compressionQuality: 0.85) {
        composer.addAttachmentData(data, mimeType: "image/jpeg", fileName: "bug-screenshot.jpg")
      }

      present(composer, animated: true)
      return
    }

    presentMailUnavailableAlert(subject: subject, body: body)
  }

  private func buildEmailBody(summary: String, description: String) -> String {
    let category = categoryField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
      ? categoryField.text!
      : L10n.tr("report_bug.category.other")

    let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    var body = """
    Bug Report

    Branding: \(AppConfiguration.branding.fullName)
    Host: \(AppConfiguration.branding.hostDisplayName)
    Category: \(category)
    Summary: \(summary)
    Contact Email: \(email.isEmpty ? L10n.tr("report_bug.email.not_provided") : email)

    Description:
    \(description)
    """

    if includeDiagnosticsSwitch.isOn {
      body += """



      Diagnostics:
      \(buildDiagnostics())
      """
    }

    if attachLogsSwitch.isOn {
      body += """



      Logs:
      Attached as recent-app-logs.txt
      """
    }

    if selectedScreenshot != nil {
      body += """

      Screenshot:
      Attached as bug-screenshot.jpg
      """
    }

    return body
  }

  private func buildDiagnostics() -> String {
    let bundle = Bundle.main
    let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? L10n.tr("common.unknown")
    let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? L10n.tr("common.unknown")
    let device = UIDevice.current

    return """
    App Version: \(version)
    Build: \(build)
    iOS Version: \(device.systemVersion)
    Device: \(device.model)
    Branding: \(AppConfiguration.branding.rawValue)
    Launch URL: \(AppConfiguration.launchURL.absoluteString)
    Notifications Enabled: \(UserDefaults.standard.object(forKey: "settings.notifications.enabled") as? Bool ?? true)
    """
  }

  private func attachLogs(to composer: MFMailComposeViewController) {
    let logs = AppLogStore.shared.exportLogs()
    guard let data = logs.data(using: .utf8), !data.isEmpty else { return }
    composer.addAttachmentData(data, mimeType: "text/plain", fileName: "recent-app-logs.txt")
  }

  private func updateDescriptionPlaceholderVisibility() {
    let text = descriptionTextView.text ?? ""
    descriptionPlaceholderLabel.isHidden = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func presentAlert(title: String, message: String) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
    present(alert, animated: true)
  }

  private func presentMailUnavailableAlert(subject: String, body: String) {
    let alert = UIAlertController(
      title: L10n.tr("report_bug.mail_unavailable.title"),
      message: L10n.tr("report_bug.mail_unavailable.message"),
      preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: L10n.tr("report_bug.copy_report"), style: .default, handler: { _ in
      UIPasteboard.general.string = "Subject: \(subject)\n\n\(body)"
      self.presentSubmissionSuccessState(
        title: L10n.tr("report_bug.copied.title"),
        message: L10n.tr("report_bug.copied.message"),
      )
    }))

    alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
    present(alert, animated: true)
  }

  private func presentSubmissionSuccessState(title: String, message: String) {
    let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)

    let iconAttachment = NSTextAttachment()
    iconAttachment.image = UIImage(systemName: "checkmark.circle.fill")?
      .withTintColor(AppTheme.primaryColor, renderingMode: .alwaysOriginal)

    let attributedTitle = NSMutableAttributedString(attachment: iconAttachment)
    attributedTitle.append(NSAttributedString(string: "\n\n\(title)", attributes: [
      .font: UIFont.systemFont(ofSize: 20, weight: .bold),
      .foregroundColor: AppTheme.primaryTextColor
    ]))

    let attributedMessage = NSAttributedString(string: message, attributes: [
      .font: UIFont.systemFont(ofSize: 15, weight: .regular),
      .foregroundColor: AppTheme.secondaryTextColor
    ])

    alert.setValue(attributedTitle, forKey: "attributedTitle")
    alert.setValue(attributedMessage, forKey: "attributedMessage")
    alert.addAction(UIAlertAction(title: L10n.tr("common.done"), style: .default))

    present(alert, animated: true)
  }

  @objc private func close() {
    dismiss(animated: true)
  }

  @objc private func endEditingTapped() {
    view.endEditing(true)
  }
}

extension ReportBugViewController: UIPickerViewDataSource, UIPickerViewDelegate {
  func numberOfComponents(in pickerView: UIPickerView) -> Int {
    1
  }

  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    categories.count
  }

  func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
    categories[row]
  }

  func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    categoryField.text = categories[row]
  }
}

extension ReportBugViewController: UITextViewDelegate {
  func textViewDidChange(_ textView: UITextView) {
    updateDescriptionPlaceholderVisibility()
  }
}

extension ReportBugViewController: PHPickerViewControllerDelegate {
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)

    guard let itemProvider = results.first?.itemProvider,
      itemProvider.canLoadObject(ofClass: UIImage.self) else {
      return
    }

    itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
      guard let image = object as? UIImage else { return }

      DispatchQueue.main.async {
        self?.selectedScreenshot = image
      }
    }
  }
}

extension ReportBugViewController: MFMailComposeViewControllerDelegate {
  func mailComposeController(
    _ controller: MFMailComposeViewController,
    didFinishWith result: MFMailComposeResult,
    error: Error?
  ) {
    controller.dismiss(animated: true) {
      if let error = error {
        self.presentAlert(title: L10n.tr("report_bug.mail_error.title"), message: error.localizedDescription)
        return
      }

      switch result {
      case .sent:
        self.presentSubmissionSuccessState(
          title: L10n.tr("report_bug.sent.title"),
          message: L10n.tr("report_bug.sent.message")
        )
      case .saved:
        self.presentSubmissionSuccessState(
          title: L10n.tr("report_bug.saved.title"),
          message: L10n.tr("report_bug.saved.message")
        )
      case .failed:
        self.presentAlert(title: L10n.tr("report_bug.send_failed.title"), message: L10n.tr("report_bug.send_failed.message"))
      case .cancelled:
        break
      @unknown default:
        break
      }
    }
  }
}

// Log handler for Report Bug
final class AppLogStore {
  static let shared = AppLogStore()

  private let queue = DispatchQueue(label: "AppLogStore.queue", qos: .utility)
  private var entries: [String] = []
  private let maxEntries = 500

  private init() {}

  func log(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)"

    queue.sync {
      entries.append(line)

      if entries.count > maxEntries {
        entries.removeFirst(entries.count - maxEntries)
      }
    }

    print(line)
  }

  func exportLogs() -> String {
    queue.sync {
      if entries.isEmpty {
        return "[\(ISO8601DateFormatter().string(from: Date()))] No logs captured yet."
      }
      return entries.joined(separator: "\n")
    }
  }
}

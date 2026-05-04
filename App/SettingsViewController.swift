/*
  Native settings screen.
  - organization/site selection
  - app preferences
  - clearing downloaded SCORM content
  - showing local asset storage size
  - displaying app version/build information
  - entry point to bug reporting
*/
import UIKit

final class SettingsViewController: UITableViewController {
  private enum Section: Int, CaseIterable {
    case organization
    case preferences
    case language
    case storage
    case support
  }

    private var assetsSizeText: String {
      ScormUtils.formattedAssetsFolderSize()
    }

    private var appVersionText: String {
      let bundle = Bundle.main
      let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
      let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
      return String(format: L10n.tr("settings.version"), version, build)
    }

    private var copyrightText: String {
      let year = Calendar.current.component(.year, from: Date())
      return "© \(year) Meridian Knowledge Solutions."
    }

  private enum OrganizationRow: Int, CaseIterable {
    case site
  }

  private enum PreferencesRow: Int, CaseIterable {
    case notifications
    case testNotifications
    case darkMode
  }

  private enum LanguageRow: Int, CaseIterable {
    case appLanguage
  }

  private enum StorageRow: Int, CaseIterable {
    case clearDownloads
  }

  private enum SupportRow: Int, CaseIterable {
    case reportBug
  }

  private let notificationsKey = "settings.notifications.enabled"
  private let darkModeKey = "settings.appearance.darkMode.enabled"
  private let onBrandingChanged: ((Branding) -> Void)?

    private lazy var darkModeSwitch: UISwitch = {
      let control = UISwitch()
      control.onTintColor = AppTheme.accentColor
      control.isOn = UserDefaults.standard.bool(forKey: darkModeKey)
      control.addTarget(self, action: #selector(darkModeChanged(_:)), for: .valueChanged)
      return control
    }()

    private func applySavedAppearance() {
      let isDarkModeEnabled = UserDefaults.standard.bool(forKey: darkModeKey)
      let style: UIUserInterfaceStyle = isDarkModeEnabled ? .dark : .light

      UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .forEach { $0.overrideUserInterfaceStyle = style }
    }

  private lazy var notificationsSwitch: UISwitch = {
    let control = UISwitch()
    control.onTintColor = AppTheme.accentColor
    control.isOn = UserDefaults.standard.object(forKey: notificationsKey) as? Bool ?? true
    control.addTarget(self, action: #selector(notificationsChanged(_:)), for: .valueChanged)
    return control
  }()

  init(onBrandingChanged: ((Branding) -> Void)? = nil) {
    self.onBrandingChanged = onBrandingChanged
    super.init(style: .insetGrouped)
    title = L10n.tr("settings.title")
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = AppTheme.groupedBackgroundColor
    tableView.backgroundColor = AppTheme.groupedBackgroundColor
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 72
    tableView.sectionHeaderTopPadding = 16
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")

    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close,
      target: self,
      action: #selector(close)
    )

    AppTheme.applyNavigationBarAppearance(to: navigationController)
    applySavedAppearance()
  }
    override func viewWillAppear(_ animated: Bool) {
      super.viewWillAppear(animated)
      tableView.reloadData()
    }

  @objc private func close() {
    dismiss(animated: true)
  }

    @objc private func darkModeChanged(_ sender: UISwitch) {
      UserDefaults.standard.set(sender.isOn, forKey: darkModeKey)

      let style: UIUserInterfaceStyle = sender.isOn ? .dark : .light

      if let windowScene = view.window?.windowScene {
        windowScene.windows.forEach { $0.overrideUserInterfaceStyle = style }
      } else {
        UIApplication.shared.connectedScenes
          .compactMap { $0 as? UIWindowScene }
          .flatMap { $0.windows }
          .forEach { $0.overrideUserInterfaceStyle = style }
      }
    }

    @objc private func notificationsChanged(_ sender: UISwitch) {
      NotificationController.shared.updateNotificationPreference(enabled: sender.isOn)

      if sender.isOn {
        NotificationController.shared.requestAuthorizationIfNeeded()
      }
    }

    private func sendTestNotification() {
      guard notificationsSwitch.isOn else {
        let alert = UIAlertController(
          title: L10n.tr("settings.notifications_disabled.title"),
          message: L10n.tr("settings.notifications_disabled.message"),
          preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
        return
      }

      dismiss(animated: true) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          NotificationController.shared.scheduleSimpleNotification(
            title: L10n.tr("settings.test_notification.title"),
            body: L10n.tr("settings.test_notification.body"),
            timeInterval: 2
          )
        }
      }
    }

  override func numberOfSections(in tableView: UITableView) -> Int {
    Section.allCases.count
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    guard let section = Section(rawValue: section) else { return 0 }

    switch section {
    case .organization:
      return OrganizationRow.allCases.count
    case .preferences:
      return PreferencesRow.allCases.count
    case .language:
      return AppConfiguration.isLocalizationEnabled ? LanguageRow.allCases.count : 0
    case .storage:
      return StorageRow.allCases.count
    case .support:
      return SupportRow.allCases.count
    }
  }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
      guard let section = Section(rawValue: section) else { return nil }

      switch section {
      case .organization:
        return L10n.tr("settings.section.organization")
      case .preferences:
        return L10n.tr("settings.section.preferences")
      case .language:
        return AppConfiguration.isLocalizationEnabled ? L10n.tr("settings.section.language") : nil
      case .storage:
        return L10n.tr("settings.section.storage")
      case .support:
        return L10n.tr("settings.section.support")
      }
    }

    // Update this later (CPY SCORM)
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
      guard let section = Section(rawValue: section) else { return nil }

      switch section {
      case .organization:
        return L10n.tr("settings.footer.organization")
      case .preferences:
        return nil
      case .language:
        return AppConfiguration.isLocalizationEnabled ? L10n.tr("settings.footer.language") : nil
      case .storage:
        return L10n.tr("settings.footer.storage")
      case .support:
        return nil
      }
    }

    // Update this later (CPY SCORM)
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
      guard let section = Section(rawValue: section) else { return nil }

      switch section {
      case .support:
        let container = UIView()

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let messageLabel = UILabel()
        messageLabel.text = L10n.tr("settings.footer.support.message")
        messageLabel.font = AppTheme.secondaryFont
        messageLabel.textColor = AppTheme.secondaryTextColor
        messageLabel.numberOfLines = 0

        let versionLabel = UILabel()
        versionLabel.text = appVersionText
        versionLabel.font = AppTheme.secondaryFont
        versionLabel.textColor = AppTheme.secondaryTextColor
        versionLabel.numberOfLines = 0

        let copyrightButton = UIButton(type: .system)
        copyrightButton.setTitle(copyrightText, for: .normal)
        copyrightButton.setTitleColor(AppTheme.secondaryTextColor, for: .normal)
        copyrightButton.titleLabel?.font = AppTheme.secondaryFont
        copyrightButton.contentHorizontalAlignment = .left

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleCopyrightLongPress(_:)))
        longPress.minimumPressDuration = 2.0
        copyrightButton.addGestureRecognizer(longPress)

        stack.addArrangedSubview(messageLabel)
        stack.addArrangedSubview(versionLabel)
        stack.addArrangedSubview(copyrightButton)

        container.addSubview(stack)

        NSLayoutConstraint.activate([
          stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
          stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
          stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
          stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])

        return container

      default:
        return nil
      }
    }

    // Update this later (CPY SCORM)
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
      guard let section = Section(rawValue: section) else { return UITableView.automaticDimension }

      switch section {
      case .support:
        return 100
      default:
        return UITableView.automaticDimension
      }
    }

    // Remove this later (CPY SCORM)
    @objc private func handleCopyrightLongPress(_ gesture: UILongPressGestureRecognizer) {
      guard gesture.state == .began else { return }
      seedBundledCourses()
    }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let section = Section(rawValue: indexPath.section) else {
      return UITableViewCell()
    }

    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
    var content = cell.defaultContentConfiguration()

    content.textProperties.font = .systemFont(ofSize: 17, weight: .medium)
    content.textProperties.color = AppTheme.primaryTextColor
    content.secondaryTextProperties.font = AppTheme.secondaryFont
    content.secondaryTextProperties.color = AppTheme.secondaryTextColor
    content.secondaryTextProperties.numberOfLines = 0

    cell.accessoryView = nil
    cell.accessoryType = .none
    cell.selectionStyle = .default
    cell.tintColor = AppTheme.accentColor

    switch section {
    case .organization:
      content.text = L10n.tr("settings.organization.current")
      content.secondaryText = "\(AppConfiguration.branding.fullName) • \(AppConfiguration.branding.hostDisplayName)"
      cell.contentConfiguration = content
      cell.accessoryType = .disclosureIndicator

    case .preferences:
      guard let row = PreferencesRow(rawValue: indexPath.row) else { break }

      switch row {
      case .notifications:
        content.text = L10n.tr("settings.notifications")
        content.secondaryText = L10n.tr("settings.notifications.subtitle")
        cell.contentConfiguration = content
        cell.accessoryView = notificationsSwitch
        cell.selectionStyle = .none

      case .testNotifications:
        content.text = L10n.tr("settings.test_notifications")
        content.secondaryText = L10n.tr("settings.test_notifications.subtitle")
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default

      case .darkMode:
        content.text = L10n.tr("settings.dark_mode")
        content.secondaryText = L10n.tr("settings.dark_mode.subtitle")
        cell.contentConfiguration = content
        cell.accessoryView = darkModeSwitch
        cell.selectionStyle = .none
      }

    case .language:
      content.text = L10n.tr("settings.language")
      content.secondaryText = AppConfiguration.selectedLanguage.displayName
      cell.contentConfiguration = content
      cell.accessoryType = .disclosureIndicator

    case .storage:
      content.text = L10n.tr("settings.clear_downloaded_content")
      content.secondaryText = String(format: L10n.tr("settings.clear_downloaded_content.subtitle"), assetsSizeText)
      content.textProperties.color = AppTheme.destructiveColor
      cell.contentConfiguration = content

    case .support:
      content.text = L10n.tr("settings.report_bug")
      content.secondaryText = L10n.tr("settings.report_bug.subtitle")
      cell.contentConfiguration = content
      cell.accessoryType = .disclosureIndicator
    }

    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)

    guard let section = Section(rawValue: indexPath.section) else { return }

    switch section {
    case .organization:
      showOrganizationPicker()

    case .preferences:
      guard let row = PreferencesRow(rawValue: indexPath.row) else { return }

      switch row {
      case .notifications, .darkMode:
        break
      case .testNotifications:
        sendTestNotification()
      }
    case .language:
      showLanguagePicker()

    case .storage:
      confirmClearAllDownloadedContent()

    case .support:
      let controller = UINavigationController(rootViewController: ReportBugViewController())
      present(controller, animated: true)
    }
  }

  private func showOrganizationPicker() {
    let controller = OrganizationPickerViewController(
      selectedBranding: AppConfiguration.branding
    ) { [weak self] branding in
      self?.applyBranding(branding)
    }

    let navigationController = UINavigationController(rootViewController: controller)
    navigationController.modalPresentationStyle = .pageSheet

    if let sheet = navigationController.sheetPresentationController {
      sheet.detents = [.medium()]
      sheet.prefersGrabberVisible = true
      sheet.preferredCornerRadius = 24
    }

    present(navigationController, animated: true)
  }

  private func applyBranding(_ branding: Branding) {
    AppConfiguration.branding = branding
    tableView.reloadData()
    onBrandingChanged?(branding)

    let alert = UIAlertController(
      title: L10n.tr("settings.organization_updated.title"),
      message: String(format: L10n.tr("settings.organization_updated.message"), branding.fullName),
      preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
    present(alert, animated: true)
  }

  private func confirmClearAllDownloadedContent() {
    let alert = UIAlertController(
      title: L10n.tr("settings.clear_confirm.title"),
      message: L10n.tr("settings.clear_confirm.message"),
      preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
    alert.addAction(UIAlertAction(title: L10n.tr("common.clear"), style: .destructive, handler: { [weak self] _ in
      self?.clearAllDownloadedContent()
    }))

    present(alert, animated: true)
  }

    private func showLanguagePicker() {
      let controller = LanguagePickerViewController(
        selectedLanguage: AppConfiguration.selectedLanguage
      ) { [weak self] language in
        AppConfiguration.selectedLanguage = language
        self?.tableView.reloadData()

        let alert = UIAlertController(
          title: L10n.tr("settings.language_updated.title"),
          message: String(format: L10n.tr("settings.language_updated.message"), language.displayName),
          preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        self?.present(alert, animated: true)
      }

      let navigationController = UINavigationController(rootViewController: controller)
      navigationController.modalPresentationStyle = .pageSheet

      if let sheet = navigationController.sheetPresentationController {
        sheet.detents = [.medium()]
        sheet.prefersGrabberVisible = true
        sheet.preferredCornerRadius = 24
      }

      present(navigationController, animated: true)
    }

    // Remove this later (CPY SCORM)
    private func seedBundledCourses() {
      guard let resourceURL = Bundle.main.resourceURL else {
        let alert = UIAlertController(
          title: "Load Failed",
          message: "Could not access bundled app resources.",
          preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
        return
      }

      let fileManager = FileManager.default
      var seededCount = 0
      var failedFiles: [String] = []

      guard let enumerator = fileManager.enumerator(
        at: resourceURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      ) else {
        let alert = UIAlertController(
          title: "Load Failed",
          message: "Could not enumerate bundled resources.",
          preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
        return
      }

      for case let fileURL as URL in enumerator {
        guard fileURL.pathExtension.lowercased() == "zip" else { continue }

        let filename = fileURL.lastPathComponent
        let assetId = fileURL.deletingPathExtension().lastPathComponent

        do {
          try? ScormUtils.deleteCourse(assetId: assetId)

          let data = try Data(contentsOf: fileURL)
          try ScormUtils.replaceDownloadedZip(
            assetId: assetId,
            filename: filename,
            data: data
          )

          seededCount += 1
        } catch {
          failedFiles.append(filename)
          print("Failed to seed \(filename):", error)
        }
      }

      let message: String
      if seededCount == 0 {
        message = "No bundled zip files were found."
      } else if failedFiles.isEmpty {
        message = "\(seededCount) bundled course(s) copied to local storage."
      } else {
        message = "\(seededCount) bundled course(s) copied.\nFailed: \(failedFiles.joined(separator: ", "))"
      }

      let alert = UIAlertController(
        title: "Demo Courses Loaded",
        message: message,
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "OK", style: .default))
      present(alert, animated: true)

      tableView.reloadData()
    }

  private func clearAllDownloadedContent() {
    let fileManager = FileManager.default
    let assetsRoot = ScormUtils.assetsRootURL()

    do {
      if fileManager.fileExists(atPath: assetsRoot.path) {
        let contents = try fileManager.contentsOfDirectory(at: assetsRoot, includingPropertiesForKeys: nil)
        for url in contents {
          try fileManager.removeItem(at: url)
        }
      }

      ScormProgressStore.shared.clearAll()

      let success = UIAlertController(
        title: L10n.tr("settings.clear_success.title"),
        message: L10n.tr("settings.clear_success.message"),
        preferredStyle: .alert
      )
      success.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
      present(success, animated: true)
      self.tableView.reloadData()
    } catch {
      let failure = UIAlertController(
        title: L10n.tr("common.error"),
        message: L10n.tr("settings.clear_failed.message"),
        preferredStyle: .alert
      )
      failure.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
      present(failure, animated: true)
    }
  }
}

private final class OrganizationPickerViewController: UIViewController {

  private let pickerView = UIPickerView()
  private let brandings = Branding.allCases
  private let selectedBranding: Branding
  private let onApply: (Branding) -> Void

  init(selectedBranding: Branding, onApply: @escaping (Branding) -> Void) {
    self.selectedBranding = selectedBranding
    self.onApply = onApply
    super.init(nibName: nil, bundle: nil)
    title = L10n.tr("settings.organization_picker.title")
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = AppTheme.groupedBackgroundColor
    AppTheme.applyNavigationBarAppearance(to: navigationController)
    configureNavigation()
    configurePicker()
    configureLayout()
  }

  private func configureNavigation() {
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .cancel,
      target: self,
      action: #selector(cancelTapped)
    )

    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: L10n.tr("common.apply"),
      style: .done,
      target: self,
      action: #selector(applyTapped)
    )
  }

  private func configurePicker() {
    pickerView.translatesAutoresizingMaskIntoConstraints = false
    pickerView.dataSource = self
    pickerView.delegate = self
    view.addSubview(pickerView)

    if let selectedIndex = brandings.firstIndex(of: selectedBranding) {
      pickerView.selectRow(selectedIndex, inComponent: 0, animated: false)
    }
  }

  private func configureLayout() {
    let titleLabel = UILabel()
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.text = L10n.tr("settings.organization_picker.title")
    titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
    titleLabel.textColor = AppTheme.primaryTextColor
    titleLabel.textAlignment = .center

    let subtitleLabel = UILabel()
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
    subtitleLabel.text = L10n.tr("settings.organization_picker.subtitle")
    subtitleLabel.font = AppTheme.secondaryFont
    subtitleLabel.textColor = AppTheme.secondaryTextColor
    subtitleLabel.textAlignment = .center
    subtitleLabel.numberOfLines = 0

    let headerStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
    headerStack.axis = .vertical
    headerStack.spacing = 8
    headerStack.translatesAutoresizingMaskIntoConstraints = false

    let card = UIView()
    card.translatesAutoresizingMaskIntoConstraints = false
    card.backgroundColor = AppTheme.cardBackgroundColor
    card.layer.cornerRadius = AppTheme.largeCornerRadius
    card.layer.cornerCurve = .continuous

    card.addSubview(pickerView)
    view.addSubview(headerStack)
    view.addSubview(card)

    NSLayoutConstraint.activate([
      headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
      headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

      card.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 20),
      card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      card.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
      card.heightAnchor.constraint(equalToConstant: 220),

      pickerView.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
      pickerView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
      pickerView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
      pickerView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
    ])
  }

  @objc private func cancelTapped() {
    dismiss(animated: true)
  }

  @objc private func applyTapped() {
    let selectedIndex = pickerView.selectedRow(inComponent: 0)
    let branding = brandings[selectedIndex]
    dismiss(animated: true) {
      self.onApply(branding)
    }
  }
}

private final class LanguagePickerViewController: UIViewController {
  private let pickerView = UIPickerView()
  private let languages = AppConfiguration.availableLanguages
  private let selectedLanguage: AppLanguage
  private let onApply: (AppLanguage) -> Void

  init(selectedLanguage: AppLanguage, onApply: @escaping (AppLanguage) -> Void) {
    self.selectedLanguage = selectedLanguage
    self.onApply = onApply
    super.init(nibName: nil, bundle: nil)
    title = L10n.tr("settings.language_picker.title")
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = AppTheme.groupedBackgroundColor
    AppTheme.applyNavigationBarAppearance(to: navigationController)
    configureNavigation()
    configurePicker()
    configureLayout()
  }

  private func configureNavigation() {
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: L10n.tr("common.cancel"),
      style: .plain,
      target: self,
      action: #selector(cancelTapped)
    )

    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: L10n.tr("common.apply"),
      style: .done,
      target: self,
      action: #selector(applyTapped)
    )
  }

  private func configurePicker() {
    pickerView.translatesAutoresizingMaskIntoConstraints = false
    pickerView.dataSource = self
    pickerView.delegate = self
    view.addSubview(pickerView)

    if let selectedIndex = languages.firstIndex(of: selectedLanguage) {
      pickerView.selectRow(selectedIndex, inComponent: 0, animated: false)
    }
  }

  private func configureLayout() {
    NSLayoutConstraint.activate([
      pickerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
      pickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      pickerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      pickerView.heightAnchor.constraint(equalToConstant: 220)
    ])
  }

  @objc private func cancelTapped() {
    dismiss(animated: true)
  }

  @objc private func applyTapped() {
    let selectedIndex = pickerView.selectedRow(inComponent: 0)
    let language = languages[selectedIndex]
    dismiss(animated: true) {
      self.onApply(language)
    }
  }
}

extension LanguagePickerViewController: UIPickerViewDataSource, UIPickerViewDelegate {
  func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    languages.count
  }

  func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
    languages[row].displayName
  }
}

extension OrganizationPickerViewController: UIPickerViewDataSource, UIPickerViewDelegate {
  func numberOfComponents(in pickerView: UIPickerView) -> Int {
    1
  }

  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    brandings.count
  }

  func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
    54
  }

  func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
    pickerView.bounds.width - 24
  }

  func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
    let branding = brandings[row]

    let container = UIView()
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()

    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

    titleLabel.text = branding.fullName
    titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
    titleLabel.textColor = AppTheme.primaryTextColor
    titleLabel.textAlignment = .center

    subtitleLabel.text = branding.hostDisplayName
    subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
    subtitleLabel.textColor = AppTheme.secondaryTextColor
    subtitleLabel.textAlignment = .center

    container.addSubview(titleLabel)
    container.addSubview(subtitleLabel)

    NSLayoutConstraint.activate([
      titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
      titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
      titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),

      subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
      subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
      subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
      subtitleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
    ])

    return container
  }
}

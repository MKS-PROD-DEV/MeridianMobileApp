import UIKit

final class SettingsViewController: UITableViewController {
  private enum Section: Int, CaseIterable {
    case organization
    case preferences
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
      return "Version \(version) (\(build))"
    }
  private enum OrganizationRow: Int, CaseIterable {
    case site
  }

  private enum PreferencesRow: Int, CaseIterable {
    case notifications
  }

  private enum StorageRow: Int, CaseIterable {
    case clearDownloads
  }

  private enum SupportRow: Int, CaseIterable {
    case reportBug
  }

  private let notificationsKey = "settings.notifications.enabled"
  private let onBrandingChanged: ((Branding) -> Void)?

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
    title = "Settings"
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
  }
    override func viewWillAppear(_ animated: Bool) {
      super.viewWillAppear(animated)
      tableView.reloadData()
    }

  @objc private func close() {
    dismiss(animated: true)
  }

  @objc private func notificationsChanged(_ sender: UISwitch) {
    UserDefaults.standard.set(sender.isOn, forKey: notificationsKey)
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
      return "Organization"
    case .preferences:
      return "Preferences"
    case .storage:
      return "Storage"
    case .support:
      return "Support"
    }
  }

  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    guard let section = Section(rawValue: section) else { return nil }

    switch section {
    case .organization:
      return "Choose which organization site and branding the app should use."
    case .preferences:
      return "Manage app-level preferences."
    case .storage:
      return "Downloaded SCORM content is stored locally on this device."
    case .support:
      return "Need help or want to report a problem?\n\n\(appVersionText)"
    }
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
      content.text = "Current Organization"
      content.secondaryText = "\(AppConfiguration.branding.fullName) • \(AppConfiguration.branding.hostDisplayName)"
      cell.contentConfiguration = content
      cell.accessoryType = .disclosureIndicator

    case .preferences:
      content.text = "Notifications"
      content.secondaryText = nil
      cell.contentConfiguration = content
      cell.accessoryView = notificationsSwitch
      cell.selectionStyle = .none

    case .storage:
      content.text = "Clear Downloaded Content"
      content.secondaryText = "Remove all saved offline courses • \(assetsSizeText)"
      content.textProperties.color = AppTheme.destructiveColor
      cell.contentConfiguration = content

    case .support:
      content.text = "Report a Bug"
      content.secondaryText = "Share an issue with the app experience"
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
      break

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
      title: "Organization Updated",
      message: "\(branding.fullName) is Active.",
      preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "OK", style: .default))
    present(alert, animated: true)
  }

  private func confirmClearAllDownloadedContent() {
    let alert = UIAlertController(
      title: "Clear Downloaded Content?",
      message: "This will remove all downloaded SCORM courses from local storage.",
      preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Clear", style: .destructive, handler: { [weak self] _ in
      self?.clearAllDownloadedContent()
    }))

    present(alert, animated: true)
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
        title: "Done",
        message: "All downloaded content has been cleared.",
        preferredStyle: .alert
      )
      success.addAction(UIAlertAction(title: "OK", style: .default))
      present(success, animated: true)
      self.tableView.reloadData()
    } catch {
      let failure = UIAlertController(
        title: "Error",
        message: "Failed to clear downloaded content.",
        preferredStyle: .alert
      )
      failure.addAction(UIAlertAction(title: "OK", style: .default))
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
    title = "Choose Organization"
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
      title: "Apply",
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
    titleLabel.text = "Choose Organization"
    titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
    titleLabel.textColor = AppTheme.primaryTextColor
    titleLabel.textAlignment = .center

    let subtitleLabel = UILabel()
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
    subtitleLabel.text = "Swipe to select the site and branding you want to use."
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

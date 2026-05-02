import UIKit

final class SettingsViewController: UITableViewController {
  private enum Section: Int, CaseIterable {
    case organization
    case preferences
    case storage
    case support
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
      return "Need help or want to report a problem?"
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
      content.secondaryText = "Remove all saved offline courses"
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
      showSitePicker()

    case .preferences:
      break

    case .storage:
      confirmClearAllDownloadedContent()

    case .support:
      let controller = UINavigationController(rootViewController: ReportBugViewController())
      present(controller, animated: true)
    }
  }

  private func showSitePicker() {
    let alert = UIAlertController(
      title: "Choose Organization",
      message: nil,
      preferredStyle: .actionSheet
    )

    for branding in Branding.allCases {
      let isCurrent = branding == AppConfiguration.branding
      let titleBase = "\(branding.fullName) — \(branding.hostDisplayName)"
      let title = isCurrent ? "✓ \(titleBase)" : titleBase

      alert.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] _ in
        self?.applyBranding(branding)
      }))
    }

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

    if let popover = alert.popoverPresentationController {
      popover.sourceView = view
      popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
    }

    present(alert, animated: true)
  }

  private func applyBranding(_ branding: Branding) {
    AppConfiguration.branding = branding
    tableView.reloadData()
    onBrandingChanged?(branding)

    let alert = UIAlertController(
      title: "Organization Updated",
      message: "\(branding.fullName) is now selected.",
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

  private func showReportBugPlaceholder() {
    let alert = UIAlertController(
      title: "Report a Bug",
      message: "Bug reporting will be added here.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    present(alert, animated: true)
  }
}

import UIKit

final class SettingsViewController: UITableViewController {
  private enum Section: Int, CaseIterable {
    case preferences
    case storage
    case support
  }

  private let notificationsKey = "settings.notifications.enabled"

  private lazy var notificationsSwitch: UISwitch = {
    let control = UISwitch()
    control.isOn = UserDefaults.standard.object(forKey: notificationsKey) as? Bool ?? true
    control.addTarget(self, action: #selector(notificationsChanged(_:)), for: .valueChanged)
    return control
  }()

  init() {
    super.init(style: .insetGrouped)
    self.title = "Settings"
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close,
      target: self,
      action: #selector(close)
    )

    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
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
    case .preferences: return 1
    case .storage: return 1
    case .support: return 1
    }
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    guard let section = Section(rawValue: section) else { return nil }

    switch section {
    case .preferences: return "Preferences"
    case .storage: return "Storage"
    case .support: return "Support"
    }
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let section = Section(rawValue: indexPath.section) else {
      return UITableViewCell()
    }

    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
    var content = cell.defaultContentConfiguration()

    cell.accessoryView = nil
    cell.accessoryType = .none
    cell.selectionStyle = .default

    switch section {
    case .preferences:
      content.text = "Notifications"
      cell.contentConfiguration = content
      cell.accessoryView = notificationsSwitch
      cell.selectionStyle = .none

    case .storage:
      content.text = "Clear All Downloaded Content"
      content.textProperties.color = .systemRed
      cell.contentConfiguration = content

    case .support:
      content.text = "Report Bug"
      cell.contentConfiguration = content
      cell.accessoryType = .disclosureIndicator
    }

    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)

    guard let section = Section(rawValue: indexPath.section) else { return }

    switch section {
    case .preferences:
      break

    case .storage:
      confirmClearAllDownloadedContent()

    case .support:
      showReportBugPlaceholder()
    }
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
    let fm = FileManager.default
    let assetsRoot = ScormUtils.assetsRootURL()

    do {
      if fm.fileExists(atPath: assetsRoot.path) {
        let contents = try fm.contentsOfDirectory(at: assetsRoot, includingPropertiesForKeys: nil)
        for url in contents {
          try fm.removeItem(at: url)
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
      title: "Report Bug",
      message: "Bug reporting will be added here.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    present(alert, animated: true)
  }
}

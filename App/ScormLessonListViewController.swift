import UIKit

final class ScormLessonListViewController: UITableViewController {
  private let assetId: String
  private let scormDir: URL
  private let manifest: ScormManifestData

  init(assetId: String, scormDir: URL, manifest: ScormManifestData) {
    self.assetId = assetId
    self.scormDir = scormDir
    self.manifest = manifest
    super.init(style: .insetGrouped)
    title = manifest.title ?? "Lessons"
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = AppTheme.groupedBackgroundColor
    tableView.backgroundColor = AppTheme.groupedBackgroundColor
    tableView.rowHeight = 72
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    AppTheme.applyNavigationBarAppearance(to: navigationController)
  }

  override func numberOfSections(in tableView: UITableView) -> Int {
    1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    manifest.scos.count
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    manifest.scos.isEmpty ? nil : "Lessons"
  }

  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    manifest.scos.isEmpty ? "No lessons are available for this course." : nil
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
    -> UITableViewCell
  {
    let sco = manifest.scos[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

    var content = cell.defaultContentConfiguration()
    content.text = sco.title
    content.secondaryText = "Lesson \(indexPath.row + 1)"
    content.textProperties.font = .systemFont(ofSize: 17, weight: .semibold)
    content.secondaryTextProperties.font = AppTheme.secondaryFont
    content.secondaryTextProperties.color = AppTheme.secondaryTextColor
    cell.contentConfiguration = content
    cell.accessoryType = .disclosureIndicator
    cell.tintColor = AppTheme.accentColor

    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)

    let sco = manifest.scos[indexPath.row]
    let launchURL = URL(fileURLWithPath: sco.href, relativeTo: scormDir).standardizedFileURL
    let injectedJS = ScormAPIShim.javascript(assetId: assetId, scoId: sco.itemIdentifier)

    let vc = ScormPlayerViewController(
      assetId: assetId,
      scoId: sco.itemIdentifier,
      launchFileURL: launchURL,
      readAccessURL: scormDir,
      injectedJS: injectedJS
    )

    let nav = UINavigationController(rootViewController: vc)
    nav.modalPresentationStyle = .fullScreen
    present(nav, animated: true)
  }
}

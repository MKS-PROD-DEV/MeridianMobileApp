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
    self.title = manifest.title ?? "Lessons"
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    manifest.scos.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
    -> UITableViewCell
  {
    let sco = manifest.scos[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

    var content = cell.defaultContentConfiguration()
    content.text = sco.title
    content.secondaryText = sco.itemIdentifier
    cell.contentConfiguration = content
    cell.accessoryType = .disclosureIndicator

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

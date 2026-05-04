import UIKit

final class ScormCourseListViewController: UITableViewController {
  private var items: [OfflineLibraryItem]

  init(items: [OfflineLibraryItem]) {
    self.items = items
    super.init(style: .insetGrouped)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = AppTheme.groupedBackgroundColor
    tableView.backgroundColor = AppTheme.groupedBackgroundColor
    tableView.rowHeight = 72
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CourseCell")
    tableView.refreshControl = UIRefreshControl()
    tableView.refreshControl?.addTarget(self, action: #selector(refreshCourses), for: .valueChanged)
    AppTheme.applyNavigationBarAppearance(to: navigationController)
  }

  @objc private func refreshCourses() {
    items = ScormUtils.loadOfflineLibraryItems()
    tableView.reloadData()
    tableView.refreshControl?.endRefreshing()
  }

  override func numberOfSections(in tableView: UITableView) -> Int {
    1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    max(items.count, 1)
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    items.isEmpty ? nil : L10n.tr("courses.title")
  }

  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    items.isEmpty ? L10n.tr("courses.footer.empty") : nil
  }

  override func tableView(
    _ tableView: UITableView,
    trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
  ) -> UISwipeActionsConfiguration? {
    guard !items.isEmpty else { return nil }

    let deleteAction = UIContextualAction(
      style: .destructive,
      title: L10n.tr("common.delete")
    ) { [weak self] _, _, completion in
      self?.deleteItem(at: indexPath, completion: completion)
    }

    let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
    configuration.performsFirstActionWithFullSwipe = false
    return configuration
  }

  private func deleteItem(at indexPath: IndexPath, completion: @escaping (Bool) -> Void) {
    let item = items[indexPath.row]

    do {
      try ScormUtils.deleteCourse(assetId: item.assetId)
      items.remove(at: indexPath.row)

      if items.isEmpty {
        tableView.reloadData()
      } else {
        tableView.deleteRows(at: [indexPath], with: .automatic)
      }

      let alert = UIAlertController(
        title: L10n.tr("courses.deleted.title"),
        message: L10n.tr("courses.deleted.message"),
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
      present(alert, animated: true)
      completion(true)
    } catch {
      let alert = UIAlertController(
        title: L10n.tr("courses.delete_failed.title"),
        message: L10n.tr("courses.delete_failed.message"),
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
      present(alert, animated: true)
      completion(false)
    }
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "CourseCell", for: indexPath)
    var content = cell.defaultContentConfiguration()

    if items.isEmpty {
      content.text = L10n.tr("courses.empty.title")
      content.secondaryText = L10n.tr("courses.empty.message")
      content.textProperties.font = .systemFont(ofSize: 17, weight: .semibold)
      content.secondaryTextProperties.font = AppTheme.secondaryFont
      content.secondaryTextProperties.color = AppTheme.secondaryTextColor
      cell.accessoryType = .none
      cell.accessoryView = nil
      cell.selectionStyle = .none
    } else {
      let item = items[indexPath.row]

      content.text = item.title
      content.secondaryText = item.subtitle
      content.textProperties.font = .systemFont(ofSize: 17, weight: .semibold)
      content.secondaryTextProperties.font = AppTheme.secondaryFont
      content.secondaryTextProperties.color = AppTheme.secondaryTextColor

      if item.isScorm {
        let infoButton = UIButton(type: .infoLight)
        infoButton.tintColor = AppTheme.accentColor
        infoButton.tag = indexPath.row
        infoButton.addTarget(self, action: #selector(infoButtonTapped(_:)), for: .touchUpInside)
        cell.accessoryView = infoButton
        cell.accessoryType = .none
      } else {
        cell.accessoryView = nil
        cell.accessoryType = .disclosureIndicator
      }

      cell.selectionStyle = .default
    }

    cell.contentConfiguration = content
    cell.tintColor = AppTheme.accentColor
    return cell
  }

  @objc private func infoButtonTapped(_ sender: UIButton) {
    guard case let .scorm(course) = items[sender.tag] else { return }

    let viewController = CourseInfoViewController(course: course)
    let nav = UINavigationController(rootViewController: viewController)
    AppTheme.applyNavigationBarAppearance(to: nav)
    nav.modalPresentationStyle = .pageSheet
    present(nav, animated: true)
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard !items.isEmpty else { return }

    tableView.deselectRow(at: indexPath, animated: true)

    switch items[indexPath.row] {
    case .scorm(let course):
      let viewController = ScormLessonListViewController(
        assetId: course.assetId,
        scormDir: course.scormDir,
        manifest: course.manifest
      )
      navigationController?.pushViewController(viewController, animated: true)

    case .file(let item):
      OfflineContentLauncher.presentContent(item, from: self)
    }
  }
}

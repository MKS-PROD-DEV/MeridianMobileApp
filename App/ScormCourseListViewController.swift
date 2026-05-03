/*
  Native screen that displays available offline SCORM courses.
  - rendering the list of downloaded courses
  - showing course progress state
  - supporting pull-to-refresh
  - supporting swipe-to-delete for full course removal
  - exposing a placeholder course info action
  - navigating to the lesson list for a selected course
*/
import UIKit

final class ScormCourseListViewController: UITableViewController {
  private var courses: [ScormCourse]

  init(courses: [ScormCourse]) {
    self.courses = courses
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
    courses = ScormUtils.loadAllCourses()
    tableView.reloadData()
    tableView.refreshControl?.endRefreshing()
  }

  override func numberOfSections(in tableView: UITableView) -> Int {
    1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    max(courses.count, 1)
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    courses.isEmpty ? nil : "Available Offline Courses"
  }

  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    courses.isEmpty ? "Download courses while online to access them later in Offline Mode." : nil
  }

  override func tableView(
    _ tableView: UITableView,
    trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
  ) -> UISwipeActionsConfiguration? {
    guard !courses.isEmpty else { return nil }

    let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
      self?.deleteCourse(at: indexPath, completion: completion)
    }

    let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
    configuration.performsFirstActionWithFullSwipe = false
    return configuration
  }

  private func deleteCourse(at indexPath: IndexPath, completion: @escaping (Bool) -> Void) {
    let course = courses[indexPath.row]

    do {
      try ScormUtils.deleteCourse(assetId: course.assetId)
      courses.remove(at: indexPath.row)

      if courses.isEmpty {
        tableView.reloadData()
      } else {
        tableView.deleteRows(at: [indexPath], with: .automatic)
      }

      let alert = UIAlertController(
        title: "Course Deleted",
        message: "The downloaded course was removed from this device.",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "OK", style: .default))
      present(alert, animated: true)
      completion(true)
    } catch {
      let alert = UIAlertController(
        title: "Delete Failed",
        message: "The course could not be deleted.",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "OK", style: .default))
      present(alert, animated: true)
      completion(false)
    }
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "CourseCell", for: indexPath)
    var content = cell.defaultContentConfiguration()

    if courses.isEmpty {
      content.text = "No Downloaded Courses"
      content.secondaryText = "Courses you download will appear here for offline access."
      content.textProperties.font = .systemFont(ofSize: 17, weight: .semibold)
      content.secondaryTextProperties.font = AppTheme.secondaryFont
      content.secondaryTextProperties.color = AppTheme.secondaryTextColor
      cell.accessoryType = .none
      cell.accessoryView = nil
      cell.selectionStyle = .none
    } else {
      let course = courses[indexPath.row]
      let progress = ScormProgressStore.shared.progressStatus(for: course.assetId)?.rawValue

      content.text = course.title

      if let progress = progress {
        content.secondaryText = "\(course.manifest.scos.count) lesson(s) • \(progress)"
      } else {
        content.secondaryText = "\(course.manifest.scos.count) lesson(s)"
      }

      content.textProperties.font = .systemFont(ofSize: 17, weight: .semibold)
      content.secondaryTextProperties.font = AppTheme.secondaryFont
      content.secondaryTextProperties.color = AppTheme.secondaryTextColor

      let infoButton = UIButton(type: .infoLight)
      infoButton.tintColor = AppTheme.accentColor
      infoButton.tag = indexPath.row
      infoButton.addTarget(self, action: #selector(infoButtonTapped(_:)), for: .touchUpInside)
      cell.accessoryView = infoButton
      cell.selectionStyle = .default
    }

    cell.contentConfiguration = content
    cell.tintColor = AppTheme.accentColor
    return cell
  }

    @objc private func infoButtonTapped(_ sender: UIButton) {
      let course = courses[sender.tag]
      let viewController = CourseInfoViewController(course: course)
      let nav = UINavigationController(rootViewController: viewController)
      AppTheme.applyNavigationBarAppearance(to: nav)
      nav.modalPresentationStyle = .pageSheet
      present(nav, animated: true)
    }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard !courses.isEmpty else { return }

    tableView.deselectRow(at: indexPath, animated: true)

    let course = courses[indexPath.row]
    let viewController = ScormLessonListViewController(
      assetId: course.assetId,
      scormDir: course.scormDir,
      manifest: course.manifest
    )
    navigationController?.pushViewController(viewController, animated: true)
  }
}

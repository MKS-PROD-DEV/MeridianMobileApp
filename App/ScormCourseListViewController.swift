import UIKit

final class ScormCourseListViewController: UITableViewController {
  private let courses: [ScormCourse]

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
    AppTheme.applyNavigationBarAppearance(to: navigationController)
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
      cell.selectionStyle = .none
    } else {
      let course = courses[indexPath.row]
      content.text = course.title
      content.secondaryText = "\(course.manifest.scos.count) lesson(s)"
      content.textProperties.font = .systemFont(ofSize: 17, weight: .semibold)
      content.secondaryTextProperties.font = AppTheme.secondaryFont
      content.secondaryTextProperties.color = AppTheme.secondaryTextColor
      cell.accessoryType = .disclosureIndicator
      cell.selectionStyle = .default
    }

    cell.contentConfiguration = content
    cell.tintColor = AppTheme.accentColor
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard !courses.isEmpty else { return }

    tableView.deselectRow(at: indexPath, animated: true)

    let course = courses[indexPath.row]
    let vc = ScormLessonListViewController(
      assetId: course.assetId,
      scormDir: course.scormDir,
      manifest: course.manifest
    )
    navigationController?.pushViewController(vc, animated: true)
  }
}

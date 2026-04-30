import UIKit

final class ScormCourseListViewController: UITableViewController {
  private let courses: [ScormCourse]

  init(courses: [ScormCourse]) {
    self.courses = courses
    super.init(style: .insetGrouped)
    self.title = "MGPlayer"
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CourseCell")
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    courses.count
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    courses.isEmpty ? nil : "Available Courses"
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let course = courses[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: "CourseCell", for: indexPath)

    var content = cell.defaultContentConfiguration()
    content.text = course.title
    content.secondaryText = "\(course.manifest.scos.count) lesson(s) • \(course.assetId)"
    cell.contentConfiguration = content
    cell.accessoryType = .disclosureIndicator

    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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

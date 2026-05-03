/*
  Course Info View.
  - Shows user data about selected course
  - Progress and Access data is fetched from DB
*/
import UIKit

final class CourseInfoViewController: UIViewController {
  private let course: ScormCourse

  init(course: ScormCourse) {
    self.course = course
    super.init(nibName: nil, bundle: nil)
    title = "Course Info"
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let scrollView = UIScrollView()
  private let contentStack = UIStackView()

  override func viewDidLoad() {
    super.viewDidLoad()

    configureView()
    configureNavigation()
    configureLayout()
    buildContent()
    AppTheme.applyNavigationBarAppearance(to: navigationController)
  }

  private func configureView() {
    view.backgroundColor = AppTheme.groupedBackgroundColor

    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.alwaysBounceVertical = true

    contentStack.translatesAutoresizingMaskIntoConstraints = false
    contentStack.axis = .vertical
    contentStack.spacing = 16

    view.addSubview(scrollView)
    scrollView.addSubview(contentStack)
  }

  private func configureNavigation() {
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close,
      target: self,
      action: #selector(closeTapped)
    )
  }

  private func configureLayout() {
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
      contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
      contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
      contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24)
    ])
  }

  private func buildContent() {
    contentStack.addArrangedSubview(makeHeaderCard())
    contentStack.addArrangedSubview(makeDetailsCard())
  }

  private func makeHeaderCard() -> UIView {
    let card = makeCardView()

    let titleLabel = UILabel()
    titleLabel.text = course.title
    titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
    titleLabel.textColor = AppTheme.primaryTextColor
    titleLabel.numberOfLines = 0
    titleLabel.textAlignment = .center

    let subtitleLabel = UILabel()
    subtitleLabel.text = "Offline SCORM course information"
    subtitleLabel.font = AppTheme.secondaryFont
    subtitleLabel.textColor = AppTheme.secondaryTextColor
    subtitleLabel.numberOfLines = 0
    subtitleLabel.textAlignment = .center

    let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
    stack.axis = .vertical
    stack.spacing = 10
    stack.translatesAutoresizingMaskIntoConstraints = false

    card.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
      stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
      stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
      stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24)
    ])

    return card
  }

  private func makeDetailsCard() -> UIView {
    let card = makeCardView()

    let progressText = ScormProgressStore.shared.progressStatus(for: course.assetId)?.rawValue ?? "Not Started"
    let lastAccessedText = formattedLastAccessedDate()
    let courseTypeText = inferredCourseType()
    let authorText = "Not available"

    let stack = UIStackView(arrangedSubviews: [
      makeInfoRow(title: "Course Name", value: course.title),
      makeInfoRow(title: "Course Type", value: courseTypeText),
      makeInfoRow(title: "Course Author", value: authorText),
      makeInfoRow(title: "Progress", value: progressText),
      makeInfoRow(title: "Last Accessed", value: lastAccessedText)
    ])

    stack.axis = .vertical
    stack.spacing = 14
    stack.translatesAutoresizingMaskIntoConstraints = false

    card.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
      stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
      stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
      stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
    ])

    return card
  }

  private func makeInfoRow(title: String, value: String) -> UIView {
    let titleLabel = UILabel()
    titleLabel.text = title
    titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
    titleLabel.textColor = AppTheme.primaryTextColor
    titleLabel.numberOfLines = 0

    let valueLabel = UILabel()
    valueLabel.text = value
    valueLabel.font = AppTheme.bodyFont
    valueLabel.textColor = AppTheme.secondaryTextColor
    valueLabel.numberOfLines = 0
    valueLabel.textAlignment = .right

    let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
    stack.axis = .horizontal
    stack.alignment = .top
    stack.spacing = 16
    stack.distribution = .fillProportionally

    return stack
  }

  private func makeCardView() -> UIView {
    let card = UIView()
    card.backgroundColor = AppTheme.cardBackgroundColor
    card.layer.cornerRadius = AppTheme.largeCornerRadius
    card.layer.cornerCurve = .continuous
    card.layer.borderWidth = 1
    card.layer.borderColor = AppTheme.separatorColor.withAlphaComponent(0.10).cgColor
    return card
  }

  private func inferredCourseType() -> String {
    "SCORM Course"
  }

  private func formattedLastAccessedDate() -> String {
    guard let date = ScormProgressStore.shared.lastAccessedDate(for: course.assetId) else {
      return "Never"
    }

    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  @objc private func closeTapped() {
    dismiss(animated: true)
  }
}

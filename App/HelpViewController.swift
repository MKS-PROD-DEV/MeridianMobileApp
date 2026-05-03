/*
 Native help screen for offline learning support.
 - providing user guidance for downloads, playback, and troubleshooting
 */
import UIKit

final class HelpViewController: UIViewController {

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
    title = "Help"
    view.backgroundColor = AppTheme.groupedBackgroundColor

    scrollView.alwaysBounceVertical = true
    scrollView.backgroundColor = .clear
    scrollView.translatesAutoresizingMaskIntoConstraints = false

    contentStack.axis = .vertical
    contentStack.spacing = 16
    contentStack.alignment = .fill
    contentStack.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(scrollView)
    scrollView.addSubview(contentStack)
  }

  private func configureNavigation() {
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close,
      target: self,
      action: #selector(close)
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
      contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28)
    ])
  }

  private func buildContent() {
    contentStack.addArrangedSubview(makeBrandHeader())

    contentStack.addArrangedSubview(
      makeInfoCard(
        title: "What this app does",
        systemImage: "sparkles.rectangle.stack",
        body: """
        \(AppConfiguration.branding.fullName) Mobile lets you access learning content in the main app and open downloaded SCORM courses offline.

        The app includes a native offline learning flow for:
        • downloaded course access
        • lesson selection
        • offline SCORM playback
        • local progress saving on your device
        """
      )
    )

    contentStack.addArrangedSubview(
      makeStepSection(
        title: "Getting Started",
        systemImage: "play.circle.fill",
        steps: [
          "Open the app and sign in if needed.",
          "Browse available learning content in the main app.",
          "Download a SCORM course if you want offline access.",
          "Open the downloaded course from the offline course area.",
          "Choose a lesson and begin learning."
        ]
      )
    )

    contentStack.addArrangedSubview(
      makeStepSection(
        title: "Using Offline Courses",
        systemImage: "arrow.down.circle.fill",
        steps: [
          "Downloaded SCORM packages are stored locally on your device.",
          "Offline courses appear in the native offline course list.",
          "Tap a course to view its lessons.",
          "Tap a lesson to launch the SCORM player.",
          "Once fully downloaded, the course can usually be opened without internet access."
        ]
      )
    )

    contentStack.addArrangedSubview(
      makeStepSection(
        title: "Progress and Resume",
        systemImage: "checkmark.circle.fill",
        steps: [
          "Your lesson progress is saved locally while you learn.",
          "The app stores SCORM learner progress in native SQLite storage on the device.",
          "When you reopen the same lesson later, saved state may be restored depending on how that SCORM package handles resume data.",
          "If connectivity is available, surrounding app workflows may also support sync behavior."
        ]
      )
    )

    contentStack.addArrangedSubview(
      makeFAQSection(
        title: "Frequently Asked Questions",
        systemImage: "questionmark.circle.fill",
        items: [
          FAQItem(
            question: "Do I need internet to play a downloaded SCORM course?",
            answer: "No. After a SCORM package is fully downloaded and extracted, lessons can be launched locally offline."
          ),
          FAQItem(
            question: "Where are offline files stored?",
            answer: "Downloaded SCORM files are stored in the app’s local Documents directory on your device."
          ),
          FAQItem(
            question: "Is my progress saved automatically?",
            answer: "Usually yes. The offline SCORM player saves progress locally as the lesson runs and during SCORM commit-style updates."
          ),
          FAQItem(
            question: "Why does a lesson fail to open correctly?",
            answer: "This can happen if the SCORM package is incomplete, missing launch metadata, or includes content that depends on unsupported browser behavior."
          ),
          FAQItem(
            question: "Do popup lesson windows work?",
            answer: "Yes. The native player supports popup windows used by some SCORM content."
          )
        ]
      )
    )

    contentStack.addArrangedSubview(
      makeInfoCard(
        title: "Troubleshooting",
        systemImage: "wrench.and.screwdriver.fill",
        body: """
        If something is not working as expected:

        • Confirm the course completed downloading
        • Reopen the course and select the lesson again
        • Make sure you opened the correct offline course
        • Try online access if the content depends on remote resources
        • If progress looks incorrect, reopen the same lesson and verify you selected the expected course and lesson

        If the issue continues, capture the course name and lesson name before reporting it.
        """
      )
    )

    contentStack.addArrangedSubview(
      makeInfoCard(
        title: "Helpful Tips",
        systemImage: "lightbulb.fill",
        body: """
        • Download courses before you lose connectivity
        • Open important courses once after download to confirm they are ready
        • Use the lesson list to launch the exact lesson you need
        • Stay in the lesson briefly before closing so progress has time to save
        """
      )
    )
  }

  private func makeBrandHeader() -> UIView {
    let card = makeCardView()
    card.backgroundColor = AppTheme.primaryColor.withAlphaComponent(0.08)

    let logoContainer = UIView()
    logoContainer.translatesAutoresizingMaskIntoConstraints = false
    logoContainer.backgroundColor = .clear

    let logoView = UIImageView()
    logoView.translatesAutoresizingMaskIntoConstraints = false
    logoView.contentMode = .scaleAspectFit
    logoView.clipsToBounds = true

    if let logo = AppTheme.logoImage {
      logoView.image = logo
    } else {
      logoView.image = UIImage(systemName: "graduationcap.fill")
      logoView.tintColor = AppTheme.primaryColor
      logoView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 40, weight: .bold)
    }

    logoContainer.addSubview(logoView)

    let titleLabel = UILabel()
    titleLabel.text = "\(AppConfiguration.branding.fullName) Help"
    titleLabel.textColor = AppTheme.primaryTextColor
    titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
    titleLabel.numberOfLines = 0
    titleLabel.textAlignment = .center

    let subtitleLabel = UILabel()
    subtitleLabel.text = "Offline learning, SCORM playback, downloads, and progress tracking."
    subtitleLabel.textColor = AppTheme.secondaryTextColor
    subtitleLabel.font = AppTheme.secondaryFont
    subtitleLabel.numberOfLines = 0
    subtitleLabel.textAlignment = .center

    let stack = UIStackView(arrangedSubviews: [logoContainer, titleLabel, subtitleLabel])
    stack.axis = .vertical
    stack.spacing = 14
    stack.alignment = .center
    stack.translatesAutoresizingMaskIntoConstraints = false

    card.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
      stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
      stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
      stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),

      logoView.topAnchor.constraint(equalTo: logoContainer.topAnchor),
      logoView.leadingAnchor.constraint(equalTo: logoContainer.leadingAnchor),
      logoView.trailingAnchor.constraint(equalTo: logoContainer.trailingAnchor),
      logoView.bottomAnchor.constraint(equalTo: logoContainer.bottomAnchor),
      logoView.heightAnchor.constraint(equalToConstant: 72),
      logoView.widthAnchor.constraint(lessThanOrEqualToConstant: 220)
    ])

    return card
  }

  private func makeInfoCard(title: String, systemImage: String, body: String) -> UIView {
    let card = makeCardView()

    let header = makeSectionHeader(title: title, systemImage: systemImage)

    let bodyLabel = UILabel()
    bodyLabel.text = body
    bodyLabel.textColor = AppTheme.secondaryTextColor
    bodyLabel.font = AppTheme.bodyFont
    bodyLabel.numberOfLines = 0

    let stack = UIStackView(arrangedSubviews: [header, bodyLabel])
    stack.axis = .vertical
    stack.spacing = 14
    stack.translatesAutoresizingMaskIntoConstraints = false

    card.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
      stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
      stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
      stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
    ])

    return card
  }

  private func makeStepSection(title: String, systemImage: String, steps: [String]) -> UIView {
    let card = makeCardView()

    let header = makeSectionHeader(title: title, systemImage: systemImage)

    let stepsStack = UIStackView()
    stepsStack.axis = .vertical
    stepsStack.spacing = 12

    for (index, step) in steps.enumerated() {
      stepsStack.addArrangedSubview(makeStepRow(number: index + 1, text: step))
    }

    let stack = UIStackView(arrangedSubviews: [header, stepsStack])
    stack.axis = .vertical
    stack.spacing = 14
    stack.translatesAutoresizingMaskIntoConstraints = false

    card.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
      stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
      stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
      stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
    ])

    return card
  }

  private func makeFAQSection(title: String, systemImage: String, items: [FAQItem]) -> UIView {
    let container = UIView()

    let header = makeSectionHeader(title: title, systemImage: systemImage)

    let faqStack = UIStackView()
    faqStack.axis = .vertical
    faqStack.spacing = 10

    items.forEach { item in
      faqStack.addArrangedSubview(SleekFAQItemView(item: item))
    }

    let stack = UIStackView(arrangedSubviews: [header, faqStack])
    stack.axis = .vertical
    stack.spacing = 14
    stack.translatesAutoresizingMaskIntoConstraints = false

    container.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: container.topAnchor),
      stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])

    return container
  }

  private func makeSectionHeader(title: String, systemImage: String) -> UIView {
    let imageView = UIImageView(image: UIImage(systemName: systemImage))
    imageView.tintColor = AppTheme.primaryColor
    imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
    imageView.setContentHuggingPriority(.required, for: .horizontal)

    let label = UILabel()
    label.text = title
    label.font = AppTheme.sectionTitleFont
    label.textColor = AppTheme.primaryTextColor
    label.numberOfLines = 0

    let stack = UIStackView(arrangedSubviews: [imageView, label])
    stack.axis = .horizontal
    stack.spacing = 10
    stack.alignment = .center

    return stack
  }

  private func makeStepRow(number: Int, text: String) -> UIView {
    let circleLabel = PaddingLabel()
    circleLabel.text = "\(number)"
    circleLabel.textColor = .white
    circleLabel.backgroundColor = AppTheme.primaryColor
    circleLabel.font = .systemFont(ofSize: 14, weight: .bold)
    circleLabel.textAlignment = .center
    circleLabel.layer.cornerRadius = 14
    circleLabel.layer.masksToBounds = true
    circleLabel.horizontalPadding = 8
    circleLabel.verticalPadding = 5
    circleLabel.setContentHuggingPriority(.required, for: .horizontal)
    circleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true

    let textLabel = UILabel()
    textLabel.text = text
    textLabel.numberOfLines = 0
    textLabel.font = AppTheme.bodyFont
    textLabel.textColor = AppTheme.primaryTextColor

    let stack = UIStackView(arrangedSubviews: [circleLabel, textLabel])
    stack.axis = .horizontal
    stack.spacing = 12
    stack.alignment = .top

    return stack
  }

  private func makeCardView() -> UIView {
    let card = UIView()
    card.backgroundColor = AppTheme.cardBackgroundColor
    card.layer.cornerRadius = AppTheme.largeCornerRadius
    card.layer.cornerCurve = .continuous
    card.layer.borderWidth = 1
    card.layer.borderColor = AppTheme.separatorColor.withAlphaComponent(0.10).cgColor
    card.layer.shadowColor = UIColor.black.withAlphaComponent(0.04).cgColor
    card.layer.shadowOpacity = 1
    card.layer.shadowRadius = 10
    card.layer.shadowOffset = CGSize(width: 0, height: 4)
    return card
  }

  @objc private func close() {
    dismiss(animated: true)
  }
}

private struct FAQItem {
  let question: String
  let answer: String
}

private final class SleekFAQItemView: UIView {

  private let item: FAQItem
  private let answerLabel = UILabel()
  private let chevronImageView = UIImageView()
  private var isExpanded = false

  init(item: FAQItem) {
    self.item = item
    super.init(frame: .zero)
    configure()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func configure() {
    backgroundColor = AppTheme.secondaryBackgroundColor
    layer.cornerRadius = 14
    layer.cornerCurve = .continuous
    layer.borderWidth = 1
    layer.borderColor = AppTheme.separatorColor.withAlphaComponent(0.10).cgColor

    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(toggleExpanded), for: .touchUpInside)

    let questionLabel = UILabel()
    questionLabel.text = item.question
    questionLabel.font = .systemFont(ofSize: 16, weight: .semibold)
    questionLabel.textColor = AppTheme.primaryTextColor
    questionLabel.numberOfLines = 0

    chevronImageView.image = UIImage(systemName: "chevron.down")
    chevronImageView.tintColor = AppTheme.primaryColor
    chevronImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
    chevronImageView.setContentHuggingPriority(.required, for: .horizontal)

    let headerStack = UIStackView(arrangedSubviews: [questionLabel, chevronImageView])
    headerStack.axis = .horizontal
    headerStack.spacing = 12
    headerStack.alignment = .top
    headerStack.translatesAutoresizingMaskIntoConstraints = false

    answerLabel.text = item.answer
    answerLabel.font = .systemFont(ofSize: 15, weight: .regular)
    answerLabel.textColor = AppTheme.secondaryTextColor
    answerLabel.numberOfLines = 0
    answerLabel.isHidden = true
    answerLabel.alpha = 0
    answerLabel.translatesAutoresizingMaskIntoConstraints = false

    addSubview(headerStack)
    addSubview(answerLabel)
    addSubview(button)

    NSLayoutConstraint.activate([
      headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
      headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      headerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

      answerLabel.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
      answerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      answerLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
      answerLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

      button.topAnchor.constraint(equalTo: topAnchor),
      button.leadingAnchor.constraint(equalTo: leadingAnchor),
      button.trailingAnchor.constraint(equalTo: trailingAnchor),
      button.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }

  @objc private func toggleExpanded() {
    isExpanded.toggle()

    if isExpanded {
      answerLabel.isHidden = false
    }

    UIView.animate(withDuration: 0.22, animations: {
      self.answerLabel.alpha = self.isExpanded ? 1 : 0
      self.chevronImageView.transform = self.isExpanded
        ? CGAffineTransform(rotationAngle: .pi)
        : .identity
    }, completion: { _ in
      self.answerLabel.isHidden = !self.isExpanded
    })
  }
}

private final class PaddingLabel: UILabel {
  var horizontalPadding: CGFloat = 0
  var verticalPadding: CGFloat = 0

  override var intrinsicContentSize: CGSize {
    let size = super.intrinsicContentSize
    return CGSize(
      width: size.width + horizontalPadding * 2,
      height: size.height + verticalPadding * 2
    )
  }

  override func drawText(in rect: CGRect) {
    let insets = UIEdgeInsets(
      top: verticalPadding,
      left: horizontalPadding,
      bottom: verticalPadding,
      right: horizontalPadding
    )
    super.drawText(in: rect.inset(by: insets))
  }
}

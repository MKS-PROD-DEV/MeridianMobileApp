/*
  Site Selection controller.
  - Site Selector
*/
import UIKit

final class InitialSiteSelectionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  private let onConfirm: (Branding) -> Void
  private var selectedBranding: Branding?

  private let scrollView: UIScrollView = {
    let view = UIScrollView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.alwaysBounceVertical = true
    view.keyboardDismissMode = .onDrag
    return view
  }()

  private let contentView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private let logoContainerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = AppTheme.secondaryBackgroundColor
    view.layer.cornerRadius = 22
    return view
  }()

  private let logoImageView: UIImageView = {
    let imageView = UIImageView(image: UIImage(named: "MGLogo"))
      imageView.translatesAutoresizingMaskIntoConstraints = false
      imageView.contentMode = .scaleAspectFit
    return imageView
  }()

  private let titleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = AppConfiguration.branding.fullName
    label.font = AppTheme.titleFont
    label.textAlignment = .center
    label.textColor = AppTheme.primaryTextColor
    return label
  }()

  private let subtitleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = L10n.tr("site_selection.subtitle")
    label.font = AppTheme.bodyFont
    label.textAlignment = .center
    label.textColor = AppTheme.secondaryTextColor
    label.numberOfLines = 0
    return label
  }()

  private let listTitleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = AppTheme.sectionTitleFont
    label.textColor = AppTheme.primaryTextColor
    return label
  }()

  private let cardContainerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = AppTheme.cardBackgroundColor
    view.layer.cornerRadius = AppTheme.largeCornerRadius
    view.layer.cornerCurve = .continuous
    return view
  }()

    private let tableView: UITableView = {
      let tableView = UITableView(frame: .zero, style: .insetGrouped)
      tableView.translatesAutoresizingMaskIntoConstraints = false
      tableView.backgroundColor = .clear
      tableView.separatorStyle = .singleLine
      tableView.showsVerticalScrollIndicator = false
      tableView.isScrollEnabled = true
      return tableView
    }()

  private let confirmButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle(L10n.tr("site_selection.confirm"), for: .normal)
    AppTheme.stylePrimaryButton(button)
    button.isEnabled = false
    button.alpha = 0.5
    return button
  }()

  init(onConfirm: @escaping (Branding) -> Void) {
    self.onConfirm = onConfirm
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .fullScreen
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = AppTheme.groupedBackgroundColor

    tableView.dataSource = self
    tableView.delegate = self
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BrandingCell")
    tableView.rowHeight = 72
    tableView.sectionHeaderHeight = 0
    tableView.sectionFooterHeight = 0

    confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

    setupLayout()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    tableView.layoutIfNeeded()
  }

  private func setupLayout() {
    view.addSubview(scrollView)
    scrollView.addSubview(contentView)

    contentView.addSubview(logoContainerView)
    logoContainerView.addSubview(logoImageView)
    contentView.addSubview(titleLabel)
    contentView.addSubview(subtitleLabel)
    contentView.addSubview(listTitleLabel)
    contentView.addSubview(cardContainerView)
    cardContainerView.addSubview(tableView)
    contentView.addSubview(confirmButton)

    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
      contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
      contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

      logoContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
      logoContainerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
      logoContainerView.widthAnchor.constraint(equalToConstant: 112),
      logoContainerView.heightAnchor.constraint(equalToConstant: 112),

      logoImageView.centerXAnchor.constraint(equalTo: logoContainerView.centerXAnchor),
      logoImageView.centerYAnchor.constraint(equalTo: logoContainerView.centerYAnchor),
      logoImageView.widthAnchor.constraint(equalToConstant: 76),
      logoImageView.heightAnchor.constraint(equalToConstant: 76),

      titleLabel.topAnchor.constraint(equalTo: logoContainerView.bottomAnchor, constant: 20),
      titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.screenHorizontalPadding),
      titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.screenHorizontalPadding),

      subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
      subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.screenHorizontalPadding),
      subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.screenHorizontalPadding),

      listTitleLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
      listTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.screenHorizontalPadding),
      listTitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.screenHorizontalPadding),

      cardContainerView.topAnchor.constraint(equalTo: listTitleLabel.bottomAnchor, constant: 12),
      cardContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      cardContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

      tableView.topAnchor.constraint(equalTo: cardContainerView.topAnchor, constant: 4),
      tableView.leadingAnchor.constraint(equalTo: cardContainerView.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: cardContainerView.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: cardContainerView.bottomAnchor, constant: -4),
      tableView.heightAnchor.constraint(equalToConstant: 320),

      confirmButton.topAnchor.constraint(equalTo: cardContainerView.bottomAnchor, constant: 24),
      confirmButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.screenHorizontalPadding),
      confirmButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.screenHorizontalPadding),
      confirmButton.heightAnchor.constraint(equalToConstant: 54),
      confirmButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -28)
    ])
  }

  @objc private func confirmTapped() {
    guard let selectedBranding else { return }
    onConfirm(selectedBranding)
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    Branding.allCases.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let branding = Branding.allCases[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: "BrandingCell", for: indexPath)

    var content = cell.defaultContentConfiguration()
    content.text = branding.fullName
    content.secondaryText = branding.hostDisplayName
    content.textProperties.font = .systemFont(ofSize: 17, weight: .semibold)
    content.textProperties.color = AppTheme.primaryTextColor
    content.secondaryTextProperties.font = AppTheme.secondaryFont
    content.secondaryTextProperties.color = AppTheme.secondaryTextColor

    cell.contentConfiguration = content
    cell.backgroundColor = .clear
    cell.selectionStyle = .none
    cell.accessoryType = branding == selectedBranding ? .checkmark : .none
    cell.tintColor = AppTheme.accentColor

    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    selectedBranding = Branding.allCases[indexPath.row]
    confirmButton.isEnabled = true
    confirmButton.alpha = 1.0
    tableView.reloadData()
  }
}

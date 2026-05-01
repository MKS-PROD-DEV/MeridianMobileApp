import UIKit

final class InitialSiteSelectionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  private let onConfirm: (Branding) -> Void
  private var selectedBranding: Branding?

  private let logoImageView: UIImageView = {
    let iv = UIImageView(image: UIImage(named: "MGLogo"))
    iv.translatesAutoresizingMaskIntoConstraints = false
    iv.contentMode = .scaleAspectFit
    return iv
  }()

  private let titleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "Meridian Global"
    label.font = .systemFont(ofSize: 28, weight: .bold)
    label.textAlignment = .center
    label.textColor = .label
    return label
  }()

  private let subtitleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "Please select your Organization to continue."
    label.font = .systemFont(ofSize: 17, weight: .regular)
    label.textAlignment = .center
    label.textColor = .secondaryLabel
    label.numberOfLines = 0
    return label
  }()

  private let tableView: UITableView = {
    let tableView = UITableView(frame: .zero, style: .insetGrouped)
    tableView.translatesAutoresizingMaskIntoConstraints = false
    return tableView
  }()

  private let confirmButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("Confirm", for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
    button.backgroundColor = AppTheme.primaryColor
    button.setTitleColor(.white, for: .normal)
    button.layer.cornerRadius = 12
    button.isEnabled = false
    button.alpha = 0.5
    return button
  }()

  init(onConfirm: @escaping (Branding) -> Void) {
    self.onConfirm = onConfirm
    super.init(nibName: nil, bundle: nil)
    self.modalPresentationStyle = .fullScreen
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    tableView.dataSource = self
    tableView.delegate = self
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BrandingCell")

    confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

    view.addSubview(logoImageView)
    view.addSubview(titleLabel)
    view.addSubview(subtitleLabel)
    view.addSubview(tableView)
    view.addSubview(confirmButton)

    NSLayoutConstraint.activate([
      logoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
      logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      logoImageView.widthAnchor.constraint(equalToConstant: 96),
      logoImageView.heightAnchor.constraint(equalToConstant: 96),

      titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 12),
      titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

      subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
      subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

      tableView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

      confirmButton.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: 16),
      confirmButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
      confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
      confirmButton.heightAnchor.constraint(equalToConstant: 50)
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
      content.text = branding.displayName
      content.secondaryText = "\(branding.fullName) • \(branding.hostDisplayName)"

      cell.contentConfiguration = content
      cell.accessoryType = (branding == selectedBranding) ? .checkmark : .none

      return cell
    }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    selectedBranding = Branding.allCases[indexPath.row]
    confirmButton.isEnabled = true
    confirmButton.alpha = 1.0
    tableView.reloadData()
  }
}

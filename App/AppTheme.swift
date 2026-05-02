import UIKit

enum AppTheme {
  static var primaryColor: UIColor {
    switch AppConfiguration.branding {
    case .mg:
      return UIColor(red: 0 / 255, green: 131 / 255, blue: 203 / 255, alpha: 1.0)
    case .psi:
      return UIColor.systemGreen
    case .adc:
      return UIColor.systemYellow
    case .cov:
      return UIColor.systemTeal
    case .vabc:
      return UIColor.systemRed
    }
  }

  static var accentColor: UIColor {
    primaryColor
  }

  static var backgroundColor: UIColor {
    .systemBackground
  }

  static var groupedBackgroundColor: UIColor {
    .systemGroupedBackground
  }

  static var secondaryBackgroundColor: UIColor {
    .secondarySystemBackground
  }

  static var cardBackgroundColor: UIColor {
    .secondarySystemBackground
  }

  static var primaryTextColor: UIColor {
    .label
  }

  static var secondaryTextColor: UIColor {
    .secondaryLabel
  }

  static var destructiveColor: UIColor {
    .systemRed
  }

  static var separatorColor: UIColor {
    .separator
  }

  static var cornerRadius: CGFloat {
    14
  }

  static var largeCornerRadius: CGFloat {
    18
  }

  static var screenHorizontalPadding: CGFloat {
    20
  }

  static var sectionSpacing: CGFloat {
    24
  }

  static var rowHeight: CGFloat {
    64
  }

  static var titleFont: UIFont {
    .systemFont(ofSize: 28, weight: .bold)
  }

  static var sectionTitleFont: UIFont {
    .systemFont(ofSize: 20, weight: .semibold)
  }

  static var bodyFont: UIFont {
    .systemFont(ofSize: 17, weight: .regular)
  }

  static var secondaryFont: UIFont {
    .systemFont(ofSize: 14, weight: .regular)
  }

  static var buttonFont: UIFont {
    .systemFont(ofSize: 18, weight: .semibold)
  }

  static var logoImage: UIImage? {
    switch AppConfiguration.branding {
    case .mg:
      return UIImage(named: "MGLogo")
    case .psi:
      return UIImage(named: "PSILogo")
    case .adc:
      return UIImage(named: "ADCLogo")
    case .cov:
      return UIImage(named: "COVLogo")
    case .vabc:
      return UIImage(named: "VABCLogo")
    }
  }

  static var shortText: String {
    switch AppConfiguration.branding {
    case .mg:
      return "MG"
    case .psi:
      return "PSI"
    case .adc:
      return "ADC"
    case .cov:
      return "COV"
    case .vabc:
      return "VABC"
    }
  }

  static func stylePrimaryButton(_ button: UIButton) {
    button.backgroundColor = primaryColor
    button.setTitleColor(.white, for: .normal)
    button.titleLabel?.font = buttonFont
    button.layer.cornerRadius = cornerRadius
    button.clipsToBounds = true
  }

  static func styleSecondaryButton(_ button: UIButton) {
    button.backgroundColor = secondaryBackgroundColor
    button.setTitleColor(primaryTextColor, for: .normal)
    button.titleLabel?.font = buttonFont
    button.layer.cornerRadius = cornerRadius
    button.clipsToBounds = true
  }

  static func applyNavigationBarAppearance(to navigationController: UINavigationController?) {
    guard let navigationBar = navigationController?.navigationBar else { return }

    let appearance = UINavigationBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = backgroundColor
    appearance.titleTextAttributes = [.foregroundColor: primaryTextColor]
    appearance.largeTitleTextAttributes = [.foregroundColor: primaryTextColor]
    appearance.shadowColor = .clear

    navigationBar.standardAppearance = appearance
    navigationBar.scrollEdgeAppearance = appearance
    navigationBar.compactAppearance = appearance
    navigationBar.tintColor = accentColor
    navigationBar.prefersLargeTitles = false
  }
}

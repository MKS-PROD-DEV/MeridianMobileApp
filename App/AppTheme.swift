import UIKit

enum AppTheme {
  static var primaryColor: UIColor {
    switch AppConfiguration.branding {
    case .mg:
      return UIColor(red: 0/255, green: 131/255, blue: 203/255, alpha: 1.0)
    case .psi:
      return UIColor.systemGreen
    }
  }

  static var backgroundColor: UIColor {
    .white
  }

  static var logoImage: UIImage? {
    switch AppConfiguration.branding {
    case .mg:
      return UIImage(named: "MGLogo")
    case .psi:
      return UIImage(named: "PSILogo")
    }
  }

  static var shortText: String {
    switch AppConfiguration.branding {
    case .mg:
      return "MG"
    case .psi:
      return "PSI"
    }
  }
}

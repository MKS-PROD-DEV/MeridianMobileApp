import Foundation

enum Branding {
  case mg
  case psi
}

enum AppConfiguration {
  static let branding: Branding = .psi
  static let isOfflineModeAuthenticationEnabled = false

  static var launchURL: URL {
    switch branding {
    case .mg:
      return URL(string: "https://sandbox7.mksi-lms.net")!
    case .psi:
      return URL(string: "https://psiadmin.mkscloud.com/support")!
    }
  }
}

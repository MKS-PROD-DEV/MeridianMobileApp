import Foundation

enum Branding: String, CaseIterable {
  case mg
  case psi
  case adc
  case cov
  case vabc

  var displayName: String {
    switch self {
    case .mg: return "MG"
    case .psi: return "PSI"
    case .adc: return "ADC"
    case .cov: return "COV"
    case .vabc: return "VABC"
    }
  }

  var fullName: String {
    switch self {
    case .mg: return "Meridian Global"
    case .psi: return "PSI"
    case .adc: return "ADC"
    case .cov: return "COV"
    case .vabc: return "VABC"
    }
  }

  var hostDisplayName: String {
    switch self {
    case .mg: return "sandbox7.mksi-lms.net"
    case .psi: return "psiadmin.mkscloud.com/support"
    case .adc: return "adc-admin.mkscloud.com"
    case .cov: return "covlc.virginia.gov"
    case .vabc: return "vabc.mkscloud.com"
    }
  }

  var launchURL: URL {
    switch self {
    case .mg:
      return URL(string: "https://sandbox7.mksi-lms.net")!
    case .psi:
      return URL(string: "https://psiadmin.mkscloud.com/support")!
    case .adc:
      return URL(string: "https://adc-admin.mkscloud.com")!
    case .cov:
      return URL(string: "https://covlc.virginia.gov")!
    case .vabc:
      return URL(string: "https://vabc.mkscloud.com")!
    }
  }
}

enum AppConfiguration {
  private static let brandingKey = "app.configuration.branding"

  static let isOfflineModeAuthenticationEnabled = false

  static var hasSelectedBranding: Bool {
    UserDefaults.standard.string(forKey: brandingKey) != nil
  }

  static var branding: Branding {
    get {
      guard let rawValue = UserDefaults.standard.string(forKey: brandingKey),
            let branding = Branding(rawValue: rawValue) else {
        return .mg
      }
      return branding
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: brandingKey)
    }
  }

  static var launchURL: URL {
    branding.launchURL
  }
}

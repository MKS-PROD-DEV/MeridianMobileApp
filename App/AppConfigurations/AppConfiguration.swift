/*
  App Configuration File.
  - Declared clients
  - Declared Display Names
  - Declare Host and Launch URLS
  - Configs for Biometrics
  - Configs to enable localization
  - Configs to add locales
*/
import Foundation

enum Branding: String, CaseIterable {
  case meridian
  case psi
  case adc
  case cov
  case vabc

  var displayName: String {
    switch self {
    case .meridian: return "MG"
    case .psi: return "PSI"
    case .adc: return "ADC"
    case .cov: return "COV"
    case .vabc: return "VABC"
    }
  }

  var fullName: String {
    switch self {
    case .meridian: return "Meridian Global"
    case .psi: return "PSI"
    case .adc: return "ADC"
    case .cov: return "COV"
    case .vabc: return "VABC"
    }
  }

  var hostDisplayName: String {
    switch self {
    case .meridian: return "sandbox7.mksi-lms.net"
    case .psi: return "psiadmin.mkscloud.com"
    case .adc: return "adc-admin.mkscloud.com"
    case .cov: return "covlc.virginia.gov"
    case .vabc: return "vabc.mkscloud.com"
    }
  }

  var launchURL: URL {
    switch self {
    case .meridian:
      return URL(string: "https://sandbox7.mksi-lms.net")!
    case .psi:
      return URL(string: "https://psiadmin.mkscloud.com")!
    case .adc:
      return URL(string: "https://adc-admin.mkscloud.com")!
    case .cov:
      return URL(string: "https://covlc.virginia.gov")!
    case .vabc:
      return URL(string: "https://vabc.mkscloud.com")!
    }
  }
}

enum AppLanguage: String, CaseIterable {
  case english = "en"
  case spanish = "es"

  var displayName: String {
    switch self {
    case .english: return "English"
    case .spanish: return "Español"
    }
  }
}

enum OfflineContentType {
  case scorm
  case video
  case pdf
  case document
  case web
  case unsupported

  static func from(fileURL: URL) -> OfflineContentType {
    switch fileURL.pathExtension.lowercased() {
    case "mp4", "mov", "m4v":
      return .video
    case "pdf":
      return .pdf
    case "doc", "docx", "ppt", "pptx", "xls", "xlsx", "txt":
      return .document
    case "html", "htm":
      return .web
    default:
      return .unsupported
    }
  }

  var localizedDisplayName: String {
    switch self {
    case .scorm:
      return L10n.tr("offline_content.type.scorm")
    case .video:
      return L10n.tr("offline_content.type.video")
    case .pdf:
      return L10n.tr("offline_content.type.pdf")
    case .document:
      return L10n.tr("offline_content.type.document")
    case .web:
      return L10n.tr("offline_content.type.web")
    case .unsupported:
      return L10n.tr("offline_content.type.unsupported")
    }
  }
}

enum AppConfiguration {
  private static let brandingKey = "app.configuration.branding"
  private static let languageKey = "app.configuration.language"

  static let isOfflineModeAuthenticationEnabled = false

  static let isLocalizationEnabled = true

  static let availableLanguages: [AppLanguage] = [
    .english,
    .spanish
  ]

  static var hasSelectedBranding: Bool {
    UserDefaults.standard.string(forKey: brandingKey) != nil
  }

  static var branding: Branding {
    get {
      guard let rawValue = UserDefaults.standard.string(forKey: brandingKey),
        let branding = Branding(rawValue: rawValue) else {
        return .meridian
      }
      return branding
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: brandingKey)
    }
  }

  static var selectedLanguage: AppLanguage {
    get {
      guard
        isLocalizationEnabled,
        let rawValue = UserDefaults.standard.string(forKey: languageKey),
        let language = AppLanguage(rawValue: rawValue)
      else {
        return .english
      }
      return language
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: languageKey)
    }
  }

  static var launchURL: URL {
    branding.launchURL
  }
}

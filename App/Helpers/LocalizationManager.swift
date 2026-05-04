/*
  Handles Localization
*/
import Foundation

enum L10n {
  static func tr(_ key: String) -> String {
    guard AppConfiguration.isLocalizationEnabled else {
      return L10n.tr(key)
    }

    let languageCode = AppConfiguration.selectedLanguage.rawValue

    guard
      let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
      let bundle = Bundle(path: path)
    else {
      return L10n.tr(key)
    }

    return bundle.localizedString(forKey: key, value: nil, table: "Localizable")
  }
}

/*
  Standard iOS app entry point.
  - app startup
  - Capacitor URL handling hooks
  - debug logging for app Documents path
*/
import Capacitor
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Override point for customization after application launch.
    // Prints simulator path for local debugging.
    print(
      "FOLDER PATH IS: \(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path)"
    )
      AppLogStore.shared.log(
        "App launched. Documents path: \(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path)"
      )
      let isDarkModeEnabled = UserDefaults.standard.bool(forKey: "settings.appearance.darkMode.enabled")
      let style: UIUserInterfaceStyle = isDarkModeEnabled ? .dark : .light

      UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .forEach { $0.overrideUserInterfaceStyle = style }
    NotificationController.shared.configure()
    return true
  }

  func applicationWillResignActive(_ application: UIApplication) {
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
  }

  func applicationWillTerminate(_ application: UIApplication) {
  }

  func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
  }

  func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    // Called when the app was launched with an activity, including Universal Links.
    // Feel free to add additional processing here, but if we want the App API to support
    // App store tracking is done here I think. Leave this
    return ApplicationDelegateProxy.shared.application(
      application, continue: userActivity, restorationHandler: restorationHandler)
  }
}

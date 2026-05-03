/*
  Notification controller.
  - hosting popup `WKWebView` instances
  - presenting popup content modally
  - allowing the user to close popup windows
*/
import Foundation
import UserNotifications
import UIKit

enum AppNotificationType {
  case simple
  case summarized
}

final class NotificationController: NSObject {
  static let shared = NotificationController()

  private let center = UNUserNotificationCenter.current()
  private let notificationsEnabledKey = "settings.notifications.enabled"

  private override init() {
    super.init()
  }

  var notificationsEnabled: Bool {
    UserDefaults.standard.object(forKey: notificationsEnabledKey) as? Bool ?? true
  }

  func configure() {
    center.delegate = self
  }

  func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
    guard notificationsEnabled else {
      completion?(false)
      return
    }

    center.getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
        completion?(true)

      case .notDetermined:
        self.center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
          completion?(granted)
        }

      case .denied:
        completion?(false)

      @unknown default:
        completion?(false)
      }
    }
  }

  func updateNotificationPreference(enabled: Bool) {
    UserDefaults.standard.set(enabled, forKey: notificationsEnabledKey)

    if !enabled {
      clearAllPendingAndDeliveredNotifications()
    }
  }

  func scheduleSimpleNotification(
    title: String,
    body: String,
    identifier: String = UUID().uuidString,
    timeInterval: TimeInterval = 1
  ) {
    guard notificationsEnabled else { return }

    requestAuthorizationIfNeeded { granted in
      guard granted else { return }

      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default
      content.interruptionLevel = .active

      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, timeInterval), repeats: false)
      let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

      self.center.add(request) { error in
        if let error = error {
          print("Failed to schedule simple notification:", error.localizedDescription)
        } else {
          print("Scheduled simple notification:", identifier)
        }
      }
    }
  }

    func scheduleSummarizedNotification(
      title: String,
      body: String,
      identifier: String = UUID().uuidString,
      threadIdentifier: String,
      timeInterval: TimeInterval = 1
    ) {
    guard notificationsEnabled else { return }

    requestAuthorizationIfNeeded { granted in
      guard granted else { return }

      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default
      content.threadIdentifier = threadIdentifier
      content.interruptionLevel = .passive

      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, timeInterval), repeats: false)
      let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

      self.center.add(request) { error in
        if let error = error {
          print("Failed to schedule summarized notification:", error.localizedDescription)
        } else {
          print("Scheduled summarized notification:", identifier)
        }
      }
    }
  }

  func clearAllPendingAndDeliveredNotifications() {
    center.removeAllPendingNotificationRequests()
    center.removeAllDeliveredNotifications()
    print("Cleared all pending and delivered notifications")
  }

  func openSystemNotificationSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }
}

extension NotificationController: UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    guard notificationsEnabled else {
      completionHandler([])
      return
    }

    completionHandler([.banner, .sound, .list])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    print("Notification tapped:", response.notification.request.identifier)
    completionHandler()
  }
}

//
//  AppDelegate.swift
//  glimm
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Route to open when app launches from a notification tap.
    @MainActor static var pendingLaunchRoute: NotificationRoute?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Called when user taps notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let route = NotificationRoute(
            userInfo: response.notification.request.content.userInfo
        )

        Task { @MainActor in
            // Set route for cold launch (when MainTabView isn't mounted yet).
            AppDelegate.pendingLaunchRoute = route
            // Post route for warm launch (when app is already running).
            NotificationCenter.default.post(name: .openNotificationDestination, object: route)
            completionHandler()
        }
    }

    // Called when notification arrives while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

extension Notification.Name {
    static let openNotificationDestination = Notification.Name("openNotificationDestination")
}

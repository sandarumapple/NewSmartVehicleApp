import FirebaseMessaging
import GoogleSignIn
import SwiftUI
import UserNotifications

@main
struct SmartVehicleApp: App {
    @UIApplicationDelegateAdaptor(FirebaseAppDelegate.self) private var firebaseDelegate
    @StateObject private var store: AppStore

    init() {
        _store = StateObject(wrappedValue: AppStore(dependencies: .live()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onOpenURL { url in
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

final class FirebaseAppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseBackend.configureIfAvailable()
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        if FirebaseBackend.isConfigured {
            Messaging.messaging().delegate = self
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        if FirebaseBackend.isConfigured {
            Messaging.messaging().apnsToken = deviceToken
            NotificationCenter.default.post(name: .smartVehicleAPNsReady, object: nil)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationCenter.default.post(
            name: .smartVehicleAPNsFailed, object: error.localizedDescription)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistration installationId: String?) {
        guard let installationId else { return }
        NotificationCenter.default.post(
            name: .smartVehicleFCMRegistration, object: installationId)
    }
}

extension Notification.Name {
    static let smartVehicleAPNsReady = Notification.Name("SmartVehicleAPNsReady")
    static let smartVehicleAPNsFailed = Notification.Name("SmartVehicleAPNsFailed")
    static let smartVehicleFCMRegistration = Notification.Name("SmartVehicleFCMRegistration")
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if FirebaseBackend.isConfigured,
            notification.request.trigger is UNPushNotificationTrigger
        {
            Messaging.messaging().appDidReceiveMessage(notification.request.content.userInfo)
            let type = notification.request.content.userInfo["type"] as? String
            if type == "like" || type == "comment" {
                // The active Firestore inbox listener presents this event locally.
                // Suppress a duplicate foreground banner if FCM also delivers it.
                completionHandler([])
                return
            }
        }
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if FirebaseBackend.isConfigured,
            response.notification.request.trigger is UNPushNotificationTrigger
        {
            Messaging.messaging().appDidReceiveMessage(response.notification.request.content.userInfo)
        }
        completionHandler()
    }
}

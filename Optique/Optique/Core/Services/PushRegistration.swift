import UIKit
import OSLog

/// Remote push plumbing: asks iOS for a device token and hands it to the backend (`/api/devices`),
/// which then sends the alerts through APNs. The token identifies the phone, not the reader.
@MainActor
enum PushRegistration {

    /// APNs has two separate worlds: Xcode debug builds talk to the sandbox, TestFlight and App Store builds to production.
    private static var environment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }

    /// Safe to call often: iOS answers with the same token until it changes.
    static func registerIfAuthorized(status: UNAuthorizationStatus) {
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }
        #if DEBUG
        if Fixtures.isActive { return }
        #endif
        UIApplication.shared.registerForRemoteNotifications()
    }

    static func upload(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        Task {
            do {
                try await APIClient.shared.post("devices", body: ["token": token, "environment": environment, "app_version": version])
                Log.notification.info("Push token registered (\(environment))")
            } catch {
                Log.notification.error("Push token upload failed: \(error)")
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushRegistration.upload(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.notification.error("Remote notification registration failed: \(error)")
    }
}

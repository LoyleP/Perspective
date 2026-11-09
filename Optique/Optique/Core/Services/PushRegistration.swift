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
    /// A reader who hasn't finished the onboarding (first launch, or after "Nouvel utilisateur") isn't registered,
    /// even when iOS permission was granted earlier: the phone joins the push list when the onboarding ends.
    static func registerIfAuthorized(status: UNAuthorizationStatus) {
        guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }
        #if DEBUG
        if Fixtures.isActive { return }
        #endif
        UIApplication.shared.registerForRemoteNotifications()
    }

    private static let tokenKey = "pushDeviceToken"

    /// Takes this phone off the push list (used by the "new user" reset). iOS keeps its own permission switch,
    /// which an app can't turn off: only deleting the app or the Réglages toggle resets it.
    static func unregister() {
        UIApplication.shared.unregisterForRemoteNotifications()
        guard let token = UserDefaults.standard.string(forKey: tokenKey) else { return }
        UserDefaults.standard.removeObject(forKey: tokenKey)
        Task { try? await APIClient.shared.post("devices", body: ["token": token], method: "DELETE") }
    }

    static func upload(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenKey)
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

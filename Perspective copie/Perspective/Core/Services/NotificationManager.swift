import Foundation
import UserNotifications
import BackgroundTasks
import Supabase

@Observable
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    /// Set when the user taps a system notification; observed by RootView and AlertesView.
    var pendingStoryID: UUID?
    private var lastCheckedStoryCount = 0

    private let center = UNUserNotificationCenter.current()

    override private init() {
        super.init()
        center.delegate = self
        Task {
            await checkAuthorizationStatus()
            await loadLastStoryCount()
        }
    }

    // MARK: - Permission Handling

    func requestAuthorization() async throws {
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        print("🔔 Notification authorization \(granted ? "granted" : "denied")")
        await checkAuthorizationStatus()
    }

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        await MainActor.run {
            authorizationStatus = settings.authorizationStatus
        }
    }

    // MARK: - Local Notification Scheduling

    func checkForNewStories() async {
        print("🔔 Checking for new stories, current auth status: \(authorizationStatus.rawValue)")

        guard authorizationStatus == .authorized else {
            print("⚠️ Notifications not authorized, current status: \(authorizationStatus.rawValue)")
            return
        }

        do {
            // Check for new notifications in the database
            let lastNotificationId = UserDefaults.standard.string(forKey: "lastNotificationId") ?? ""
            print("🔔 Last notification ID: \(lastNotificationId)")

            let response = try await SupabaseService.shared.client
                .from("notifications")
                .select()
                .order("sent_at", ascending: false)
                .limit(1)
                .execute()

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let notifications = try decoder.decode([PushNotification].self, from: response.data)

            print("🔔 Found \(notifications.count) notifications in database")

            // If we have a new notification
            if let latestNotification = notifications.first,
               latestNotification.id.uuidString != lastNotificationId {

                print("🔔 New notification found: \(latestNotification.title)")

                // Schedule local notification
                await scheduleLocalNotification(
                    title: latestNotification.title,
                    body: latestNotification.body,
                    storyID: latestNotification.storyId
                )

                // Save this notification ID as seen
                UserDefaults.standard.set(latestNotification.id.uuidString, forKey: "lastNotificationId")
            } else {
                print("🔔 No new notifications (either empty or already seen)")
            }

        } catch {
            print("❌ Failed to check for new notifications: \(error)")
        }
    }

    private func loadLastStoryCount() async {
        lastCheckedStoryCount = UserDefaults.standard.integer(forKey: "lastStoryCount")
    }

    private func scheduleLocalNotification(title: String, body: String, storyID: UUID?) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let storyID {
            content.userInfo = ["story_id": storyID.uuidString]
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await center.add(request)
            print("✅ Local notification scheduled: \(title)")
        } catch {
            print("❌ Failed to schedule notification: \(error)")
        }
    }

    // MARK: - Fetch Notifications

    func fetchNotifications() async throws -> [PushNotification] {
        let response = try await SupabaseService.shared.client
            .from("notifications")
            .select()
            .order("sent_at", ascending: false)
            .limit(50)
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let notifications = try decoder.decode([PushNotification].self, from: response.data)
        return notifications
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let idString = userInfo["story_id"] as? String, let storyID = UUID(uuidString: idString) {
            Task { @MainActor in
                pendingStoryID = storyID
            }
        }
        print("📬 Notification tapped")
        completionHandler()
    }
}

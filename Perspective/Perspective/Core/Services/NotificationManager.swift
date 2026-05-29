import Foundation
import OSLog
import UserNotifications
import BackgroundTasks
import Supabase

@MainActor
@Observable
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    var authorizationStatus: UNAuthorizationStatus = .notDetermined
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
        Log.notification.info("Authorization \(granted ? "granted" : "denied")")
        await checkAuthorizationStatus()
    }

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Local Notification Scheduling

    func checkForNewStories() async {
        Log.notification.debug("Checking for new stories, auth status: \(self.authorizationStatus.rawValue)")

        guard authorizationStatus == .authorized else {
            Log.notification.info("Notifications not authorized, status: \(self.authorizationStatus.rawValue)")
            return
        }

        do {
            let lastNotificationId = UserDefaults.standard.string(forKey: "lastNotificationId") ?? ""

            let notifications: [PushNotification] = try await SupabaseService.shared.client
                .from("notifications")
                .select()
                .order("sent_at", ascending: false)
                .limit(1)
                .execute()
                .value

            if let latestNotification = notifications.first,
               latestNotification.id.uuidString != lastNotificationId {

                Log.notification.info("New notification: \(latestNotification.title)")

                await scheduleLocalNotification(
                    title: latestNotification.title,
                    body: latestNotification.body,
                    storyID: latestNotification.storyId
                )

                UserDefaults.standard.set(latestNotification.id.uuidString, forKey: "lastNotificationId")
            }

        } catch {
            Log.notification.error("Failed to check for new notifications: \(error)")
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
            trigger: nil
        )

        do {
            try await center.add(request)
            Log.notification.info("Local notification scheduled: \(title)")
        } catch {
            Log.notification.error("Failed to schedule notification: \(error)")
        }
    }

    // MARK: - Fetch Notifications

    func fetchNotifications() async throws -> [PushNotification] {
        let notifications: [PushNotification] = try await SupabaseService.shared.client
            .from("notifications")
            .select()
            .order("sent_at", ascending: false)
            .limit(50)
            .execute()
            .value
        return notifications
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: @preconcurrency UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
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
        Log.notification.debug("Notification tapped")
        completionHandler()
    }
}

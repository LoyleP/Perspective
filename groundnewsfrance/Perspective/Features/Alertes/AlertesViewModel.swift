import Foundation
import UserNotifications

@Observable
final class AlertesViewModel {
    var notifications: [PushNotification] = []
    var isLoading = false
    var error: Error?
    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    init() {
        authorizationStatus = NotificationManager.shared.authorizationStatus
    }

    func load() async {
        isLoading = true
        error = nil

        do {
            notifications = try await NotificationManager.shared.fetchNotifications()
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func requestNotificationPermission() async {
        do {
            try await NotificationManager.shared.requestAuthorization()
            await NotificationManager.shared.checkAuthorizationStatus()
            authorizationStatus = NotificationManager.shared.authorizationStatus
        } catch {
            self.error = error
        }
    }

    func refresh() async {
        await load()
    }
}

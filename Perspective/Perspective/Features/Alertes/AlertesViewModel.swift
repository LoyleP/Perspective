import Foundation
import UserNotifications

@MainActor
@Observable
final class AlertesViewModel {
    private(set) var notifications: [PushNotification] = []
    private(set) var isLoading = false
    private(set) var error: AppError?
    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let repository: any StoryRepositoryProtocol

    init(repository: any StoryRepositoryProtocol = StoryRepository.shared) {
        self.repository = repository
        authorizationStatus = NotificationManager.shared.authorizationStatus
    }

    func load() async {
        isLoading = true
        error = nil

        do {
            notifications = try await NotificationManager.shared.fetchNotifications()
        } catch {
            self.error = AppError.from(error)
        }

        isLoading = false
    }

    func requestNotificationPermission() async {
        do {
            try await NotificationManager.shared.requestAuthorization()
            await NotificationManager.shared.checkAuthorizationStatus()
            authorizationStatus = NotificationManager.shared.authorizationStatus
        } catch {
            self.error = AppError.from(error)
        }
    }

    func fetchStory(id: UUID) async -> Story? {
        try? await repository.fetchStory(id: id)
    }

    func refresh() async {
        await load()
    }
}

import SwiftUI
import UserNotifications

struct AlertesView: View {

    @State private var viewModel = AlertesViewModel()
    @State private var path = NavigationPath()
    @State private var isFetchingStory = false
    private let notificationManager = NotificationManager.shared

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Alertes")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: Story.self) { story in
                    StoryDetailView(story: story)
                }
                .task { await viewModel.load() }
                .onChange(of: notificationManager.pendingStoryID) { _, storyID in
                    guard let storyID else { return }
                    navigate(to: storyID)
                    notificationManager.pendingStoryID = nil
                }
        }
    }

    // MARK: - State routing

    @ViewBuilder
    private var content: some View {
        if viewModel.authorizationStatus == .notDetermined {
            permissionPrompt
        } else if viewModel.authorizationStatus == .denied {
            permissionDenied
        } else if viewModel.isLoading && viewModel.notifications.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
        } else if viewModel.notifications.isEmpty {
            emptyState
        } else {
            notificationList
        }
    }

    // MARK: - Permission prompts

    private var permissionPrompt: some View {
        ContentUnavailableView {
            Label("Activez les notifications", systemImage: "bell.badge")
        } description: {
            Text("Recevez une notification à chaque nouvelle actualité ajoutée.")
        } actions: {
            Button("Activer les notifications") {
                Task { await viewModel.requestNotificationPermission() }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.Adaptive.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
    }

    private var permissionDenied: some View {
        ContentUnavailableView {
            Label("Notifications désactivées", systemImage: "bell.slash")
        } description: {
            Text("Activez les notifications dans Réglages pour recevoir des alertes.")
        } actions: {
            Button("Ouvrir Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.Adaptive.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Aucune alerte", systemImage: "bell")
        } description: {
            Text("Vous recevrez une notification à chaque mise à jour.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
    }

    // MARK: - Notification list

    private var notificationList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.st) {
                ForEach(viewModel.notifications) { notification in
                    notificationCard(notification)
                }
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.top, AppSpacing.m)
            .padding(.bottom, AppSpacing.xxl)
        }
        .refreshable { await viewModel.refresh() }
        .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
    }

    private func notificationCard(_ notification: PushNotification) -> some View {
        Button {
            guard let storyId = notification.storyId else { return }
            navigate(to: storyId)
        } label: {
            HStack(alignment: .top, spacing: AppSpacing.m) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(notification.title)
                        .font(.appTitle3)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(notification.body)
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textBody)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if notification.storyId != nil {
                    Image(systemName: "chevron.right")
                        .font(.appFootnote)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                        .padding(.top, 2)
                }
            }
            .padding(AppSpacing.m)
            .background(AppColors.Adaptive.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.ml)
                    .stroke(AppColors.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation

    private func navigate(to storyID: UUID) {
        guard !isFetchingStory else { return }
        isFetchingStory = true
        Task {
            if let story = try? await StoryRepository.shared.fetchStory(id: storyID) {
                path.append(story)
            }
            isFetchingStory = false
        }
    }
}

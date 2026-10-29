import SwiftUI
import UserNotifications

/// Alerts tab: past alerts grouped by day. Marks alerts as seen.
struct AlertesView: View {

    @State private var viewModel = AlertesViewModel()
    @State private var selectedStory: Story?
    /// False while the tab is in the background; the list reloads each time it becomes active.
    var isActive = true
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            AppHeader()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.l) {
                    Text("Alertes")
                        .font(.appTitle)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if viewModel.authorizationStatus != .authorized && viewModel.authorizationStatus != .provisional {
                        permissionCard
                    }
                    content
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.bottom, AppSpacing.xxl)
            }
            .refreshable { await viewModel.refresh() }
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedStory) { story in
            StoryDetailView(story: story)
        }
        .task(id: isActive) {
            if isActive { await viewModel.load() }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.notifications.isEmpty {
            SkeletonLines(count: 6, lineHeight: 14)
                .padding(.top, AppSpacing.m)
        } else if let error = viewModel.error, viewModel.notifications.isEmpty {
            ContentUnavailableView {
                Label("Impossible de charger", hero: "signal-slash", size: 44)
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Réessayer") { Task { await viewModel.refresh() } }
                    .buttonStyle(.optiquePrimary)
            }
        } else if viewModel.notifications.isEmpty {
            ContentUnavailableView(
                "Aucune alerte",
                hero: "bell",
                description: Text("Les grands sujets du jour apparaîtront ici.")
            )
        } else {
            ForEach(days, id: \.day) { group in
                VStack(alignment: .leading, spacing: 0) {
                    Text(group.title)
                        .font(.appHeading)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, AppSpacing.xs)
                    ForEach(group.items) { notification in
                        row(notification)
                        Divider().overlay(AppColors.Adaptive.divider)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ notification: PushNotification) -> some View {
        let label = AlertRow(notification: notification)
        if let storyID = notification.storyId {
            Button {
                Task { selectedStory = await viewModel.fetchStory(id: storyID) }
            } label: {
                label
            }
            .buttonStyle(CardPressStyle())
        } else {
            label
        }
    }

    // MARK: - Permission

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            Label("Notifications désactivées", hero: "bell-slash")
                .font(.appBodyStrong)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
            Text("Activez-les pour être prévenu quand un grand sujet est couvert par plusieurs médias.")
                .font(.appBody)
                .foregroundStyle(AppColors.Adaptive.textBody)
            Button(viewModel.authorizationStatus == .notDetermined ? "Activer" : "Ouvrir les Réglages") {
                if viewModel.authorizationStatus == .notDetermined {
                    Task { await viewModel.requestNotificationPermission() }
                } else if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.optiquePrimary)
            .padding(.top, AppSpacing.xs)
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    // MARK: - Grouping

    private struct DayGroup {
        let day: Date
        let title: String
        let items: [PushNotification]
    }

    private var days: [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.notifications) { calendar.startOfDay(for: $0.sentAt) }
        return grouped.keys.sorted(by: >).map { day in
            let title: String
            if calendar.isDateInToday(day) {
                title = "Aujourd'hui"
            } else if calendar.isDateInYesterday(day) {
                title = "Hier"
            } else {
                title = day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR"))).capitalized
            }
            return DayGroup(day: day, title: title, items: grouped[day] ?? [])
        }
    }
}

// MARK: - Row

private struct AlertRow: View {
    let notification: PushNotification

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(notification.sentAt.formatted(.dateTime.hour().minute().locale(Locale(identifier: "fr_FR"))))
                .overlineStyle()
            Text(notification.title)
                .font(.appBodyStrong)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            HStack(spacing: AppSpacing.s) {
                if let coverage = notification.coverage {
                    SpectrumBar(coverage: coverage)
                        .frame(width: 72)
                }
                Text(notification.body)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, AppSpacing.st)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Alertes") {
    NavigationStack { AlertesView() }
}
#endif

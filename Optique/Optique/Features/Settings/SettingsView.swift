import SwiftUI
import StoreKit

/// App settings as a standard grouped list, presented as a sheet from Mon Optique.
struct SettingsView: View {

    @Environment(SessionState.self) private var session
    @Environment(ReadingHistoryStore.self) private var history
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("preferredTopics") private var preferredTopicsRaw = ""

    @State private var showMethodologie = false
    @State private var showOwnership = false
    @State private var showPaywall = false
    @State private var showManage = false
    @State private var confirmReset = false
    @State private var isRestoring = false

    #if DEBUG
    @State private var notificationTestMessage = ""
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                if AppConfig.paywallEnabled {
                    PlanCard(
                        isPremium: session.isPremium,
                        used: session.storiesOpened,
                        total: session.freeLimit,
                        onUpgrade: { showPaywall = true },
                        onManage: session.storeManager.isPremium ? { showManage = true } : nil,
                        dark: true
                    )
                    group {
                        tapRow("refresh-cw", "Restaurer les achats", trailing: isRestoring ? AnyView(ProgressView()) : nil) {
                            Task {
                                isRestoring = true
                                await session.storeManager.restorePurchases()
                                isRestoring = false
                            }
                        }
                        .disabled(isRestoring)
                    }
                }

                group("Préférences", footer: "Au plus une alerte par heure, quand un sujet est couvert par plusieurs médias.") {
                    rowShell("bell", "Alertes des grands sujets") {
                        Toggle("", isOn: $notificationsEnabled).labelsHidden()
                    }
                    divider
                    NavigationLink { TopicPreferencesView() } label: {
                        rowShell("layout-grid", "Thèmes préférés") {
                            valueChevron(preferredTopicsSummary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                group("Transparence") {
                    tapRow("file-text", "Méthodologie", trailing: AnyView(valueChevron(nil))) { showMethodologie = true }
                    divider
                    tapRow("building-2", "Propriété des médias", trailing: AnyView(valueChevron(nil))) { showOwnership = true }
                }

                group("Données et légal") {
                    NavigationLink { LegalView() } label: {
                        rowShell("scale", "Informations légales") { valueChevron(nil) }
                    }
                    .buttonStyle(.plain)
                    divider
                    tapRow("trash-2", "Effacer l'historique", destructive: true) { confirmReset = true }
                        .disabled(history.leans.isEmpty && history.stories.isEmpty)
                    divider
                    rowShell("info", "Version") {
                        Text(appVersion).typeStyle(.meta).foregroundStyle(AppColors.Adaptive.textMeta)
                    }
                }

                #if DEBUG
                group("Développeur") {
                    NavigationLink { DesignSystemGalleryView() } label: {
                        rowShell("swatch-book", "Design system") { valueChevron(nil) }
                    }
                    .buttonStyle(.plain)
                    divider
                    tapRow("bell-ring", "Tester les notifications") { Task { await testNotifications() } }
                    if !notificationTestMessage.isEmpty {
                        Text(notificationTestMessage)
                            .typeStyle(.meta)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                            .padding(.horizontal, AppSpacing.m)
                            .padding(.bottom, AppSpacing.s)
                    }
                }
                #endif
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .tint(AppColors.Adaptive.textPrimary)
        .onChange(of: notificationsEnabled) { oldValue, newValue in
            guard newValue, !oldValue else { return }
            Task {
                do {
                    try await NotificationManager.shared.requestAuthorization()
                    if NotificationManager.shared.authorizationStatus != .authorized {
                        notificationsEnabled = false
                    }
                } catch {
                    notificationsEnabled = false
                }
            }
        }
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .appBackButton()
        .confirmationDialog("Effacer l'historique ?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Effacer", role: .destructive) { history.reset(); Haptics.warning() }
        } message: {
            Text("Votre historique et votre spectre de lecture seront remis à zéro.")
        }
        .sheet(isPresented: $showMethodologie) {
            textSheet(title: "Méthodologie", text: methodologieText)
        }
        .sheet(isPresented: $showOwnership) {
            textSheet(title: "Propriété des médias", text: ownershipText)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(isReplay: true)
        }
        .manageSubscriptionsSheet(isPresented: $showManage)
    }

    // MARK: - Building blocks

    private var divider: some View {
        Divider().padding(.leading, 52)
    }

    private func group<Content: View>(_ title: String? = nil, footer: String? = nil,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            if let title {
                Text(title)
                    .typeStyle(.label)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                    .padding(.horizontal, AppSpacing.s)
            }
            VStack(spacing: 0) { content() }
                .background(AppColors.Adaptive.cardSurface, in: RoundedRectangle(cornerRadius: AppRadius.xl))
            if let footer {
                Text(footer)
                    .typeStyle(.meta)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                    .padding(.horizontal, AppSpacing.s)
            }
        }
    }

    private func rowShell<Trailing: View>(_ icon: String, _ title: String, destructive: Bool = false,
                                          @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: AppSpacing.m) {
            LucideIcon(icon, size: 20)
                .frame(width: 24)
            Text(title)
                .typeStyle(.body)
                .lineLimit(1)
            Spacer(minLength: AppSpacing.s)
            trailing()
        }
        .foregroundStyle(destructive ? Color.red : AppColors.Adaptive.textPrimary)
        .padding(.horizontal, AppSpacing.m)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private func tapRow(_ icon: String, _ title: String, destructive: Bool = false,
                        trailing: AnyView? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowShell(icon, title, destructive: destructive) { trailing }
        }
        .buttonStyle(.plain)
    }

    private func valueChevron(_ value: String?) -> some View {
        HStack(spacing: 6) {
            if let value {
                Text(value).typeStyle(.meta).foregroundStyle(AppColors.Adaptive.textMeta)
            }
            LucideIcon("chevron-right", size: 16)
                .foregroundStyle(AppColors.Adaptive.textMeta)
        }
    }

    // MARK: - Sheets

    private func textSheet(title: String, text: String) -> some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .typeStyle(.body)
                    .foregroundStyle(AppColors.Adaptive.textBody)
                    .lineSpacing(4)
                    .padding(AppSpacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppColors.Adaptive.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        showMethodologie = false
                        showOwnership = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Right-hand value of the "Thèmes préférés" row: how many topics are followed.
    private var preferredTopicsSummary: String {
        let count = StoryTopic.preferred(from: preferredTopicsRaw).count
        return count == 0 ? "Aucun" : "\(count)"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    // MARK: - Static text

    private let methodologieText = """
    Optique classe les médias français sur un spectre politique en 5 positions, de l'extrême-gauche (position 1) à l'extrême-droite (position 7).

    Cette classification repose sur une analyse éditoriale des lignes politiques des publications, de leurs positionnements historiques et de la couverture internationale des think tanks et baromètres de confiance.

    Chaque article importé est associé à la position de sa source. La couverture d'une histoire est calculée en agrégeant les positions de toutes les sources qui l'ont publiée.

    Les classifications sont révisées périodiquement et peuvent évoluer en fonction du contexte éditorial de chaque publication.
    """

    private let ownershipText = """
    En France, la majorité des grands groupes de presse sont détenus par des industriels et financiers dont l'activité principale est extérieure aux médias.

    Cette concentration capitalistique peut influencer les lignes éditoriales, les sujets couverts et la manière dont certains événements sont traités.

    Optique affiche les informations de propriété pour chaque source afin de vous permettre d'identifier les intérêts économiques derrière les médias que vous consultez.

    Les données de propriété sont issues de sources publiques et mises à jour manuellement.
    """

    #if DEBUG
    private func testNotifications() async {
        notificationTestMessage = "Vérification des permissions..."

        // Step 1: Request authorization if not already granted
        let manager = NotificationManager.shared
        if manager.authorizationStatus != .authorized {
            do {
                try await manager.requestAuthorization()
                await manager.checkAuthorizationStatus()

                if manager.authorizationStatus != .authorized {
                    notificationTestMessage = "❌ Permission refusée"
                    return
                }
            } catch {
                notificationTestMessage = "❌ Erreur: \(error.localizedDescription)"
                return
            }
        }

        // Step 2: Clear last notification ID to allow re-showing existing notifications
        UserDefaults.standard.removeObject(forKey: "lastNotificationId")

        // Step 3: Check for new stories (will show the latest notification from database)
        notificationTestMessage = "Vérification des nouvelles actualités..."
        await manager.checkForNewStories()

        notificationTestMessage = "✅ Vérification terminée"

        // Clear message after 2 seconds
        try? await Task.sleep(for: .seconds(2))
        notificationTestMessage = ""
    }
    #endif
}

#if DEBUG
#Preview("Réglages") {
    NavigationStack { SettingsView() }
        .environment(SessionState())
        .environment(ReadingHistoryStore())
}
#endif

/// Privacy policy and terms of service, grouped off the main settings list.
struct LegalView: View {
    var body: some View {
        Form {
            if let url = URL(string: "https://loylep.github.io/Perspective/legal/privacy-policy") {
                Link(destination: url) {
                    Label("Politique de confidentialité", lucide: "hand")
                }
            }
            if let url = URL(string: "https://loylep.github.io/Perspective/legal/terms-of-service") {
                Link(destination: url) {
                    Label("Conditions d'utilisation", lucide: "file")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .tint(AppColors.Adaptive.textPrimary)
        .navigationTitle("Informations légales")
        .navigationBarTitleDisplayMode(.inline)
        .appBackButton()
    }
}

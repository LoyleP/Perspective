import SwiftUI

/// App settings as a standard grouped list, presented as a sheet from Mon Optique.
struct SettingsView: View {

    @Environment(SessionState.self) private var session
    @Environment(ReadingHistoryStore.self) private var history
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false

    @State private var showMethodologie = false
    @State private var showOwnership = false
    @State private var showPaywall = false
    @State private var confirmReset = false
    @State private var isRestoring = false

    #if DEBUG
    @AppStorage("devIsPremium") private var devIsPremium = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var showOnboarding = false
    @State private var notificationTestMessage = ""
    #endif

    var body: some View {
        Form {
            Section("Abonnement") {
                LabeledContent("Formule", value: session.isPremium ? "Optique+" : "Gratuite")
                if !session.isPremium {
                    Button {
                        showPaywall = true
                    } label: {
                        Label("Passer à Optique+", systemImage: "sparkles")
                            .foregroundStyle(AppColors.Brand.accent)
                    }
                }
                Button {
                    Task {
                        isRestoring = true
                        await session.storeManager.restorePurchases()
                        isRestoring = false
                    }
                } label: {
                    HStack {
                        Label("Restaurer les achats", systemImage: "arrow.clockwise")
                        if isRestoring {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRestoring)
            }

            Section {
                Toggle(isOn: $notificationsEnabled) {
                    Label("Alertes des grands sujets", systemImage: "bell")
                }
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
            } header: {
                Text("Notifications")
            } footer: {
                Text("Au plus une alerte par heure, quand un sujet est couvert par plusieurs médias.")
            }

            Section("Lecture") {
                NavigationLink {
                    MySpectrumView()
                } label: {
                    Label("Mon spectre de lecture", systemImage: "chart.bar")
                }
                NavigationLink {
                    TopicPreferencesView()
                } label: {
                    Label("Thèmes préférés", systemImage: "square.grid.2x2")
                }
                Button(role: .destructive) {
                    confirmReset = true
                } label: {
                    Label("Effacer l'historique", systemImage: "trash")
                }
                .disabled(history.leans.isEmpty && history.stories.isEmpty)
            }

            Section("À propos") {
                Button {
                    showMethodologie = true
                } label: {
                    Label("Méthodologie", systemImage: "doc.text")
                }
                Button {
                    showOwnership = true
                } label: {
                    Label("Propriété des médias", systemImage: "building.2")
                }
                if let url = URL(string: "https://loylep.github.io/Perspective/legal/privacy-policy") {
                    Link(destination: url) {
                        Label("Politique de confidentialité", systemImage: "hand.raised")
                    }
                }
                if let url = URL(string: "https://loylep.github.io/Perspective/legal/terms-of-service") {
                    Link(destination: url) {
                        Label("Conditions d'utilisation", systemImage: "doc.plaintext")
                    }
                }
                LabeledContent("Version", value: appVersion)
            }

            #if DEBUG
            Section("Développeur") {
                NavigationLink {
                    DesignSystemGalleryView()
                } label: {
                    Label("Design system", systemImage: "paintpalette")
                }
                Toggle(isOn: $devIsPremium) {
                    Label("Mode premium", systemImage: "crown")
                }
                .onChange(of: devIsPremium) { _, newValue in
                    if newValue { session.storiesOpened = 0 }
                }
                Button {
                    Task { await testNotifications() }
                } label: {
                    Label("Tester les notifications", systemImage: "bell.badge")
                }
                if !notificationTestMessage.isEmpty {
                    Text(notificationTestMessage)
                        .font(.appFootnote)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
                Button {
                    hasCompletedOnboarding = false
                    showOnboarding = true
                } label: {
                    Label("Rejouer l'onboarding", systemImage: "arrow.counterclockwise")
                }
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .tint(AppColors.Adaptive.textPrimary)
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("OK") { dismiss() }
            }
        }
        .confirmationDialog("Effacer l'historique ?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Effacer", role: .destructive) { history.reset() }
        } message: {
            Text("Votre historique et votre spectre de lecture seront remis à zéro.")
        }
        .sheet(isPresented: $showMethodologie) {
            textSheet(title: "Méthodologie", text: methodologieText)
        }
        .sheet(isPresented: $showOwnership) {
            textSheet(title: "Propriété des médias", text: ownershipText)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        #if DEBUG
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        #endif
    }

    // MARK: - Sheets

    private func textSheet(title: String, text: String) -> some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.appBody)
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

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    // MARK: - Static text

    private let methodologieText = """
    Optique classe les médias français sur un spectre politique en 7 positions, de l'extrême-gauche (position 1) à l'extrême-droite (position 7).

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

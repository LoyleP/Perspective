import SwiftUI
import UserNotifications

struct SettingsView: View {

    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("colorSchemeRaw") private var colorSchemeRaw = 0

    @State private var showMethodologie = false
    @State private var showOwnership = false

    #if DEBUG
    @Environment(SessionState.self) private var session
    @AppStorage("devIsPremium") private var devIsPremium = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var showOnboarding = false
    @State private var notificationTestMessage = ""
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {

                Text("Paramètres")
                    .font(.appLargeTitle)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.m)

                // MARK: Mon profil de lecture

                settingsSectionHeader("Mon profil de lecture")

                NavigationLink {
                    MySpectrumView()
                } label: {
                    settingsRow {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(AppColors.Adaptive.textSecondary)
                            .frame(width: 20)
                        Text("Mon spectre de lecture")
                            .font(.appBody)
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.appFootnote)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                    }
                }

                // MARK: Notifications

                settingsSectionHeader("Notifications")

                settingsRow {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(AppColors.Adaptive.textSecondary)
                        .frame(width: 20)
                    Text("Activer les notifications")
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                    Spacer()
                    Toggle("", isOn: $notificationsEnabled)
                        .labelsHidden()
                        .onChange(of: notificationsEnabled) { oldValue, newValue in
                            guard newValue, !oldValue else { return }
                            Task {
                                let center = UNUserNotificationCenter.current()
                                do {
                                    let granted = try await center.requestAuthorization(
                                        options: [.alert, .badge, .sound]
                                    )
                                    if !granted { notificationsEnabled = false }
                                } catch {
                                    notificationsEnabled = false
                                }
                            }
                        }
                }

                // MARK: Apparence

                settingsSectionHeader("Apparence")

                settingsRow {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(AppColors.Adaptive.textSecondary)
                        .frame(width: 20)
                    Text("Thème")
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                    Spacer()
                    Picker("", selection: $colorSchemeRaw) {
                        Text("Système").tag(0)
                        Text("Clair").tag(1)
                        Text("Sombre").tag(2)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                }

                // MARK: À propos

                settingsSectionHeader("À propos")

                VStack(spacing: 0) {
                    Button {
                        showMethodologie = true
                    } label: {
                        settingsRowContent {
                            Image(systemName: "doc.text")
                                .foregroundStyle(AppColors.Adaptive.textSecondary)
                                .frame(width: 20)
                            Text("Méthodologie")
                                .font(.appBody)
                                .foregroundStyle(AppColors.Adaptive.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.appFootnote)
                                .foregroundStyle(AppColors.Adaptive.textMeta)
                        }
                    }

                    Divider().padding(.leading, AppSpacing.m + 20 + AppSpacing.m)

                    Button {
                        showOwnership = true
                    } label: {
                        settingsRowContent {
                            Image(systemName: "building.2")
                                .foregroundStyle(AppColors.Adaptive.textSecondary)
                                .frame(width: 20)
                            Text("Propriété des médias")
                                .font(.appBody)
                                .foregroundStyle(AppColors.Adaptive.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.appFootnote)
                                .foregroundStyle(AppColors.Adaptive.textMeta)
                        }
                    }

                    Divider().padding(.leading, AppSpacing.m + 20 + AppSpacing.m)

                    Button {
                        if let url = URL(string: "https://loylep.github.io/Perspective/legal/privacy-policy") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        settingsRowContent {
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(AppColors.Adaptive.textSecondary)
                                .frame(width: 20)
                            Text("Politique de confidentialité")
                                .font(.appBody)
                                .foregroundStyle(AppColors.Adaptive.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.appFootnote)
                                .foregroundStyle(AppColors.Adaptive.textMeta)
                        }
                    }

                    Divider().padding(.leading, AppSpacing.m + 20 + AppSpacing.m)

                    Button {
                        if let url = URL(string: "https://loylep.github.io/Perspective/legal/terms-of-service") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        settingsRowContent {
                            Image(systemName: "doc.plaintext")
                                .foregroundStyle(AppColors.Adaptive.textSecondary)
                                .frame(width: 20)
                            Text("Conditions d'utilisation")
                                .font(.appBody)
                                .foregroundStyle(AppColors.Adaptive.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.appFootnote)
                                .foregroundStyle(AppColors.Adaptive.textMeta)
                        }
                    }

                    Divider().padding(.leading, AppSpacing.m + 20 + AppSpacing.m)

                    settingsRowContent {
                        Image(systemName: "info.circle")
                            .foregroundStyle(AppColors.Adaptive.textSecondary)
                            .frame(width: 20)
                        Text("Version")
                            .font(.appBody)
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                        Spacer()
                        Text(appVersion)
                            .font(.appBody)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                    }
                }
                .background(AppColors.Adaptive.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
                .padding(.horizontal, AppSpacing.m)
                #if DEBUG
                settingsSectionHeader("Développeur")

                settingsRow {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                        .frame(width: 20)
                    Text("Mode premium")
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                    Spacer()
                    Toggle("", isOn: $devIsPremium)
                        .labelsHidden()
                        .onChange(of: devIsPremium) { _, newValue in
                            session.isPremium = newValue
                            if newValue { session.storiesOpened = 0 }
                        }
                }

                VStack(spacing: AppSpacing.s) {
                    Button {
                        Task {
                            await testNotifications()
                        }
                    } label: {
                        settingsRowContent {
                            Image(systemName: "bell.badge")
                                .foregroundStyle(AppColors.Adaptive.textSecondary)
                                .frame(width: 20)
                            Text("Tester les notifications")
                                .font(.appBody)
                                .foregroundStyle(AppColors.Adaptive.textPrimary)
                            Spacer()
                        }
                    }
                    .background(AppColors.Adaptive.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))

                    if !notificationTestMessage.isEmpty {
                        Text(notificationTestMessage)
                            .font(.appCaption1)
                            .foregroundStyle(AppColors.Adaptive.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, AppSpacing.m)

                Button {
                    hasCompletedOnboarding = false
                    showOnboarding = true
                } label: {
                    settingsRowContent {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(AppColors.Adaptive.textSecondary)
                            .frame(width: 20)
                        Text("Rejouer l'onboarding")
                            .font(.appBody)
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                        Spacer()
                    }
                }
                .background(AppColors.Adaptive.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
                .padding(.horizontal, AppSpacing.m)
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView()
                }
                #endif
            }
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.Adaptive.feedBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showMethodologie) {
            methodologieSheet
        }
        .sheet(isPresented: $showOwnership) {
            ownershipSheet
        }
    }

    // MARK: - Row helpers

    private func settingsSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.appCaption1)
            .foregroundStyle(AppColors.Adaptive.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.m)
            .padding(.bottom, -AppSpacing.s)
    }

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        settingsRowContent(content: content)
            .background(AppColors.Adaptive.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
            .padding(.horizontal, AppSpacing.m)
    }

    private func settingsRowContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: AppSpacing.m) {
            content()
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, 14)
    }

    // MARK: - Sheets

    private var methodologieSheet: some View {
        NavigationStack {
            ScrollView {
                Text(methodologieText)
                    .font(.appBody)
                    .foregroundStyle(AppColors.Adaptive.textBody)
                    .lineSpacing(4)
                    .padding(AppSpacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppColors.Adaptive.feedBackground.ignoresSafeArea())
            .navigationTitle("Méthodologie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { showMethodologie = false }
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var ownershipSheet: some View {
        NavigationStack {
            ScrollView {
                Text(ownershipText)
                    .font(.appBody)
                    .foregroundStyle(AppColors.Adaptive.textBody)
                    .lineSpacing(4)
                    .padding(AppSpacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppColors.Adaptive.feedBackground.ignoresSafeArea())
            .navigationTitle("Propriété des médias")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { showOwnership = false }
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    // MARK: - Static text

    private let methodologieText = """
    Perspective classe les médias français sur un spectre politique en 7 positions, de l'extrême-gauche (position 1) à l'extrême-droite (position 7).

    Cette classification repose sur une analyse éditoriale des lignes politiques des publications, de leurs positionnements historiques et de la couverture internationale des think tanks et baromètres de confiance.

    Chaque article importé est associé à la position de sa source. La couverture d'une histoire est calculée en agrégeant les positions de toutes les sources qui l'ont publiée.

    Les classifications sont révisées périodiquement et peuvent évoluer en fonction du contexte éditorial de chaque publication.
    """

    private let ownershipText = """
    En France, la majorité des grands groupes de presse sont détenus par des industriels et financiers dont l'activité principale est extérieure aux médias.

    Cette concentration capitalistique peut influencer les lignes éditoriales, les sujets couverts et la manière dont certains événements sont traités.

    Perspective affiche les informations de propriété pour chaque source afin de vous permettre d'identifier les intérêts économiques derrière les médias que vous consultez.

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

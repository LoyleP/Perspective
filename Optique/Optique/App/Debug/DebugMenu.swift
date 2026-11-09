#if DEBUG
import SwiftUI
import CoreMotion
import UserNotifications
import UIKit

/// Floating debug button (or shake) → full debug menu. Debug builds only.
enum DebugMenu {
    static let reloadNotification = Notification.Name("DEBUG_RELOAD_APP")
    static func reloadApp() { NotificationCenter.default.post(name: reloadNotification, object: nil) }
}

extension View {
    func debugMenu() -> some View { modifier(DebugMenuModifier()) }
}

// MARK: - Entry point

private struct DebugMenuModifier: ViewModifier {
    @State private var showMenu = false
    @State private var offset = CGSize(width: 0, height: 0)
    @GestureState private var drag = CGSize.zero
    @State private var shake = ShakeDetector()

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .trailing) {
                Button {
                    showMenu = true
                } label: {
                    LucideIcon("bug", size: 22)
                        .typeStyle(.section)
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                        .background(Color.yellow, in: Circle())
                        .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 1))
                        .shadow(radius: 6)
                }
                .opacity(0.85)
                .offset(x: offset.width + drag.width, y: offset.height + drag.height)
                .padding(.trailing, 6)
                .gesture(
                    DragGesture()
                        .updating($drag) { value, state, _ in state = value.translation }
                        .onEnded { value in
                            offset.width += value.translation.width
                            offset.height += value.translation.height
                        }
                )
                .accessibilityLabel("Menu debug")
            }
            .onAppear { shake.start { showMenu = true } }
            .sheet(isPresented: $showMenu) {
                DebugMenuView()
            }
    }
}

// MARK: - Shake

/// Detects a shake with the accelerometer (no permission needed).
@MainActor
private final class ShakeDetector {
    private let motion = CMMotionManager()
    private var lastFire = Date.distantPast

    func start(onShake: @escaping @MainActor () -> Void) {
        guard motion.isAccelerometerAvailable, !motion.isAccelerometerActive else { return }
        motion.accelerometerUpdateInterval = 0.05
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let a = data?.acceleration else { return }
            let force = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
            if force > 2.6, Date().timeIntervalSince(self.lastFire) > 1.5 {
                self.lastFire = Date()
                onShake()
            }
        }
    }
}

// MARK: - Menu

private struct DebugMenuView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionState.self) private var session
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(ReadingHistoryStore.self) private var history
    @Environment(\.commentStore) private var commentStore

    @AppStorage(Fixtures.fixturesKey) private var useFixtures = false
    @AppStorage(Fixtures.stateKey) private var forcedState = "normal"
    @AppStorage(DebugRoute.textSizeKey) private var textSize = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("lastSeenAlertsAt") private var lastSeenAlertsAt: Double = 0
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false

    @State private var cover: Cover?
    @State private var authStatus = "…"
    @State private var message = ""
    @State private var ping: [String: String] = [:]
    @State private var confirmWipe = false
    @State private var confirmNewUser = false

    private let notifications = NotificationManager.shared

    enum Cover: String, Identifiable {
        case onboarding, paywall
        case feed, story, explorer, topic, sources, source, profile, alerts, settings, gallery
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                dataSection
                flowsSection
                notificationsSection
                subscriptionSection
                localDataSection
                apiSection
                infoSection
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                if !message.isEmpty {
                    Text(message)
                        .typeStyle(.meta)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                        .transition(.move(edge: .bottom))
                }
            }
            .task { await refreshAuthStatus() }
            .fullScreenCover(item: $cover) { cover in
                CoverHost(cover: cover) { self.cover = nil }
                    .environment(session)
                    .environment(bookmarks)
                    .environment(history)
            }
            .confirmationDialog("Effacer toutes les données locales ?", isPresented: $confirmWipe, titleVisibility: .visible) {
                Button("Tout effacer", role: .destructive) { wipeEverything() }
            } message: {
                Text("Préférences, historique, enregistrés, onboarding… L'app se recharge.")
            }
            .confirmationDialog("Simuler un nouvel utilisateur ?", isPresented: $confirmNewUser, titleVisibility: .visible) {
                Button("Tout remettre à zéro", role: .destructive) { resetToNewUser() }
            } message: {
                Text("Onboarding, thèmes, historique, enregistrés, lois suivies, sujets gratuits et compte Optique+ de test sont effacés. L'autorisation des notifications, elle, se réinitialise dans les réglages de l'iPhone.")
            }
        }
    }

    // MARK: Données

    private var dataSection: some View {
        Section {
            Toggle("Données fictives (hors ligne)", isOn: $useFixtures)
            Picker("État forcé", selection: $forcedState) {
                Text("Normal").tag("normal")
                Text("Chargement infini").tag("loading")
                Text("Vide").tag("empty")
                Text("Erreur réseau").tag("error")
            }
            .disabled(!useFixtures)
            Picker("Taille du texte", selection: $textSize) {
                Text("Système").tag("")
                ForEach(DebugRoute.textSizeNames, id: \.self) { Text($0).tag($0) }
            }
            Button("Recharger l'app avec ces réglages") {
                DebugMenu.reloadApp()
                dismiss()
            }
        } header: {
            Text("Données et affichage")
        } footer: {
            Text("Les données fictives et l'état forcé s'appliquent aux écrans (flux, Explorer, alertes, sources). Rechargez pour les voir.")
        }
    }

    // MARK: Flux

    private var flowsSection: some View {
        Section("Lancer un flux ou un écran") {
            launch("Onboarding", "hand.wave", .onboarding)
            launch("Paywall Optique+", "sparkles", .paywall)
            Button {
                session.fillCounter()
                done("Limite atteinte : ouvrez un sujet pour voir l'écran de limite.")
                dismiss()
            } label: {
                Label("Limite de lecture atteinte", systemImage: "rectangle.bottomthird.inset.filled")
            }
            DisclosureGroup("Écrans (plein écran)") {
                launch("À la une", "newspaper", .feed)
                launch("Sujet", "doc.text", .story)
                launch("Explorer", "magnifyingglass", .explorer)
                launch("Thème", "square.grid.2x2", .topic)
                launch("Sources", "building.columns", .sources)
                launch("Source", "building.2", .source)
                launch("Mon Optique", "person.crop.circle", .profile)
                launch("Alertes", "bell", .alerts)
                launch("Réglages", "gearshape", .settings)
                launch("Design system", "paintpalette", .gallery)
            }
        }
    }

    private func launch(_ title: String, _ icon: String, _ cover: Cover) -> some View {
        Button { self.cover = cover } label: { Label(title, systemImage: icon) }
    }

    // MARK: Notifications

    private var notificationsSection: some View {
        Section {
            LabeledContent("Autorisation", value: authStatus)
            Button("Demander l'autorisation") {
                Task {
                    try? await notifications.requestAuthorization()
                    await refreshAuthStatus()
                }
            }
            Button("Simuler une alerte") {
                Task { await simulateAlert() }
            }
            Button("Notification dans 5 s (ouvre un sujet)") {
                Task { await schedule(withStory: true) }
            }
            Button("Notification dans 5 s (sans sujet)") {
                Task { await schedule(withStory: false) }
            }
            Button("Simuler un tap : ouvrir un sujet") {
                Task {
                    guard let story = await sampleStory() else { return done("Aucun sujet disponible.") }
                    notifications.pendingStoryID = story.id
                    done("Deep link vers « \(story.title.prefix(40))… »")
                    dismiss()
                }
            }
            Button("Relancer la vérification serveur") {
                Task {
                    UserDefaults.standard.removeObject(forKey: "lastNotificationId")
                    await notifications.checkForNewStories()
                    done("Vérification faite : une notif locale part si l'autorisation est accordée.")
                }
            }
            Button("Marquer les alertes comme non lues") {
                lastSeenAlertsAt = 0
                DebugMenu.reloadApp()
                done("Pastille de la cloche rétablie.")
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Pour tester le tap depuis l'écran de verrouillage, lancez une notif dans 5 s puis verrouillez le téléphone.")
        }
    }

    private func schedule(withStory: Bool) async {
        await refreshAuthStatus()
        let story = withStory ? await sampleStory() : nil
        do {
            try await notifications.debugSchedule(
                title: story?.title ?? "Notification de test",
                body: story.map { "\($0.sources.count) sources • nouvelle actualité" } ?? "Sans sujet associé",
                storyID: story?.id,
                after: 5
            )
            done("Notification programmée dans 5 s. Quittez l'app pour la voir en bannière.")
        } catch {
            done("Échec : \(error.localizedDescription)")
        }
    }

    /// Adds a fake alert built from the latest story at the top of the Alertes tab (with the unread
    /// badge on the bell) and shows its banner, like a real alert from the server would.
    private func simulateAlert() async {
        guard let story = await sampleStory() else { return done("Aucun sujet disponible.") }
        let counts = story.computedCoverage.map {
            [$0.lean1Count, $0.lean2Count, $0.lean3Count, $0.lean4Count, $0.lean5Count, $0.lean6Count, $0.lean7Count]
        }
        let sourceCount = story.sources.count
        let alert = PushNotification(
            id: UUID(),
            title: story.title,
            body: "Alerte simulée · \(sourceCount) \(sourceCount == 1 ? "source" : "sources")",
            storyCount: 1,
            storyId: story.id,
            sentAt: Date(),
            createdAt: Date(),
            leanCounts: counts
        )
        notifications.debugAlerts.insert(alert, at: 0)
        await refreshAuthStatus()
        try? await notifications.debugSchedule(title: alert.title, body: alert.body, storyID: story.id, after: 1)
        DebugMenu.reloadApp()
        done(notifications.authorizationStatus == .authorized
             ? "Alerte ajoutée en tête de l'onglet Alertes, bannière dans 1 s."
             : "Alerte ajoutée en tête de l'onglet Alertes (pas de bannière : notifications non autorisées).")
    }

    private func sampleStory() async -> Story? {
        try? await StoryRepository.shared.fetchFeed(topic: nil, limit: 1, offset: 0).first
    }

    private func refreshAuthStatus() async {
        await notifications.checkAuthorizationStatus()
        authStatus = switch notifications.authorizationStatus {
        case .notDetermined: "Non demandée"
        case .denied: "Refusée"
        case .authorized: "Accordée"
        case .provisional: "Provisoire"
        case .ephemeral: "Éphémère"
        @unknown default: "Inconnue"
        }
    }

    // MARK: Abonnement

    private var subscriptionSection: some View {
        Section {
            Toggle("Compte Optique+ (test)", isOn: Binding(get: { session.testPremium }, set: { session.testPremium = $0 }))
                .sensoryFeedback(.selection, trigger: session.testPremium)
            Button {
                session.resetCounter()
                Haptics.lightImpact()
                done("Sujets gratuits remis à zéro.")
            } label: {
                LabeledContent {
                    Text("\(session.storiesOpened) / \(session.freeLimit)")
                        .monospacedDigit()
                } label: {
                    Text("Remettre les sujets gratuits à zéro")
                }
            }
            Button("Restaurer les achats") {
                Task {
                    await session.storeManager.restorePurchases()
                    done(session.storeManager.isPremium ? "Premium actif." : "Aucun achat à restaurer.")
                }
            }
            LabeledContent("Produits StoreKit", value: "\(session.storeManager.products.count)")
        } header: {
            Text("Abonnement")
        } footer: {
            Text("Bascule entre la vue d'un compte gratuit (\(session.freeLimit) sujets par jour) et celle d'un compte Optique+.")
        }
    }

    // MARK: Données locales

    private var localDataSection: some View {
        Section("Données locales") {
            Button("Rejouer l'onboarding au prochain lancement") {
                hasCompletedOnboarding = false
                done("L'onboarding s'affiche maintenant.")
                dismiss()
            }
            Button("Effacer l'historique et le spectre") { history.reset(); done("Historique effacé.") }
            Button("Effacer les enregistrés") {
                for story in bookmarks.stories { bookmarks.toggle(story) }
                done("Enregistrés effacés.")
            }
            Button("Importer des commentaires de test") {
                Task {
                    let stories = (try? await StoryRepository.shared.fetchFeed(topic: nil, limit: 30, offset: 0)) ?? []
                    for story in stories { commentStore.seedMockIfNeeded(for: story.id) }
                    done("Commentaires de test ajoutés à \(stories.count) sujets.")
                }
            }
            Button("Effacer les commentaires") {
                commentStore.clearAll()
                done("Commentaires effacés.")
            }
            Button("Effacer les thèmes préférés") {
                UserDefaults.standard.removeObject(forKey: "preferredTopics")
                done("Thèmes réinitialisés.")
            }
            Button("Simuler un nouvel utilisateur", role: .destructive) { confirmNewUser = true }
            Button("Tout effacer (UserDefaults + historique)", role: .destructive) { confirmWipe = true }
        }
    }

    /// Puts the app back in the state of a first launch: onboarding to see again, nothing saved, no
    /// preferences, a full daily allowance and a free account.
    private func resetToNewUser() {
        session.testPremium = false
        session.resetCounter()
        history.reset()
        bookmarks.reset()
        LawFollowStore.shared.reset()
        CommentStore.shared.clearAll()
        notifications.debugAlerts = []
        let defaults = UserDefaults.standard
        for key in ["preferredTopics", "notificationsEnabled", "alertsPromptDismissed", "lastSeenAlertsAt",
                    "lastNotificationId", "lastStoryCount", "seenFirstStoryHint", "profileSince"] {
            defaults.removeObject(forKey: key)
        }
        notificationsEnabled = false
        PushRegistration.unregister()
        hasCompletedOnboarding = false   // the root shows the onboarding again
        Haptics.success()
        dismiss()
    }

    private func wipeEverything() {
        history.reset()
        for story in bookmarks.stories { bookmarks.toggle(story) }
        if let id = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: id)
        }
        DebugMenu.reloadApp()
        done("Données effacées.")
    }

    // MARK: API

    private var apiSection: some View {
        Section("API") {
            LabeledContent("Base", value: AppConfig.apiBaseURL.absoluteString)
                .typeStyle(.meta)
            ForEach(["health", "feed?limit=1", "sources", "notifications?limit=1"], id: \.self) { path in
                Button {
                    Task { await check(path) }
                } label: {
                    HStack {
                        Text("GET /\(path)")
                        Spacer()
                        Text(ping[path] ?? "").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func check(_ path: String) async {
        ping[path] = "…"
        guard let url = URL(string: AppConfig.apiBaseURL.absoluteString + "/" + path) else { return }
        let start = Date()
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            ping[path] = "\(status) · \(ms) ms · \(data.count / 1024) Ko"
        } catch {
            ping[path] = "erreur"
        }
    }

    // MARK: Infos

    private var infoSection: some View {
        Section("Infos") {
            let info = Bundle.main.infoDictionary
            LabeledContent("Version", value: "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))")
            LabeledContent("Bundle", value: Bundle.main.bundleIdentifier ?? "?")
            LabeledContent("iOS", value: UIDevice.current.systemVersion)
            LabeledContent("Appareil", value: UIDevice.current.model)
            LabeledContent("Notifs activées (réglage)", value: notificationsEnabled ? "oui" : "non")
        }
    }

    private func done(_ text: String) {
        withAnimation(.app) { message = text }
        Task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.app) { if message == text { message = "" } }
        }
    }
}

// MARK: - Full-screen host

/// Shows one flow or screen full screen with a "Fermer" pill.
private struct CoverHost: View {
    let cover: DebugMenuView.Cover
    let close: () -> Void

    var body: some View {
        content
            .overlay(alignment: .bottom) {
                Button("Fermer le debug", action: close)
                    .typeStyle(.meta)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.yellow, in: Capsule())
                    .padding(.bottom, 4)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch cover {
        case .onboarding: DebugScreenHost(screen: "onboarding")
        case .paywall: DebugScreenHost(screen: "paywall")
        default: DebugScreenHost(screen: cover.rawValue)
        }
    }
}
#endif

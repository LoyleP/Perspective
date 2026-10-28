import SwiftUI
import CoreText
import OSLog

@main
struct OptiqueApp: App {

    @Environment(\.scenePhase) private var scenePhase

    init() {
        for name in ["Geist-VariableFont_wght", "BarlowCondensed-Bold", "BarlowCondensed-SemiBold"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }

        // Permission is asked at the end of onboarding (or from Réglages / Alertes), not at launch.
        Task {
            await NotificationManager.shared.checkAuthorizationStatus()
        }

        Log.general.info("App init completed")
    }

    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .preferredColorScheme(.dark)

                if showSplash {
                    SplashView {
                        showSplash = false
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    Task {
                        await NotificationManager.shared.checkForNewStories()
                    }
                }
            }
        }
    }
}

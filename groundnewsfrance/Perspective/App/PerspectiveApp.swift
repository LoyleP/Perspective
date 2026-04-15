import SwiftUI
import CoreText

@main
struct PerspectiveApp: App {

    @AppStorage("colorSchemeRaw") private var colorSchemeRaw = 0
    @Environment(\.scenePhase) private var scenePhase

    init() {
        print("🚀🚀🚀 APP LAUNCHED - Console is working! 🚀🚀🚀")

        for name in ["Geist-VariableFont_wght", "BarlowCondensed-Bold", "BarlowCondensed-SemiBold"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }

        // Request notification permissions on launch
        Task {
            try? await NotificationManager.shared.requestAuthorization()
        }

        print("🚀 App init completed")
    }

    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .preferredColorScheme(preferredColorScheme)

                if showSplash {
                    SplashView {
                        showSplash = false
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    // Check for new stories when app becomes active
                    Task {
                        await NotificationManager.shared.checkForNewStories()
                    }
                }
            }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
}

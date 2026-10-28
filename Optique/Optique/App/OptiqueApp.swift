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

        #if DEBUG && targetEnvironment(simulator)
        // Live reload: loads InjectionIII's bundle when the InjectionIII app is installed.
        Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
        #endif

        // Permission is asked at the end of onboarding (or from Réglages / Alertes), not at launch.
        Task {
            await NotificationManager.shared.checkAuthorizationStatus()
        }

        Log.general.info("App init completed")
    }

    @State private var showSplash = true

    private var skipsSplash: Bool {
        #if DEBUG
        return DebugRoute.screen != nil
        #else
        return false
        #endif
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
        if let screen = DebugRoute.screen {
            DebugScreenHost(screen: screen)
        } else {
            RootView()
                .debugTextSizeOverride()
        }
        #else
        RootView()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                rootContent
                    .preferredColorScheme(.dark)

                if showSplash && !skipsSplash {
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

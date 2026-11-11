import SwiftUI
import CoreText
import OSLog

@main
struct OptiqueApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        for name in ["Geist-VariableFont_wght"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        AppAppearance.configure()
        // Sheets and pushed pages are separate hosting views: hide their scroll bars too.
        UIScrollView.appearance().showsVerticalScrollIndicator = false
        UIScrollView.appearance().showsHorizontalScrollIndicator = false

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
    @State private var launch = LaunchGate.shared
    #if DEBUG
    /// Screen opened with `--screen`; cleared by the gallery's home button to reach the real app.
    @State private var debugScreen = DebugRoute.screen
    #endif

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
        if let screen = debugScreen {
            DebugScreenHost(screen: screen, onHome: { debugScreen = nil })
        } else {
            RootView()
                .typeStyle(.body)
                .debugTextSizeOverride()
        }
        #else
        RootView()
            .typeStyle(.body)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                rootContent

                if showSplash && !skipsSplash {
                    SplashView {
                        showSplash = false
                    }
                }
            }
            .preferredColorScheme(.light)
            // No scroll bars anywhere in the app.
            .scrollIndicators(.hidden)
            .onAppear { if skipsSplash { launch.entered = true } }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    Task {
                        // Alerts now arrive as remote pushes; re-check permission and refresh the device token.
                        await NotificationManager.shared.checkAuthorizationStatus()
                        await LawFollowStore.shared.checkForUpdates()
                    }
                }
            }
        }
    }
}

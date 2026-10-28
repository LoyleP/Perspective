#if DEBUG
import SwiftUI

/// Debug launcher: opens one screen directly with offline fixture data.
///
///     xcrun simctl launch <udid> com.flow.optique --screen story --state loading --text-size xxxl
///
/// Screens: feed, story, explorer, topic, sources, source, profile, alerts, settings,
/// onboarding, paywall, thread, gallery. `--state normal|loading|empty|error` (default normal).
/// `--text-size` takes a Dynamic Type size: xs, s, m, l, xl, xxl, xxxl, ax1 … ax5.
/// `--story <n>` picks the n-th fixture story (default 0) for story/thread.
enum DebugRoute {

    static var screen: String? { value(after: "--screen") }

    static let textSizeKey = "debug.textSize"

    /// Launch argument first, then the value chosen in the debug menu.
    static var textSize: DynamicTypeSize? {
        textSize(named: value(after: "--text-size") ?? UserDefaults.standard.string(forKey: textSizeKey))
    }

    static let textSizeNames = ["xs", "s", "m", "l", "xl", "xxl", "xxxl", "ax1", "ax2", "ax3", "ax4", "ax5"]

    static func textSize(named name: String?) -> DynamicTypeSize? {
        switch name {
        case "xs": return .xSmall
        case "s": return .small
        case "m": return .medium
        case "l": return .large
        case "xl": return .xLarge
        case "xxl": return .xxLarge
        case "xxxl": return .xxxLarge
        case "ax1": return .accessibility1
        case "ax2": return .accessibility2
        case "ax3": return .accessibility3
        case "ax4": return .accessibility4
        case "ax5": return .accessibility5
        default: return nil
        }
    }

    static var storyIndex: Int { Int(value(after: "--story") ?? "") ?? 0 }

    static func value(after flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        return args[index + 1]
    }
}

extension View {
    /// Applies the Dynamic Type size forced by `--text-size` or the debug menu, if any.
    @ViewBuilder
    func debugTextSizeOverride() -> some View {
        if let size = DebugRoute.textSize {
            dynamicTypeSize(size)
        } else {
            self
        }
    }
}

struct DebugScreenHost: View {
    let screen: String

    @State private var session = SessionState()
    @State private var bookmarks = BookmarkStore()
    @State private var history = ReadingHistoryStore()
    @State private var searchText = ""

    private var story: Story {
        Fixtures.stories[min(DebugRoute.storyIndex, Fixtures.stories.count - 1)]
    }

    var body: some View {
        content
            .environment(session)
            .environment(bookmarks)
            .environment(history)
            .preferredColorScheme(.dark)
            .debugTextSizeOverride()
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case "feed": NavigationStack { FeedView() }
        case "story": NavigationStack { StoryDetailView(story: story) }
        case "thread": NavigationStack { StoryThreadView(story: story) }
        case "explorer": NavigationStack { DiscoverView(searchText: $searchText) }
        case "topic": NavigationStack { TopicStoriesView(topic: .politique) }
        case "sources": NavigationStack { SourcesView() }
        case "source": NavigationStack { SourceDetailView(source: Fixtures.sources[4]) }
        case "profile": NavigationStack { ProfileView() }
        case "alerts": NavigationStack { AlertesView() }
        case "settings": NavigationStack { SettingsView() }
        case "onboarding": OnboardingView()
        case "paywall": PaywallView()
        case "gallery": NavigationStack { DesignSystemGalleryView() }
        default:
            ContentUnavailableView("Écran inconnu : \(screen)", systemImage: "questionmark.square.dashed")
        }
    }
}
#endif

import SwiftUI

/// Round profile button: opens Mon Optique. There are no accounts, so it shows a placeholder photo
/// (`Assets.xcassets/ProfilePlaceholder`).
struct ProfileAvatarButton: View {
    /// A plain `Button` (not a `NavigationLink`): in a toolbar the glass background of a link comes out oval.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("ProfilePlaceholder")
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 34)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColors.stroke, lineWidth: 1))
        }
        .accessibilityLabel("Mon Optique")
    }
}

/// The Optique mark shown at the center of the header.
struct HeaderLogo: View {
    var body: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 30, height: 30)
            .foregroundStyle(AppColors.Adaptive.textPrimary)
            .accessibilityHidden(true)
    }
}

/// App header for screens that hide the navigation bar: profile avatar at the left, logo in the
/// center, nothing at the right (the leading button's width is mirrored to keep the logo centered).
struct AppHeader: View {
    var body: some View {
        HStack {
            NavigationLink { ProfileView() } label: {
                Color.clear.frame(width: 44, height: 44)
                    .overlay {
                        Image("ProfilePlaceholder").resizable().scaledToFill()
                            .frame(width: 34, height: 34).clipShape(Circle())
                            .overlay(Circle().stroke(AppColors.stroke, lineWidth: 1))
                    }
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Mon Optique")
            Spacer()
            HeaderLogo()
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, AppSpacing.s)
        .frame(height: 48)
        .background(AppColors.Adaptive.background)
    }
}

private struct AppHeaderToolbar: ViewModifier {
    @State private var showsProfile = false

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ProfileAvatarButton { showsProfile = true } }
                ToolbarItem(placement: .principal) { HeaderLogo() }
            }
            .navigationDestination(isPresented: $showsProfile) { ProfileView() }
    }
}

extension View {
    /// Same header as `AppHeader`, built from navigation-bar items: the profile picture as a toolbar
    /// button (a circle) and the logo at the centre.
    func appHeaderToolbar() -> some View { modifier(AppHeaderToolbar()) }
}

/// Horizontal topic tabs under the header: the selected tab is bold ink with an underline.
struct TopicTabs: View {
    @Binding var selection: StoryTopic
    /// Called on tap, before the (deferred) selection change, so the page can show its loader at once.
    var onWillSwitch: () -> Void = {}
    /// Called when the deferred change turned out to be a no-op (tapped back to the current tab).
    var onSwitchCancelled: () -> Void = {}
    @Namespace private var indicator
    /// Drives the indicator on its own, so only the tab bar animates and the page below doesn't.
    @State private var shown: StoryTopic = .tout
    @State private var pending: Task<Void, Never>?

    private var topics: [StoryTopic] { [.tout] + StoryTopic.selectable }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(topics) { topic in
                        let isSelected = topic == shown
                        Button {
                            if topic != shown { onWillSwitch(); Haptics.selection() }
                            withAnimation(.app) { shown = topic }
                            // The page below switches right away: its stories come from memory or
                            // the disk cache, so there is nothing to wait for.
                            pending?.cancel()
                            pending = Task {
                                guard !Task.isCancelled else { return }
                                if selection == topic { onSwitchCancelled() }
                                selection = topic
                                pending = nil
                            }
                        } label: {
                            Text(topic == .tout ? "À la une" : topic.rawValue)
                                .font(.appCaption)
                                .foregroundStyle(isSelected ? AppColors.Adaptive.textPrimary : AppColors.Adaptive.textMeta)
                                .padding(.horizontal, AppSpacing.st)
                                .frame(minHeight: 44)
                                .overlay(alignment: .bottom) {
                                    // One shared view: it slides and resizes to the selected tab.
                                    if isSelected {
                                        Rectangle()
                                            .fill(AppColors.Adaptive.textPrimary)
                                            .frame(height: 2)
                                            .matchedGeometryEffect(id: "indicator", in: indicator)
                                    }
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .id(topic)
                    }
                }
                .padding(.horizontal, AppSpacing.s)
            }
            .onAppear { shown = selection }
            .onChange(of: selection) { _, new in
                if pending == nil, shown != new { withAnimation(.app) { shown = new } }
                withAnimation(.app) { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }
}

#if DEBUG
#Preview("Header and tabs") {
    @Previewable @State var topic: StoryTopic = .tout
    return NavigationStack {
        VStack(spacing: 0) {
            AppHeader()
            TopicTabs(selection: $topic)
            Spacer()
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(AppColors.Adaptive.background)
    }
    .environment(BookmarkStore())
    .environment(ReadingHistoryStore())
    .environment(SessionState())
}
#endif

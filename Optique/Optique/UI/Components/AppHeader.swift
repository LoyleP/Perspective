import SwiftUI

/// Round profile button: opens Mon Optique. There are no accounts, so it shows a placeholder photo
/// (`Assets.xcassets/ProfilePlaceholder`).
struct ProfileAvatarButton: View {
    var body: some View {
        NavigationLink {
            ProfileView()
        } label: {
            Image("ProfilePlaceholder")
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 34)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColors.stroke, lineWidth: 1))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
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
            ProfileAvatarButton()
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

extension View {
    /// Same header as `AppHeader`, built from navigation-bar items (for screens that keep
    /// the navigation bar, such as Explorer with its search field).
    func appHeaderToolbar() -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ProfileAvatarButton() }
                ToolbarItem(placement: .principal) { HeaderLogo() }
            }
    }
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
                            if topic != shown { onWillSwitch() }
                            withAnimation(.app) { shown = topic }
                            // The page below switches once the indicator has landed, so loading
                            // it never competes with the animation. The animation never waits on it.
                            pending?.cancel()
                            pending = Task {
                                try? await Task.sleep(for: .milliseconds(420))
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

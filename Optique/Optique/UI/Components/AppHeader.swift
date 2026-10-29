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

    private var topics: [StoryTopic] { [.tout] + StoryTopic.selectable }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.l) {
                    ForEach(topics) { topic in
                        let isSelected = topic == selection
                        Button {
                            withAnimation(.snappy) { selection = topic }
                        } label: {
                            VStack(spacing: 6) {
                                Text(topic == .tout ? "À la une" : topic.rawValue)
                                    .font(.appCaption)
                                    .foregroundStyle(isSelected ? AppColors.Adaptive.textPrimary : AppColors.Adaptive.textMeta)
                                Capsule()
                                    .fill(isSelected ? AppColors.Adaptive.textPrimary : .clear)
                                    .frame(height: 3)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .id(topic)
                    }
                }
                .padding(.horizontal, AppSpacing.m)
            }
            .onChange(of: selection) { _, new in
                withAnimation(.snappy) { proxy.scrollTo(new, anchor: .center) }
            }
        }
        .overlay(alignment: .bottom) {
            Divider().overlay(AppColors.Adaptive.divider)
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

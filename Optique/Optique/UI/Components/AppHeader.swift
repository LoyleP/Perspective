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

/// Pills under the header: rounded chips (with an optional icon), the selected one filled. The fill
/// slides from pill to pill, and the row scrolls to keep the selected one in view.
struct PillTabs<Item: Hashable & Identifiable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String
    var icon: (Item) -> String? = { _ in nil }
    /// Each pill's frame inside the row, so the grey capsules and the highlight can be drawn as
    /// layers of their own: grey capsules, then the highlight, then every label on top.
    @State private var frames: [Item: CGRect] = [:]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(items) { item in
                        let isSelected = item == selection
                        Button {
                            withAnimation(.app) { selection = item }
                        } label: {
                            HStack(spacing: 5) {
                                if let name = icon(item) { LucideIcon(name, size: 14) }
                                Text(title(item))
                                    .typeStyle(.metaMedium)
                            }
                            .foregroundStyle(isSelected ? AppColors.Adaptive.background : AppColors.Adaptive.textPrimary)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("pills")) } action: { frames[item] = $0 }
                        .id(item)
                    }
                }
                .background(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        ForEach(items) { item in
                            if let frame = frames[item] {
                                Capsule().fill(AppColors.Adaptive.surfaceElevated)
                                    .frame(width: frame.width, height: frame.height)
                                    .offset(x: frame.minX, y: frame.minY)
                            }
                        }
                        if let frame = frames[selection] {
                            Capsule().fill(AppColors.Adaptive.textPrimary)
                                .frame(width: frame.width, height: frame.height)
                                .offset(x: frame.minX, y: frame.minY)
                        }
                    }
                }
                .coordinateSpace(name: "pills")
                .padding(.horizontal, AppSpacing.m)
                .padding(.vertical, AppSpacing.s)
            }
            .onChange(of: selection) { _, new in
                withAnimation(.app) { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }
}

/// The home page's topic pills.
struct TopicPills: View {
    let topics: [StoryTopic]
    @Binding var selection: StoryTopic

    var body: some View {
        PillTabs(
            items: topics,
            selection: $selection,
            title: { $0 == .tout ? "À la une" : $0.rawValue },
            icon: { $0.lucideIcon }
        )
    }
}

#if DEBUG
#Preview("Header and tabs") {
    @Previewable @State var topic: StoryTopic = .tout
    return NavigationStack {
        VStack(spacing: 0) {
            AppHeader()
            TopicPills(topics: [.tout] + StoryTopic.selectable, selection: $topic)
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

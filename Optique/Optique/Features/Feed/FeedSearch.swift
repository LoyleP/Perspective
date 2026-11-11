import SwiftUI

/// State of the home page's search: the header field and the page under it share it.
@MainActor @Observable
final class FeedSearchState {
    var isActive = false
    var text = ""
    private(set) var recents: [String]

    private static let key = "recentSearches"

    init() {
        recents = (UserDefaults.standard.string(forKey: Self.key) ?? "").split(separator: "\n").map(String.init)
    }

    func remember(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return }
        recents = Array(([q] + recents.filter { $0.caseInsensitiveCompare(q) != .orderedSame }).prefix(6))
        UserDefaults.standard.set(recents.joined(separator: "\n"), forKey: Self.key)
    }

    func clearRecents() {
        recents = []
        UserDefaults.standard.removeObject(forKey: Self.key)
    }
}

// MARK: - Header

/// The home header: profile, logo and a search button that grows leftwards into the field (avatar and logo
/// step aside, "Annuler" slides in) and shrinks back.
struct FeedHeader: View {
    @Bindable var search: FeedSearchState
    let onProfile: () -> Void

    @FocusState private var focused: Bool
    private let side: CGFloat = 44
    private let margin: CGFloat = 16
    private let cancelWidth: CGFloat = 52

    var body: some View {
        GeometryReader { geo in
            let active = search.isActive
            let expanded = geo.size.width - margin * 2 - cancelWidth
            ZStack(alignment: .trailing) {
                // Profile and logo.
                ZStack {
                    HStack {
                        Button(action: onProfile) {
                            Image("ProfilePlaceholder")
                                .resizable().scaledToFill()
                                .frame(width: 34, height: 34)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(AppColors.stroke, lineWidth: 1))
                                .frame(width: side, height: side)
                                .glassCircle()
                        }
                        .accessibilityLabel("Mon Optique")
                        Spacer()
                    }
                }
                .opacity(active ? 0 : 1)
                .scaleEffect(active ? 0.92 : 1)
                .allowsHitTesting(!active)

                // Annuler
                HStack {
                    Spacer()
                    Button {
                        focused = false
                        withAnimation(.morph) { search.isActive = false }
                        search.text = ""
                    } label: {
                        LucideIcon("x", size: 18)
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                            .frame(width: side, height: side)
                            .glassCircle()
                    }
                    .accessibilityLabel("Fermer la recherche")
                    .frame(width: cancelWidth, alignment: .trailing)
                    .opacity(active ? 1 : 0)
                    .offset(x: active ? 0 : 24)
                    .allowsHitTesting(active)
                }

                // The search button, which is also the field.
                HStack(spacing: AppSpacing.s) {
                    LucideIcon("search", size: 18)
                        .foregroundStyle(active ? AppColors.Adaptive.textMeta : AppColors.Adaptive.textPrimary)
                    TextField("Rechercher un sujet", text: $search.text)
                        .focused($focused)
                        .submitLabel(.search)
                        .onSubmit { search.remember(search.text) }
                        .typeStyle(.ui)
                        .autocorrectionDisabled()
                        .opacity(active ? 1 : 0)
                        .allowsHitTesting(active)
                    if active, !search.text.isEmpty {
                        Button { search.text = "" } label: {
                            LucideIcon("x", size: 14)
                                .foregroundStyle(AppColors.Adaptive.textMeta)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Effacer")
                    }
                }
                .padding(.horizontal, active ? AppSpacing.st : (side - 18) / 2)
                .frame(width: active ? expanded : side, height: side, alignment: .leading)
                .glassCapsule()
                .clipShape(Capsule())
                .contentShape(Capsule())
                .onTapGesture {
                    guard !active else { return }
                    withAnimation(.morph) { search.isActive = true }
                    focused = true
                }
                .offset(x: active ? -cancelWidth : 0)
                .accessibilityElement(children: active ? .contain : .ignore)
                .accessibilityLabel("Rechercher")
                .accessibilityAddTraits(active ? [] : .isButton)
            }
            .padding(.horizontal, margin)
            .frame(maxHeight: .infinity)
        }
        .frame(height: 44)
    }
}

extension View {
    @ViewBuilder
    func glassCircle() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: Circle())
        } else {
            background(AppColors.Adaptive.surfaceElevated, in: Circle())
        }
    }

    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: Capsule())
        } else {
            background(AppColors.Adaptive.surfaceElevated, in: Capsule())
        }
    }
}

/// The glass search field of the home header, as a plain field (Explorer keeps it pinned at the top).
struct GlassSearchField: View {
    @Binding var text: String
    var focus: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            LucideIcon("search", size: 18)
                .foregroundStyle(AppColors.Adaptive.textMeta)
            TextField("Rechercher un sujet", text: $text)
                .focused(focus)
                .submitLabel(.search)
                .typeStyle(.ui)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    LucideIcon("x", size: 14)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Effacer")
            }
        }
        .padding(.horizontal, AppSpacing.st)
        .frame(height: 44)
        .glassCapsule()
        .clipShape(Capsule())
    }
}

/// The round glass cross next to the field.
struct GlassCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            LucideIcon("x", size: 18)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .frame(width: 44, height: 44)
                .glassCircle()
        }
        .accessibilityLabel("Fermer la recherche")
    }
}

// MARK: - Page under the field

/// Themes, recent searches and the most covered stories; headline results while typing.
struct FeedSearchContent: View {
    @Bindable var search: FeedSearchState

    @State private var viewModel = DiscoverViewModel()

    /// The five most covered stories of the moment.
    private var trending: [Story] {
        Array(viewModel.stories.sorted { $0.sources.count > $1.sources.count }.prefix(5))
    }

    var body: some View {
        ScrollView {
            if viewModel.trimmedQuery.isEmpty {
                idle
            } else {
                results
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 52) }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .onChange(of: search.text, initial: true) { _, new in viewModel.searchText = new }
        .task(id: search.text) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await viewModel.search()
        }
        .task { await viewModel.load() }
    }

    // MARK: Idle

    private var idle: some View {
        LazyVStack(alignment: .leading, spacing: AppSpacing.xl) {
            if !search.recents.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    SectionHeader(title: "Récentes", actionTitle: "Effacer") { search.clearRecents() }
                    ForEach(search.recents, id: \.self) { query in
                        Button { search.text = query } label: {
                            HStack(spacing: AppSpacing.st) {
                                LucideIcon("clock", size: 16)
                                    .foregroundStyle(AppColors.Adaptive.textMeta)
                                Text(query)
                                    .typeStyle(.ui)
                                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                                Spacer()
                            }
                            .frame(height: 40)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.m)
            }

            VStack(alignment: .leading, spacing: AppSpacing.m) {
                SectionHeader(title: "Thèmes")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(StoryTopic.selectable) { topic in
                        NavigationLink(value: topic) { ThemeTile(topic: topic) }
                            .buttonStyle(CardPressStyle())
                    }
                }
            }
            .padding(.horizontal, AppSpacing.m)

            if !trending.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: "Les plus couverts", subtitle: "Ce que tout le monde reprend")
                        .padding(.bottom, AppSpacing.xs)
                    ForEach(trending) { story in
                        storyLink(story)
                    }
                }
                .padding(.horizontal, AppSpacing.m)
            }
        }
        .padding(.top, AppSpacing.m)
        .padding(.bottom, AppSpacing.xxl)
    }

    // MARK: Results

    @ViewBuilder
    private var results: some View {
        if viewModel.searchResults.isEmpty {
            if viewModel.isSearching || viewModel.trimmedQuery.count < 2 {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.xxl)
            } else {
                ContentUnavailableView.search(text: viewModel.trimmedQuery)
                    .padding(.top, AppSpacing.xxl)
            }
        } else {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.searchResults) { story in
                    storyLink(story)
                }
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.bottom, AppSpacing.xxl)
        }
    }

    private func storyLink(_ story: Story) -> some View {
        NavigationLink {
            StoryDetailView(story: story)
                .onAppear { search.remember(search.text) }
        } label: {
            StoryRow(story: story)
        }
        .buttonStyle(CardPressStyle())
    }
}

import SwiftUI
import StoreKit

/// The reader's page, built around their own reading spectrum (Letterboxd, Goodreads, Spotify and
/// Speak patterns): a hero coloured by what they read with three numbers, the plan, an interactive
/// gauge of their spectrum, then two shelves of covers: what they read last and what they saved.
struct ProfileView: View {

    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(ReadingHistoryStore.self) private var history
    @Environment(SessionState.self) private var session
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showManage = false
    /// The story being read. Opened from state (not from a link inside a shelf): reading a story
    /// reorders the history, which rebuilt the link that opened it and sent the reader back here.
    @State private var openedStory: Story?
    @State private var selectedLean: PoliticalLean?
    @State private var countersShown = false
    @AppStorage("profileSince") private var since: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    if AppConfig.paywallEnabled {
                        PlanCard(
                            isPremium: session.isPremium,
                            used: session.storiesOpened,
                            total: session.freeLimit,
                            onUpgrade: { showPaywall = true },
                            onManage: session.storeManager.isPremium ? { showManage = true } : nil
                        )
                        .padding(.horizontal, AppSpacing.m)
                    }
                    spectrumSection
                    shelf("Récemment lu", stories: history.stories, list: .history)
                    shelf("Enregistrés", stories: bookmarks.stories, list: .saved)
                }
                .padding(.top, AppSpacing.m)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .appBackButton()
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { NavIcon("gearshape") }
                    .accessibilityLabel("Réglages")
            }
        }
        .tint(AppColors.Adaptive.textPrimary)
        .navigationDestination(item: $openedStory) { story in
            StoryDetailView(story: story)
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .manageSubscriptionsSheet(isPresented: $showManage)
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
        .sensoryFeedback(.selection, trigger: selectedLean)
        .onAppear {
            if since == 0 { since = Date().timeIntervalSince1970 }
            // The numbers count up and the gauge lands on the side the reader leans to.
            if reduceMotion {
                countersShown = true
                selectedLean = dominantLean
            } else {
                withAnimation(.spring(duration: 0.9, bounce: 0.1).delay(0.35)) { countersShown = true }
                withAnimation(.spring(duration: 0.6, bounce: 0.2).delay(0.55)) { selectedLean = dominantLean }
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: AppSpacing.st) {
            Image("ProfilePlaceholder")
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColors.stroke, lineWidth: 1))

            VStack(spacing: 4) {
                HStack(spacing: AppSpacing.s) {
                    Text("Lecteur Optique")
                        .font(.appTitle)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                    if AppConfig.paywallEnabled && session.isPremium {
                        HStack(spacing: 4) {
                            HeroIcon("sparkles", size: 12)
                            Text("PLUS").font(.appCaption)
                        }
                        .foregroundStyle(AppColors.Brand.onInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.Brand.accent, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.4, bounce: 0.2), value: session.isPremium)
                Text("Avec Optique depuis \(sinceText)")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }

            HStack(spacing: 0) {
                stat(history.leans.count, "articles lus")
                divider
                stat(history.stories.count, "sujets ouverts")
                divider
                stat(bookmarks.stories.count, "enregistrés")
            }
            .padding(.top, AppSpacing.s)
            .padding(.horizontal, AppSpacing.m)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 108)
        .padding(.bottom, AppSpacing.l)
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(countersShown ? value : 0)")
                .font(.appTitle)
                .monospacedDigit()
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .contentTransition(.numericText())
            Text(label)
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textMeta)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle().fill(AppColors.Adaptive.divider).frame(width: 1, height: 32)
    }

    private var sinceText: String {
        Date(timeIntervalSince1970: since == 0 ? Date().timeIntervalSince1970 : since)
            .formatted(.dateTime.month(.abbreviated).year().locale(Locale(identifier: "fr_FR")))
    }

    // MARK: - Spectrum

    private var dominantLean: PoliticalLean? {
        guard let coverage = history.coverage, coverage.totalCount > 0 else { return nil }
        return PoliticalLean.allCases.max { coverage.share(of: $0) < coverage.share(of: $1) }
    }

    private var spectrumSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Votre spectre")
                .font(.appHeading)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .padding(.horizontal, AppSpacing.m)

            VStack(alignment: .leading, spacing: AppSpacing.m) {
                if let coverage = history.coverage, coverage.totalCount > 0 {
                    Text(history.insight)
                        .font(.geist(.heading, .medium))
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    CoverageDial(
                        shares: PoliticalLean.allCases.map { (lean: $0, share: coverage.share(of: $0)) },
                        selected: selectedLean,
                        onSelect: { selectedLean = $0 }
                    )
                    Text(balanceHint(coverage))
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textBody)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(coverage.totalCount == 1 ? "Sur 1 article lu" : "Sur \(coverage.totalCount) articles lus")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                } else {
                    Text("Votre spectre se dessine au fil de vos lectures")
                        .font(.geist(.heading, .medium))
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Chaque article ouvert dans Optique compte, selon la position de son média. Lisez quelques sujets pour voir d'où vous venez.")
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textBody)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(AppSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.Adaptive.cardSurface, in: RoundedRectangle(cornerRadius: AppRadius.xl))
            .padding(.horizontal, AppSpacing.m)
        }
    }

    /// A nudge toward the side the reader opens least, once there is enough reading to say so.
    private func balanceHint(_ coverage: CoverageStats) -> String {
        guard coverage.totalCount >= 5 else {
            return "Touchez une tranche pour voir sa part dans vos lectures."
        }
        if coverage.leftShare > coverage.rightShare + 0.15 {
            return "Vous lisez peu la droite. Un sujet vu depuis l'autre bord élargit le tableau."
        }
        if coverage.rightShare > coverage.leftShare + 0.15 {
            return "Vous lisez peu la gauche. Un sujet vu depuis l'autre bord élargit le tableau."
        }
        return "Vos lectures sont réparties des deux côtés. Continuez ainsi."
    }

    // MARK: - Shelves

    @ViewBuilder
    private func shelf(_ title: String, stories: [Story], list: ProfileStoriesView.StoryList) -> some View {
        if !stories.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                NavigationLink {
                    ProfileStoriesView(list: list)
                } label: {
                    HStack(spacing: AppSpacing.s) {
                        Text(title)
                            .font(.appHeading)
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                        Text("\(stories.count)")
                            .font(.appCaption)
                            .monospacedDigit()
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                        Spacer()
                        HeroIcon("chevron-right", size: 16)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                    }
                    .padding(.horizontal, AppSpacing.m)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: AppSpacing.st) {
                        ForEach(stories.prefix(12)) { story in
                            Button { openedStory = story } label: {
                                StoryPoster(story: story)
                            }
                            .buttonStyle(CardPressStyle())
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, AppSpacing.m, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }
}

/// A story as a small poster: its photo, a fade, the headline over it.
private struct StoryPoster: View {
    let story: Story
    private let width: CGFloat = 148
    private let height: CGFloat = 196

    var body: some View {
        Color.clear
            .frame(width: width, height: height)
            .overlay { RemoteImage(url: story.leadImageURL, tint: tint, maxPixel: 480) }
            .overlay(alignment: .bottomLeading) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                    Text(story.title)
                        .font(.geist(.caption, .medium))
                        .foregroundStyle(.white)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .padding(AppSpacing.s)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.l))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(story.title)
    }

    private var tint: Color? {
        story.computedCoverage.flatMap { PoliticalLean(rawValue: $0.dominantLean)?.spectrumColor }
    }
}

// MARK: - Saved stories and history

/// The saved stories or the reading history, as a list of story rows.
struct ProfileStoriesView: View {
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(ReadingHistoryStore.self) private var history
    @State var list: StoryList
    @State private var confirmClearHistory = false
    /// Opened from state, as on the profile: the history reorders when a story is read.
    @State private var openedStory: Story?

    enum StoryList: String {
        case saved = "Enregistrés"
        case history = "Historique"
    }

    init(list: StoryList) { _list = State(initialValue: list) }

    var body: some View {
        ScrollView {
            storyList
                .padding(.horizontal, AppSpacing.m)
                .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .navigationDestination(item: $openedStory) { story in
            StoryDetailView(story: story)
        }
        .navigationTitle(list.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .appBackButton()
        .confirmationDialog("Effacer l'historique ?", isPresented: $confirmClearHistory, titleVisibility: .visible) {
            Button("Effacer", role: .destructive) { history.reset(); Haptics.warning() }
        } message: {
            Text("Votre spectre de lecture sera aussi remis à zéro.")
        }
    }

    // MARK: - Lists

    @ViewBuilder
    private var storyList: some View {
        let stories = list == .saved ? bookmarks.stories : history.stories
        if stories.isEmpty {
            Group {
                if list == .saved {
                    ContentUnavailableView(
                        "Aucun sujet enregistré",
                        hero: "bookmark",
                        description: Text("Touchez le signet d'un sujet pour le retrouver ici.")
                    )
                } else {
                    ContentUnavailableView(
                        "Aucun historique",
                        hero: "clock",
                        description: Text("Les sujets que vous ouvrez apparaîtront ici.")
                    )
                }
            }
            .padding(.top, AppSpacing.l)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if list == .history {
                    HStack {
                        Text(stories.count == 1 ? "1 sujet" : "\(stories.count) sujets")
                            .font(.appCaption)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                        Spacer()
                        Button("Effacer") { confirmClearHistory = true }
                            .font(.appCaption)
                            .foregroundStyle(AppColors.Brand.accent)
                    }
                }
                ForEach(stories) { story in
                    Button { openedStory = story } label: {
                        StoryRow(story: story)
                    }
                    .buttonStyle(CardPressStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            if list == .saved { bookmarks.toggle(story) } else { history.remove(story) }
                        } label: {
                            Label(
                                list == .saved ? "Retirer des enregistrés" : "Retirer de l'historique",
                                hero: "trash"
                            )
                        }
                    }
                    Divider().overlay(AppColors.Adaptive.divider)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Mon Optique") {
    NavigationStack { ProfileView() }
        .environment(BookmarkStore())
        .environment(ReadingHistoryStore())
}
#endif

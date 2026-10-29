import SwiftUI

/// "Mon Optique": reading spectrum, saved stories and history.
struct ProfileView: View {

    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(ReadingHistoryStore.self) private var history
    @State private var showSettings = false
    @State private var list: StoryList = .saved
    @State private var confirmClearHistory = false

    enum StoryList: String, CaseIterable, Identifiable {
        case saved = "Enregistrés"
        case history = "Historique"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.l) {
                NavigationLink {
                    MySpectrumView()
                } label: {
                    ReadingSpectrumCard(history: history)
                }
                .buttonStyle(CardPressStyle())

                Picker("Liste", selection: $list) {
                    ForEach(StoryList.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                storyList
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .navigationTitle("Mon Optique")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Réglages")
            }
        }
        .tint(AppColors.Adaptive.textPrimary)
        .navigationDestination(for: Story.self) { story in
            StoryDetailView(story: story)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .confirmationDialog("Effacer l'historique ?", isPresented: $confirmClearHistory, titleVisibility: .visible) {
            Button("Effacer", role: .destructive) { history.reset() }
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
                        systemImage: "bookmark",
                        description: Text("Touchez le signet d'un sujet pour le retrouver ici.")
                    )
                } else {
                    ContentUnavailableView(
                        "Aucun historique",
                        systemImage: "clock",
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
                            .font(.appFootnote)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                        Spacer()
                        Button("Effacer") { confirmClearHistory = true }
                            .font(.appFootnote)
                            .foregroundStyle(AppColors.Brand.accent)
                    }
                }
                ForEach(stories) { story in
                    NavigationLink(value: story) {
                        StoryRow(story: story)
                    }
                    .buttonStyle(CardPressStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            if list == .saved { bookmarks.toggle(story) } else { history.remove(story) }
                        } label: {
                            Label(
                                list == .saved ? "Retirer des enregistrés" : "Retirer de l'historique",
                                systemImage: "trash"
                            )
                        }
                    }
                    Divider().overlay(AppColors.Adaptive.divider)
                }
            }
        }
    }
}

// MARK: - Reading spectrum card

private struct ReadingSpectrumCard: View {
    let history: ReadingHistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Text("Votre spectre de lecture")
                    .overlineStyle(AppColors.Brand.accent)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }
            Text(history.insight)
                .font(.appTitle2)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .multilineTextAlignment(.leading)

            if let coverage = history.coverage {
                SpectrumBar(coverage: coverage, barHeight: 10)
                ViewThatFits(in: .horizontal) {
                    HStack { shares(coverage) }
                    VStack(alignment: .leading, spacing: AppSpacing.xs) { shares(coverage) }
                }
                Text(coverage.totalCount == 1 ? "1 article lu" : "\(coverage.totalCount) articles lus")
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            } else {
                Text("Chaque article ouvert depuis Optique compte, selon la position de son média.")
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func shares(_ coverage: CoverageStats) -> some View {
        share("Gauche", coverage.leftShare, AppColors.Spectrum.gauche)
        Spacer(minLength: AppSpacing.s)
        share("Centre", coverage.centreShare, AppColors.Spectrum.centre)
        Spacer(minLength: AppSpacing.s)
        share("Droite", coverage.rightShare, AppColors.Spectrum.droite)
    }

    private func share(_ title: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).foregroundStyle(AppColors.Adaptive.textTertiary)
            Text(value, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .foregroundStyle(AppColors.Adaptive.textPrimary)
        }
        .font(.appFootnote)
        .fixedSize()
    }
}

#if DEBUG
#Preview("Mon Optique") {
    NavigationStack { ProfileView() }
        .environment(BookmarkStore())
        .environment(ReadingHistoryStore())
}
#endif

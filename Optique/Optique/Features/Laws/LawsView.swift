import SwiftUI

@MainActor
@Observable
final class LawsViewModel {
    private(set) var laws: [Law] = []
    private(set) var checkedAt: Date?
    private(set) var isLoading = false
    private(set) var error: AppError?

    func load() async {
        guard !isLoading else { return }
        isLoading = laws.isEmpty
        defer { isLoading = false }
        // Last list received shows at once; the network refreshes it behind.
        if laws.isEmpty, let cached = await LawRepository.shared.cachedLaws(), laws.isEmpty {
            laws = cached.laws
            checkedAt = cached.checkedAt
            isLoading = false
        }
        do {
            let page = try await LawRepository.shared.fetchLaws()
            laws = page.laws
            checkedAt = page.checkedAt
            error = nil
            prefetchDetailsOnce(page.laws)
        } catch {
            if laws.isEmpty { self.error = AppError.from(error) }
        }
    }

    private var didPrefetchDetails = false

    /// Fetches every law's page in the background once per session, so opening one shows its
    /// stories without waiting.
    private func prefetchDetailsOnce(_ laws: [Law]) {
        guard !didPrefetchDetails else { return }
        didPrefetchDetails = true
        let uids = laws.map(\.uid)
        Task(priority: .utility) {
            for uid in uids { _ = try? await LawRepository.shared.fetchLaw(uid: uid) }
        }
    }
}

/// Lois tab: the bills in progress in Parliament, most recent activity first, each with its path.
/// Filter pills sit under the header over horizontally swiping pages, one per filter, like the home
/// page. Reloads every few minutes while visible; the server re-checks the Assemblée and Sénat at
/// most every 10 minutes.
struct LawsView: View {
    @State private var viewModel = LawsViewModel()
    @State private var selected: Law?
    @State private var position: LawFilter? = .all
    var isActive = true

    private static let refreshInterval: Duration = .seconds(300)

    var body: some View {
        VStack(spacing: 0) {
            PillTabs(
                items: LawFilter.allCases,
                selection: Binding(get: { position ?? .all }, set: { position = $0 }),
                title: \.rawValue
            )
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(LawFilter.allCases) { filter in
                        LawsFilterPage(filter: filter, viewModel: viewModel) { selected = $0 }
                            .containerRelativeFrame(.horizontal)
                            .id(filter)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $position)
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .appHeaderToolbar()
        .navigationDestination(item: $selected) { law in
            LawDetailView(law: law)
        }
        .onChange(of: position) { _, _ in Haptics.selection() }
        // Loaded once at launch even while another tab is shown, so the first visit is instant.
        .task { await viewModel.load() }
        .task(id: isActive) {
            guard isActive else { return }
            while !Task.isCancelled {
                await viewModel.load()
                try? await Task.sleep(for: Self.refreshInterval)
            }
        }
    }
}

/// One filter's list of laws, grouped by what is happening now.
private struct LawsFilterPage: View {
    let filter: LawFilter
    let viewModel: LawsViewModel
    let onSelect: (Law) -> Void
    @State private var collapsed: Set<LawSection> = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let checkedAt = viewModel.checkedAt {
                    Text("Vérifié \(checkedAt.relativeToNowFrench())")
                        .typeStyle(.meta)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                        .padding(.top, AppSpacing.m)
                }
                content
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.bottom, AppSpacing.xxl)
        }
        .refreshable { await viewModel.load() }
        .shrinksTabBarOnScroll()
        .sensoryFeedback(.selection, trigger: collapsed)
    }

    private var visibleLaws: [Law] { viewModel.laws.filter(filter.includes) }

    private var groups: [(section: LawSection, laws: [Law])] {
        LawSection.allCases.compactMap { section in
            let laws = visibleLaws
                .filter { LawSection.of($0) == section }
                .sorted { ($0.storyCount ?? 0, $0.lastActAt ?? .distantPast) > ($1.storyCount ?? 0, $1.lastActAt ?? .distantPast) }
            return laws.isEmpty ? nil : (section, laws)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            SkeletonLines(count: 6)
        } else if let error = viewModel.error {
            ContentUnavailableView("Lois indisponibles", lucide: "scroll-text", description: Text(error.localizedDescription))
        } else if visibleLaws.isEmpty {
            ContentUnavailableView("Aucun texte", lucide: "scroll-text", description: Text("Aucun texte ne correspond à ce filtre pour le moment."))
        } else {
            // Grouped by what is happening now, the most talked-about texts first in each group.
            ForEach(Array(groups.enumerated()), id: \.element.section) { index, group in
                let isCollapsed = collapsed.contains(group.section)
                let toggle = {
                    withAnimation(.app) {
                        if isCollapsed { collapsed.remove(group.section) } else { collapsed.insert(group.section) }
                    }
                }
                HStack(spacing: 0) {
                    Button(action: toggle) {
                        HStack(spacing: AppSpacing.s) {
                            LucideIcon("chevron-right", size: 18)
                                .foregroundStyle(AppColors.Adaptive.textMeta)
                                .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                            SectionHeader(title: group.section.rawValue)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)
                    InfoBubble(text: group.section.explanation, label: "Ce que veut dire « \(group.section.rawValue) »")
                    // The rest of the row still folds the section.
                    Color.clear.contentShape(Rectangle()).onTapGesture(perform: toggle)
                }
                .accessibilityAddTraits(.isHeader)
                .accessibilityValue(isCollapsed ? "Replié" : "Déplié")
                .padding(.top, index == 0 ? AppSpacing.m : AppSpacing.xl)
                .padding(.bottom, AppSpacing.m)
                if !isCollapsed {
                    VStack(spacing: AppSpacing.s) {
                        ForEach(group.laws) { law in
                            Button { onSelect(law) } label: { LawRow(law: law) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

/// Four-segment bar: Déposé, Voté par une chambre, Voté par les deux, Loi. It shows where the law
/// stands; with `selectedStep` set (the law page's carousel) it shows where the law stood at that step
/// and keeps the law's real progress dimmed behind it.
struct LawProgressBar: View {
    let law: Law
    /// Names each stage under its segment (law page); rows keep the bare bar.
    var showsLabels = false
    /// Index into `law.steps` of the step being looked at, or nil for the law's current progress.
    var selectedStep: Int? = nil

    private var current: Double { LawExplainer.progressPosition(of: law) }

    private var lit: Double {
        guard let step = selectedStep else { return current }
        if step < 0 { return min(1, current) }   // the filing card
        let positions = LawExplainer.positions(of: law)
        guard positions.indices.contains(step) else { return current }
        return min(positions[step], current)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(0..<4, id: \.self) { index in
                VStack(alignment: .leading, spacing: 6) {
                    segment(index)
                    if showsLabels {
                        Text(LawExplainer.progressStages[index])
                            .typeStyle(.meta)
                            .foregroundStyle(index == min(Int(max(lit - 0.001, 0)), 3)
                                             ? AppColors.Adaptive.textPrimary : AppColors.Adaptive.textMeta)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .animation(.app, value: lit)
        .accessibilityElement()
        .accessibilityLabel("Avancement : \(Int(current)) étapes sur 4")
    }

    /// One segment: the track, the law's real progress dimmed, and the progress at the selected step on top.
    private func segment(_ index: Int) -> some View {
        let litFraction = min(max(lit - Double(index), 0), 1)
        let realFraction = min(max(current - Double(index), 0), 1)
        return Capsule()
            .fill(AppColors.Adaptive.divider)
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.Adaptive.textPrimary.opacity(0.3))
                            .frame(width: geo.size.width * realFraction)
                        Capsule()
                            .fill(AppColors.Adaptive.textPrimary)
                            .frame(width: geo.size.width * litFraction)
                    }
                }
            }
            .frame(height: 4)
    }
}

/// List groups: what is happening to the text right now.
enum LawSection: String, CaseIterable, Identifiable {
    case committee = "En commission"
    case debate = "En débat"
    case filed = "Déposés"
    case voted = "Votés récemment"

    var id: String { rawValue }

    /// What the title means, for the info bubble next to it.
    var explanation: String {
        switch self {
        case .committee: return "Un petit groupe de députés ou de sénateurs étudie le texte et le modifie avant qu'il soit débattu devant tous les élus."
        case .debate: return "Le texte est discuté et amendé en public, devant tous les députés ou tous les sénateurs, avant d'être soumis au vote."
        case .filed: return "Le texte vient d'être déposé au Parlement. Personne ne l'a encore examiné : il attend d'être étudié en commission."
        case .voted: return "Une chambre (Assemblée nationale ou Sénat) a adopté ou rejeté le texte ces dernières semaines, ou la loi vient d'être promulguée."
        }
    }

    static func of(_ law: Law) -> LawSection {
        guard let step = law.current else { return .filed }
        if law.isPromulgated { return .voted }
        switch step.stage {
        case "vote", "done":
            let decided = LawDates.date(step.decidedAt ?? step.startedAt) ?? .distantPast
            return decided > Date().addingTimeInterval(-21 * 86_400) ? .voted : .committee
        case "seance": return .debate
        case "commission": return .committee
        default: return .filed
        }
    }
}

/// List row: a plain title, who it concerns in one line, and its status in a plain sentence. The
/// section header above already says what stage the row is at, and the full path (progress bar
/// included) is on the law's own page, so the row itself doesn't repeat either.
struct LawRow: View {
    let law: Law

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            if let name = law.authorName {
                HStack(spacing: AppSpacing.s) {
                    AsyncImage(url: law.authorPhoto.flatMap(URL.init(string:))) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(AppColors.Adaptive.surfaceElevated)
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                    Text(name)
                        .typeStyle(.meta)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                        .lineLimit(1)
                }
            }
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text(law.displayTitle)
                    .typeStyle(.rowTitle)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(LawExplainer.headline(for: law))
                    .typeStyle(.meta)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
                LawProgressBar(law: law)
                    .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.Adaptive.cardSurface, in: RoundedRectangle(cornerRadius: AppRadius.xl))
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .accessibilityElement(children: .combine)
    }
}

/// What the Lois tabs filter on.
enum LawFilter: String, CaseIterable, Identifiable {
    case all = "Tous les textes"
    case assemblee = "À l'Assemblée"
    case senat = "Au Sénat"
    case government = "Projets de loi"
    case members = "Propositions"

    var id: String { rawValue }

    func includes(_ law: Law) -> Bool {
        switch self {
        case .all: return true
        case .assemblee: return law.current?.chamber == "AN"
        case .senat: return law.current?.chamber == "SN"
        case .government: return law.kind == "Projet de loi"
        case .members: return law.kind == "Proposition de loi"
        }
    }
}

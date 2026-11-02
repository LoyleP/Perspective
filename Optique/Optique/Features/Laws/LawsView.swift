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
        do {
            let page = try await LawRepository.shared.fetchLaws()
            laws = page.laws
            checkedAt = page.checkedAt
            error = nil
        } catch {
            if laws.isEmpty { self.error = AppError.from(error) }
        }
    }
}

/// Lois tab: the bills in progress in Parliament, most recent activity first, each with its path.
/// Reloads every few minutes while visible; the server re-checks the Assemblée and Sénat at most
/// every 10 minutes.
struct LawsView: View {
    @State private var viewModel = LawsViewModel()
    @State private var selected: Law?
    @State private var filter: LawFilter = .all
    var isActive = true

    private static let refreshInterval: Duration = .seconds(300)

    var body: some View {
        VStack(spacing: 0) {
            AppHeader()
            LawTabs(selection: $filter)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    content
                    if let checkedAt = viewModel.checkedAt {
                        Text("Assemblée nationale et Sénat · vérifié \(checkedAt.relativeToNowFrench())")
                            .font(.appCaption)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                            .padding(.top, AppSpacing.m)
                    }
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.bottom, AppSpacing.xxl)
            }
            .refreshable { await viewModel.load() }
            .shrinksTabBarOnScroll()
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selected) { law in
            LawDetailView(law: law)
        }
        .task(id: isActive) {
            guard isActive else { return }
            while !Task.isCancelled {
                await viewModel.load()
                try? await Task.sleep(for: Self.refreshInterval)
            }
        }
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
            ContentUnavailableView("Lois indisponibles", hero: "building-library", description: Text(error.localizedDescription))
        } else if visibleLaws.isEmpty {
            ContentUnavailableView("Aucun texte", hero: "building-library", description: Text("Aucun texte ne correspond à ce filtre pour le moment."))
        } else {
            // Grouped by what is happening now, the most talked-about texts first in each group.
            ForEach(Array(groups.enumerated()), id: \.element.section) { index, group in
                SectionHeader(title: group.section.rawValue)
                    .padding(.top, index == 0 ? AppSpacing.s : AppSpacing.xl)
                ForEach(group.laws) { law in
                    Button { selected = law } label: { LawRow(law: law) }
                        .buttonStyle(.plain)
                    Divider().overlay(AppColors.Adaptive.divider)
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
                            .font(.appCaption)
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
    case voted = "Votés récemment"
    case debate = "En débat"
    case committee = "En commission"
    case filed = "Déposés"

    var id: String { rawValue }

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

/// List row: a plain title, who it concerns, its status in a plain sentence, a simple progress bar
/// and what's next.
private struct LawRow: View {
    let law: Law

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(law.displayTitle)
                .font(.geist(.body, .medium))
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let why = law.whyItMatters, !why.isEmpty {
                Text(why)
                    .font(.appBody)
                    .foregroundStyle(AppColors.Adaptive.textBody)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Text(LawExplainer.headline(for: law))
                .font(.appBody)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .multilineTextAlignment(.leading)
            LawProgressBar(law: law)
                .padding(.top, 2)
            if let next = LawExplainer.next(for: law) {
                Text("Ensuite : \(next)")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, AppSpacing.m)
        .contentShape(Rectangle())
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

/// Sub-tabs under the header, same look and motion as the home page's topic tabs (a line under the
/// selected tab that slides and resizes), with filters made for laws.
struct LawTabs: View {
    @Binding var selection: LawFilter
    @Namespace private var indicator

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(LawFilter.allCases) { filter in
                        let isSelected = filter == selection
                        Button {
                            withAnimation(.app) { selection = filter }
                        } label: {
                            Text(filter.rawValue)
                                .font(.appCaption)
                                .foregroundStyle(isSelected ? AppColors.Adaptive.textPrimary : AppColors.Adaptive.textMeta)
                                .padding(.horizontal, AppSpacing.st)
                                .frame(minHeight: 44)
                                .overlay(alignment: .bottom) {
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
                        .id(filter)
                    }
                }
                .padding(.horizontal, AppSpacing.s)
            }
            .onChange(of: selection) { _, new in
                withAnimation(.app) { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }
}

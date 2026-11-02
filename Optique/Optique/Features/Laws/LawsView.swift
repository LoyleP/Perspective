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
    var isActive = true

    private static let refreshInterval: Duration = .seconds(300)

    var body: some View {
        VStack(spacing: 0) {
            AppHeader()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.bottom, AppSpacing.m)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lois")
                .font(.appTitle)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Les textes en cours de vote au Parlement, étape par étape.")
                .font(.appBody)
                .foregroundStyle(AppColors.Adaptive.textMeta)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            SkeletonLines(count: 6)
        } else if let error = viewModel.error {
            ContentUnavailableView("Lois indisponibles", hero: "building-library", description: Text(error.localizedDescription))
        } else if viewModel.laws.isEmpty {
            ContentUnavailableView("Aucun texte en cours", hero: "building-library", description: Text("Revenez plus tard."))
        } else {
            ForEach(viewModel.laws) { law in
                Button { selected = law } label: { LawRow(law: law) }
                    .buttonStyle(.plain)
                Divider().overlay(AppColors.Adaptive.divider)
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

/// List row: the law's title, its status in a plain sentence, a simple progress bar and what's next.
private struct LawRow: View {
    let law: Law

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(law.displayTitle)
                .font(.appBodyStrong)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
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

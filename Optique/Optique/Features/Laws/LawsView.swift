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
            Text(freshness)
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textMeta)
        }
    }

    private var freshness: String {
        guard let checkedAt = viewModel.checkedAt else { return "Assemblée nationale et Sénat" }
        return "Assemblée et Sénat · vérifié \(checkedAt.relativeToNowFrench())"
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

/// List row: kind, title, compact path and where the text stands.
private struct LawRow: View {
    let law: Law

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(law.kindLine)
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textMeta)
            Text(law.displayTitle)
                .font(.appBodyStrong)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            LawPathView(law: law, compact: true)
            Text(LawExplainer.status(of: law))
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .lineLimit(2)
        }
        .padding(.vertical, AppSpacing.m)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

import SwiftUI

// MARK: - Filter

private enum SourceFilter: CaseIterable, Hashable {
    case tout
    case lean(PoliticalLean)

    static var allCases: [SourceFilter] {
        [.tout] + PoliticalLean.allCases.map { .lean($0) }
    }

    var label: String {
        switch self {
        case .tout:        return "Tout"
        case .lean(let l): return l.shortLabel
        }
    }
}

// MARK: - ViewModel

@Observable
private final class SourcesViewModel {

    var sources: [Source] = []
    var isLoading = false
    var error: Error?

    func loadSources() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        do {
            sources = try await SourceRepository.shared.fetchAllSources()
        } catch {
            self.error = error
        }
        isLoading = false
    }
}

// MARK: - View

struct SourcesView: View {

    @State private var viewModel = SourcesViewModel()
    @State private var selectedFilter: SourceFilter = .tout

    var body: some View {
        content
            .navigationTitle("Sources")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: Source.self) { source in
                SourceDetailView(source: source)
            }
            .task { await viewModel.loadSources() }
            .onAppear {
                configureNavigationBarAppearance()
            }
    }

    // MARK: - State routing

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.sources.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
        } else if let error = viewModel.error, viewModel.sources.isEmpty {
            ContentUnavailableView {
                Label("Impossible de charger", systemImage: "wifi.slash")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Réessayer") {
                    Task { await viewModel.loadSources() }
                }
                .buttonStyle(.borderedProminent)
            }
            .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
        } else {
            sourceList
        }
    }

    // MARK: - Source list

    private var sourceList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                leanFilterBar

                methodologyCallout

                if filteredSources.isEmpty {
                    ContentUnavailableView(
                        "Aucun média",
                        systemImage: "building.columns",
                        description: Text("Aucun média pour ce filtre.")
                    )
                    .padding(.top, AppSpacing.xl)
                } else {
                    VStack(spacing: AppSpacing.st) {
                        ForEach(filteredSources) { source in
                            NavigationLink(value: source) {
                                SourceCard(source: source)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.top, AppSpacing.m)
            .padding(.bottom, AppSpacing.xxl)
        }
        .refreshable { await viewModel.loadSources() }
        .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
    }

    // MARK: - Methodology callout

    private var methodologyCallout: some View {
        HStack(alignment: .top, spacing: AppSpacing.s) {
            Image(systemName: "info.circle")
                .font(.appFootnote)
                .foregroundStyle(AppColors.Adaptive.textTertiary)
                .padding(.top, 1)
            Text("Les orientations politiques sont établies par consensus académique : Labarre (Univ. de Zurich, 2024), Cagé et al. (Sciences Po, 2022), Institut Montaigne (2020) et le RSF Ownership Monitor.")
                .font(.appCaption1)
                .foregroundStyle(AppColors.Adaptive.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.m)
        .background(AppColors.Adaptive.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.m))
    }

    // MARK: - Filter bar

    private var leanFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(SourceFilter.allCases, id: \.label) { filter in
                    filterChip(filter)
                }
            }
        }
    }

    private func filterChip(_ filter: SourceFilter) -> some View {
        let isSelected = selectedFilter == filter
        let bg: Color = {
            if isSelected {
                if case .lean(let l) = filter { return l.spectrumColor }
                return AppColors.Adaptive.textSecondary
            }
            return AppColors.Adaptive.cardSurface
        }()
        let fg: Color = {
            if isSelected {
                if case .lean(let l) = filter { return l.tagTextColor }
                return AppColors.Adaptive.background
            }
            return AppColors.Adaptive.textSecondary
        }()
        return Button {
            selectedFilter = filter
        } label: {
            Text(filter.label)
                .font(.appFootnote)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(fg)
                .padding(.horizontal, AppSpacing.st)
                .padding(.vertical, AppSpacing.s)
                .background(bg)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColors.stroke, lineWidth: 1))
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }

    // MARK: - Filtering

    private var filteredSources: [Source] {
        switch selectedFilter {
        case .tout:        return viewModel.sources
        case .lean(let l): return viewModel.sources.filter { $0.politicalLean == l.rawValue }
        }
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()

        appearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold),
            .foregroundColor: UIColor(AppColors.Adaptive.textPrimary)
        ]

        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor(AppColors.Adaptive.textPrimary)
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}

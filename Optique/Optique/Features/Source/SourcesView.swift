import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
private final class SourcesViewModel {

    private(set) var sources: [Source] = []
    private(set) var isLoading = false
    private(set) var error: AppError?

    func loadSources() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        do {
            sources = try await SourceRepository.shared.fetchAllSources()
        } catch {
            self.error = AppError.from(error)
        }
        isLoading = false
    }
}

// MARK: - View

/// All analysed sources, grouped by position on the spectrum.
struct SourcesView: View {

    @State private var viewModel = SourcesViewModel()
    @State private var query = ""

    var body: some View {
        content
            .background(AppColors.Adaptive.background.ignoresSafeArea())
            .navigationTitle("Sources")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Rechercher un média")
            .task { await viewModel.loadSources() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.sources.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.error, viewModel.sources.isEmpty {
            ContentUnavailableView {
                Label("Impossible de charger", systemImage: "wifi.slash")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Réessayer") { Task { await viewModel.loadSources() } }
                    .buttonStyle(.optiquePrimary)
            }
        } else if filtered.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            list
        }
    }

    private var filtered: [Source] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return viewModel.sources }
        return viewModel.sources.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.l, pinnedViews: [.sectionHeaders]) {
                ForEach(PoliticalLean.allCases) { lean in
                    let group = filtered.filter { $0.politicalLean == lean.rawValue }
                    if !group.isEmpty {
                        Section {
                            VStack(spacing: 0) {
                                ForEach(group) { source in
                                    NavigationLink {
                                        SourceDetailView(source: source)
                                    } label: {
                                        SourceRow(source: source)
                                    }
                                    .buttonStyle(CardPressStyle())
                                    if source.id != group.last?.id {
                                        Divider()
                                            .overlay(AppColors.Adaptive.divider)
                                            .padding(.leading, 64)
                                    }
                                }
                            }
                            .cardSurface()
                        } header: {
                            HStack(spacing: AppSpacing.s) {
                                Circle().fill(lean.spectrumColor).frame(width: 10, height: 10)
                                Text(lean.label)
                                    .font(.appHeadline)
                                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                                Text("\(group.count)")
                                    .font(.appFootnote)
                                    .foregroundStyle(AppColors.Adaptive.textMeta)
                                Spacer()
                            }
                            .padding(.vertical, AppSpacing.s)
                            .background(AppColors.Adaptive.background)
                            .accessibilityAddTraits(.isHeader)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.bottom, AppSpacing.xxl)
        }
    }
}

// MARK: - Row

private struct SourceRow: View {
    let source: Source

    var body: some View {
        HStack(spacing: AppSpacing.st) {
            SourceAvatarView(source: source, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                if let owner = source.ownerName ?? source.ownerType?.displayName {
                    Text(owner)
                        .font(.appFootnote)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.appFootnote)
                .foregroundStyle(AppColors.Adaptive.textMeta)
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.st)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("SourcesView") {
    NavigationStack {
        SourcesView()
    }
}
#endif

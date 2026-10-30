import SwiftUI

struct MySpectrumView: View {

    @Environment(ReadingHistoryStore.self) private var store

    var body: some View {
        ScrollView {
            if store.leans.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    spectrumBar
                    breakdownSection
                    resetButton
                }
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .background(AppColors.Adaptive.feedBackground.ignoresSafeArea())
        .navigationTitle("Mon spectre")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppColors.Adaptive.feedBackground, for: .navigationBar)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: AppSpacing.m) {
            HeroIcon("chart-bar", size: 44)
                .foregroundStyle(AppColors.Adaptive.textTertiary)
            Text("Aucun historique")
                .font(.appBodyStrong)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
            Text("Lisez des articles pour voir comment votre consommation d'information se répartit sur le spectre politique.")
                .font(.appBody)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.xxxl)
    }

    // MARK: - Spectrum bar

    private var spectrumBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("RÉPARTITION · \(store.leans.count) ARTICLE\(store.leans.count > 1 ? "S" : "")")
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textTertiary)
                .padding(.horizontal, AppSpacing.m)

            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(barSegments, id: \.lean) { seg in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(seg.lean.spectrumColor)
                            .frame(width: geo.size.width * seg.fraction - 2)
                    }
                }
            }
            .frame(height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(.horizontal, AppSpacing.m)
        }
    }

    // MARK: - Breakdown list

    private var breakdownSection: some View {
        VStack(spacing: AppSpacing.s) {
            ForEach(store.breakdown, id: \.lean) { item in
                HStack(spacing: AppSpacing.m) {
                    LeanTagView(lean: item.lean, style: .rounded)
                        .frame(width: 90, alignment: .leading)

                    ProgressView(value: Double(item.count), total: Double(store.leans.count))
                        .tint(item.lean.spectrumColor)

                    Text("\(item.count)")
                        .font(.appBody)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .frame(width: 28, alignment: .trailing)
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.vertical, 14)
                .cardSurface()
                .padding(.horizontal, AppSpacing.m)
            }
        }
    }

    // MARK: - Reset button

    private var resetButton: some View {
        Button(role: .destructive) {
            store.reset()
        } label: {
            Text("Réinitialiser l'historique")
                .font(.appBody)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .cardSurface()
        }
        .padding(.horizontal, AppSpacing.m)
    }

    // MARK: - Bar segment data

    private struct BarSegment {
        let lean: PoliticalLean
        let fraction: Double
    }

    private var barSegments: [BarSegment] {
        let total = Double(store.leans.count)
        guard total > 0 else { return [] }
        return PoliticalLean.allCases.compactMap { lean -> BarSegment? in
            let count = store.leans.filter { PoliticalLean.from($0) == lean }.count
            guard count > 0 else { return nil }
            return BarSegment(lean: lean, fraction: Double(count) / total)
        }
    }
}

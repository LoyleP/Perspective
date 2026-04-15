import SwiftUI

struct MySpectrumView: View {

    @State private var history: [Int] =
        UserDefaults.standard.array(forKey: "readingHistory") as? [Int] ?? []

    var body: some View {
        ScrollView {
            if history.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    Text("Mon spectre")
                        .font(.appLargeTitle)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppSpacing.m)
                    sectionHeader
                    breakdownCards
                    resetButton
                }
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .background(AppColors.Adaptive.feedBackground.ignoresSafeArea())
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppColors.Adaptive.feedBackground, for: .navigationBar)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: AppSpacing.m) {
            Image(systemName: "chart.bar")
                .font(.system(size: 44))
                .foregroundStyle(AppColors.Adaptive.textTertiary)
            Text("Aucun historique")
                .font(.appHeadline)
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

    // MARK: - Section header

    private var sectionHeader: some View {
        Text("Répartition · \(history.count) articles")
            .font(.appCaption1)
            .foregroundStyle(AppColors.Adaptive.textTertiary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.m)
            .padding(.bottom, -AppSpacing.s)
    }

    // MARK: - Breakdown cards

    private var breakdownCards: some View {
        VStack(spacing: AppSpacing.s) {
            ForEach(breakdown, id: \.lean) { item in
                HStack(spacing: AppSpacing.m) {
                    Text(item.lean.label)
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                    Spacer()
                    Text("\(item.count) article\(item.count > 1 ? "s" : "")")
                        .font(.appBody)
                        .fontWeight(.medium)
                        .foregroundStyle(item.lean.color)
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.vertical, 14)
                .background(AppColors.Adaptive.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
                .padding(.horizontal, AppSpacing.m)
            }
        }
    }

    // MARK: - Reset button

    private var resetButton: some View {
        Button(role: .destructive) {
            UserDefaults.standard.removeObject(forKey: "readingHistory")
            history = []
        } label: {
            Text("Réinitialiser l'historique")
                .font(.appBody)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.Adaptive.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
        }
        .padding(.horizontal, AppSpacing.m)
    }

    // MARK: - Computed

    private var breakdown: [(lean: PoliticalLean, count: Int)] {
        (1...7).compactMap { leanInt in
            let count = history.filter { $0 == leanInt }.count
            guard count > 0, let lean = PoliticalLean.from(leanInt) else { return nil }
            return (lean: lean, count: count)
        }
        .sorted { $0.count > $1.count }
    }
}

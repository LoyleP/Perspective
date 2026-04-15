import SwiftUI

struct OwnershipBreakdownView: View {

    let articles: [Article]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            VStack(spacing: 0) {
                // Stacked bar
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(breakdown, id: \.type.rawValue) { item in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(item.type.color)
                                .frame(width: geo.size.width * CGFloat(item.fraction))
                        }
                    }
                }
                .frame(height: 6)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .padding(.horizontal, AppSpacing.m)
                .padding(.bottom, AppSpacing.m)

                // Legend rows
                VStack(spacing: 1) {
                    ForEach(Array(breakdown.enumerated()), id: \.element.type.rawValue) { index, item in
                        HStack(spacing: AppSpacing.m) {
                            Circle()
                                .fill(item.type.color)
                                .frame(width: 8, height: 8)
                            Text(item.type.displayName)
                                .font(.appBody)
                                .foregroundStyle(AppColors.Adaptive.textPrimary)
                            Spacer()
                            Text("\(Int(item.fraction * 100))%")
                                .font(.appBody)
                                .fontWeight(.medium)
                                .foregroundStyle(AppColors.Adaptive.textSecondary)
                        }
                        .padding(.horizontal, AppSpacing.m)
                        .padding(.vertical, 14)
                        .background(AppColors.Adaptive.cardSurface)

                        if index < breakdown.count - 1 {
                            Divider().padding(.leading, AppSpacing.m + 8 + AppSpacing.m)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
                .padding(.horizontal, AppSpacing.m)
            }
        }
    }

    // MARK: - Computed

    private struct BreakdownItem {
        let type: OwnerType
        let count: Int
        let fraction: Double
    }

    private var breakdown: [BreakdownItem] {
        let sources = articles.compactMap { $0.source }
        let total = sources.count
        guard total > 0 else { return [] }

        var counts: [OwnerType: Int] = [:]
        var unknownCount = 0
        for source in sources {
            if let type = source.ownerType {
                counts[type, default: 0] += 1
            } else {
                unknownCount += 1
            }
        }

        var items = counts
            .map { BreakdownItem(type: $0.key, count: $0.value, fraction: Double($0.value) / Double(total)) }
            .sorted { $0.count > $1.count }

        // If all sources are untyped, show a single Unknown entry
        if items.isEmpty && unknownCount > 0 {
            items = [BreakdownItem(type: .unknown, count: unknownCount, fraction: 1.0)]
        }

        return items
    }
}

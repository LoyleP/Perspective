import SwiftUI

/// Who owns the outlets covering a story: a stacked bar plus ranked rows, limited to the four
/// largest owner types and an "Autres" slice, so five sections at most.
struct OwnershipBreakdownView: View {

    let articles: [Article]

    private static let maxSections = 5

    /// Distinct hues by slice rank (largest first), so neighbouring slices always contrast.
    private static let palette: [Color] = [
        Color(light: "E08A00", dark: "FFB020"),   // amber
        Color(light: "0E9F8E", dark: "2DD4BF"),   // teal
        Color(light: "7C3AED", dark: "A78BFA"),   // violet
        Color(light: "DB2777", dark: "F472B6"),   // pink
        Color(light: AppColors.Zinc.Hex.z400, dark: AppColors.Zinc.Hex.z500),   // zinc grey (Autres)
    ]

    var body: some View {
        let items = breakdown
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(items) { item in
                        item.color
                            .frame(width: max(4, (geo.size.width - CGFloat(items.count - 1) * 2) * item.fraction))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 16)
            .accessibilityHidden(true)

            VStack(spacing: AppSpacing.m) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: AppSpacing.s) {
                            Circle().fill(item.color).frame(width: 8, height: 8)
                            Text(item.name)
                                .typeStyle(.body)
                                .foregroundStyle(AppColors.Adaptive.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: AppSpacing.s)
                            Text("\(item.count) média\(item.count > 1 ? "s" : "")")
                                .typeStyle(.meta)
                                .foregroundStyle(AppColors.Adaptive.textMeta)
                            Text(item.fraction, format: .percent.precision(.fractionLength(0)))
                                .typeStyle(.body)
                                .monospacedDigit()
                                .foregroundStyle(AppColors.Adaptive.textPrimary)
                                .frame(minWidth: 44, alignment: .trailing)
                        }
                        GeometryReader { geo in
                            Capsule().fill(item.color.opacity(0.18))
                                .overlay(alignment: .leading) {
                                    Capsule().fill(item.color)
                                        .frame(width: max(4, geo.size.width * item.fraction))
                                }
                        }
                        .frame(height: 4)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.horizontal, AppSpacing.m)
    }

    // MARK: - Computed

    private struct BreakdownItem: Identifiable {
        let id: String
        let name: String
        let color: Color
        let count: Int
        let fraction: Double
    }

    private var breakdown: [BreakdownItem] {
        let sources = articles.compactMap { $0.source }
        let total = sources.count
        guard total > 0 else { return [] }

        var counts: [OwnerType: Int] = [:]
        for source in sources { counts[source.ownerType ?? .unknown, default: 0] += 1 }

        let sorted = counts.sorted { $0.value > $1.value }
        let head = sorted.prefix(sorted.count > Self.maxSections ? Self.maxSections - 1 : Self.maxSections)
        var items = head.enumerated().map { index, entry in
            BreakdownItem(id: entry.key.rawValue, name: entry.key.displayName, color: Self.palette[index],
                          count: entry.value, fraction: Double(entry.value) / Double(total))
        }
        let rest = sorted.dropFirst(head.count).reduce(0) { $0 + $1.value }
        if rest > 0 {
            items.append(BreakdownItem(id: "other", name: "Autres", color: Self.palette[4],
                                       count: rest, fraction: Double(rest) / Double(total)))
        }
        return items
    }
}

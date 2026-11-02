import SwiftUI

/// The app's tab bar: a floating glass capsule, with the selected tab on a darker inner
/// capsule. Each tab shows its icon with a short name under it, so no tab has to be guessed.
struct FloatingTabBar: View {

    struct Item: Identifiable {
        let id: Int
        let accessibilityLabel: String
        /// Short visible name under the icon.
        var title: String = ""
        /// Heroicon name, or an asset name when `isAsset` is true.
        let icon: String
        /// Whether a solid variant of the Heroicon exists, shown when selected.
        var hasSolid = false
        var isAsset = false
        /// Shows a small dot on the icon (unread alerts).
        var showsBadge = false
    }

    let items: [Item]
    @Binding var selection: Int

    @Namespace private var indicator

    /// Height the bar occupies at the bottom of the screen (for content insets).
    static let margin: CGFloat = 24
    static let height: CGFloat = 64 + margin

    private let itemHeight: CGFloat = 56
    private let iconSize: CGFloat = 24

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                button(for: item)
            }
        }
        .padding(4)
        .background { barBackground }
        .padding(.horizontal, Self.margin)
        .padding(.bottom, Self.margin)
    }

    // MARK: - Items

    private func button(for item: Item) -> some View {
        let isSelected = selection == item.id
        return Button {
            guard selection != item.id else { return }
            withAnimation(.app) { selection = item.id }
        } label: {
            icon(for: item, isSelected: isSelected)
                .overlay(alignment: .topTrailing) {
                    if item.showsBadge {
                        Circle()
                            .fill(AppColors.Adaptive.textPrimary)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(AppColors.Adaptive.background, lineWidth: 2))
                            .offset(x: 3, y: -2)
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: itemHeight)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color(light: "1409090B", dark: "7309090B"))
                            .matchedGeometryEffect(id: "indicator", in: indicator)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private func icon(for item: Item, isSelected: Bool) -> some View {
        let color = isSelected ? AppColors.Adaptive.textPrimary : AppColors.Adaptive.textPrimary.opacity(0.62)
        VStack(spacing: 3) {
            if item.isAsset {
                Image(item.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
            } else {
                HeroIcon(item.icon, solid: isSelected && item.hasSolid, size: iconSize)
            }
            if !item.title.isEmpty {
                Text(item.title)
                    .font(.geist(.caption, .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(color)
    }

    // MARK: - Background

    @ViewBuilder
    private var barBackground: some View {
        if #available(iOS 26.0, *) {
            Capsule().fill(.clear).glassEffect(.regular, in: .capsule)
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(AppColors.stroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        }
    }
}

#if DEBUG
#Preview("Tab bar") {
    @Previewable @State var selection = 0
    return ZStack(alignment: .bottom) {
        AppColors.Adaptive.background.ignoresSafeArea()
        FloatingTabBar(
            items: [
                .init(id: 0, accessibilityLabel: "À la une", icon: "home", hasSolid: true),
                .init(id: 1, accessibilityLabel: "Explorer", icon: "magnifying-glass"),
                .init(id: 2, accessibilityLabel: "Alertes", icon: "bell", hasSolid: true)
            ],
            selection: $selection
        )
    }
}
#endif

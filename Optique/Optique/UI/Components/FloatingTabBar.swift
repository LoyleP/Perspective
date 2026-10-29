import SwiftUI

/// The app's tab bar: a floating glass capsule, with the selected tab on a darker inner
/// capsule. Icons only (no labels), larger than the system tab bar's.
struct FloatingTabBar: View {

    struct Item: Identifiable {
        let id: Int
        let accessibilityLabel: String
        /// SF Symbol name, or an asset name when `isAsset` is true.
        let icon: String
        var selectedIcon: String? = nil
        var isAsset = false
    }

    let items: [Item]
    @Binding var selection: Int

    @Namespace private var indicator

    /// Height the bar occupies at the bottom of the screen (for content insets).
    static let height: CGFloat = 64 + 8

    private let itemSize = CGSize(width: 88, height: 56)
    private let iconSize: CGFloat = 30

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                button(for: item)
            }
        }
        .padding(4)
        .background { barBackground }
        .padding(.bottom, 8)
    }

    // MARK: - Items

    private func button(for item: Item) -> some View {
        let isSelected = selection == item.id
        return Button {
            guard selection != item.id else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { selection = item.id }
        } label: {
            icon(for: item, isSelected: isSelected)
                .frame(width: itemSize.width, height: itemSize.height)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color(light: "14000000", dark: "73000000"))
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
        if item.isAsset {
            Image(item.icon)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(color)
        } else {
            Image(systemName: isSelected ? (item.selectedIcon ?? item.icon) : item.icon)
                .font(.system(size: iconSize - 4, weight: isSelected ? .medium : .regular))
                .foregroundStyle(color)
                .frame(width: iconSize, height: iconSize)
        }
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
                .init(id: 0, accessibilityLabel: "À la une", icon: "AppLogoTab", isAsset: true),
                .init(id: 1, accessibilityLabel: "Mon Optique", icon: "person.crop.circle", selectedIcon: "person.crop.circle.fill"),
                .init(id: 2, accessibilityLabel: "Explorer", icon: "magnifyingglass")
            ],
            selection: $selection
        )
    }
}
#endif

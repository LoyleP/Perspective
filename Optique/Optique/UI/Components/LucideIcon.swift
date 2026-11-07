import SwiftUI

/// Lucide icons (lucide.dev, ISC licence: `UI/Theme/LUCIDE-LICENSE.txt`) rendered from the asset
/// catalog (`Assets.xcassets/Icons`). Names are Lucide's own (`bell`, `chevron-right`…). Every icon has a
/// `bold` cut (heavier stroke, for a selected state); `heart`, `bookmark` and `bell` also have a `filled` cut.
/// The icon takes the current foreground style and scales with Dynamic Type.
struct LucideIcon: View {
    let name: String
    var bold = false
    var filled = false
    @ScaledMetric private var scaledSize: CGFloat

    private static let filledNames: Set<String> = ["heart", "bookmark", "bell"]

    init(_ name: String, bold: Bool = false, filled: Bool = false, size: CGFloat = 20) {
        self.name = name
        self.bold = bold
        self.filled = filled
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    private var assetName: String {
        if filled && Self.filledNames.contains(name) { return "lucide-\(name)-fill" }
        return bold ? "lucide-\(name)-bold" : "lucide-\(name)"
    }

    var body: some View {
        Image(assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: scaledSize, height: scaledSize)
            .accessibilityHidden(true)
    }
}

extension Label where Title == Text, Icon == LucideIcon {
    /// `Label` with a Lucide icon in place of an SF Symbol.
    init(_ title: String, lucide name: String, bold: Bool = false, size: CGFloat = 20) {
        self.init {
            Text(title)
        } icon: {
            LucideIcon(name, bold: bold, size: size)
        }
    }
}

extension ContentUnavailableView where Label == SwiftUI.Label<Text, LucideIcon>, Description == Text, Actions == EmptyView {
    /// `ContentUnavailableView` with a Lucide icon in place of an SF Symbol.
    init(_ title: String, lucide name: String, description: Text) {
        self.init {
            SwiftUI.Label(title, lucide: name, size: 44)
        } description: {
            description
        }
    }
}

import SwiftUI

// Geist throughout, Regular and Medium only. Sizes follow Dynamic Type via the text style
// each token is relative to. Hierarchy comes from size and Regular/Medium, never from bold.
extension Font {

    enum GeistWeight {
        case regular
        case medium

        var fontName: String { self == .medium ? "Geist-Medium" : "Geist-Regular" }
    }

    static func geist(_ size: CGFloat, _ weight: GeistWeight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.fontName, size: size, relativeTo: style)
    }

    /// Screen titles ("À la une") — 34
    static var appDisplay: Font { .geist(34, .medium, relativeTo: .largeTitle) }
    /// Headlines over photos — 28
    static var appLargeTitle: Font { .geist(28, .medium, relativeTo: .title) }
    /// Story headline — 22
    static var appTitle1: Font { .geist(22, .medium, relativeTo: .title2) }
    /// Section titles — 20
    static var appTitle2: Font { .geist(20, .medium, relativeTo: .title3) }
    /// Card titles — 18
    static var appTitle3: Font { .geist(18, .medium, relativeTo: .title3) }
    /// Row titles — 17 medium
    static var appHeadline: Font { .geist(17, .medium, relativeTo: .headline) }
    /// Body — 17 regular
    static var appBody: Font { .geist(17, .regular, relativeTo: .body) }
    /// Dek / secondary paragraph — 15
    static var appSubheadline: Font { .geist(15, .regular, relativeTo: .subheadline) }
    /// Metadata — 13 medium
    static var appFootnote: Font { .geist(13, .medium, relativeTo: .footnote) }
    /// Chips and labels — 12 medium
    static var appCaption1: Font { .geist(12, .medium, relativeTo: .caption) }
    /// Fine print — 11
    static var appCaption2: Font { .geist(11, .regular, relativeTo: .caption2) }
    /// Overline — 11 medium, uppercase and tracked (see `overlineStyle()`)
    static var appOverline: Font { .geist(11, .medium, relativeTo: .caption2) }
}

extension UIFont {
    /// UIKit twin of `Font.geist`, for navigation bars, tab bars and other UIKit-backed controls.
    static func geist(_ size: CGFloat, _ weight: Font.GeistWeight = .regular, relativeTo style: UIFont.TextStyle = .body) -> UIFont {
        let base = UIFont(name: weight.fontName, size: size) ?? .systemFont(ofSize: size, weight: weight == .medium ? .medium : .regular)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }
}

extension View {
    /// Uppercase, tracked overline used above headlines and section titles.
    func overlineStyle(_ color: Color = AppColors.Adaptive.textMeta) -> some View {
        self
            .font(.appOverline)
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(color)
    }
}

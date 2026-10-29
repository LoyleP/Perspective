import SwiftUI

// Geist throughout, Regular and Medium only, in exactly four sizes (see `AppTextSize`).
// Sizes follow Dynamic Type via the text style each size is relative to. Hierarchy comes from size and Regular/Medium, never from bold.
extension Font {

    enum GeistWeight {
        case regular
        case medium

        var fontName: String { self == .medium ? "Geist-Medium" : "Geist-Regular" }
    }

    /// The only four type sizes in the app. Every font goes through one of these, so a fifth
    /// size cannot be introduced without changing this enum (and the design system with it).
    enum AppTextSize: CGFloat {
        case title = 28     // screen and story headlines, big numbers
        case heading = 20   // section titles, card titles
        case body = 16      // reading text, row titles, tab titles' parent size
        case caption = 13   // metadata, chips, labels, topic tabs

        var textStyle: Font.TextStyle {
            switch self {
            case .title: .title
            case .heading: .title3
            case .body: .body
            case .caption: .footnote
            }
        }
        var uiTextStyle: UIFont.TextStyle {
            switch self {
            case .title: .title1
            case .heading: .title3
            case .body: .body
            case .caption: .footnote
            }
        }
    }

    static func geist(_ size: AppTextSize, _ weight: GeistWeight = .regular) -> Font {
        .custom(weight.fontName, size: size.rawValue, relativeTo: size.textStyle)
    }

    /// Headlines, big numbers — 28 medium
    static var appTitle: Font { .geist(.title, .medium) }
    /// Section and card titles — 20 medium
    static var appHeading: Font { .geist(.heading, .medium) }
    /// Row titles and emphasis — 16 medium
    static var appBodyStrong: Font { .geist(.body, .medium) }
    /// Reading text, dek — 16 regular
    static var appBody: Font { .geist(.body, .regular) }
    /// Metadata, chips, labels, overlines — 13 medium
    static var appCaption: Font { .geist(.caption, .medium) }
}

extension UIFont {
    /// UIKit twin of `Font.geist`, for navigation bars and other UIKit-backed controls.
    static func geist(_ size: Font.AppTextSize, _ weight: Font.GeistWeight = .regular) -> UIFont {
        let base = UIFont(name: weight.fontName, size: size.rawValue) ?? .systemFont(ofSize: size.rawValue, weight: weight == .medium ? .medium : .regular)
        return UIFontMetrics(forTextStyle: size.uiTextStyle).scaledFont(for: base)
    }
}

extension View {
    /// Uppercase, tracked overline used above headlines and section titles.
    func overlineStyle(_ color: Color = AppColors.Adaptive.textMeta) -> some View {
        self
            .font(.appCaption)
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(color)
    }
}

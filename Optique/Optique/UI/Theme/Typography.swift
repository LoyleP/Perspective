import SwiftUI

// Geist throughout: Regular for reading text, Medium for captions, SemiBold for titles (see `AppTextSize`).
// Sizes follow Dynamic Type via the text style each size is relative to. Hierarchy comes from size and weight, never from bold.
extension Font {

    enum GeistWeight {
        case regular
        case medium
        case semibold

        var fontName: String {
            switch self {
            case .regular: "Geist-Regular"
            case .medium: "Geist-Medium"
            case .semibold: "Geist-SemiBold"
            }
        }

        var systemWeight: UIFont.Weight {
            switch self {
            case .regular: .regular
            case .medium: .medium
            case .semibold: .semibold
            }
        }
    }

    /// The only type sizes in the app. Every font goes through one of these, so a new size
    /// cannot be introduced without changing this enum (and the design system with it).
    enum AppTextSize: CGFloat {
        case title = 28     // screen and story headlines, big numbers
        case heading = 20   // section titles, card titles
        case body = 16      // row titles and emphasis
        case reading = 14   // paragraphs, bullet points, comments, descriptions
        case caption = 13   // metadata, chips, labels, topic tabs

        var textStyle: Font.TextStyle {
            switch self {
            case .title: .title
            case .heading: .title3
            case .body: .body
            case .reading: .callout
            case .caption: .footnote
            }
        }
        var uiTextStyle: UIFont.TextStyle {
            switch self {
            case .title: .title1
            case .heading: .title3
            case .body: .body
            case .reading: .callout
            case .caption: .footnote
            }
        }
    }

    static func geist(_ size: AppTextSize, _ weight: GeistWeight = .regular) -> Font {
        .custom(weight.fontName, size: size.rawValue, relativeTo: size.textStyle)
    }

    /// Headlines, big numbers — 28 semibold
    static var appTitle: Font { .geist(.title, .semibold) }
    /// Section and card titles — 20 semibold
    static var appHeading: Font { .geist(.heading, .semibold) }
    /// Row titles and emphasis — 16 semibold
    static var appBodyStrong: Font { .geist(.body, .semibold) }
    /// Paragraphs, bullet points, comments, deks — 14 regular
    static var appBody: Font { .geist(.reading, .regular) }
    /// Metadata, chips, labels, overlines — 13 medium
    static var appCaption: Font { .geist(.caption, .medium) }
}

extension UIFont {
    /// UIKit twin of `Font.geist`, for navigation bars and other UIKit-backed controls.
    static func geist(_ size: Font.AppTextSize, _ weight: Font.GeistWeight = .regular) -> UIFont {
        let base = UIFont(name: weight.fontName, size: size.rawValue) ?? .systemFont(ofSize: size.rawValue, weight: weight.systemWeight)
        return UIFontMetrics(forTextStyle: size.uiTextStyle).scaledFont(for: base)
    }
}

extension View {
    /// Small grey meta line above headlines and section titles (sentence case, like the rest).
    func overlineStyle(_ color: Color = AppColors.Adaptive.textMeta) -> some View {
        self
            .font(.appCaption)
            .foregroundStyle(color)
    }
}

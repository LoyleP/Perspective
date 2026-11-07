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

// MARK: - Role-based type styles
//
// Two voices: SF Pro Condensed for titles only (like Apple News), Geist for everything else. A `TypeStyle` fixes
// size, line height and tracking together, and scales all three with Dynamic Type.
// Use `.typeStyle(.rowTitle)` on text; the older `.appBody`-style fonts remain for screens not migrated yet.

struct TypeStyle {
    enum Voice { case condensed, sans }

    let voice: Voice
    /// Weight: 400 regular, 500 medium, 600 semibold.
    let weight: CGFloat
    let size: CGFloat
    let lineHeight: CGFloat
    /// Letter spacing in em (0.01 = 1 % of the font size).
    let tracking: CGFloat
    let textStyle: UIFont.TextStyle

    // Titles: SF Pro Condensed
    static let display    = TypeStyle(voice: .condensed, weight: 700, size: 34, lineHeight: 38, tracking: 0, textStyle: .title1)
    static let headline   = TypeStyle(voice: .condensed, weight: 700, size: 26, lineHeight: 30, tracking: 0, textStyle: .title2)
    static let rowTitle   = TypeStyle(voice: .condensed, weight: 700, size: 20, lineHeight: 24, tracking: 0.003, textStyle: .headline)
    // Reading text: Geist
    static let standfirst = TypeStyle(voice: .sans, weight: 400, size: 17, lineHeight: 24, tracking: 0, textStyle: .body)
    /// Standfirst on compact cards and rows.
    static let dek        = TypeStyle(voice: .sans, weight: 400, size: 15, lineHeight: 20, tracking: 0, textStyle: .subheadline)
    static let reading    = TypeStyle(voice: .sans, weight: 400, size: 17, lineHeight: 26, tracking: 0, textStyle: .body)

    // Interface: Geist
    static let screenTitle = TypeStyle(voice: .sans, weight: 600, size: 28, lineHeight: 32, tracking: -0.004, textStyle: .title1)
    static let figure = TypeStyle(voice: .sans, weight: 600, size: 48, lineHeight: 52, tracking: -0.01, textStyle: .largeTitle)
    static let body    = TypeStyle(voice: .sans, weight: 400, size: 15, lineHeight: 22, tracking: 0, textStyle: .subheadline)
    static let section = TypeStyle(voice: .sans, weight: 600, size: 20, lineHeight: 24, tracking: -0.002, textStyle: .title3)
    static let ui      = TypeStyle(voice: .sans, weight: 500, size: 15, lineHeight: 20, tracking: 0, textStyle: .subheadline)
    static let meta    = TypeStyle(voice: .sans, weight: 400, size: 13, lineHeight: 16, tracking: 0.002, textStyle: .footnote)
    static let metaMedium = TypeStyle(voice: .sans, weight: 500, size: 13, lineHeight: 16, tracking: 0.002, textStyle: .footnote)
    static let label   = TypeStyle(voice: .sans, weight: 500, size: 12, lineHeight: 14, tracking: 0.02, textStyle: .caption1)

    func scale(for size: DynamicTypeSize) -> CGFloat {
        let category = size.contentSizeCategory
        return UIFontMetrics(forTextStyle: textStyle)
            .scaledValue(for: self.size, compatibleWith: UITraitCollection(preferredContentSizeCategory: category)) / self.size
    }

    func uiFont(scale: CGFloat) -> UIFont {
        let points = size * scale
        switch voice {
        case .condensed:
            // SF Pro in its condensed width, the way Apple News sets headlines.
            let base = UIFont.systemFont(ofSize: points, weight: weight >= 700 ? .bold : .semibold)
            let descriptor = base.fontDescriptor.addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.width: -0.2]
            ])
            return UIFont(descriptor: descriptor, size: points)
        case .sans:
            let name = weight >= 600 ? "Geist-SemiBold" : weight >= 500 ? "Geist-Medium" : "Geist-Regular"
            return UIFont(name: name, size: points) ?? .systemFont(ofSize: points, weight: .regular)
        }
    }
}

private extension DynamicTypeSize {
    var contentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}

private struct TypeStyleModifier: ViewModifier {
    let style: TypeStyle
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let scale = style.scale(for: dynamicTypeSize)
        let font = style.uiFont(scale: scale)
        let lineHeight = style.lineHeight * scale
        content
            .font(Font(font as CTFont))
            .tracking(style.tracking * font.pointSize)
            .exactLineHeight(lineHeight, naturalHeight: font.lineHeight)
    }
}

private extension View {
    /// Sets the line height itself (iOS 26 can go below the font's natural height, which tight headlines
    /// need); earlier systems can only add space between lines.
    @ViewBuilder
    func exactLineHeight(_ height: CGFloat, naturalHeight: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            lineHeight(.exact(points: height))
        } else {
            lineSpacing(max(height - naturalHeight, 0))
        }
    }
}

extension View {
    /// Applies a role of the type scale: font, letter spacing and line height together.
    func typeStyle(_ style: TypeStyle) -> some View { modifier(TypeStyleModifier(style: style)) }
}

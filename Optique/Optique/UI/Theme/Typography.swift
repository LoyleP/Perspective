import SwiftUI

// Type scale built on Dynamic Type text styles so every size follows the
// user's text-size setting. SF Pro throughout; weight carries the hierarchy.
extension Font {

    /// Screen titles ("À la une") — 34pt bold
    static var appDisplay: Font {
        .system(.largeTitle, design: .default, weight: .bold)
    }

    /// Hero headlines laid over images — 28pt heavy
    static var appLargeTitle: Font {
        .system(.title, design: .default, weight: .heavy)
    }

    /// Story detail headline — 22pt bold
    static var appTitle1: Font {
        .system(.title2, design: .default, weight: .bold)
    }

    /// Section titles — 20pt bold
    static var appTitle2: Font {
        .system(.title3, design: .default, weight: .bold)
    }

    /// Card titles — 20pt semibold
    static var appTitle3: Font {
        .system(.title3, design: .default, weight: .semibold)
    }

    /// Row titles — 17pt semibold
    static var appHeadline: Font {
        .system(.headline, design: .default, weight: .semibold)
    }

    /// Body — 17pt regular
    static var appBody: Font {
        .system(.body, design: .default, weight: .regular)
    }

    /// Dek / secondary paragraph — 15pt regular
    static var appSubheadline: Font {
        .system(.subheadline, design: .default, weight: .regular)
    }

    /// Metadata — 13pt medium
    static var appFootnote: Font {
        .system(.footnote, design: .default, weight: .medium)
    }

    /// Chips and labels — 12pt semibold
    static var appCaption1: Font {
        .system(.caption, design: .default, weight: .semibold)
    }

    /// Fine print — 11pt regular
    static var appCaption2: Font {
        .system(.caption2, design: .default, weight: .regular)
    }

    /// Overline ("8 SOURCES · IL Y A 2 H") — 11pt semibold; pair with
    /// `.textCase(.uppercase)` and `.tracking(0.6)` (see `overlineStyle()`).
    static var appOverline: Font {
        .system(.caption2, design: .default, weight: .semibold)
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

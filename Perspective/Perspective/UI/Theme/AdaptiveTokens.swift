import SwiftUI
import UIKit

// Semantic adaptive color tokens for light/dark mode.
// Each token references existing AppColors.Neutral values via UIColor dynamic provider.
// DesignTokens.swift is intentionally untouched.

extension AppColors {
    enum Adaptive {

        // MARK: - Backgrounds

        /// Feed scroll background (n200 light / n900 dark)
        static var feedBackground: Color {
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(Neutral.n950) : UIColor(Neutral.n50)
            })
        }

        /// Page-level background (n100 light / n900 dark)
        static var background: Color {
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(Neutral.n950) : UIColor(Neutral.n50)
            })
        }

        /// Cards on the feed (n100 light / n800 dark)
        static var cardSurface: Color {
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(Neutral.n900) : UIColor(Neutral.n100)
            })
        }

        /// Cards on the detail page (n50 light / n800 dark)
        static var detailSurface: Color {
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(Neutral.n900) : UIColor(Neutral.n100)
            })
        }

        // MARK: - Dividers

        /// 1pt separator lines (n200 light / n800 dark)
        static var divider: Color {
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(Neutral.n800) : UIColor(Neutral.n200)
            })
        }

        // MARK: - Text

        /// Large titles and prominent text (n800 light / n50 dark)
        static var textPrimary: Color {
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(Neutral.n50) : UIColor(Neutral.n800)
            })
        }

        /// Card titles (n700 light / n200 dark)
        static var textSecondary: Color {
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(Neutral.n200) : UIColor(Neutral.n700)
            })
        }

        /// Body and paragraph text (n600 light / n300 dark)
        static var textBody: Color {
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(Neutral.n300) : UIColor(Neutral.n600)
            })
        }

        /// Captions and section headers (n500 light / n400 dark)
        static var textTertiary: Color {
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(Neutral.n400) : UIColor(Neutral.n500)
            })
        }

        /// Source names, counts, metadata (n400 light / n500 dark)
        static var textMeta: Color {
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(Neutral.n500) : UIColor(Neutral.n400)
            })
        }

        // MARK: - UI

        /// Loading skeletons and empty image areas (n300 light / n600 dark)
        static var placeholder: Color {
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(Neutral.n600) : UIColor(Neutral.n300)
            })
        }

        /// Component borders (black@8% light / white@10% dark)
        static var stroke: Color {
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(white: 1, alpha: 0.10)
                    : UIColor(white: 0, alpha: 0.08)
            })
        }
    }
}

import SwiftUI

// Semantic color tokens. Black and white (plus greys) that follow the system light/dark theme.

extension AppColors {
    enum Adaptive {

        // MARK: - Backgrounds

        /// Page and feed background: white / black
        static let background = Color(light: "FFFFFF", dark: "000000")
        static let feedBackground = background

        /// Cards and grouped rows
        static let cardSurface = Color(light: "F4F4F4", dark: "111111")
        static let detailSurface = cardSurface

        /// Chips, sheets, banners — one step above cards
        static let surfaceElevated = Color(light: "E9E9E9", dark: "1E1E1E")

        // MARK: - Dividers

        static let divider = Color(light: "1A000000", dark: "1FFFFFFF")

        // MARK: - Text

        /// Titles and prominent text
        static let textPrimary = Color(light: "000000", dark: "FFFFFF")
        /// Card titles
        static let textSecondary = Color(light: "1F1F1F", dark: "EDEDED")
        /// Body and paragraph text
        static let textBody = Color(light: "3A3A3A", dark: "D2D2D2")
        /// Captions and section headers
        static let textTertiary = Color(light: "5F5F5F", dark: "A3A3A3")
        /// Source names, counts, metadata
        static let textMeta = Color(light: "707070", dark: "8E8E8E")

        // MARK: - UI

        /// Loading skeletons and empty image areas
        static let placeholder = Color(light: "E4E4E4", dark: "1C1C1C")
        /// Component borders
        static let stroke = AppColors.stroke
        /// Gradient under text laid over photos (photos are always dark-scrimmed, in both themes)
        static let imageScrim = LinearGradient(
            stops: [
                .init(color: .black.opacity(0), location: 0),
                .init(color: .black.opacity(0.25), location: 0.35),
                .init(color: .black.opacity(0.7), location: 0.6),
                .init(color: .black.opacity(0.92), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

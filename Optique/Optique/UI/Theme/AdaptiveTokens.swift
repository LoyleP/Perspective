import SwiftUI

// Semantic color tokens. Black and white (plus greys) that follow the system light/dark theme.

extension AppColors {
    enum Adaptive {

        // MARK: - Backgrounds

        /// Page and feed background: white / zinc-950
        static let background = Color(light: "FFFFFF", dark: AppColors.Zinc.Hex.z950)
        static let feedBackground = background

        /// Cards and grouped rows
        static let cardSurface = Color(light: AppColors.Zinc.Hex.z100, dark: AppColors.Zinc.Hex.z900)
        static let detailSurface = cardSurface

        /// Chips, sheets, banners — one step above cards
        static let surfaceElevated = Color(light: AppColors.Zinc.Hex.z200, dark: AppColors.Zinc.Hex.z800)

        // MARK: - Dividers

        static let divider = Color(light: "1A09090B", dark: "1FFAFAFA")

        // MARK: - Text

        /// Titles and prominent text
        static let textPrimary = Color(light: AppColors.Zinc.Hex.z950, dark: AppColors.Zinc.Hex.z50)
        /// Card titles (same as primary: the text scale has three greys — primary, body, meta)
        static let textSecondary = textPrimary
        /// Body and paragraph text
        static let textBody = Color(light: AppColors.Zinc.Hex.z700, dark: AppColors.Zinc.Hex.z300)
        /// Captions and section headers (same as body)
        static let textTertiary = textBody
        /// Source names, counts, metadata
        static let textMeta = Color(light: AppColors.Zinc.Hex.z600, dark: AppColors.Zinc.Hex.z400)

        // MARK: - UI

        /// Loading skeletons and empty image areas
        static let placeholder = Color(light: AppColors.Zinc.Hex.z200, dark: AppColors.Zinc.Hex.z800)
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

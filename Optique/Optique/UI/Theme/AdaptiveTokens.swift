import SwiftUI

// Semantic color tokens. The app is permanently dark (`.preferredColorScheme(.dark)`
// at the root), so tokens are static values on the dark ink scale.

extension AppColors {
    enum Adaptive {

        // MARK: - Backgrounds

        /// Page and feed background
        static let feedBackground = Neutral.n950
        static let background = Neutral.n950

        /// Cards and grouped rows
        static let cardSurface = Neutral.n900
        static let detailSurface = Neutral.n900

        /// Sheets, menus, chips — one step above cards
        static let surfaceElevated = Neutral.n800

        // MARK: - Dividers

        static let divider = Color.white.opacity(0.08)

        // MARK: - Text

        /// Titles and prominent text
        static let textPrimary = Neutral.n50
        /// Card titles
        static let textSecondary = Neutral.n100
        /// Body and paragraph text
        static let textBody = Neutral.n200
        /// Captions and section headers
        static let textTertiary = Neutral.n300
        /// Source names, counts, metadata
        static let textMeta = Neutral.n400

        // MARK: - UI

        /// Loading skeletons and empty image areas
        static let placeholder = Neutral.n800
        /// Component borders
        static let stroke = Color.white.opacity(0.08)
        /// Gradient under text laid over photos
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

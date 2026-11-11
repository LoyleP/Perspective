import SwiftUI

/// Image that fills its frame, fades in, and shows a tinted placeholder
/// while loading or when there is no image. Size it from the outside, e.g.
/// `Color.clear.frame(...).overlay { RemoteImage(url:) }.clipped()`.
/// `maxPixel` caps the decoded size (default fits a full-width card on a 3x screen).
struct RemoteImage: View {
    let url: URL?
    var tint: Color? = nil
    var maxPixel: Int = 1000
    /// When set, a missing, loading or failed photo shows this topic's tile (gradient and icon) instead of a plain fill.
    var topic: StoryTopic? = nil
    /// Other photos of the same story, tried in order when `url` is too small. Used with `topic`.
    var alternates: [URL] = []
    /// Pushes the placeholder's icon down, for screens with controls over the top of the image.
    var iconInset: CGFloat = 0

    var body: some View {
        PipelineImage(url: url, maxPixel: maxPixel, alternates: alternates, sharpOnly: topic != nil) { image in
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if let topic {
            TopicPlaceholder(topic: topic, inset: iconInset)
        } else {
            neutral
        }
    }

    private var neutral: some View {
        LinearGradient(
            colors: [(tint ?? AppColors.Adaptive.surfaceElevated).opacity(0.45), AppColors.Adaptive.cardSurface],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// The look of a theme tile on the Discover page: the topic's gradient with its icon, large and faint, in the top right.
struct TopicPlaceholder: View {
    let topic: StoryTopic
    var inset: CGFloat = 0

    var body: some View {
        let colors = topic.tileColors
        GeometryReader { geo in
            let size = min(max(min(geo.size.width, geo.size.height) * 0.62, 28), 150)
            LinearGradient(colors: [Color(hex: colors.top), Color(hex: colors.bottom)], startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .topTrailing) {
                    LucideIcon(topic.lucideIcon, size: size)
                        .foregroundStyle(.white.opacity(0.3))
                        .rotationEffect(.degrees(8))
                        .offset(x: size * 0.18, y: inset - size * 0.12)
                }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

import SwiftUI

/// Image that fills its frame, fades in, and shows a tinted placeholder
/// while loading or when there is no image. Size it from the outside, e.g.
/// `Color.clear.frame(...).overlay { RemoteImage(url:) }.clipped()`.
/// `maxPixel` caps the decoded size (default fits a full-width card on a 3x screen).
struct RemoteImage: View {
    let url: URL?
    var tint: Color? = nil
    var maxPixel: Int = 1000

    var body: some View {
        PipelineImage(url: url, maxPixel: maxPixel) { image in
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [(tint ?? AppColors.Adaptive.surfaceElevated).opacity(0.45), AppColors.Adaptive.cardSurface],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

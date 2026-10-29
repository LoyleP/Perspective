import SwiftUI

/// AsyncImage that fills its frame, fades in, and shows a tinted placeholder
/// while loading or when there is no image. Size it from the outside, e.g.
/// `Color.clear.frame(...).overlay { RemoteImage(url:) }.clipped()`.
struct RemoteImage: View {
    let url: URL?
    var tint: Color? = nil

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
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

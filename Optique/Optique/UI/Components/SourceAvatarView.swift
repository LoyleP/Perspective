import SwiftUI

/// Circular source logo; falls back to the source's initial on its lean color.
struct SourceAvatarView: View {
    let source: Source
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            initialView
            if let url = source.logoURL.flatMap(URL.init) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill().background(.white)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppColors.stroke, lineWidth: 1))
        .accessibilityLabel(source.name)
    }

    private var initialView: some View {
        let lean = source.lean
        return ZStack {
            Circle().fill(lean?.spectrumColor ?? AppColors.Adaptive.surfaceElevated)
            Text(String(source.name.prefix(1)).uppercased())
                .font(.geist(size * 0.44, .medium, relativeTo: .caption))
                .foregroundStyle(lean?.tagTextColor ?? AppColors.Adaptive.textSecondary)
        }
    }
}

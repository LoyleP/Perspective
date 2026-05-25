import SwiftUI

struct SourceAvatarView: View {
    let source: Source
    var size: CGFloat = 18

    var body: some View {
        Group {
            if let s = source.logoURL, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        Color.clear.overlay(img.resizable().scaledToFill()).clipped()
                    } else {
                        initialView
                    }
                }
            } else {
                initialView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppColors.stroke, lineWidth: 1))
    }

    private var initialView: some View {
        let lean = source.lean
        return ZStack {
            Circle().fill(lean?.spectrumColor ?? AppColors.Adaptive.placeholder)
            Text(String(source.name.prefix(1)).uppercased())
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(lean?.tagTextColor ?? AppColors.Adaptive.textSecondary)
        }
    }
}

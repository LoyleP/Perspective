import SwiftUI

/// Animated highlight sweeping across placeholder shapes. Static when Reduce Motion is on.
struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    LinearGradient(
                        colors: [.clear, AppColors.Adaptive.textPrimary.opacity(0.08), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .visualEffect { [phase] effect, proxy in
                        effect.offset(x: proxy.size.width * phase)
                    }
                    .onAppear {
                        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                            phase = 1
                        }
                    }
                }
            }
            .mask(content)
    }
}

extension View {
    func shimmering() -> some View { modifier(Shimmer()) }
}

/// Stack of placeholder text lines; the last one is shorter.
struct SkeletonLines: View {
    var count: Int = 3
    var lineHeight: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: lineHeight / 2)
                    .fill(AppColors.Adaptive.placeholder)
                    .frame(height: lineHeight)
                    .frame(maxWidth: index == count - 1 ? 180 : .infinity, alignment: .leading)
            }
        }
        .shimmering()
        .accessibilityLabel("Chargement")
    }
}

#if DEBUG
#Preview("Skeleton") {
    VStack(alignment: .leading, spacing: 24) {
        SkeletonLines(count: 4)
        RoundedRectangle(cornerRadius: 20).fill(AppColors.Adaptive.placeholder).frame(height: 180).shimmering()
    }
    .padding()
    .background(AppColors.Adaptive.background)
}
#endif

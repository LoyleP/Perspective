import SwiftUI

/// Capsule buttons: `.optiquePrimary` (light fill, ink label) and
/// `.optiqueSecondary` (elevated surface, light label).
struct OptiqueButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appHeadline)
            .foregroundStyle(kind == .primary ? AppColors.Neutral.n950 : AppColors.Adaptive.textPrimary)
            .padding(.horizontal, AppSpacing.l)
            .frame(minHeight: 50)
            .background(
                kind == .primary ? AppColors.Neutral.n50 : AppColors.Adaptive.surfaceElevated,
                in: Capsule()
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == OptiqueButtonStyle {
    static var optiquePrimary: OptiqueButtonStyle { OptiqueButtonStyle(kind: .primary) }
    static var optiqueSecondary: OptiqueButtonStyle { OptiqueButtonStyle(kind: .secondary) }
}

#if DEBUG
#Preview("Buttons") {
    VStack(spacing: 12) {
        Button("Continuer") {}.buttonStyle(.optiquePrimary)
        Button("Plus tard") {}.buttonStyle(.optiqueSecondary)
    }
    .padding()
    .background(AppColors.Adaptive.background)
}
#endif

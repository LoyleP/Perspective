import SwiftUI

/// Full-width, 52 pt gray call to action (the law page's "Voir tout le parcours"). Put the label,
/// and an optional icon, in the button's content.
struct GrayCTAStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .typeStyle(.ui)
            .foregroundStyle(AppColors.Adaptive.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(light: AppColors.Zinc.Hex.z200, dark: AppColors.Zinc.Hex.z800), in: Capsule())
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == GrayCTAStyle {
    static var grayCTA: GrayCTAStyle { GrayCTAStyle() }
}

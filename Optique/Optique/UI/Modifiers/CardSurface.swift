import SwiftUI

struct CardSurface: ViewModifier {
    var fill: Color = AppColors.Adaptive.cardSurface
    var radius: CGFloat = AppRadius.ml

    func body(content: Content) -> some View {
        content
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(AppColors.stroke, lineWidth: 1))
    }
}

extension View {
    func cardSurface(
        fill: Color = AppColors.Adaptive.cardSurface,
        radius: CGFloat = AppRadius.ml
    ) -> some View {
        modifier(CardSurface(fill: fill, radius: radius))
    }
}

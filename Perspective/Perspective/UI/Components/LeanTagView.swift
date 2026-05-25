import SwiftUI

struct LeanTagView: View {
    let lean: PoliticalLean
    var style: Style = .capsule

    enum Style {
        case capsule
        case rounded
    }

    var body: some View {
        Text(style == .capsule ? lean.label : lean.shortLabel)
            .font(.appFootnote)
            .foregroundStyle(lean.tagTextColor)
            .padding(.horizontal, style == .capsule ? AppSpacing.st : AppSpacing.s)
            .padding(.vertical, style == .capsule ? AppSpacing.s : AppSpacing.xs)
            .background(lean.spectrumColor)
            .clipShape(shape)
            .overlay(shape.stroke(AppColors.stroke, lineWidth: 1))
    }

    private var shape: some Shape {
        RoundedRectangle(cornerRadius: style == .capsule ? .infinity : AppRadius.s)
    }
}

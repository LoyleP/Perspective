import SwiftUI

/// Soft paywall card shown on a story after the 5th story opened in a session.
/// Non-blocking: dismissible, and shown again on the next story while the gate is active.
struct PaywallBannerView: View {

    @Binding var isPresented: Bool
    var onUpgradeTapped: () -> Void = {}

    @Environment(SessionState.self) private var session

    var body: some View {
        HStack(spacing: AppSpacing.st) {
            Image(systemName: "sparkles")
                .font(.appHeadline)
                .foregroundStyle(AppColors.Brand.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Lisez sans limite")
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                Text("\(session.storiesOpened) sujets ouverts · Optique+")
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }

            Spacer(minLength: 0)

            Button("Voir", action: onUpgradeTapped)
                .font(.appFootnote.weight(.semibold))
                .foregroundStyle(AppColors.Neutral.n950)
                .padding(.horizontal, AppSpacing.m)
                .padding(.vertical, AppSpacing.s)
                .background(AppColors.Neutral.n50, in: Capsule())

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.appCaption1.weight(.semibold))
                    .foregroundStyle(AppColors.Adaptive.textTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Fermer")
        }
        .padding(.leading, AppSpacing.m)
        .padding(.trailing, AppSpacing.s)
        .padding(.vertical, AppSpacing.st)
        .background(AppColors.Adaptive.surfaceElevated, in: RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.xl).stroke(AppColors.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        .padding(.horizontal, AppSpacing.m)
        .padding(.bottom, AppSpacing.s)
    }
}

import SwiftUI

// Soft paywall bottom banner shown after the 5th story opened in a session.
// Non-blocking: dismissible with the X, reappears on next story open while gate is active.
struct PaywallBannerView: View {

    @Binding var isPresented: Bool
    var onUpgradeTapped: () -> Void = {}

    var body: some View {
        HStack(spacing: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Accès illimité avec Perspective+")
                    .font(.appTitle3)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)

                Text("Vous avez consulté 5 articles aujourd'hui.")
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }

            Spacer()

            Button(action: onUpgradeTapped) {
                Text("Voir")
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Adaptive.background)
                    .padding(.horizontal, AppSpacing.st)
                    .padding(.vertical, AppSpacing.s)
                    .background(AppColors.Adaptive.textPrimary)
                    .clipShape(Capsule())
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.appCaption1)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.Adaptive.textTertiary)
                    .padding(AppSpacing.s)
                    .background(AppColors.Adaptive.placeholder.opacity(0.4))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.m)
        .background(AppColors.Adaptive.detailSurface)
        .overlay(alignment: .top) {
            AppColors.Adaptive.divider.frame(height: 1)
        }
    }
}

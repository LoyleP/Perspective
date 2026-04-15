import SwiftUI

// Full-screen paywall sheet. UI only for MVP — no real purchase flow.
struct PaywallView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionState.self) private var session

    @State private var isAnnual = true

    private let monthlyPrice = "3,99 €/mois"
    private let annualPrice  = "29,99 €/an"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                        .padding(.bottom, AppSpacing.xl)

                    sectionHeader("Fonctionnalités")
                    featuresCard
                        .padding(.bottom, AppSpacing.l)

                    sectionHeader("Formule")
                    pricingSection
                        .padding(.bottom, AppSpacing.xl)

                    ctaButton
                        .padding(.bottom, AppSpacing.m)

                    legalSection
                        .padding(.bottom, AppSpacing.xxl)
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.top, AppSpacing.xl)
            }
            .background(AppColors.Adaptive.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AppColors.Adaptive.background, for: .navigationBar)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Perspective+")
                .font(.appLargeTitle)
                .foregroundStyle(AppColors.Adaptive.textPrimary)

            Text("Comprenez plus. Payez moins qu'un café.")
                .font(.appBody)
                .foregroundStyle(AppColors.Adaptive.textMeta)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Section header

    private func sectionHeader(_ label: String) -> some View {
        Text(label.uppercased())
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppColors.Adaptive.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, AppSpacing.xs)
    }

    // MARK: - Features

    private var featuresCard: some View {
        let items: [(String, String)] = [
            ("infinity",        "Accès illimité aux histoires"),
            ("chart.bar.fill",  "Mon spectre de lecture personnel"),
            ("bell.fill",       "Alertes en temps réel"),
            ("bookmark.fill",   "Marque-pages et historique"),
        ]
        return VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    AppColors.Adaptive.divider.frame(height: 1)
                }
                featureRow(icon: item.0, label: item.1)
            }
        }
        .background(AppColors.Adaptive.detailSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
    }

    private func featureRow(icon: String, label: String) -> some View {
        HStack(spacing: AppSpacing.m) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.Adaptive.textTertiary)
                .frame(width: 20)
            Text(label)
                .font(.appFootnote)
                .foregroundStyle(AppColors.Adaptive.textSecondary)
            Spacer()
        }
        .padding(AppSpacing.m)
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: AppSpacing.s) {
            pricingCard(annual: true,  price: annualPrice,  badge: "Économisez 37%")
            pricingCard(annual: false, price: monthlyPrice, badge: nil)
        }
    }

    private func pricingCard(annual: Bool, price: String, badge: String?) -> some View {
        let selected = isAnnual == annual
        return Button { isAnnual = annual } label: {
            HStack(spacing: AppSpacing.m) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(annual ? "Annuel" : "Mensuel")
                        .font(.appTitle3)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                    Text(price)
                        .font(.appFootnote)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }

                Spacer()

                if let badge {
                    Text(badge)
                        .font(.appCaption1)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .padding(.horizontal, AppSpacing.s)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColors.Adaptive.placeholder.opacity(0.4))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppColors.stroke, lineWidth: 1))
                }

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.appTitle3)
                    .foregroundStyle(selected ? AppColors.Adaptive.textPrimary : AppColors.Adaptive.textMeta)
            }
            .padding(AppSpacing.m)
            .background(AppColors.Adaptive.detailSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.ml)
                    .stroke(selected ? AppColors.Adaptive.textSecondary : AppColors.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            session.isPremium = true
            dismiss()
        } label: {
            Text("Commencer avec Perspective+")
                .font(.appHeadline)
                .foregroundStyle(AppColors.Adaptive.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.m)
                .background(AppColors.Adaptive.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: AppSpacing.s) {
            Text("Renouvellement automatique. Annulable à tout moment depuis les Réglages.")
                .font(.appCaption1)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Button("Restaurer les achats") {}
                .font(.appCaption1)
                .foregroundStyle(AppColors.Adaptive.textTertiary)
        }
    }
}

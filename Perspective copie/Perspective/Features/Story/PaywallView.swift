import SwiftUI
import StoreKit

// Full-screen paywall sheet with real StoreKit 2 integration
struct PaywallView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionState.self) private var session

    @State private var isAnnual = true
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var storeManager: StoreManager {
        session.storeManager
    }

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
            .alert("Erreur", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
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
            if storeManager.isLoading {
                ProgressView()
                    .padding(.vertical, AppSpacing.m)
            } else if let annual = storeManager.annualProduct, let monthly = storeManager.monthlyProduct {
                // Real products loaded from StoreKit
                pricingCard(
                    annual: true,
                    price: annual.displayPrice + "/an",
                    badge: "Économisez 37%",
                    product: annual
                )
                pricingCard(
                    annual: false,
                    price: monthly.displayPrice + "/mois",
                    badge: nil,
                    product: monthly
                )
            } else {
                // Fallback: Show mock products if StoreKit fails (not configured yet)
                mockPricingCard(annual: true, price: "0,00 €/an", badge: "Économisez 37%")
                mockPricingCard(annual: false, price: "0,00 €/mois", badge: nil)
            }
        }
    }

    private func pricingCard(annual: Bool, price: String, badge: String?, product: Product) -> some View {
        let selected = isAnnual == annual
        return Button { isAnnual = annual } label: {
            pricingCardContent(annual: annual, price: price, badge: badge, selected: selected)
        }
        .buttonStyle(.plain)
    }

    private func mockPricingCard(annual: Bool, price: String, badge: String?) -> some View {
        let selected = isAnnual == annual
        return Button { isAnnual = annual } label: {
            pricingCardContent(annual: annual, price: price, badge: badge, selected: selected)
        }
        .buttonStyle(.plain)
    }

    private func pricingCardContent(annual: Bool, price: String, badge: String?, selected: Bool) -> some View {
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

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            Task { await handlePurchase() }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(AppColors.Adaptive.background)
                } else {
                    Text("Commencer avec Perspective+")
                        .font(.appHeadline)
                }
            }
            .foregroundStyle(AppColors.Adaptive.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.m)
            .background(AppColors.Adaptive.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
        }
        .disabled(isPurchasing)
    }

    private func handlePurchase() async {
        isPurchasing = true

        // If real products loaded, use StoreKit
        if let product = isAnnual ? storeManager.annualProduct : storeManager.monthlyProduct {
            do {
                try await storeManager.purchase(product)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        } else {
            // Fallback: Mock purchase flow (for testing when products not configured)
            // In production, this would show "Configure products in App Store Connect"
            // For MVP testing with €0.00 pricing, just unlock premium
            #if DEBUG
            UserDefaults.standard.set(true, forKey: "devIsPremium")
            dismiss()
            #else
            errorMessage = "Les abonnements ne sont pas encore configurés. Contactez le support."
            showError = true
            #endif
        }

        isPurchasing = false
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: AppSpacing.s) {
            Text("Renouvellement automatique. Annulable à tout moment depuis les Réglages.")
                .font(.appCaption1)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Button("Restaurer les achats") {
                Task {
                    await storeManager.restorePurchases()
                }
            }
            .font(.appCaption1)
            .foregroundStyle(AppColors.Adaptive.textTertiary)
        }
    }
}

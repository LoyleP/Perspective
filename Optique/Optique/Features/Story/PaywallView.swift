import SwiftUI
import StoreKit

/// Optique+ subscription sheet (StoreKit 2): what you get, two plans, then purchase.
struct PaywallView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionState.self) private var session

    @State private var plan: Plan = .annual
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    enum Plan {
        case annual
        case monthly
    }

    private var storeManager: StoreManager { session.storeManager }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                hero
                benefits
                plans
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.top, AppSpacing.xxl)
            .padding(.bottom, AppSpacing.l)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) { purchaseBar }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(AppColors.Adaptive.surfaceElevated, in: Circle())
            }
            .accessibilityLabel("Fermer")
            .padding(AppSpacing.m)
        }
        .alert("Erreur", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack(spacing: 3) {
                ForEach(PoliticalLean.allCases) { lean in
                    Capsule().fill(lean.spectrumColor).frame(height: 8)
                }
            }
            .frame(width: 140)
            .accessibilityHidden(true)
            Text("Optique+")
                .overlineStyle(AppColors.Brand.accent)
            Text("Lisez sans limite")
                .font(.appDisplay)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Et soutenez une information qui montre tous les points de vue.")
                .font(.appBody)
                .foregroundStyle(AppColors.Adaptive.textBody)
        }
    }

    // MARK: - Benefits

    private var benefits: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            benefit("infinity", "Sujets illimités", "Plus de limite de 5 sujets par session.")
            benefit("heart", "Un projet indépendant", "Financé par ses lecteurs, sans groupe de presse derrière.")
            benefit("eye.slash", "Sans publicité ni pistage", "Ce que vous lisez reste sur votre iPhone.")
        }
    }

    private func benefit(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.m) {
            Image(systemName: icon)
                .font(.appHeadline)
                .foregroundStyle(AppColors.Brand.accent)
                .frame(width: 36, height: 36)
                .background(AppColors.Brand.accentSoft, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                Text(detail)
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Plans

    @ViewBuilder
    private var plans: some View {
        if storeManager.isLoading && storeManager.products.isEmpty {
            ProgressView().frame(maxWidth: .infinity)
        } else {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: AppSpacing.st))
                : AnyLayout(HStackLayout(spacing: AppSpacing.st))
            layout {
                planCard(
                    .annual,
                    title: "Annuel",
                    price: storeManager.annualProduct?.displayPrice ?? "—",
                    detail: annualPerMonth.map { "soit \($0)/mois" } ?? "par an",
                    badge: annualSavings.map { "−\($0) %" }
                )
                planCard(
                    .monthly,
                    title: "Mensuel",
                    price: storeManager.monthlyProduct?.displayPrice ?? "—",
                    detail: "par mois",
                    badge: nil
                )
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func planCard(_ option: Plan, title: String, price: String, detail: String, badge: String?) -> some View {
        let selected = plan == option
        return Button {
            plan = option
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text(title)
                        .font(.appHeadline)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? AppColors.Brand.accent : AppColors.Adaptive.textMeta)
                }
                Text(price)
                    .font(.appTitle2)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(detail)
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                if let badge {
                    Text(badge)
                        .font(.appCaption1)
                        .foregroundStyle(AppColors.Neutral.n950)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.Brand.accent, in: Capsule())
                        .padding(.top, AppSpacing.xs)
                }
            }
            .padding(AppSpacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                selected ? AppColors.Brand.accentSoft : AppColors.Adaptive.cardSurface,
                in: RoundedRectangle(cornerRadius: AppRadius.l)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.l)
                    .stroke(selected ? AppColors.Brand.accent : AppColors.stroke, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(CardPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Annual price spread over 12 months, in the product's currency.
    private var annualPerMonth: String? {
        guard let annual = storeManager.annualProduct, annual.price > 0 else { return nil }
        return (annual.price / 12).formatted(annual.priceFormatStyle)
    }

    /// Percent saved by paying yearly, when both prices are known.
    private var annualSavings: Int? {
        guard let annual = storeManager.annualProduct?.price,
              let monthly = storeManager.monthlyProduct?.price,
              monthly > 0 else { return nil }
        let ratio = NSDecimalNumber(decimal: annual / (monthly * 12)).doubleValue
        let savings = Int((1 - ratio) * 100)
        return savings > 0 ? savings : nil
    }

    // MARK: - Purchase

    private var purchaseBar: some View {
        VStack(spacing: AppSpacing.s) {
            Button {
                Task { await handlePurchase() }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView().tint(AppColors.Neutral.n950)
                    } else {
                        Text(plan == .annual ? "S'abonner à l'année" : "S'abonner au mois")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.optiquePrimary)
            .disabled(isPurchasing)

            Text("Renouvellement automatique, annulable à tout moment dans les Réglages de l'iPhone.")
                .font(.appCaption2)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .multilineTextAlignment(.center)

            HStack(spacing: AppSpacing.m) {
                Button("Restaurer") {
                    Task { await storeManager.restorePurchases() }
                }
                if let url = URL(string: "https://loylep.github.io/Perspective/legal/terms-of-service") {
                    Link("Conditions", destination: url)
                }
                if let url = URL(string: "https://loylep.github.io/Perspective/legal/privacy-policy") {
                    Link("Confidentialité", destination: url)
                }
            }
            .font(.appCaption1)
            .foregroundStyle(AppColors.Adaptive.textTertiary)
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.top, AppSpacing.st)
        .padding(.bottom, AppSpacing.s)
        .background(AppColors.Adaptive.background)
    }

    private func handlePurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        if let product = plan == .annual ? storeManager.annualProduct : storeManager.monthlyProduct {
            do {
                try await storeManager.purchase(product)
                if storeManager.isPremium { dismiss() }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        } else {
            // Products not available (StoreKit configuration missing).
            #if DEBUG
            UserDefaults.standard.set(true, forKey: "devIsPremium")
            dismiss()
            #else
            errorMessage = "Les abonnements sont indisponibles pour le moment. Réessayez plus tard."
            showError = true
            #endif
        }
    }
}

#if DEBUG
#Preview("PaywallView") {
    PaywallView()
        .environment(SessionState())
}
#endif

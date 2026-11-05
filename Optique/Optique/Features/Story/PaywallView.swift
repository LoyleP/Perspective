import SwiftUI
import StoreKit

/// Optique+ subscription sheet (StoreKit 2). Built the way the best news and reading paywalls are
/// (SCMP, Medium, Locket, Kitchen Stories): what you get in three lines, two plans with the yearly one
/// as the default, a single button that names the price, and the renewal terms right under it.
struct PaywallView: View {

    /// Closes the paywall when it isn't shown in a sheet (the debug launcher shows it as the root).
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var systemDismiss
    @Environment(SessionState.self) private var session
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var plan: Plan = .annual
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    enum Plan {
        case annual
        case monthly
    }

    private var storeManager: StoreManager { session.storeManager }

    private func dismiss() {
        if let onClose { onClose() } else { systemDismiss() }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                hero
                // The prices come straight after the pitch, so they are on screen without scrolling.
                plans.staggerIn(2)
                benefits.staggerIn(3)
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.top, 64)
            .padding(.bottom, AppSpacing.l)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) { purchaseBar }
        .background(alignment: .top) { glow }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .overlay(alignment: .topTrailing) { closeButton }
        .sensoryFeedback(.selection, trigger: plan)
        .alert("Erreur", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Hero

    /// The five positions of the spectrum as blurred colour blobs behind the title, drifting slowly
    /// and out of step with each other (still when Reduce Motion is on).
    private var glow: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack {
                    ForEach(Array(PoliticalLean.allCases.enumerated()), id: \.offset) { index, lean in
                        let phase = Double(index) * 1.3
                        Circle()
                            .fill(lean.spectrumColor)
                            .frame(width: 200, height: 200)
                            .position(
                                x: geo.size.width * (0.08 + 0.21 * Double(index)) + CGFloat(sin(t * 0.32 + phase)) * 60,
                                y: 30 + CGFloat(cos(t * 0.26 + phase * 1.7)) * 46
                            )
                    }
                }
                .blur(radius: 64)
            }
        }
        .frame(height: 320)
        .opacity(0.34)
        .mask(alignment: .top) {
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack(spacing: AppSpacing.st) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(AppColors.Brand.onInk)
                    .frame(width: 44, height: 44)
                    .background(AppColors.Brand.accent, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .accessibilityHidden(true)
                Text("Optique+")
                    .font(.geist(.heading, .medium))
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
            }
            .staggerIn(0)

            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("Tous les angles,\nsans limite")
                    .font(.appTitle)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Lisez autant de sujets que vous voulez, et soutenez une information qui montre tous les points de vue.")
                    .font(.appBody)
                    .foregroundStyle(AppColors.Adaptive.textBody)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .staggerIn(1)
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            NavIcon("xmark")
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .frame(width: 44, height: 44)
                .background(AppColors.Adaptive.surfaceElevated, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fermer")
        .padding(AppSpacing.m)
    }

    // MARK: - Benefits

    private var benefits: some View {
        VStack(spacing: 0) {
            benefit("book-open", "Sujets illimités", "Fini la limite de 5 sujets par session.")
            Divider().overlay(AppColors.Adaptive.divider).padding(.leading, 68)
            benefit("heart", "Un projet indépendant", "Financé par ses lecteurs, sans groupe de presse derrière.")
            Divider().overlay(AppColors.Adaptive.divider).padding(.leading, 68)
            benefit("eye-slash", "Sans publicité ni pistage", "Ce que vous lisez reste sur votre iPhone.")
        }
        .frame(maxWidth: .infinity)
        .background(AppColors.Adaptive.cardSurface, in: RoundedRectangle(cornerRadius: AppRadius.xl))
    }

    private func benefit(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.st) {
            HeroIcon(icon, size: 22)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .frame(width: 40, height: 40)
                .background(AppColors.Adaptive.surfaceElevated, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appBodyStrong)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                Text(detail)
                    .font(.appBody)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.m)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Plans

    @ViewBuilder
    private var plans: some View {
        if storeManager.isLoading && storeManager.products.isEmpty {
            ProgressView().frame(maxWidth: .infinity, minHeight: 140)
        } else {
            VStack(spacing: AppSpacing.st) {
                planRow(
                    .annual,
                    title: "Annuel",
                    price: storeManager.annualProduct?.displayPrice ?? "—",
                    unit: "/ an",
                    detail: annualPerMonth.map { "soit \($0) par mois" } ?? "facturé une fois par an",
                    strike: annualFullPrice,
                    badge: annualSavings.map { "−\($0) %" }
                )
                planRow(
                    .monthly,
                    title: "Mensuel",
                    price: storeManager.monthlyProduct?.displayPrice ?? "—",
                    unit: "/ mois",
                    detail: "sans engagement",
                    strike: nil,
                    badge: nil
                )
            }
        }
    }

    private func planRow(_ option: Plan, title: String, price: String, unit: String, detail: String,
                         strike: String?, badge: String?) -> some View {
        let selected = plan == option
        return Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.2)) { plan = option }
        } label: {
            HStack(spacing: AppSpacing.st) {
                ZStack {
                    Circle().stroke(selected ? AppColors.Brand.accent : AppColors.Adaptive.textMeta, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    Circle().fill(AppColors.Brand.accent)
                        .frame(width: 14, height: 14)
                        .scaleEffect(selected ? 1 : 0.01)
                        .opacity(selected ? 1 : 0)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: AppSpacing.s) {
                        Text(title)
                            .font(.geist(.body, .medium))
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                        if let badge {
                            Text(badge)
                                .font(.appCaption)
                                .foregroundStyle(AppColors.Brand.onInk)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(AppColors.Brand.accent, in: Capsule())
                        }
                    }
                    Text(detail)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }

                Spacer(minLength: AppSpacing.s)

                VStack(alignment: .trailing, spacing: 2) {
                    if let strike {
                        Text(strike)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                            .strikethrough()
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(price)
                            .font(.appHeading)
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text(unit)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                    }
                }
            }
            .padding(AppSpacing.m)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(
                selected ? AppColors.Brand.accentSoft : AppColors.Adaptive.cardSurface,
                in: RoundedRectangle(cornerRadius: AppRadius.xl)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xl)
                    .stroke(AppColors.Brand.accent, lineWidth: 2)
                    .opacity(selected ? 1 : 0)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        }
        .buttonStyle(CardPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// Annual price spread over 12 months, in the product's currency.
    private var annualPerMonth: String? {
        guard let annual = storeManager.annualProduct, annual.price > 0 else { return nil }
        return (annual.price / 12).formatted(annual.priceFormatStyle)
    }

    /// What twelve monthly payments would cost, crossed out next to the yearly price.
    private var annualFullPrice: String? {
        guard let monthly = storeManager.monthlyProduct, monthly.price > 0, annualSavings != nil else { return nil }
        return (monthly.price * 12).formatted(monthly.priceFormatStyle)
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

    private var selectedProduct: Product? {
        plan == .annual ? storeManager.annualProduct : storeManager.monthlyProduct
    }

    /// The exact sentence the store requires, with the real price of the chosen plan.
    private var terms: String {
        let price = selectedProduct?.displayPrice
        let period = plan == .annual ? "par an" : "par mois"
        let head = price.map { "\($0) \(period), renouvelé automatiquement." } ?? "Renouvelé automatiquement."
        return head + " Annulable à tout moment dans les Réglages de l'iPhone."
    }

    private var purchaseBar: some View {
        VStack(spacing: AppSpacing.s) {
            Button {
                Task { await handlePurchase() }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView().tint(AppColors.Brand.onInk)
                    } else {
                        Text(plan == .annual ? "S'abonner à l'année" : "S'abonner au mois")
                            .contentTransition(.interpolate)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.optiquePrimary)
            .disabled(isPurchasing)
            .animation(.spring(duration: 0.35, bounce: 0.1), value: plan)

            Text(terms)
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.interpolate)
                .animation(.spring(duration: 0.35, bounce: 0.1), value: plan)

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
            .font(.appCaption)
            .foregroundStyle(AppColors.Adaptive.textTertiary)
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.top, AppSpacing.st)
        .padding(.bottom, AppSpacing.s)
        .background(
            AppColors.Adaptive.background
                .shadow(color: AppColors.Adaptive.background, radius: 14, y: -8)
        )
    }

    private func handlePurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        if let product = selectedProduct {
            do {
                try await storeManager.purchase(product)
                if storeManager.isPremium {
                    Haptics.success()
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        } else {
            // Products not available (StoreKit configuration missing).
            #if DEBUG
            session.testPremium = true
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

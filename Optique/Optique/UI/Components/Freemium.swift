import SwiftUI

// The pieces of the free / Optique+ experience, each used in one place:
// - `ReadingMeter`: the five free topics as a row of segments (plan card, limit screen);
// - `FreeTopicToast`: a quiet heads-up when the free allowance is nearly used;
// - `ReadingLimitGate`: the moment a free reader hits the limit, shown over a blurred preview;
// - `PlanCard`: which plan you are on, in the profile.

// MARK: - Meter

/// One segment per free topic, filled left to right as topics are opened. The newest one pops in.
struct ReadingMeter: View {
    let used: Int
    let total: Int
    var height: CGFloat = 6
    /// Animates the segments filling one after the other when first shown.
    var animatesIn = false

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(AppColors.Adaptive.surfaceElevated)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.Brand.accent)
                            .scaleEffect(x: index < used && (shown || !animatesIn || reduceMotion) ? 1 : 0.001, anchor: .leading)
                            .animation(
                                .spring(duration: 0.5, bounce: 0.15).delay(animatesIn && !reduceMotion ? 0.25 + Double(index) * 0.09 : 0),
                                value: shown
                            )
                    }
                    .frame(height: height)
            }
        }
        .onAppear { shown = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(min(used, total)) sujets gratuits utilisés sur \(total)")
    }
}

// MARK: - Toast

/// "Dernier sujet gratuit": shown briefly over a story when the free allowance is nearly gone.
/// Tapping it opens the paywall.
struct FreeTopicToast: View {
    let remaining: Int
    let action: () -> Void

    private var text: String {
        remaining == 0 ? "Dernier sujet gratuit du jour" : "Plus que \(remaining) sujet\(remaining > 1 ? "s" : "") gratuit\(remaining > 1 ? "s" : "")"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.s) {
                HeroIcon("sparkles", size: 16)
                Text(text)
                    .font(.appCaption)
                HeroIcon("chevron-right", size: 12)
                    .opacity(0.6)
            }
            .foregroundStyle(AppColors.Adaptive.textPrimary)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(AppColors.Adaptive.surfaceElevated, in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        }
        .buttonStyle(CardPressStyle())
        .accessibilityLabel("\(text). Découvrir Optique+")
    }
}

// MARK: - Limit gate

/// What a free reader sees on the topic past their allowance: the headline and standfirst stay
/// readable, the rest sits blurred behind this card, with one clear way forward.
struct ReadingLimitGate: View {
    let used: Int
    let total: Int
    let onUpgrade: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            ReadingMeter(used: used, total: total, animatesIn: true)
                .staggerIn(0)

            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("Vous avez lu vos \(total) sujets gratuits")
                    .font(.appHeading)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Optique+ lève la limite et soutient une information qui montre tous les points de vue. Vos sujets gratuits reviennent demain.")
                    .font(.appBody)
                    .foregroundStyle(AppColors.Adaptive.textBody)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .staggerIn(1)

            VStack(spacing: AppSpacing.xs) {
                Button(action: onUpgrade) {
                    Text("Découvrir Optique+").frame(maxWidth: .infinity)
                }
                .buttonStyle(.optiquePrimary)

                Button(action: onBack) {
                    Text("Revenir au fil")
                        .font(.appBodyStrong)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .staggerIn(2)
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.Adaptive.cardSurface, in: RoundedRectangle(cornerRadius: AppRadius.xl))
        .shadow(color: .black.opacity(0.3), radius: 24, y: 10)
        .padding(.horizontal, AppSpacing.m)
    }
}

// MARK: - Plan card

/// Which plan the reader is on, in the profile. Free: the allowance used so far and the way to
/// Optique+. Optique+: a thank-you, and the way to manage the subscription when it is a real one.
struct PlanCard: View {
    let isPremium: Bool
    let used: Int
    let total: Int
    let onUpgrade: () -> Void
    var onManage: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            if isPremium { premium } else { free }
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.Adaptive.cardSurface, in: RoundedRectangle(cornerRadius: AppRadius.xl))
        .accessibilityElement(children: .contain)
    }

    private var free: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Text("Formule gratuite")
                    .font(.appBodyStrong)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                Spacer()
                Text("\(min(used, total)) / \(total) sujets")
                    .font(.appCaption)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }
            ReadingMeter(used: used, total: total)
            Text(used >= total
                 ? "Vous avez utilisé vos sujets gratuits. Ils reviennent demain."
                 : "\(total - used) sujet\(total - used > 1 ? "s" : "") gratuit\(total - used > 1 ? "s" : "") restant\(total - used > 1 ? "s" : "") aujourd'hui.")
                .font(.appBody)
                .foregroundStyle(AppColors.Adaptive.textBody)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onUpgrade) {
                HStack(spacing: AppSpacing.s) {
                    HeroIcon("sparkles", size: 16)
                    Text("Passer à Optique+")
                }
            }
            .buttonStyle(.grayCTA)
        }
    }

    private var premium: some View {
        HStack(alignment: .top, spacing: AppSpacing.st) {
            HeroIcon("check-badge", size: 28)
                .foregroundStyle(AppColors.Brand.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Optique+")
                    .font(.appBodyStrong)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                Text("Sujets illimités, sans publicité ni pistage. Merci de soutenir une information indépendante.")
                    .font(.appBody)
                    .foregroundStyle(AppColors.Adaptive.textBody)
                    .fixedSize(horizontal: false, vertical: true)
                if let onManage {
                    Button("Gérer l'abonnement", action: onManage)
                        .font(.appBodyStrong)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .padding(.top, AppSpacing.xs)
                }
            }
        }
    }
}

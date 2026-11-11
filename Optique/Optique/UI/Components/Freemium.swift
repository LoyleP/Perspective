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
    /// For a dark surface: white fill on a faint white track.
    var onDark = false

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(onDark ? Color.white.opacity(0.2) : AppColors.Adaptive.surfaceElevated)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(onDark ? Color.white : AppColors.Brand.accent)
                            .scaleEffect(x: index < used && (shown || !animatesIn || reduceMotion) ? 1 : 0.001, anchor: .leading)
                            .animation(
                                .data.delay(animatesIn ? Motion.delay(0.25) + Motion.stagger(index, step: 0.08) : 0),
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
                LucideIcon("sparkles", size: 20)
                Text(text)
                    .typeStyle(.standfirst)
                LucideIcon("chevron-right", size: 14)
                    .opacity(0.6)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(Color.black, in: Capsule())
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
            ReadingMeter(used: used, total: total, animatesIn: true, onDark: true)
                .staggerIn(0)

            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("Vous avez lu vos \(total) sujets gratuits")
                    .typeStyle(.section)
                    .foregroundStyle(Color.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                FreeTopicsCountdown()
            }
            .staggerIn(1)

            VStack(spacing: AppSpacing.xs) {
                Button(action: onUpgrade) {
                    Text("Découvrir Optique+")
                        .typeStyle(.ui)
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white, in: Capsule())
                }
                .buttonStyle(CardPressStyle())

                Button(action: onBack) {
                    Text("Revenir au fil")
                        .typeStyle(.ui)
                        .foregroundStyle(Color.white.opacity(0.6))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .staggerIn(2)
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "0A0A0A"), in: RoundedRectangle(cornerRadius: AppRadius.xl))
        .shadow(color: .black.opacity(0.3), radius: 24, y: 10)
        .padding(.horizontal, AppSpacing.m)
    }
}

/// Time left until the free topics come back (they start again at local midnight), ticking every second.
private struct FreeTopicsCountdown: View {
    private static func remaining(at date: Date) -> Int {
        let midnight = Calendar.current.startOfDay(for: date).addingTimeInterval(24 * 3600)
        return max(Int(midnight.timeIntervalSince(date).rounded(.up)), 0)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let total = Self.remaining(at: context.date)
            let (h, m, s) = (total / 3600, total % 3600 / 60, total % 60)
            VStack(alignment: .leading, spacing: 2) {
                Text("Vos sujets gratuits reviennent dans")
                    .typeStyle(.body)
                    .foregroundStyle(Color.white.opacity(0.7))
                Text(String(format: "%02d:%02d:%02d", h, m, s))
                    .typeStyle(.screenTitle)
                    .monospacedDigit()
                    .foregroundStyle(Color.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Vos sujets gratuits reviennent dans \(h) heures \(m) minutes")
        }
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
    /// Dark card with a white call to action, used at the top of Réglages.
    var dark = false

    private var primary: Color { dark ? .white : AppColors.Adaptive.textPrimary }
    private var secondary: Color { dark ? Color.white.opacity(0.7) : AppColors.Adaptive.textBody }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            if isPremium { premium } else { free }
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(dark ? Color(light: "0A0A0A", dark: "1F1F22") : AppColors.Adaptive.cardSurface, in: RoundedRectangle(cornerRadius: AppRadius.xl))
        .accessibilityElement(children: .contain)
    }

    private var free: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Text("Formule gratuite")
                    .typeStyle(.ui)
                    .foregroundStyle(primary)
                Spacer()
                Text("\(min(used, total)) / \(total) sujets")
                    .typeStyle(.meta)
                    .monospacedDigit()
                    .foregroundStyle(dark ? Color.white.opacity(0.6) : AppColors.Adaptive.textMeta)
            }
            ReadingMeter(used: used, total: total, onDark: dark)
            Text(used >= total
                 ? "Vous avez utilisé vos sujets gratuits. Ils reviennent demain."
                 : "\(total - used) sujet\(total - used > 1 ? "s" : "") gratuit\(total - used > 1 ? "s" : "") restant\(total - used > 1 ? "s" : "") aujourd'hui.")
                .typeStyle(.body)
                .foregroundStyle(secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onUpgrade) {
                HStack(spacing: AppSpacing.s) {
                    LucideIcon("sparkles", size: 16)
                    Text("Passer à Optique+")
                }
                .typeStyle(.ui)
                .foregroundStyle(dark ? Color.black : primary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(dark ? Color.white : Color.clear, in: Capsule())
            }
            .buttonStyle(.plain)
            .modifier(CTAFallback(enabled: !dark))
        }
    }

    private var premium: some View {
        HStack(alignment: .top, spacing: AppSpacing.st) {
            LucideIcon("badge-check", size: 28)
                .foregroundStyle(dark ? Color.white : AppColors.Brand.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Optique+")
                    .typeStyle(.ui)
                    .foregroundStyle(primary)
                Text("Sujets illimités, sans publicité ni pistage. Merci de soutenir une information indépendante.")
                    .typeStyle(.body)
                    .foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let onManage {
                    Button("Gérer l'abonnement", action: onManage)
                        .typeStyle(.ui)
                        .foregroundStyle(primary)
                        .padding(.top, AppSpacing.xs)
                }
            }
        }
    }
}


/// Keeps the grey call-to-action look for the light plan card.
private struct CTAFallback: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled { content.buttonStyle(.grayCTA) } else { content }
    }
}

import SwiftUI

// Height reserved for the bottom overlay (indicator + button + bottom padding).
private let overlayHeight: CGFloat = 160

struct OnboardingView: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                OnboardingPage1().tag(0)
                OnboardingPage2().tag(1)
                OnboardingPage3().tag(2)
                OnboardingPage4().tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack(spacing: AppSpacing.l) {
                PageIndicator(count: 4, current: currentPage)

                Button {
                    if currentPage < 3 {
                        withAnimation { currentPage += 1 }
                    } else {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text(currentPage < 3 ? "Continuer" : "Commencer")
                        .font(.appHeadline)
                        .foregroundStyle(AppColors.Adaptive.feedBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.m)
                        .background(AppColors.Adaptive.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
                }
                .padding(.horizontal, AppSpacing.m)
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.Adaptive.feedBackground.ignoresSafeArea())
    }
}

// MARK: - Page 1

private struct OnboardingPage1: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            SpectrumBar()
                .padding(.horizontal, AppSpacing.m)
                .padding(.bottom, AppSpacing.xxl)

            pageText(
                title: "L'info vue\nde partout",
                body: "Perspective regroupe les mêmes événements couverts par 23 médias français, de l'extrême-gauche à l'extrême-droite."
            )
        }
        .padding(.bottom, overlayHeight)
    }
}

// MARK: - Page 2

private struct OnboardingPage2: View {

    private let mockRows: [(title: String, leanLabel: String, leanColor: Color, textColor: Color)] = [
        ("Selon Le Monde, la réforme favorise les cadres supérieurs", "Gauche", AppColors.Spectrum.gauche, .white),
        ("Le projet de loi passe en commission sans amendement majeur", "Centre", AppColors.Neutral.n200, AppColors.Neutral.n800),
        ("Pour CNews, cette réforme est une nécessité économique urgente", "E. droite", AppColors.Spectrum.eDroite, .white),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(spacing: AppSpacing.s) {
                ForEach(Array(mockRows.enumerated()), id: \.offset) { _, row in
                    MockStoryRow(
                        title: row.title,
                        leanLabel: row.leanLabel,
                        leanColor: row.leanColor,
                        textColor: row.textColor
                    )
                }
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.bottom, AppSpacing.xxl)

            pageText(
                title: "Même sujet,\nangles différents",
                body: "Chaque histoire montre comment chaque bord du spectre l'a traitée, quels angles ont été choisis, et quels médias ont préféré l'ignorer."
            )
        }
        .padding(.bottom, overlayHeight)
    }
}

// MARK: - Page 3

private struct OnboardingPage3: View {

    private let sources: [(name: String, lean: String, leanColor: Color, textColor: Color)] = [
        ("Le Monde",    "Gauche",    AppColors.Spectrum.gauche,       .white),
        ("France Info", "Centre",    AppColors.Neutral.n200,          AppColors.Neutral.n800),
        ("Le Figaro",   "C. droite", AppColors.Spectrum.centreDroite, .white),
        ("CNews",       "E. droite", AppColors.Spectrum.eDroite,      .white),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(spacing: AppSpacing.s) {
                ForEach(Array(sources.enumerated()), id: \.offset) { _, src in
                    HStack(spacing: AppSpacing.m) {
                        ZStack {
                            Circle().fill(AppColors.Adaptive.placeholder)
                            Text(String(src.name.prefix(1)))
                                .font(.appFootnote)
                                .foregroundStyle(AppColors.Adaptive.textSecondary)
                        }
                        .frame(width: 28, height: 28)

                        Text(src.name)
                            .font(.appBody)
                            .foregroundStyle(AppColors.Adaptive.textSecondary)

                        Spacer()

                        Text(src.lean)
                            .font(.appFootnote)
                            .foregroundStyle(src.textColor)
                            .padding(.horizontal, AppSpacing.s)
                            .padding(.vertical, AppSpacing.xs)
                            .background(src.leanColor)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.s))
                    }
                    .padding(.horizontal, AppSpacing.m)
                    .padding(.vertical, AppSpacing.st)
                    .background(AppColors.Adaptive.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
                }
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.bottom, AppSpacing.xxl)

            pageText(
                title: "Des sources,\npas des opinions",
                body: "Le positionnement de chaque média est basé sur des études académiques indépendantes. Perspective n'écrit rien, n'édite rien."
            )
        }
        .padding(.bottom, overlayHeight)
    }
}

// MARK: - Page 4

private struct OnboardingPage4: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            pageText(
                title: "Prêt à lire\nautrement ?",
                body: "Gratuit pour commencer. Aucun compte requis."
            )
        }
        .padding(.bottom, overlayHeight)
    }
}

// MARK: - Shared text block

private func pageText(title: String, body: String) -> some View {
    VStack(alignment: .leading, spacing: AppSpacing.m) {
        Text(title)
            .font(.appLargeTitle)
            .foregroundStyle(AppColors.Adaptive.textPrimary)
            .fixedSize(horizontal: false, vertical: true)

        Text(body)
            .font(.appBody)
            .foregroundStyle(AppColors.Adaptive.textBody)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, AppSpacing.m)
}

// MARK: - Spectrum bar

private struct SpectrumBar: View {

    private let segments: [(color: Color, label: String)] = [
        (AppColors.Spectrum.eGauche,      "E.G"),
        (AppColors.Spectrum.gauche,       "G"),
        (AppColors.Spectrum.centreGauche, "C.G"),
        (AppColors.Spectrum.centre,       "C"),
        (AppColors.Spectrum.centreDroite, "C.D"),
        (AppColors.Spectrum.droite,       "D"),
        (AppColors.Spectrum.eDroite,      "E.D"),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / CGFloat(segments.count)
            HStack(spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.offset) { i, seg in
                    ZStack {
                        seg.color
                        Text(seg.label)
                            .font(.appCaption2)
                            .foregroundStyle(
                                i == 3
                                    ? AppColors.Neutral.n800
                                    : Color.white.opacity(0.85)
                            )
                    }
                    .frame(width: w, height: 56)
                }
            }
        }
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
    }
}

// MARK: - Mock story row

private struct MockStoryRow: View {
    let title: String
    let leanLabel: String
    let leanColor: Color
    let textColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.m) {
            Text(leanLabel)
                .font(.appFootnote)
                .foregroundStyle(textColor)
                .padding(.horizontal, AppSpacing.s)
                .padding(.vertical, AppSpacing.xs)
                .background(leanColor)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.s))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.s).stroke(AppColors.stroke, lineWidth: 1))
                .fixedSize()

            Text(title)
                .font(.appBody)
                .foregroundStyle(AppColors.Adaptive.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.m)
        .background(AppColors.Adaptive.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
    }
}

// MARK: - Page indicator

private struct PageIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(
                        i == current
                            ? AppColors.Adaptive.textPrimary
                            : AppColors.Adaptive.placeholder
                    )
                    .frame(width: i == current ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: current)
            }
        }
    }
}

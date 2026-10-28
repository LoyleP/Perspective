import SwiftUI

/// First launch, three steps: what Optique shows (with a live story), topic choice,
/// then an explanation of alerts before the system notification prompt.
struct OnboardingView: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("preferredTopics") private var preferredTopicsRaw = ""
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false

    @State private var step = 0
    @State private var topics: Set<StoryTopic> = []
    @State private var example: Story?
    @State private var isRequestingAlerts = false

    private let stepCount = 3

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                Group {
                    switch step {
                    case 0: valueStep
                    case 1: topicsStep
                    default: alertsStep
                    }
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            .scrollBounceBehavior(.basedOnSize)

            footer
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .task { example = await Self.loadExample() }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: AppSpacing.m) {
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? AppColors.Brand.accent : AppColors.Adaptive.surfaceElevated)
                        .frame(height: 4)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Étape \(step + 1) sur \(stepCount)")

            Button("Passer") { finish() }
                .font(.appFootnote.weight(.semibold))
                .foregroundStyle(AppColors.Adaptive.textTertiary)
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.top, AppSpacing.s)
    }

    private var footer: some View {
        VStack(spacing: AppSpacing.s) {
            if step < stepCount - 1 {
                Button {
                    withAnimation(.snappy) { step += 1 }
                } label: {
                    Text(step == 1 && topics.isEmpty ? "Continuer sans choisir" : "Continuer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.optiquePrimary)
            } else {
                Button {
                    Task { await enableAlerts() }
                } label: {
                    Group {
                        if isRequestingAlerts {
                            ProgressView().tint(AppColors.Neutral.n950)
                        } else {
                            Text("Activer les alertes")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.optiquePrimary)
                .disabled(isRequestingAlerts)

                Button {
                    finish()
                } label: {
                    Text("Plus tard").frame(maxWidth: .infinity)
                }
                .buttonStyle(.optiqueSecondary)
            }
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.top, AppSpacing.s)
        .padding(.bottom, AppSpacing.m)
    }

    // MARK: - Step 1: what Optique shows

    private var valueStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            title("Voyez l'info\nde tous les côtés")
            Text("Optique regroupe les articles de dizaines de médias sur un même sujet et montre qui en parle, de l'extrême-gauche à l'extrême-droite.")
                .font(.appBody)
                .foregroundStyle(AppColors.Adaptive.textBody)

            if let example, let coverage = example.computedCoverage {
                StoryHeroCard(story: example, size: .medium)
                    .allowsHitTesting(false)
                SpectrumBar(coverage: coverage, style: .detailed, sources: example.sources)
                    .padding(AppSpacing.m)
                    .cardSurface()
            } else {
                RoundedRectangle(cornerRadius: AppRadius.xl)
                    .fill(AppColors.Adaptive.placeholder)
                    .aspectRatio(3.0 / 2.0, contentMode: .fit)
                    .shimmering()
                SkeletonLines(count: 3, lineHeight: 14)
            }
        }
    }

    // MARK: - Step 2: topics

    private var topicsStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            title("Qu'est-ce qui\nvous intéresse ?")
            Text("Vos thèmes apparaîtront en premier dans Explorer. Vous pourrez les modifier dans les Réglages.")
                .font(.appBody)
                .foregroundStyle(AppColors.Adaptive.textBody)
            TopicPickerGrid(selection: $topics)
        }
    }

    // MARK: - Step 3: alerts

    private var alertsStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            title("Soyez prévenu\ndes grands sujets")
            Text("Une alerte quand un sujet est couvert par plusieurs médias, au plus une fois par heure. Rien d'autre.")
                .font(.appBody)
                .foregroundStyle(AppColors.Adaptive.textBody)
            sampleAlert
                .padding(.top, AppSpacing.s)
        }
    }

    /// Lock-screen style preview of what an alert looks like.
    private var sampleAlert: some View {
        HStack(alignment: .top, spacing: AppSpacing.st) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("OPTIQUE")
                        .font(.appCaption1)
                        .foregroundStyle(AppColors.Adaptive.textTertiary)
                    Spacer()
                    Text("maintenant")
                        .font(.appCaption2)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
                Text(example?.title ?? "Réforme des retraites : le gouvernement présente son projet")
                    .font(.appSubheadline.weight(.semibold))
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .lineLimit(2)
                HStack(spacing: AppSpacing.s) {
                    if let coverage = example?.computedCoverage {
                        SpectrumBar(coverage: coverage).frame(width: 64)
                    }
                    Text("\(example?.sources.count ?? 8) sources · nouvelle actualité")
                        .font(.appFootnote)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
            }
        }
        .padding(AppSpacing.st)
        .background(AppColors.Adaptive.surfaceElevated, in: RoundedRectangle(cornerRadius: AppRadius.xl))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Exemple d'alerte")
    }

    // MARK: - Helpers

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.appDisplay)
            .foregroundStyle(AppColors.Adaptive.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func enableAlerts() async {
        isRequestingAlerts = true
        try? await NotificationManager.shared.requestAuthorization()
        await NotificationManager.shared.checkAuthorizationStatus()
        notificationsEnabled = NotificationManager.shared.authorizationStatus == .authorized
        isRequestingAlerts = false
        finish()
    }

    private func finish() {
        preferredTopicsRaw = StoryTopic.storageValue(topics)
        hasCompletedOnboarding = true
    }

    /// A recent story covered by many sources, with a photo, to show the spectrum for real.
    private static func loadExample() async -> Story? {
        let stories = (try? await StoryRepository.shared.fetchFeed(topic: nil, limit: 30, offset: 0)) ?? []
        return stories
            .filter { $0.leadImageURL != nil && $0.computedCoverage != nil }
            .max { $0.sources.count < $1.sources.count }
    }
}

#if DEBUG
#Preview("OnboardingView") {
    OnboardingView()
}
#endif

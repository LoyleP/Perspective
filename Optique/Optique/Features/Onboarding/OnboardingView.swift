import SwiftUI

/// First launch, two steps: what Optique shows (a live story told by the left and by the right),
/// then topic choice. Alerts are offered later, in the feed, once a first story has been read.
struct OnboardingView: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("preferredTopics") private var preferredTopicsRaw = ""

    @State private var step = 0
    @State private var topics: Set<StoryTopic> = []
    @State private var example: Story?

    private let stepCount = 2

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                Group {
                    switch step {
                    case 0: valueStep
                    default: topicsStep
                    }
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
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
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textTertiary)
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.top, AppSpacing.s)
    }

    private var footer: some View {
        VStack(spacing: AppSpacing.s) {
            if step < stepCount - 1 {
                Button {
                    withAnimation(.app) { step += 1 }
                } label: {
                    Text("Continuer").frame(maxWidth: .infinity)
                }
                .buttonStyle(.optiquePrimary)
            } else {
                Button { finish() } label: {
                    Text(topics.isEmpty ? "Commencer sans choisir" : "Commencer").frame(maxWidth: .infinity)
                }
                .buttonStyle(.optiquePrimary)
            }
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.top, AppSpacing.s)
        .padding(.bottom, AppSpacing.m)
    }

    // MARK: - Step 1: what Optique shows

    private var valueStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            title("Le même sujet,\nraconté autrement")
            Text("Optique regroupe les articles de dizaines de médias sur un même sujet et vous montre ce que chaque bord en dit.")
                .font(.appBody)
                .foregroundStyle(AppColors.Adaptive.textBody)

            if let example {
                VStack(alignment: .leading, spacing: AppSpacing.st) {
                    Text(example.title)
                        .font(.geist(.heading, .medium))
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(Self.sides(of: example), id: \.label) { side in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(side.label)
                                .font(.appCaption)
                                .foregroundStyle(side.color)
                            Text(side.line)
                                .font(.appBody)
                                .foregroundStyle(AppColors.Adaptive.textBody)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(AppSpacing.st)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.Adaptive.cardSurface, in: RoundedRectangle(cornerRadius: AppRadius.l))
                    }
                }
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
            Text("Vos thèmes passeront en premier dans votre fil. Vous pourrez les modifier dans les Réglages.")
                .font(.appBody)
                .foregroundStyle(AppColors.Adaptive.textBody)
            TopicPickerGrid(selection: $topics)
        }
    }

    // MARK: - Helpers

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.appTitle)
            .foregroundStyle(AppColors.Adaptive.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func finish() {
        preferredTopicsRaw = StoryTopic.storageValue(topics)
        hasCompletedOnboarding = true
    }

    /// A recent political story covered by both the left and the right, to show the idea for real.
    private static func loadExample() async -> Story? {
        let stories = (try? await StoryRepository.shared.fetchFeed(topic: nil, limit: 30, offset: 0)) ?? []
        return stories
            .filter { $0.hasPoliticalAngle && sides(of: $0).count == 2 }
            .max { ($0.spectrumSummary != nil ? 1 : 0, $0.sources.count) < ($1.spectrumSummary != nil ? 1 : 0, $1.sources.count) }
    }

    /// What the left and the right say: the first point of each side's summary, else a headline.
    private static func sides(of story: Story) -> [(label: String, line: String, color: Color)] {
        let groups: [(String, [PoliticalLean], Color)] = [
            ("À gauche", [.gauche, .extremeGauche], PoliticalLean.gauche.spectrumColor),
            ("À droite", [.droite, .extremeDroite], PoliticalLean.droite.spectrumColor)
        ]
        return groups.compactMap { label, leans, color in
            let point = story.spectrumSummary?.perspectives
                .first { leans.contains($0.lean) }?
                .summary.components(separatedBy: "\n").first?
                .trimmingCharacters(in: CharacterSet(charactersIn: "• ").union(.whitespaces))
            let headline = story.articles
                .first { leans.contains(PoliticalLean.from($0.source?.politicalLean ?? 4) ?? .centre) }?
                .title
            guard let line = (point?.isEmpty == false ? point : headline) else { return nil }
            return (label, line, color)
        }
    }
}

#if DEBUG
#Preview("OnboardingView") {
    OnboardingView()
}
#endif

import SwiftUI

/// First launch, four steps with one idea each (Apple News, Particle, Ground News and NYT patterns).
/// Every step starts with its title and description, then its visual:
/// 1. what Optique is: the French media, left to right, around one mark;
/// 2. the idea on a real story of the day: who covers it and what each side keeps;
/// 3. topics to put first;
/// 4. the big-story alerts, shown as the notification itself before the system asks.
/// A back chevron, a progress bar and "Passer" stay at the top; one main button at the bottom.
struct OnboardingView: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("preferredTopics") private var preferredTopicsRaw = ""
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("alertsPromptDismissed") private var alertsPromptDismissed = false

    @State private var step = 0
    @State private var forward = true
    @State private var topics: Set<StoryTopic> = []
    @State private var example: Story?
    @State private var sources: [Source] = []
    @State private var isAskingForAlerts = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let stepCount = 4

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                Group {
                    switch step {
                    case 0: welcomeStep
                    case 1: exampleStep
                    case 2: topicsStep
                    default: alertsStep
                    }
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(step)
                .transition(.asymmetric(
                    insertion: .identity,
                    removal: .stepExit(forward: forward, reduceMotion: reduceMotion)
                ))
            }
            .scrollBounceBehavior(.basedOnSize)

            footer
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: step)
        .task { await load() }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: AppSpacing.st) {
            Button { go(to: step - 1) } label: {
                HeroIcon("chevron-left", size: 20)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(step == 0 ? 0 : 1)
            .scaleEffect(step == 0 ? 0.6 : 1)
            .blur(radius: step == 0 ? 4 : 0)
            .animation(.spring(duration: 0.35, bounce: 0.2), value: step == 0)
            .disabled(step == 0)
            .accessibilityLabel("Retour")

            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { index in
                    // Each segment fills from its left edge as the step is reached, and empties toward it on the way back.
                    Capsule()
                        .fill(AppColors.Adaptive.surfaceElevated)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(AppColors.Brand.accent)
                                .scaleEffect(x: index <= step ? 1 : 0.001, anchor: .leading)
                                .animation(.spring(duration: 0.5, bounce: 0.1).delay(index == step ? 0.12 : 0), value: step)
                        }
                        .frame(height: 4)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Étape \(step + 1) sur \(stepCount)")

            Button("Passer") { finish() }
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .opacity(step == stepCount - 1 ? 0 : 1)
                .animation(.app, value: step == stepCount - 1)
                .disabled(step == stepCount - 1)
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.top, AppSpacing.s)
    }

    private var footer: some View {
        VStack(spacing: AppSpacing.xs) {
            Button(action: primaryAction) {
                Text(primaryTitle)
                    .contentTransition(.interpolate)
                    .animation(.spring(duration: 0.4, bounce: 0.1), value: primaryTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.optiquePrimary)
            .disabled(isAskingForAlerts)

            // The alerts step can be declined; the others are a plain "next".
            if step == stepCount - 1 && alertsCanBeAsked {
                Button("Plus tard") { finish() }
                    .font(.appBodyStrong)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .transition(.blurRise)
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.1), value: step)
        .padding(.horizontal, AppSpacing.m)
        .padding(.top, AppSpacing.s)
        .padding(.bottom, AppSpacing.m)
    }

    private var primaryTitle: String {
        switch step {
        case 0: return "Commencer"
        case 2: return topics.isEmpty ? "Continuer sans choisir" : "Continuer"
        case stepCount - 1: return alertsCanBeAsked ? "Activer les alertes" : "C'est parti"
        default: return "Continuer"
        }
    }

    private func primaryAction() {
        guard step == stepCount - 1 else { go(to: step + 1); return }
        guard alertsCanBeAsked else { finish(); return }
        isAskingForAlerts = true
        Task {
            try? await NotificationManager.shared.requestAuthorization()
            notificationsEnabled = NotificationManager.shared.authorizationStatus == .authorized
            alertsPromptDismissed = true   // the feed won't offer them again
            isAskingForAlerts = false
            finish()
        }
    }

    private var alertsCanBeAsked: Bool {
        NotificationManager.shared.authorizationStatus == .notDetermined
    }

    // MARK: - Step 1: welcome

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            heading("L'actualité,\nsous tous les angles",
                    sources.count >= 10
                    ? "Optique réunit les articles de \(sources.count) médias, de la gauche à la droite, et les rassemble par sujet."
                    : "Optique réunit les articles des médias français, de la gauche à la droite, et les rassemble par sujet.")
            SourceArc(sources: sources)
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.l)
                .staggerIn(2)
        }
    }

    // MARK: - Step 2: a real story

    private var exampleStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            heading("Un sujet,\ntous les points de vue",
                    "Pour chaque sujet, voyez quels médias en parlent et ce que chaque bord en retient.")
            Group {
                if let example {
                    ExampleStoryCard(story: example, sides: Self.sides(of: example))
                } else {
                    RoundedRectangle(cornerRadius: AppRadius.xl)
                        .fill(AppColors.Adaptive.placeholder)
                        .frame(height: 300)
                        .shimmering()
                }
            }
            .staggerIn(2)
        }
    }

    // MARK: - Step 3: topics

    private var topicsStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            heading("Qu'est-ce qui\nvous intéresse ?",
                    "Ces thèmes passeront en premier dans votre fil. Vous pourrez les changer dans les Réglages.")
            ChipFlow(spacing: AppSpacing.s) {
                // The chips cascade in, one after the other.
                ForEach(Array(StoryTopic.selectable.enumerated()), id: \.element) { index, topic in
                    TopicChip(topic: topic, isOn: topics.contains(topic)) {
                        if topics.contains(topic) { topics.remove(topic) } else { topics.insert(topic) }
                    }
                    .staggerIn(delay: 0.24 + Double(index) * 0.035)
                }
            }
            .sensoryFeedback(.selection, trigger: topics)
        }
    }

    // MARK: - Step 4: alerts

    private var alertsStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            heading("Les grands sujets,\ndès qu'ils éclatent",
                    "Une alerte quand un sujet est repris par de nombreux médias, avec le bord qui en parle le plus. Au plus une par heure.")
            NotificationPreview(story: example)
                .padding(.top, AppSpacing.l)
        }
    }

    // MARK: - Helpers

    /// Title and description, always first on a step and close together.
    private func heading(_ titleText: String, _ descriptionText: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            title(titleText).staggerIn(0)
            paragraph(descriptionText).staggerIn(1)
        }
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.appTitle)
            .foregroundStyle(AppColors.Adaptive.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.appBody)
            .foregroundStyle(AppColors.Adaptive.textBody)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func go(to newStep: Int) {
        guard (0..<stepCount).contains(newStep) else { return }
        // The direction is set first, in its own update, so the leaving step picks it up for its exit.
        forward = newStep > step
        Task { @MainActor in
            withAnimation(.spring(duration: 0.42, bounce: 0.12)) { step = newStep }
        }
    }

    private func finish() {
        preferredTopicsRaw = StoryTopic.storageValue(topics)
        hasCompletedOnboarding = true
        Haptics.success()
    }

    private func load() async {
        await NotificationManager.shared.checkAuthorizationStatus()
        async let story = Self.loadExample()
        async let list = Self.loadSources()
        let (s, l) = await (story, list)
        example = s
        withAnimation(.app) { sources = l }
    }

    private static func loadSources() async -> [Source] {
        if let cached = await SourceRepository.shared.cachedSources(), !cached.isEmpty { return cached }
        return (try? await SourceRepository.shared.fetchAllSources()) ?? []
    }

    /// A recent political story covered by both the left and the right, to show the idea for real.
    private static func loadExample() async -> Story? {
        let stories = (try? await StoryRepository.shared.fetchFeed(topic: nil, limit: 30, offset: 0)) ?? []
        return stories
            .filter { $0.hasPoliticalAngle && $0.computedCoverage != nil && sides(of: $0).count == 2 }
            .max { ($0.spectrumSummary != nil ? 1 : 0, $0.sources.count) < ($1.spectrumSummary != nil ? 1 : 0, $1.sources.count) }
    }

    /// What the left and the right say: the first point of each side's summary, else a headline.
    fileprivate static func sides(of story: Story) -> [(lean: PoliticalLean, label: String, line: String)] {
        let groups: [(PoliticalLean, String, [PoliticalLean])] = [
            (.gauche, "À gauche", [.gauche, .extremeGauche]),
            (.droite, "À droite", [.droite, .extremeDroite])
        ]
        return groups.compactMap { lean, label, leans in
            let point = story.spectrumSummary?.perspectives
                .first { leans.contains($0.lean) }?
                .summary.components(separatedBy: "\n").first?
                .trimmingCharacters(in: CharacterSet(charactersIn: "• ").union(.whitespaces))
            let headline = story.articles
                .first { leans.contains(PoliticalLean.from($0.source?.politicalLean ?? 4) ?? .centre) }?
                .title
            guard let line = (point?.isEmpty == false ? point : headline) else { return nil }
            return (lean, label, line)
        }
    }
}

// MARK: - Motion

/// Offset, blur and fade, for transitions.
private struct BlurShift: ViewModifier {
    let x: CGFloat
    let y: CGFloat
    let blur: CGFloat
    let opacity: Double
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(x: x, y: y)
            .blur(radius: blur)
            .opacity(opacity)
    }
}

private extension AnyTransition {
    /// The step being left slides a short way toward where it goes, shrinks a touch and blurs out.
    static func stepExit(forward: Bool, reduceMotion: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        return .modifier(
            active: BlurShift(x: forward ? -56 : 56, y: 0, blur: 10, opacity: 0, scale: 0.97),
            identity: BlurShift(x: 0, y: 0, blur: 0, opacity: 1, scale: 1)
        )
    }

    /// Rises in out of a blur.
    static var blurRise: AnyTransition {
        .modifier(
            active: BlurShift(x: 0, y: 10, blur: 6, opacity: 0, scale: 1),
            identity: BlurShift(x: 0, y: 0, blur: 0, opacity: 1, scale: 1)
        )
    }
}

// MARK: - Welcome visual

/// Up to 15 real source logos on two half rings, far left on the left to far right on the right
/// (the same reading as the coverage dial), around the Optique mark.
private struct SourceArc: View {
    let sources: [Source]
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let height: CGFloat = 230

    /// An even pick along the spectrum, sorted left to right.
    private var picked: [Source] {
        let sorted = sources.filter(\.isActive).sorted { $0.politicalLean < $1.politicalLean }
        guard sorted.count > 15 else { return sorted }
        return (0..<15).map { sorted[Int(Double($0) * Double(sorted.count - 1) / 14)] }
    }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: height - 36)
            let outer = min(geo.size.width / 2 - 28, height - 64)
            let inner = outer - 62
            let items = picked
            ZStack {
                // Faint guide arcs, the spectrum underneath.
                ForEach([outer, inner], id: \.self) { r in
                    Path { p in p.addArc(center: center, radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false) }
                        .stroke(AppColors.Adaptive.divider, style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
                }

                if items.isEmpty {
                    ForEach(Array(PoliticalLean.allCases.enumerated()), id: \.offset) { index, lean in
                        let angle = 180 - Double(index) * 180 / Double(PoliticalLean.allCases.count - 1)
                        Circle()
                            .fill(lean.spectrumColor.opacity(0.5))
                            .frame(width: 30, height: 30)
                            .position(point(center, outer, angle))
                    }
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, source in
                        // Alternate rings so neighbouring logos never touch.
                        let onOuter = index.isMultiple(of: 2)
                        let angle = 180 - Double(index) * 180 / Double(max(items.count - 1, 1))
                        SourceAvatarView(source: source, size: onOuter ? 38 : 32)
                            .overlay(Circle().stroke(source.lean?.spectrumColor ?? .clear, lineWidth: 2))
                            .scaleEffect(shown || reduceMotion ? 1 : 0.4)
                            .opacity(shown || reduceMotion ? 1 : 0)
                            .animation(.spring(duration: 0.55, bounce: 0.3).delay(0.3 + Double(index) * 0.035), value: shown)
                            .position(point(center, onOuter ? outer : inner, angle))
                    }
                }

                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .foregroundStyle(AppColors.Brand.onInk)
                    .frame(width: 72, height: 72)
                    .background(AppColors.Brand.accent, in: Circle())
                    .position(center)

                HStack {
                    Text("Gauche")
                    Spacer()
                    Text("Droite")
                }
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .padding(.horizontal, 4)
                .position(x: geo.size.width / 2, y: height - 8)
            }
        }
        .frame(height: height)
        .onAppear { shown = true }
        .onChange(of: sources.count) { _, _ in shown = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Les médias suivis par Optique, de la gauche à la droite")
    }

    private func point(_ center: CGPoint, _ radius: CGFloat, _ degrees: Double) -> CGPoint {
        let a = degrees * .pi / 180
        return CGPoint(x: center.x + radius * cos(a), y: center.y - radius * sin(a))
    }
}

// MARK: - Example card

/// A real story of the day: how many outlets cover it, how the coverage splits, and one line from
/// each side, the way a story page shows it.
private struct ExampleStoryCard: View {
    let story: Story
    let sides: [(lean: PoliticalLean, label: String, line: String)]
    @State private var barDrawn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Un sujet du jour")
                .overlineStyle()
            Text(story.title)
                .font(.geist(.heading, .medium))
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if let coverage = story.computedCoverage {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    SpectrumBar(coverage: coverage, barHeight: 8)
                        .mask(alignment: .leading) {
                            Rectangle().scaleEffect(x: barDrawn ? 1 : 0.001, anchor: .leading)
                        }
                    HStack(spacing: AppSpacing.s) {
                        SourceStack(sources: story.sources, size: 22, ringColor: AppColors.Adaptive.cardSurface)
                        Text(story.sources.count == 1 ? "1 média" : "\(story.sources.count) médias")
                            .font(.appCaption)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                        Spacer(minLength: 0)
                        LeanTags(coverage: coverage)
                    }
                }
            }

            Divider().overlay(AppColors.Adaptive.divider)

            ForEach(Array(sides.enumerated()), id: \.element.label) { index, side in
                VStack(alignment: .leading, spacing: 6) {
                    LeanTagPill(lean: side.lean, text: side.label)
                    Text(side.line)
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textBody)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .staggerIn(delay: 0.55 + Double(index) * 0.12)
            }
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.Adaptive.cardSurface, in: RoundedRectangle(cornerRadius: AppRadius.xl))
        .accessibilityElement(children: .combine)
        .onAppear {
            if reduceMotion { barDrawn = true; return }
            withAnimation(.easeInOut(duration: 0.7).delay(0.35)) { barDrawn = true }
        }
    }
}

// MARK: - Topic chips

private struct TopicChip: View {
    let topic: StoryTopic
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                HeroIcon(isOn ? "check-circle" : topic.heroIcon, solid: isOn, size: 18)
                Text(topic.rawValue)
                    .font(.appBodyStrong)
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? AppColors.Brand.onInk : AppColors.Adaptive.textPrimary)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(isOn ? AppColors.Brand.accent : AppColors.Adaptive.cardSurface, in: Capsule())
            .overlay(Capsule().stroke(isOn ? .clear : AppColors.stroke, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(CardPressStyle())
        .animation(.app, value: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Wraps its children onto as many rows as needed.
private struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Notification preview

/// The alert as it would land on the lock screen, built from the story of the day, with an older
/// one tucked behind it.
private struct NotificationPreview: View {
    let story: Story?
    @State private var olderIn = false
    @State private var newIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var line: String {
        guard let story else { return "Un sujet repris par de nombreux médias" }
        let side = story.computedCoverage.map { $0.leanVerdict.text.lowercased() } ?? ""
        return "\(story.sources.count) médias en parlent" + (side.isEmpty ? "" : " · \(side)")
    }

    var body: some View {
        ZStack(alignment: .top) {
            banner(title: "Optique", line: "Un autre grand sujet du jour", headline: nil)
                .scaleEffect(newIn ? 0.92 : 1, anchor: .top)
                .offset(y: newIn ? -14 : 0)
                .opacity(olderIn ? (newIn ? 0.45 : 1) : 0)
                .blur(radius: olderIn ? 0 : 6)
            banner(title: "Optique", line: line, headline: story?.title ?? "Le sujet du moment, dès qu'il éclate")
                .offset(y: newIn ? 0 : -60)
                .scaleEffect(newIn ? 1 : 0.94, anchor: .top)
                .opacity(newIn ? 1 : 0)
                .blur(radius: newIn ? 0 : 8)
        }
        .padding(.top, 14)
        .onAppear {
            if reduceMotion { olderIn = true; newIn = true; return }
            withAnimation(.spring(duration: 0.5, bounce: 0.15).delay(0.25)) { olderIn = true }
            withAnimation(.spring(duration: 0.6, bounce: 0.3).delay(0.75)) { newIn = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Exemple d'alerte : \(line)")
    }

    private func banner(title: String, line: String, headline: String?) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.st) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(AppColors.Brand.onInk)
                .frame(width: 38, height: 38)
                .background(AppColors.Brand.accent, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title).font(.appBodyStrong)
                    Spacer()
                    Text("maintenant").font(.appCaption).foregroundStyle(AppColors.Adaptive.textMeta)
                }
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                if let headline {
                    Text(headline)
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .lineLimit(2)
                }
                Text(line)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                    .lineLimit(1)
            }
        }
        .padding(AppSpacing.st)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.Adaptive.cardSurface, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppColors.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }
}

#if DEBUG
#Preview("OnboardingView") {
    OnboardingView()
}
#endif

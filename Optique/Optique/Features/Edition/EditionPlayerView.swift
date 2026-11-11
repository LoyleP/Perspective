import SwiftUI

/// The Brief as a full-screen player: an opening card, then each story on one slide (photo, headline, written points,
/// coverage), then a closing card. Tap the right or left edge, or swipe sideways, to move between slides. Every element
/// comes in with the motion system's `enter`, one after the other, and leaves with `exit`.
struct EditionPlayerView: View {
    let edition: Edition
    /// Opens a story's page: the player closes and the story is pushed on the feed.
    var onOpenStory: (Story) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    /// The slide on screen, or the one being settled on once the finger lifts.
    @State private var index = 0
    /// How far the finger has pulled the slides sideways.
    @State private var drag: CGFloat = 0

    private var count: Int { edition.stories.count + 2 }

    // A pager of its own rather than a paging ScrollView: every slide is built up front (no blank frame while a lazy
    // slide loads), sits exactly one screen apart (nothing peeks in from the sides), and the slide being reached is
    // known the moment the finger lifts, so its content starts coming in while it slides into place.
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let top = geo.safeAreaInsets.top
            let bottom = geo.safeAreaInsets.bottom
            // The pager ignores the safe area, so a slide spans the whole screen, under the status bar and home indicator.
            let height = geo.size.height + top + bottom
            ZStack(alignment: .topLeading) {
                Color.black
                HStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { i in
                        content(for: i, top: top, bottom: bottom)
                            .frame(width: width, height: height)
                            .clipped()
                            // Only the slide on screen and its neighbours are drawn.
                            .opacity(abs(i - index) <= 1 ? 1 : 0)
                            .allowsHitTesting(i == index)
                    }
                }
                .frame(width: width, alignment: .leading)
                .offset(x: -CGFloat(index) * width + drag)

                tapZones
                chrome(top: top)
            }
            .frame(width: width, height: height)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(swipe(width: width))
            .ignoresSafeArea()
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
        .sensoryFeedback(.selection, trigger: index)
        .task {
            // Photos are fetched before their slide is reached, so none arrives empty.
            for story in edition.stories {
                if let url = story.leadImageURL { _ = await ImagePipeline.shared.firstSharp([url] + story.imageAlternates, maxPixel: 1400) }
            }
        }
    }

    // MARK: Paging

    /// Sideways drags move the slides under the finger; past the first and last slide they resist.
    private func swipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let dx = value.translation.width
                // A mostly vertical drag is not a page turn.
                guard drag != 0 || abs(dx) > abs(value.translation.height) else { return }
                let pastEdge = (index == 0 && dx > 0) || (index == count - 1 && dx < 0)
                drag = pastEdge ? dx / (1 + abs(dx) / (width * 0.35)) * 0.5 : dx
            }
            .onEnded { value in
                guard drag != 0 else { return }
                // Turn when the slide is pulled past half way, or flicked that far.
                let reach = min(abs(drag) > width / 2 ? abs(drag) : abs(value.predictedEndTranslation.width), width)
                var target = index
                if reach > width / 2 { target += drag < 0 ? 1 : -1 }
                settle(on: target, width: width, velocity: value.velocity.width)
            }
    }

    /// Sends the slides to `target`, carrying on at the finger's speed.
    private func settle(on target: Int, width: CGFloat, velocity: CGFloat) {
        let target = min(max(target, 0), count - 1)
        let left = (CGFloat(index - target) * width) - drag  // points still to travel
        // The spring's starting speed, as a share of the distance left per second.
        let relative = abs(left) > 1 ? min(max(Double(velocity / left), -10), 40) : 0
        withAnimation(.surface(velocity: relative)) {
            index = target
            drag = 0
        }
    }

    @ViewBuilder
    private func content(for index: Int, top: CGFloat, bottom: CGFloat) -> some View {
        if index == 0 {
            IntroPage(edition: edition, top: top, bottom: bottom, isCurrent: self.index == index)
        } else if index <= edition.stories.count {
            StoryPage(story: edition.stories[index - 1], top: top, bottom: bottom, isCurrent: self.index == index) {
                onOpenStory(edition.stories[index - 1])
                dismiss()
            }
        } else {
            OutroPage(edition: edition, top: top, bottom: bottom, isCurrent: self.index == index) { dismiss() }
        }
    }

    // MARK: Chrome

    /// One segment per card, lit up to the one on screen, and the close button.
    private func chrome(top: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(0..<count, id: \.self) { index in
                    Capsule()
                        .fill(index <= self.index ? Color.white : Color.white.opacity(0.32))
                        .frame(height: 2)
                        .animation(.select, value: self.index)
                }
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.top, top + 6)
            .accessibilityHidden(true)

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    LucideIcon("x", size: 20)
                        .foregroundStyle(Color.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Fermer le Brief")
            }
            .padding(.horizontal, AppSpacing.s)
            Spacer()
        }
        .background(alignment: .top) {
            LinearGradient(colors: [Color.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: top + 90)
                .allowsHitTesting(false)
        }
    }

    /// The edges of the screen step to the next or previous card, as in a story.
    private var tapZones: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: geo.size.width * 0.28)
                    .contentShape(Rectangle())
                    .onTapGesture { move(-1) }
                Spacer(minLength: 0)
                Color.clear
                    .frame(width: geo.size.width * 0.28)
                    .contentShape(Rectangle())
                    .onTapGesture { move(1) }
            }
            .padding(.top, geo.safeAreaInsets.top + 60)
            .padding(.bottom, geo.safeAreaInsets.bottom + 110)
        }
    }

    private func move(_ step: Int) {
        let next = min(max(index + step, 0), count - 1)
        guard next != index else { return }
        withAnimation(.surface) { index = next; drag = 0 }
    }
}

// MARK: - Shared pieces

private enum Ink {
    static let secondary = Color.white.opacity(0.82)
    static let faint = Color.white.opacity(0.6)
    static let line = Color.white.opacity(0.18)
}

/// The small uppercase label above a card's content.
private struct Kicker: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .typeStyle(.label)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(Ink.secondary)
            .lineLimit(1)
    }
}

/// An element coming in once its slide has settled: it fades in while rising a few points; going out it just fades.
private struct Reveal: ViewModifier {
    let shown: Bool
    /// Elements sharing a slide come in one after another, in this order.
    var order = 0

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || Motion.isReduced ? 0 : 8)
            .animation(shown ? .easeOut(duration: Motion.moderate).delay(Motion.delay(0.5) + Motion.stagger(order, step: 0.12)) : .exit, value: shown)
    }
}

private extension View {
    func reveal(_ shown: Bool, order: Int = 0) -> some View { modifier(Reveal(shown: shown, order: order)) }
}

// MARK: - Opening card

private struct IntroPage: View {
    let edition: Edition
    let top: CGFloat
    let bottom: CGFloat
    let isCurrent: Bool

    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Kicker("BRIEF")
                    Spacer()
                    Kicker(edition.dateLabel)
                }
                Rectangle().fill(Ink.line).frame(height: 1).padding(.top, AppSpacing.st)
            }
            .reveal(shown)

            Text(edition.headline)
                .typeStyle(.display)
                .foregroundStyle(Color.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AppSpacing.l)
                .reveal(shown)

            VStack(alignment: .leading, spacing: AppSpacing.m) {
                ForEach(Array(edition.stories.enumerated()), id: \.element.id) { index, story in
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.st) {
                        Text(String(format: "%02d", index + 1))
                            .typeStyle(.label)
                            .monospacedDigit()
                            .foregroundStyle(Ink.faint)
                            .frame(width: 22, alignment: .leading)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(story.title)
                                .typeStyle(.ui)
                                .foregroundStyle(Color.white)
                                .fixedSize(horizontal: false, vertical: true)
                            if let first = story.bullets.first {
                                Text(first)
                                    .typeStyle(.body)
                                    .foregroundStyle(Ink.faint)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .reveal(shown)
                }
            }
            .padding(.top, AppSpacing.xl)

            Spacer(minLength: AppSpacing.l)
            Kicker("\(edition.stories.count) SUJETS · \(edition.readingMinutes) MIN DE LECTURE")
                .reveal(shown)
        }
        .onChange(of: isCurrent, initial: true) { _, now in shown = now }
        .padding(.horizontal, 24)
        .padding(.top, top + 56)
        .padding(.bottom, bottom + 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - A story: everything on one slide

private struct StoryPage: View {
    let story: Story
    let top: CGFloat
    let bottom: CGFloat
    let isCurrent: Bool
    let onOpen: () -> Void

    @State private var shown = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "111113")
            // The photo fills the slide behind everything and fades into black under the text.
            Color.clear
                .overlay { RemoteImage(url: story.leadImageURL, tint: nil, maxPixel: 1400, topic: story.placeholderTopic, alternates: story.imageAlternates, iconInset: top + 70) }
                .clipped()
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.55), location: 0),
                    .init(color: Color.black.opacity(0.1), location: 0.22),
                    .init(color: Color.black.opacity(0.72), location: 0.5),
                    .init(color: Color.black, location: 0.72),
                ],
                startPoint: .top, endPoint: .bottom
            )
            content
        }
        .onChange(of: isCurrent, initial: true) { _, now in shown = now }
    }

    /// Headline, the written points, then who covers it, with the share button.
    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Spacer(minLength: 0)
            Text(story.title)
                .typeStyle(.display)
                .foregroundStyle(Color.white)
                .fixedSize(horizontal: false, vertical: true)
                .reveal(shown)

            VStack(alignment: .leading, spacing: AppSpacing.s) {
                ForEach(Array(story.bullets.prefix(3).enumerated()), id: \.offset) { _, bullet in
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.s) {
                        Circle().fill(Ink.faint).frame(width: 5, height: 5)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 5 }
                        Text(bullet)
                            .typeStyle(.body)
                            .foregroundStyle(Ink.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .reveal(shown, order: 1)
                }
            }

            coverage
                .reveal(shown, order: 2)

            HStack(spacing: AppSpacing.s) {
                Button(action: onOpen) {
                    HStack(spacing: AppSpacing.s) {
                        Text("Voir le sujet")
                        // Lucide ships the left arrow only; mirrored it is the right one.
                        LucideIcon("arrow-left", size: 16)
                            .scaleEffect(x: -1)
                    }
                    .modifier(PlayerButton(solid: true))
                }
                .buttonStyle(.plain)
                if let url = story.articles.first.flatMap({ URL(string: $0.url) }) {
                    ShareLink(item: url, subject: Text(story.title)) {
                        HStack(spacing: AppSpacing.s) {
                            LucideIcon("share", size: 16)
                            Text("Partager")
                        }
                        .modifier(PlayerButton())
                    }
                }
            }
            .reveal(shown, order: 2)
        }
        .padding(.horizontal, 24)
        .padding(.top, top + 90)
        .padding(.bottom, bottom + 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    /// How many outlets cover it and from which side.
    @ViewBuilder
    private var coverage: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.s) {
                Text("\(story.sources.count)")
                    .font(.system(size: 40, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.white)
                Text(story.sources.count > 1 ? "médias en parlent" : "média en parle")
                    .typeStyle(.body)
                    .foregroundStyle(Ink.secondary)
            }
            if let coverage = story.computedCoverage {
                SpectrumBar(coverage: coverage, barHeight: 8)
                Text(coverage.leanVerdictKind.text)
                    .typeStyle(.metaMedium)
                    .foregroundStyle(Color.white)
            }
        }
    }
}

/// A 52 pt capsule button, the size of the law page's "Voir tout le parcours", on a light veil over the photo.
private struct PlayerButton: ViewModifier {
    /// White with dark content for the main action; otherwise the veil.
    var solid = false

    func body(content: Content) -> some View {
        content
            .typeStyle(.ui)
            .foregroundStyle(solid ? Color.black : Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(solid ? Color.white : Color.white.opacity(0.16), in: Capsule())
            .contentShape(Capsule())
    }
}

// MARK: - Closing card

private struct OutroPage: View {
    let edition: Edition
    let top: CGFloat
    let bottom: CGFloat
    let isCurrent: Bool
    let onClose: () -> Void

    @State private var shown = false

    var body: some View {
        VStack(spacing: AppSpacing.l) {
            Spacer()
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(Color.white)
                .reveal(shown)
                .accessibilityHidden(true)
            VStack(spacing: AppSpacing.s) {
                Text("Fin de l'édition")
                    .typeStyle(.display)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white)
                Text(edition.slot == .matin ? "Prochaine édition à 18 h" : "Prochaine édition demain à 6 h")
                    .typeStyle(.body)
                    .foregroundStyle(Ink.secondary)
            }
            .reveal(shown)
            Spacer()
            Button(action: onClose) {
                Text("Revenir au fil")
                    .typeStyle(.ui)
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white, in: Capsule())
            }
            .buttonStyle(CardPressStyle())
            .reveal(shown)
        }
        .padding(.horizontal, 24)
        .padding(.top, top + 56)
        .padding(.bottom, bottom + 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: isCurrent, initial: true) { _, now in shown = now }
    }
}

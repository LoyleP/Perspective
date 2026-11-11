import SwiftUI

/// Black screen with a slow bloom of the five spectrum colours (the paywall's glow, centred) behind the logo, whose
/// four pillars rise one after another. It waits for the first feed page, then dissolves into the app.
struct SplashView: View {

    private static let minimumDuration: Duration = .milliseconds(2300)
    private static let maximumDuration: Duration = .seconds(4)
    /// Where each pillar of the logo starts and ends, as a share of its width.
    private static let pillars: [ClosedRange<CGFloat>] = [0...0.16, 0.16...0.37, 0.37...0.68, 0.68...1]

    @State private var gate = LaunchGate.shared
    @State private var glowIn = false
    @State private var risen = [false, false, false, false]
    @State private var breathing = false
    @State private var revealing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onFinished: () -> Void

    private let logoSize: CGFloat = 80

    var body: some View {
        ZStack {
            Color.black
                .opacity(revealing ? 0 : 1)
                .ignoresSafeArea()

            bloom
                .opacity(glowIn && !revealing ? 1 : 0)
                .scaleEffect(revealing ? 1.25 : 1)
                .ignoresSafeArea()

            logo
                .scaleEffect(revealing ? 1.5 : (breathing ? 1.035 : 1))
                .blur(radius: revealing ? 14 : 0)
                .opacity(revealing ? 0 : 1)
        }
        .allowsHitTesting(!revealing)
        .task { await run() }
    }

    // MARK: - Logo

    private var logo: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFit()
            .foregroundStyle(AppColors.Zinc.z50)
            .frame(width: logoSize, height: logoSize)
            .mask(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { index in
                        let range = Self.pillars[index]
                        Rectangle()
                            .frame(width: logoSize * (range.upperBound - range.lowerBound))
                            .scaleEffect(y: risen[index] ? 1 : 0, anchor: .bottom)
                    }
                }
                .frame(width: logoSize, height: logoSize, alignment: .leading)
            }
            .accessibilityHidden(true)
    }

    // MARK: - Bloom

    /// The paywall's colour blobs, drifting out of step, centred on the logo.
    private var bloom: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || revealing)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack {
                    ForEach(Array(PoliticalLean.allCases.enumerated()), id: \.offset) { index, lean in
                        let phase = Double(index) * 1.3
                        Circle()
                            .fill(lean.spectrumColor)
                            .frame(width: 230, height: 230)
                            .position(
                                x: geo.size.width * (0.12 + 0.19 * Double(index)) + CGFloat(sin(t * 0.32 + phase)) * 56,
                                y: geo.size.height * 0.5 + CGFloat(cos(t * 0.26 + phase * 1.7)) * 70
                            )
                    }
                }
                .drawingGroup()
                .blur(radius: 72)
            }
        }
        .drawingGroup()   // the blurred glow becomes one bitmap, so fading and scaling it out costs nothing
        .opacity(0.42)
        .mask(
            RadialGradient(colors: [.black, .clear], center: .center, startRadius: 40, endRadius: 360)
        )
        .accessibilityHidden(true)
    }

    // MARK: - Sequence

    private func run() async {
        if reduceMotion {
            glowIn = true
            risen = [true, true, true, true]
        } else {
            withAnimation(.easeOut(duration: 1.1)) { glowIn = true }
            for index in 0..<4 {
                withAnimation(.emphasis.delay(0.25 + Double(index) * 0.12)) { risen[index] = true }
            }
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { breathing = true }
        }

        // Stays up for at least a moment, then until the feed has something to show (or a limit).
        let clock = ContinuousClock()
        let start = clock.now
        try? await Task.sleep(for: Self.minimumDuration - .milliseconds(reduceMotion ? 0 : 900))
        while !gate.feedReady, clock.now - start < Self.maximumDuration {
            try? await Task.sleep(for: .milliseconds(50))
        }

        // A last beat on the finished logo, then it lifts; the app only starts to appear once it is on its way out.
        if !reduceMotion { try? await Task.sleep(for: .milliseconds(350)) }
        withAnimation(.easeInOut(duration: reduceMotion ? 0.3 : 0.8)) { revealing = true }
        if !reduceMotion { try? await Task.sleep(for: .milliseconds(300)) }
        gate.entered = true
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 350 : 650))
        onFinished()
    }
}

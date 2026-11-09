import SwiftUI

/// Pieces of a step arrive one after the other: each rises a little, sharpens out of a blur and fades in.
struct StaggerIn: ViewModifier {
    let delay: Double
    /// Heavy content (a moving grid) only fades: a blur over it is redrawn every frame.
    var blurs = true
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .blur(radius: !blurs || shown || reduceMotion ? 0 : 8)
            .offset(y: !blurs || shown || reduceMotion ? 0 : 18)
            .onAppear {
                withAnimation(.spring(duration: 0.6, bounce: 0.15).delay(reduceMotion ? 0 : delay)) { shown = true }
            }
    }
}

extension View {
    /// Title, description and visual come in in that order: 0, 1, 2…
    func staggerIn(_ order: Int) -> some View { modifier(StaggerIn(delay: 0.08 + Double(order) * 0.08)) }
    func staggerIn(delay: Double) -> some View { modifier(StaggerIn(delay: delay)) }
    /// Fades in with no blur or movement, for heavy content.
    func fadeIn(delay: Double) -> some View { modifier(StaggerIn(delay: delay, blurs: false)) }
}

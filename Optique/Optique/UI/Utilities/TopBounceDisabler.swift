import SwiftUI
import UIKit

extension View {
    /// Removes the rubber-band at the top of the enclosing scroll view, so a downward drag at the top
    /// reaches the navigation zoom's interactive dismissal instead of being absorbed by the bounce.
    /// Place it inside the scroll view's content.
    func noTopBounce() -> some View { background(TopBounceDisabler()) }
}

private struct TopBounceDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> Probe { Probe() }
    func updateUIView(_ view: Probe, context: Context) {}

    final class Probe: UIView {
        private var observation: NSKeyValueObservation?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            observation = nil
            guard window != nil else { return }
            var view: UIView? = superview
            while let current = view, !(current is UIScrollView) { view = current.superview }
            guard let scroll = view as? UIScrollView else { return }
            observation = scroll.observe(\.contentOffset, options: [.new]) { scroll, _ in
                let top = -scroll.adjustedContentInset.top
                if scroll.contentOffset.y < top {
                    scroll.contentOffset.y = top
                }
            }
        }
    }
}

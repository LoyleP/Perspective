import SwiftUI
import UIKit

/// Swiping right goes back to the previous page, except while the comments panel is open (its
/// drag-to-close could otherwise also trigger it and close the story). Uses a plain view that finds its navigation controller through the
/// responder chain (a background view controller is not part of that hierarchy in SwiftUI).
struct SwipeBackDisabler: UIViewRepresentable {
    let isDisabled: Bool

    func makeUIView(context: Context) -> Probe { Probe() }
    func updateUIView(_ view: Probe, context: Context) {
        view.isDisabled = isDisabled
        view.apply()
    }

    final class Probe: UIView {
        private weak var navigation: UINavigationController?
        var isDisabled = false
        private weak var originalDelegate: UIGestureRecognizerDelegate?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { fatalError() }

        private func findNavigationController() -> UINavigationController? {
            var responder: UIResponder? = self
            while let current = responder {
                if let controller = current as? UIViewController {
                    if let nav = controller.navigationController { return nav }
                }
                responder = current.next
            }
            return nil
        }

        func apply() {
            if navigation == nil { navigation = findNavigationController() }
            // With the system back button hidden, UIKit refuses the edge swipe: let it through.
            if let edge = navigation?.interactivePopGestureRecognizer, edge.delegate != nil {
                originalDelegate = edge.delegate
                edge.delegate = nil
            }
            setSwipeBack(enabled: !isDisabled)
        }

        /// Every swipe-back recognizer: the edge one, iOS 26's full-width one, and the parallax
        /// transition pans UIKit puts on the navigation controller's view.
        private func swipeBackRecognizers() -> [UIGestureRecognizer] {
            guard let navigation else { return [] }
            var recognizers = (navigation.view.gestureRecognizers ?? []).filter {
                String(describing: type(of: $0)).contains("ParallaxTransitionPan")
            }
            if let edge = navigation.interactivePopGestureRecognizer { recognizers.append(edge) }
            if #available(iOS 26.0, *), let content = navigation.interactiveContentPopGestureRecognizer {
                recognizers.append(content)
            }
            return recognizers
        }

        private func setSwipeBack(enabled: Bool) {
            for recognizer in swipeBackRecognizers() { recognizer.isEnabled = enabled }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                apply()
            } else {
                setSwipeBack(enabled: true)
                if let original = originalDelegate { navigation?.interactivePopGestureRecognizer?.delegate = original }
                navigation = nil
            }
        }

        // SwiftUI can switch the gesture back on during layout passes; keep it off.
        override func layoutSubviews() {
            super.layoutSubviews()
            if window != nil { apply() }
        }
    }
}

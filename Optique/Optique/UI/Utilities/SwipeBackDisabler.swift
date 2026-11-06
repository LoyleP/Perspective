import SwiftUI
import UIKit

/// Switches the navigation controller's swipe-back gestures off while `isDisabled` (the comments
/// panel's drag-to-close could otherwise also pop the story), and back on afterwards. It only toggles
/// `isEnabled`; UIKit keeps owning the gestures. Finds its navigation controller through the responder chain.
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
        private var didDisable = false

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { fatalError() }

        private func findNavigationController() -> UINavigationController? {
            var responder: UIResponder? = self
            while let current = responder {
                if let controller = current as? UIViewController, let nav = controller.navigationController { return nav }
                responder = current.next
            }
            return nil
        }

        func apply() {
            if navigation == nil { navigation = findNavigationController() }
            // Only touch the gestures while disabled, and give them back exactly once.
            if isDisabled {
                setSwipeBack(enabled: false)
                didDisable = true
            } else if didDisable {
                setSwipeBack(enabled: true)
                didDisable = false
            }
        }

        private func setSwipeBack(enabled: Bool) {
            guard let navigation else { return }
            var recognizers = (navigation.view.gestureRecognizers ?? []).filter {
                String(describing: type(of: $0)).contains("ParallaxTransitionPan")
            }
            if let edge = navigation.interactivePopGestureRecognizer { recognizers.append(edge) }
            if #available(iOS 26.0, *), let content = navigation.interactiveContentPopGestureRecognizer {
                recognizers.append(content)
            }
            for recognizer in recognizers { recognizer.isEnabled = enabled }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                apply()
            } else {
                if didDisable { setSwipeBack(enabled: true); didDisable = false }
                navigation = nil
            }
        }

        // SwiftUI can switch the gesture back on during layout passes; keep it off while disabled.
        override func layoutSubviews() {
            super.layoutSubviews()
            if window != nil { apply() }
        }
    }
}

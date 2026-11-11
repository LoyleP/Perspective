import SwiftUI
import UIKit

// Optique's motion system. The reasoning and the sources are in `docs/motion-system.md`.
//
// A news app is read, not watched, so motion here has three jobs only: confirm a touch, show where
// something came from or went, and mark the rare moment that deserves attention. Everything else is still.
//
// Every animation in the app uses one of the roles below. Nothing writes its own duration or curve.
//
//  Role       Duration  Shape            Used for
//  press      0.15 s    spring, no bounce  a control reacting under the finger
//  select     0.30 s    spring, no bounce  a highlight moving to what was chosen (pills, tabs, plans)
//  layout     0.35 s    spring, no bounce  content making room (fold, bars hiding, text changing)
//  morph      0.26 s    spring, 5 % bounce one element turning into another (search button to field)
//  enter      0.40 s    spring, no bounce  something arriving (toast, banner, badge, staged content)
//  exit       0.20 s    ease in            something leaving for good
//  surface    0.45 s    spring, no bounce  a large surface moving (sheet, onboarding step)
//  emphasis   0.50 s    spring, 22 % bounce the few moments meant to be noticed (first-run tip, onboarding)
//  data       0.70 s    spring, no bounce  figures and bars settling on their value
//  fade       0.20 s    ease out          opacity or colour alone
//
// Springs are used for anything that moves because a spring can be interrupted and redirected without a
// jump; curves are kept for opacity and for exits. Bounce is reserved for `emphasis` and `morph`.
//
// With Reduce Motion on, every role loses its bounce and its stagger and runs as a short ease, and the
// `rise` / `pop` transitions become plain fades.

enum Motion {
    /// True when the reader asked the system for less motion.
    static var isReduced: Bool { UIAccessibility.isReduceMotionEnabled }

    // Durations, in seconds.
    static let instant = 0.15
    static let quick = 0.2
    static let brisk = 0.26
    static let standard = 0.3
    static let moderate = 0.35
    static let gentle = 0.4
    static let large = 0.45
    static let expressive = 0.5
    static let slow = 0.7

    /// Delay between two items that arrive one after the other.
    static let staggerStep = 0.05
    /// A staggered group never takes longer than this to start its last item.
    static let staggerCap = 0.4

    /// Delay of the item at `index` in a staggered group (none with Reduce Motion).
    static func stagger(_ index: Int, step: Double = staggerStep) -> Double {
        isReduced ? 0 : min(Double(index) * step, staggerCap)
    }

    /// A delay that disappears with Reduce Motion.
    static func delay(_ seconds: Double) -> Double { isReduced ? 0 : seconds }

    fileprivate static func spring(_ duration: Double, bounce: Double = 0) -> Animation {
        isReduced ? .easeOut(duration: min(duration, quick)) : .spring(duration: duration, bounce: bounce)
    }
}

extension Animation {
    /// A control reacting under the finger.
    static var press: Animation { Motion.spring(Motion.instant) }
    /// A highlight moving to what was chosen.
    static var select: Animation { Motion.spring(Motion.standard) }
    /// Content making room: folding, bars hiding, a label changing.
    static var layout: Animation { Motion.spring(Motion.moderate) }
    /// One element turning into another.
    static var morph: Animation { Motion.spring(Motion.brisk, bounce: 0.05) }
    /// Something arriving.
    static var enter: Animation { Motion.spring(Motion.gentle) }
    /// Something leaving for good: faster than it came, and accelerating away.
    static var exit: Animation { .easeIn(duration: Motion.quick) }
    /// A large surface moving.
    static var surface: Animation { Motion.spring(Motion.large) }
    /// A large surface let go by the finger: `surface`, starting at the finger's speed so the hand-off doesn't jolt.
    /// `velocity` is relative to the distance left (points per second ÷ points to go).
    static func surface(velocity: Double) -> Animation {
        Motion.isReduced ? .easeOut(duration: Motion.quick) : .interpolatingSpring(duration: Motion.large, bounce: 0, initialVelocity: velocity)
    }
    /// The few moments meant to be noticed.
    static var emphasis: Animation { Motion.spring(Motion.expressive, bounce: 0.22) }
    /// Figures and bars settling on their value.
    static var data: Animation { Motion.spring(Motion.slow) }
    /// Opacity or colour alone.
    static var fade: Animation { .easeOut(duration: Motion.quick) }
}

extension AnyTransition {
    /// Comes up from below and fades in; leaves the same way. A fade with Reduce Motion.
    static var rise: AnyTransition {
        Motion.isReduced ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    /// Grows in from slightly smaller while fading. A fade with Reduce Motion.
    static var pop: AnyTransition {
        Motion.isReduced ? .opacity : .scale(scale: 0.8).combined(with: .opacity)
    }
}

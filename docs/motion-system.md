# Optique motion system

The tokens live in `Optique/Optique/UI/Theme/Motion.swift`. Every animation in the app uses one of the roles below; no view writes its own duration or curve.

## What motion is for in a news app

Optique is read, not watched. Motion is allowed to do three things:

1. **Confirm a touch.** The control reacts under the finger at once.
2. **Keep the reader oriented.** It shows where something came from or went (a story growing out of its card, a sheet coming up, a pill highlight sliding to the chosen topic).
3. **Mark a rare moment.** A first-run tip or an onboarding step may ask for attention. Nothing on a reading surface does.

Anything that does none of these is still. Text never animates while it is being read, tab switches are instant, and lists do not animate their rows in.

## The evidence the numbers come from

| Finding | Source | What it sets here |
|---|---|---|
| A response under about 0.1 s feels instantaneous; about 1 s is the limit for an unbroken train of thought. | Nielsen, *Response Times: The 3 Important Limits* (via [NN/g, animation duration](https://www.nngroup.com/articles/animation-duration/)) | Press feedback starts on touch-down and lasts 0.15 s. No transition is longer than 0.7 s. |
| Interface animations should be brief; larger screen changes such as a modal are comfortable around 200 to 300 ms, and linear motion looks unnatural. | [NN/g, *Executing UX Animations: Duration and Motion Characteristics*](https://www.nngroup.com/articles/animation-duration/) | The working range is 0.15 to 0.5 s. Nothing that moves uses a linear curve. |
| Animation should be unobtrusive, brief and subtle, and serve feedback or orientation. | [NN/g, *The Role of Animation and Motion in UX*](https://www.nngroup.com/articles/animation-purpose-ux/) | The three jobs above. |
| Entering elements decelerate and take longer (about 400 ms emphasized, 250 ms standard); exiting elements accelerate and are shorter (about 200 ms). | [Material Design 3, easing and duration](https://m3.material.io/styles/motion/easing-and-duration) and its [token spec](https://m3.material.io/styles/motion/easing-and-duration/tokens-specs) | `enter` is 0.4 s, `exit` is 0.2 s and eases in. |
| Material 3 itself now recommends spring physics over fixed easing curves. | [Material Design 3, motion physics](https://m3.material.io/blog/m3-expressive-motion-theming) | Springs for everything that moves. |
| A spring keeps velocity continuous, so it can be interrupted and redirected without a jump; duration and bounce are enough to describe it; bounce is not the reason to use one. | [Apple, WWDC23 *Animate with springs*](https://developer.apple.com/videos/play/wwdc2023/10158/) | Roles are defined as `spring(duration:bounce:)`. Most have no bounce. |
| Start with no overshoot and add bounce only where the gesture has momentum. | [Apple, WWDC18 *Designing Fluid Interfaces*](https://developer.apple.com/videos/play/wwdc2018/803/) | Bounce is limited to `emphasis` and a trace on `morph`. |
| Do not add motion for its own sake; keep feedback brief and precise; avoid custom motion on frequent interactions; never make people wait for an animation. | [Apple Human Interface Guidelines, Motion](https://developer.apple.com/design/human-interface-guidelines/motion) | Tab switches are instant. Frequent actions use the two shortest roles. Springs stay interruptible. |
| With Reduce Motion, replace movement that carries meaning with a dissolve or fade instead of removing it; scaling, spinning and parallax are the effects to drop. | [Apple, Reduced Motion evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria/) | Every role loses bounce and stagger and runs as a short ease; `rise` and `pop` become fades; ambient loops stop. |
| News motion should connect and aid understanding, and credibility argues against exaggerated motion. | BBC GEL motion principles (mirror pages only were found, so treat as secondary) | No bounce on reading surfaces. |

Two caveats. The Material easing-and-duration values are from a system Google no longer maintains, so they are used as bounds, not copied. The BBC material could only be found on mirror sites.

## The roles

| Role | Duration | Shape | Use it for | Examples in the app |
|---|---|---|---|---|
| `press` | 0.15 s | spring, no bounce | A control reacting under the finger | Cards and buttons scaling on touch |
| `select` | 0.30 s | spring, no bounce | A highlight moving to what was chosen | Topic and law pills, tab bar indicator, plan picker, coverage dial, onboarding progress |
| `layout` | 0.35 s | spring, no bounce | Content making room | Folding a law section, tab bar hiding or shrinking, article bars, button label changes |
| `morph` | 0.26 s | spring, 5 % bounce | One element turning into another | Search button growing into the field |
| `enter` | 0.40 s | spring, no bounce | Something arriving | Free-topics badge, lock banner, staged content on the paywall and onboarding |
| `exit` | 0.20 s | ease in | Something leaving for good | Debug toast clearing |
| `surface` | 0.45 s | spring, no bounce | A large surface moving | Comments sheet, onboarding step change |
| `emphasis` | 0.50 s | spring, 22 % bounce | The few moments meant to be noticed | Coverage tip, onboarding source arc and alert preview, profile dominant lean |
| `data` | 0.70 s | spring, no bounce | Figures and bars settling on a value | Profile counters, free-topics meter |
| `fade` | 0.20 s | ease out | Opacity or colour alone | Onboarding "Passer", source list loading |

Why these durations: travel distance sets duration. A press moves a few points (0.15 s), a highlight crosses part of the screen (0.3 s), a sheet crosses most of it (0.45 s). `data` is the one deliberate exception above 0.5 s, because the eye has to follow a value changing, not a shape moving. `morph` is shorter than its size suggests because it was tuned by hand to feel immediate.

## Rules

- **Springs move, curves fade.** Anything that changes position or size uses a spring role. Opacity and colour use `fade`. Exits use `exit`.
- **Exits are faster than entrances.** The reader has already decided; do not make them watch.
- **Bounce is rare.** Only `emphasis` bounces visibly, and only on first-run or one-time moments.
- **Stagger is short.** `Motion.stagger(index)` adds 0.05 s per item by default and never delays the last item by more than 0.4 s.
- **Transitions come in two shapes.** `.rise` (up from below with a fade) and `.pop` (grows from 80 % with a fade). Navigation uses the system push and zoom.
- **Haptics pair with selection, not with movement.** A selection tick accompanies `select`; nothing else vibrates by default.
- **Ambient motion is separate.** The splash, the paywall glow, the skeleton shimmer and the onboarding marquee are slow loops, not transitions. They keep their own timing and all stop with Reduce Motion.

## Reduce Motion

`Motion.isReduced` reads the system setting. When it is on:

- every spring role becomes an ease-out of at most 0.2 s, with no bounce;
- `Motion.stagger` and `Motion.delay` return zero;
- `.rise` and `.pop` become opacity fades;
- the splash, shimmer, marquee and glow loops are paused (already handled where they are defined).

## Known exceptions

- **Splash.** Its timings were tuned by hand and are kept. Only the logo pillars use `emphasis`.
- **Scroll-driven effects** (pills scrolling away, law step cards scaling as they pass) follow the finger and have no duration.
- **Onboarding step transitions** keep their custom slide-and-blur shapes; their timing comes from `surface` and `enter`.

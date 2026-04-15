# Motion & Transitions Implementation

**Date:** 2026-04-05
**Scope:** Option 1 — Motion & Transitions from visual polish audit

---

## Changes Summary

Implemented **4 animation systems** to replace static SwiftUI defaults:

### 1. Card Press Interactions ✅
**Files modified:**
- `UI/Components/CardPressStyle.swift` (new)
- `Features/Feed/FeedView.swift`

**Implementation:**
- Custom `CardPressStyle` ButtonStyle with spring physics
- Scale: 0.97x on press (3% reduction)
- Opacity: 0.9 on press (10% transparency)
- Spring parameters: `response: 0.3, dampingFraction: 0.6`
- Applied to all NavigationLink instances in FeedView

**Visual effect:** Cards now "press in" with momentum when tapped, providing haptic-like visual feedback.

---

### 2. Bookmark Button Animation ✅
**Files modified:**
- `Features/Feed/HeroCardView.swift`
- `Features/Feed/StoryCardView.swift` (2 instances)
- `Features/Story/StoryDetailView.swift`

**Implementation:**
- SF Symbol `.bounce` effect on bookmark state change
- Spring animation wrapper: `response: 0.3, dampingFraction: 0.5`
- Triggers on `bookmarks.isBookmarked(story)` value change

**Visual effect:** Bookmark icon bounces and scales when toggled (iOS 17+ native symbol animation).

---

### 3. Hero Card Parallax ✅
**Files modified:**
- `Features/Feed/HeroCardView.swift`

**Implementation:**
- GeometryReader-based scroll position tracking
- Image offset: `min(200, max(-200, scrollOffset * 0.3))`
- Parallax factor: 0.3 (image moves 30% of scroll speed)
- Clamped to ±200pt to prevent excessive translation

**Visual effect:** Hero card image translates vertically as user scrolls, creating depth separation between image and card chrome.

---

### 4. Navigation Zoom Transitions ✅
**Files modified:**
- `Features/Feed/FeedView.swift`

**Implementation:**
- iOS 18+ `.navigationTransition(.zoom)` with matched geometry
- `@Namespace` for transition coordination
- `.matchedTransitionSource(id:in:)` on all story cards
- Smooth zoom from card → detail view

**Visual effect:** Story cards morph into detail view with native iOS 18 zoom transition (falls back to push on iOS 17).

---

## Technical Details

### Spring Physics
All animations use `.spring()` instead of linear `.animation()`:
- **Response:** Time to complete one oscillation (0.3s standard)
- **Damping:** Friction factor (0.5–0.6 for snappy feel)

### Performance
- All animations run on main thread (lightweight transforms)
- No custom CALayer animations required
- Native SwiftUI modifiers throughout

### Accessibility
- Animations respect system Reduce Motion settings (handled by SwiftUI)
- No layout shifts, only visual transforms
- VoiceOver unaffected

---

## Before/After

**Before:**
- Instant card taps (no feedback)
- Static bookmark toggle
- Fixed hero image
- Linear navigation push

**After:**
- Spring-dampened card press (0.97x scale)
- Bouncing bookmark icon
- Parallax hero image (0.3x scroll speed)
- Zoom navigation transitions (iOS 18+)

---

## Next Steps (Optional)

### Remaining from original plan:
- **Tab chip momentum:** Horizontal scroll deceleration with physics
- **Coverage chart fills:** Animated bar chart reveal on appearance
- **Bottom sheet animations:** Paywall/settings with spring-dampened drag

### Suggested additions:
- **List item stagger:** Sequential appearance delays for feed items
- **Image fade-in:** Smooth AsyncImage reveal with transition
- **Pull-to-refresh glow:** Custom refresh indicator with spring bounce

---

## Files Changed (6 total)

1. `UI/Components/CardPressStyle.swift` — new custom ButtonStyle
2. `Features/Feed/FeedView.swift` — namespace + card sources + zoom transition
3. `Features/Feed/HeroCardView.swift` — parallax + bookmark animation
4. `Features/Feed/StoryCardView.swift` — bookmark animation (2 instances)
5. `Features/Story/StoryDetailView.swift` — toolbar bookmark animation

**Lines changed:** ~60 additions, ~15 removals
**Build status:** Compatible with iOS 17+ (zoom transition iOS 18+ only)

# Design System

Direction (2026-10-29): **black or white, Geist, Regular/Medium only.** The UI is monochrome (black, white, greys) and follows the system light/dark theme; the only color is the 7-position political spectrum. A debug gallery lives in Réglages → Développeur → Design system.

## Colors (`UI/Theme/DesignTokens.swift`, `AdaptiveTokens.swift`)

### Semantic (`AppColors.Adaptive`, light / dark)
| Token | Light | Dark | Use |
|---|---|---|---|
| background | #FFFFFF | #000000 | Page |
| cardSurface | #F4F4F4 | #111111 | Cards, grouped rows |
| surfaceElevated | #E9E9E9 | #1E1E1E | Chips, sheets, banners |
| textPrimary / Secondary / Body / Tertiary / Meta | #000 / 1F1F1F / 3A3A3A / 5F5F5F / 707070 | #FFF / EDEDED / D2D2D2 / A3A3A3 / 8E8E8E | Text hierarchy |
| placeholder | #E4E4E4 | #1C1C1C | Skeletons |
| divider / stroke | black 10 % / 8 % | white 12 % / 10 % | Lines, borders |
| imageScrim | black 0 → 92 % gradient | same | Text over photos (always white text) |

`AppColors.Neutral` is a fixed grey scale kept only for building tokens.

### Brand (`AppColors.Brand`)
No brand color. `accent` = ink (black on white / white on black), `accentSoft` = ink 10–14 %, `onInk` = inverse (text on ink fills such as primary buttons), `onImage` = white.

### Spectrum (`AppColors.Spectrum`, `PoliticalLean.spectrumColor`)
5 positions (since 2026-10-29 centre-gauche is merged into gauche and centre-droite into droite): red → grey → blue, each with a light-theme and dark-theme value (≥ 3:1 on its background):
EG #A81F26 / #C2272D · G #D9383F / #EF5A5F · C #86868C / #B5B5BA · D #3A6FE0 / #4F86F7 · ED #2442B8 / #2D55D8.
`tagTextColor` is adaptive (≥ 4.5:1 on a solid fill). `code` = EG/G/C/D/ED. `PoliticalLean` raw values stay on the stored 1–7 scale (1, 2, 4, 6, 7); `PoliticalLean.from(_:)` folds a stored 3 into gauche and 5 into droite, and `CoverageStats.countsByLean` / `share(of:)` fold the matching counts.

## Typography (`UI/Theme/Typography.swift`)
**Geist** (variable font, named instances `Geist-Regular`, `Geist-Medium`) everywhere. Weights are capped at Medium: hierarchy comes from size and Regular vs Medium. All tokens use `Font.custom(_, size:, relativeTo:)` so they follow Dynamic Type.
appDisplay 34 M · appLargeTitle 28 M · appTitle1 22 M · appTitle2 20 M · appTitle3 18 M · appHeadline 17 M · appBody 17 R · appSubheadline 15 R · appFootnote 13 M · appCaption1 12 M · appCaption2 11 R · appOverline 11 M (+ `.overlineStyle()`: uppercase, tracked). Use `.geist(size, .regular|.medium, relativeTo:)` for one-offs and `UIFont.geist` for UIKit. `UI/Theme/AppAppearance.swift` applies Geist to the navigation bar, tab bar items, segmented controls and search field; system alerts, context menus and the share sheet stay in the system font. Barlow Condensed was removed.

## Spacing & radii
Unchanged: `AppSpacing` 4-pt grid (xs 4 … xxxl 64), `AppRadius` (xs 4 … xl 20, pill).

## Components (`UI/Components`)
- **SpectrumBar** — `.compact` (proportional line, `barHeight`) and `.detailed` (verdict, logos stacked per position, 7-step axis, left/centre/right shares; wraps at large text sizes). Single VoiceOver label with the shares and verdict.
- **StoryHeroCard** — photo card (text over photos is always white on the scrim, in both themes), `.large` 4:5 / `.medium` 3:2; text under the photo at accessibility text sizes.
- **StoryRow** — overline meta, headline, spectrum line + verdict, scaled thumbnail (hidden at accessibility sizes).
- **SourceAvatarView / SourceStack** — logo (from `/api/logo`) or initial on lean color; overlapping stack with "+N".
- **LeanTagView** — chip with color dot, optional share.
- **SectionHeader**, **RemoteImage** (fading AsyncImage with tinted placeholder), **Shimmer / SkeletonLines** (static with Reduce Motion), **OptiqueButtonStyle** (`.optiquePrimary` light capsule, `.optiqueSecondary` elevated), **CardPressStyle**, **TopicPickerGrid** (1 column at accessibility sizes), **PaywallBannerView**, **OwnershipBreakdownView**.

## Accessibility checks done (2026-10-28)
- Largest accessibility text size on iPhone 18 Pro Max: feed and story detail checked, layouts adapt (hero stacks, rows drop thumbnails, spectrum shares and verdict wrap, axis codes capped at xxxLarge).
- Touch targets ≥ 44 pt on custom close buttons; icon-only toolbar buttons have labels.
- Not checked: a small-screen device (only one simulator installed), VoiceOver end-to-end, Reduce Transparency.

## Working on a screen without rebuilding (debug builds only)

1. **Xcode previews** — every shared component and main screen has `#Preview`s (normal, large text, edge cases). In previews the repositories return offline fixtures (`Core/Models/Fixtures.swift`, active when `XCODE_RUNNING_FOR_PREVIEWS=1`, `--fixtures` or `--screen`).
2. **Screen launcher** — open one screen directly with fixture data:
   `xcrun simctl launch <udid> com.flow.optique --screen <name> [--state normal|loading|empty|error] [--text-size xs…xxxl|ax1…ax5] [--story <n>]`
   Screens: feed, story, thread, explorer, topic, sources, source, profile, alerts, settings, onboarding, paywall, gallery. Code: `App/DebugScreenHost.swift`.
3. **Live reload (simulator)** — install InjectionIII (Mac App Store / github.com/johnno1962/InjectionIII), run it, open the project. Debug simulator builds link with `-interposable` and load its bundle at launch; `RootView` re-renders on each injection. Not set up on device.

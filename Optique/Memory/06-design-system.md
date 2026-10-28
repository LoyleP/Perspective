# Design System

Direction: **dark, image-led** (2026-10-28). The app is permanently dark (`.preferredColorScheme(.dark)` in `OptiqueApp`); there is no theme setting. A debug gallery of everything below lives in Réglages → Développeur → Design system.

## Colors (`UI/Theme/DesignTokens.swift`, `AdaptiveTokens.swift`)

### Ink scale (`AppColors.Neutral`)
n50 #F5F5F4 · n100 #E7E7E5 · n200 #D4D4D2 · n300 #B4B4B1 · n400 #8E8E8B · n500 #6B6B69 · n600 #4A4A49 · n700 #2E2E2F · n800 #202022 · n900 #151517 · n950 #0A0A0B

### Semantic (`AppColors.Adaptive`, static)
| Token | Value | Use |
|---|---|---|
| background / feedBackground | n950 | Page |
| cardSurface / detailSurface | n900 | Cards, grouped rows |
| surfaceElevated | n800 | Chips, sheets, banners |
| textPrimary / Secondary / Body / Tertiary / Meta | n50 / n100 / n200 / n300 / n400 | Text hierarchy |
| placeholder | n800 | Skeletons |
| divider, stroke | white 8 % | Lines, borders |
| imageScrim | black 0 → 92 % gradient | Text over photos |

### Spectrum (`AppColors.Spectrum`, `PoliticalLean.spectrumColor`)
Diverging red → grey → blue with symmetric lightness (outer dark, middle mid, inner light), every step ≥ 3:1 on n950:
EG #C2272D · G #EF5A5F · CG #F5A3A6 · C #B5B5BA · CD #A3BEFA · D #4F86F7 · ED #2D55D8.
`tagTextColor` gives ≥ 4.5:1 text on a solid fill (white on EG/ED, ink elsewhere). `PoliticalLean.color` is an alias. `code` = EG/G/CG/C/CD/D/ED.

### Brand (`AppColors.Brand`)
accent #FFB547 (amber — never red or blue, so it never reads as a position), accentSoft = accent 16 %.

## Typography (`UI/Theme/Typography.swift`)
All SF Pro on Dynamic Type text styles:
appDisplay (largeTitle bold) · appLargeTitle (title heavy, headlines on photos) · appTitle1 (title2 bold) · appTitle2 (title3 bold, section titles) · appTitle3 (title3 semibold) · appHeadline · appBody · appSubheadline · appFootnote (medium) · appCaption1 (caption semibold) · appCaption2 · appOverline (caption2 semibold) + `.overlineStyle()` (uppercase, tracked). Barlow Condensed Bold is used only for the "L'essentiel" rank numbers (`relativeTo: .title`). Geist is registered but unused.

## Spacing & radii
Unchanged: `AppSpacing` 4-pt grid (xs 4 … xxxl 64), `AppRadius` (xs 4 … xl 20, pill).

## Components (`UI/Components`)
- **SpectrumBar** — `.compact` (proportional line, `barHeight`) and `.detailed` (verdict, logos stacked per position, 7-step axis, left/centre/right shares; wraps at large text sizes). Single VoiceOver label with the shares and verdict.
- **StoryHeroCard** — photo card, `.large` 4:5 / `.medium` 3:2; text under the photo at accessibility text sizes.
- **StoryRow** — overline meta, headline, spectrum line + verdict, scaled thumbnail (hidden at accessibility sizes).
- **SourceAvatarView / SourceStack** — logo (from `/api/logo`) or initial on lean color; overlapping stack with "+N".
- **LeanTagView** — chip with color dot, optional share.
- **SectionHeader**, **RemoteImage** (fading AsyncImage with tinted placeholder), **Shimmer / SkeletonLines** (static with Reduce Motion), **OptiqueButtonStyle** (`.optiquePrimary` light capsule, `.optiqueSecondary` elevated), **CardPressStyle**, **TopicPickerGrid** (1 column at accessibility sizes), **PaywallBannerView**, **OwnershipBreakdownView**.

## Accessibility checks done (2026-10-28)
- Largest accessibility text size on iPhone 18 Pro Max: feed and story detail checked, layouts adapt (hero stacks, rows drop thumbnails, spectrum shares and verdict wrap, axis codes capped at xxxLarge).
- Touch targets ≥ 44 pt on custom close buttons; icon-only toolbar buttons have labels.
- Not checked: a small-screen device (only one simulator installed), VoiceOver end-to-end, Reduce Transparency.

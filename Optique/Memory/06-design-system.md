# Design System

Direction (2026-10-29): **black or white, Geist, Regular/Medium only.** The UI is monochrome (black, white, greys) and follows the system light/dark theme; the only color is the 7-position political spectrum. A debug gallery lives in Réglages → Développeur → Design system (or `--screen gallery`); its "Tags de couverture" section renders every tag variant from `Fixtures.tagVariants` (mock data, `#if DEBUG` only).

## Colors (`UI/Theme/DesignTokens.swift`, `AdaptiveTokens.swift`)

### Zinc scale (`AppColors.Zinc`)
Every grey is Tailwind CSS **Zinc**: 50 #FAFAFA · 100 #F4F4F5 · 200 #E4E4E7 · 300 #D4D4D8 · 400 #A1A1AA · 500 #71717A · 600 #52525B · 700 #3F3F46 · 800 #27272A · 900 #18181B · 950 #09090B. `Zinc.z50…z950` are `Color`s; `Zinc.Hex.z50…` are the hex strings for theme-switching tokens. The lean (spectrum) colors are separate and unchanged.

### Semantic (`AppColors.Adaptive`, light / dark)
| Token | Light | Dark | Use |
|---|---|---|---|
| background | white | zinc-950 | Page |
| cardSurface | zinc-100 | zinc-900 | Cards, grouped rows |
| surfaceElevated | zinc-200 | zinc-800 | Chips, sheets, banners |
| textPrimary / Secondary / Body / Tertiary / Meta | zinc-950 / 900 / 700 / 700 / 600 | zinc-50 / 100 / 300 / 300 / 400 | Text hierarchy |
| placeholder | zinc-200 | zinc-800 | Skeletons |
| divider / stroke | zinc-950 10 % / 8 % | zinc-50 12 % / 10 % | Lines, borders |
| imageScrim | black 0 → 92 % gradient | same | Text over photos (always white text) |

Text contrast is checked by `DesignTokensTests`: every text level is ≥ 4.5:1 (WCAG AA) on both the page and card surfaces, in both themes. In light mode the text steps start one darker than a straight 950 → 500 ladder because zinc-500 on a zinc-100 card is only 4.4:1.

### Brand (`AppColors.Brand`)
No brand color. `accent` = ink (zinc-950 on white / zinc-50 on zinc-950), `accentSoft` = ink 10–14 %, `onInk` = inverse (text on ink fills such as primary buttons), `onImage` = white.

### Spectrum (`AppColors.Spectrum`, `PoliticalLean.spectrumColor`)
5 positions (since 2026-10-29 centre-gauche is merged into gauche and centre-droite into droite): red → grey → blue, each with a light-theme and dark-theme value (≥ 3:1 on its background):
EG #A81F26 / #C2272D · G #D9383F / #EF5A5F · C #86868C / #B5B5BA · D #3A6FE0 / #4F86F7 · ED #2442B8 / #2D55D8.
`tagTextColor` is adaptive (≥ 4.5:1 on a solid fill; kept for solid-fill chips such as the gallery swatches). `code` = EG/G/C/D/ED. `PoliticalLean` raw values stay on the stored 1–7 scale (1, 2, 4, 6, 7); `PoliticalLean.from(_:)` folds a stored 3 into gauche and 5 into droite, and `CoverageStats.countsByLean` / `share(of:)` fold the matching counts.

## Typography (`UI/Theme/Typography.swift`)
**Geist** (variable font, named instances `Geist-Regular`, `Geist-Medium`) everywhere. Weights: Regular for reading text, Medium for captions, SemiBold for titles (Geist-SemiBold named instance); no Bold. All tokens use `Font.custom(_, size:, relativeTo:)` so they follow Dynamic Type.
Exactly five sizes, enforced by `Font.AppTextSize` (`.geist(_:_:)` and `UIFont.geist(_:_:)` only accept it, so a sixth size won't compile): title 28 · heading 20 · body 16 · reading 14 · caption 13. Tokens: `appTitle` 28 SB · `appHeading` 20 SB · `appBodyStrong` 16 SB (row titles, emphasis) · `appBody` 14 R (paragraphs, bullet points, comments, deks) · `appCaption` 13 M (+ `.overlineStyle()`: uppercase, tracked). Never add a size or a raw `.system`/`.footnote` font; change the enum deliberately instead. `UI/Theme/AppAppearance.swift` applies Geist to the navigation bar, segmented controls and search field; system alerts, context menus and the share sheet stay in the system font. Barlow Condensed was removed.

- **AppHeader / TopicTabs / ProfileAvatarButton** (`UI/Components/AppHeader.swift`) — X-style header (avatar left, logo center) and the sliding topic tab row under it.

## Icons
All icons are **Heroicons 2.2.0** (MIT, heroicons.com), outline 24 px with a few solid variants (user-circle, bookmark, check-circle), stored as template SVGs in `Assets.xcassets/Icons` as `hero-<name>` / `hero-<name>-solid`. Use `HeroIcon("bell", solid:, size:)`, `Label("Title", hero: "bell")` or `ContentUnavailableView("Title", hero: "bell", description:)` (`UI/Components/HeroIcon.swift`); never `Image(systemName:)`. Topic icons: `StoryTopic.heroIcon`. The brand logo (`AppLogo`, `AppLogoTab`) is separate. Still system-drawn (cannot be replaced): the navigation back chevron, the search field magnifier and clear button, `ContentUnavailableView.search`, segmented controls, toggles, disclosure chevrons, alerts/menus/share sheet. The debug menu and design-system gallery still use SF Symbols. To add an icon, copy `package/24/outline/<name>.svg` from the `heroicons` npm package into a new `hero-<name>.imageset` (template rendering, preserve vector data, `currentColor` replaced by `#000000`).

## Spacing & radii
Unchanged: `AppSpacing` 4-pt grid (xs 4 … xxxl 64), `AppRadius` (xs 4 … xl 20, pill).

## Components (`UI/Components`)
- **LeanTags** (`UI/Components/LeanTags.swift`) — the single coverage tag on every story card (hero, `StoryRow`, "L'essentiel" row, Alertes row). Text comes from `CoverageStats.leanVerdict` (one source of truth, also used by the story page header): "Couverture à gauche / au centre / à droite / à l'extrême gauche / à l'extrême droite", "Couverture équilibrée" when no position is ≥ 10 points ahead of the next, "Peu de sources" under 3 sources. Colors are OKLCH tints of the position's hue, chroma 0.032: dark mode = text L 0.936 on a background at L 0.30, light mode = inverted. The right (droite and extrême droite) uses the hand-picked `oklch(0.932 0.032 255.585)`; the gray centre stays neutral. Pill padding 7 × 2, `appCaption`.
- **SideCarouselView** (Features/Story) — horizontal carousel of one card per political side, no color accents (neutral bullets, no colored line). It opens on the position with the highest share (`selected` is initialised in `init`, then re-applied with `ScrollViewReader.scrollTo` on appear). `scrollTransition` scales/dims off-center cards, `viewAligned` snapping, `scrollPosition(id:anchor: .center)`.
- **SpectrumBar** — `.compact` (proportional line, `barHeight`) and `.detailed` (verdict, logos stacked per position, 7-step axis, left/centre/right shares; wraps at large text sizes). Single VoiceOver label with the shares and verdict. Cards no longer show it (replaced by `LeanTags`); it remains on the detailed spectrum, profile and onboarding.
- **StoryHeroCard** — photo on top (4:3 `.large` / 16:9 `.medium`), then: relative time line, headline (≤ 3 lines), then `LeanTags` + `SourceStack` side by side. Text never sits over the photo.
- **StoryRow** — compact row: time line, headline (≤ 3 lines), optional dek, then `LeanTags` + `SourceStack`; trailing photo is a square as tall as the text (`SquareTrailingLayout`, 64–120 pt), hidden at accessibility text sizes.
- **CommentsSheet** (Features/Story) — custom bottom panel (no system sheet, so it can be flush with the screen edges; corner radius 44, grabber only). Keyboard model follows Instagram: content respects the keyboard safe area while the background ignores it and runs behind the keyboard. Opened from "Ajouter un commentaire" (`startsTyping`) it is compact (top comment + composer + emoji row) and its visibility is driven by the keyboard inset, so it rises and drops on the keyboard's own curve (a cold first keyboard stalls before that pass, off screen). Opened from the posted comments it hugs its list (medium detent cap), and pulling the grabber or scrolling up snaps it to full height; dragging down returns to medium, then closes. Exit mirrors entry; the backdrop is instant (no fades).
- **SourceAvatarView / SourceStack** — logo (from `/api/logo`) or initial on lean color; overlapping stack with "+N".
- **LeanTagView** — chip with color dot, optional share (gallery/legacy; cards use `LeanTags`).
- **SectionHeader**, **RemoteImage** (fading AsyncImage with tinted placeholder), **Shimmer / SkeletonLines** (static with Reduce Motion), **OptiqueButtonStyle** (`.optiquePrimary` light capsule, `.optiqueSecondary` elevated), **CardPressStyle**, **TopicPickerGrid** (1 column at accessibility sizes), **PaywallBannerView**, **OwnershipBreakdownView**.

## Accessibility checks done (2026-10-28)
- Largest accessibility text size on iPhone 18 Pro Max: feed and story detail checked, layouts adapt (hero stacks, rows drop thumbnails, spectrum shares and verdict wrap, axis codes capped at xxxLarge).
- Touch targets ≥ 44 pt on custom close buttons; icon-only toolbar buttons have labels.
- Not checked: a small-screen device (only one simulator installed), VoiceOver end-to-end, Reduce Transparency.

## Working on a screen without rebuilding (debug builds only)

1. **Xcode previews** — every shared component and main screen has `#Preview`s (normal, large text, edge cases). In previews the repositories return offline fixtures (`Core/Models/Fixtures.swift`, active when `XCODE_RUNNING_FOR_PREVIEWS=1`, `--fixtures` or `--screen`).
2. **Screen launcher** — open one screen directly with fixture data:
   `xcrun simctl launch <udid> com.flow.optique --screen <name> [--state normal|loading|empty|error] [--text-size xs…xxxl|ax1…ax5] [--story <n>]`
   Screens: feed, story, explorer, topic, sources, source, profile, alerts, settings, onboarding, paywall, gallery. Code: `App/DebugScreenHost.swift`.
3. **Live reload (simulator)** — install InjectionIII (Mac App Store / github.com/johnno1962/InjectionIII), run it, open the project. Debug simulator builds link with `-interposable` and load its bundle at launch; `RootView` re-renders on each injection. Not set up on device.

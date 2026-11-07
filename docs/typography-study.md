# Optique — Typography study and plan

Scope: how the main news apps manage type, what Optique does today, and a plan plus a new font system.
Method: code audit of the app, and web research on 12 products. **Evidence quality is flagged on every claim**: the publishers rarely document *why* they chose a face, so the "why" below is mostly inferred from the foundries' own texts and from what the system does, not from internal design docs.

---

## 1. Summary

1. **The font is not the main problem; the hierarchy is.** Optique uses one family (Geist) in five sizes, 13 / 14 / 16 / 20 / 28. The bottom three are within 3 pt of each other and all use Medium or Regular, so a metadata line, a standfirst and a headline look almost the same. That is why a screen reads as "a lot going on".
2. **Every serious news app separates two voices**: a serif (or at least a distinct headline face) for what you *read*, and a neutral sans for what you *operate or scan* (labels, times, data). Optique has only the second voice, so it has no way to say "this is the story" versus "this is the interface".
3. **Body copy in the benchmark sits at 15–18 px; Optique's reading size is 14 pt.** Apple's own default body is 17 pt.
4. **Competitors keep metadata deliberately quiet and few.** Optique shows up to four stacked text levels plus two graphic chips on one row.
5. **Recommendation:** a two-voice system, **Newsreader (serif) for headlines and reading text + Geist (kept) for interface and metadata**, built as a role-based scale (8 roles, each with size, line height, tracking, weight), plus a "three levels per card" density rule. Fallback with zero licensing/bundle cost: Apple's New York + SF.

---

## 2. Where Optique stands today (audit)

Source: `Optique/UI/Theme/Typography.swift` and a count of every `.font(...)` call in the app.

| Fact | Detail |
|---|---|
| Families | Geist only (one variable file, `Geist-VariableFont_wght.ttf`) |
| Sizes | 28 title · 20 heading · 16 body · 14 reading · 13 caption |
| Steps between sizes | 1.40 · 1.25 · 1.14 · 1.08, so the last two steps are almost invisible |
| Weights in use | Regular (reading text), Medium (captions, some titles), SemiBold (titles). Row titles are *Medium* 16, the same weight as the 13 pt captions around them |
| Usage | ~194 font calls: **caption 45 %** (87), body-reading 23 %, strong body 11 %, heading 7 %, title 6 %, ad-hoc `geist(...)` combos 8 %. Nearly half of all text in the app is the smallest, mid-weight style |
| Tracking (letter spacing) | **None anywhere** (0 uses). Same spacing at 13 pt and 28 pt |
| Line spacing | Hand-set in 10 places (3 or 4 pt), otherwise font default. No line-height token |
| Reading size | 14 pt for paragraphs, below iOS body (17) and the BBC's 15–18 px range |
| Typeface voice | One neutral geometric sans for headlines *and* body *and* labels. No editorial voice |

### What a typical card looks like (StoryRow)

Four stacked text tiers plus two graphic chips and a photo, in about 90 pt of height:

1. `13 medium` grey: time
2. `16 medium` black: headline (2 lines)
3. `14 regular` grey: standfirst (1 line, truncated)
4. lean tag chip + source avatar stack + `+N`

Headline (16 medium) and standfirst (14 regular) differ by 2 pt and one weight step; the caption above is 13 medium. The eye gets no clear entry point, so the reader scans everything. This matches your feedback.

---

## 3. Benchmark

Confidence: **High** = foundry or publisher text; **Medium** = reputable article; **Low** = third-party design-system reconstruction.

| Product | Faces and roles | Why (as far as documented) | Confidence |
|---|---|---|---|
| **The New York Times** | Custom: Cheltenham (serif headlines), Imperial (print body), Franklin (sans, labels / digital), Karnak (rare display). Digital body reported as a Georgia-style serif | One system standardised in 2003 to replace a mix of headline fonts: each face has one job. Sources disagree on digital body; the *rationale* is not documented in what I found | Medium / Low ([overview](https://madegooddesigns.com/new-york-times-font/), [roles](https://www.shadcn.io/design/nytimes)) |
| **The Guardian** | Guardian family by Commercial Type: Egyptian (headlines), Text Egyptian, Sans (headlines, 4 widths), Text Sans | One superfamily cut for every job: "serious news headlines, expressive features, readable text, tiny financial listings, infographics". The text cuts are drawn separately from the headline cuts, with squarer bowls so characters stay open at small sizes | High ([type.today](https://type.today/en/journal/guardian)) |
| **BBC** | Reith (Dalton Maag): serif, sans and condensed | Built to make on-screen text easier to read; benchmarked against the previous fonts; designed to work "without adjusting the tracking". GEL guidance: body 15–18 px, sizes below body "sparingly, and only for supplementary, tangential information", measure 60–70 characters, leading ≥ 1.5 for body | High ([GEL typography](https://bbc.github.io/gel/foundations/typography/), [AbilityNet](https://abilitynet.org.uk/news-blogs/how-bbc-designed-accessible-typeface)) |
| **Financial Times** | Financier (Klim): serif, display and text cuts; Metric (Klim): sans for functional text | Financier was built to work from wide broadsheets to narrow phones: the text cut keeps horizontal efficiency but lowers the x-height for a more elegant tone. Serif for editorial, sans for everything functional | High for Financier ([Poynter](https://www.poynter.org/reporting-editing/2014/financial-times-a-classic-redesign-for-the-digital-age/), [Klim](https://klim.co.nz/in-use/financial-times/)); Low for the app split |
| **Washington Post** | Postoni (Matthew Carter, Bodoni-based headline family); Franklin sans for data/UI. Body face disputed by sources | A custom headline voice for identity; neutral sans for charts and interface | Medium ([Type Network](https://typenetwork.com/articles/washington-post), [Datawrapper](https://www.datawrapper.de/blog/fonts-for-data-visualization)); app not documented |
| **The Economist** | Milo Serif (body) and Econ Sans (headers, charts) | Faces "cut for optimal legibility in digital and print", with better small-size presence | Medium ([Designmodo](https://designmodo.com/the-economist-redesign/)) |
| **Bloomberg Businessweek** | Publico (serif) and Neue Haas Grotesk (sans); Bloomberg's own chart face based on Helvetica | Serif for text, sans for data | Medium ([karlssonwilker](https://karlssonwilker.com/case-study/bloomberg-businessweek)) |
| **Apple News / Apple system** | SF Pro (UI + expressive headlines, with width styles) and New York (serif companion) | Apple's WWDC22 talk: SF is the "editorial voice" in headlines, with Condensed/Compressed widths that cut a headline from five lines to three; the system switches to the Display optical size at ≥ 20 pt. New York has optical sizes so it works as a reading face small and a graphic face large. Whether Apple News uses New York is not officially confirmed | High for SF/New York ([WWDC22](https://developer.apple.com/videos/play/wwdc2022/110381/), [fonts](https://developer.apple.com/fonts/)); Low for News itself |
| **Le Monde** | Historic custom family Le Monde Journal (Porchez, 1994: print); web identity 2012: TheSerif (Lucas de Groot) for editorial content only, Helvetica/Arial for the rest | A distinctive serif reserved strictly for editorial content; a neutral sans for the interface | Medium ([Porchez](https://planete.typographie.org/infos/police/lemonde.html), [Queffelec](https://www.queffelec.fr/projets/le-monde-identite-visuelle)); 2012, may be dated |
| **Libération** | Print relaunch with two custom ultra-condensed faces (Production Type), plus Tiempos Text (Klim) and Produkt (Commercial Type) | Identity-led; app typography not documented | Medium ([Graphiline](https://www.graphiline.com/article/20839/Les-typos-du-nouveau-Liberation-decryptees)) |
| **Medium** | Reported: Charter (serif body), a sans for UI. A 2015 measurement found sizes 28/22/18/14/12 | Charter was drawn for low-resolution output, so it reads well on screens. Medium itself documents none of this | Low ([analysis](https://medium.com/@dmitri145/my-attempt-to-reverse-engineer-mediums-design-part-1-font-size-line-height-and-baseline-e5035b91cd57)) |
| **SmartNews, Ground News, Flipboard, Artifact** | SmartNews: reportedly system fonts. No reliable data for the others | System fonts give instant native rendering across scripts | Low ([SmartNews](https://oh-my-design.kr/design-systems/smartnews)) |

**Gaps I could not close**: I found no primary documentation for the NYT, FT, Post, Ground News, Flipboard or Artifact *apps*, and no recent French app teardown (Le Monde, Le Figaro, Libération). Reading those apps' live interfaces would settle it.

---

## 4. What the leaders have in common

1. **Two voices, clearly separated.** Serif (or a distinct headline face) for the editorial voice; neutral sans for interface, labels, data. NYT, Guardian, BBC, FT, Economist, Bloomberg, Le Monde all do it. Even Apple ships a serif companion.
2. **Faces are cut for a job, not just picked.** Headline, text and "tiny" cuts are drawn separately (Guardian, Financier, New York, Newsreader and Literata via optical size). Small text is looser and sturdier; large text is tighter and finer.
3. **A small set of roles, hierarchy from several signals at once.** Size, family and weight change together. Weight alone (Optique today) is the weakest signal.
4. **Body is generous.** 15–18 px with leading ≥ 1.5 (BBC GEL); measure 60–70 characters. Apple's default body is 17 pt.
5. **Metadata is rationed.** The BBC's rule is explicit: sizes below body "sparingly, and only for supplementary, tangential information". The smallest style is the exception, not the 45 % default.
6. **The simplest apps use the system font** (SmartNews, reportedly). That is a choice for speed and native Dynamic Type, not for character, and it shows that the *structure* matters more than the face.

Caveat on research: the NN/g article I could verify only covers glanceable reading of single words, and the commonly quoted "16 px minimum" and "50–75 characters" figures come from blogs, not NN/g. I rely on the BBC's published guidance and Apple's defaults for numbers.

---

## 5. Diagnosis of Optique

| Symptom you reported | Cause in the code |
|---|---|
| Too much to scan | 4 text tiers + 2 chips per row; dek shown on every row; time, sources, lean tag all competing |
| Hierarchy is unclear | 13 / 14 / 16 are one visual band; headline and caption share the Medium weight |
| Everything looks the same | One family, no tracking differences, no serif/sans contrast |
| Hard to read paragraphs | 14 pt reading size, line spacing patched by hand in 10 places |
| Letter spacing "not managed" | Tracking is never set, anywhere; Geist at 13 pt runs at the same spacing as at 28 pt |

---

## 6. Proposed font system

### Faces

| Voice | Face | Used for | Why |
|---|---|---|---|
| Editorial | **Newsreader** (Production Type, SIL OFL, variable: weight 200–800, optical size 6–72) | Headlines, standfirsts, reading text | Made for continuous on-screen reading in news-style content ([Google Fonts](https://fonts.google.com/specimen/Newsreader)); optical sizing lets one family serve a 16 pt standfirst and a 32 pt headline; free licence; French foundry, strong Latin-extended support for accents |
| Interface | **Geist** (kept) | Time, source names, chips, buttons, tabs, numbers, section titles | Already in the app and the brand; neutral; good at small sizes. Keeping it limits the change to what is broken |

**Alternatives, in order**
- **New York + SF** (system, free, zero bundle weight, automatic Dynamic Type, optical sizes built in). Safest, but looks like Apple News, so less distinctive. In SwiftUI: `.fontDesign(.serif)`.
- **Literata** (TypeTogether, OFL, optical size 7–72, made for Google Play Books reading): excellent for long text, a more bookish tone ([source](https://www.type-together.com/literata-3)).
- **Commercial** (Tiempos Text/Headline from Klim; Guardian-style families): best result, real licence cost; revisit once the structure is proven.

I recommend a one-day **bake-off** (phase 0) with Newsreader, New York and Literata on real French headlines before committing.

### Scale: 8 roles (instead of 5 sizes)

Sizes are pt, relative to a Dynamic Type style so they scale. Line height and tracking are part of the role, not left to each screen.

| Role | Face / weight | Size / line | Tracking | Used for |
|---|---|---|---|---|
| `display` | Newsreader SemiBold, display optical size | 32 / 36 | −0.6 % | Story page headline, hero (large) |
| `headline` | Newsreader SemiBold | 24 / 28 | −0.3 % | Hero (medium), blindspot cards |
| `rowTitle` | Newsreader SemiBold | 18 / 22 | 0 | List rows, "L'essentiel" |
| `standfirst` | Newsreader Regular | 17 / 24 | 0 | Dek under a headline |
| `reading` | Newsreader Regular | 17 / 26 | 0 | Summaries, article text, comments |
| `section` | Geist SemiBold | 20 / 24 | −0.2 % | Section titles ("Thèmes", "Angles morts") |
| `ui` | Geist Medium | 15 / 20 | 0 | Buttons, pills, tabs, row emphasis |
| `meta` | Geist Regular | 13 / 16 | +0.2 % | Time, sources, counts: **one line per card** |
| `label` | Geist Medium | 12 / 14 | +2 % | Chips and tags only |

Why this fixes the band problem: headline-to-meta now differs by **family, size (18 vs 13, ratio 1.4), weight and colour at once**, where today it differs by 3 pt and one weight step.

Rules: Newsreader at 2 weights (Regular, SemiBold), Geist at 3 (Regular, Medium, SemiBold); three text colours only (`textPrimary`, `textBody`, `textMeta`); sentence case, no all caps in French; left-aligned, never justified; measure of ≤ 70 characters on reading text.

### Information diet (the density half of the fix)

A type system alone will not cure "too much information". Proposed card rules:

1. **Maximum three text levels per card**: headline, one meta line, optional standfirst.
2. **One meta line**: merge time and sources into a single line ("Le Monde, Libération +13 · il y a 2 h"); the avatar stack stays, but the separate time line goes.
3. **Standfirst only where it earns its place**: hero and the first one or two rows; no truncated one-line dek on every row.
4. **The lean tag** (`Surtout relayé à gauche`) moves onto the meta line's right side or onto the story page, instead of a fourth tier on every row.
5. **Section headers carry no subtitle** on the home page, only where the section needs explaining.

---

## 7. Implementation plan

**Phase 0 — Bake-off (½–1 day).** Add a specimen screen to `DesignSystemGalleryView` rendering real headlines, standfirsts and a paragraph in Newsreader / New York / Literata at the proposed roles, at default and two larger Dynamic Type sizes. You pick the serif. *Output: decision.*

**Phase 1 — Tokens (1 day).** Replace `Typography.swift` with a `TypeStyle` model (family, weight, size, line height, tracking, Dynamic Type style) and a `.typeStyle(.rowTitle)` modifier that sets font, tracking and line spacing together. Keep `appCaption`, `appBody` etc. as deprecated aliases mapped onto the new roles so nothing breaks. Add the serif files to the bundle and register them. Optical size: either set the `opsz` variation through the font descriptor or ship static optical-size cuts; check bundle size first.

**Phase 2 — Core surfaces (2–3 days).** Migrate in order of exposure: `StoryRow`, `StoryHeroCard`, the "L'essentiel" row, `StoryDetailView` (headline, summary, spectrum), pills and tabs, `SectionHeader`, then Lois rows, Explorer tiles, Profile and Settings, paywall.

**Phase 3 — Density pass (1–2 days).** Apply the card rules in §6 to `StoryRow`, hero, essentials and blindspots; remove duplicated meta.

**Phase 4 — QA (1 day).**
- Dynamic Type from xSmall to AX3 on the 5 densest screens; check truncation and the existing `isAccessibilitySize` fallbacks.
- Long French words, accents, and numerals in headlines.
- Contrast check on the three greys.
- Before/after screenshots of the same 10 stories.

**Phase 5 — Measure (ongoing).** A 5-second test on 5 people (what is the story, who covers it?) before and after; track scroll depth on the feed and time to first story open.

**Risks**
- **Bundle size**: variable serif files can be large; measure before shipping, subset to Latin Extended if needed.
- **Performance**: custom variable fonts with optical sizes cost more at first draw; check scroll on the feed on an older device.
- **Dynamic Type**: custom fonts need explicit scaling (the current code already uses `relativeTo`); keep that.
- **Brand shift**: a serif changes the app's personality noticeably. The bake-off is there so this is a deliberate choice.

## 8. Decisions I need from you

1. Serif direction: Newsreader (recommended), New York (system, free), or Literata?
2. How far on density: type only, or the full "three levels per card" rule too?
3. Should the lean tag stay on every row, or move to the story page?

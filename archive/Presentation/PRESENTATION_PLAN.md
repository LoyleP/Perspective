# Perspective - Presentation Plan (2m30s)

**Format**: Screen recording with camera window + PowerPoint + iPhone Simulator
**Total Duration**: 150 seconds

---

## Recording Setup

- **Left**: PowerPoint presentation (slides advance on cue)
- **Right**: iPhone Simulator running Perspective app
- **Bottom-right**: Camera window (your face)

**Pro tip**: Use QuickTime or OBS. Practice screen recording once to nail the layout.

---

## Timing Breakdown

| Slide | Duration | Cumulative |
|-------|----------|------------|
| 1. Hook + Problem | 20s | 0:20 |
| 2. The Concept | 25s | 0:45 |
| 3. Origin Story | 20s | 1:05 |
| 4. Feed Demo | 25s | 1:30 |
| 5. Story Detail Demo | 30s | 2:00 |
| 6. Monetization + Impact | 20s | 2:20 |
| 7. Closing | 10s | 2:30 |

---

## SLIDE 1: Hook + Problem (20s)

### Visual
- Split-screen comparison: same event, opposite headlines
- Examples: Le Figaro vs Mediapart, or Libération vs Le Point

### Script
> "Same story. Opposite headlines. Sound familiar? French news is fragmented across political lines. Readers stick to their bubble. They never see how the *other side* covers the story. Result: polarization, filter bubbles, zero perspective."

### Simulator Action
- **None yet** (stay on home screen or blank)

---

## SLIDE 2: The Concept (25s)

### Visual
- Perspective logo (centered)
- Tagline: "See Every Side"
- 7-point spectrum graphic: Extrême-gauche → Centre → Extrême-droite
- Color-coded (red → gray → blue)

### Script
> "Perspective fixes this. One story, *every* angle. We aggregate French news articles covering the same event, map each source's political lean—extrême-gauche to extrême-droite—and show you the full spectrum in one place.
>
> Not just aggregation. **Aggregation with political context**. So you can see what Le Figaro says *and* what Mediapart says, side-by-side."

### Simulator Action
- **Launch app** (splash → feed appears)

---

## SLIDE 3: Origin Story (20s)

### Visual
- France map (centered)
- Political spectrum overlay
- Text: "Built for the French Media Ecosystem"

### Script
> "I noticed the problem: in France, readers stay in their bubble. They never see how different parts of the political spectrum cover the same story. **Nobody's built a solution for this**. French media landscape is unique—strong political identities, distinct ownership models. So I built Perspective: one app to break filter bubbles in French news."

### Simulator Action
- **Stay on feed** (let user absorb the UI)

---

## SLIDE 4: Feed Demo (25s)

### Visual
- Annotated screenshot of FeedView with callouts:
  - "Hero story (featured)"
  - "Daily brief (top 2)"
  - "Coverage chart (political breakdown)"
  - "Source count"

### Script
> "Open the app. You see today's top stories. Each story shows:
> - How many sources covered it
> - The political breakdown—bar chart showing left/center/right distribution
> - One tap, you're in.
>
> Hero story at the top. Daily brief below. Zero clutter. Just signal."

### Simulator Action
- **Scroll through feed slowly** (show hero → brief → feed stories)
- **Highlight coverage chart** (point with cursor if possible)

---

## SLIDE 5: Story Detail Demo (30s)

### Visual
- Annotated screenshot of StoryDetailView:
  - "Spectrum summary (AI-generated)"
  - "Articles grouped by political lean"
  - "Ownership breakdown"

### Script
> "Inside a story: articles grouped by political lean. Read the left's take, read the right's take, read center coverage. All in one scroll.
>
> AI-generated spectrum summary (powered by Gemini): 'Here's how the left frames it. Here's the right's angle.' No more guessing. No more accidental bubbles.
>
> And we show ownership: this source is owned by a billionaire. This one's independent. Context matters."

### Simulator Action
- **Tap a story card** → StoryDetailView opens
- **Scroll to spectrum summary** (let it appear)
- **Scroll to articles section** (show lean grouping)
- **Scroll to ownership breakdown** (show owner types)

---

## SLIDE 6: Monetization + Impact (20s)

### Visual
- Freemium model graphic:
  - "5 stories free"
  - "Premium: Unlimited access"
- StoreKit subscription pricing (monthly/annual)

### Script
> "Freemium model: 5 stories free per session. Premium unlocks unlimited access via StoreKit subscriptions—monthly or annual.
>
> Mission: break filter bubbles. Give French readers the full picture. One story at a time."

### Simulator Action
- **Navigate back to feed**
- **Open 5 stories rapidly** (trigger paywall)
- **Show PaywallView** (pricing screen)

---

## SLIDE 7: Closing + Call to Action (10s)

### Visual
- Perspective logo
- Tagline: "See Every Side"
- Text: "Coming Soon" or "Download Now" (based on launch status)
- Optional: QR code or App Store badge

### Script
> "Perspective. See every side. Download now."

### Simulator Action
- **Fade to app icon** or **return to home screen**

---

## Pre-Recording Checklist

### Simulator Prep
- [ ] Launch simulator (iPhone 15 Pro or similar)
- [ ] Clear all previous session data (reset `storiesOpened` if needed)
- [ ] Ensure Supabase has live data (stories with multiple articles)
- [ ] Test: Can you trigger spectrum summary generation?
- [ ] Test: Can you trigger paywall after 5 story opens?
- [ ] Check: Notifications permission already granted (avoid mid-demo prompts)

### PowerPoint Prep
- [ ] Export slides as 16:9 aspect ratio
- [ ] Use presenter notes for script cues
- [ ] Add slide numbers (bottom-right) for timing reference
- [ ] Test: Can you advance slides with keyboard (spacebar) while recording?

### Recording Setup
- [ ] Screen layout: PowerPoint left, Simulator right, Camera bottom-right
- [ ] Test audio: clear, no background noise
- [ ] Lighting: face well-lit
- [ ] Rehearse ONCE with timer (target 2m25s, 5s buffer)

---

## Script Delivery Tips

1. **Energy on slides 1-2**: Hook them hard. Problem → Solution.
2. **Slow down on slide 5**: Most complex. Let visuals breathe.
3. **Pause after "aggregation with political context"**: Let it land (1 second).
4. **Simulator actions = silent moments**: Let UI speak. No need to narrate clicks.
5. **Smile on camera**: Passion sells. You believe in this.

---

## Backup Plan

If demo glitches (network fail, Supabase timeout):
- Pre-record simulator walkthrough separately
- Overlay as B-roll during slides 4-6
- Narrator audio stays live

---

## Post-Recording

- [ ] Watch once: timing on target?
- [ ] Export as MP4 (1080p minimum)
- [ ] Add captions (YouTube auto-generate or manual)
- [ ] Thumbnail: Perspective logo + "See Every Side"

---

**Total prep time**: ~2 hours (1hr rehearsal, 30min recording, 30min export/polish)

**Good luck. You've built something powerful. Show it.**

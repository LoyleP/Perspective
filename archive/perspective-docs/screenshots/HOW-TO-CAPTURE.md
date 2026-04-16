# App Store Screenshots Guide

## Required Sizes

App Store Connect requires screenshots for:

1. **iPhone 6.7"** (iPhone 15 Pro Max, 15 Plus, 14 Pro Max, 14 Plus)
   - Resolution: **1290 × 2796 pixels**
   - Device: iPhone 15 Pro Max simulator

2. **iPhone 6.5"** (iPhone 14 Plus, 13 Pro Max, 12 Pro Max, 11 Pro Max)
   - Resolution: **1242 × 2688 pixels**
   - Device: iPhone 14 Plus simulator

3. **iPad Pro 12.9"** (Optional, if targeting iPad)
   - Resolution: **2048 × 2732 pixels**
   - Device: iPad Pro 12.9" simulator

## How to Capture (Simulator Method)

### Step 1: Run app in simulator

```bash
cd /Users/arthur/Desktop/Coding/Ground\ News\ France/groundnewsfrance
xcodebuild -project groundnewsfrance.xcodeproj \
  -scheme Perspective \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  build
```

Then manually run from Xcode (Cmd+R) with iPhone 17 Pro Max selected.

### Step 2: Take screenshots

**In Simulator:**
- Navigate to desired screen
- Press **Cmd+S** to save screenshot
- Screenshots saved to Desktop by default
- Or: File → New Screen Shot (Cmd+S)

**Alternative - Using xcrun simctl:**

```bash
# List running simulators
xcrun simctl list devices | grep Booted

# Capture screenshot (replace UDID)
xcrun simctl io booted screenshot screenshot-name.png
```

### Step 3: Verify dimensions

```bash
sips -g pixelWidth -g pixelHeight screenshot.png
```

Should match required resolutions exactly.

## Recommended Screenshots (in order)

### 1. Feed View (À la une)
- Show hero story card
- Daily brief visible
- "Cette semaine" tag visible
- Clean, professional look

**How to set up:**
- Open app → Feed tab automatically shown
- Ensure stories loaded
- Light mode recommended (clearer for screenshots)

### 2. Story Detail with Spectrum
- Story detail page
- Spectrum summary visible (TL;DR section)
- Coverage tags at top
- Article thumbnails visible

**How to set up:**
- Tap any story from feed
- Scroll to show spectrum summary clearly
- Ensure "TL;DR" section visible

### 3. Coverage Chart
- Story detail scrolled down
- "Couverture politique" chart visible
- Bar chart showing distribution
- Clean, data-focused

**How to set up:**
- Same story detail page
- Scroll down to coverage chart section
- Center the chart in viewport

### 4. Sources/Ownership View
- Sources list or ownership breakdown
- Show media ownership info
- Spectrum colors visible

**How to set up:**
- From story detail → tap "Propriété des médias"
- Or: Navigate to Discover tab → Sources

### 5. Settings (Optional)
- Settings page
- Show toggle for notifications
- Show theme picker
- Privacy policy link visible

**How to set up:**
- Bottom tab bar → Profile/Settings tab
- Scroll to show key settings

## Tips for Best Screenshots

1. **Use Light Mode** (easier to read on App Store)
   - Settings → Apparence → Clair

2. **Hide Status Bar** (optional, cleaner look)
   - Simulator → Features → Toggle Status Bar (Cmd+Shift+S)
   - Or leave visible (shows time/signal - more realistic)

3. **Ensure Data Loaded**
   - Wait for all images/data to load before capturing
   - No loading spinners in screenshots

4. **Portrait Orientation Only**
   - All screenshots must be portrait
   - Device → Rotate Left/Right if needed

5. **No Placeholders or Lorem Ipsum**
   - Use real news data
   - Ensure articles have loaded

## Processing Screenshots

After capturing, move to organized folder:

```bash
mkdir -p screenshots/iphone-6.7
mkdir -p screenshots/iphone-6.5
mkdir -p screenshots/ipad-12.9

# Move screenshots to appropriate folders
mv ~/Desktop/screenshot-*.png screenshots/iphone-6.7/
```

## Naming Convention

Suggested naming:
- `01-feed.png`
- `02-story-detail.png`
- `03-coverage-chart.png`
- `04-sources.png`
- `05-settings.png`

## Upload to App Store Connect

1. Go to App Store Connect → My Apps → Perspective → App Store tab
2. Scroll to "App Preview and Screenshots"
3. Select device size (6.7", 6.5", iPad)
4. Drag & drop PNG files
5. Reorder if needed (first screenshot = primary)

## Quick Capture Script

Run this after screenshots captured to organize:

```bash
#!/bin/bash
cd /Users/arthur/Desktop/Coding/Ground\ News\ France/groundnewsfrance/screenshots

# Check if screenshots exist on Desktop
if ls ~/Desktop/Simulator*.png 1> /dev/null 2>&1; then
  echo "Moving screenshots from Desktop..."
  mv ~/Desktop/Simulator*.png iphone-6.7/
  echo "✅ Screenshots moved to screenshots/iphone-6.7/"
else
  echo "No screenshots found on Desktop"
fi

# List captured screenshots
echo ""
echo "Captured screenshots:"
ls -lh iphone-6.7/
```

Save as `organize-screenshots.sh`, make executable:

```bash
chmod +x screenshots/organize-screenshots.sh
```

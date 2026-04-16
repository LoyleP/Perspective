# Pre-Submission Testing Checklist

## Build Configuration

- [ ] Test **Release** configuration (not Debug)
- [ ] Build succeeds without warnings
- [ ] Run on physical device (recommended, not just simulator)

## Legal & Privacy

- [ ] Settings → Privacy policy link opens correct URL
- [ ] Settings → Terms link opens correct URL
- [ ] GitHub Pages URLs are live (https://loylep.github.io/Perspective/legal/...)
- [ ] Legal docs display correctly in Safari
- [ ] Contact email visible in legal docs

## Core Functionality

- [ ] App launches without crash
- [ ] Feed loads news stories
- [ ] Tap story → detail view opens
- [ ] Spectrum summary displays
- [ ] Coverage chart renders
- [ ] Articles can be opened in browser (HTTPS only)
- [ ] Bookmarks work (save/remove)
- [ ] Bottom tab navigation works
- [ ] Discover tab loads sources
- [ ] Notifications permission prompt works (if enabled)

## Compliance Checks

### No Paywall UI
- [ ] Story detail page has NO paywall banner
- [ ] No "Upgrade to Premium" prompts anywhere
- [ ] No subscription UI visible
- [ ] All stories open without payment prompt

### Error Handling
- [ ] Turn on Airplane Mode → error shows French message (not debug text)
- [ ] Error message: "Impossible de se connecter. Vérifiez votre connexion internet."
- [ ] No coding paths, type names, or DecodingError details shown to user
- [ ] Retry button works

### HTTPS Enforcement
- [ ] Articles open in WKWebView
- [ ] Only HTTPS URLs load (HTTP blocked)
- [ ] Check console logs for "⚠️ Blocked non-HTTPS URL" if needed

### Debug Features Hidden
- [ ] Settings → No "Développeur" section visible (Release build)
- [ ] No premium toggle visible
- [ ] No "Tester les notifications" button
- [ ] No "Rejouer l'onboarding" button

## User Experience

- [ ] Onboarding shows on first launch
- [ ] Theme picker works (Clair / Sombre / Système)
- [ ] Dark mode renders correctly
- [ ] Swipe actions work (bookmark from feed)
- [ ] Navigation animations smooth
- [ ] Loading states show ProgressView (not blank)
- [ ] Empty states display correctly
- [ ] Refresh works (pull to refresh on feed)

## Data & Storage

- [ ] Bookmarks persist after app restart
- [ ] Theme preference persists
- [ ] Onboarding only shows once
- [ ] No data sent to servers (app is read-only)
- [ ] No authentication required

## Permissions

- [ ] Only notification permission requested (optional)
- [ ] No location, camera, microphone, contacts requested
- [ ] Permission can be denied without breaking app

## Network & API

- [ ] Supabase credentials loaded from build settings
- [ ] Stories fetch successfully
- [ ] Sources fetch successfully
- [ ] Error handling works (disconnect network → reconnect)
- [ ] No hardcoded API keys visible in source code

## App Icon & Metadata

- [ ] App icon displays on home screen
- [ ] Launch screen shows briefly (no errors)
- [ ] App name "Perspective" visible
- [ ] Bundle identifier correct
- [ ] Version number correct (Info.plist auto-generated)

## Accessibility (Optional but Recommended)

- [ ] VoiceOver works on main UI elements
- [ ] Dynamic Type scales text
- [ ] Color contrast sufficient (dark mode)

## Memory & Performance

- [ ] No memory warnings during normal use
- [ ] App doesn't crash after ~5 min of use
- [ ] Scrolling is smooth
- [ ] Images load without blocking UI

## Testing Commands

### Build Release on Simulator
```bash
cd "/Users/arthur/Desktop/Coding/Ground News France/groundnewsfrance"
xcodebuild -project groundnewsfrance.xcodeproj \
  -scheme Perspective \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

### Build Release on Device
```bash
cd "/Users/arthur/Desktop/Coding/Ground News France/groundnewsfrance"
xcodebuild -project groundnewsfrance.xcodeproj \
  -scheme Perspective \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  build
```

### Archive for App Store
```bash
xcodebuild -project groundnewsfrance.xcodeproj \
  -scheme Perspective \
  -configuration Release \
  -archivePath ./build/Perspective.xcarchive \
  archive
```

Then distribute via Xcode Organizer:
1. Xcode → Window → Organizer
2. Select archive
3. Distribute App → App Store Connect
4. Upload

## Sign-Off

When all items checked:

- [ ] All critical issues resolved
- [ ] All high-priority issues resolved
- [ ] Legal documents live and accessible
- [ ] Screenshots captured and organized
- [ ] Ready for App Store submission

**Tested by:** _______________
**Date:** _______________
**Build Number:** _______________
**Notes:** _______________

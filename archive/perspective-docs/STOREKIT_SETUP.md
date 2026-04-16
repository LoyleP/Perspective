# StoreKit 2 Implementation Guide

## Overview

Perspective uses StoreKit 2 with **€0.00 pricing** for free subscriptions. This allows:
- Real StoreKit implementation passes App Store review
- No payment processing complexity
- Pricing can be updated remotely in App Store Connect without code changes
- Users subscribe for free during MVP testing phase

## Product IDs

Two auto-renewable subscription products:
- **Monthly**: `perspective.premium.monthly`
- **Annual**: `perspective.premium.annual`

## App Store Connect Setup

### Step 1: Create Subscription Group

1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **My Apps** → **Perspective** → **In-App Purchases**
3. Click **Create** → **Auto-Renewable Subscriptions**
4. Create subscription group named **"Premium"**

### Step 2: Create Monthly Subscription

1. In the Premium group, click **Create Subscription**
2. Fill in details:
   - **Product ID**: `perspective.premium.monthly`
   - **Reference Name**: Premium Monthly
   - **Subscription Duration**: 1 Month

3. Add localization (French):
   - **Display Name**: Premium Mensuel
   - **Description**: Accès mensuel illimité à Perspective+

4. **Pricing**:
   - Select **France** in territories
   - Set price to **€0.00** (free)
   - All territories: €0.00

5. Save

### Step 3: Create Annual Subscription

1. In the Premium group, click **Create Subscription**
2. Fill in details:
   - **Product ID**: `perspective.premium.annual`
   - **Reference Name**: Premium Annual
   - **Subscription Duration**: 1 Year

3. Add localization (French):
   - **Display Name**: Premium Annuel
   - **Description**: Accès annuel illimité à Perspective+ avec 37% de réduction

4. **Pricing**:
   - Select **France** in territories
   - Set price to **€0.00** (free)
   - All territories: €0.00

5. Save

### Step 4: Submit for Review

Once both subscriptions are created:
1. Click **Submit for Review** on each product
2. Provide screenshot showing paywall UI
3. Provide test instructions: "Tap any story 5 times to trigger paywall, tap purchase button"

## Sandbox Testing

### Setup Sandbox Test Account

1. Go to **App Store Connect** → **Users and Access** → **Sandbox Testers**
2. Create a new sandbox tester with a **French Apple ID**
3. **Important**: Use a unique email that's never been used with a real Apple ID

### Test on Device/Simulator

1. Open Xcode project
2. Select **Product** → **Scheme** → **Edit Scheme**
3. Under **Run** → **Options**, set **StoreKit Configuration** to `Perspective.storekit`
4. Run app on simulator
5. Open 5 stories to trigger paywall
6. Tap purchase button → StoreKit sandbox dialog appears
7. Confirm purchase (no password needed in sandbox)
8. Verify premium features unlock

### Verify Subscription Status

In debug logs, look for:
```
✅ Loaded 2 products
✅ Purchase successful: perspective.premium.monthly
ℹ️ Active subscriptions: ["perspective.premium.monthly"]
```

## Restore Purchases

Users can restore purchases via:
1. Paywall screen → "Restaurer les achats" button
2. Settings → Premium section (when implemented)

Restore calls `StoreManager.restorePurchases()` which syncs with App Store.

## Updating Pricing Later

When ready to charge users:

1. Go to App Store Connect → In-App Purchases
2. Select each subscription
3. Update price (e.g., Monthly to €3.99, Annual to €29.99)
4. Submit price change for review
5. **No code changes required** — StoreKit automatically fetches new prices via `Product.displayPrice`

## Implementation Architecture

### Files

- `StoreManager.swift`: StoreKit 2 integration (product loading, purchasing, transaction verification)
- `SessionState.swift`: Premium status check via `storeManager.isPremium`
- `PaywallView.swift`: SwiftUI paywall with real purchase flow
- `AppConfig.swift`: Product ID constants
- `Perspective.storekit`: Local StoreKit configuration for Xcode testing

### Premium Check Flow

```swift
// SessionState computed property
var isPremium: Bool {
    #if DEBUG
    return UserDefaults.standard.bool(forKey: "devIsPremium") || storeManager.isPremium
    #else
    return storeManager.isPremium
    #endif
}
```

- In **Debug builds**: Toggle in Settings → Debug section
- In **Release builds**: Only real StoreKit subscriptions unlock premium

### Transaction Verification

All purchases are verified using `VerificationResult`:
```swift
private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .unverified:
        throw StoreError.failedVerification
    case .verified(let safe):
        return safe
    }
}
```

Unverified transactions are rejected (prevents jailbreak piracy).

## Testing Checklist

- [ ] Products load successfully (check console logs)
- [ ] Paywall shows "0,00 €/mois" and "0,00 €/an" pricing
- [ ] Purchase flow completes without errors
- [ ] Premium status persists across app launches
- [ ] Restore purchases works after reinstalling app
- [ ] Debug toggle in Settings still works in Debug builds
- [ ] Release build shows no debug UI elements

## App Store Review Notes

When submitting app:
1. **In-App Purchases section**: Select both subscription products
2. **Demo account**: Provide sandbox tester credentials
3. **Review notes**: "Subscriptions are currently set to €0.00 for beta testing. Pricing will be updated to €3.99/month and €29.99/year after user feedback."

## Troubleshooting

### Products not loading

Check console logs for:
```
❌ Failed to load products: [error details]
```

**Solution**: Verify product IDs in App Store Connect match `AppConfig.swift` exactly.

### Purchase fails with "verification failed"

**Solution**: Ensure app is signed with same Team ID as App Store Connect subscription products.

### Sandbox prompts for password repeatedly

**Solution**: Sign out of all Apple IDs in Settings → App Store, then sign in with sandbox tester account.

### "Cannot connect to iTunes Store" in Sandbox

**Solution**: Check internet connection. Sandbox requires network access even for free products.

## Future Enhancements

When implementing paid subscriptions:

1. **Free trial**: Add 7-day free trial in App Store Connect subscription settings
2. **Promotional offers**: Create intro offers for first-time subscribers
3. **Subscription management**: Add link to App Store subscriptions in Settings
4. **Cancellation flow**: Detect when user cancels and show retention offer

## References

- [StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)
- [Testing In-App Purchases](https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases)
- [App Store Review Guidelines 3.1.1](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase)

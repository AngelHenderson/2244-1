# 2244 Release Readiness

Generated: 2026-04-30

Use this as the final engineering and App Store checklist for release
candidates. It is intentionally limited to launch blockers, trust/privacy,
monetization, Firebase, IAP, first-launch UX, and external console work.

## Automated Local Gate

Run before archiving:

```bash
node scripts/validate-launch-readiness.mjs
swift test --package-path Packages/GameCore
swift test --package-path Packages/GameApp
swift test --package-path Packages/GameServices
swift test --package-path Packages/GameUI
swift build --package-path Packages/GameUI
xcodebuild -workspace game2244.xcworkspace -scheme game2244 -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -workspace game2244.xcworkspace -scheme game2244 -configuration Release -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## App Store Metadata

- App icon: `AppIcon` is configured in the app target.
- Display name: `Ultimate2244` is set in `Info.plist`; confirm this is the
  intended public name.
- Bundle identifier: `com.ideabloomlabs.game2244`; App Store Connect,
  Firebase, AdMob, Game Center, and provisioning profiles must match it.
- Version/build: `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1`.
- Devices/orientation: iPhone and iPad are targeted; portrait and landscape are
  declared. Confirm screenshots cover the shipped orientations.
- Entitlements: Game Center is enabled in `game2244.entitlements`.
- Privacy: `PrivacyInfo.xcprivacy` declares app-owned UserDefaults usage
  (`CA92.1`); third-party SDK manifests are supplied by their packages.
- Ad tracking: `NSUserTrackingUsageDescription`, AdMob app/ad unit keys, and
  SKAdNetwork entries are present in `Info.plist`.

## No Mock Leakage

- Runtime leaderboard default is `.empty`, not `.mock`.
- Game Center country filters return an empty state instead of synthetic rows.
- Profile compare is debug-only because it uses synthetic players.
- Season history only backfills preview data in Debug builds.
- `LiveMonetizationService` fails closed; live purchases route through
  `PurchaseService`/StoreKit.

## Firebase

- Deploy `firebase/firestore.rules` and Cloud Functions from `firebase/`.
- Enable anonymous auth.
- Confirm `GoogleService-Info.plist` exists locally in `2244/game2244/` and
  matches `com.ideabloomlabs.game2244`.
- The release credential file is removed from the current git index and ignored.
  If the repo is shared outside the release team, rotate Firebase credentials
  and purge any historical committed copies before publishing.
- Run the Firebase smoke checklist in `Docs/FIREBASE_INTEGRATION_GUIDE.md`.

## IAP / StoreKit

- Confirm all 13 product IDs in `Docs/IAP_CATALOG.md` exist in App Store
  Connect with matching type, localization, pricing, and review screenshots.
- Attach all one-time IAPs, subscriptions, and Game Center leaderboards to the
  submitted app version.
- Run the sandbox-purchase checklist in `Docs/IAP_CATALOG.md`.

## UMP / Privacy

- In an EU/EEA test region, confirm the consent flow appears before ad requests
  and Settings exposes "Ad Privacy Choices" when required.
- In a non-EU test region, confirm the app does not block launch or rewards on a
  missing privacy form.
- If UMP cannot present, Home falls back to Settings and Settings surfaces an
  inline unavailable message.
- Complete App Store Connect App Privacy answers and AdMob Privacy & messaging
  forms before review.

## First Launch

- Fresh install should show How to Play automatically in Release builds until
  `PlayerReadinessStore.markTutorialCompleted()` persists completion.
- Debug builds suppress automatic tutorial presentation, but the release branch
  is covered by `FirstLaunchTutorialGate` tests.
- Manual delete/reinstall check: delete the app, reinstall, launch, complete
  tutorial, finish one run, force quit, relaunch, and confirm the tutorial does
  not repeat.

## Manual-Only External Checks

- Paid Applications agreement, tax, and banking in App Store Connect.
- IAP/subscription pricing and review screenshot upload.
- Game Center leaderboard metadata and app-version attachment.
- Firebase project deployment and rules playground verification.
- AdMob payment profile, store-listing linkage, consent messages, and limited
  ad serving status.
- TestFlight upload, App Privacy nutrition label, and final Xcode privacy report.

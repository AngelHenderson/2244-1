# 2244 Release Readiness

Generated: 2026-04-30

Use this as the final engineering and App Store checklist for release
candidates. It is intentionally limited to launch blockers, trust/privacy,
monetization, Firebase, IAP, first-launch UX, and external console work.

## Current State Snapshot (2026-04-30)

What is verified done from this machine:

- Repo HEAD: `381945ab` (Address remaining Focus, Trust, And Launch Readiness gaps).
- Firebase project pinned via `firebase/.firebaserc` to the existing Faith
  project, `faith-a5d4c`. `firebase use` from `firebase/` resolves to
  that project; root no longer relies on global state for the Firebase project
  directory.
- `firebase/functions/` TypeScript build passes (`npm install` + `npm run build`
  produces `lib/index.js` and `lib/submitScore.js`). One pre-existing source
  bug fixed: `firebase-functions/v2/https` does not export `logger` in
  `firebase-functions@^5`; replaced `functions.logger` with `import { logger }
  from "firebase-functions"`.
- Firestore rules must be deployed to Faith (`faith-a5d4c`). Previous
  deployment notes against `project-7513530591038917977` no longer apply to
  the active release project.
- `validate-launch-readiness.mjs` passes. Root `firestore.rules` and
  `firebase/firestore.rules` are byte-identical.

Still blocked from this machine:

- Cloud Functions deploy. Confirm whether Faith (`faith-a5d4c`) is on Blaze.
  `cloudfunctions.googleapis.com`, `cloudbuild.googleapis.com`, and
  `artifactregistry.googleapis.com` require Blaze. Until the project is
  upgraded, `submitScore` is not deployed and direct client writes to
  `/leaderboards/{boardId}/scores/{uid}` will be denied (which matches rules,
  but means no leaderboard data lands in Firestore).
- Live game-end smoke writes: cannot run until `submitScore` deploys.
- Live `/players/{uid}/progress/blocked` smoke write: requires a real device
  session and Firebase Console observation; not runnable from this CLI.
- Leaked Firebase Web API key. `2244/game2244/GoogleService-Info.plist` was
  un-tracked in commit `148eaa07`, but the key
  `AIzaSyC6wRiQH9L50oNcnVazu0tFsFkAnDeof7M` (project number 1032642468174)
  remains in git history and is still valid until rotated in the GCP console.

## Required External Actions Before Submission

The numbered items below must be completed in App Store Connect, GCP, AdMob,
or on a device — they cannot be finished from this CLI session.

1. **Upgrade Firebase plan.** Open
   <https://console.firebase.google.com/project/faith-a5d4c/usage/details>
   and confirm the Faith project is on Blaze (pay-as-you-go). Set a budget
   alert if it is not already configured.
2. **Deploy Cloud Functions** once Blaze is active:
   ```bash
   cd firebase
   firebase deploy --only functions --project faith-a5d4c
   ```
   Expect a callable `submitScore` to appear in
   `https://console.firebase.google.com/project/faith-a5d4c/functions`.
3. **Rotate the leaked Web API key** in the GCP Console under APIs & Services →
   Credentials. The current value in git history is
   `AIzaSyC6wRiQH9L50oNcnVazu0tFsFkAnDeof7M`. After rotating, regenerate
   `GoogleService-Info.plist` from the Firebase Console (Project Settings →
   Your apps → iOS app), drop the new file at
   `2244/game2244/GoogleService-Info.plist` (still gitignored), and add API key
   restrictions (iOS bundle identifier `com.ideabloomlabs.game2244`, allowed
   APIs limited to Firebase services).
4. **App Store Connect IAP SKUs.** Confirm all 15 SKUs from
   `Docs/IAP_CATALOG.md` exist with matching type, localization, pricing, and
   review screenshots, and are attached to the submitted version.
5. **Sandbox consumables.** Purchase each consumable bundle (Coin Pouch, Gem
   Pack, Power-Up bundles) in TestFlight Sandbox. After purchase, force a
   restore (`SKPaymentQueue.restoreCompletedTransactions`) and confirm the
   ledger key `tx-<id>:<productId>:<index>:<itemType>` blocks a second grant —
   gem balance and inventory must not change.
6. **Sandbox non-consumables / subscription.** Purchase Remove Ads, the Theme
   Pack, Auto-Claim Boosts, individual Pro, and family Pro subscriptions.
   Confirm entitlements gate the appropriate features (no ads, themes unlocked,
   subscription perks active), and that a restore on a clean install re-grants
   without double-counting.
7. **UMP regional check.** With the device region set to an EU/EEA country,
   launch a clean install and confirm Google UMP shows the consent form before
   any ad request and that Settings shows “Ad Privacy Choices.” Switch to a
   non-EU region (e.g. US) and confirm the form does not block launch or
   rewards. If UMP fails to load, Settings should surface an inline
   "unavailable" message.
8. **Release .ipa first-launch tutorial.** Build a Release archive, install
   on a device with no prior install of `com.ideabloomlabs.game2244`, launch,
   and confirm How to Play presents automatically. Complete the tutorial,
   finish one run, force-quit, and relaunch — the tutorial must not reappear.
9. **Live Firestore smoke (post-Blaze).** With the Release build:
   - Complete a non-sandbox run; confirm
     `/leaderboards/global/scores/{uid}` is written and contains
     `highestTileStep`, `composite`, `score`, `seed`.
   - Block a leaderboard player; confirm
     `/players/{uid}/progress/blocked` mirrors the change. Force-quit and
     relaunch; confirm the blocked list still filters that player.
   - Submit a report; confirm `/reports/{id}` lands with `reporterId ==
     request.auth.uid` and that direct client writes to
     `/leaderboards/global/scores/{uid}` are rejected from the Firestore Rules
     Playground.
10. **App Store Connect agreements.** Paid Applications agreement, tax, and
    banking must be signed and active.
11. **AdMob.** Payment profile, store-listing linkage, consent messages, and
    limited-ad-serving status must be set before review.

## Automated Local Gate

Run before archiving:

```bash
node scripts/validate-launch-readiness.mjs
swift test --package-path Packages/GameCore
swift test --package-path Packages/GameApp
swift test --package-path Packages/GameServices
swift test --package-path Packages/GameUI
swift build --package-path Packages/GameUI
FIREBASE_SOURCE_FIRESTORE=1 xcodebuild -workspace game2244.xcworkspace -scheme game2244 -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
FIREBASE_SOURCE_FIRESTORE=1 xcodebuild -workspace game2244.xcworkspace -scheme game2244 -configuration Release -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
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

- Confirm all 15 product IDs in `Docs/IAP_CATALOG.md` exist in App Store
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

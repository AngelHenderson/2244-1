# Current Owner Tasks

This file used to contain the first Firebase leaderboard setup checklist. That
checklist is superseded by the current release docs and active Firebase package.

Use these sources instead:

- `Docs/ReleaseReadiness.md` for App Store, AdMob, IAP, TestFlight, and manual
  release gates.
- `Docs/FIREBASE_INTEGRATION_GUIDE.md` for Firebase smoke tests and backend
  deployment notes.
- `Docs/IAP_CATALOG.md` for the canonical 15-SKU StoreKit catalog.
- `firebase/README.md` for local Firebase CLI commands.

Current manual work that cannot be completed from the local repo:

1. Complete App Store Connect paid agreements, tax, banking, App Privacy,
   IAP/subscription metadata, pricing, review screenshots, and app-version
   attachment.
2. In Xcode Cloud, set Development Workflow environment variable
   `FIREBASE_SOURCE_FIRESTORE` to `1` before running Archive - iOS.
3. Complete AdMob payment/profile setup, store-listing linkage, consent
   messages, and limited-ad-serving checks.
4. Run TestFlight sandbox purchases and restores for every IAP/subscription SKU.
5. Run real-device Firebase smoke tests for leaderboard writes, progress sync,
   blocked-player sync, and report submission.

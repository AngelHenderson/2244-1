# 2244 Cloud Functions

Server-side logic the iOS app expects.

## Functions

| Trigger | Purpose | Status |
|---|---|---|
| `onReportCreated` (`reports/{reportId}` create) | De-dupes player reports, tallies abuse points on the reported player, escalates to ban after threshold | Implemented |
| `onPurchaseCreated` (`players/{uid}/purchases/{txnId}` create) | Verifies StoreKit JWS server-side | Stub (commented out) |

## Setup

```bash
npm install -g firebase-tools
firebase login
firebase use --add               # pick the project that matches GoogleService-Info.plist
cd functions && npm install
```

## Deploy

```bash
firebase deploy --only functions,firestore:rules
```

## Local emulator

```bash
firebase emulators:start
```

The iOS app will pick up the emulator automatically if you call
`Firestore.firestore().useEmulator("localhost", 8080)` before any reads
in DEBUG builds — see `FirebaseService` for the wiring point.

## Tunables

Edit the constants at the top of `index.js`:

- `REPORT_COOLDOWN_HOURS` — same reporter → same target rate-limit (default 24h)
- `ABUSE_POINTS_FOR_BAN` — reports needed to trigger a ban (default 5)
- `FIRST_BAN_HOURS` / `SECOND_BAN_HOURS` — temporary ban durations
- `PERMABAN_AFTER_TEMP_BANS` — permaban after this many temp bans

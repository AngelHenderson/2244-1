# Firebase Leaderboard Integration Guide

This guide covers the complete Firebase leaderboard implementation for Game 2244.

## Overview

The implementation provides:
- ✅ Cross-platform leaderboards (iOS/Android ready)
- ✅ Server-authoritative scoring to prevent cheating
- ✅ Composite scoring system (highest tile > speed > moves > score)
- ✅ Global, daily, and mode-specific leaderboards
- ✅ Anonymous authentication for privacy
- ✅ Seamless integration with existing UI

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   SwiftUI App   │ -> │  GameUI Package │ -> │GameServices Pkg │
│                 │    │                 │    │                 │
│ • Firebase Init │    │ • LeaderboardUI │    │ • LeaderboardSvc│
│ • Env Injection │    │ • Client Bridge │    │ • Firebase Calls│
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Firebase Auth  │    │ Cloud Functions │    │   Firestore     │
│                 │    │                 │    │                 │
│ • Anonymous     │    │ • Score Submit  │    │ • Leaderboards  │
│ • User Identity │    │ • Validation    │    │ • Security Rules│
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Components Implemented

### 1. Core Models (`GameServices`)
- **LeaderboardModels.swift**: Core data structures
- **CompositeScore**: Deterministic ranking algorithm
- **LeaderboardService**: Firebase API integration
- **FirebaseService**: Configuration and auth management

### 2. UI Integration (`GameUI`)
- **FirebaseLeaderboardClient**: Bridge to existing UI
- Uses existing LeaderboardView (no UI changes needed)
- Maintains compatibility with Game Center implementation

### 3. Cloud Backend (`firebase/`)
- **Cloud Functions**: Server-authoritative score submission
- **Firestore Rules**: Security and access control
- **TypeScript**: Validation and composite scoring

## Setup Instructions

### 1. Firebase Project Setup
```bash
# 1. Create Firebase project at console.firebase.google.com
# 2. Enable Authentication (Anonymous)
# 3. Create Firestore database
# 4. Add iOS app with bundle ID: com.game2244.app
```

### 2. Configuration Files
```bash
# Copy your GoogleService-Info.plist to main app target
cp ~/Downloads/GoogleService-Info.plist game2244/GoogleService-Info.plist

# Or use the template and fill in your values
cp firebase/GoogleService-Info-template.plist game2244/GoogleService-Info.plist
```

### 3. Deploy Backend
```bash
cd firebase

# Install Firebase CLI if needed
npm install -g firebase-tools

# Login and init
firebase login
firebase init functions
firebase init firestore

# Install function dependencies
cd functions
npm install

# Deploy everything
firebase deploy
```

### 4. iOS Project Setup
The iOS integration is already complete. Just add GoogleService-Info.plist to your main app target.

## How It Works

### Score Submission Flow
1. **Game completes** -> App calls leaderboard client
2. **Client authenticates** -> Anonymous Firebase auth
3. **Submit to Cloud Function** -> Server validates and scores
4. **Composite calculation** -> Prioritizes tile > speed > moves
5. **Firestore write** -> Only if score is better than existing

### Composite Scoring Algorithm
```swift
// Encodes: tile_step * 10^13 + time_bonus * 10^9 + move_bonus * 10^6 + score
// `highestTileStep` is the AlphaMag step index. The Swift client and the
// Cloud Function both prefer the explicit step over `log2(highestTile)`
// because tiles past 2^62 overflow to Int.max on the wire.
let p = max(2, highestTileStep)
let t = max(0, 10000 - seconds)  // Speed bonus (less time = better)
let m = max(0, 1000 - moves)     // Efficiency bonus (fewer moves = better)
let s = min(score, 999999)       // Raw score (tie-breaker)

composite = p * 10^13 + t * 10^9 + m * 10^6 + s
```

### Run-summary submission

The client now submits a full `GameRunSummary` rather than a score-only
estimate. `LeaderboardClient.submitRun(_:)` is called from
`game2244App.submitGameEndProgress(summary:)` when a non-sandboxed run ends; it
forwards `score`, `scoreAlpha`, `highestTile`, `highestTileStep`, `moves`,
`duration`, `seed`, and `infinityMergeCount`. Mirroring clients (Game Center +
Firebase) call `submitRun` on each backend; the default `submitRun` falls back
to `submitScore(summary.score)` for backends that have not implemented run
submission.

The infinity-tile (Hall of Fame) submission still goes through
`submitInfinityCount(_:)` separately.

### Leaderboard Types
- **Global**: `boardId = "global"`
- **Daily**: `boardId = "daily:YYYY-MM-DD"`
- **Modes**: `boardId = "mode:classic"`

## Security Features

### Server-Authoritative
- All score submissions go through Cloud Functions
- Client cannot write directly to Firestore
- Server recalculates and validates all scores

### Validation Checks
```typescript
// Sanity checks in submitScore (firebase/functions/src/submitScore.ts):
- highestTileStep is provided (or derived from highestTile when small enough)
- highestTileStep in [1, MAX_TILE_STEP] (currently 2000)
- Time in [0, 86400]
- Moves in [0, 1_000_000]
- Score in [0, 1e12]
- Loose move/step relationship: moves >= step * 2.5 (lower bound)
- Composite score recomputed server-side from validated inputs
```

The previous power-of-2 ceiling at 131072 has been removed so alpha/infinity
progression (`1a`, `1b`, `∞`) can land on the leaderboard. The client sends
both `highestTile` and `highestTileStep`; the function prefers `highestTileStep`
because the numeric tile value overflows in JavaScript at very high steps.

### Anti-Cheat Measures
1. **Server validation**: All scores validated on server
2. **Rate limiting**: Built into Cloud Functions
3. **Integrity tokens**: Ready for App Attest/Play Integrity
4. **Anomaly detection**: Server can flag suspicious scores

## Cost Estimation

### Firebase Pricing (Monthly)
- **Authentication**: Free (<50k MAU)
- **Firestore**: ~$1-5 (read/write operations)
- **Cloud Functions**: ~$0.40 (invocations)
- **Total**: <$10/month for moderate usage

### Scaling
- Functions auto-scale to handle traffic spikes
- Firestore handles 1M+ concurrent connections
- Global CDN for low latency worldwide

## Usage in Game

### Submit Score
```swift
// Automatic submission after game ends
// Called from existing LeaderboardView -> LeaderboardModel -> LeaderboardClient
// No changes needed to existing game code
```

### View Leaderboards
```swift
// Already integrated with existing LeaderboardView
// Supports all existing features:
// - Global/Daily/Mode filtering
// - Pagination
// - User rank display
// - Multiple periods (Today/Week/All-Time)
```

## Testing

### Local Development
```bash
# Use Firebase emulators for local testing
firebase emulators:start --only auth,firestore,functions

# Set environment variable to use emulators
export USE_FIREBASE_EMULATORS=true
```

### Credential-free launch validation

Run this from the repo root:

```bash
node scripts/validate-launch-readiness.mjs
```

The script does not require Firebase credentials. It checks that
`firestore.rules` and `firebase/firestore.rules` are synchronized and that the
rules cover the launch paths:

- `/leaderboards/{boardId}/scores/{uid}` is public-read and client-write denied;
- `/players/{uid}` requires the Firebase Auth UID as the document key;
- `/players/{uid}/progress/{document=**}` covers user-owned progress documents;
- `/players/{uid}/progress/blocked` is covered by the progress mirror rule;
- `/players/{uid}/leaderboards/{board=**}` covers per-player leaderboard metadata;
- `/players/{uid}/purchases/{txnId}` covers purchase receipt mirrors;
- `/reports/{id}` is append-only and requires `reporterId == request.auth.uid`.

### Production Testing
- Test with anonymous authentication
- Verify score submissions appear in Firebase Console
- Check leaderboard display in app
- Validate composite scoring is working

### Release smoke-test checklist

These checks require a Firebase project but no production data mutation beyond a
sandbox/test user:

1. Install a fresh build with the release `GoogleService-Info.plist`.
2. Confirm anonymous auth succeeds and the app receives a Firebase Auth UID.
3. Complete or end a non-sandbox run; confirm the Cloud Function writes or
   updates `/leaderboards/global/scores/{uid}`.
4. Confirm `/players/{uid}/progress/state` writes after app background/foreground.
5. Block a leaderboard player, force quit, relaunch, and confirm
   `/players/{uid}/progress/blocked` round-trips and still filters the player.
6. Submit a report from the leaderboard and confirm a new `/reports/{id}` doc
   contains `reporterId`, `reportedPlayerName`, `reason`, and timestamps.
7. Attempt a direct client write to `/leaderboards/global/scores/{uid}` from the
   emulator or Firebase console rules playground and confirm it is denied.

## Monitoring

### Firebase Console
- Monitor authentication usage
- Check Firestore read/write patterns
- View Cloud Functions execution logs
- Track error rates and performance

### Key Metrics
- Daily/Weekly/Monthly active users
- Average scores per user
- Leaderboard engagement rates
- Error rates and latency

## Migration Notes

### From Game Center
- Firebase leaderboards run alongside Game Center
- Users get cross-platform visibility
- Gradual migration possible
- Game Center can still be used for iOS-specific features

### Future Enhancements
1. **Friends system**: Firestore queries for friend leaderboards
2. **Achievements**: Integration with game achievement system
3. **Real-time updates**: Firebase realtime listeners for live leaderboards
4. **Advanced anti-cheat**: Integrate App Attest and Play Integrity
5. **Analytics**: Custom events for leaderboard interactions

## Firestore Rules Source-of-Truth

The deployable rules live at `firebase/firestore.rules` and are picked up by
`firebase deploy --only firestore:rules` via `firebase/firebase.json`. The
root-level `firestore.rules` mirrors that file exactly — keep both in sync.

Both files require:

- `/players/{uid}` — `isOwner(uid)` for read/write. The document key MUST be the
  Firebase Auth UID. `GemWallet.startCloudSync()` now refuses to run when no
  Auth UID is available, since the rule would reject every write.
- `/players/{uid}/progress/{document=**}` — `isOwner(uid)`.
- `/players/{uid}/leaderboards/{board=**}` — read for authed users, write for
  the owner only.
- `/players/{uid}/purchases/{txnId}` — append-only by owner.
- `/reports/{id}` — append-only, must include `reporterId == request.auth.uid`.
- `/leaderboards/{boardId}/scores/{uid}` — public read, **Cloud Function-only
  write**. Direct client writes are rejected; the `submitScore` callable is the
  only legitimate write path.

## Troubleshooting

### Common Issues
1. **GoogleService-Info.plist missing**: Copy from Firebase Console
2. **Authentication fails**: Check bundle ID matches Firebase config
3. **Function errors**: Check logs in Firebase Console
4. **Permission errors**: Verify Firestore rules are deployed
5. **Build errors**: Ensure all package dependencies are resolved

### Debug Tips
```swift
// Enable Firebase debug logging
#if DEBUG
FirebaseConfiguration.shared.setLoggerLevel(.debug)
#endif
```

## Support

- Firebase Documentation: https://firebase.google.com/docs
- Game 2244 Issues: Create GitHub issue with [Firebase] tag
- Firebase Console: https://console.firebase.google.com

---

**Implementation Status**: ✅ Complete and Ready for Production

The Firebase leaderboard system is fully integrated and ready to use. Simply add your GoogleService-Info.plist and deploy the Cloud Functions to go live!

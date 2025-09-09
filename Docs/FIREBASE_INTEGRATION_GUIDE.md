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
// Encodes: highest_tile_power * 10^13 + time_bonus * 10^9 + move_bonus * 10^6 + score
let p = log2(highestTile)  // Exponential weight for higher tiles
let t = max(0, 10000 - seconds)  // Speed bonus (less time = better)
let m = max(0, 1000 - moves)     // Efficiency bonus (fewer moves = better)
let s = min(score, 999999)       // Raw score (tie-breaker)

composite = p * 10^13 + t * 10^9 + m * 10^6 + s
```

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
// Basic sanity checks in submitScore function:
- Highest tile must be power of 2 (4 to 131072)
- Time must be reasonable (0 to 24 hours)
- Moves must be reasonable (0 to 10,000)
- Score must be reasonable (0 to 10M)
- Move/tile relationship validation
```

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

### Production Testing
- Test with anonymous authentication
- Verify score submissions appear in Firebase Console
- Check leaderboard display in app
- Validate composite scoring is working

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
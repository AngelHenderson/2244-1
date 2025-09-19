# Quickstart Guide: Create 2244 - Initial Playable Shell

**Date**: 2025-01-16  
**Feature**: 003-create-2244-initial

## Prerequisites

- Xcode 16.0+
- iOS 18.0+ Simulator or Device
- Swift 6.0
- Active Apple Developer account (for StoreKit testing)

## Setup Steps

### 1. Clone and Open Project
```bash
git checkout 003-create-2244-initial
open game2244.xcworkspace
```

### 2. Configure Signing
1. Select `game2244` target
2. Set your development team
3. Update bundle identifier if needed

### 3. Build and Run
```bash
# Build for simulator
xcodebuild -workspace game2244.xcworkspace \
  -scheme game2244 \
  -configuration Debug \
  -sdk iphonesimulator \
  build

# Or use Xcode: Cmd+R
```

## Feature Validation Checklist

### ✅ Launch & Profile
1. **Launch app** → Should auto-load default profile without login
2. **View main menu** → Should display:
   - Circular hub with 9 feature buttons
   - Vertical progression path (512→1024→2048→4096)
   - Top bar: Rank #231,105, Score 4096, 754 gems
   - Bottom navigation: Profile, Achievements, Leaderboard, Settings
3. **Check initial inventory** → Profile should have:
   - 305 coins, 754 gems
   - 3 Hammers, 2 Swaps, 5 Undos, 1 Shuffle
   - 0 Magnets, 0 Doubles

### ✅ Core Gameplay
1. **Start Classic Seed Demo**
   - Board should be 5×8 grid
   - Tiles should be draggable to form chains
2. **Test chain validation**
   - Connect two identical tiles → Should highlight valid
   - Add third tile (same or double) → Should remain valid
   - Try invalid connection → Should show error feedback
3. **Complete a chain**
   - Release valid chain → Tiles merge
   - Gravity applies → Tiles fall
   - Board refills → New tiles appear
4. **Check deterministic behavior**
   - Note seed in debug console
   - Restart with same seed → Same tile sequence

### ✅ Power-Ups
1. **Use Hammer**
   - Tap Hammer button → Enter selection mode
   - Tap any tile → Tile removed, board adjusts
   - Check inventory decreased by 1
2. **Use Swap**
   - Tap Swap → Select two tiles
   - Tiles exchange positions
3. **Use Undo**
   - Make a move → Tap Undo
   - Board reverts to previous state
4. **Use Shuffle**
   - Tap Shuffle → All tiles randomize
   - Board remains full

### ✅ Audio & Themes
1. **Check default theme**
   - Classic theme should be active
   - Background music playing
   - Sound effects on actions
2. **Switch themes**
   - Open Settings → Theme selector
   - Select Minimal → Music crossfades in <500ms
   - Select Retro → 8-bit music starts
3. **Test premium themes**
   - Cyberpunk, Lofi, Orchestral → Should show purchase prompt
4. **Volume controls**
   - Adjust music volume → Changes immediately
   - Adjust effects volume → Test with tile tap
   - Disable audio → All sounds stop

### ✅ Haptics
1. **Enable haptics** in Settings
2. **Test feedback patterns**
   - Tile selection → Light tap
   - Chain completion → Success pattern
   - Invalid move → Error buzz
   - Power-up activation → Strong impact
3. **Disable haptics** → No vibration feedback

### ✅ Sample Projects & Tasks
1. **Classic Seed Demo tasks**
   - View task list → 7 tasks (3 completed, 2 in progress, 2 not started)
   - Complete "Achieve a 5-tile chain" → Status updates
2. **Daily Challenge tasks**
   - 12 tasks with varied completion states
   - "Submit first score" should be completable
3. **Journey Intro tasks**
   - Stage 1: 5 tasks
   - Stage 2: 9 tasks

### ✅ Daily Challenge
1. **Start Daily Challenge**
   - Uses device local date for seed
   - Same puzzle for entire day
2. **Complete challenge**
   - Score submits to leaderboard
   - Can only submit once per day

### ✅ Challenge Designer
1. **Create custom challenge**
   - Set target score: 10,000
   - Set move limit: 50
   - Select allowed tiles
2. **Save challenge** → Appears in profile
3. **Play custom challenge**
4. **Edit challenge** → Can modify own challenges only

### ✅ Shop & IAP
1. **Open Shop**
   - View products: themes, coin/gem packs, ad-free
   - Prices load from StoreKit
2. **Test purchase** (Sandbox)
   - Purchase ad-free → Ads disappear
   - Purchase theme → Unlocks immediately
   - Purchase gems → Balance updates
3. **Restore purchases** → Previous purchases restored

### ✅ Rewards & Monetization
1. **Free Spin Wheel**
   - Tap Free Spin → Wheel animates
   - Receive reward (coins/gems/power-ups)
   - Next spin available in 24 hours
2. **Watch Ad for Rewards**
   - Tap "Watch Ad" → Rewarded video plays
   - Receive bonus (30 gems default)
   - Daily limit: 5 ads
3. **Time-Limited Offers**
   - Sale Offer → Shows discount percentage
   - Best Offer → Countdown timer (31:10)
   - Daily Deal → Refreshes daily

### ✅ Leaderboards & Social
1. **Game Center Integration**
   - Auto-sign in on launch
   - View global rank (#231,105)
   - Submit scores automatically
2. **Leaderboard Screen**
   - Top 100 players
   - Nearby players (±10 ranks)
   - Weekly/Daily filters
3. **Achievements**
   - Progress tracking (256 reached)
   - Game Center sync

### ✅ External Services
1. **Google AdMob**
   - Banner ad at bottom (if not ad-free)
   - Rewarded videos functional
   - Test ads in debug mode
2. **Firebase Analytics**
   - Events tracking
   - User properties set
   - Remote config values loaded
3. **Push Notifications**
   - Daily reminder (if enabled)
   - Special offers notification

### ✅ Settings & Profile
1. **Profile screen**
   - Shows statistics: games played, high score, etc.
   - Displays achievements
   - Shows currency balances
2. **Settings**
   - All toggles functional
   - Changes persist between sessions

## Performance Validation

### Frame Rate
1. During gameplay → Should maintain 60 FPS
2. During chain animation → No drops below 50 FPS
3. Theme switching → Completes in <500ms

### Audio Latency
1. Tile tap → Sound within 50ms
2. Chain complete → Immediate feedback
3. No audio glitches during crossfade

## Test Data Verification

### Expected Initial State
```json
{
  "profile": {
    "coins": 305,
    "gems": 0,
    "powerUps": {
      "hammer": 3,
      "swap": 2,
      "undo": 5,
      "shuffle": 1,
      "magnet": 0,
      "double": 0
    },
    "currentTheme": "classic",
    "unlockedThemes": ["classic", "minimal", "retro"]
  }
}
```

### Sample Task Distribution
- Classic: 3 completed, 2 in progress, 2 not started
- Daily: 4 completed, 3 in progress, 5 not started
- Journey Stage 1: 1 completed, 1 in progress, 3 not started
- Journey Stage 2: 2 completed, 3 in progress, 4 not started

## Troubleshooting

### Audio Not Playing
- Check device not in silent mode
- Verify audio files in bundle
- Check Settings → Music Volume > 0

### Haptics Not Working
- Verify device supports haptics
- Check Settings → Haptics enabled
- Not available in simulator

### StoreKit Issues
- Ensure signed in to sandbox account
- Check network connection
- Try Store → Restore Purchases

### Performance Issues
- Close other apps
- Check available device storage
- Restart device if needed

## Success Criteria

All items in the Feature Validation Checklist should pass. The app should:
- Launch without authentication
- Play all three sample game modes
- Successfully use all 6 power-up types
- Switch between themes with crossfade
- Track and display sample project tasks
- Handle IAP in sandbox environment
- Maintain 60 FPS during gameplay

## Next Steps

After validation:
1. Run automated test suite
2. Check memory usage in Instruments
3. Verify no console warnings/errors
4. Submit for code review
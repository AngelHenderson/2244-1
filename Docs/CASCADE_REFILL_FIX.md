# Cascade Refill Fix - Natural Top-Down Tile Spawning

## Problem
The auto-cascade system was working, but tiles were spawning randomly throughout the board after merges instead of falling naturally from the top like in match-3 games (Candy Crush, Bejeweled, etc.).

### What Was Happening
```
After merge + gravity:
  [ ]  [ ]  [8]  [4]  [2]
  [4]  [ ]  [2]  [8]  [ ]
  [2]  [8]  [ ]  [4]  [8]
  [8]  [4]  [2]  [ ]  [4]
  [4]  [2]  [8]  [4]  [2]

After refillToFull():
  [16] [32] [8]  [4]  [2]   ← New tiles appear here
  [4]  [64] [2]  [8]  [128] ← And here
  [2]  [8]  [256][4]  [8]   ← And here
  [8]  [4]  [2]  [512][4]   ← Everywhere!
  [4]  [2]  [8]  [4]  [2]
```

This made the game feel chaotic and unnatural - tiles would just appear randomly in the middle of the board.

### What Should Happen (Match-3 Style)
```
After merge + gravity:
  [ ]  [ ]  [8]  [4]  [2]
  [4]  [ ]  [2]  [8]  [ ]
  [2]  [8]  [ ]  [4]  [8]
  [8]  [4]  [2]  [ ]  [4]
  [4]  [2]  [8]  [4]  [2]

Spawn at top only:
  [16] [32] [8]  [4]  [2]   ← New tiles spawn HERE
  [4]  [ ]  [2]  [8]  [ ]
  [2]  [8]  [ ]  [4]  [8]
  [8]  [4]  [2]  [ ]  [4]
  [4]  [2]  [8]  [4]  [2]

Apply gravity → tiles fall:
  [16] [32] [8]  [4]  [2]
  [4]  [8]  [2]  [8]  [8]
  [2]  [4]  [8]  [4]  [4]
  [8]  [2]  [2]  [8]  [2]
  [4]  [ ]  [ ]  [4]  [ ]

Repeat until board is full...
```

## Root Cause

In `performCascadeStep()` (line 1156), the code was calling `refillToFull()` which fills ALL empty cells immediately:

```swift
// Old code - spawns tiles everywhere
applyGravityDown()
refillToFull()  // ❌ Fills all empty cells at once
```

## Solution

Changed to use `refillToFullWithCascade()` which the user had already implemented perfectly! This method:
1. Spawns tiles ONLY at the top row
2. Applies gravity to make them fall
3. Repeats until board is full
4. Creates natural cascading motion

```swift
// New code - natural cascade effect
applyGravityDown()

// Use cascade-aware refill that spawns only from top
if config.fillMode == .alwaysFull {
    refillToFullWithCascade()  // ✅ Spawns from top, applies gravity
} else {
    refillToFull()
}
```

## How It Works Now

### Cascade Flow After Player Move:
1. **Player completes chain** → Tiles merge
2. **Gravity applies** → Tiles fall to fill gaps
3. **Auto-cascade starts:**
   - Find all matching adjacent groups
   - Merge all groups simultaneously
   - Apply gravity again
   - **Spawn new tiles ONLY at top row**
   - **Apply gravity to make new tiles fall**
   - Check for more matches
   - Repeat until no matches found
4. **Award combo bonuses**
5. **Return control to player**

### Visual Sequence (Like Your Images):
```
Frame 1: Matching tiles highlighted
Frame 2: Tiles merge with particle effects  
Frame 3: Empty spaces appear
Frame 4: Gravity - tiles fall down
Frame 5: New tiles spawn at top
Frame 6: New tiles fall down
Frame 7: Board refills naturally
Frame 8: Check for new matches
Frame 9: "Combo x8" displayed if multiple cascades occurred
```

## Testing Results
✅ All AutoCascadeTests pass (4/4)
✅ All GameEngineTests pass (8/8)
✅ No linter errors

## Code Changes

### File: `Packages/GameCore/Sources/GameCore/GameEngine.swift`

**Line 1154-1164**: Changed `performCascadeStep()` to use cascade-aware refill

```swift
// Apply gravity and refill from top (creates natural cascade effect)
applyGravityDown()

// Use cascade-aware refill that spawns only from top
if config.fillMode == .alwaysFull {
    refillToFullWithCascade()
} else {
    refillToFull()
}
```

## Result

Now the game plays exactly like the images you showed:
- ✅ Tiles only spawn from the top
- ✅ Natural falling motion with gravity
- ✅ Cascades flow smoothly top-to-bottom
- ✅ Match-3 style gameplay
- ✅ Satisfying visual effects

The cascade system now works like Candy Crush, Bejeweled, and other match-3 games where tiles always enter from the top and fall naturally downward!

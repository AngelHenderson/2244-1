# Tasks: Audio Chain SFX & Session Reliability

**Branch**: `develop-AJ`
**Files touched**:
- `Packages/GameServices/Sources/GameServices/AudioService.swift`
- `Packages/GameUI/Sources/GameUI/SimplifiedGlassBoardView.swift`
- `Packages/GameUI/Sources/GameUI/BoardView.swift`
- `Packages/GameUI/Sources/GameUI/HybridGameScreen.swift`
- `Packages/GameUI/Sources/GameUI/Challenge/CustomChallengeGameScreen.swift`

---

## Summary of Changes Already Made

The following changes are **already in the codebase** on `develop-AJ`. These tasks document what was done, what to verify, and what remains.

### What changed:
1. **Chain sounds now play instrument taps** (not subtle ticks) — `playSfx("chain")` routes to `playInstrumentTapSound` instead of `playChainTickSound`
2. **First tile plays a "select" sound** — added `playSfx("select")` to `SimplifiedGlassBoardView.beginPath`
3. **Merge plays 1 final note** — `playMergeSfx(tileCount:)` plays a single instrument tap (tiles already sounded during chain building)
4. **Power-up mode suppresses chain sounds** — `isPowerUpActive` flag prevents `beginPath` / select sound from firing during magnet/hammer/swap
5. **Audio session no longer reconfigured on every sound** — removed `setCategory` + `setActive` from `cleanupAndPrepareForNewSound()`; added `ensureAudioSessionActive()` as retry-on-failure fallback

---

## Phase 1: Verification & Manual QA

### T001 — Verify chain sound count per instrument
**File**: `Packages/GameServices/Sources/GameServices/AudioService.swift`
**Action**: On a device/simulator, test each instrument theme and confirm the correct number of sounds:
- **3-tile chain** → 3 notes during building + 1 on merge = **4 total**
- **5-tile chain** → 5 notes during building + 1 on merge = **6 total**
- **2-tile chain** → 2 notes during building + 1 on merge = **3 total**

Test with these instruments (verify note cycling):
| Instrument | `tapSoundCount` | Expected cycle |
|---|---|---|
| piano | 3 | tap_1 → tap_2 → tap_3 → tap_1... |
| xylophone | 2 | tap_1 → tap_2 → tap_1... |
| muted-nylon | 1 | tap_1 → tap_1 → tap_1... |
| guitar | 20 (single file) | note slicing 1–20 |
| kalimba | 12 (single file) | note slicing 1–12 |
| drum | 6 (single file) | note slicing 1–6 |

---

### T002 — Verify magnet power-up sound sequence
**Files**:
- `Packages/GameUI/Sources/GameUI/SimplifiedGlassBoardView.swift` (line ~362, `isPowerUpActive` guard)
- `Packages/GameUI/Sources/GameUI/HybridGameScreen.swift` (line ~493, `isPowerUpActive` param)

**Action**: Activate magnet mode and tap a tile. Confirm:
1. **No instrument tap** plays when you tap the tile (the `isPowerUpActive` guard skips `beginPath`)
2. **Electric zap** plays during the magnet pull animation
3. **One instrument tap** plays after merge completes
4. Second magnet use plays the **next note** in the cycle (e.g., xylophone: tap_1 first time → tap_2 second time)

---

### T003 — Verify hammer power-up sound sequence
**Files**: Same as T002
**Action**: Activate hammer mode and tap a tile. Confirm:
1. **No instrument tap** on tile tap (power-up suppression)
2. **Axe chop sound** plays
3. No merge sound (hammer destroys, doesn't merge)

---

### T004 — Verify swap power-up sound sequence
**Files**: Same as T002
**Action**: Activate swap mode and tap two tiles. Confirm:
1. **No instrument tap** on either tile tap
2. Swap animation/haptic fires correctly
3. No stray sounds

---

### T005 — Stress test audio session reliability
**File**: `Packages/GameServices/Sources/GameServices/AudioService.swift`
**Action**: Play 20+ consecutive chains rapidly. Confirm:
1. Sounds **never cut out** mid-session
2. If sounds do fail, they **self-recover** on the next play (via `ensureAudioSessionActive()` retry)
3. No audio artifacts, clicks, or pops from rapid player creation

Also test:
- Background the app and return → sounds should resume
- Receive a notification mid-chain → sounds should resume
- Play music from another app (e.g., Spotify) alongside → `mixWithOthers` should work

---

### T006 — Verify CustomChallengeGameScreen has parity
**File**: `Packages/GameUI/Sources/GameUI/Challenge/CustomChallengeGameScreen.swift` (line ~70)
**Action**: Open a custom challenge and confirm:
1. Chain sounds match HybridGameScreen behavior
2. Power-up mode suppression works identically
3. `isPowerUpActive` flag is passed correctly

---

## Phase 2: Remaining Polish

### T007 [P] — Remove excessive print logging from AudioService
**File**: `Packages/GameServices/Sources/GameServices/AudioService.swift`
**Action**: The audio service has dozens of `print()` debug statements (e.g., lines with emoji prefixes like `🎹`, `⚡`, `🔊`, `✅`, `❌`). Replace them with `OSLog` Logger calls at appropriate levels:
- `print("🎹 Playing...")` → `logger.debug("Playing \(theme) sound: \(soundName)")`
- `print("❌ Failed...")` → `logger.error("Failed to play: \(error)")`
- Remove redundant success prints entirely

Create logger: `private let logger = Logger(subsystem: "com.game2244", category: "Audio")`

---

### T008 [P] — Add audio session interruption handler
**File**: `Packages/GameServices/Sources/GameServices/AudioService.swift`
**Action**: In `init()`, register for `AVAudioSession.interruptionNotification`. When an interruption **ends** (`.ended` with `.shouldResume`), call `ensureAudioSessionActive()` to reactivate the session. This handles phone calls, Siri, etc. gracefully.

```swift
NotificationCenter.default.addObserver(
    forName: AVAudioSession.interruptionNotification,
    object: nil,
    queue: nil
) { notification in
    guard let info = notification.userInfo,
          let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue),
          type == .ended else { return }
    Task { await self.ensureAudioSessionActive() }
}
```

---

### T009 [P] — Add unit test for playMergeSfx single-note behavior
**File**: `Packages/GameServices/Tests/GameServicesTests/AudioServiceTests.swift`
**Action**: Add a test confirming `playMergeSfx(tileCount:)` calls `playInstrumentTapSound` exactly **once** regardless of `tileCount`. Use the existing `DefaultAudioService` (no-op) to verify the protocol contract, or create a spy wrapper around `LiveAudioService` if testable.

---

### T010 [P] — Add unit test for isPowerUpActive suppression
**File**: `Packages/GameUI/Tests/GameUITests/` (new file if needed)
**Action**: Verify that when `isPowerUpActive = true`:
- `SimplifiedGlassBoardView` does NOT call `beginPath` on drag start
- `BoardView` does NOT play "tap" sound on tile tap

This can be a snapshot or behavioral test using the existing test infrastructure.

---

## Dependencies

```
T001-T006 (verification) — can all run in parallel [P], no code changes
T007, T008, T009, T010 (polish) — can all run in parallel [P], different files

T001-T006 → should complete before T007-T010 (confirm behavior before cleaning up)
```

## Parallel Execution Examples

```
# Phase 1: Launch all verification tasks together
Task: "T001 — Test chain sound count for each instrument on device"
Task: "T002 — Test magnet power-up suppresses select sound, plays zap then merge"
Task: "T003 — Test hammer power-up suppresses select sound"
Task: "T004 — Test swap power-up suppresses select sound"
Task: "T005 — Stress test 20+ rapid chains, test background/notification recovery"
Task: "T006 — Test CustomChallengeGameScreen matches HybridGameScreen behavior"

# Phase 2: Launch all polish tasks together (after Phase 1 passes)
Task: "T007 — Replace print() with OSLog in AudioService.swift"
Task: "T008 — Add AVAudioSession interruption handler in AudioService.init()"
Task: "T009 — Unit test playMergeSfx plays exactly 1 note"
Task: "T010 — Unit test isPowerUpActive suppresses beginPath and tap sound"
```

## Validation Checklist

- [x] Chain sounds play instrument taps (not ticks) — `AudioService.swift:192`
- [x] First tile plays select sound — `SimplifiedGlassBoardView.swift:363`
- [x] Merge plays exactly 1 note — `AudioService.swift:277-279`
- [x] Power-up modes suppress drag gesture sounds — `SimplifiedGlassBoardView.swift:362`, `BoardView.swift:274`
- [x] Audio session configured once in init, not per-sound — `AudioService.swift:107-118`
- [x] Failed plays retry with session reactivation — `ensureAudioSessionActive()` pattern
- [ ] T001-T006: Manual QA passes
- [ ] T007: Debug prints removed
- [ ] T008: Interruption handler added
- [ ] T009-T010: Unit tests pass

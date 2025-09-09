# Implementation Notes

## Current Status

The project has been successfully bootstrapped with a modular architecture following the roadmap specifications:

### ✅ Completed (M0 & M1)

1. **Modular Architecture Setup**
   - Created 5 local Swift packages: GameCore, GameApp, GameUI, GameServices, GameTestingSupport
   - Each module has clear responsibilities and dependencies
   - All packages compile successfully with Swift 6

2. **Core Game Engine (GameCore)**
   - Deterministic RNG for replay support
   - Board representation with tiles and positions
   - Chain validation logic (first two equal, then same/double)
   - Merge mechanics and gravity simulation
   - Game over detection

3. **State Management (GameApp)**
   - @Observable GameStore (no @StateObject/ObservableObject)
   - Dependency injection via @Environment
   - Path tracking and validation

4. **UI Layer (GameUI)**
   - BoardView with drag gesture handling
   - TileView with animations
   - Theme system with color palette
   - Path visualization

5. **Services (GameServices)**
   - StoreKit 2 purchase service ready
   - Ad service protocol with dummy implementation
   - Haptics service for feedback

## Next Steps

To fully integrate the packages with the Xcode project, you'll need to:

1. **Open in Xcode**
   - Open `game2244.xcworkspace` in Xcode
   - Add package dependencies to the main app target:
     - File > Add Package Dependencies > Add Local
     - Select each package from the Packages folder

2. **Configure Build Settings**
   - Ensure iOS 18.0 minimum deployment target
   - Enable Swift 6 language mode

3. **Test the App**
   - Build and run on iOS Simulator
   - The game should be playable with drag gestures
   - Chain validation and merging should work

## Architecture Decisions

- **No @AppStorage in @Observable**: Following best practices to avoid breaking observation
- **Dependency Injection**: All services injected via environment, not props
- **Deterministic Engine**: Supports replay and daily mode features
- **Protocol-based Services**: Easy to swap implementations (dummy vs real ads)

## Testing

All packages include test targets using Swift Testing framework:
- GameCoreTests: Engine logic, validation, RNG
- GameAppTests: Store behavior
- GameUITests: Theme system
- GameServicesTests: Service protocols

Run tests with:
```bash
swift test --package-path Packages/GameCore
```

## Known Limitations

1. The workspace needs manual package linking in Xcode
2. StoreKit products need configuration in App Store Connect
3. Ad service is currently dummy implementation only

## Development Workflow

1. Make changes to packages in their respective folders
2. Run package tests to verify
3. Build the main app to test integration
4. Use the workspace for full app development

## Roadmap & Tasks (Epics/Stories)

- **CG: Core Gameplay 2244 (P0)**
  - [x] CG01: Swipe and merge loop
    - [x] Gesture handling for continuous path selection across orthogonal neighbors
    - [x] Validation: only identical values can be chained, length ≥ 2
    - [x] Merge resolution with deterministic order and seedable RNG (merge result: next power of two for identical chain)
    - [x] Acceptance: chain length ≥ 2, merge to one tile on release, no diagonal chaining
  - [ ] CG02: Chain scoring and combo multiplier
    - [ ] Scoring formula and combo window
    - [ ] Acceptance: longer chains strictly higher; combo active only within window
  - [ ] CG03: Board refill and spawn rules
    - [ ] Gravity collapse and spawn distribution via weighted bag
    - [ ] Acceptance: no illegal immediate deadlocks; unit tests for edge refills
  - [ ] CG04: Game over detection and restart
    - [ ] Detect no valid chain paths; restart seeded board
    - [ ] Acceptance: deterministic dead-board test
  - [ ] CG05: Score and best score
    - [ ] Session score; persisted best score via storage adapter
    - [ ] Acceptance: best updates only when session ends above record

- **UI: Visuals and Interaction Polish (P1)**
  - [ ] UI01: Grid layout and tile rendering (scalable, variants)
  - [ ] UI02: Merge animations (120 Hz friendly)
  - [ ] UI03: Particle effects (capped per frame)
  - [ ] UI04: Event banner host

- **PF: Progression and Feedback (P1)**
  - [ ] PF01: Combo meter and chain highlight
  - [ ] PF02: Score popups
  - [ ] PF03: Game over screen

- **SC: Social and Competitive (P1)**
  - [ ] SC01: Game Center leaderboards
  - [ ] SC02: Share score

- **MU: Monetization and Ads (P1)**
  - [ ] MU01: Banner ads
  - [ ] MU02: Interstitials on restart/game over
  - [ ] MU03: Rewarded ads for continue/booster

- **PR: Persistence and Cloud (P0 → P1)**
  - [ ] PR01: Local multi-save slots
  - [ ] PR02: Cloud sync

- **RC: Analytics and Remote Config (P0 → P1)**
  - [ ] RC01: Remote banners and limited-time events
  - [ ] RC02: Analytics instrumentation (minimal first)
  - [ ] RC03: A/B flags

- **ST: Settings and Utility (P0)**
  - [ ] ST01: Pause menu
  - [ ] ST02: Toggles for sound, music, haptics
  - [ ] ST03: Multi-save selector

- **TH: Theming and Customization (P1)**
  - [ ] TH01: Theme packs
  - [ ] TH02: Seasonal themes

- **AX: Accessibility, Performance, QA, Release (P0 → P2)**
  - [ ] AX01: Accessibility
  - [ ] AX02: Performance
  - [ ] AX03: Testing
  - [ ] AX04: Compliance and metadata

### Notes
- State holder: `GameStore` as `@Observable`; UI reads with `@Environment`/`@Bindable`.
- Pure math in nonisolated helpers for easy tests.
- Inject services via `@Environment` values: `gameClock`, `random`, `storage`, `haptics`, `audio`.

---

## GameScreen (screenshot parity) – Pixel/UI Spec

Goal: Recreate the provided 2244-style screen pixel-for-pixel in SwiftUI while preserving our modular architecture. This section specifies structure, measurements, colors, typography, assets, and interactions.

### Layout map (ZStack)
1. Background: full-screen starfield/galaxy image with subtle vignette.
2. Foreground VStack (top → bottom):
   - `TopHUD` row: rank badge (left), progress track with milestone chips (center), gem wallet (right).
   - `BoardFrame` (rounded rect container) with embedded `BoardGrid` and `PathOverlay`.
   - `BottomRail` containing: next queue rail and a crowned reserve tile docked to the bottom-center.

3. Side toolbars layered in a ZStack above the board container:
   - `LeftToolbar` (vertical): pause button, shop button, ad-reward shortcut.
   - `RightToolbar` (vertical): boosters (hammer, shuffle, magnet) with remaining counts and gem price.

Responsiveness: use a fixed design width reference of 390 pt (iPhone 15 Pro). Scale by min(widthRatio, heightRatio). Maintain 5×8 grid with constant inter-tile spacing.

### BoardFrame + Grid
- Board container corner radius: 20 pt; inner padding: 12 pt; outer shadow: black 0.35 alpha, y: 6, blur: 18.
- Grid: 5 columns × 8 rows.
- Tile size: clamp to ≤80 pt. Spacing: 8 pt (already implemented). Keep board centered.
- Board mat color: near-black with 40% opacity over background; inner stroke 1 pt, white 6%.

### Tiles (`TileView`)
- Shape: rounded square radius 12 pt.
- Style: 3D raised with dual shadow:
  - Top highlight: white 25% at y:-2, blur: 3.
  - Bottom drop: black 30% at y:3, blur: 6.
- Label: bold rounded font, tight tracking. Dynamic text sizing based on digits/suffix.
- Colors (approx – finalize with assets):
  - Blue: 0x2EA3E4, Orange: 0xF28B3C, Pink: 0xF16799, Lime: 0xD7E338, Navy: 0x1E73B9, Green (special): 0x7ED957.
- Selected state: glowing white outline 2–3 pt plus inner light. Valid path glow: teal/green; invalid: red. Endpoints receive a stronger glow.
- Content format for variant game: mantissa + suffix letter (e.g., `226u`, `3v`, `1w`). Implement via a `TileValue` formatter (mantissa:Int, magnitude: enum { u, v, w, ... }).

### PathOverlay
- Polyline connecting centers of selected tiles.
- Stroke: 6 pt, rounded joins and caps.
- Valid: gradient [white → green] with 60% outer bloom; Invalid: [white → red].
- Subtle shimmering animation along the stroke during drag.

### TopHUD
- Left: `RankBadge` pill
  - Label: "Rank:" left, numeric right; dark pill 70% opacity, white text.
- Center: `MilestoneTrack`
  - Horizontal rail with neutral bar (6 pt height, 80% width of board).
  - Three milestone chips over the rail (`226u`, current `1w` large with crown, `3w`). Chips are color-coded tiles (miniatures) with subtle drop.
  - Current chip has crown badge and sits on top of rail.
- Right: `GemWallet`
  - Gem icon + integer amount; trailing plus button in a small green square.

### LeftToolbar (vertical)
- Buttons (top → bottom): Pause ("||"), Shop (crate icon + label "SHOP"), Ad gift (+gems label).
- Each is a rounded square with inner icon; spacing 18 pt; drop shadow ~20%.

### RightToolbar (vertical)
- Boosters with counts and price bubbles:
  - Hammer, Shuffle (two arrows), Magnet (attractor). Show small circular bubble with remaining count on icon; show gem price label beside.
  - Gem price displayed in compact pill with gem icon.

### BottomRail
- Up-caret button centered just below board (toggleable drawer behavior; initially no-op).
- `ReserveTile` (large crowned green tile labeled `1w`) docked just above the caret.

### Typography
- Primary: rounded, bold weights for numbers (SF Rounded preferred).
- Sizing:
  - Tile label: 32–40 pt at 80 pt tile; scale down with tile size and digits.
  - HUD labels: 12–18 pt.
- Accessibility: support Dynamic Type; never truncate tile labels (scale to fit).

### Interaction spec
- Drag to select chain; backtracking supported; commit on lift if valid length ≥ 2.
- Toolbars:
  - Pause: opens Pause menu (stub ok initially).
  - Shop: opens store (stub ok initially).
  - Ad gift: triggers rewarded ad that adds gems.
  - Boosters: tap to arm (hammer/swap) or immediate (shuffle); show insufficient-gems toast if needed.
- Progress track chips are non-interactive (display only).

### Data/connectivity to GameStore
- Continue to use `GameStore` for path state, score, gems, and power-ups.
- Add presentation models for HUD:
  - `rank: Int`, `milestones: [MilestoneChip]` (value + color + state), `gemBalance: Int`.
- Add `TileValue` domain and formatter for mantissa+suffix tiles (non-breaking; map current Int values into textual style until new engine values are introduced).

### Asset checklist (to be provided)
- Background: high-res galaxy PNG (portrait), plus @2x/@3x.
- Tile base textures (flat and 3D raised) or simple color palette if drawn in code.
- Crown badge (PNG/SVG with transparent bg).
- Icons: pause, store, gift/ad, hammer, shuffle, magnet, gem, plus, caret up, lock, infinity.
- Milestone chip frames (optional; can be drawn with SwiftUI).

### Component breakdown (GameUI)
- `GameScreen` (new) – orchestrates layout for this screen.
- `TopHUD`, `RankBadge`, `MilestoneTrack`, `GemWallet`.
- `BoardFrame` (container), reuses `BoardView` inside.
- `PathOverlay` – move visual from `BoardView` into dedicated modifier to enable glow/gradient.
- `LeftToolbar`, `RightToolbar`, `BoosterButton`.
- `BottomRail`, `ReserveTile`.

### Measurements (reference 390×844)
- Board outer frame width ≈ min(screenWidth - 32, 350).
- Grid spacing: 8 pt; tile max size: 80 pt; board padding: 12 pt.
- Toolbars offset from board edges by 10–14 pt.
- Rail width: ≈ board width - 40 pt; height: 6 pt; chip size: 36 pt; center chip: 44 pt.

### Implementation plan (phased)
1. Introduce `GameScreen` and slot into `GameView` replacing ad-hoc header/controls.
2. Build `TopHUD` with progress rail and wallet.
3. Wrap current `BoardView` with `BoardFrame` and layer `LeftToolbar` + `RightToolbar` in a ZStack.
4. Add `BottomRail` with crowned `ReserveTile` (uses theme color; stub behavior).
5. Upgrade `TileView` to 3D raised style variant and suffix-aware formatting.
6. Replace current overlay stroke with gradient glow path.
7. Wire boosters to existing `GameStore` actions; add insufficient-gems feedback.
8. Theming pass: colors, shadows, contrast tuning; finalize with supplied assets.

### Acceptance criteria
- Visual parity within 2 px on iPhone 15 Pro screenshot overlay.
- All interactive elements present and tappable.
- Dynamic Type large sizes do not clip labels; VoiceOver announces semantics.
- No runtime or linter errors; tests pass.

### Open questions
- Exact color hexes for each tile and HUD chip.
- Whether milestone chips are functional or cosmetic.
- Final sizes/positions for right-toolbar price bubbles and count badges.

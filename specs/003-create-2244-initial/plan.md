# Implementation Plan: Create 2244 - Initial Playable Shell

**Branch**: `003-create-2244-initial` | **Date**: 2025-01-16 | **Spec**: [/specs/003-create-2244-initial/spec.md](spec.md)
**Input**: Feature specification from `/specs/003-create-2244-initial/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → Feature spec loaded successfully
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → No NEEDS CLARIFICATION markers found
   → Project Type: iOS mobile app with modular Swift packages
   → Structure Decision: Existing modular package structure
3. Evaluate Constitution Check section below
   → No violations detected
   → Update Progress Tracking: Initial Constitution Check
4. Execute Phase 0 → research.md
   → Research audio architecture and theme system
5. Execute Phase 1 → contracts, data-model.md, quickstart.md, CLAUDE.md
6. Re-evaluate Constitution Check section
   → No new violations
   → Update Progress Tracking: Post-Design Constitution Check
7. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
8. STOP - Ready for /tasks command
```

## Summary
Create an initial playable shell for 2244 puzzle game with circular hub menu UI, auto-loading default profile, progression path visualization, full gameplay mechanics including chain validation and power-ups, six music themes, daily spin wheel, rewarded ads, time-limited offers, Game Center leaderboards, Google AdMob integration, and Firebase analytics. Built on existing modular Swift package architecture following strict Swift 6 concurrency and SwiftUI Observation patterns.

## Technical Context
**Language/Version**: Swift 6.0 (strict concurrency mode)
**Primary Dependencies**: SwiftUI 5+, AVFoundation, StoreKit 2, Game Center, Core Haptics, Firebase SDK, Google AdMob
**Storage**: UserDefaults (settings/profile), JSON files (saves/challenges), Firebase (analytics/config)
**Testing**: Swift Testing framework (not XCTest)
**Target Platform**: iOS 18+, iPadOS optional, 60 FPS target
**Project Type**: iOS mobile app with modular packages
**Performance Goals**: 60 FPS during gameplay, <500ms theme switch, <50ms audio latency
**Constraints**: No authentication, local profile only, deterministic gameplay
**Scale/Scope**: 1 default profile, 9 hub features, 6 music themes, 6 power-up types, leaderboards, ads

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Simplicity**:
- Projects: 5 existing packages (GameCore, GameApp, GameUI, GameServices, GameTestingSupport) ✓
- Using framework directly? Yes - SwiftUI, StoreKit 2, AVFoundation ✓
- Single data model? Yes - GameState in GameCore ✓
- Avoiding patterns? Yes - no unnecessary abstractions ✓

**Architecture**:
- EVERY feature as library? Yes - modular packages ✓
- Libraries listed:
  - GameCore: Engine, rules, deterministic RNG
  - GameApp: State management, stores
  - GameUI: Views, themes, animations
  - GameServices: Audio, haptics, IAP, ads
  - GameTestingSupport: Test fixtures
- CLI per library: N/A (iOS app)
- Library docs: README per package ✓

**Testing (NON-NEGOTIABLE)**:
- RED-GREEN-Refactor cycle enforced? Yes ✓
- Git commits show tests before implementation? Will enforce ✓
- Order: Contract→Integration→E2E→Unit strictly followed? Yes ✓
- Real dependencies used? Yes - actual Game Center, StoreKit sandbox ✓
- Integration tests for: new libraries, contract changes, shared schemas? Yes ✓
- FORBIDDEN: Implementation before test - understood ✓

**Observability**:
- Structured logging included? Yes - os.Logger per module ✓
- Frontend logs → backend? N/A (local app) ✓
- Error context sufficient? Yes - detailed error types ✓

**Versioning**:
- Version number assigned? Using existing app version ✓
- BUILD increments on every change? Yes via CI ✓
- Breaking changes handled? N/A (initial release) ✓

## Project Structure

### Documentation (this feature)
```
specs/003-create-2244-initial/
├── spec.md              # Feature specification
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
│   ├── profile.yaml     # Profile structure
│   ├── game-state.yaml  # Game state contracts
│   ├── audio.yaml       # Audio theme contracts
│   └── iap.yaml         # In-app purchase contracts
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (existing modular structure)
```
Packages/
├── GameCore/           # Pure Swift engine
│   ├── Sources/
│   │   └── GameCore/
│   │       ├── GameEngine.swift (existing, needs power-up updates)
│   │       ├── Board.swift (existing, needs 5x8 config)
│   │       ├── PowerUpManager.swift (new)
│   │       └── ProfileManager.swift (new)
│   └── Tests/
│
├── GameApp/            # State management
│   ├── Sources/
│   │   └── GameApp/
│   │       ├── GameStore.swift (existing, needs profile updates)
│   │       ├── ProfileStore.swift (new)
│   │       └── SampleProjectTasks.swift (new)
│   └── Tests/
│
├── GameUI/             # SwiftUI views
│   ├── Sources/
│   │   └── GameUI/
│   │       ├── BoardView.swift (existing, needs 5x8 layout)
│   │       ├── MainMenuView.swift (new)
│   │       └── ThemeSelector.swift (new)
│   └── Tests/
│
├── GameServices/       # Platform services
│   ├── Sources/
│   │   └── GameServices/
│   │       ├── AudioService.swift (existing, needs theme system)
│   │       ├── MusicThemeManager.swift (new)
│   │       ├── HapticsService.swift (existing)
│   │       └── PurchaseService.swift (existing)
│   └── Tests/
│
└── GameTestingSupport/ # Test helpers
    ├── Sources/
    └── Tests/
```

**Structure Decision**: Use existing modular package structure

## Phase 0: Outline & Research

### Research Tasks Identified:
1. **Audio Theme Architecture**
   - How to implement 6 music themes with crossfade
   - AVAudioEngine vs AVAudioPlayer for low latency
   - Memory management for multiple audio tracks

2. **Theme Switching Performance**
   - Achieving <500ms crossfade between themes
   - Preloading strategies for audio assets
   - Fallback handling for missing audio files

3. **Sample Project Tasks System**
   - Best structure for pre-populated tasks
   - Task state persistence approach
   - UI for task tracking within game modes

4. **Power-Up Inventory Management**
   - Initial inventory distribution
   - Consumption tracking
   - UI feedback for power-up usage

### Research Execution:
```
For Audio Architecture:
  Task: "Research AVAudioEngine for multi-track music with crossfade"
  Task: "Find best practices for iOS game audio with 50ms latency"
  
For Theme System:
  Task: "Research audio asset bundling strategies for iOS"
  Task: "Evaluate Core Audio vs AVFoundation for game music"
  
For Task System:
  Task: "Research task/quest systems in mobile puzzle games"
  Task: "Find patterns for progress tracking UI"
```

**Output**: research.md with technical decisions documented

## Phase 1: Design & Contracts

### Data Model Design:
1. **Profile Entity**
   - id: UUID
   - powerUpInventory: [PowerUpType: Int]
   - coins: Int
   - achievements: Set<AchievementID>
   - settings: ProfileSettings
   - createdAt: Date

2. **GameSession Entity**
   - board: Board (5x8)
   - score: Int
   - moves: Int
   - mode: GameMode
   - powerUpsUsed: [PowerUpType: Int]
   - tasks: [TaskID: TaskStatus]

3. **MusicTheme Entity**
   - id: ThemeID
   - name: String
   - isPremium: Bool
   - backgroundTrack: AudioAsset
   - effectsMap: [SoundEffect: AudioAsset]
   - hapticPatterns: [InteractionType: HapticPattern]

4. **ProjectTask Entity**
   - id: TaskID
   - title: String
   - status: TaskStatus (completed/inProgress/notStarted)
   - projectID: ProjectID

### API Contracts:
1. **Profile Management**
   - GET /profile → Profile
   - PUT /profile/powerups → UpdatedInventory
   - PUT /profile/coins → UpdatedBalance

2. **Game State**
   - POST /game/start → GameSession
   - PUT /game/chain → ChainResult
   - PUT /game/powerup → PowerUpResult

3. **Audio System**
   - GET /audio/themes → [MusicTheme]
   - PUT /audio/theme/{id} → ThemeChangeResult
   - PUT /audio/volume → VolumeSettings

4. **IAP System**
   - GET /iap/products → [Product]
   - POST /iap/purchase → PurchaseResult
   - POST /iap/restore → RestoreResult

### Contract Tests:
- One test file per endpoint
- Schema validation for all requests/responses
- Tests written to fail initially (TDD)

### Agent Context Update:
- Update CLAUDE.md with Swift 6 patterns
- Add audio architecture decisions
- Document theme system approach

**Output**: data-model.md, /contracts/*.yaml, failing tests, quickstart.md, CLAUDE.md updates

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Profile & data model tasks (5 tasks)
- Hub menu UI layout (8 tasks - circular buttons, progression path)
- Board configuration tasks (3 tasks)
- Power-up implementation tasks (6 tasks, one per type)
- Audio theme tasks (8 tasks - system + 6 themes)
- Spin wheel & rewards (4 tasks)
- Time-limited offers system (3 tasks)
- Ad integration - Google AdMob (3 tasks)
- Game Center leaderboards (4 tasks)
- Firebase integration (3 tasks)
- UI implementation tasks (12 tasks)
- Integration test tasks (8 tasks)
- Sample project tasks setup (4 tasks)

**Ordering Strategy**:
1. Firebase & external SDKs setup [P]
2. Profile and data model [P]
3. Hub menu layout & navigation
4. Board configuration [P]
5. Power-up system
6. Audio architecture
7. Theme implementation
8. Spin wheel & rewards
9. Ad integration
10. Leaderboards
11. Time-limited offers
12. UI components
13. Integration tests
14. Sample tasks setup

**Estimated Output**: 61 numbered, ordered tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*No violations requiring justification*

## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented (none)

---
*Based on Constitution v2.1.1 - See `/memory/constitution.md`*
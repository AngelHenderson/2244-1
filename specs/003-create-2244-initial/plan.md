# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
4. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
5. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, or `GEMINI.md` for Gemini CLI).
6. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
7. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
8. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Create 2244 - a chain-based puzzle game where players connect adjacent tiles (2→2→4→8) to score points and progress. The initial playable shell delivers:
- **Core Gameplay**: 5×8 board with chain validation (first two equal, subsequent same/double)
- **6 Power-Ups**: Hammer, Swap, Undo, Shuffle, Magnet, Double with command pattern
- **3 Game Modes**: Classic (endless), Daily Challenge (SHA256 seed), Journey (staged)
- **Audio System**: 6 music themes with <500ms crossfade using AVAudioEngine
- **Profile System**: Auto-loading with 305 coins, initial power-ups [3,2,5,1,0,0]
- **33 Sample Tasks**: Pre-populated across modes to simulate active gameplay

Implementation follows TDD with RED-GREEN-REFACTOR cycle and Swift 6 strict concurrency.

## Technical Context
**Language/Version**: Swift 6 with strict concurrency
**Primary Dependencies**: SwiftUI, AVAudioEngine, StoreKit 2, GameKit
**Storage**: UserDefaults + JSON files for saves/challenges
**Testing**: Swift Testing framework (NOT XCTest)
**Target Platform**: iOS 18+ (iPhone primary, iPad secondary)
**Project Type**: mobile - iOS app with modular packages
**Performance Goals**: 60 FPS gameplay, <500ms audio crossfade, <50ms haptic latency
**Constraints**: 5×8 fixed board, deterministic RNG, offline-capable
**Scale/Scope**: Single-player game, 3 game modes, 6 themes, 33 pre-populated tasks

## Constitution Check (2244 Game)
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Game Architecture**:
- Modular packages: GameCore (engine), GameApp (stores), GameUI (views), GameServices ✓
- Pure Swift game engine (deterministic, testable) ✓
- @Observable stores with @MainActor (no @StateObject) ✓
- Swift 6 strict concurrency enabled ✓

**Game Requirements**:
- 5×8 fixed board (not configurable) ✓
- Chain rules: first two equal, subsequent same/double ✓
- Initial profile: 305 coins, [3,2,5,1,0,0] power-ups ✓
- 6 themes with <500ms crossfade ✓
- 33 pre-populated sample tasks ✓

**Testing (NON-NEGOTIABLE)**:
- Swift Testing framework (NOT XCTest) ✓
- RED-GREEN-Refactor for all game features ✓
- Contract tests for Profile, GameSession, MusicTheme ✓
- Integration tests for chains, power-ups, themes ✓
- 60 FPS performance validation ✓
- FORBIDDEN: Implementation before test, using @StateObject

**Observability**:
- Structured logging included?
- Frontend logs → backend? (unified stream)
- Error context sufficient?

**Versioning**:
- Version number assigned? (MAJOR.MINOR.BUILD)
- BUILD increments on every change?
- Breaking changes handled? (parallel tests, migration plan)

## Project Structure

### Documentation (this feature)
```
specs/[###-feature]/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
# Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure]
```

**Structure Decision**: [DEFAULT to Option 1 unless Technical Context indicates web/mobile app]

## Phase 0: Game Architecture Research
1. **Audio Architecture** (research.md lines 8-72):
   - AVAudioEngine node graph for multi-theme music
   - Dual-buffer preloading (current + next theme)
   - <500ms crossfade requirement
   - Theme-specific haptic patterns

2. **Power-Up System** (research.md lines 105-138):
   - Command pattern for undo/redo
   - Initial inventory: [3 hammer, 2 swap, 5 undo, 1 shuffle, 0 magnet, 0 double]
   - Validation through game engine

3. **Game Board** (research.md lines 190-204):
   - Fixed 5×8 layout (40 tiles)
   - Chain rules: first two equal, subsequent same or double
   - 8-direction adjacency for chains
   - Deterministic RNG with SHA256(salt + date) for daily

**Output**: research.md documenting all game design decisions

## Phase 1: Game Design & Contracts
*Prerequisites: research.md complete*

1. **Game Entities** (data-model.md):
   - **Profile** (lines 8-75): coins=305, gems=0, power-ups, achievements
   - **GameSession** (lines 77-126): 5×8 board, seed, score, moves
   - **MusicTheme** (lines 128-181): 6 themes, sound effects, haptics
   - **ProjectTask** (lines 183-244): 33 pre-populated tasks
   - **SpinWheelReward** (lines 283-306): daily spin, 24hr cooldown
   - **TimeLimitedOffer** (lines 309-336): countdown deals

2. **Game Contracts** (/contracts/):
   - **profile.yaml**: Initial inventory validation
   - **game-state.yaml**: Board dimensions, chain rules
   - **audio.yaml**: Theme structure, crossfade specs
   - **iap.yaml**: Product IDs for themes/gems
   - **rewards.yaml**: Spin wheel, offers

3. **Gameplay Tests** (quickstart.md):
   - Profile auto-loads in <100ms
   - Chain [2,2,4,8] validates correctly
   - Power-ups consume from inventory
   - Theme switches in <500ms
   - Daily challenge uses date seed

**Output**: Complete game design docs with failing contract tests

## Phase 2: Game Implementation Tasks (74 total)
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Categories**:
- **Setup** (T001-T004): Firebase, AdMob, Game Center, StoreKit
- **Tests First** (T005-T019):
  - 5 contract tests for game structures
  - 10 integration tests for gameplay mechanics
- **Core Game** (T020-T037):
  - 6 entity models (Profile, GameSession, etc.)
  - 6 game logic components (Board, PowerUps, Chain validation)
  - 6 state stores (@Observable with @MainActor)
- **Game UI** (T038-T051):
  - Hub menu with 9 features
  - 5×8 board view with chain highlighting
  - Power-up bar, theme selector, spin wheel
- **Services** (T052-T063):
  - Audio system with AVAudioEngine
  - Theme-specific haptics
  - AdMob, Game Center, StoreKit 2
- **Polish** (T064-T074): 60 FPS validation, quickstart verification

**Estimated Output**: 74 numbered tasks with [P] parallelization markers

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Game Development Execution
*These phases are beyond the scope of the /plan command*

**Phase 3**: Generate 74 game implementation tasks (/tasks command)
**Phase 4**: Build the game following TDD:
  - RED: Write failing tests for each game feature
  - GREEN: Implement minimal code to pass
  - REFACTOR: Optimize while maintaining 60 FPS
**Phase 5**: Game validation:
  - Play through all 3 modes
  - Verify 33 sample tasks appear
  - Test all 6 power-ups
  - Confirm <500ms theme crossfade
  - Validate chain rules [2,2,4,8...]

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |


## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [ ] Phase 0: Research complete (/plan command)
- [ ] Phase 1: Design complete (/plan command)
- [ ] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [ ] Initial Constitution Check: PASS
- [ ] Post-Design Constitution Check: PASS
- [ ] All NEEDS CLARIFICATION resolved
- [ ] Complexity deviations documented

---
*Based on Constitution v2.1.1 - See `/memory/constitution.md`*
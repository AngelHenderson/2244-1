# Tasks: Create 2244 - Initial Playable Shell

**Input**: Design documents from `/specs/003-create-2244-initial/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/, quickstart.md

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → Extract: Swift 6, SwiftUI, AVAudioEngine, StoreKit 2
   → Structure: GameCore, GameApp, GameUI, GameServices packages
2. Load optional design documents:
   → data-model.md: 10 core entities → model tasks
   → contracts/: 5 contract files → 5 contract test tasks
   → research.md: Audio architecture decisions → setup tasks
3. Generate tasks by category:
   → Setup: Package structure, dependencies, configuration
   → Tests: Contract tests, integration tests (TDD)
   → Core: Models, game engine, state stores
   → UI: Views, gesture handling, animations
   → Services: Audio, haptics, StoreKit, GameKit
   → Polish: Performance validation, quickstart verification
4. Apply task rules:
   → Different files/packages = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001-T074)
6. Return: SUCCESS (74 tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Core Package**: `Packages/GameCore/Sources/GameCore/`
- **App Package**: `Packages/GameApp/Sources/GameApp/`
- **UI Package**: `Packages/GameUI/Sources/GameUI/`
- **Services Package**: `Packages/GameServices/Sources/GameServices/`
- **Tests**: `Packages/[Package]/Tests/[Package]Tests/`

## Phase 3.1: Setup & Configuration
- [ ] T001 Create modular package structure (GameCore, GameApp, GameUI, GameServices)
- [ ] T002 Configure Swift 6 strict concurrency in all Package.swift files
- [ ] T003 [P] Add AVAudioEngine and StoreKit 2 dependencies to GameServices
- [ ] T004 [P] Configure Firebase and AdMob SDK dependencies
- [ ] T005 [P] Set up Game Center entitlements and capabilities
- [ ] T006 Create app workspace configuration linking all packages

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

### Contract Tests
- [ ] T007 [P] Contract test for Profile initial state in Packages/GameApp/Tests/GameAppTests/ProfileContractTests.swift
- [ ] T008 [P] Contract test for GameSession board validation in Packages/GameCore/Tests/GameCoreTests/GameSessionContractTests.swift
- [ ] T009 [P] Contract test for Audio theme crossfade in Packages/GameServices/Tests/GameServicesTests/AudioContractTests.swift
- [ ] T010 [P] Contract test for IAP products in Packages/GameServices/Tests/GameServicesTests/IAPContractTests.swift
- [ ] T011 [P] Contract test for Rewards system in Packages/GameApp/Tests/GameAppTests/RewardsContractTests.swift

### Integration Tests
- [ ] T012 [P] Integration test: Profile auto-loads in <100ms in Tests/IntegrationTests/ProfileLoadTests.swift
- [ ] T013 [P] Integration test: Chain [2,2,4,8] validates correctly in Tests/IntegrationTests/ChainValidationTests.swift
- [ ] T014 [P] Integration test: Power-ups consume from inventory in Tests/IntegrationTests/PowerUpTests.swift
- [ ] T015 [P] Integration test: Theme switches in <500ms in Tests/IntegrationTests/ThemeSwitchTests.swift
- [ ] T016 [P] Integration test: Daily challenge uses date seed in Tests/IntegrationTests/DailyChallengeTests.swift
- [ ] T017 [P] Integration test: 33 sample tasks load correctly in Tests/IntegrationTests/SampleTasksTests.swift
- [ ] T018 [P] Integration test: 5×8 board maintains fixed dimensions in Tests/IntegrationTests/BoardDimensionTests.swift
- [ ] T019 [P] Integration test: Initial inventory [3,2,5,1,0,0] in Tests/IntegrationTests/InitialInventoryTests.swift
- [ ] T020 [P] Integration test: 60 FPS during gameplay in Tests/IntegrationTests/PerformanceTests.swift
- [ ] T021 [P] Integration test: Deterministic RNG with seed in Tests/IntegrationTests/DeterministicRNGTests.swift

## Phase 3.3: Core Implementation (ONLY after tests are failing)

### Data Models
- [ ] T022 [P] Profile model with initial state (305 coins, [3,2,5,1,0,0]) in Packages/GameCore/Sources/GameCore/Models/Profile.swift
- [ ] T023 [P] GameSession model with 5×8 board in Packages/GameCore/Sources/GameCore/Models/GameSession.swift
- [ ] T024 [P] MusicTheme model with 6 themes in Packages/GameCore/Sources/GameCore/Models/MusicTheme.swift
- [ ] T025 [P] ProjectTask model for 33 sample tasks in Packages/GameCore/Sources/GameCore/Models/ProjectTask.swift
- [ ] T026 [P] Challenge model for custom challenges in Packages/GameCore/Sources/GameCore/Models/Challenge.swift
- [ ] T027 [P] SpinWheelReward model in Packages/GameCore/Sources/GameCore/Models/SpinWheelReward.swift
- [ ] T028 [P] TimeLimitedOffer model in Packages/GameCore/Sources/GameCore/Models/TimeLimitedOffer.swift
- [ ] T029 [P] Leaderboard models in Packages/GameCore/Sources/GameCore/Models/LeaderboardEntry.swift
- [ ] T030 [P] AdConfiguration model in Packages/GameCore/Sources/GameCore/Models/AdConfiguration.swift
- [ ] T031 [P] IAPProduct model in Packages/GameCore/Sources/GameCore/Models/IAPProduct.swift

### Game Engine
- [ ] T032 Board manager with 5×8 fixed layout in Packages/GameCore/Sources/GameCore/Engine/BoardManager.swift
- [ ] T033 Chain validator (first two equal, subsequent same/double) in Packages/GameCore/Sources/GameCore/Engine/ChainValidator.swift
- [ ] T034 Tile generator with AlphaMag progression in Packages/GameCore/Sources/GameCore/Engine/TileGenerator.swift
- [ ] T035 Gravity system for tile falling in Packages/GameCore/Sources/GameCore/Engine/GravitySystem.swift
- [ ] T036 Deterministic RNG with SHA256(salt + date) in Packages/GameCore/Sources/GameCore/Engine/DeterministicRNG.swift
- [ ] T037 Score calculator with chain bonuses in Packages/GameCore/Sources/GameCore/Engine/ScoreCalculator.swift

### Power-Up Commands
- [ ] T038 [P] HammerCommand implementation in Packages/GameCore/Sources/GameCore/PowerUps/HammerCommand.swift
- [ ] T039 [P] SwapCommand implementation in Packages/GameCore/Sources/GameCore/PowerUps/SwapCommand.swift
- [ ] T040 [P] UndoCommand implementation in Packages/GameCore/Sources/GameCore/PowerUps/UndoCommand.swift
- [ ] T041 [P] ShuffleCommand implementation in Packages/GameCore/Sources/GameCore/PowerUps/ShuffleCommand.swift
- [ ] T042 [P] MagnetCommand implementation in Packages/GameCore/Sources/GameCore/PowerUps/MagnetCommand.swift
- [ ] T043 [P] DoubleCommand implementation in Packages/GameCore/Sources/GameCore/PowerUps/DoubleCommand.swift

### State Management (@Observable with @MainActor)
- [ ] T044 GameStore with profile and session in Packages/GameApp/Sources/GameApp/Stores/GameStore.swift
- [ ] T045 ProfileStore with inventory management in Packages/GameApp/Sources/GameApp/Stores/ProfileStore.swift
- [ ] T046 AudioStore with theme preloading in Packages/GameApp/Sources/GameApp/Stores/AudioStore.swift
- [ ] T047 PurchaseStore for StoreKit 2 in Packages/GameApp/Sources/GameApp/Stores/PurchaseStore.swift
- [ ] T048 LeaderboardStore for Game Center in Packages/GameApp/Sources/GameApp/Stores/LeaderboardStore.swift
- [ ] T049 TaskProgressStore for sample tasks in Packages/GameApp/Sources/GameApp/Stores/TaskProgressStore.swift

## Phase 3.4: UI Implementation

### Core Views
- [ ] T050 HubMenuView with 9 feature buttons in Packages/GameUI/Sources/GameUI/Views/HubMenuView.swift
- [ ] T051 GameBoardView with 5×8 grid in Packages/GameUI/Sources/GameUI/Views/GameBoardView.swift
- [ ] T052 TileView with chain highlighting in Packages/GameUI/Sources/GameUI/Views/TileView.swift
- [ ] T053 PowerUpBarView with inventory display in Packages/GameUI/Sources/GameUI/Views/PowerUpBarView.swift
- [ ] T054 ProgressionPathView with 512→4096 in Packages/GameUI/Sources/GameUI/Views/ProgressionPathView.swift

### Feature Views
- [ ] T055 [P] ThemeSelectorView with 6 themes in Packages/GameUI/Sources/GameUI/Views/ThemeSelectorView.swift
- [ ] T056 [P] SpinWheelView with animation in Packages/GameUI/Sources/GameUI/Views/SpinWheelView.swift
- [ ] T057 [P] ChallengeDesignerView in Packages/GameUI/Sources/GameUI/Views/ChallengeDesignerView.swift
- [ ] T058 [P] ShopView with IAP products in Packages/GameUI/Sources/GameUI/Views/ShopView.swift
- [ ] T059 [P] LeaderboardView with ranks in Packages/GameUI/Sources/GameUI/Views/LeaderboardView.swift
- [ ] T060 [P] ProjectTasksView for 33 tasks in Packages/GameUI/Sources/GameUI/Views/ProjectTasksView.swift

### Gesture Handling
- [ ] T061 ChainGestureRecognizer for drag in Packages/GameUI/Sources/GameUI/Gestures/ChainGestureRecognizer.swift
- [ ] T062 TileSelectionHandler for power-ups in Packages/GameUI/Sources/GameUI/Gestures/TileSelectionHandler.swift

## Phase 3.5: Services Integration

### Audio System
- [ ] T063 AVAudioEngine setup with dual-buffer in Packages/GameServices/Sources/GameServices/Audio/AudioEngine.swift
- [ ] T064 ThemeCrossfader with <500ms transition in Packages/GameServices/Sources/GameServices/Audio/ThemeCrossfader.swift
- [ ] T065 SoundEffectsPlayer for all effects in Packages/GameServices/Sources/GameServices/Audio/SoundEffectsPlayer.swift

### External Services
- [ ] T066 [P] HapticsService with theme patterns in Packages/GameServices/Sources/GameServices/Haptics/HapticsService.swift
- [ ] T067 [P] GameCenterService for leaderboards in Packages/GameServices/Sources/GameServices/GameCenter/GameCenterService.swift
- [ ] T068 [P] StoreKitService for IAP in Packages/GameServices/Sources/GameServices/StoreKit/StoreKitService.swift
- [ ] T069 [P] AdMobService for ads in Packages/GameServices/Sources/GameServices/AdMob/AdMobService.swift
- [ ] T070 [P] FirebaseService for analytics in Packages/GameServices/Sources/GameServices/Firebase/FirebaseService.swift

## Phase 3.6: Polish & Validation
- [ ] T071 Performance profiling: Maintain 60 FPS during gameplay
- [ ] T072 Audio validation: Verify <500ms crossfade between themes
- [ ] T073 Haptic validation: Test all feedback patterns on device
- [ ] T074 Complete quickstart.md validation checklist

## Dependencies
- Setup (T001-T006) blocks everything
- Tests (T007-T021) before implementation (T022-T070)
- Models (T022-T031) before engine (T032-T037)
- Engine before power-ups (T038-T043)
- State stores (T044-T049) before views (T050-T062)
- Views before services integration
- All implementation before polish (T071-T074)

## Parallel Execution Examples

### Launch contract tests together:
```bash
Task: "Contract test for Profile initial state"
Task: "Contract test for GameSession board validation"
Task: "Contract test for Audio theme crossfade"
Task: "Contract test for IAP products"
Task: "Contract test for Rewards system"
```

### Launch integration tests together:
```bash
Task: "Integration test: Profile auto-loads in <100ms"
Task: "Integration test: Chain [2,2,4,8] validates correctly"
Task: "Integration test: Power-ups consume from inventory"
Task: "Integration test: Theme switches in <500ms"
Task: "Integration test: Daily challenge uses date seed"
```

### Launch model creation together:
```bash
Task: "Profile model with initial state"
Task: "GameSession model with 5×8 board"
Task: "MusicTheme model with 6 themes"
Task: "ProjectTask model for 33 sample tasks"
Task: "Challenge model for custom challenges"
```

### Launch power-up commands together:
```bash
Task: "HammerCommand implementation"
Task: "SwapCommand implementation"
Task: "UndoCommand implementation"
Task: "ShuffleCommand implementation"
Task: "MagnetCommand implementation"
Task: "DoubleCommand implementation"
```

## Notes
- Swift 6 strict concurrency must be enabled in all packages
- Use @Observable and @Bindable, NOT @StateObject/@ObservableObject
- All stores must use @MainActor for UI thread safety
- Deterministic RNG essential for replay support
- 33 pre-populated tasks distributed across game modes as specified
- Initial profile: 305 coins, [3,2,5,1,0,0] power-ups
- Fixed 5×8 board dimensions (not configurable)
- Chain validation: first two equal, subsequent same or double

## Validation Checklist
- ✅ All 5 contracts have corresponding test tasks (T007-T011)
- ✅ All 10 entities have model tasks (T022-T031)
- ✅ All tests come before implementation (T007-T021 before T022-T070)
- ✅ Parallel tasks in different files/packages
- ✅ Each task specifies exact file path
- ✅ No [P] tasks modify the same file
- ✅ TDD cycle enforced with failing tests first
- ✅ 60 FPS performance validation included (T020, T071)
- ✅ <500ms audio crossfade validation included (T015, T072)
- ✅ All 6 power-ups have command tasks (T038-T043)
- ✅ All 6 themes covered in MusicTheme model (T024)
- ✅ 33 sample tasks addressed (T025, T060)
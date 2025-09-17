# Tasks: Create 2244 - Initial Playable Shell

**Input**: Design documents from `/specs/003-create-2244-initial/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Quick Reference Guide for Implementation
When implementing each task, refer to these specific sections:
- **Profile System**: data-model.md lines 8-75, contracts/profile.yaml
- **Game Session**: data-model.md lines 77-126, contracts/game-state.yaml
- **Audio Architecture**: research.md lines 8-49, contracts/audio.yaml
- **Power-Ups**: research.md lines 105-138, data-model.md lines 52-59
- **Board Config**: research.md lines 190-204, data-model.md lines 96-105
- **Tasks System**: research.md lines 74-103, data-model.md lines 183-244
- **IAP Products**: research.md lines 170-188, contracts/iap.yaml
- **Theme Assets**: research.md lines 51-72, data-model.md lines 128-181

## Critical Implementation Notes

### Initial Values & Defaults
- **Profile Start**: 305 coins, 0 gems, power-ups: [3 hammer, 2 swap, 5 undo, 1 shuffle, 0 magnet, 0 double]
- **Board**: EXACTLY 5 columns × 8 rows (not variable)
- **Daily Spin**: 24-hour cooldown from last spin
- **Ad Rewards**: 30 gems per video, max 5 per day
- **Theme Crossfade**: Must complete in <500ms
- **Audio Latency**: <50ms for sound effects

### Swift 6 Requirements
- Use @Observable, NOT @StateObject/@ObservableObject
- @MainActor for all UI-related stores
- NEVER put @AppStorage inside @Observable classes
- Inject services via @Environment, not view properties
- Swift Testing framework only (not XCTest)

### File Structure Rules
- Each package task works on separate file = can parallelize
- Tasks modifying same file must be sequential
- Contract tests must fail before implementation begins

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → Feature spec loaded successfully
   → Project Type: iOS mobile app with modular Swift packages
2. Load optional design documents:
   → data-model.md: Profile, GameSession, MusicTheme, ProjectTask entities
   → contracts/: profile.yaml, game-state.yaml, audio.yaml, iap.yaml, rewards.yaml
   → research.md: Technical decisions documented
3. Generate tasks by category:
   → Setup: Firebase SDK, Google AdMob configuration (4 tasks)
   → Tests: Contract tests, integration tests (15 tasks)
   → Core: Models, stores, game logic (18 tasks)
   → UI: Views, navigation, themes (14 tasks)
   → Services: Audio, haptics, IAP, ads (12 tasks)
   → Integration: Game Center, leaderboards (6 tasks)
   → Polish: Sample tasks, performance (5 tasks)
4. Apply task rules:
   → Different packages = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001-T074)
6. Validate task completeness:
   → All contracts have tests ✓
   → All entities have models ✓
   → All features implemented ✓
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **GameCore**: `Packages/GameCore/Sources/GameCore/`
- **GameApp**: `Packages/GameApp/Sources/GameApp/`
- **GameUI**: `Packages/GameUI/Sources/GameUI/`
- **GameServices**: `Packages/GameServices/Sources/GameServices/`
- **Tests**: `Packages/[Package]/Tests/[Package]Tests/`

## Phase 3.1: Setup & External Dependencies
- [ ] T001 Configure Firebase SDK in game2244.xcodeproj for analytics and remote config
- [ ] T002 [P] Configure Google AdMob SDK with test ad units in game2244.xcodeproj
- [ ] T003 [P] Configure Game Center entitlements in game2244.entitlements
- [ ] T004 [P] Set up StoreKit configuration file for IAP testing in Configuration.storekit

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

### Contract Tests
- [ ] T005 [P] Contract test for Profile structure in Packages/GameCore/Tests/GameCoreTests/ProfileContractTests.swift
  - Reference: contracts/profile.yaml lines 99-221 (Profile schema)
  - Validate: Initial inventory (3 hammers, 2 swaps, 5 undos, 1 shuffle), 305 coins
- [ ] T006 [P] Contract test for GameSession state in Packages/GameCore/Tests/GameCoreTests/GameSessionContractTests.swift
  - Reference: contracts/game-state.yaml lines 145-188 (GameSession schema)  
  - Validate: 5×8 board dimensions, seed for deterministic replay
- [ ] T007 [P] Contract test for MusicTheme structure in Packages/GameServices/Tests/GameServicesTests/MusicThemeContractTests.swift
  - Reference: contracts/audio.yaml (MusicTheme schema)
  - Validate: 6 themes (3 free, 3 IAP), crossfade properties
- [ ] T008 [P] Contract test for IAP products in Packages/GameServices/Tests/GameServicesTests/IAPContractTests.swift
  - Reference: contracts/iap.yaml (Product schemas)
  - Validate: Product IDs match research.md lines 178-187
- [ ] T009 [P] Contract test for Rewards system in Packages/GameCore/Tests/GameCoreTests/RewardsContractTests.swift
  - Reference: contracts/rewards.yaml (SpinWheel, TimeLimitedOffer schemas)
  - Validate: Reward types, daily spin logic

### Integration Tests
- [ ] T010 [P] Integration test for profile auto-loading in Packages/GameApp/Tests/GameAppTests/ProfileAutoLoadTests.swift
  - Reference: quickstart.md lines 40-51 (expected initial state)
  - Test: Auto-load without login, verify initial inventory
- [ ] T011 [P] Integration test for chain validation rules in Packages/GameCore/Tests/GameCoreTests/ChainValidationTests.swift
  - Reference: CLAUDE.md chain validation rules, contracts/game-state.yaml lines 39-69
  - Test: First two equal, subsequent same/double, adjacency, no duplicates
- [ ] T012 [P] Integration test for power-up consumption in Packages/GameCore/Tests/GameCoreTests/PowerUpIntegrationTests.swift
  - Reference: research.md lines 105-138 (command pattern), data-model.md lines 52-59
  - Test: Each power-up type execution and undo
- [ ] T013 [P] Integration test for theme switching in Packages/GameServices/Tests/GameServicesTests/ThemeSwitchingTests.swift
  - Reference: research.md lines 31-49 (dual-buffer, <500ms crossfade)
  - Test: Crossfade timing, memory management
- [ ] T014 [P] Integration test for daily challenge seed generation in Packages/GameCore/Tests/GameCoreTests/DailyChallengeTests.swift
  - Reference: CLAUDE.md (SHA256(salt + date)), contracts/game-state.yaml lines 22-27
  - Test: Same seed per day, different across days
- [ ] T015 [P] Integration test for task progress tracking in Packages/GameApp/Tests/GameAppTests/TaskProgressTests.swift
  - Reference: data-model.md lines 234-244, quickstart.md lines 108-118
  - Test: Status transitions, 33 pre-populated tasks
- [ ] T016 [P] Integration test for leaderboard submission in Packages/GameServices/Tests/GameServicesTests/LeaderboardTests.swift
  - Reference: data-model.md lines 339-358, quickstart.md lines 161-172
  - Test: Auto-submit scores, rank updates
- [ ] T017 [P] Integration test for ad rewards in Packages/GameServices/Tests/GameServicesTests/AdRewardsTests.swift
  - Reference: data-model.md lines 360-382, quickstart.md lines 151-159
  - Test: 30 gems per ad, daily limit 5
- [ ] T018 [P] Integration test for spin wheel rewards in Packages/GameCore/Tests/GameCoreTests/SpinWheelTests.swift
  - Reference: data-model.md lines 283-306, quickstart.md lines 151-153
  - Test: 24-hour cooldown, reward distribution
- [ ] T019 [P] Integration test for time-limited offers in Packages/GameServices/Tests/GameServicesTests/TimeLimitedOffersTests.swift
  - Reference: data-model.md lines 309-336, quickstart.md lines 157-159
  - Test: Countdown timer, offer expiration

## Phase 3.3: Core Implementation (ONLY after tests are failing)

### Data Models
- [ ] T020 [P] Profile entity with initial inventory in Packages/GameCore/Sources/GameCore/Models/Profile.swift
  - Reference: data-model.md lines 8-75 (Profile struct)
  - Implement: powerUpInventory with defaults (3,2,5,1,0,0), 305 coins initial
- [ ] T021 [P] GameSession entity with 5×8 board in Packages/GameCore/Sources/GameCore/Models/GameSession.swift
  - Reference: data-model.md lines 77-126 (GameSession, Board, Tile)
  - Implement: Fixed 5×8 dimensions, deterministic seed support
- [ ] T022 [P] MusicTheme entity in Packages/GameServices/Sources/GameServices/Models/MusicTheme.swift
  - Reference: data-model.md lines 128-181 (MusicTheme, HapticPattern)
  - Implement: 6 themes with sound effects and haptic mappings
- [ ] T023 [P] ProjectTask entity in Packages/GameCore/Sources/GameCore/Models/ProjectTask.swift
  - Reference: data-model.md lines 183-244 (ProjectTask, TaskRequirement, TaskReward)
  - Implement: Category system, requirement validation
- [ ] T024 [P] SpinWheelReward entity in Packages/GameCore/Sources/GameCore/Models/SpinWheelReward.swift
  - Reference: data-model.md lines 283-306 (SpinWheelReward, DailySpinResult)
  - Implement: Weight-based probability, jackpot flag
- [ ] T025 [P] TimeLimitedOffer entity in Packages/GameServices/Sources/GameServices/Models/TimeLimitedOffer.swift
  - Reference: data-model.md lines 309-336 (TimeLimitedOffer, OfferItem)
  - Implement: Expiration tracking, discount calculations

### Game Logic
- [ ] T026 Update Board to 5×8 configuration in Packages/GameCore/Sources/GameCore/Engine/Board.swift
  - Reference: research.md lines 190-204, data-model.md lines 96-105
  - Implement: Fixed 5 columns × 8 rows, adaptive cell sizing
- [ ] T027 Implement PowerUpManager with command pattern in Packages/GameCore/Sources/GameCore/Engine/PowerUpManager.swift
  - Reference: research.md lines 105-138 (PowerUpCommand protocol)
  - Implement: canExecute, execute, undo for each power-up type
- [ ] T028 [P] Implement ProfileManager with auto-load in Packages/GameCore/Sources/GameCore/Managers/ProfileManager.swift
  - Reference: quickstart.md lines 40-42, data-model.md lines 475-487
  - Implement: UserDefaults persistence, auto-create default profile
- [ ] T029 [P] Implement deterministic RNG for daily mode in Packages/GameCore/Sources/GameCore/Engine/RandomNumberGenerator.swift
  - Reference: CLAUDE.md (SHA256 seed), contracts/game-state.yaml lines 22-27
  - Implement: Seeded RNG for replay support, daily seed generation
- [ ] T030 Update chain validation for new rules in Packages/GameCore/Sources/GameCore/Engine/ChainValidator.swift
  - Reference: CLAUDE.md chain rules, contracts/game-state.yaml lines 39-69
  - Implement: First two equal, subsequent same/double, 8-direction adjacency
- [ ] T031 [P] Implement SpinWheelManager in Packages/GameCore/Sources/GameCore/Managers/SpinWheelManager.swift
  - Reference: data-model.md lines 283-306, quickstart.md lines 151-153
  - Implement: Weight-based selection, 24-hour cooldown

### State Management
- [ ] T032 Create ProfileStore with @Observable in Packages/GameApp/Sources/GameApp/Stores/ProfileStore.swift
  - Reference: data-model.md lines 431-444 (ProfileStore definition)
  - Implement: consumePowerUp, addCoins, unlockTheme, updateTaskProgress methods
- [ ] T033 Update GameStore for new features in Packages/GameApp/Sources/GameApp/Stores/GameStore.swift
  - Reference: data-model.md lines 416-427 (GameStore updates)
  - Implement: @Observable with @MainActor, no @AppStorage inside
- [ ] T034 [P] Create ThemeStore for audio management in Packages/GameApp/Sources/GameApp/Stores/ThemeStore.swift
  - Reference: research.md lines 31-49 (dual-buffer preloading)
  - Implement: Current + next theme loaded, <500ms crossfade
- [ ] T035 [P] Create TaskStore for progress tracking in Packages/GameApp/Sources/GameApp/Stores/TaskStore.swift
  - Reference: data-model.md lines 234-244, quickstart.md lines 228-234
  - Implement: Track 33 tasks (10 completed, 8 in progress, 15 not started)
- [ ] T036 [P] Create OfferStore for time-limited deals in Packages/GameApp/Sources/GameApp/Stores/OfferStore.swift
  - Reference: data-model.md lines 309-336 (TimeLimitedOffer)
  - Implement: Countdown timers, purchase tracking
- [ ] T037 Create SampleProjectTasks.swift with 33 tasks in Packages/GameApp/Sources/GameApp/Data/SampleProjectTasks.swift
  - Reference: quickstart.md lines 228-234 (task distribution)
  - Implement: Classic (7), Daily (12), Journey Stage 1 (5), Stage 2 (9)

## Phase 3.4: UI Implementation

### Main Hub & Navigation
- [ ] T038 Create MainMenuView with circular hub layout in Packages/GameUI/Sources/GameUI/Screens/MainMenuView.swift
- [ ] T039 Create ProgressionPathView for 512→1024→2048→4096 in Packages/GameUI/Sources/GameUI/Components/ProgressionPathView.swift
- [ ] T040 [P] Create HubFeatureButton component in Packages/GameUI/Sources/GameUI/Components/HubFeatureButton.swift
- [ ] T041 Create BottomNavigationView for profile/achievements/leaderboard/settings in Packages/GameUI/Sources/GameUI/Components/BottomNavigationView.swift

### Game UI Updates
- [ ] T042 Update BoardView for 5×8 layout in Packages/GameUI/Sources/GameUI/Game/BoardView.swift
- [ ] T043 Create PowerUpBar with inventory display in Packages/GameUI/Sources/GameUI/Game/PowerUpBar.swift
- [ ] T044 [P] Create TaskListView for sample projects in Packages/GameUI/Sources/GameUI/Components/TaskListView.swift
- [ ] T045 [P] Create ChainHighlightView for validation feedback in Packages/GameUI/Sources/GameUI/Game/ChainHighlightView.swift

### Feature Screens
- [ ] T046 [P] Create ThemeSelectorView in Packages/GameUI/Sources/GameUI/Screens/ThemeSelectorView.swift
- [ ] T047 [P] Create SpinWheelView with animation in Packages/GameUI/Sources/GameUI/Screens/SpinWheelView.swift
- [ ] T048 [P] Create LeaderboardView with Game Center integration in Packages/GameUI/Sources/GameUI/Screens/LeaderboardView.swift
- [ ] T049 [P] Create ShopView with IAP products in Packages/GameUI/Sources/GameUI/Screens/ShopView.swift
- [ ] T050 [P] Create ChallengeDesignerView in Packages/GameUI/Sources/GameUI/Screens/ChallengeDesignerView.swift
- [ ] T051 [P] Create TimeLimitedOffersView with countdown in Packages/GameUI/Sources/GameUI/Screens/TimeLimitedOffersView.swift

## Phase 3.5: Services Implementation

### Audio System
- [ ] T052 Implement MusicThemeManager with AVAudioEngine in Packages/GameServices/Sources/GameServices/Audio/MusicThemeManager.swift
  - Reference: research.md lines 8-29 (AVAudioEngine node structure)
  - Implement: AVAudioPlayerNode → AVAudioMixerNode → AVAudioUnitReverb → Main mixer
  - Crossfade: 400ms ramp down/up overlapping (research.md lines 43-48)
- [ ] T053 Update AudioService for theme crossfade in Packages/GameServices/Sources/GameServices/Audio/AudioService.swift
  - Reference: research.md lines 31-49 (dual-buffer preloading)
  - Implement: Keep current + next theme in memory (~20MB each)
  - Fallback chain: Theme → Classic → Silent
- [ ] T054 [P] Create theme audio assets in MusicThemes.xcassets for Classic/Minimal/Retro
  - Reference: research.md lines 51-72 (asset organization)
  - Structure: background.m4a, effects.json, haptics.json per theme
- [ ] T055 [P] Configure theme-specific haptic patterns in Packages/GameServices/Sources/GameServices/Haptics/ThemeHaptics.swift
  - Reference: research.md lines 140-153 (haptic patterns by theme)
  - Implement: Classic (subtle), Retro (sharp clicks), Cyberpunk (glitchy)

### Platform Services
- [ ] T056 [P] Implement AdService with Google AdMob in Packages/GameServices/Sources/GameServices/Ads/AdService.swift
- [ ] T057 [P] Implement GameCenterService for leaderboards in Packages/GameServices/Sources/GameServices/GameCenter/GameCenterService.swift
- [ ] T058 [P] Update PurchaseService with StoreKit 2 products in Packages/GameServices/Sources/GameServices/IAP/PurchaseService.swift
- [ ] T059 [P] Implement FirebaseService for analytics in Packages/GameServices/Sources/GameServices/Analytics/FirebaseService.swift

### Offer & Reward Services
- [ ] T060 [P] Implement RewardedAdService in Packages/GameServices/Sources/GameServices/Ads/RewardedAdService.swift
- [ ] T061 [P] Implement OfferService for time-limited deals in Packages/GameServices/Sources/GameServices/Offers/OfferService.swift
- [ ] T062 [P] Implement NotificationService for daily reminders in Packages/GameServices/Sources/GameServices/Notifications/NotificationService.swift
- [ ] T063 [P] Implement RemoteConfigService with Firebase in Packages/GameServices/Sources/GameServices/Config/RemoteConfigService.swift

## Phase 3.6: Integration & Polish

### System Integration
- [ ] T064 Wire up dependency injection in game2244/App.swift with @Environment keys
- [ ] T065 Configure app launch sequence with profile auto-load in game2244/App.swift
- [ ] T066 [P] Set up UserDefaults persistence for profile and settings
- [ ] T067 [P] Configure JSON storage for challenges and saves
- [ ] T068 [P] Integrate Firebase SDK initialization in app delegate
- [ ] T069 [P] Configure AdMob banner and rewarded video placements

### Polish & Performance
- [ ] T070 [P] Implement frame rate monitoring with CADisplayLink
- [ ] T071 [P] Add loading states and error handling throughout UI
- [ ] T072 [P] Configure app icons and launch screen
- [ ] T073 Verify 60 FPS performance during gameplay
- [ ] T074 Run quickstart.md validation checklist

## Dependencies
- Setup (T001-T004) must complete first
- Tests (T005-T019) before implementation (T020-T063)  
- Models (T020-T025) before game logic (T026-T031)
- State management (T032-T037) before UI (T038-T051)
- UI components before integration (T064-T069)
- All implementation before polish (T070-T074)

## Parallel Execution Examples

### Initial Setup (can run all together):
```
Task: "Configure Firebase SDK in game2244.xcodeproj"
Task: "Configure Google AdMob SDK in game2244.xcodeproj"
Task: "Configure Game Center entitlements"
Task: "Set up StoreKit configuration file"
```

### Contract Tests (launch T005-T009 together):
```
Task: "Contract test for Profile structure"
Task: "Contract test for GameSession state"
Task: "Contract test for MusicTheme structure"
Task: "Contract test for IAP products"
Task: "Contract test for Rewards system"
```

### Integration Tests (launch T010-T019 together):
```
Task: "Integration test for profile auto-loading"
Task: "Integration test for chain validation rules"
Task: "Integration test for power-up consumption"
Task: "Integration test for theme switching"
Task: "Integration test for daily challenge seed"
```

### Data Models (launch T020-T025 together):
```
Task: "Profile entity with initial inventory"
Task: "GameSession entity with 5×8 board"
Task: "MusicTheme entity"
Task: "ProjectTask entity"
Task: "SpinWheelReward entity"
Task: "TimeLimitedOffer entity"
```

## Notes
- [P] tasks work on different packages/files with no dependencies
- Verify all tests fail before implementing features (TDD)
- Commit after each task completion
- Use Swift Testing framework, not XCTest
- Follow Swift 6 concurrency with @Observable/@Bindable patterns
- Maintain 60 FPS target throughout implementation

## Task Generation Summary
- **Total Tasks**: 74
- **Setup Tasks**: 4
- **Test Tasks**: 15 (must fail first)
- **Core Implementation**: 18 (models + logic)
- **UI Tasks**: 14 (views + components)
- **Service Tasks**: 12 (audio, ads, IAP)
- **Integration Tasks**: 6 (wiring + config)
- **Polish Tasks**: 5 (performance + validation)

## Validation Checklist
- [x] All 5 contracts have corresponding test tasks with specific schema references
- [x] All 9 entities have model tasks with line-by-line implementation guides
- [x] All tests come before implementation with validation criteria
- [x] Parallel tasks work on different files/packages
- [x] Each task specifies exact file path and design doc references
- [x] No parallel task modifies same file as another [P] task
- [x] Task numbering is sequential (T001-T074)
- [x] Dependencies clearly documented with rationale

## Task Execution Helper

### When Starting a Task:
1. Read the task description and references
2. Open the referenced design document sections
3. Check if file already exists (prefer editing over creating)
4. For tests: Write to fail first, verify failure
5. For implementation: Follow exact specifications from references
6. Verify against quickstart.md acceptance criteria

### Key Design Document Sections by Feature:
- **Profile Auto-Load**: quickstart.md lines 40-51, data-model.md lines 8-75
- **Chain Validation**: CLAUDE.md (rules section), contracts/game-state.yaml lines 39-69
- **Audio System**: research.md lines 8-72 (complete architecture)
- **Power-Ups**: research.md lines 105-138 (command pattern), line 125-137 (initial counts)
- **Sample Tasks**: quickstart.md lines 228-234 (exact distribution)
- **Theme Switching**: research.md lines 31-49 (<500ms requirement)
- **Daily Challenge**: CLAUDE.md (SHA256 seed), data-model.md lines 77-126

### Common Pitfalls to Avoid:
- Don't use @StateObject or ObservableObject (use @Observable)
- Don't put @AppStorage in @Observable classes
- Don't use XCTest (use Swift Testing framework)
- Don't create variable board sizes (fixed 5×8)
- Don't skip writing failing tests first
- Don't forget initial inventory values (3,2,5,1,0,0)
- Don't miss the 305 coins starting value
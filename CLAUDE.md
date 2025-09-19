# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

2244 is a puzzle game for iOS 18+ built with Swift 6, SwiftUI, and modular architecture. Players connect adjacent tiles to create chains and merge them for higher scores.

## Build and Test Commands

### Building the Project
```bash
# Build workspace for iOS Simulator
xcodebuild -workspace game2244.xcworkspace -scheme game2244 -configuration Debug -sdk iphonesimulator -quiet clean build

# Run tests
xcodebuild test -workspace game2248.xcworkspace -scheme game2248 -destination 'platform=iOS Simulator,name=iPhone 16' -quiet

# Test individual packages
swift test --package-path Packages/GameCore
```

## Architecture

### Modular Structure
- **GameCore**: Pure Swift game engine with deterministic RNG, board logic, chain validation
- **GameApp**: State management (@Observable stores), dependency injection keys
- **GameUI**: SwiftUI views, gesture handling, theming system  
- **GameServices**: StoreKit 2, ad service protocols, haptics, remote config
- **GameTestingSupport**: Test fixtures, mocks, snapshot helpers

### Key Implementation Details

**Observation Pattern**: Uses @Observable and @Bindable, NOT @StateObject/@ObservableObject.

**Dependency Injection**: All services injected via @Environment, not view properties:
```swift
@Environment(\.gameStore) private var gameStore
@Environment(\.purchaseService) private var purchaseService
```

**Chain Validation Rules**:
1. First two tiles must be equal
2. Subsequent tiles must be same or double previous
3. All tiles must be adjacent (8 directions)
4. No duplicate positions in chain

**Deterministic RNG**: Engine uses seeded RNG for replay support. Daily mode uses SHA256(salt + date).

**StoreKit Integration**: Uses StoreKit 2 with placeholder product ID `com.game2244.adfree`

### Development Guidelines
- Swift 6 strict concurrency enabled
- iOS 18+ minimum deployment
- Swift Testing framework (not XCTest)
- No @AppStorage inside @Observable classes

## Recent Updates (Feature 003: Initial Playable Shell)

### Audio Architecture
- **AVAudioEngine** for multi-theme music system with <500ms crossfade
- **Dual-buffer preloading**: Current + next theme in memory
- **Theme assets**: Separate asset catalogs with fallback chain
- **6 themes**: Classic, Minimal, Retro (free); Cyberpunk, Lofi, Orchestral (IAP)

### Power-Up System
- **Protocol-based commands**: PowerUpCommand protocol for all power-ups
- **Initial inventory**: 3 Hammers, 2 Swaps, 5 Undos, 1 Shuffle, 0 Magnets, 0 Doubles
- **6 power-up types**: Hammer, Swap, Magnet, Shuffle, Undo, Double

### Board Configuration
- **5×8 fixed layout** (5 columns, 8 rows)
- **Adaptive sizing** based on screen width
- **Tile values**: 2 to infinity using AlphaMag progression

### Profile System
- **Single default profile** auto-loads on launch
- **UserDefaults persistence** for profile data
- **305 starting coins** for new profiles

### Sample Projects
- **33 pre-populated tasks** across 3 game modes
- **Task states**: Completed, In Progress, Not Started
- **JSON-defined** tasks with UserDefaults progress tracking
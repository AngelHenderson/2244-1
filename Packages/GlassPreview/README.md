# Glass Preview Row - 2244 Game Feature

A drop-in SwiftPM module implementing the Glass Preview Row feature for 2244-style tile-linking games.

## Overview

This module adds a "glass preview row" above the main game grid where upcoming tiles spawn inside glass bubbles. Players can shatter the glass by ending chains on these preview tiles to earn power-up rewards.

## Features

### Core Mechanics
- **Glass Preview Row**: 1:1 aligned above the play grid, one preview slot per column
- **Glass Interaction**: Preview tiles spawn in glass bubbles that can be shattered for rewards
- **2244 Linking Rules**: 8-direction adjacency, start with ≥2 identical tiles, continue with same or double values
- **Chain Validation**: Comprehensive rule enforcement with helpful error messages
- **Power-up Rewards**: Weighted random rewards (hammer, swap, magnet, shuffle, undo, bomb)

### Visual & Theme
- **Background**: Solid dark blue (#020617) as specified
- **Glass Effects**: Animated glass overlay with shimmer effects
- **Shatter Animation**: Visual feedback when glass breaks
- **Tile Colors**: Value-based color coding with smooth animations

### Technical Features
- **Deterministic RNG**: Seeded random generation for consistent testing
- **Analytics Events**: Comprehensive event tracking for all game actions
- **Debug HUD**: Full debugging interface for testing and development
- **Configuration**: Remote-configurable reward weights and game rules
- **Swift 6 Compliant**: Modern Swift with strict concurrency

## Quick Start

```swift
import SwiftUI
import GlassPreview

struct ContentView: View {
    var body: some View {
        GlassPreview.gameView()
    }
}
```

## Advanced Usage

### Custom Configuration

```swift
let config = GlassGameStore.Config(
    giftWeights: [
        .hammer: 30,
        .swap: 20,
        .magnet: 15,
        .shuffle: 15,
        .undo: 15,
        .bomb: 5
    ],
    giftOnAutoDrop: false,
    requireDirectBelowInChain: true,
    backgroundColorHex: "#020617"
)

let gameView = GlassPreview.gameView(
    cols: 5,
    rows: 8,
    seed: 12345,
    config: config
)
```

### Using the Game Store Directly

```swift
@State private var gameStore = GlassPreview.gameStore(seed: 42)

var body: some View {
    VStack {
        // Custom UI using gameStore
        Text("Score: \\(gameStore.score)")
        
        // Chain building
        Button("Start Chain") {
            gameStore.beginChain(at: Point(col: 0, row: 0))
        }
        
        Button("Commit Chain") {
            gameStore.commitChain()
        }
    }
}
```

### Configuration Presets

```swift
// Balanced gameplay
GlassPreview.gameView(config: .balanced)

// More frequent rewards
GlassPreview.gameView(config: .generous)

// Challenging gameplay
GlassPreview.gameView(config: .challenging)

// Testing with guaranteed rewards
GlassPreview.gameView(config: GlassPreview.testConfig)
```

## Game Rules

### Chain Building
1. **Start**: Begin with ≥2 adjacent identical tiles
2. **Continue**: Add tiles with same value OR exactly double the previous value
3. **Direction**: 8-direction adjacency (including diagonals)
4. **Constraints**: Each tile used only once per chain, lines may cross

### Glass Mechanics
1. **Preview Tiles**: Spawn in glass bubbles in the preview row
2. **Glass Interaction**: Cannot start chains on glass, can only end chains on glass
3. **Shatter Condition**: End chain on glass tile that's directly above the previous tile
4. **Rewards**: One random power-up per glass shatter
5. **Auto-drop**: Glass removed without reward when tiles drop naturally

### Power-ups
- **Hammer** (30%): Destroy chosen tile
- **Swap** (20%): Swap any two adjacent tiles  
- **Magnet** (15%): Pull same numbers together
- **Shuffle** (15%): Randomize board layout
- **Undo** (15%): Undo last move
- **Bomb** (5%): Clear 3×3 area

## Debug Features

The module includes a comprehensive debug HUD accessible in-game:

- **Game State**: Current score, moves, chain status
- **Preview Queues**: Visual representation of upcoming tiles
- **Power-up Inventory**: Current power-up counts
- **Analytics**: Real-time event tracking
- **Debug Actions**: Force all glass, custom seeds, manual rewards
- **Configuration**: Live view of all game settings

Access the debug HUD by tapping the "Debug" button in the game view.

## Analytics Events

The module automatically tracks:
- `session_start`: Game initialization with seed
- `merge_chain`: Chain completion with length, values, glass status
- `glass_break`: Glass shatter with column, age, reward type
- `preview_refill`: Tile drops from preview to board
- `powerup_use`: Power-up usage with board state hash

## Testing

Comprehensive test suite covering:
- Core data model functionality
- Chain building and validation rules
- Glass interaction mechanics
- Power-up reward system
- Analytics event generation
- Edge cases and error conditions

Run tests with:
```bash
swift test
```

## Integration

This module is designed to integrate with existing 2244-style games:

1. **Drop-in Replacement**: Use `GlassGameView` as a complete game screen
2. **Custom Integration**: Use `GlassGameStore` with your own UI
3. **Legacy Compatibility**: Convert to/from existing game state formats
4. **Modular Design**: Import only the components you need

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- SwiftUI

## Architecture

The module follows clean architecture principles:

- **Data Layer**: `GlassDataModel.swift` - Core data structures
- **Business Logic**: `GlassGameStore.swift` - Game state management
- **Presentation**: `GlassPreviewViews.swift` - SwiftUI components
- **Debug Tools**: `GlassDebugHUD.swift` - Development utilities
- **Public API**: `GlassPreview.swift` - Clean public interface

All components are designed to be testable, maintainable, and performant.

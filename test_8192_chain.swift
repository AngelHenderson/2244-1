#!/usr/bin/env swift

import Foundation
import GameCore

// Create engine with deterministic seed
let config = GameConfig(
    boardWidth: 5,
    boardHeight: 8,
    seed: 12345,
    fillMode: .alwaysFull
)
let engine = GameEngine(config: config)

// Clear board and set up 40 tiles of value 128
engine._setAllTilesForTesting(value: nil)
engine._resetScoreForTesting()

// Place 40 tiles of 128 in a pattern
var positions: [Position] = []
var tilesPlaced = 0
for row in 1..<8 { // Start from row 1 to avoid top row
    for col in 0..<5 {
        if tilesPlaced < 40 {
            let pos = Position(row: row, col: col)
            engine._setTileForTesting(at: pos, value: 128)
            positions.append(pos)
            tilesPlaced += 1
        }
    }
}

print("📊 Test Setup:")
print("   Placed \(tilesPlaced) tiles of value 128")

// Simulate connecting all 40 tiles (they need to be adjacent)
// For testing, we'll create a simplified chain
var chainPositions: [Position] = []
// Create a valid chain by selecting tiles that are actually adjacent
for row in 1..<4 {
    for col in 0..<5 {
        let pos = Position(row: row, col: col)
        chainPositions.append(pos)
        if chainPositions.count >= 40 {
            break
        }
    }
    if chainPositions.count >= 40 {
        break
    }
}

// Ensure we have exactly 40 positions
while chainPositions.count < 40 {
    let row = 3 + (chainPositions.count - 15) / 5
    let col = (chainPositions.count - 15) % 5
    chainPositions.append(Position(row: row, col: col))
}

print("\n🔗 Creating chain of \(chainPositions.count) tiles...")
let stateBefore = engine.currentState()
let tilesBefore = stateBefore.board.tiles().count

// Commit the chain
let result = engine.commitChain(chainPositions, applyGravity: false)

print("\n📈 Results:")
print("   Score: \(result.score)")
print("   Highest tile: \(result.highestTile)")
print("   Tiles before: \(tilesBefore)")
print("   Tiles after: \(result.board.tiles().count)")

// Check what value was created
var createdValue: Int? = nil
for pos in chainPositions {
    if let tile = result.board[pos] {
        createdValue = tile.value
        print("   Created tile value: \(tile.value) at \(pos)")
        break
    }
}

if let value = createdValue, value == 8192 {
    print("\n✅ Successfully created 8192 from 40×128 chain!")
    print("⚠️  8192 is a SKIP milestone - no tiles should be eliminated")
}
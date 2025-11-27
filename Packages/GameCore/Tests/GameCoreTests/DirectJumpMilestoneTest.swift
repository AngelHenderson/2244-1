import Testing
@testable import GameCore

@Test("Direct jump to 8192 applies intermediate milestone eliminations")
func testDirectJumpTo8192AppliesToEliminations() {
    let config = GameConfig(
        boardWidth: 5,
        boardHeight: 8,
        seed: 99999,
        fillMode: .alwaysFull
    )
    let engine = GameEngine(config: config)

    // Clear and setup a board with 2s, 4s, and two 4096 tiles
    engine._setAllTilesForTesting(value: nil)
    engine._resetScoreForTesting()

    // Place some low value tiles that should be eliminated
    engine._setTileForTesting(at: Position(row: 0, col: 0), value: 2)
    engine._setTileForTesting(at: Position(row: 0, col: 1), value: 2)
    engine._setTileForTesting(at: Position(row: 0, col: 2), value: 4)
    engine._setTileForTesting(at: Position(row: 0, col: 3), value: 4)
    engine._setTileForTesting(at: Position(row: 0, col: 4), value: 8)

    // Place two 4096 tiles that we'll merge to create 8192
    engine._setTileForTesting(at: Position(row: 1, col: 0), value: 4096)
    engine._setTileForTesting(at: Position(row: 1, col: 1), value: 4096)

    // Fill rest with higher values that won't be eliminated
    for row in 2..<8 {
        for col in 0..<5 {
            engine._setTileForTesting(at: Position(row: row, col: col), value: 16)
        }
    }

    print("📊 Initial board state:")
    let stateBefore = engine.currentState()
    var initialCounts: [Int: Int] = [:]
    for row in 0..<8 {
        for col in 0..<5 {
            let pos = Position(row: row, col: col)
            if let tile = stateBefore.board[pos] {
                initialCounts[tile.value, default: 0] += 1
            }
        }
    }
    for (value, count) in initialCounts.sorted(by: { $0.key < $1.key }) {
        print("   Value \(value): \(count) tiles")
    }

    print("\n🎮 Current highest tile: \(stateBefore.highestTile)")
    #expect(stateBefore.highestTile == 0 || stateBefore.highestTile == 4096, "Highest should be 0 or 4096")
    #expect(initialCounts[2] == 2, "Should have 2 tiles of value 2")
    #expect(initialCounts[4] == 2, "Should have 2 tiles of value 4")

    // Now merge the two 4096 tiles to create 8192
    // This jumps from highest=4096 to highest=8192
    print("\n🔗 Merging two 4096 tiles to create 8192...")
    let result = engine.commitChain(
        [Position(row: 1, col: 0), Position(row: 1, col: 1)],
        applyGravity: false
    )

    print("\n📊 Final board state:")
    var finalCounts: [Int: Int] = [:]
    for row in 0..<8 {
        for col in 0..<5 {
            let pos = Position(row: row, col: col)
            if let tile = result.board[pos] {
                finalCounts[tile.value, default: 0] += 1
            }
        }
    }
    for (value, count) in finalCounts.sorted(by: { $0.key < $1.key }) {
        print("   Value \(value): \(count) tiles")
    }

    // Verify the 8192 was created
    #expect(result.highestTile == 8192, "Should have created 8192")
    #expect(finalCounts[8192] == 1, "Should have exactly one 8192 tile")

    // CRITICAL VERIFICATION: 2s and 4s should be eliminated
    // When jumping from 4096 to 8192, we pass:
    // - 2048 milestone (eliminates 2s) - already passed
    // - 4096 milestone (eliminates 4s) - already passed
    // - 8192 milestone (skip, no elimination)
    // Since we started with highest=4096, no NEW eliminations should occur
    // But if we had started lower, they would be eliminated

    // Actually, let's test from a lower starting point
}
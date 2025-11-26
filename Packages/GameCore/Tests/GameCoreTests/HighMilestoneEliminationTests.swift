import Testing
import Foundation
@testable import GameCore

struct HighMilestoneEliminationTests {

    @Test("Reaching 4 trillion eliminates 33M and 67M tiles")
    func testFourTrillionEliminatesMegaTiles() {
        let config = GameConfig(boardWidth: 4, boardHeight: 4, seed: 12345)
        let engine = GameEngine(config: config)

        // Clear board and set up test scenario
        engine._setAllTilesForTesting(value: nil)

        // Place some 33M and 67M tiles on the board
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 33_554_432)  // 33M
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 67_108_864)  // 67M
        engine._setTileForTesting(at: Position(row: 0, col: 2), value: 33_554_432)  // 33M
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 134_217_728) // 134M

        // Place two ~2 trillion tiles to merge into ~4 trillion
        let twoTrillion = 2_199_023_255_552  // 2^41
        engine._setTileForTesting(at: Position(row: 2, col: 0), value: twoTrillion)
        engine._setTileForTesting(at: Position(row: 2, col: 1), value: twoTrillion)

        print("Board before creating 4T milestone:")
        for row in 0..<4 {
            for col in 0..<4 {
                if let tile = engine.currentState().board[Position(row: row, col: col)] {
                    print("  [\(row),\(col)]: \(formatValue(tile.value))")
                }
            }
        }

        // Merge to create 4 trillion milestone
        let chain = [Position(row: 2, col: 0), Position(row: 2, col: 1)]
        let state = engine.commitChain(chain)

        print("\nBoard after creating 4T milestone:")
        var found33M = false
        var found67M = false
        var found134M = false

        for row in 0..<4 {
            for col in 0..<4 {
                if let tile = state.board[Position(row: row, col: col)] {
                    let value = tile.value
                    print("  [\(row),\(col)]: \(formatValue(value))")

                    if value == 33_554_432 {
                        found33M = true
                    } else if value == 67_108_864 {
                        found67M = true
                    } else if value == 134_217_728 {
                        found134M = true
                    }
                }
            }
        }

        // After creating 4T, all tiles below 268M should be eliminated
        // 4T >> 14 = 268M threshold
        #expect(!found33M, "33M tiles should be eliminated (below 268M threshold)")
        #expect(!found67M, "67M tiles should be eliminated (below 268M threshold)")
        #expect(!found134M, "134M tiles should be eliminated (below 268M threshold)")

        // The merged tile should be approximately 4 trillion
        #expect(state.highestTile >= 4_000_000_000_000, "Should have created ~4T tile")
    }

    @Test("Threshold elimination removes all tiles below cutoff")
    func testThresholdElimination() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 99999)
        let engine = GameEngine(config: config)

        // Clear and setup various tile values
        engine._setAllTilesForTesting(value: nil)

        // Place a variety of tiles
        let testValues = [
            16_777_216,    // 16M
            33_554_432,    // 33M
            67_108_864,    // 67M
            134_217_728,   // 134M
            268_435_456,   // 268M
            536_870_912,   // 536M
        ]

        for (index, value) in testValues.enumerated() {
            let row = index / 3
            let col = index % 3
            engine._setTileForTesting(at: Position(row: row, col: col), value: value)
        }

        // Create a 1 trillion tile (which should eliminate everything below 61M)
        // 1T >> 14 ≈ 61M
        let halfTrillion = 549_755_813_888  // ~0.5T
        engine._setTileForTesting(at: Position(row: 2, col: 0), value: halfTrillion)
        engine._setTileForTesting(at: Position(row: 2, col: 1), value: halfTrillion)

        let state = engine.commitChain([Position(row: 2, col: 0), Position(row: 2, col: 1)])

        // Check what remains
        var remainingValues = Set<Int>()
        for row in 0..<3 {
            for col in 0..<3 {
                if let tile = state.board[Position(row: row, col: col)] {
                    if tile.value < 1_000_000_000_000 { // Ignore the merged tile
                        remainingValues.insert(tile.value)
                    }
                }
            }
        }

        // 1T >> 14 = 61M, so 16M and 33M should be eliminated
        #expect(!remainingValues.contains(16_777_216), "16M should be eliminated")
        #expect(!remainingValues.contains(33_554_432), "33M should be eliminated")

        // 67M and above should remain (or be replaced by new spawns)
        // Note: The board refills after elimination, so we can't check for specific values remaining
    }
}

private func formatValue(_ value: Int) -> String {
    if value >= 1_000_000_000_000 {
        return "\(value / 1_000_000_000_000)T"
    } else if value >= 1_000_000_000 {
        return "\(value / 1_000_000_000)B"
    } else if value >= 1_000_000 {
        return "\(value / 1_000_000)M"
    } else if value >= 1_000 {
        return "\(value / 1_000)K"
    } else {
        return "\(value)"
    }
}
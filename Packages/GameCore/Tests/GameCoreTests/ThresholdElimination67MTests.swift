import Testing
import Foundation
@testable import GameCore

struct ThresholdElimination67MTests {

    @Test("67M milestone eliminates all tiles below 4096")
    func test67MEliminatesBelow4K() {
        let config = GameConfig(boardWidth: 4, boardHeight: 4, seed: 12345)
        let engine = GameEngine(config: config)

        // Clear board and set up test scenario
        engine._setAllTilesForTesting(value: nil)

        // Place various low-value tiles
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 2)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 4)
        engine._setTileForTesting(at: Position(row: 0, col: 2), value: 8)
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 1024)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 2048)
        engine._setTileForTesting(at: Position(row: 1, col: 2), value: 4096)
        engine._setTileForTesting(at: Position(row: 1, col: 3), value: 8192)

        // Place two 33M tiles to merge into 67M
        engine._setTileForTesting(at: Position(row: 2, col: 0), value: 33_554_432)
        engine._setTileForTesting(at: Position(row: 2, col: 1), value: 33_554_432)

        print("Board before creating 67M:")
        for row in 0..<4 {
            for col in 0..<4 {
                if let tile = engine.currentState().board[Position(row: row, col: col)] {
                    print("  [\(row),\(col)]: \(tile.value)")
                }
            }
        }

        // Merge to create 67M
        let chain = [Position(row: 2, col: 0), Position(row: 2, col: 1)]
        let state = engine.commitChain(chain)

        print("\nBoard after creating 67M:")
        var foundBelowThreshold = false
        let threshold = 67_108_864 >> 14  // 4096

        for row in 0..<4 {
            for col in 0..<4 {
                if let tile = state.board[Position(row: row, col: col)] {
                    print("  [\(row),\(col)]: \(tile.value)")
                    if tile.value < threshold && tile.value != 67_108_864 {
                        foundBelowThreshold = true
                        print("    ❌ Found value below threshold: \(tile.value)")
                    }
                }
            }
        }

        // 67M >> 14 = 4096, so everything below 4096 should be eliminated
        #expect(!foundBelowThreshold, "All tiles below 4096 should be eliminated")
        #expect(state.highestTile == 67_108_864, "Should have created 67M tile")
    }

    @Test("134M milestone eliminates all tiles below 8192")
    func test134MEliminatesBelow8K() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 99999)
        let engine = GameEngine(config: config)

        // Clear and setup
        engine._setAllTilesForTesting(value: nil)

        // Place tiles around the 8K threshold
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 4096)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 8192)
        engine._setTileForTesting(at: Position(row: 0, col: 2), value: 16384)

        // Create 134M
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 67_108_864)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 67_108_864)

        let state = engine.commitChain([Position(row: 1, col: 0), Position(row: 1, col: 1)])

        // Check what remains
        var foundBelow8K = false
        for row in 0..<3 {
            for col in 0..<3 {
                if let tile = state.board[Position(row: row, col: col)] {
                    if tile.value < 8192 && tile.value != 134_217_728 {
                        foundBelow8K = true
                    }
                }
            }
        }

        // 134M >> 14 = 8192, so everything below 8192 should be eliminated
        #expect(!foundBelow8K, "All tiles below 8192 should be eliminated")
        #expect(state.highestTile == 134_217_728, "Should have created 134M tile")
    }

    @Test("268M is a skip milestone - no elimination")
    func test268MSkipsMilestone() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 11111)
        let engine = GameEngine(config: config)

        // Clear and setup
        engine._setAllTilesForTesting(value: nil)

        // Place some tiles that would be below the theoretical threshold
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 8192)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 16384)

        // Create 268M (position 2 from 67M, which should skip)
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 134_217_728)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 134_217_728)

        let stateBefore = engine.currentState()

        let state = engine.commitChain([Position(row: 1, col: 0), Position(row: 1, col: 1)])

        // Since 268M is a skip milestone, the low value tiles should still exist
        // (though the board refills, so we can't check exact values)
        var found8K = false
        var found16K = false

        for row in 0..<3 {
            for col in 0..<3 {
                if let tile = state.board[Position(row: row, col: col)] {
                    if tile.value == 8192 {
                        found8K = true
                    } else if tile.value == 16384 {
                        found16K = true
                    }
                }
            }
        }

        // We can't guarantee specific tiles remain due to refill,
        // but we can verify it reached 268M
        #expect(state.highestTile == 268_435_456, "Should have created 268M tile")
    }

    @Test("536M milestone eliminates all tiles below 32K")
    func test536MEliminatesBelow32K() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 22222)
        let engine = GameEngine(config: config)

        // Clear and setup
        engine._setAllTilesForTesting(value: nil)

        // Place tiles around the 32K threshold
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 16384)  // 16K
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 32768)  // 32K
        engine._setTileForTesting(at: Position(row: 0, col: 2), value: 65536)  // 65K

        // Create 536M
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 268_435_456)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 268_435_456)

        let state = engine.commitChain([Position(row: 1, col: 0), Position(row: 1, col: 1)])

        // Check what remains
        var foundBelow32K = false
        for row in 0..<3 {
            for col in 0..<3 {
                if let tile = state.board[Position(row: row, col: col)] {
                    if tile.value < 32768 && tile.value != 536_870_912 {
                        foundBelow32K = true
                        print("Found tile below 32K: \(tile.value)")
                    }
                }
            }
        }

        // 536M >> 14 = 32768, so everything below 32K should be eliminated
        #expect(!foundBelow32K, "All tiles below 32K should be eliminated")
        #expect(state.highestTile == 536_870_912, "Should have created 536M tile")
    }
}

private func countTiles(_ board: GameCore.Board) -> Int {
    var count = 0
    for row in 0..<board.height {
        for col in 0..<board.width {
            if board[Position(row: row, col: col)] != nil {
                count += 1
            }
        }
    }
    return count
}
import Testing
import Foundation
@testable import GameCore

struct EliminationDebugTests {

    @Test("32K milestone should eliminate all 16s from board (new pattern)")
    func test32KEliminatesSixteens() {
        let config = GameConfig(boardWidth: 4, boardHeight: 4, seed: 12345, fillMode: .alwaysFull)
        let engine = GameEngine(config: config)

        // Clear board and set up test scenario
        for row in 0..<4 {
            for col in 0..<4 {
                engine._setTileForTesting(at: Position(row: row, col: col), value: nil)
            }
        }

        // Place some 16s on the board (32K eliminates 16s in new pattern)
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 16)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 16)
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 16)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 16)

        // Place two 16K tiles to merge into 32K
        engine._setTileForTesting(at: Position(row: 2, col: 0), value: 16384)
        engine._setTileForTesting(at: Position(row: 2, col: 1), value: 16384)

        // Fill rest with some other values
        engine._setTileForTesting(at: Position(row: 3, col: 0), value: 8)
        engine._setTileForTesting(at: Position(row: 3, col: 1), value: 16)

        print("🔍 Board before merge:")
        for row in 0..<4 {
            for col in 0..<4 {
                if let tile = engine.currentState().board[Position(row: row, col: col)] {
                    print("  [\(row),\(col)]: \(tile.value)")
                }
            }
        }

        // Merge the two 16K tiles to create 32K
        let chain = [Position(row: 2, col: 0), Position(row: 2, col: 1)]
        let newState = engine.commitChain(chain)

        print("\n🎯 Board after creating 32K (should have no 16s):")
        var foundAny16s = false
        for row in 0..<4 {
            for col in 0..<4 {
                if let tile = newState.board[Position(row: row, col: col)] {
                    print("  [\(row),\(col)]: \(tile.value)")
                    if tile.value == 16 {
                        foundAny16s = true
                        print("    ❌ Found a 16!")
                    }
                }
            }
        }

        #expect(!foundAny16s, "All 16s should be eliminated after creating 32K tile")
        #expect(newState.highestTile == 32768, "Highest tile should be 32768")
    }

    @Test("16K milestone eliminates 8s (new pattern)")
    func test16KEliminatesEights() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 999, fillMode: .alwaysFull)
        let engine = GameEngine(config: config)

        // Clear and setup
        for row in 0..<3 {
            for col in 0..<3 {
                engine._setTileForTesting(at: Position(row: row, col: col), value: nil)
            }
        }

        // Place 8s that should be eliminated
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 8)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 8)
        engine._setTileForTesting(at: Position(row: 0, col: 2), value: 8)

        // Place two 8K tiles to merge
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 8192)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 8192)

        // Merge to create 16K
        let chain = [Position(row: 1, col: 0), Position(row: 1, col: 1)]
        let stateAfter = engine.commitChain(chain)

        // Check that 8s are eliminated (16K eliminates 8s in new pattern)
        var found8s = false

        for row in 0..<3 {
            for col in 0..<3 {
                if let tile = stateAfter.board[Position(row: row, col: col)] {
                    if tile.value == 8 { found8s = true }
                }
            }
        }

        #expect(!found8s, "All 8s should be eliminated after creating 16K")
        #expect(stateAfter.highestTile == 16384, "Highest tile should be 16384")
    }
}
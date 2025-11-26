import Testing
import Foundation
@testable import GameCore

struct EliminationDebugTests {

    @Test("32K milestone should eliminate all 2s from board")
    func test32KEliminatesTwos() {
        let config = GameConfig(boardWidth: 4, boardHeight: 4, seed: 12345, fillMode: .alwaysFull)
        let engine = GameEngine(config: config)

        // Clear board and set up test scenario
        for row in 0..<4 {
            for col in 0..<4 {
                engine._setTileForTesting(at: Position(row: row, col: col), value: nil)
            }
        }

        // Place some 2s on the board
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 2)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 2)
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 2)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 2)

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

        print("\n🎯 Board after creating 32K (should have no 2s):")
        var foundAny2s = false
        for row in 0..<4 {
            for col in 0..<4 {
                if let tile = newState.board[Position(row: row, col: col)] {
                    print("  [\(row),\(col)]: \(tile.value)")
                    if tile.value == 2 {
                        foundAny2s = true
                        print("    ❌ Found a 2!")
                    }
                }
            }
        }

        #expect(!foundAny2s, "All 2s should be eliminated after creating 32K tile")
        #expect(newState.highestTile == 32768, "Highest tile should be 32768")
    }

    @Test("16K milestone should not eliminate anything (no 1s exist)")
    func test16KDoesNotEliminateAnything() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 999, fillMode: .alwaysFull)
        let engine = GameEngine(config: config)

        // Clear and setup
        for row in 0..<3 {
            for col in 0..<3 {
                engine._setTileForTesting(at: Position(row: row, col: col), value: nil)
            }
        }

        // Place 2s, 4s, 8s
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 2)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 4)
        engine._setTileForTesting(at: Position(row: 0, col: 2), value: 8)

        // Place two 8K tiles to merge
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 8192)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 8192)

        let stateBefore = engine.currentState()

        // Merge to create 16K
        let chain = [Position(row: 1, col: 0), Position(row: 1, col: 1)]
        let stateAfter = engine.commitChain(chain)

        // Check that 2s, 4s, 8s still exist (16K eliminates 1s, which don't exist)
        var found2 = false, found4 = false, found8 = false

        for row in 0..<3 {
            for col in 0..<3 {
                if let tile = stateAfter.board[Position(row: row, col: col)] {
                    if tile.value == 2 { found2 = true }
                    if tile.value == 4 { found4 = true }
                    if tile.value == 8 { found8 = true }
                }
            }
        }

        #expect(found2 || found4 || found8, "Low value tiles should still exist after 16K (only 1s are eliminated)")
        #expect(stateAfter.highestTile == 16384, "Highest tile should be 16384")
    }
}
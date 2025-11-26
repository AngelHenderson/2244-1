import Testing
import Foundation
@testable import GameCore

struct NewEliminationPatternTests {

    @Test("2048 milestone eliminates all 2s")
    func test2048EliminatesTwos() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 12345)
        let engine = GameEngine(config: config)

        // Setup board with some 2s
        engine._setAllTilesForTesting(value: nil)
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 2)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 2)
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 1024)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 1024)

        // Create 2048 by merging
        let chain = [Position(row: 1, col: 0), Position(row: 1, col: 1)]
        let state = engine.commitChain(chain)

        // Check no 2s remain
        var found2s = false
        for row in 0..<3 {
            for col in 0..<3 {
                if let tile = state.board[Position(row: row, col: col)] {
                    if tile.value == 2 {
                        found2s = true
                    }
                }
            }
        }

        #expect(!found2s, "All 2s should be eliminated after creating 2048")
        #expect(state.highestTile == 2048)
    }

    @Test("4096 milestone eliminates all 4s")
    func test4096EliminatesFours() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 12345)
        let engine = GameEngine(config: config)

        // Setup board with some 4s
        engine._setAllTilesForTesting(value: nil)
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 4)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 4)
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 2048)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 2048)

        // Create 4096 by merging
        let chain = [Position(row: 1, col: 0), Position(row: 1, col: 1)]
        let state = engine.commitChain(chain)

        // Check no 4s remain
        var found4s = false
        for row in 0..<3 {
            for col in 0..<3 {
                if let tile = state.board[Position(row: row, col: col)] {
                    if tile.value == 4 {
                        found4s = true
                    }
                }
            }
        }

        #expect(!found4s, "All 4s should be eliminated after creating 4096")
        #expect(state.highestTile == 4096)
    }

    @Test("8192 milestone does not eliminate anything (skip)")
    func test8192SkipsElimination() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 12345)
        let engine = GameEngine(config: config)

        // Setup board with low values
        engine._setAllTilesForTesting(value: nil)
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 2)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 4)
        engine._setTileForTesting(at: Position(row: 0, col: 2), value: 8)
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 4096)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 4096)

        // Create 8192 by merging
        let chain = [Position(row: 1, col: 0), Position(row: 1, col: 1)]
        let state = engine.commitChain(chain)

        // Check that low values still exist (8192 is a skip milestone)
        var found2 = false, found4 = false, found8 = false
        for row in 0..<3 {
            for col in 0..<3 {
                if let tile = state.board[Position(row: row, col: col)] {
                    if tile.value == 2 { found2 = true }
                    if tile.value == 4 { found4 = true }
                    if tile.value == 8 { found8 = true }
                }
            }
        }

        #expect(found2 || found4 || found8, "Low value tiles should still exist after 8192 (skip milestone)")
        #expect(state.highestTile == 8192)
    }

    @Test("16K milestone eliminates all 8s")
    func test16KEliminatesEights() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 12345)
        let engine = GameEngine(config: config)

        // Setup board with some 8s
        engine._setAllTilesForTesting(value: nil)
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 8)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 8)
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 8192)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 8192)

        // Create 16384 by merging
        let chain = [Position(row: 1, col: 0), Position(row: 1, col: 1)]
        let state = engine.commitChain(chain)

        // Check no 8s remain
        var found8s = false
        for row in 0..<3 {
            for col in 0..<3 {
                if let tile = state.board[Position(row: row, col: col)] {
                    if tile.value == 8 {
                        found8s = true
                    }
                }
            }
        }

        #expect(!found8s, "All 8s should be eliminated after creating 16K")
        #expect(state.highestTile == 16384)
    }

    @Test("32K milestone eliminates all 16s")
    func test32KEliminatesSixteens() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 12345)
        let engine = GameEngine(config: config)

        // Setup board with some 16s
        engine._setAllTilesForTesting(value: nil)
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 16)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 16)
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 16384)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 16384)

        // Create 32768 by merging
        let chain = [Position(row: 1, col: 0), Position(row: 1, col: 1)]
        let state = engine.commitChain(chain)

        // Check no 16s remain
        var found16s = false
        for row in 0..<3 {
            for col in 0..<3 {
                if let tile = state.board[Position(row: row, col: col)] {
                    if tile.value == 16 {
                        found16s = true
                    }
                }
            }
        }

        #expect(!found16s, "All 16s should be eliminated after creating 32K")
        #expect(state.highestTile == 32768)
    }

    @Test("65K milestone eliminates all 32s")
    func test65KEliminatesThirtyTwos() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 12345)
        let engine = GameEngine(config: config)

        // Setup board with some 32s
        engine._setAllTilesForTesting(value: nil)
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 32)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 32)
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 32768)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 32768)

        // Create 65536 by merging
        let chain = [Position(row: 1, col: 0), Position(row: 1, col: 1)]
        let state = engine.commitChain(chain)

        // Check no 32s remain
        var found32s = false
        for row in 0..<3 {
            for col in 0..<3 {
                if let tile = state.board[Position(row: row, col: col)] {
                    if tile.value == 32 {
                        found32s = true
                    }
                }
            }
        }

        #expect(!found32s, "All 32s should be eliminated after creating 65K")
        #expect(state.highestTile == 65536)
    }

    @Test("131K milestone does not eliminate anything (skip)")
    func test131KSkipsElimination() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 12345)
        let engine = GameEngine(config: config)

        // Setup board with various values
        engine._setAllTilesForTesting(value: nil)
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 32)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 64)
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 65536)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 65536)

        // Create 131072 by merging
        let chain = [Position(row: 1, col: 0), Position(row: 1, col: 1)]
        let state = engine.commitChain(chain)

        // Check that values still exist (131K is a skip milestone)
        var found32 = false, found64 = false
        for row in 0..<3 {
            for col in 0..<3 {
                if let tile = state.board[Position(row: row, col: col)] {
                    if tile.value == 32 { found32 = true }
                    if tile.value == 64 { found64 = true }
                }
            }
        }

        #expect(found32 || found64, "Values should still exist after 131K (skip milestone)")
        #expect(state.highestTile == 131072)
    }

    @Test("Multiple eliminations accumulate correctly")
    func testMultipleEliminations() {
        let config = GameConfig(boardWidth: 4, boardHeight: 4, seed: 99999)
        let engine = GameEngine(config: config)

        // Clear and setup - we'll create 4K then 16K to accumulate eliminations
        engine._setAllTilesForTesting(value: nil)

        // First create 4096 to eliminate 4s
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 2048)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 2048)
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 4)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 4)

        var state = engine.commitChain([Position(row: 0, col: 0), Position(row: 0, col: 1)])
        #expect(state.highestTile == 4096, "Should have created 4096")

        // Now add 8s and create 16K to eliminate them
        engine._setTileForTesting(at: Position(row: 2, col: 0), value: 8192)
        engine._setTileForTesting(at: Position(row: 2, col: 1), value: 8192)
        engine._setTileForTesting(at: Position(row: 2, col: 2), value: 8)
        engine._setTileForTesting(at: Position(row: 2, col: 3), value: 8)

        state = engine.commitChain([Position(row: 2, col: 0), Position(row: 2, col: 1)])
        #expect(state.highestTile == 16384, "Should have created 16384")

        // Check that neither 4s nor 8s exist on the board
        var found4s = false, found8s = false
        for row in 0..<4 {
            for col in 0..<4 {
                if let tile = state.board[Position(row: row, col: col)] {
                    if tile.value == 4 { found4s = true }
                    if tile.value == 8 { found8s = true }
                }
            }
        }

        #expect(!found4s, "No 4s should exist (eliminated by 4096)")
        #expect(!found8s, "No 8s should exist (eliminated by 16384)")
    }
}
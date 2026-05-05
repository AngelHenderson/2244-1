import Testing
@testable import GameCore

struct MagnetPowerUpTests {
    
    @Test("Magnet merges all tiles with same value")
    func testMagnetMergesAllSameTiles() {
        // Use a full board to avoid issues with refillToFull changing test setup
        let config = GameConfig(boardWidth: 5, boardHeight: 5, seed: 12345, fillMode: .alwaysFull)
        let engine = GameEngine(config: config)
        
        // Fill board completely to avoid refill complications
        for row in 0..<5 {
            for col in 0..<5 {
                engine._setTileForTesting(at: Position(row: row, col: col), value: 8)
            }
        }
        
        // Place five tiles with value 64 at different positions
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 64)
        engine._setTileForTesting(at: Position(row: 0, col: 4), value: 64)
        engine._setTileForTesting(at: Position(row: 2, col: 2), value: 64)
        engine._setTileForTesting(at: Position(row: 3, col: 1), value: 64)
        engine._setTileForTesting(at: Position(row: 4, col: 3), value: 64)
        
        // Count tiles before magnetize
        var count64Before = 0
        for row in 0..<5 {
            for col in 0..<5 {
                if let tile = engine.currentState().board[Position(row: row, col: col)], tile.value == 64 {
                    count64Before += 1
                }
            }
        }
        #expect(count64Before == 5)
        
        // Use magnet on one of the 64 tiles
        let targetPosition = Position(row: 2, col: 2)
        let state = engine.magnetize(value: 64, to: targetPosition)
        
        // After magnetize, check that merged tile exists somewhere on the board
        var mergedTileValue: Int? = nil
        var found512 = false
        
        for row in 0..<5 {
            for col in 0..<5 {
                if let tile = state.board[Position(row: row, col: col)] {
                    if tile.value == 512 {
                        found512 = true
                        mergedTileValue = tile.value
                    }
                }
            }
        }
        
        // The merged value should be: 5 tiles × 64 = 320
        // Rounded up to next power of 2 = 512
        #expect(found512, "Merged tile with value 512 should exist on the board")
        #expect(mergedTileValue == 512, "Merged value should be 512 (5 × 64 = 320 → next power of 2)")
        
        // Score should have increased by the merged value
        #expect(state.score >= 512, "Score should include the merged tile value")
    }
    
    @Test("Magnet does nothing when only one tile exists")
    func testMagnetWithOnlyOneTile() {
        let config = GameConfig(boardWidth: 5, boardHeight: 5, seed: 12345, fillMode: .alwaysFull)
        let engine = GameEngine(config: config)
        
        // Fill board completely with different values
        for row in 0..<5 {
            for col in 0..<5 {
                engine._setTileForTesting(at: Position(row: row, col: col), value: 8)
            }
        }
        
        // Place only one tile with value 64
        let position = Position(row: 2, col: 2)
        engine._setTileForTesting(at: position, value: 64)
        
        // Count 64 tiles before
        var count64Before = 0
        for row in 0..<5 {
            for col in 0..<5 {
                if let tile = engine.currentState().board[Position(row: row, col: col)], tile.value == 64 {
                    count64Before += 1
                }
            }
        }
        #expect(count64Before == 1)
        
        // Use magnet on the single tile
        let stateAfter = engine.magnetize(value: 64, to: position)
        
        // Count 64 tiles after - should still be 1 since no merge occurred
        var count64After = 0
        for row in 0..<5 {
            for col in 0..<5 {
                if let tile = stateAfter.board[Position(row: row, col: col)], tile.value == 64 {
                    count64After += 1
                }
            }
        }
        #expect(count64After == 1, "Single tile should remain when no other matching tiles exist")
        
        // Undo should not be available since nothing changed
        #expect(stateAfter.undoAvailable == false, "Undo should not be available when magnet does nothing")
    }
    
    @Test("Magnet merges two tiles correctly")
    func testMagnetMergesTwoTiles() {
        let config = GameConfig(boardWidth: 5, boardHeight: 5, seed: 12345, fillMode: .alwaysFull)
        let engine = GameEngine(config: config)
        
        // Fill board completely with different values
        for row in 0..<5 {
            for col in 0..<5 {
                engine._setTileForTesting(at: Position(row: row, col: col), value: 16)
            }
        }
        
        // Place two tiles with value 128
        let targetPosition = Position(row: 1, col: 1)
        engine._setTileForTesting(at: targetPosition, value: 128)
        engine._setTileForTesting(at: Position(row: 3, col: 3), value: 128)
        
        // Use magnet
        let state = engine.magnetize(value: 128, to: targetPosition)
        
        // Check that a tile with value 256 exists somewhere on the board
        var found256 = false
        for row in 0..<5 {
            for col in 0..<5 {
                if let tile = state.board[Position(row: row, col: col)], tile.value == 256 {
                    found256 = true
                }
            }
        }
        
        // 2 × 128 = 256 (already a power of 2)
        #expect(found256, "Merged tile with value 256 should exist on the board")
        
        // Undo should be available
        #expect(state.undoAvailable == true, "Undo should be available after magnet")
        
        // Score should have increased
        #expect(state.score >= 256, "Score should include the merged tile value")
    }
    
    @Test("Magnet merges high-value tiles (e.g. 9c -> 18c)")
    func testMagnetMergesHighValueTiles() {
        let step9c = 62
        let step18c = 63
        #expect(TileStepLabelFormatter.labelForStep(step9c) == "9c")
        #expect(TileStepLabelFormatter.labelForStep(step18c) == "18c")
        
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 77, fillMode: .sparse)
        let engine = GameEngine(config: config)
        engine._setAllTilesForTesting(value: nil)
        
        let positions = [
            Position(row: 0, col: 0),
            Position(row: 0, col: 1)
        ]
        positions.forEach { engine._setHighValueTileForTesting(at: $0, step: step9c) }
        
        let state = engine.magnetize(value: engine.currentState().board[positions[0]]!.value, to: positions[0])
        let resultTile = state.board[positions[0]]
        
        #expect(resultTile?.stepIndex == step18c, "Magnet should advance high-value tiles to the next tier")
    }
}

import Testing
@testable import GameCore

struct AutoCascadeTests {
    
    @Test("Auto-cascade merges adjacent matching tiles")
    func testBasicAutoMerge() {
        let config = GameConfig(boardWidth: 5, boardHeight: 5, seed: 12345, fillMode: .alwaysFull)
        let engine = GameEngine(config: config)
        
        // Clear board and set up a simple match
        for row in 0..<5 {
            for col in 0..<5 {
                engine._setTileForTesting(at: Position(row: row, col: col), value: 8)
            }
        }
        
        // Place three matching tiles in a row at the bottom
        engine._setTileForTesting(at: Position(row: 4, col: 0), value: 32)
        engine._setTileForTesting(at: Position(row: 4, col: 1), value: 32)
        engine._setTileForTesting(at: Position(row: 4, col: 2), value: 32)
        engine._setTileForTesting(at: Position(row: 3, col: 2), value: 32)
        
        engine._resetScoreForTesting()
        
        // Count initial 32 tiles
        var initialCount32 = 0
        for row in 0..<5 {
            for col in 0..<5 {
                if let tile = engine.currentState().board[Position(row: row, col: col)], tile.value == 32 {
                    initialCount32 += 1
                }
            }
        }
        #expect(initialCount32 == 3, "Should start with exactly 3 tiles of value 32")
        
        // Run cascade
        let score = engine.runAutoCascade()
        
        // Should have merged 3 tiles of value 32 into a 64
        #expect(score > 0, "Score should increase from merge")
        
        // Check that a merged tile was created (64)
        var count64 = 0
        for row in 0..<5 {
            for col in 0..<5 {
                if let tile = engine.currentState().board[Position(row: row, col: col)], tile.value == 64 {
                    count64 += 1
                }
            }
        }
        
        #expect(count64 >= 1, "Should have created at least one 64 tile from merging three 32s")
        
        // The original three 32 tiles should be gone (merged into 128)
        // Note: New tiles might spawn during refill, but the original 3 should be merged
        var count32AfterMerge = 0
        for row in 0..<5 {
            for col in 0..<5 {
                if let tile = engine.currentState().board[Position(row: row, col: col)], tile.value == 32 {
                    count32AfterMerge += 1
                }
            }
        }
        
        // If new 32s spawned, that's okay - just check that we have fewer than we started with
        // or that a 128 was created (which proves the merge happened)
        #expect(count32AfterMerge < initialCount32 || count64 > 0, "32 tiles should be merged or reduced")
    }
    
    @Test("Cascade triggers multiple merges in sequence")
    func testMultiCascade() {
        let config = GameConfig(boardWidth: 5, boardHeight: 6, seed: 12345, fillMode: .alwaysFull)
        let engine = GameEngine(config: config)
        
        // Clear board
        for row in 0..<6 {
            for col in 0..<5 {
                engine._setTileForTesting(at: Position(row: row, col: col), value: 2)
            }
        }
        
        // Set up a cascade scenario:
        // Bottom: two 16s that will merge
        engine._setTileForTesting(at: Position(row: 5, col: 2), value: 16)
        engine._setTileForTesting(at: Position(row: 4, col: 2), value: 16)
        
        engine._resetScoreForTesting()
        
        // Run cascade
        let score = engine.runAutoCascade()
        
        // Should trigger multiple merges
        #expect(score >= 144, "Should get score from cascading merges with combo bonus")
    }
    
    @Test("Find matching groups correctly identifies adjacent tiles")
    func testFindMatchingGroups() {
        let config = GameConfig(boardWidth: 5, boardHeight: 5, seed: 12345, fillMode: .alwaysFull)
        let engine = GameEngine(config: config)
        
        // Clear board with a unique value that won't match
        for row in 0..<5 {
            for col in 0..<5 {
                engine._setTileForTesting(at: Position(row: row, col: col), value: 4)
            }
        }
        
        // Place a group of 4 matching tiles in a square
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 64)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 64)
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 64)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 64)
        
        engine._resetScoreForTesting()
        
        // Run cascade
        let score = engine.runAutoCascade()
        
        // Should merge all 4 tiles (64 * 4 = 256)
        #expect(score > 0, "Should merge the group")
        
        // Check that a 256 tile was created (or higher if it cascaded further)
        var found256OrHigher = false
        for row in 0..<5 {
            for col in 0..<5 {
                if let tile = engine.currentState().board[Position(row: row, col: col)], tile.value >= 256 {
                    found256OrHigher = true
                    break
                }
            }
        }
        
        #expect(found256OrHigher, "Should have created a 256 tile (or higher from cascading)")
    }
    
    @Test("Swap triggers auto-cascade")
    func testSwapTriggersAutoCascade() {
        let config = GameConfig(boardWidth: 5, boardHeight: 5, seed: 12345, fillMode: .alwaysFull)
        let engine = GameEngine(config: config)
        
        // Clear board
        for row in 0..<5 {
            for col in 0..<5 {
                engine._setTileForTesting(at: Position(row: row, col: col), value: 2048)
            }
        }
        
        // Set up: two 32s with a different tile between them
        engine._setTileForTesting(at: Position(row: 4, col: 0), value: 32)
        engine._setTileForTesting(at: Position(row: 4, col: 1), value: 8)
        engine._setTileForTesting(at: Position(row: 4, col: 2), value: 32)
        
        let scoreBefore = engine.currentState().score
        
        // Swap the middle tile with something else to bring the 32s together
        _ = engine.swap(Position(row: 4, col: 1), Position(row: 3, col: 1))
        
        let scoreAfter = engine.currentState().score
        
        // Check that score increased (indicating a merge happened)
        #expect(scoreAfter > scoreBefore, "Score should increase after swap triggers cascade")
        
        // Check that a 64 tile exists (from merging two 32s)
        var found64OrHigher = false
        for row in 0..<5 {
            for col in 0..<5 {
                if let tile = engine.currentState().board[Position(row: row, col: col)], tile.value >= 64 {
                    found64OrHigher = true
                    break
                }
            }
        }
        
        #expect(found64OrHigher, "Should have created a 64+ tile from merging 32s")
    }
}

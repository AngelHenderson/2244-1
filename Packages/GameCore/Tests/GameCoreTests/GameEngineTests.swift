import Testing
import Foundation
@testable import GameCore

private func valueGrid(from board: GameCore.Board) -> [[Int?]] {
    (0..<board.height).map { row in
        (0..<board.width).map { col in
            board[GameCore.Position(row: row, col: col)]?.value
        }
    }
}

struct GameEngineTests {
    @Test
    func testInitialBoardFilled() {
        let engine = GameEngine()
        let state = engine.currentState()
        
        for row in 0..<state.board.height {
            for col in 0..<state.board.width {
                let position = Position(row: row, col: col)
                #expect(state.board[position] != nil)
            }
        }
    }
    
    @Test
    func testValidChainValidation() {
        let engine = GameEngine()
        
        // Test 1: Basic chain with identical values
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 2)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 2)
        engine._setTileForTesting(at: Position(row: 0, col: 2), value: 2)
        let chain1 = [Position(row: 0, col: 0), Position(row: 0, col: 1), Position(row: 0, col: 2)]
        #expect(engine.validateChain(chain1).isValid)
        
        // Test 2: Chain with doubling progression (2-2-4-8)
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 2)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 2)
        engine._setTileForTesting(at: Position(row: 1, col: 2), value: 4)
        engine._setTileForTesting(at: Position(row: 1, col: 3), value: 8)
        let chain2 = [
            Position(row: 1, col: 0),
            Position(row: 1, col: 1),
            Position(row: 1, col: 2),
            Position(row: 1, col: 3)
        ]
        #expect(engine.validateChain(chain2).isValid)
        
        // Test 3: Diagonal connections are allowed
        engine._setTileForTesting(at: Position(row: 2, col: 0), value: 4)
        engine._setTileForTesting(at: Position(row: 3, col: 1), value: 4)
        let chain3 = [Position(row: 2, col: 0), Position(row: 3, col: 1)]
        #expect(engine.validateChain(chain3).isValid)
        
        // Test 4: Invalid - first two tiles different
        engine._setTileForTesting(at: Position(row: 4, col: 0), value: 2)
        engine._setTileForTesting(at: Position(row: 4, col: 1), value: 4)
        let chain4 = [Position(row: 4, col: 0), Position(row: 4, col: 1)]
        #expect(!engine.validateChain(chain4).isValid)
        
        // Test 5: Invalid - value doesn't follow progression
        engine._setTileForTesting(at: Position(row: 5, col: 0), value: 2)
        engine._setTileForTesting(at: Position(row: 5, col: 1), value: 2)
        engine._setTileForTesting(at: Position(row: 5, col: 2), value: 8) // Should be 2 or 4
        let chain5 = [
            Position(row: 5, col: 0),
            Position(row: 5, col: 1),
            Position(row: 5, col: 2)
        ]
        #expect(!engine.validateChain(chain5).isValid)
    }
    
    @Test
    func testDeterministicRNG() {
        let seed: UInt64 = 12345
        var rng1 = DeterministicRNG(seed: seed)
        var rng2 = DeterministicRNG(seed: seed)
        
        for _ in 0..<100 {
            #expect(rng1.next() == rng2.next())
        }
    }
    
    @Test
    func testScoring_ChainAndCombo() {
        let engine = GameEngine(config: GameConfig(seed: 42))
        // Clear a small 2x2 corner to control spawns
        let p00 = Position(row: 0, col: 0)
        let p01 = Position(row: 0, col: 1)
        let p10 = Position(row: 1, col: 0)
        // Force identical tiles (4) in a chain of length 2 horizontally
        engine._setTileForTesting(at: p00, value: 4)
        engine._setTileForTesting(at: p01, value: 4)
        engine._setTileForTesting(at: p10, value: 8) // blocker below
        engine._resetScoreForTesting()
        engine._setLastMergeAtMsForTesting(nil)
        var state = engine.commitChain([p00, p01])
        // Tiered doubling: [4,4] -> base 4 doubled once (levels=1) => 8
        // With auto-cascade enabled, score will be >= 8 (may include cascade bonuses)
        #expect(state.score >= 8, "Score should be at least 8 from the base chain")
        let scoreAfterFirst = state.score
        
        // Prepare a second quick chain to trigger combo increase
        let p20 = Position(row: 2, col: 0)
        let p21 = Position(row: 2, col: 1)
        engine._setTileForTesting(at: p20, value: 4)
        engine._setTileForTesting(at: p21, value: 4)
        // Simulate quick follow-up within combo window
        let now = Int(Date().timeIntervalSince1970 * 1000)
        engine._setLastMergeAtMsForTesting(now)
        state = engine.commitChain([p20, p21])
        #expect(state.score > scoreAfterFirst) // increased by at least base with multiplier >= 1.5
        
        // Test longer chain with progression
        engine._setTileForTesting(at: Position(row: 3, col: 0), value: 2)
        engine._setTileForTesting(at: Position(row: 3, col: 1), value: 2)
        engine._setTileForTesting(at: Position(row: 3, col: 2), value: 4)
        engine._setTileForTesting(at: Position(row: 3, col: 3), value: 8)
        let longChain = [
            Position(row: 3, col: 0),
            Position(row: 3, col: 1),
            Position(row: 3, col: 2),
            Position(row: 3, col: 3)
        ]
        engine._resetScoreForTesting()
        engine._setLastMergeAtMsForTesting(nil) // Reset combo multiplier
        state = engine.commitChain(longChain)
        // Sum 2+2+4+8 = 16; rounded to next power-of-two => 16
        // With auto-cascade enabled, score will be >= 16 (may include cascade bonuses)
        #expect(state.score >= 16, "Score should be at least 16 from the base chain")
    }

    @Test
    func testChainMergeScalesWithLength() {
        let config = GameConfig(boardWidth: 1, boardHeight: 5, seed: 99, fillMode: .sparse)
        let engine = GameEngine(config: config)
        engine._setAllTilesForTesting(value: nil)
        
        // Fill a column with identical values to simulate a long chain.
        let basePositions = (0..<5).map { Position(row: $0, col: 0) }
        basePositions.forEach { engine._setTileForTesting(at: $0, value: 64) }
        
        engine._resetScoreForTesting()
        let state = engine.commitChain(basePositions)
        
        // Expected value: 5 * 64 rounded up to the next power of two = 512
        let expectedValue = 512
        #expect(state.board[basePositions.last!]?.value == expectedValue, "Long chain should keep doubling")
        #expect(state.score >= expectedValue, "Score should reflect the resulting tile")
    }
    
    @Test
    func testHighValueChainsAdvanceBeyond9c() {
        let step9c = 62
        let step18c = 63
        #expect(TileStepLabelFormatter.labelForStep(step9c) == "9c")
        #expect(TileStepLabelFormatter.labelForStep(step18c) == "18c")
        
        let config = GameConfig(boardWidth: 1, boardHeight: 2, seed: 7, fillMode: .sparse)
        let engine = GameEngine(config: config)
        engine._setAllTilesForTesting(value: nil)
        
        let positions = (0..<2).map { Position(row: $0, col: 0) }
        positions.forEach { engine._setHighValueTileForTesting(at: $0, step: step9c) }
        
        let state = engine.commitChain(positions)
        let resultingTile = state.board[positions.last!]
        
        #expect(resultingTile?.stepIndex == step18c, "Merging 9c tiles should produce an 18c tile")
    }
    
    @Test
    func testScoreValueTracksBeyondIntRange() {
        let config = GameConfig(boardWidth: 2, boardHeight: 2, seed: 11, fillMode: .sparse)
        let engine = GameEngine(config: config)
        engine._setAllTilesForTesting(value: nil)
        
        let posA = Position(row: 0, col: 0)
        let posB = Position(row: 0, col: 1)
        let highStep = 80
        engine._setHighValueTileForTesting(at: posA, step: highStep)
        engine._setHighValueTileForTesting(at: posB, step: highStep)
        
        engine._resetScoreForTesting()
        let state = engine.commitChain([posA, posB])
        
        let expectedStep = TileStepMath.mergedStep(from: [highStep, highStep])
        let expectedScore = AlphaNumber.powerOfTwo(step: expectedStep)
        #expect(state.scoreValue == expectedScore, "ScoreValue should capture large merges without overflowing Int")
        #expect(state.score == Int.max, "Legacy Int score should clamp for extremely large merges")
    }
    
    @Test
    func testCommitChainCanSkipGravityForAnimationPipeline() {
        let config = GameConfig(boardWidth: 3, boardHeight: 4, seed: 5, fillMode: .alwaysFull)
        let engine = GameEngine(config: config)
        engine._setAllTilesForTesting(value: nil)
        
        let dropColumnPositions = [
            Position(row: 3, col: 0),
            Position(row: 2, col: 0),
            Position(row: 1, col: 0)
        ]
        
        // Chain tiles on the bottom row plus a supporting column above them
        engine._setTileForTesting(at: dropColumnPositions[0], value: 2)
        engine._setTileForTesting(at: Position(row: 3, col: 1), value: 2)
        engine._setTileForTesting(at: dropColumnPositions[1], value: 16)
        engine._setTileForTesting(at: dropColumnPositions[2], value: 32)
        
        let chain = [dropColumnPositions[0], Position(row: 3, col: 1)]
        let stateWithoutGravity = engine.commitChain(chain, applyGravity: false)
        
        // Chain source position should now be empty while supporting tiles stay suspended
        #expect(stateWithoutGravity.board[dropColumnPositions[0]] == nil, "Source tile should remain empty before gravity resolves")
        #expect(stateWithoutGravity.board[dropColumnPositions[1]]?.value == 16, "Supporting tiles should not fall until gravity phase")
        #expect(stateWithoutGravity.board[Position(row: 3, col: 1)]?.value == 4, "Merged tile should land at the target")
        
        let postGravityState = engine.applyGravityAfterChain()
        #expect(postGravityState.board[dropColumnPositions[0]]?.value == 16, "Gravity phase should move the column down into empty space")
    }
    
    @Test
    func testDeferredGravityMatchesImmediateCommit() {
        let config = GameConfig(boardWidth: 3, boardHeight: 4, seed: 9, fillMode: .alwaysFull)
        let immediateEngine = GameEngine(config: config)
        let deferredEngine = GameEngine(config: config)
        
        [immediateEngine, deferredEngine].forEach { engine in
            engine._setAllTilesForTesting(value: nil)
            engine._resetScoreForTesting()
        }
        
        let tiles: [(Position, Int)] = [
            (Position(row: 3, col: 0), 2),
            (Position(row: 3, col: 1), 2),
            (Position(row: 2, col: 0), 8),
            (Position(row: 1, col: 1), 16)
        ]
        tiles.forEach { pos, value in
            immediateEngine._setTileForTesting(at: pos, value: value)
            deferredEngine._setTileForTesting(at: pos, value: value)
        }
        
        let chain = [Position(row: 3, col: 0), Position(row: 3, col: 1)]
        let immediateState = immediateEngine.commitChain(chain)
        
        _ = deferredEngine.commitChain(chain, applyGravity: false)
        let deferredState = deferredEngine.applyGravityAfterChain()
        
        #expect(
            valueGrid(from: immediateState.board) == valueGrid(from: deferredState.board),
            "Deferred gravity should match the immediate commit result"
        )
        #expect(immediateState.score == deferredState.score, "Score calculations should stay consistent")
    }
    
    @Test
    func testSwapDropRefillKeepsBoardStable() {
        let config = GameConfig(boardWidth: 4, boardHeight: 4, seed: 7, fillMode: .alwaysFull)
        let engine = GameEngine(config: config)
        
        // Fill board with a known value to remove randomness
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                engine._setTileForTesting(at: Position(row: row, col: col), value: 8)
            }
        }
        
        // Arrange tiles so that a swap could previously trigger a cascade
        let topLeft = Position(row: 0, col: 0)
        let topMid = Position(row: 0, col: 1)
        let topRight = Position(row: 0, col: 2)
        let midMid = Position(row: 1, col: 1)
        
        engine._setTileForTesting(at: topLeft, value: 4)
        engine._setTileForTesting(at: topMid, value: 2)
        engine._setTileForTesting(at: topRight, value: 4)
        engine._setTileForTesting(at: midMid, value: 4)
        engine._resetScoreForTesting()
        
        let state = engine.swap(topMid, midMid)
        
        // Swap should not award score (no cascade)
        #expect(state.score == 0, "Swap should not trigger auto-cascade scoring")
        
        // Tiles should remain present (board stays full)
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let pos = Position(row: row, col: col)
                #expect(state.board[pos] != nil, "Board should stay full after swap-drop-refill")
            }
        }
        
        // Verify swapped values landed in expected positions without merging
        #expect(state.board[topLeft]?.value == 4)
        #expect(state.board[topMid]?.value == 4)
        #expect(state.board[topRight]?.value == 4)
        #expect(state.board[midMid]?.value == 2)
    }

    @Test
    func testTieredDoubling_LongChains() {
        let engine = GameEngine()

        func snakePath(length: Int, width: Int = 5, height: Int = 8) -> [Position] {
            var result: [Position] = []
            for row in 0..<height {
                if result.count >= length { break }
                if row % 2 == 0 {
                    for col in 0..<width {
                        if result.count >= length { break }
                        result.append(Position(row: row, col: col))
                    }
                } else {
                    for col in (0..<width).reversed() {
                        if result.count >= length { break }
                        result.append(Position(row: row, col: col))
                    }
                }
            }
            return Array(result.prefix(length))
        }

        // 17 twos -> 64
        let path17 = snakePath(length: 17)
        for p in path17 { engine._setTileForTesting(at: p, value: 2) }
        engine._resetScoreForTesting()
        engine._setLastMergeAtMsForTesting(nil)
        var state = engine.commitChain(path17)
        // With auto-cascade enabled, score will be >= 64 (may include cascade bonuses)
        #expect(state.score >= 64, "Score should be at least 64 from the base chain")

        // 33 twos -> 128
        let path33 = snakePath(length: 33)
        for p in path33 { engine._setTileForTesting(at: p, value: 2) }
        engine._resetScoreForTesting()
        engine._setLastMergeAtMsForTesting(nil)
        state = engine.commitChain(path33)
        // With auto-cascade enabled, score will be >= 128 (may include cascade bonuses)
        #expect(state.score >= 128, "Score should be at least 128 from the base chain")
    }
    
    @Test
    func testGiftMergeTerminal() {
        let engine = GameEngine(config: GameConfig(seed: 123))
        
        // Set up a simple chain that can end on a gift
        let p00 = Position(row: 0, col: 2)  // First tile: 4
        let p01 = Position(row: 0, col: 1)  // Second tile: 4
        let p02 = Position(row: 0, col: 0)  // Gift position with gem rewards
        
        // Clear and set up tiles
        engine._setTileForTesting(at: p00, value: 4)
        engine._setTileForTesting(at: p01, value: 4)
        engine._setTileForTesting(at: p02, value: nil) // Clear position for gift
        
        // Place a gift at the terminal position
        _ = engine.placeGift(at: p02, targetValue: 8)
        
        // Create chain from tiles to gift
        let chain = [p00, p01, p02]
        
        // Validate that the gift chain is valid
        let validation = engine.validateGiftChain(chain)
        #expect(validation.isValid, "Gift chain should be valid")
        
        // Test the gift merge
        engine._resetScoreForTesting()
        let initialState = engine.currentState()
        let giftPositions = engine.giftPositions()
        #expect(giftPositions.contains(p02), "Gift should be placed at p02")
        
        // Commit the gift chain and resolve drop/refill phases manually
        let mergedState = engine.commitGiftChain(chain)
        let mergedTile = mergedState.board[p02]
        let giftPositionsAfterMerge = engine.giftPositions()
        _ = engine.applyGravityAfterChain()
        let resultState = engine.refillBoard()

        // Verify the merge occurred correctly
        #expect(mergedState.score > 0, "Score should increase after gift merge")
        #expect(mergedTile != nil, "Result tile should be placed at gift position before gravity")
        #expect(resultState.gems > initialState.gems, "Gems should increase from gift break")
        
        // Verify the result tile has at least the expected value (2 * max value in chain)
        // With auto-cascade enabled, the value may be higher due to subsequent merges
        guard let resultTile = mergedTile else {
            Issue.record("Gift merge should leave a result tile before gravity resolves")
            return
        }
        #expect(resultTile.value >= 8, "Result should be at least 2 * max(4, 4) = 8")
        
        #expect(!giftPositionsAfterMerge.contains(p02), "Gift should be consumed after merge")
    }
    
    @Test
    func testGiftValidation() {
        let engine = GameEngine()
        
        // Test that you cannot start a chain on a gift
        let giftPos = Position(row: 0, col: 0)
        _ = engine.placeGift(at: giftPos, targetValue: 4)
        
        let invalidChain = [giftPos, Position(row: 0, col: 1)]
        let validation = engine.validateGiftChain(invalidChain)
        #expect(!validation.isValid, "Should not be able to start chain on gift")
        
        // Test that gift must be adjacent to previous tile
        engine._setTileForTesting(at: Position(row: 1, col: 0), value: 2)
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 2)
        let giftPos2 = Position(row: 0, col: 3) // Not adjacent to (1,1)
        _ = engine.placeGift(at: giftPos2, targetValue: 4)
        
        let nonAdjacentChain = [Position(row: 1, col: 0), Position(row: 1, col: 1), giftPos2]
        let validation2 = engine.validateGiftChain(nonAdjacentChain)
        #expect(!validation2.isValid, "Gift must be adjacent to previous tile")
    }
    
    @Test("Gravity with gift merge consumes gift and refills")
    func testGravityWithGiftMerge() {
        let engine = GameEngine(config: GameConfig(seed: 456))
        
        // Set up a column with tiles and a gift at top
        let col = 2
        let giftPos = Position(row: 0, col: col)   // Gift at top
        let tile1Pos = Position(row: 1, col: col)  // Tile below gift
        let tile2Pos = Position(row: 2, col: col)  // Another tile
        let tile3Pos = Position(row: 3, col: col)  // Bottom tile
        
        // Clear column and set up test scenario
        for row in 0..<8 {
            let value: Int? = nil
            engine._setTileForTesting(at: Position(row: row, col: col), value: value)
        }
        
        // Place gift at top
        _ = engine.placeGift(at: giftPos, targetValue: 8)
        
        // Place tiles below
        engine._setTileForTesting(at: tile1Pos, value: 4)
        engine._setTileForTesting(at: tile2Pos, value: 4)
        engine._setTileForTesting(at: tile3Pos, value: 8)
        
        // Create chain that ends on gift
        let chain = [tile1Pos, tile2Pos, giftPos]
        
        // Verify initial state
        #expect(engine.giftPositions().contains(giftPos), "Gift should be at top")
        #expect(engine.currentState().board[tile3Pos]?.value == 8, "Bottom tile should be 8")
        
        // Commit the chain and process drop/refill
        _ = engine.commitGiftChain(chain)
        _ = engine.applyGravityAfterChain()
        let resultState = engine.refillBoard()
        
        // After merge and gravity:
        // 1. Gift should be consumed and replaced with result tile
        // 2. Bottom tile (8) should fall down
        // 3. New tiles should fill empty spaces from top
        // 4. A new gift should appear at the top
        
        // Check that tiles have fallen due to gravity
        #expect(resultState.board[Position(row: 7, col: col)] != nil, "Bottom position should have a tile after gravity")
        
        // Check that new gift spawned at top after the merge
        let newGiftPositions = engine.giftPositions()
        #expect(newGiftPositions.contains(giftPos), "New gift should spawn at top after breaking previous gift")
    }
    
    @Test 
    func testMultiColumnGravity() {
        let engine = GameEngine(config: GameConfig(boardWidth: 3, boardHeight: 4, seed: 789))
        
        // Clear board
        for row in 0..<4 {
            for col in 0..<3 {
                let value: Int? = nil
                engine._setTileForTesting(at: Position(row: row, col: col), value: value)
            }
        }
        
        // Set up scattered tiles
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 2)  // Top left
        engine._setTileForTesting(at: Position(row: 2, col: 0), value: 4)  // Middle left
        engine._setTileForTesting(at: Position(row: 1, col: 1), value: 8)  // Middle center
        engine._setTileForTesting(at: Position(row: 3, col: 2), value: 16) // Bottom right
        
        // Apply gravity directly to the board
        var board = engine.currentState().board
        board.applyGravity()
        
        // After gravity, tiles should fall to bottom of their columns
        #expect(board[BoardIndex(row: 3, col: 0)].tile?.value == 4, "4 should fall to bottom of column 0")
        #expect(board[BoardIndex(row: 2, col: 0)].tile?.value == 2, "2 should be above 4 in column 0") 
        #expect(board[BoardIndex(row: 3, col: 1)].tile?.value == 8, "8 should fall to bottom of column 1")
        #expect(board[BoardIndex(row: 3, col: 2)].tile?.value == 16, "16 should stay at bottom of column 2")
        
        // Top positions should be empty after gravity
        #expect(board[BoardIndex(row: 0, col: 0)].kind == CellKind.empty, "Top of column 0 should be empty")
        #expect(board[BoardIndex(row: 0, col: 1)].kind == CellKind.empty, "Top of column 1 should be empty")
    }
    
    @Test("Milestone elimination removes too-low tiles and raises spawn floor")
    func testMilestoneEliminationRemovesTiles() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 99, fillMode: .alwaysFull)
        let engine = GameEngine(config: config)
        
        // Clear the board for deterministic setup
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                engine._setTileForTesting(at: Position(row: row, col: col), value: nil)
            }
        }
        
        let removedValue = 262_144
        let milestoneValue = removedValue << 14 // 4B milestone
        let targetPositions = [
            Position(row: 0, col: 0),
            Position(row: 1, col: 1),
            Position(row: 2, col: 2)
        ]
        targetPositions.forEach { engine._setTileForTesting(at: $0, value: removedValue) }
        
        engine._applyMilestoneEliminationForTesting(createdValue: milestoneValue)
        
        let state = engine.currentState()
        for pos in targetPositions {
            #expect(state.board[pos]?.value != removedValue, "Tile \(removedValue) should be eliminated from board")
        }
        
        #expect(engine._latestEliminatedValueForTesting() == removedValue, "Spawn floor should reflect removed value")
    }

    @Test("Creating a 65K tile purges all 4s immediately")
    func testMilestoneEliminationOn65KMerge() {
        let config = GameConfig(boardWidth: 4, boardHeight: 4, seed: 11, fillMode: .alwaysFull)
        let engine = GameEngine(config: config)
        engine._setAllTilesForTesting(value: 4)

        let left = Position(row: 0, col: 0)
        let right = Position(row: 0, col: 1)
        engine._setTileForTesting(at: left, value: 32_768)
        engine._setTileForTesting(at: right, value: 32_768)

        let state = engine.commitChain([left, right])

        #expect(state.highestTile == 65_536, "Chain should produce a 65K tile")
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let pos = Position(row: row, col: col)
                if let tile = state.board[pos] {
                    #expect(tile.value != 4, "All 4s should be eliminated after reaching 65K")
                }
            }
        }
        #expect(engine._latestEliminatedValueForTesting() == 32, "Spawn floor should reflect the 65K milestone")
    }

    @Test("Milestone elimination re-triggers when the same 65K tile appears again")
    func testMilestoneEliminationRepeatsForExistingMilestone() {
        let config = GameConfig(boardWidth: 4, boardHeight: 4, seed: 22, fillMode: .alwaysFull)
        let engine = GameEngine(config: config)
        engine._setAllTilesForTesting(value: 8)

        let firstPair = [Position(row: 0, col: 0), Position(row: 0, col: 1)]
        firstPair.forEach { engine._setTileForTesting(at: $0, value: 32_768) }
        _ = engine.commitChain(firstPair)

        // Reintroduce a low-tier tile (value 4) via manual override to simulate a power-up or gift.
        let lowPos = Position(row: 3, col: 3)
        engine._setTileForTesting(at: lowPos, value: 4)
        #expect(engine.currentState().board[lowPos]?.value == 4, "Setup should place a 4 back on the board")

        let secondPair = [Position(row: 1, col: 0), Position(row: 1, col: 1)]
        secondPair.forEach { engine._setTileForTesting(at: $0, value: 32_768) }
        let state = engine.commitChain(secondPair)

        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let pos = Position(row: row, col: col)
                if let tile = state.board[pos] {
                    #expect(tile.value != 4, "Any reintroduced 4s should be purged on the next 65K creation")
                }
            }
        }
    }

    @Test("Milestone reward keeps the milestone tile on the board")
    func testMilestoneRewardsDoNotRemoveMilestoneTile() {
        let config = GameConfig(
            boardWidth: 3,
            boardHeight: 3,
            seed: 5,
            initialTileCount: 0,
            fillMode: .sparse
        )
        let engine = GameEngine(config: config)

        // Fill the board deterministically so the reward has tiles to clear.
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                engine._setTileForTesting(at: Position(row: row, col: col), value: 4)
            }
        }

        let left = Position(row: 0, col: 0)
        let right = Position(row: 0, col: 1)
        engine._setTileForTesting(at: left, value: 1_024)
        engine._setTileForTesting(at: right, value: 1_024)

        let state = engine.commitChain([left, right])

        let milestoneValue = 2_048
        var milestoneTiles = 0
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let pos = Position(row: row, col: col)
                if state.board[pos]?.value == milestoneValue {
                    milestoneTiles += 1
                }
            }
        }

        #expect(milestoneTiles > 0, "Milestone reward should not remove the newly created milestone tile")
    }
}

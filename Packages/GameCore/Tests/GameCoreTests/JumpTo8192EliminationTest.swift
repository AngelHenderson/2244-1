import Testing
@testable import GameCore

@Test("Jumping to 8192 should eliminate 2s and 4s from previous milestones")
func testJumpTo8192EliminatesPreviousMilestones() {
    // Create engine with deterministic seed
    let config = GameConfig(
        boardWidth: 5,
        boardHeight: 8,
        seed: 12345,
        fillMode: .alwaysFull
    )
    let engine = GameEngine(config: config)

    // Clear board and set up a mixed board with 2s, 4s, and 128s
    engine._setAllTilesForTesting(value: nil)
    engine._resetScoreForTesting()

    // Place some 2s and 4s that should be eliminated
    engine._setTileForTesting(at: Position(row: 7, col: 0), value: 2)
    engine._setTileForTesting(at: Position(row: 7, col: 1), value: 2)
    engine._setTileForTesting(at: Position(row: 7, col: 2), value: 4)
    engine._setTileForTesting(at: Position(row: 7, col: 3), value: 4)
    engine._setTileForTesting(at: Position(row: 7, col: 4), value: 4)

    // Place 35 tiles of 128 for creating 8192 in a valid snake path.
    var chainPositions: [Position] = []
    for row in 0..<8 {
        let columns = row.isMultiple(of: 2) ? Array(0..<5) : Array((0..<5).reversed())
        for col in columns {
            let pos = Position(row: row, col: col)
            // Skip the bottom row where we placed 2s and 4s.
            if row != 7 {
                engine._setTileForTesting(at: pos, value: 128)
                chainPositions.append(pos)
            }
        }
    }

    print("📊 Initial board state:")
    var initialCounts: [Int: Int] = [:]
    for row in 0..<8 {
        for col in 0..<5 {
            let pos = Position(row: row, col: col)
            if let tile = engine.currentState().board[pos] {
                initialCounts[tile.value, default: 0] += 1
            }
        }
    }
    for (value, count) in initialCounts.sorted(by: { $0.key < $1.key }) {
        print("   Value \(value): \(count) tiles")
    }

    // Verify we have 2s and 4s
    #expect(initialCounts[2] ?? 0 > 0, "Should have some 2s on the board")
    #expect(initialCounts[4] ?? 0 > 0, "Should have some 4s on the board")

    // Commit the chain - this should create 8192 and trigger eliminations
    let result = engine.commitChain(chainPositions, applyGravity: false)

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

    // Verify results
    #expect(result.highestTile == 8192, "Should have created 8192")
    #expect(finalCounts[8192] == 1, "Should have exactly one 8192 tile")

    // CRITICAL: 2s and 4s should be ELIMINATED because we passed milestones 2048 and 4096
    #expect(finalCounts[2] == nil || finalCounts[2] == 0, "All 2s should be eliminated (2048 milestone)")
    #expect(finalCounts[4] == nil || finalCounts[4] == 0, "All 4s should be eliminated (4096 milestone)")

    print("\n✅ Milestone eliminations applied:")
    print("   2048 milestone: eliminated all 2s")
    print("   4096 milestone: eliminated all 4s")
    print("   8192 milestone: skip (no elimination)")
}

@Test("Creating tiles sequentially should apply eliminations correctly")
func testSequentialMilestoneEliminations() {
    let config = GameConfig(
        boardWidth: 5,
        boardHeight: 8,
        seed: 54321,
        fillMode: .alwaysFull
    )
    let engine = GameEngine(config: config)

    // Clear and setup
    engine._setAllTilesForTesting(value: nil)
    engine._resetScoreForTesting()

    // Fill board with low values
    for row in 0..<8 {
        for col in 0..<5 {
            let pos = Position(row: row, col: col)
            let value = (row == 0) ? 2 : 4
            engine._setTileForTesting(at: pos, value: value)
        }
    }

    print("📊 Testing sequential milestone creation:")

    // First create 2048 - should eliminate 2s
    engine._applyMilestoneEliminationForTesting(createdValue: 2048)

    var counts: [Int: Int] = [:]
    for row in 0..<8 {
        for col in 0..<5 {
            let pos = Position(row: row, col: col)
            if let tile = engine.currentState().board[pos] {
                counts[tile.value, default: 0] += 1
            }
        }
    }

    print("After 2048: 2s=\(counts[2] ?? 0), 4s=\(counts[4] ?? 0)")
    #expect((counts[2] ?? 0) == 0, "2s should be eliminated after 2048")
    #expect((counts[4] ?? 0) > 0, "4s should still exist after 2048")

    // Now create 4096 - should eliminate 4s
    engine._applyMilestoneEliminationForTesting(createdValue: 4096)

    counts.removeAll()
    for row in 0..<8 {
        for col in 0..<5 {
            let pos = Position(row: row, col: col)
            if let tile = engine.currentState().board[pos] {
                counts[tile.value, default: 0] += 1
            }
        }
    }

    print("After 4096: 2s=\(counts[2] ?? 0), 4s=\(counts[4] ?? 0)")
    #expect((counts[2] ?? 0) == 0, "2s should remain eliminated")
    #expect((counts[4] ?? 0) == 0, "4s should be eliminated after 4096")

    // Create 8192 - should NOT eliminate anything (skip milestone)
    engine._applyMilestoneEliminationForTesting(createdValue: 8192)

    print("After 8192: No elimination (skip milestone)")
}

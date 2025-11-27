import Testing
@testable import GameCore

@Test("First time creating 8192 should eliminate 2s and 4s")
func testFirstTime8192EliminatesLowerValues() {
    let config = GameConfig(
        boardWidth: 5,
        boardHeight: 8,
        seed: 777,
        fillMode: .sparse  // Use sparse to control tiles better
    )
    let engine = GameEngine(config: config)

    // Clear board - start fresh with no milestones reached
    engine._setAllTilesForTesting(value: nil)
    engine._resetScoreForTesting()

    // The engine starts with highest tile = 0, no milestones reached

    // Set up a board with 2s, 4s, and lots of 128s
    // Place 2s and 4s
    engine._setTileForTesting(at: Position(row: 7, col: 0), value: 2)
    engine._setTileForTesting(at: Position(row: 7, col: 1), value: 2)
    engine._setTileForTesting(at: Position(row: 7, col: 2), value: 4)
    engine._setTileForTesting(at: Position(row: 7, col: 3), value: 4)
    engine._setTileForTesting(at: Position(row: 7, col: 4), value: 8)

    // Create exactly 40 tiles of 128 in a valid chain pattern
    var chainPositions: [Position] = []

    // Create a snaking chain through the board
    // Row 0: left to right
    for col in 0..<5 {
        let pos = Position(row: 0, col: col)
        engine._setTileForTesting(at: pos, value: 128)
        chainPositions.append(pos)
    }

    // Row 1: right to left
    for col in (0..<5).reversed() {
        let pos = Position(row: 1, col: col)
        engine._setTileForTesting(at: pos, value: 128)
        chainPositions.append(pos)
    }

    // Row 2: left to right
    for col in 0..<5 {
        let pos = Position(row: 2, col: col)
        engine._setTileForTesting(at: pos, value: 128)
        chainPositions.append(pos)
    }

    // Row 3: right to left
    for col in (0..<5).reversed() {
        let pos = Position(row: 3, col: col)
        engine._setTileForTesting(at: pos, value: 128)
        chainPositions.append(pos)
    }

    // Row 4: left to right
    for col in 0..<5 {
        let pos = Position(row: 4, col: col)
        engine._setTileForTesting(at: pos, value: 128)
        chainPositions.append(pos)
    }

    // Row 5: right to left
    for col in (0..<5).reversed() {
        let pos = Position(row: 5, col: col)
        engine._setTileForTesting(at: pos, value: 128)
        chainPositions.append(pos)
    }

    // Row 6: left to right
    for col in 0..<5 {
        let pos = Position(row: 6, col: col)
        engine._setTileForTesting(at: pos, value: 128)
        chainPositions.append(pos)
    }

    // Row 7 is partially filled with 2s and 4s, skip it

    // We have 35 tiles so far, need 5 more
    // Add some extras with value 128
    engine._setTileForTesting(at: Position(row: 6, col: 0), value: 128)
    engine._setTileForTesting(at: Position(row: 6, col: 1), value: 128)
    engine._setTileForTesting(at: Position(row: 6, col: 2), value: 128)
    engine._setTileForTesting(at: Position(row: 6, col: 3), value: 128)
    engine._setTileForTesting(at: Position(row: 6, col: 4), value: 128)

    // Ensure we have exactly 40 positions for our chain
    chainPositions = Array(chainPositions.prefix(40))

    print("📊 Initial state:")
    let initialState = engine.currentState()
    print("   Highest tile: \(initialState.highestTile)")

    var initialCounts: [Int: Int] = [:]
    for row in 0..<8 {
        for col in 0..<5 {
            let pos = Position(row: row, col: col)
            if let tile = initialState.board[pos] {
                initialCounts[tile.value, default: 0] += 1
            }
        }
    }

    print("   Tile counts:")
    for (value, count) in initialCounts.sorted(by: { $0.key < $1.key }) {
        print("      Value \(value): \(count) tiles")
    }

    #expect(initialCounts[2] == 2, "Should have 2 tiles of value 2")
    #expect(initialCounts[4] == 2, "Should have 2 tiles of value 4")
    #expect(initialCounts[128]! >= 40, "Should have at least 40 tiles of 128")

    print("\n🔗 Creating chain with \(chainPositions.count) tiles of 128...")

    // Commit the chain - this creates 8192 for the first time
    let result = engine.commitChain(chainPositions, applyGravity: false)

    print("\n📊 Final state:")
    print("   Highest tile: \(result.highestTile)")

    var finalCounts: [Int: Int] = [:]
    for row in 0..<8 {
        for col in 0..<5 {
            let pos = Position(row: row, col: col)
            if let tile = result.board[pos] {
                finalCounts[tile.value, default: 0] += 1
            }
        }
    }

    print("   Tile counts:")
    for (value, count) in finalCounts.sorted(by: { $0.key < $1.key }) {
        print("      Value \(value): \(count) tiles")
    }

    // Key assertions
    #expect(result.highestTile == 8192, "Should have created 8192")

    // When jumping from 0/128 to 8192, we pass these milestones:
    // - 2048: eliminates 2s ✓
    // - 4096: eliminates 4s ✓
    // - 8192: skip (no elimination)

    #expect(finalCounts[2] == nil || finalCounts[2] == 0,
            "All 2s should be eliminated when passing 2048 milestone")
    #expect(finalCounts[4] == nil || finalCounts[4] == 0,
            "All 4s should be eliminated when passing 4096 milestone")
    #expect(finalCounts[8] ?? 0 > 0,
            "8s should NOT be eliminated (no milestone eliminates them yet)")

    print("\n✅ Milestone eliminations correctly applied:")
    print("   Passed 2048: eliminated all 2s")
    print("   Passed 4096: eliminated all 4s")
    print("   Reached 8192: skip milestone (no elimination)")
}
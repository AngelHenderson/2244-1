import Testing
@testable import GameCore

@Test("40 tiles of 128 should create 8192 without elimination")
func test40TilesOf128Creates8192() {
    // Create engine with deterministic seed
    let config = GameConfig(
        boardWidth: 5,
        boardHeight: 8,
        seed: 12345,
        fillMode: .alwaysFull
    )
    let engine = GameEngine(config: config)

    // Clear board and set up tiles of value 128
    engine._setAllTilesForTesting(value: 128)
    engine._resetScoreForTesting()

    // Create a valid chain of 40 adjacent tiles
    var chainPositions: [Position] = []

    // Build a snake-like chain pattern
    // Row 0: left to right (5 tiles)
    for col in 0..<5 {
        chainPositions.append(Position(row: 0, col: col))
    }
    // Row 1: right to left (5 tiles)
    for col in (0..<5).reversed() {
        chainPositions.append(Position(row: 1, col: col))
    }
    // Row 2: left to right (5 tiles)
    for col in 0..<5 {
        chainPositions.append(Position(row: 2, col: col))
    }
    // Row 3: right to left (5 tiles)
    for col in (0..<5).reversed() {
        chainPositions.append(Position(row: 3, col: col))
    }
    // Row 4: left to right (5 tiles)
    for col in 0..<5 {
        chainPositions.append(Position(row: 4, col: col))
    }
    // Row 5: right to left (5 tiles)
    for col in (0..<5).reversed() {
        chainPositions.append(Position(row: 5, col: col))
    }
    // Row 6: left to right (5 tiles)
    for col in 0..<5 {
        chainPositions.append(Position(row: 6, col: col))
    }
    // Row 7: right to left (5 tiles)
    for col in (0..<5).reversed() {
        chainPositions.append(Position(row: 7, col: col))
    }

    // Take exactly 40 positions
    chainPositions = Array(chainPositions.prefix(40))

    print("🔗 Chain has \(chainPositions.count) positions")

    // Track tiles before merge
    let stateBefore = engine.currentState()
    var tilesBeforeMerge: [Int: Int] = [:]
    for row in 0..<8 {
        for col in 0..<5 {
            let pos = Position(row: row, col: col)
            if let tile = stateBefore.board[pos] {
                tilesBeforeMerge[tile.value, default: 0] += 1
            }
        }
    }

    // Commit the chain
    let result = engine.commitChain(chainPositions, applyGravity: false)

    // Check the result
    #expect(result.highestTile == 8192, "Should create 8192 from 40×128")

    // Find the created tile
    var createdTilePosition: Position? = nil
    for pos in chainPositions {
        if let tile = result.board[pos] {
            if tile.value == 8192 {
                createdTilePosition = pos
                break
            }
        }
    }

    #expect(createdTilePosition != nil, "Should have created an 8192 tile")

    // Count remaining tiles - should NOT have eliminated anything
    // because 8192 is a skip milestone
    var tilesAfterMerge: [Int: Int] = [:]
    for row in 0..<8 {
        for col in 0..<5 {
            let pos = Position(row: row, col: col)
            if let tile = result.board[pos] {
                tilesAfterMerge[tile.value, default: 0] += 1
            }
        }
    }

    print("\n📊 Tiles before merge:")
    for (value, count) in tilesBeforeMerge.sorted(by: { $0.key < $1.key }) {
        print("   Value \(value): \(count) tiles")
    }

    print("\n📊 Tiles after merge:")
    for (value, count) in tilesAfterMerge.sorted(by: { $0.key < $1.key }) {
        print("   Value \(value): \(count) tiles")
    }

    // Since 8192 is a skip milestone, NO tiles should be eliminated
    // The only change should be: -39 tiles of 128, +1 tile of 8192
    let tiles128Before = tilesBeforeMerge[128] ?? 0
    let tiles128After = tilesAfterMerge[128] ?? 0
    let tiles8192After = tilesAfterMerge[8192] ?? 0

    print("\n✅ Verification:")
    print("   128 tiles before: \(tiles128Before)")
    print("   128 tiles after: \(tiles128After)")
    print("   8192 tiles after: \(tiles8192After)")
    print("   128 tiles removed: \(tiles128Before - tiles128After)")

    #expect(tiles128Before - tiles128After == 40, "Should have consumed exactly 40 tiles of 128")
    #expect(tiles8192After == 1, "Should have created exactly 1 tile of 8192")

    // Check that no other values were eliminated (8192 is a skip milestone)
    for (value, countBefore) in tilesBeforeMerge {
        if value != 128 { // Skip the tiles we merged
            let countAfter = tilesAfterMerge[value] ?? 0
            #expect(countAfter >= countBefore || countAfter == 0,
                   "Value \(value) should not have been eliminated (8192 is a skip milestone)")
        }
    }
}
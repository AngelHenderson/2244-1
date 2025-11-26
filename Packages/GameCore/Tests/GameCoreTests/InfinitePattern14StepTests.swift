import Testing
import Foundation
@testable import GameCore

struct InfinitePattern14StepTests {

    @Test("After 67M, elimination is always 14 steps down")
    func test14StepEliminationPattern() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 12345)
        let engine = GameEngine(config: config)

        // Test cases for the 14-step pattern after 134M
        let testCases: [(milestone: Int, expectedElimination: Int?)] = [
            // Special cases before the infinite pattern
            (67108864, 4096),      // 67M eliminates 4096 (special)
            (134217728, 8192),     // 134M eliminates 8192 (special)

            // After 134M: 14-step pattern with skips
            (268435456, nil),      // 268M skips (position 2 from 67M)
            (536870912, 32768),    // 536M >> 14 = 32768
            (1073741824, 65536),   // 1G >> 14 = 65536

            (2147483648, nil),     // 2G skips (position 5 from 67M)
            (4294967296, 262144),  // 4G >> 14 = 262144
            (8589934592, 524288),  // 8G >> 14 = 524288

            (17179869184, nil),    // 16G skips (position 8 from 67M)
            (34359738368, 2097152), // 32G >> 14 = 2097152
            (68719476736, 4194304), // 64G >> 14 = 4194304
        ]

        for (milestone, expected) in testCases {
            let result = engine.milestoneExcludedValue(for: milestone)
            #expect(result == expected,
                   "Milestone \(milestone) should \(expected == nil ? "skip" : "eliminate \(expected!)")")
        }
    }

    @Test("Spawn values are 7 steps down from milestones after 67M")
    func testSpawnValuesAfter67M() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 12345)
        let engine = GameEngine(config: config)

        // Clear board and setup
        engine._setAllTilesForTesting(value: nil)

        // Create a 67M tile to trigger the new spawn logic
        engine._setTileForTesting(at: Position(row: 0, col: 0), value: 33554432)
        engine._setTileForTesting(at: Position(row: 0, col: 1), value: 33554432)

        // Merge to create 67M
        let state = engine.commitChain([Position(row: 0, col: 0), Position(row: 0, col: 1)])

        #expect(state.highestTile == 67108864, "Should have created 67M")

        // After creating 67M, minimum spawn should be 67M >> 7 = 524288
        // Test by checking that no values below 524288 spawn
        let minExpectedSpawn = 67108864 >> 7 // 524288

        // Check the board for any spawned values
        var minFoundValue = Int.max
        for row in 0..<3 {
            for col in 0..<3 {
                if let tile = state.board[Position(row: row, col: col)] {
                    if tile.value < minFoundValue && tile.value != 67108864 {
                        minFoundValue = tile.value
                    }
                }
            }
        }

        if minFoundValue != Int.max {
            #expect(minFoundValue >= minExpectedSpawn,
                   "Minimum spawn value should be at least \(minExpectedSpawn), found \(minFoundValue)")
        }
    }

    @Test("Skip pattern continues correctly in infinite repetition")
    func testSkipPatternContinues() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 12345)
        let engine = GameEngine(config: config)

        // Test that every 3rd position from 67M is a skip
        // Positions: 0 (67M), 1 (134M), 2 (268M skip), 3 (536M), 4 (1G), 5 (2G skip), etc.

        let skipPositions = [2, 5, 8, 11, 14, 17, 20] // Every 3rd position
        let nonSkipPositions = [0, 1, 3, 4, 6, 7, 9, 10]

        // Test skip positions
        for pos in skipPositions {
            if pos <= 20 { // Don't test too large values
                let milestone = 67108864 * (1 << pos) // 67M * 2^position
                let result = engine.milestoneExcludedValue(for: milestone)
                #expect(result == nil, "Position \(pos) from 67M should skip")
            }
        }

        // Test non-skip positions for correct 14-step elimination
        for pos in nonSkipPositions {
            if pos <= 10 && pos >= 3 { // Test a reasonable range after the special cases
                let milestone = 67108864 * (1 << pos) // 67M * 2^position
                let result = engine.milestoneExcludedValue(for: milestone)
                if pos < 2 {
                    // Special cases for 67M and 134M
                    continue
                }
                let expected = milestone >> 14
                #expect(result == expected,
                       "Position \(pos) from 67M should eliminate \(expected)")
            }
        }
    }

    @Test("Very large milestones follow 14-step pattern")
    func testVeryLargeMilestones() {
        let config = GameConfig(boardWidth: 3, boardHeight: 3, seed: 12345)
        let engine = GameEngine(config: config)

        // Test some very large milestones (within Int range)
        // Position from 67M = exponent - 26
        let testCases: [(exponent: Int, shouldSkip: Bool)] = [
            (40, true),  // 2^40: position 14 from 67M (14 % 3 = 2, skip)
            (41, false), // 2^41: position 15 from 67M (15 % 3 = 0, not skip)
            (42, false), // 2^42: position 16 from 67M (16 % 3 = 1, not skip)
            (43, true),  // 2^43: position 17 from 67M (17 % 3 = 2, skip)
            (44, false), // 2^44: position 18 from 67M (18 % 3 = 0, not skip)
        ]

        for test in testCases {
            let milestone = 1 << test.exponent
            let result = engine.milestoneExcludedValue(for: milestone)

            if test.shouldSkip {
                #expect(result == nil, "2^\(test.exponent) should skip")
            } else {
                let expected = milestone >> 14
                #expect(result == expected,
                       "2^\(test.exponent) should eliminate \(expected)")
            }
        }
    }
}
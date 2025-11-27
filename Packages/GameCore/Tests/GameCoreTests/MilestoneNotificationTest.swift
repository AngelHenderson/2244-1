import Testing
@testable import GameCore

@Test("Skip milestones should not return elimination or addition values")
func testSkipMilestonesNoChanges() {
    let config = GameConfig()
    let engine = GameEngine(config: config)

    // Test skip milestones - they should return nil for both eliminated and added values
    let skipMilestones = [8192, 131072, 2097152, 33554432]

    for milestone in skipMilestones {
        let eliminated = engine.milestoneExcludedValue(for: milestone)
        let added = engine.milestoneAddedValue(for: milestone)

        #expect(eliminated == nil, "\(milestone) is a skip milestone - should not eliminate anything")
        #expect(added == nil, "\(milestone) is a skip milestone - should not add anything to spawn pool")
    }
}

@Test("Elimination milestones should return correct values")
func testEliminationMilestones() {
    let config = GameConfig()
    let engine = GameEngine(config: config)

    // Test elimination milestones
    let testCases: [(milestone: Int, eliminates: Int?, adds: Int?)] = [
        (2048, 2, 4),      // Eliminates 2s, adds 4s to spawn
        (4096, 4, 8),      // Eliminates 4s, adds 8s to spawn
        (8192, nil, nil),  // Skip - no changes
        (16384, 8, 16),    // Eliminates 8s, adds 16s to spawn
        (32768, 16, 32),   // Eliminates 16s, adds 32s to spawn
        (65536, 32, 64),   // Eliminates 32s, adds 64s to spawn
        (131072, nil, nil), // Skip - no changes
    ]

    for testCase in testCases {
        let eliminated = engine.milestoneExcludedValue(for: testCase.milestone)
        let added = engine.milestoneAddedValue(for: testCase.milestone)

        #expect(eliminated == testCase.eliminates,
                "Milestone \(testCase.milestone) should eliminate \(testCase.eliminates ?? 0)")
        #expect(added == testCase.adds,
                "Milestone \(testCase.milestone) should add \(testCase.adds ?? 0) to spawn pool")
    }
}

@Test("Getting milestones between values")
func testMilestonesBetween() {
    let config = GameConfig()
    let engine = GameEngine(config: config)

    // Test 1: Jump from 128 to 8192 should include 2048, 4096, and 8192
    let milestones1 = engine.milestonesBetween(128, and: 8192)
    #expect(milestones1.contains(2048), "Should include 2048")
    #expect(milestones1.contains(4096), "Should include 4096")
    #expect(milestones1.contains(8192), "Should include 8192")
    #expect(milestones1.count == 3, "Should have exactly 3 milestones")

    // Test 2: Jump from 4096 to 8192 should only include 8192
    let milestones2 = engine.milestonesBetween(4096, and: 8192)
    #expect(milestones2 == [8192], "Should only include 8192")

    // Test 3: Jump from 8192 to 16384 should only include 16384
    let milestones3 = engine.milestonesBetween(8192, and: 16384)
    #expect(milestones3 == [16384], "Should only include 16384")

    // Test 4: No milestones if no change
    let milestones4 = engine.milestonesBetween(100, and: 127)
    #expect(milestones4.isEmpty, "No milestones between 100 and 127")
}

@Test("Notifications for skip milestone 8192")
func testSkipMilestoneNotifications() {
    let config = GameConfig()
    let engine = GameEngine(config: config)

    // When jumping from 128 to 8192:
    // - Pass 2048: eliminates 2s, adds 4s
    // - Pass 4096: eliminates 4s, adds 8s
    // - Reach 8192: skip milestone (no changes)

    let passedMilestones = engine.milestonesBetween(128, and: 8192)

    var eliminatedValues: Set<Int> = []
    var addedValues: Set<Int> = []

    for milestone in passedMilestones {
        if let eliminated = engine.milestoneExcludedValue(for: milestone) {
            eliminatedValues.insert(eliminated)
        }
        if let added = engine.milestoneAddedValue(for: milestone) {
            addedValues.insert(added)
        }
    }

    // Should have eliminated 2s and 4s
    #expect(eliminatedValues.contains(2), "Should eliminate 2s from 2048 milestone")
    #expect(eliminatedValues.contains(4), "Should eliminate 4s from 4096 milestone")
    #expect(eliminatedValues.count == 2, "Should eliminate exactly 2 values")

    // Should have added 4s and 8s to spawn pool
    #expect(addedValues.contains(4), "Should add 4s to spawn from 2048 milestone")
    #expect(addedValues.contains(8), "Should add 8s to spawn from 4096 milestone")
    #expect(addedValues.count == 2, "Should add exactly 2 values")

    // 8192 itself should not contribute to eliminations or additions
    let direct8192Eliminated = engine.milestoneExcludedValue(for: 8192)
    let direct8192Added = engine.milestoneAddedValue(for: 8192)
    #expect(direct8192Eliminated == nil, "8192 should not eliminate anything")
    #expect(direct8192Added == nil, "8192 should not add anything")
}
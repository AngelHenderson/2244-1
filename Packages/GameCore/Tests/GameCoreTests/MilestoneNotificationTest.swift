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
    // When eliminating X, we add X * 128 (7 steps above) to spawn pool
    let testCases: [(milestone: Int, eliminates: Int?, adds: Int?)] = [
        (2048, 2, 256),      // Eliminates 2s, adds 256s to spawn (2 * 128)
        (4096, 4, 512),      // Eliminates 4s, adds 512s to spawn (4 * 128)
        (8192, nil, nil),    // Skip - no changes
        (16384, 8, 1024),    // Eliminates 8s, adds 1024s to spawn (8 * 128)
        (32768, 16, 2048),   // Eliminates 16s, adds 2048s to spawn (16 * 128)
        (65536, 32, 4096),   // Eliminates 32s, adds 4096s to spawn (32 * 128)
        (131072, nil, nil),  // Skip - no changes
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

    // Test 1: Jump from 128 to 8192 includes early spawn milestones plus 2048, 4096, and 8192
    let milestones1 = engine.milestonesBetween(128, and: 8192)
    #expect(milestones1.contains(256), "Should include 256")
    #expect(milestones1.contains(512), "Should include 512")
    #expect(milestones1.contains(1024), "Should include 1024")
    #expect(milestones1.contains(2048), "Should include 2048")
    #expect(milestones1.contains(4096), "Should include 4096")
    #expect(milestones1.contains(8192), "Should include 8192")
    #expect(milestones1.count == 6, "Should have exactly 6 milestones")

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
    // - Early milestones eliminate implicit 1s and add 128s
    // - Pass 2048: eliminates 2s, adds 256s
    // - Pass 4096: eliminates 4s, adds 512s
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

    // Should have eliminated implicit 1s plus 2s and 4s
    #expect(eliminatedValues.contains(1), "Early milestones should eliminate implicit 1s")
    #expect(eliminatedValues.contains(2), "Should eliminate 2s from 2048 milestone")
    #expect(eliminatedValues.contains(4), "Should eliminate 4s from 4096 milestone")
    #expect(eliminatedValues.count == 3, "Should eliminate exactly 3 values")

    // Should have added 128s, 256s, and 512s to spawn pool
    #expect(addedValues.contains(128), "Should add 128s to spawn from early milestones")
    #expect(addedValues.contains(256), "Should add 256s to spawn from 2048 milestone (2 * 128)")
    #expect(addedValues.contains(512), "Should add 512s to spawn from 4096 milestone (4 * 128)")
    #expect(addedValues.count == 3, "Should add exactly 3 values")

    // 8192 itself should not contribute to eliminations or additions
    let direct8192Eliminated = engine.milestoneExcludedValue(for: 8192)
    let direct8192Added = engine.milestoneAddedValue(for: 8192)
    #expect(direct8192Eliminated == nil, "8192 should not eliminate anything")
    #expect(direct8192Added == nil, "8192 should not add anything")
}

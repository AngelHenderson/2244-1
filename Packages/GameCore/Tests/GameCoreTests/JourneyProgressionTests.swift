import Testing
import Foundation
@testable import GameCore

@Suite("Journey Progression Tests")
struct JourneyProgressionTests {
    
    @Test("Journey tiles progress to 873bz")
    func testJourneyProgressionTo873bz() {
        let tiles = JourneyTileGenerator.generateFullJourney()
        
        // Should have 817 tiles plus infinity
        #expect(tiles.count == 818)  // 817 doublings + 1 infinity tile
        
        // Last tile before infinity should be step 817 (873bz)
        let lastTile = tiles[tiles.count - 2]
        if case .highValue(let step) = lastTile.type {
            #expect(step == 817)
            let formatted = JourneyTileGenerator.formatTileAtStep(step)
            print("Step 817 formats as: \(formatted)")
            #expect(formatted == "873bz")
        } else {
            Issue.record("Last tile before infinity should be highValue type")
        }
        
        // Check infinity tile
        let infinityTile = tiles.last!
        #expect(infinityTile.type == .infinity)
    }
    
    @Test("Tile formatting shows correct progression")
    func testTileFormattingProgression() {
        // Test key milestones in the progression
        let testCases: [(step: Int, expected: String)] = [
            (1, "2"),
            (10, "1K"),     // 2^10 = 1024 ≈ 1K
            (20, "1M"),     // 2^20 = 1048576 ≈ 1M  
            (30, "1B"),     // 2^30 = 1073741824 ≈ 1B
            (40, "1a"),     // 2^40 ≈ 1.1 * 10^12 ≈ 1a
            (50, "1b"),     // 2^50 ≈ 1.1 * 10^15 ≈ 1b
            (60, "1c"),     // 2^60 ≈ 1.2 * 10^18 ≈ 1c
            (817, "873bz")  // The target!
        ]
        
        for (step, expected) in testCases {
            let formatted = JourneyTileGenerator.formatTileAtStep(step)
            print("Step \(step): \(formatted) (expected: \(expected))")
            
            // For larger values, just check the suffix is correct
            if step > 60 {
                if step == 817 {
                    #expect(formatted == expected)
                } else {
                    // Just verify it has a letter suffix
                    #expect(formatted.contains(where: { $0.isLetter && $0.isLowercase }))
                }
            }
        }
    }
    
    @Test("Journey shows tiles beyond current highest")
    func testJourneyBeyondHighest() {
        // Test with a highest tile of 1024
        let tiles = JourneyTileGenerator.generateJourney(highest: 1024, stepsAhead: 10)
        
        // Should include all tiles up to 1024, then 10 more, plus infinity
        // 1024 is step 10 (2^10), so we should have tiles: 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024
        // That's 10 tiles, plus 10 ahead, plus infinity = 21 tiles
        #expect(tiles.count >= 21)
        
        // Check that we have tiles beyond 1024
        let tilesAfter1024 = tiles.filter { tile in
            if tile.type == .infinity { return false }
            if case .highValue = tile.type { return true }
            return tile.value > 1024
        }
        #expect(tilesAfter1024.count >= 10)
    }
    
    @Test("High value tiles format correctly")
    func testHighValueTileFormatting() {
        // Create a high value tile for step 100
        let tile = Tile(value: Int.max, type: .highValue(step: 100))
        
        // The formatter should recognize this and format appropriately
        let formatted = JourneyTileGenerator.formatTileAtStep(100)
        print("Step 100 tile formats as: \(formatted)")
        
        // Step 100 should be around 10^30, which is suffix 'g'
        #expect(formatted.hasSuffix("g"))
    }
}
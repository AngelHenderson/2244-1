import Testing
@testable import GameCore

@Suite("Journey Abbreviation Tier Tests")
struct JourneyAbbreviationTiersTests {
    @Test("Tier sequence includes expected labels")
    func testTierSequenceContainsMilestones() {
        let labels = Set(JourneyAbbreviationTiers.tiers.map { $0.label.lowercased() })
        #expect(labels.contains("1m"))
        #expect(labels.contains("1b"))
        #expect(labels.contains("1a"))
        #expect(labels.contains("1z"))
        #expect(labels.contains("1aa"))
        #expect(labels.contains("1az"))
        #expect(labels.contains("1ba"))
        #expect(labels.contains("1bz"))
        #expect(labels.contains("873bz"))
        #expect(labels.contains("∞"))
    }
    
    @Test("Tier lookup by step")
    func testTierLookupByStep() {
        #expect(JourneyAbbreviationTiers.tier(forStep: 19)?.label == "1M")
        #expect(JourneyAbbreviationTiers.tier(forStep: 29)?.label == "1B")
        #expect(JourneyAbbreviationTiers.tier(forStep: 39)?.label == "1a")
        #expect(JourneyAbbreviationTiers.tier(forStep: 817)?.label == "873bz")
    }
    
    @Test("Tier lookup from tile values")
    func testTierLookupFromTile() {
        let millionTile = Tile(value: 1 << 20)
        #expect(JourneyAbbreviationTiers.tier(for: millionTile)?.label == "1M")
        
        let trillionTile = Tile(value: Int.max, type: .highValue(step: 39))
        #expect(JourneyAbbreviationTiers.tier(for: trillionTile)?.label == "1a")
        
        let infinityTile = Tile(value: 0, type: .infinity)
        #expect(JourneyAbbreviationTiers.tier(for: infinityTile)?.isInfinity == true)
    }
}

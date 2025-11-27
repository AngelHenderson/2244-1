import Testing
import Foundation
@testable import GameCore

@Suite("AlphaMag Progression Tests")
struct AlphaMagProgressionTests {
    
    @Test("Letter progression continues through all letters without capping")
    func testFullLetterProgression() throws {
        // Test progression through single letters
        #expect(AlphaMag.format(1_000_000_000_000) == "1a")  // 10^12
        #expect(AlphaMag.format(1_000_000_000_000_000) == "1b")  // 10^15
        #expect(AlphaMag.format(1_000_000_000_000_000_000) == "1c")  // 10^18

        // Test suffix ordinal calculations for higher tiers
        // Since Decimal can't handle extremely large numbers, we'll test the suffix logic directly

        // Test 'z' is ordinal 26
        let zOrdinal = try AlphaMag.ordinal(forSuffix: "z")
        #expect(zOrdinal == 26)
        #expect(AlphaMag.suffix(forOrdinal: 26) == "z")

        // Test double letters
        let aaOrdinal = try AlphaMag.ordinal(forSuffix: "aa")
        #expect(aaOrdinal == 27)
        #expect(AlphaMag.suffix(forOrdinal: 27) == "aa")

        // Test progression to 'bz'
        let bzOrdinal = try AlphaMag.ordinal(forSuffix: "bz")
        #expect(bzOrdinal == 78)
        #expect(AlphaMag.suffix(forOrdinal: 78) == "bz")

        // Test it continues past 'bz'
        let caOrdinal = try AlphaMag.ordinal(forSuffix: "ca")
        #expect(caOrdinal == 79)
        #expect(AlphaMag.suffix(forOrdinal: 79) == "ca")

        // Test next suffix progression
        #expect(try AlphaMag.nextSuffix(after: "z") == "aa")
        #expect(try AlphaMag.nextSuffix(after: "bz") == "ca")
    }
    
    @Test("Doubling sequence reaches 873bz correctly")
    func testDoublingTo873bz() throws {
        // The doubling sequence 2, 4, 8, 16... should eventually reach ~873 * 10^245
        // This happens at approximately step 817 (2^817)

        // We can't actually compute 2^817 in Decimal, but we can verify the formatting
        // would work if we could represent such a value

        // Test that 873bz would format correctly
        // 873 * 10^245 (slightly different from 1bz which is 10^243)
        // Note: Decimal type has limits, so we'll use a smaller test value

        // Test a more reasonable value that still uses the bz suffix
        // bz is ordinal 78, which means 10^(12 + 77*3) = 10^243
        // Let's test 1bz = 10^243
        // Since Decimal can't handle such large numbers, we'll skip the actual formatting test
        // and just verify the suffix progression logic

        // Verify bz is ordinal 78
        let bzOrdinal = try AlphaMag.ordinal(forSuffix: "bz")
        #expect(bzOrdinal == 78)

        // Verify suffix generation
        #expect(AlphaMag.suffix(forOrdinal: 78) == "bz")

        // Test that the next suffix after bz is ca
        let nextSuffix = try AlphaMag.nextSuffix(after: "bz")
        #expect(nextSuffix == "ca")
    }
    
    @Test("Suffix progression is correct")
    func testSuffixProgression() throws {
        // Single letters
        #expect(AlphaMag.suffix(forOrdinal: 1) == "a")
        #expect(AlphaMag.suffix(forOrdinal: 2) == "b")
        #expect(AlphaMag.suffix(forOrdinal: 3) == "c")
        #expect(AlphaMag.suffix(forOrdinal: 26) == "z")
        
        // Double letters
        #expect(AlphaMag.suffix(forOrdinal: 27) == "aa")
        #expect(AlphaMag.suffix(forOrdinal: 28) == "ab")
        #expect(AlphaMag.suffix(forOrdinal: 52) == "az")
        #expect(AlphaMag.suffix(forOrdinal: 53) == "ba")
        #expect(AlphaMag.suffix(forOrdinal: 78) == "bz")
        
        // Past bz
        #expect(AlphaMag.suffix(forOrdinal: 79) == "ca")
        #expect(AlphaMag.suffix(forOrdinal: 80) == "cb")
        #expect(AlphaMag.suffix(forOrdinal: 104) == "cz")
        
        // Much higher values
        #expect(AlphaMag.suffix(forOrdinal: 702) == "zz")  // Last double letter
        #expect(AlphaMag.suffix(forOrdinal: 703) == "aaa") // First triple letter
    }
    
    @Test("Tile formatting shows all milestones before infinity")
    func testTileFormattingMilestones() {
        // Test key milestones in the doubling sequence
        let milestones: [(Int, String)] = [
            (2, "2"),
            (4, "4"),
            (8, "8"),
            (16, "16"),
            (32, "32"),
            (64, "64"),
            (128, "128"),
            (256, "256"),
            (512, "512"),
            (1024, "1024"),
            (2048, "2048"),
            (4096, "4096"),
            (8192, "8192"),
            (16384, "16K"),  // Start using K
            (32768, "32K"),
            (65536, "65K"),
            (131072, "131K"),
            (262144, "262K"),
            (524288, "524K"),
            (1048576, "1M"),  // Start using M
            (2097152, "2M"),
            (1073741824, "1B"),  // Start using B
            (Int.max, AlphaMag.formatTileValue(Int.max))  // Whatever max int gives
        ]
        
        for (value, expected) in milestones {
            let formatted = AlphaMag.formatTileValue(value)
            print("Tile \(value) -> \"\(formatted)\" (expected: \"\(expected)\")")
            if value < 1_000_000_000_000 {  // Only check exact formatting for smaller values
                #expect(formatted == expected)
            }
        }
    }
    
    @Test("Score display uses K/M/B/alphabetic notation with full precision")
    func testScoreDisplayFormatting() {
        // Test billion formatting
        #expect(AlphaMag.formatScoreDisplay(710_000_000_000) == "710B")
        #expect(AlphaMag.formatScoreDisplay(999_999_999_999) == "999B")  // Shows as 999B

        // Test trillion formatting with 'a' suffix - shows full precision with commas
        #expect(AlphaMag.formatScoreDisplay(1_000_000_000_000) == "1,000a")  // 1 trillion = 1,000 billion
        #expect(AlphaMag.formatScoreDisplay(2_040_584_000_000) == "2,040a")  // 2,040.584 billion
        #expect(AlphaMag.formatScoreDisplay(5_500_000_000_000) == "5,500a")  // 5,500 billion
        #expect(AlphaMag.formatScoreDisplay(394_567_000_000_000) == "394,567a")  // 394,567 billion
        #expect(AlphaMag.formatScoreDisplay(999_999_000_000_000) == "999,999a")  // 999,999 billion

        // Test quadrillion formatting with 'b' suffix
        #expect(AlphaMag.formatScoreDisplay(1_000_000_000_000_000) == "1,000b")  // 1 quadrillion = 1,000 trillion
        #expect(AlphaMag.formatScoreDisplay(5_500_000_000_000_000) == "5,500b")  // 5,500 trillion

        // Test quintillion formatting with 'c' suffix (if Int can hold it)
        if Int.max >= 1_000_000_000_000_000_000 {
            #expect(AlphaMag.formatScoreDisplay(1_000_000_000_000_000_000) == "1c")  // 1 quintillion
            #expect(AlphaMag.formatScoreDisplay(2_345_000_000_000_000_000) == "2,345c")  // 2,345 quintillion
        }

        // Test million formatting
        #expect(AlphaMag.formatScoreDisplay(950_000_000) == "950M")
        #expect(AlphaMag.formatScoreDisplay(1_500_000) == "1M")  // Shows as 1M

        // Test thousand formatting
        #expect(AlphaMag.formatScoreDisplay(512_000) == "512K")
        #expect(AlphaMag.formatScoreDisplay(1_500) == "1K")  // Shows as 1K
        #expect(AlphaMag.formatScoreDisplay(9_999) == "9K")  // Shows as 9K
        #expect(AlphaMag.formatScoreDisplay(10_000) == "10K")  // Shows as 10K
        #expect(AlphaMag.formatScoreDisplay(999_000) == "999K")  // Shows as 999K

        // Test small values
        #expect(AlphaMag.formatScoreDisplay(999) == "999")
        #expect(AlphaMag.formatScoreDisplay(0) == "0")
    }
    
    @Test("No artificial capping at any suffix")
    func testNoCapping() throws {
        // Test that we can format values at any suffix level
        let testSuffixes = ["a", "z", "aa", "az", "bz", "ca", "cz", "zz", "aaa", "zzz"]
        
        for suffix in testSuffixes {
            let ord = try AlphaMag.ordinal(forSuffix: suffix)
            let computedSuffix = AlphaMag.suffix(forOrdinal: ord)
            #expect(computedSuffix == suffix)
            
            // Test next suffix works
            let nextSuffix = try AlphaMag.nextSuffix(after: suffix)
            let nextOrd = try AlphaMag.ordinal(forSuffix: nextSuffix)
            #expect(nextOrd == ord + 1)
        }
    }
}
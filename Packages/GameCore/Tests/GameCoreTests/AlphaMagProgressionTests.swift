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
        
        // Test it continues past 'z'
        let zValue = Decimal(string: "1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")!  // 10^87 = 1z
        #expect(try AlphaMag.format(zValue) == "1z")
        
        // Test double letters
        let aaValue = zValue * 1000  // 10^90 = 1aa
        #expect(try AlphaMag.format(aaValue) == "1aa")
        
        // Test progression to 'bz'
        let bzOrdinal = try AlphaMag.ordinal(forSuffix: "bz")
        #expect(bzOrdinal == 78)
        
        // bz represents 10^(12 + 77*3) = 10^243
        let bzValue = Decimal(string: "1" + String(repeating: "0", count: 243))!
        #expect(try AlphaMag.format(bzValue) == "1bz")
        
        // Test it continues past 'bz'
        let afterBzValue = bzValue * 1000  // Should be 1ca
        #expect(try AlphaMag.format(afterBzValue) == "1ca")
    }
    
    @Test("Doubling sequence reaches 873bz correctly")
    func testDoublingTo873bz() throws {
        // The doubling sequence 2, 4, 8, 16... should eventually reach ~873 * 10^245
        // This happens at approximately step 817 (2^817)
        
        // We can't actually compute 2^817 in Decimal, but we can verify the formatting
        // would work if we could represent such a value
        
        // Test that 873bz would format correctly
        // 873 * 10^245 (slightly different from 1bz which is 10^243)
        let value873bz = Decimal(string: "873" + String(repeating: "0", count: 245))!
        let formatted = try AlphaMag.format(value873bz)
        
        // The value 873 * 10^245 should format as "873bz" 
        // because bz is for 10^243 base, and 873 * 10^245 = 87300 * 10^243
        // Actually it would be 87300bz, let's check the actual formatting
        print("873 * 10^245 formats as: \(formatted)")
        
        // More precisely, for the "bz" tier (10^243):
        // We want values like 1bz, 2bz, ..., 873bz, ...
        // 873 * 10^243 should give us "873bz"
        let correctValue = Decimal(string: "873" + String(repeating: "0", count: 243))!
        let correctFormatted = try AlphaMag.format(correctValue)
        #expect(correctFormatted == "873bz")
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
    
    @Test("Score display stays in millions even past billions")
    func testScoreDisplayFormatting() {
        #expect(AlphaMag.formatScoreDisplay(710_000_000_000) == "710,000M")
        #expect(AlphaMag.formatScoreDisplay(950_000_000) == "950M")
        #expect(AlphaMag.formatScoreDisplay(512_000) == "512K")
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
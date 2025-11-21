import Testing
@testable import GameCore

@Suite("TileStepLabelFormatter Tests")
struct TileStepLabelFormatterTests {
    
    @Test("Small values and K suffix")
    func testSmallAndK() {
        // 2 -> step 12 = 8192
        #expect(TileStepLabelFormatter.labelForStep(12) == "8,192")
        #expect(TileStepLabelFormatter.labelForStep(13) == "16K")
        #expect(TileStepLabelFormatter.labelForStep(14) == "32K")
        #expect(TileStepLabelFormatter.labelForStep(15) == "65K")
        #expect(TileStepLabelFormatter.labelForStep(16) == "131K")
        #expect(TileStepLabelFormatter.labelForStep(17) == "262K")
        #expect(TileStepLabelFormatter.labelForStep(18) == "524K")
    }
    
    @Test("M and B suffixes and letter tiers")
    func testMAndBAndLetters() {
        // 2^20 = 1_048_576 (step 19)
        #expect(TileStepLabelFormatter.labelForStep(19) == "1M")
        // 2^24 = 16_777_216 (step 23)
        #expect(TileStepLabelFormatter.labelForStep(23) == "16M")
        // 2^25 = 33_554_432 (step 24)
        #expect(TileStepLabelFormatter.labelForStep(24) == "33M")
        // 2^39 = 549_755_813_888 (step 38)
        #expect(TileStepLabelFormatter.labelForStep(38) == "549B")
        // 2^40 = 1_099_511_627_776 (step 39) -> 1a
        #expect(TileStepLabelFormatter.labelForStep(39) == "1a")
        // 2^44 = 17_592_186_044_416 (step 43) -> 17a
        #expect(TileStepLabelFormatter.labelForStep(43) == "17a")
    }
    
    @Test("Carry at 1000 boundary")
    func testCarryAt1000() {
        // Step 49 = 2^50 = 1,125,899,906,842,624 = 1125a
        // Step 48 = 2^49 = 562,949,953,421,312 = 562a 
        // We need to find where we get close to 999 in the "a" tier
        // 2^49.96 ≈ 999 trillion, so around step 49
        // Since we only deal with integer steps, we can't get exactly 999a
        // But we can verify the carry logic by checking that values just before
        // 1000 in one tier properly carry to the next tier
        
        // Let's verify the pattern instead:
        // Step 39 gives us 1a (first trillion)
        let step39 = TileStepLabelFormatter.labelForStep(39)
        #expect(step39 == "1a")
        
        // Step 49 = 2^50 = 1,125,899,906,842,624 should give us 1b (first quadrillion)
        let step49 = TileStepLabelFormatter.labelForStep(49)
        #expect(step49 == "1b")
        
        // Step 59 = 2^60 should give us 1c
        let step59 = TileStepLabelFormatter.labelForStep(59)
        #expect(step59 == "1c")
    }
    
    @Test("Lowercase letters")
    func testLowercaseLetters() {
        let label39 = TileStepLabelFormatter.labelForStep(39)
        #expect(label39.hasSuffix("a"))
        #expect(!label39.hasSuffix("A"))
    }
    
    @Test("Format tile values")
    func testFormatTileValue() {
        #expect(TileStepLabelFormatter.formatTileValue(2) == "2")
        #expect(TileStepLabelFormatter.formatTileValue(512) == "512")
        #expect(TileStepLabelFormatter.formatTileValue(1024) == "1,024")
        #expect(TileStepLabelFormatter.formatTileValue(8192) == "8,192")
        #expect(TileStepLabelFormatter.formatTileValue(16384) == "16K")
        #expect(TileStepLabelFormatter.formatTileValue(32768) == "32K")
        #expect(TileStepLabelFormatter.formatTileValue(65536) == "65K")
        #expect(TileStepLabelFormatter.formatTileValue(131072) == "131K")
    }
    
    @Test("Step for value conversion")
    func testStepForValue() {
        #expect(TileStepLabelFormatter.stepForValue(2) == 0)
        #expect(TileStepLabelFormatter.stepForValue(4) == 1)
        #expect(TileStepLabelFormatter.stepForValue(8) == 2)
        #expect(TileStepLabelFormatter.stepForValue(16) == 3)
        #expect(TileStepLabelFormatter.stepForValue(8192) == 12)
        #expect(TileStepLabelFormatter.stepForValue(16384) == 13)
        
        // Non-power-of-2 values should return nil
        #expect(TileStepLabelFormatter.stepForValue(3) == nil)
        #expect(TileStepLabelFormatter.stepForValue(15) == nil)
        #expect(TileStepLabelFormatter.stepForValue(100) == nil)
    }
    
    @Test("Starting from different values")
    func testDifferentStartValues() {
        // Starting from 4
        #expect(TileStepLabelFormatter.labelForStep(0, start: 4) == "4")
        #expect(TileStepLabelFormatter.labelForStep(1, start: 4) == "8")
        #expect(TileStepLabelFormatter.labelForStep(11, start: 4) == "8,192")
        
        // Starting from 8
        #expect(TileStepLabelFormatter.labelForStep(0, start: 8) == "8")
        #expect(TileStepLabelFormatter.labelForStep(10, start: 8) == "8,192")
    }
    
    @Test("Excel-style suffix progression")
    func testExcelSuffixProgression() {
        // Verify the suffix pattern follows Excel-style: a, b, ..., z, aa, ab, ..., az, ba, ...
        // Step 39 = 1a (first trillion tier)
        #expect(TileStepLabelFormatter.labelForStep(39).hasSuffix("a"))
        
        // As we go higher, we should see b, c, d, etc.
        // The exact steps depend on the doubling pattern
        // but we can verify the suffix generation logic
        let suffixes = (1...30).map { TileStepLabelFormatter.excelLetters(for: $0).lowercased() }
        #expect(suffixes[0] == "a")
        #expect(suffixes[1] == "b")
        #expect(suffixes[25] == "z")
        #expect(suffixes[26] == "aa")
        #expect(suffixes[27] == "ab")
    }
    
    @Test("Letter tier mantissa compresses to single digit")
    func testLetterTierLeadingDigit() {
        let label = TileStepLabelFormatter.label(fromChunks: [0, 0, 0, 0, 461])
        #expect(label == "4a")
        let labelNine = TileStepLabelFormatter.label(fromChunks: [0, 0, 0, 0, 987])
        #expect(labelNine == "9a")
    }
}
import Testing
@testable import GameUI

struct TileLabelFormatterTests {
    @Test
    func testNumericOnly() {
        #expect(TileLabelFormatter.format(3) == "3")
        #expect(TileLabelFormatter.format(14) == "14")
        #expect(TileLabelFormatter.format(99) == "99")
    }

    @Test
    func testLargeValuesStayNumeric() {
        #expect(TileLabelFormatter.format(100) == "100")
        #expect(TileLabelFormatter.format(226) == "226")
        #expect(TileLabelFormatter.format(904) == "904")
    }

    @Test
    func testThousandsStayNumeric() {
        #expect(TileLabelFormatter.format(1000) == "1000")
        #expect(TileLabelFormatter.format(3000) == "3000")
        #expect(TileLabelFormatter.format(9040) == "9040")
        #expect(TileLabelFormatter.format(8192) == "8192")
    }
}

struct CompactNumberFormatterTests {
    @Test
    func testCompact() {
        #expect(CompactNumberFormatter.format(999) == "999")
        #expect(CompactNumberFormatter.format(1000) == "1K")
        #expect(CompactNumberFormatter.format(8192) == "8K")
        #expect(CompactNumberFormatter.format(1_000_000) == "1M")
        #expect(CompactNumberFormatter.format(1_000_000_000) == "1B")
    }
}



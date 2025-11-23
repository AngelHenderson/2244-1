import Testing
import SwiftUI
@testable import GameUI

struct ThemeTests {
    @Test
    @MainActor
    func testColorForValues() {
        let color2 = Theme.color(for: 2)
        let color2048 = Theme.color(for: 2048)
        
        #expect(color2 != color2048)
    }
    
    @Test
    @MainActor
    func testPaletteWrapsFor2048Class() {
        let baseValue = 2048
        let wrappedValue = 1 << 36  // ≈68B, shares exponent % 25 with 2048
        
        #expect(Theme.color(for: baseValue) == Theme.color(for: wrappedValue))
        #expect(Theme.textColor(for: baseValue) == Theme.textColor(for: wrappedValue))
    }
}
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
}
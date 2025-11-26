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
    
    @Test
    @MainActor
    func testJourneyMilestoneOverrides() {
        let expectedColor = Color(hex: "C275FF")
        let journeyValues = [274_000_000_000, 549_000_000_000]
        
        for value in journeyValues {
            #expect(Theme.color(for: value) == expectedColor)
            #expect(Theme.textColor(for: value) == .black)
        }
    }
    
    @Test
    @MainActor
    func testTextColorRepeatsEvery25Steps() {
        for step in 1...25 {
            let baseStepColor = Theme.textColorForStep(step)
            let repeatedStepColor = Theme.textColorForStep(step + 25)
            #expect(baseStepColor == repeatedStepColor)
            
            let baseValue = 1 << step
            let repeatedValue = 1 << (step + 25)
            #expect(Theme.textColor(for: baseValue) == Theme.textColor(for: repeatedValue))
        }
    }
}
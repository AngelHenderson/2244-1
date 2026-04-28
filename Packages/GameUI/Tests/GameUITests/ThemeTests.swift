import Testing
import SwiftUI
import GameCore
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
    func testJourneyMilestonesUsePaletteCycling() {
        let expectations: [(value: Int, color: Color, textColor: Color)] = [
            (274_000_000_000, Color(hex: "FFFFEB"), .black),
            (549_000_000_000, Color(hex: "8849D1"), .white)
        ]
        
        for item in expectations {
            #expect(Theme.color(for: item.value) == item.color)
            #expect(Theme.textColor(for: item.value) == item.textColor)
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
    
    @Test
    @MainActor
    func testJourneyScreenshotTextColors() {
        let expectations: [(value: Int, color: Color)] = [
            (256, .white),
            (512, .black),
            (128, .white),
            (65_536, .black),
            (4_096, .white)
        ]
        
        for item in expectations {
            #expect(Theme.textColor(for: item.value) == item.color)
        }
    }
    
    @Test
    @MainActor
    func testPaletteRepeatsPastTrillions() {
        let lowerExponent = 20  // 1M
        let higherExponent = 45 // ≈35a (1 << 45)
        let lowerValue = 1 << lowerExponent
        let higherValue = 1 << higherExponent
        
        #expect(Theme.color(for: lowerValue) == Theme.color(for: higherValue))
        #expect(Theme.textColor(for: lowerValue) == Theme.textColor(for: higherValue))
    }
    
    @Test
    @MainActor
    func testHighValueStepPaletteRepeats() {
        let baseStep = 70
        let wrappedStep = baseStep - 25
        
        #expect(Theme.colorForStep(baseStep) == Theme.colorForStep(wrappedStep))
        #expect(Theme.textColorForStep(baseStep) == Theme.textColorForStep(wrappedStep))
    }
    
    @Test
    @MainActor
    func testJourneyMilestonesRepeatEvery25Steps() {
        let labels = ["1M", "1B", "1a", "1b", "1c"]
        let cycleLength = 25
        
        for label in labels {
            guard let tier = GameCore.JourneyAbbreviationTiers.tier(forLabel: label),
                  let step = tier.step else {
                Issue.record("No tier found for label \(label)")
                continue
            }
            
            let color = Theme.colorForStep(step)
            let textColor = Theme.textColorForStep(step)
            let referenceColor = Theme.colorForStep(step + cycleLength)
            let referenceTextColor = Theme.textColorForStep(step + cycleLength)
            
            #expect(color == referenceColor)
            #expect(textColor == referenceTextColor)
        }
    }
}

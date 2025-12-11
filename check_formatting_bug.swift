import Foundation

// Mocking the GameCore/GameUI logic to reproduce the issue

// From GameUI/Journey/JourneyTileGenerator.swift
enum JourneyTileGenerator {
    private static let milestoneSteps: [Int] = [
        55,   // 64q
        60,   // 2Q
        65,   // 64Q
        70,   // 2s
    ]
    
    // From GameCore/JourneyTileGenerator.swift (simulated)
    static func formatStepNotation(_ step: Int) -> String {
        // Steps 39+: Use alphabetical notation
        let baseStep = (step - 39) % 10
        let letterIndex = (step - 39) / 10

        let coefficient: String = {
            switch baseStep {
            case 0: return "1"
            case 1: return "2"
            case 2: return "4"
            case 3: return "8"
            case 4: return "16"
            case 5: return "32"
            case 6: return "64"
            case 7: return "128"
            case 8: return "256"
            case 9: return "512"
            default: return "1"
            }
        }()

        let letter: String = {
            if letterIndex < 26 {
                return String(Character(UnicodeScalar(97 + letterIndex)!))
            } else {
                return "∞"
            }
        }()

        return "\(coefficient)\(letter)"
    }
    
    static func check() {
        print("Checking steps around 62 (8c)...")
        for step in 55...70 {
            let label = formatStepNotation(step)
            print("Step \(step): \(label)")
        }
    }
}

JourneyTileGenerator.check()

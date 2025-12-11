import Foundation

// Mocking GameCore/JourneyTileGenerator logic
struct GameCoreGenerator {
    static func formatTileAtStep(_ step: Int) -> String {
        if step < 0 { return "∞" }

        let exponent = step + 1

        if exponent <= 62 {
            // Small exponents (not relevant for 8c)
            return "SMALL"
        }

        // 2^exponent = mantissa * 10^power
        let powerOf10 = Double(exponent) * log10(2.0)
        let intPower = Int(floor(powerOf10))
        let mantissa = pow(10.0, powerOf10 - Double(intPower))
        
        // For powers >= 12
        let suffixOrdinal = (intPower - 12) / 3 + 1
        
        // Mock AlphaMag.suffix
        let suffix: String
        if suffixOrdinal == 1 { suffix = "a" }
        else if suffixOrdinal == 2 { suffix = "b" }
        else if suffixOrdinal == 3 { suffix = "c" }
        else if suffixOrdinal == 4 { suffix = "d" }
        else { suffix = "?" }
        
        // Adjust mantissa
        let tierBase = 12 + (suffixOrdinal - 1) * 3
        let adjustedMantissa = mantissa * pow(10.0, Double(intPower - tierBase))
        
        return "\(Int(adjustedMantissa))\(suffix)"
    }
}

print("Checking GameCore logic:")
for step in 60...70 {
    let label = GameCoreGenerator.formatTileAtStep(step)
    print("Step \(step): \(label)")
}

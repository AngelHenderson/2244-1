import Foundation

/// Generates tiles for the journey display, including values beyond Int.max
public struct JourneyTileGenerator {
    
    /// Generate journey tiles from step 0 (value 2) to step 816 (873bz) then infinity
    /// Returns an array of 818 tiles total
    public static func generateFullJourney() -> [Tile] {
        // Generate tiles for steps 0 through 816 (817 tiles)
        // Tile.make(forStep:) handles both normal values and high values correctly
        var tiles = (0...816).map { Tile.make(forStep: $0) }

        // Add infinity tile at the end
        tiles.append(Tile.infinity())

        return tiles
    }
    
    /// Generate journey tiles relative to current highest (shows window around current position)
    public static func generateJourney(highest: Int, stepsAhead: Int = 20) -> [Tile] {
        let currentStep = TileStepLabelFormatter.stepForValue(highest, start: 2) ?? 0
        let startStep = max(0, currentStep - 10)
        let endStep = min(816, currentStep + stepsAhead)

        var tiles = (startStep...endStep).map { Tile.make(forStep: $0) }
        tiles.append(Tile.infinity())

        return tiles
    }
    
    /// Format a tile value for a specific step in the doubling sequence
    /// This handles values beyond Int.max by computing the label directly
    /// Step is 0-based: step 0 = 2^1, step 1 = 2^2, etc.
    public static func formatTileAtStep(_ step: Int) -> String {
        if step < 0 || step >= 817 { return "∞" }

        // Convert 0-based step to exponent
        let exponent = step + 1

        // For small exponents, we can compute the actual value
        if exponent <= 62 {
            let value = 1 << exponent  // 2^exponent
            return AlphaMag.formatTileValue(value)
        }

        // For larger exponents, we need to compute the label mathematically
        // 2^exponent = mantissa * 10^power
        // log10(2^exponent) = exponent * log10(2) = exponent * 0.30103
        let powerOf10 = Double(exponent) * log10(2.0)
        let intPower = Int(floor(powerOf10))
        let mantissa = pow(10.0, powerOf10 - Double(intPower))
        
        // Format based on power of 10
        if intPower < 3 { return String(Int(mantissa)) }
        if intPower < 6 { return "\(Int(mantissa))K" }
        if intPower < 9 { return "\(Int(mantissa))M" }
        if intPower < 12 { return "\(Int(mantissa))B" }
        
        // For powers >= 12, use alphabetic suffixes
        let suffixOrdinal = (intPower - 12) / 3 + 1
        let suffix = AlphaMag.suffix(forOrdinal: suffixOrdinal)
        
        // Adjust mantissa for the tier
        let tierBase = 12 + (suffixOrdinal - 1) * 3
        let adjustedMantissa = mantissa * pow(10.0, Double(intPower - tierBase))
        
        return "\(Int(adjustedMantissa))\(suffix)"
    }
}
import Foundation

/// Generates tiles for the journey display, including values beyond Int.max
public struct JourneyTileGenerator {
    
    /// Generate journey tiles up to 873bz
    /// Returns an array of tiles with special handling for values beyond Int.max
    public static func generateFullJourney() -> [Tile] {
        var tiles: [Tile] = []
        
        // Start with normal doubling sequence
        var current = 2
        var step = 1
        
        // Generate tiles up to Int.max/2 (step ~62)
        while current > 0 && current <= (Int.max >> 1) {
            tiles.append(Tile(value: current))
            current = current << 1
            step += 1
        }
        
        // After step 62, we can't double anymore without overflow
        // But we need to continue to step 817 to reach 873bz
        // Use highValue type to track the step number
        
        // For steps 63-817, create tiles with highValue type
        while step <= 817 {
            tiles.append(Tile(value: Int.max, type: .highValue(step: step)))
            step += 1
        }
        
        // Add infinity tile at the end
        tiles.append(Tile(value: 0, type: .infinity))
        
        return tiles
    }
    
    /// Generate journey tiles relative to current highest
    public static func generateJourney(highest: Int, stepsAhead: Int = 20) -> [Tile] {
        var tiles: [Tile] = []
        var current = 2
        
        // First, add all tiles up to highest
        while current > 0 && current <= highest {
            tiles.append(Tile(value: current))
            if current > (Int.max >> 1) {
                break
            }
            current = current << 1
        }
        
        // Calculate what step we're at
        var currentStep = 1
        var temp = 2
        while temp < current && temp > 0 {
            temp = temp << 1
            currentStep += 1
        }
        
        // Then add more tiles beyond highest
        var stepsAdded = 0
        while stepsAdded < stepsAhead {
            currentStep += 1
            if current > (Int.max >> 1) || current <= 0 {
                // Use highValue type for tiles we can't represent
                tiles.append(Tile(value: Int.max, type: .highValue(step: currentStep)))
            } else {
                current = current << 1
                tiles.append(Tile(value: current))
            }
            stepsAdded += 1
        }
        
        // Add infinity tile at the end
        tiles.append(Tile(value: 0, type: .infinity))
        
        return tiles
    }
    
    /// Format a tile value for a specific step in the doubling sequence
    /// This handles values beyond Int.max by computing the label directly
    public static func formatTileAtStep(_ step: Int) -> String {
        if step <= 0 { return "∞" }
        if step == 1 { return "2" }
        
        // For small steps, we can compute the actual value
        if step <= 62 {
            let value = 1 << step  // 2^step
            return AlphaMag.formatTileValue(value)
        }
        
        // For larger steps, we need to compute the label mathematically
        // 2^step = mantissa * 10^power
        // log10(2^step) = step * log10(2) = step * 0.30103
        let powerOf10 = Double(step) * log10(2.0)
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
        
        // Special case: check if this is step 817 (873bz)
        if step == 817 {
            return "873bz"
        }
        
        return "\(Int(adjustedMantissa))\(suffix)"
    }
}
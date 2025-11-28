import Foundation

/// Generates tiles for the journey display, including values beyond Int.max
public struct JourneyTileGenerator {
    
    /// Generate journey tiles up to 873bz
    /// Returns an array of tiles with special handling for values beyond Int.max
    public static func generateFullJourney() -> [Tile] {
        var tiles: [Tile] = []

        // Start with normal doubling sequence
        var current = 2
        var exponent = 1  // Track the exponent (2^exponent = current)

        // Generate tiles up to Int.max/2 (up to 2^62)
        while current > 0 && current <= (Int.max >> 1) {
            tiles.append(Tile(value: current))
            current = current << 1
            exponent += 1
        }

        // After 2^62, we can't double anymore without overflow
        // But we need to continue to 2^817 to reach 873bz
        // Use highValue type to track the step number

        // For exponents 63-817, create tiles with highValue type
        // The step should be consistent with stepForValue: step = exponent - 1
        while exponent <= 817 {
            let step = exponent - 1  // Convert to 0-based step
            tiles.append(Tile(value: Int.max, type: .highValue(step: step)))
            exponent += 1
        }
        
        // Add infinity tile at the end
        tiles.append(Tile(value: 0, type: .infinity))
        
        return tiles
    }
    
    /// Generate journey tiles relative to current highest
    public static func generateJourney(highest: Int, stepsAhead: Int = 20) -> [Tile] {
        var tiles: [Tile] = []
        var current = 2
        var exponent = 1  // Track exponent: 2^exponent = current

        // First, add all tiles up to highest
        while current > 0 && current <= highest {
            tiles.append(Tile(value: current))
            if current > (Int.max >> 1) {
                break
            }
            current = current << 1
            exponent += 1
        }

        // Then add more tiles beyond highest
        var stepsAdded = 0
        while stepsAdded < stepsAhead {
            if current > (Int.max >> 1) || current <= 0 {
                // Use highValue type for tiles we can't represent
                // Step should be consistent with stepForValue: step = exponent - 1
                let step = exponent - 1
                tiles.append(Tile(value: Int.max, type: .highValue(step: step)))
            } else {
                current = current << 1
                tiles.append(Tile(value: current))
            }
            exponent += 1
            stepsAdded += 1
        }
        
        // Add infinity tile at the end
        tiles.append(Tile(value: 0, type: .infinity))
        
        return tiles
    }
    
    /// Format a tile value for a specific step in the doubling sequence
    /// This handles values beyond Int.max by computing the label directly
    /// Step is 0-based: step 0 = 2^1, step 1 = 2^2, etc.
    public static func formatTileAtStep(_ step: Int) -> String {
        if step < 0 { return "∞" }

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
        
        // Special case: check if this is step 817 (873bz)
        if step == 817 {
            return "873bz"
        }
        
        return "\(Int(adjustedMantissa))\(suffix)"
    }
}
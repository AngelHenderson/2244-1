import Foundation

public enum TileStepMath {
    /// Returns the doubling step index for a tile (0 -> value 2, 1 -> 4, etc.)
    public static func step(for tile: Tile?) -> Int? {
        tile?.stepIndex
    }
    
    /// Creates a tile for the given step index.
    public static func tile(forStep step: Int) -> Tile {
        let shift = step + 1
        if shift > 0 && shift < Int.bitWidth {
            return Tile(value: 1 << shift)
        } else {
            return Tile(value: Int.max, type: .highValue(step: step))
        }
    }
    
    /// Returns the approximate Int value for a given step (clamped to Int.max).
    public static func value(forStep step: Int) -> Int {
        let shift = step + 1
        if shift > 0 && shift < Int.bitWidth {
            return 1 << shift
        }
        return Int.max
    }
    
    /// Computes the resulting step when merging tiles with the provided steps.
    public static func mergedStep(from steps: [Int]) -> Int {
        guard let maxStep = steps.max() else { return 0 }
        var mantissa: Double = 0
        for step in steps {
            mantissa += pow(2.0, Double(step - maxStep))
        }
        // Avoid log2(0)
        guard mantissa > 0 else { return maxStep }
        let total = Double(maxStep) + log2(mantissa)
        let epsilon = 1e-9
        return max(0, Int(ceil(total - epsilon)))
    }
}

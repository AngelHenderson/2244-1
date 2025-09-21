import Foundation

// Elimination rules for 2244 game.
// When a tile reaches the key value (left), it triggers elimination of the specified value (right).
// Rules continue infinitely following the established pattern.
public enum EliminationRules {
    
    /// Get the elimination value for a given milestone
    /// Returns nil if the value is not a valid elimination milestone
    public static func eliminationValue(for milestone: Int) -> Int? {
        // Check if it's a power of 2
        guard milestone > 0 && (milestone & (milestone - 1)) == 0 else { return nil }
        
        let log2Value = Int(log2(Double(milestone)))
        
        // For milestones up to 16M (2^24), use 13th block down
        if log2Value <= 24 {
            let power = log2Value - 10  // 13th down means 12 steps down, so power = log2 - 10
            return 1 << power  // 2^power using bit shift
        }
        // For milestones 67M and above (2^26+), use 14th block down
        else {
            let power = log2Value - 11  // 14th down means 13 steps down, so power = log2 - 11
            return 1 << power  // 2^power using bit shift
        }
    }
    
    /// Check if a tile value should trigger elimination
    public static func shouldEliminate(_ value: Int) -> Bool {
        return eliminationValue(for: value) != nil
    }
    
    /// Get all elimination milestones up to a given value
    public static func milestonesUpTo(_ maxValue: Int) -> [(value: Int, eliminationValue: Int)] {
        var milestones: [(value: Int, eliminationValue: Int)] = []
        
        // Generate milestones up to the max value
        var current = 2
        while current <= maxValue {
            if let eliminationValue = eliminationValue(for: current) {
                milestones.append((value: current, eliminationValue: eliminationValue))
            }
            current = current << 1  // Next power of 2
        }
        
        return milestones
    }
    
    /// Get the next elimination milestone after a given value
    public static func nextMilestone(after value: Int) -> (value: Int, eliminationValue: Int)? {
        var current = value
        while current < Int.max {
            current = current << 1  // Next power of 2
            if let eliminationValue = eliminationValue(for: current) {
                return (value: current, eliminationValue: eliminationValue)
            }
        }
        return nil
    }
    
    /// Legacy map for backward compatibility (only includes first few milestones)
    public static let map: [Int: Int] = [
        2_048: 2,
        4_096: 4,
        16_384: 8,      // 16K
        32_768: 16,     // 32K
        65_536: 32,     // 65K
        262_144: 64,    // 262K
        524_288: 128,   // 524K
        1_048_576: 256, // 1M
        4_194_304: 512, // 4M
        8_388_608: 1_024, // 8M
        16_777_216: 2_048, // 16M
        67_108_864: 4_096,     // 67M -> 4096s removed (14th down)
        134_217_728: 8_192,    // 134M -> 8192s removed (14th down)
        268_435_456: 16_384,   // 268M -> 16K removed (14th down)
        536_870_912: 32_768,   // 536M -> 32K removed (14th down)
        1_073_741_824: 65_536  // 1B -> 65K removed (14th down)
    ]
}
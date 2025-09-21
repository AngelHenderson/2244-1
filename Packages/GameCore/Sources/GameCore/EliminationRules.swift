// Time-based elimination rules for 2244 game.
// When a tile reaches the key value (left), it gets removed for the specified duration in seconds (right).
// Rules continue infinitely following the established pattern.
public enum EliminationRules {
    
    /// Get the elimination duration for a given tile value
    /// Returns nil if the value is not a valid elimination milestone
    public static func durationForValue(_ value: Int) -> Int? {
        // New elimination pattern as specified:
        // 2048 -> 2s removed
        // 4096 -> 4s removed
        // 16K -> 8s removed
        // 32K -> 16s removed
        // 65K -> 32s removed
        // 262K -> 64s removed
        // 524K -> 128s removed
        // 1M -> 256s removed
        // 4M -> 512s removed
        // 8M -> 1024s removed
        // 16M -> 2048s removed
        switch value {
        case 2_048: return 2
        case 4_096: return 4
        case 16_384: return 8      // 16K
        case 32_768: return 16     // 32K
        case 65_536: return 32     // 65K
        case 262_144: return 64    // 262K
        case 524_288: return 128   // 524K
        case 1_048_576: return 256 // 1M
        case 4_194_304: return 512 // 4M
        case 8_388_608: return 1_024 // 8M
        case 16_777_216: return 2_048 // 16M
        default: return nil
        }
    }
    
    /// Check if a tile value should be eliminated
    public static func shouldEliminate(_ value: Int) -> Bool {
        return durationForValue(value) != nil
    }
    
    /// All elimination milestones in order
    private static let allMilestones: [(value: Int, duration: Int)] = [
        (2_048, 2),
        (4_096, 4),
        (16_384, 8),      // 16K
        (32_768, 16),     // 32K
        (65_536, 32),     // 65K
        (262_144, 64),    // 262K
        (524_288, 128),   // 524K
        (1_048_576, 256), // 1M
        (4_194_304, 512), // 4M
        (8_388_608, 1_024), // 8M
        (16_777_216, 2_048) // 16M
    ]
    
    /// Get all elimination milestones up to a given value
    public static func milestonesUpTo(_ maxValue: Int) -> [(value: Int, duration: Int)] {
        return allMilestones.filter { $0.value <= maxValue }
    }
    
    /// Get the next elimination milestone after a given value
    public static func nextMilestone(after value: Int) -> (value: Int, duration: Int)? {
        return allMilestones.first { $0.value > value }
    }
}

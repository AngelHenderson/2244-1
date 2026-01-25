import Foundation

/// Reward given when breaking a gift (glass) on the board
public struct GiftReward: Codable, Sendable, Equatable {
    public let type: GiftRewardType
    public let value: Int

    public init(type: GiftRewardType, value: Int) {
        self.type = type
        self.value = value
    }
}

/// Types of rewards that can be obtained from breaking gifts
public enum GiftRewardType: String, Codable, Sendable, Equatable {
    case gems
    case powerUp
    case spin
    case scoreBoost

    public func displayName(value: Int, powerUpType: PowerUpType? = nil) -> String {
        switch self {
        case .gems:
            return "\(value) Gems"
        case .powerUp:
            if let powerUp = powerUpType {
                return "\(value) \(powerUp.rawValue.capitalized)"
            }
            return "\(value) Power-Up"
        case .spin:
            return "\(value) Spin\(value > 1 ? "s" : "")"
        case .scoreBoost:
            return "\(value)X Boost"
        }
    }
}

/// Manages gift rewards for each column
public struct GiftRewardManager {
    /// Get ALL rewards for a specific column (0-indexed)
    /// Breaking a gift awards ALL rewards in the column
    public static func allRewards(forColumn col: Int) -> [(type: GiftRewardType, value: Int, powerUpType: PowerUpType?)] {
        switch col {
        case 0:
            // Column 1: 50 Gems AND 2 Swaps
            return [
                (.gems, 50, nil),
                (.powerUp, 2, .swap)
            ]
        case 1:
            // Column 2: 1 Hammer AND 1 Swap AND 1 MegaMerge (Magnet)
            return [
                (.powerUp, 1, .hammer),
                (.powerUp, 1, .swap),
                (.powerUp, 1, .magnet)
            ]
        case 2:
            // Column 3: 2X Boost AND 3X Boost AND 4X Boost
            return [
                (.scoreBoost, 2, nil),
                (.scoreBoost, 3, nil),
                (.scoreBoost, 4, nil)
            ]
        case 3:
            // Column 4: 45 Gems AND 1 Hammer AND 1 Spin AND 3X Boost
            return [
                (.gems, 45, nil),
                (.powerUp, 1, .hammer),
                (.spin, 1, nil),
                (.scoreBoost, 3, nil)
            ]
        case 4:
            // Column 5: 1 MegaMerge (Magnet) AND 1 Spin AND 2X Boost
            return [
                (.powerUp, 1, .magnet),
                (.spin, 1, nil),
                (.scoreBoost, 2, nil)
            ]
        default:
            // Default fallback: 1 gem
            return [(.gems, 1, nil)]
        }
    }
}

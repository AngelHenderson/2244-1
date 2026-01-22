import Foundation

// MARK: - Gift Reward System

public struct GiftReward: Codable, Sendable {
    public let message: String
    public let items: [GiftRewardItem]
    public let isFromGlassShatter: Bool

    public init(message: String, items: [GiftRewardItem], isFromGlassShatter: Bool = false) {
        self.message = message
        self.items = items
        self.isFromGlassShatter = isFromGlassShatter
    }

    public static func randomReward(isFromGlassShatter: Bool = false) -> GiftReward {
        let rewards = [
            GiftReward(
                message: "A helpful hammer appeared!",
                items: [GiftRewardItem(type: .hammer, amount: 1)],
                isFromGlassShatter: isFromGlassShatter
            ),
            GiftReward(
                message: "Some magical gems appeared!",
                items: [GiftRewardItem(type: .gems, amount: 5)],
                isFromGlassShatter: isFromGlassShatter
            ),
            GiftReward(
                message: "A powerful magnet appeared!",
                items: [GiftRewardItem(type: .magnet, amount: 1)],
                isFromGlassShatter: isFromGlassShatter
            ),
            GiftReward(
                message: "Multiple goodies appeared!",
                items: [
                    GiftRewardItem(type: .gems, amount: 3),
                    GiftRewardItem(type: .hammer, amount: 1)
                ],
                isFromGlassShatter: isFromGlassShatter
            )
        ]
        return rewards.randomElement() ?? rewards[0]
    }

    /// Get reward for a specific column (0-indexed)
    /// Column 1: 50 Gems + 2 Swaps
    /// Column 2: 1 Hammer + 1 Swap + 1 MegaMerge
    /// Column 3: 2X + 3X + 4X Boost
    /// Column 4: 45 Gems + 1 Hammer + 1 Spin + 3X Boost
    /// Column 5: 1 MegaMerge + 1 Spin + 2X Boost
    public static func rewardForColumn(_ col: Int, isFromGlassShatter: Bool = true) -> GiftReward {
        switch col {
        case 0:
            return GiftReward(
                message: "Glass shattered! Gems and Swaps!",
                items: [
                    GiftRewardItem(type: .gems, amount: 50),
                    GiftRewardItem(type: .swap, amount: 2)
                ],
                isFromGlassShatter: isFromGlassShatter
            )
        case 1:
            return GiftReward(
                message: "Glass shattered! Power-ups galore!",
                items: [
                    GiftRewardItem(type: .hammer, amount: 1),
                    GiftRewardItem(type: .swap, amount: 1),
                    GiftRewardItem(type: .magnet, amount: 1)
                ],
                isFromGlassShatter: isFromGlassShatter
            )
        case 2:
            return GiftReward(
                message: "Glass shattered! Score Boost Bonanza!",
                items: [
                    GiftRewardItem(type: .boost2x, amount: 1),
                    GiftRewardItem(type: .boost3x, amount: 1),
                    GiftRewardItem(type: .boost4x, amount: 1)
                ],
                isFromGlassShatter: isFromGlassShatter
            )
        case 3:
            return GiftReward(
                message: "Glass shattered! Jackpot!",
                items: [
                    GiftRewardItem(type: .gems, amount: 45),
                    GiftRewardItem(type: .hammer, amount: 1),
                    GiftRewardItem(type: .bonusSpin, amount: 1),
                    GiftRewardItem(type: .boost3x, amount: 1)
                ],
                isFromGlassShatter: isFromGlassShatter
            )
        case 4:
            return GiftReward(
                message: "Glass shattered! Great rewards!",
                items: [
                    GiftRewardItem(type: .magnet, amount: 1),
                    GiftRewardItem(type: .bonusSpin, amount: 1),
                    GiftRewardItem(type: .boost2x, amount: 1)
                ],
                isFromGlassShatter: isFromGlassShatter
            )
        default:
            return GiftReward(
                message: "Glass shattered!",
                items: [GiftRewardItem(type: .gems, amount: 1)],
                isFromGlassShatter: isFromGlassShatter
            )
        }
    }
}

public struct GiftRewardItem: Codable, Hashable, Sendable {
    public enum GiftType: String, Codable, Sendable {
        case hammer
        case magnet
        case gems
        case swap
        case undo
        case bonusSpin
        case boost2x
        case boost3x
        case boost4x
    }

    public let type: GiftType
    public let amount: Int

    public init(type: GiftType, amount: Int) {
        self.type = type
        self.amount = amount
    }
}
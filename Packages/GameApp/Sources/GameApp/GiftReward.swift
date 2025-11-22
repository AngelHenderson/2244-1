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
}

public struct GiftRewardItem: Codable, Sendable {
    public enum GiftType: String, Codable, Sendable {
        case hammer, magnet, gems, swap, undo
    }

    public let type: GiftType
    public let amount: Int

    public init(type: GiftType, amount: Int) {
        self.type = type
        self.amount = amount
    }
}
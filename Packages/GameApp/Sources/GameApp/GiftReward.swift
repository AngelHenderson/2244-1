import Foundation

// MARK: - Gift Reward System

public struct GiftReward: Sendable {
    public let message: String
    public let items: [GiftRewardItem]

    public init(message: String, items: [GiftRewardItem]) {
        self.message = message
        self.items = items
    }

    public static func randomReward() -> GiftReward {
        let rewards = [
            GiftReward(
                message: "A helpful hammer appeared!",
                items: [GiftRewardItem(type: .hammer, amount: 1)]
            ),
            GiftReward(
                message: "Some magical gems appeared!",
                items: [GiftRewardItem(type: .gems, amount: 5)]
            ),
            GiftReward(
                message: "A powerful magnet appeared!",
                items: [GiftRewardItem(type: .magnet, amount: 1)]
            ),
            GiftReward(
                message: "Multiple goodies appeared!",
                items: [
                    GiftRewardItem(type: .gems, amount: 3),
                    GiftRewardItem(type: .hammer, amount: 1)
                ]
            )
        ]
        return rewards.randomElement() ?? rewards[0]
    }
}

public struct GiftRewardItem: Sendable {
    public enum GiftType: Sendable {
        case hammer, magnet, gems, swap, undo
    }

    public let type: GiftType
    public let amount: Int

    public init(type: GiftType, amount: Int) {
        self.type = type
        self.amount = amount
    }
}
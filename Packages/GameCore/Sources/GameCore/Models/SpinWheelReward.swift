import Foundation

public struct SpinWheelReward: Identifiable, Codable, Sendable {
    public let id: UUID
    public let type: RewardType
    public let value: Int
    public let weight: Int
    public let displayName: String
    public let displayColor: String
    public let powerUpType: PowerUpType?

    public init(
        id: UUID = UUID(),
        type: RewardType,
        value: Int,
        weight: Int,
        displayName: String? = nil,
        displayColor: String = "#FFD700",
        powerUpType: PowerUpType? = nil
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.weight = weight
        self.displayName = displayName ?? type.defaultDisplayName(value: value)
        self.displayColor = displayColor
        self.powerUpType = powerUpType
    }

    public static let defaultRewards: [SpinWheelReward] = [
        SpinWheelReward(type: .coins, value: 10, weight: 30, displayColor: "#FFD700"),
        SpinWheelReward(type: .coins, value: 25, weight: 20, displayColor: "#FFD700"),
        SpinWheelReward(type: .coins, value: 50, weight: 10, displayColor: "#FFD700"),
        SpinWheelReward(type: .coins, value: 100, weight: 5, displayColor: "#FFD700"),
        SpinWheelReward(type: .powerUp, value: 1, weight: 15, displayColor: "#FF6B6B", powerUpType: .hammer),
        SpinWheelReward(type: .powerUp, value: 1, weight: 10, displayColor: "#4ECDC4", powerUpType: .swap),
        SpinWheelReward(type: .powerUp, value: 2, weight: 5, displayColor: "#95E77E", powerUpType: .undo),
        SpinWheelReward(type: .experience, value: 50, weight: 5, displayColor: "#845EC2")
    ]

    public var probability: Double {
        let totalWeight = Self.defaultRewards.reduce(0) { $0 + $1.weight }
        return Double(weight) / Double(totalWeight)
    }
}

public enum RewardType: String, CaseIterable, Codable, Sendable {
    case coins
    case powerUp
    case experience
    case theme
    case trophy

    func defaultDisplayName(value: Int) -> String {
        switch self {
        case .coins:
            return "\(value) Coins"
        case .powerUp:
            return "\(value) Power-Up"
        case .experience:
            return "\(value) XP"
        case .theme:
            return "Theme Unlock"
        case .trophy:
            return "Trophy"
        }
    }
}

public struct SpinWheelSession: Codable, Sendable {
    public let sessionId: UUID
    public let timestamp: Date
    public let reward: SpinWheelReward
    public let freeSpinUsed: Bool

    public init(
        sessionId: UUID = UUID(),
        timestamp: Date = Date(),
        reward: SpinWheelReward,
        freeSpinUsed: Bool = false
    ) {
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.reward = reward
        self.freeSpinUsed = freeSpinUsed
    }
}

public struct SpinWheelManager {
    private static let freeSpinCooldown: TimeInterval = 14400

    public static func canClaimFreeSpin(lastFreeSpinDate: Date?) -> Bool {
        guard let lastDate = lastFreeSpinDate else { return true }
        return Date().timeIntervalSince(lastDate) >= freeSpinCooldown
    }

    public static func nextFreeSpinDate(from lastDate: Date) -> Date {
        return lastDate.addingTimeInterval(freeSpinCooldown)
    }

    public static func spin(with seed: UInt64? = nil) -> SpinWheelReward {
        var rng = DeterministicRNG(seed: seed ?? UInt64.random(in: 0...UInt64.max))
        let totalWeight = defaultRewards.reduce(0) { $0 + $1.weight }
        let randomValue = Int(rng.nextDouble() * Double(totalWeight))

        var cumulativeWeight = 0
        for reward in defaultRewards {
            cumulativeWeight += reward.weight
            if randomValue < cumulativeWeight {
                return reward
            }
        }

        return defaultRewards.first!
    }

    public static var defaultRewards: [SpinWheelReward] {
        return SpinWheelReward.defaultRewards
    }
}
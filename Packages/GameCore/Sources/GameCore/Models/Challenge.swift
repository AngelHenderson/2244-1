import Foundation

public struct Challenge: Identifiable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String
    public let mode: ChallengeMode
    public let difficulty: ChallengeDifficulty
    public let targetScore: Int?
    public let targetTile: Int?
    public let timeLimit: TimeInterval?
    public let moveLimit: Int?
    public let bannedPowerUps: Set<PowerUpType>
    public let reward: ChallengeReward
    public let createdAt: Date
    public let createdBy: String?
    public let seed: UInt64?
    public let maxSpawnTile: Int?
    public let minSpawnTile: Int?

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        mode: ChallengeMode = .custom,
        difficulty: ChallengeDifficulty = .medium,
        targetScore: Int? = nil,
        targetTile: Int? = nil,
        timeLimit: TimeInterval? = nil,
        moveLimit: Int? = nil,
        bannedPowerUps: Set<PowerUpType> = [],
        reward: ChallengeReward? = nil,
        createdAt: Date = Date(),
        createdBy: String? = nil,
        seed: UInt64? = nil,
        maxSpawnTile: Int? = nil,
        minSpawnTile: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.mode = mode
        self.difficulty = difficulty
        self.targetScore = targetScore
        self.targetTile = targetTile
        self.timeLimit = timeLimit
        self.moveLimit = moveLimit
        self.bannedPowerUps = bannedPowerUps
        self.reward = reward ?? ChallengeReward.default(for: difficulty)
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.seed = seed
        self.maxSpawnTile = maxSpawnTile
        self.minSpawnTile = minSpawnTile
    }
}

public enum ChallengeMode: String, CaseIterable, Codable, Sendable {
    case daily
    case weekly
    case monthly
    case custom
    case community
}

public enum ChallengeDifficulty: String, CaseIterable, Codable, Sendable {
    case easy
    case medium
    case hard
    case expert
}

public struct ChallengeReward: Codable, Sendable {
    public let coins: Int
    public let experience: Int
    public let powerUps: [PowerUpType: Int]
    public let trophyType: TrophyType?

    public init(coins: Int, experience: Int, powerUps: [PowerUpType: Int] = [:], trophyType: TrophyType? = nil) {
        self.coins = coins
        self.experience = experience
        self.powerUps = powerUps
        self.trophyType = trophyType
    }

    public static func `default`(for difficulty: ChallengeDifficulty) -> ChallengeReward {
        switch difficulty {
        case .easy:
            return ChallengeReward(coins: 25, experience: 50, powerUps: [:], trophyType: .bronze)
        case .medium:
            return ChallengeReward(coins: 50, experience: 100, powerUps: [.hammer: 1], trophyType: .silver)
        case .hard:
            return ChallengeReward(coins: 100, experience: 200, powerUps: [.hammer: 2, .swap: 1], trophyType: .gold)
        case .expert:
            return ChallengeReward(coins: 250, experience: 500, powerUps: [.hammer: 3, .swap: 2, .undo: 3], trophyType: .platinum)
        }
    }
}

public enum TrophyType: String, CaseIterable, Codable, Sendable {
    case bronze
    case silver
    case gold
    case platinum
    case diamond
}
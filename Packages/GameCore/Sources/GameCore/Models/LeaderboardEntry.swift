import Foundation

public struct LeaderboardEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let playerId: String
    public let playerName: String
    public let score: Int
    public let rank: Int
    public let timestamp: Date
    public let gameMode: GameMode
    public let metadata: LeaderboardMetadata

    public init(
        id: UUID = UUID(),
        playerId: String,
        playerName: String,
        score: Int,
        rank: Int = 0,
        timestamp: Date = Date(),
        gameMode: GameMode = .classic,
        metadata: LeaderboardMetadata = LeaderboardMetadata()
    ) {
        self.id = id
        self.playerId = playerId
        self.playerName = playerName
        self.score = score
        self.rank = rank
        self.timestamp = timestamp
        self.gameMode = gameMode
        self.metadata = metadata
    }

    public var formattedScore: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: score)) ?? "\(score)"
    }

    public var formattedRank: String {
        let suffix: String
        switch rank {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
        return "\(rank)\(suffix)"
    }

    public var isTopThree: Bool {
        return rank >= 1 && rank <= 3
    }

    public var isTopTen: Bool {
        return rank >= 1 && rank <= 10
    }

    public var isTopHundred: Bool {
        return rank >= 1 && rank <= 100
    }
}

public struct LeaderboardMetadata: Codable, Sendable {
    public let highestTile: Int?
    public let longestChain: Int?
    public let totalMerges: Int?
    public let gameTime: TimeInterval?
    public let movesCount: Int?
    public let powerUpsUsed: Int?
    public let countryCode: String?

    public init(
        highestTile: Int? = nil,
        longestChain: Int? = nil,
        totalMerges: Int? = nil,
        gameTime: TimeInterval? = nil,
        movesCount: Int? = nil,
        powerUpsUsed: Int? = nil,
        countryCode: String? = nil
    ) {
        self.highestTile = highestTile
        self.longestChain = longestChain
        self.totalMerges = totalMerges
        self.gameTime = gameTime
        self.movesCount = movesCount
        self.powerUpsUsed = powerUpsUsed
        self.countryCode = countryCode
    }
}

public enum LeaderboardPeriod: String, CaseIterable, Codable, Sendable {
    case daily
    case weekly
    case monthly
    case allTime

    public var displayName: String {
        switch self {
        case .daily:
            return "Today"
        case .weekly:
            return "This Week"
        case .monthly:
            return "This Month"
        case .allTime:
            return "All Time"
        }
    }

    public var startDate: Date {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .daily:
            return calendar.startOfDay(for: now)
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        case .monthly:
            return calendar.dateInterval(of: .month, for: now)?.start ?? now
        case .allTime:
            return Date(timeIntervalSince1970: 0)
        }
    }
}

public struct Leaderboard: Codable, Sendable {
    public let period: LeaderboardPeriod
    public let gameMode: GameMode
    public let entries: [LeaderboardEntry]
    public let lastUpdated: Date
    public let totalPlayers: Int

    public init(
        period: LeaderboardPeriod,
        gameMode: GameMode,
        entries: [LeaderboardEntry],
        lastUpdated: Date = Date(),
        totalPlayers: Int? = nil
    ) {
        self.period = period
        self.gameMode = gameMode
        self.entries = entries
        self.lastUpdated = lastUpdated
        self.totalPlayers = totalPlayers ?? entries.count
    }

    public var topEntry: LeaderboardEntry? {
        return entries.first { $0.rank == 1 }
    }

    public var topThree: [LeaderboardEntry] {
        return Array(entries.filter { $0.isTopThree }.prefix(3))
    }

    public func entry(for playerId: String) -> LeaderboardEntry? {
        return entries.first { $0.playerId == playerId }
    }

    public func percentileRank(for score: Int) -> Double {
        let lowerScores = entries.filter { $0.score < score }.count
        return Double(lowerScores) / Double(totalPlayers) * 100
    }
}

public struct LeaderboardReward: Codable, Sendable {
    public let position: Int
    public let coins: Int
    public let experience: Int
    public let powerUps: [PowerUpType: Int]
    public let trophyType: TrophyType?

    public static func rewards(for position: Int) -> LeaderboardReward {
        switch position {
        case 1:
            return LeaderboardReward(position: 1, coins: 1000, experience: 500,
                                    powerUps: [.hammer: 10, .swap: 5, .undo: 10],
                                    trophyType: .platinum)
        case 2:
            return LeaderboardReward(position: 2, coins: 500, experience: 250,
                                    powerUps: [.hammer: 5, .swap: 3, .undo: 5],
                                    trophyType: .gold)
        case 3:
            return LeaderboardReward(position: 3, coins: 250, experience: 150,
                                    powerUps: [.hammer: 3, .swap: 2, .undo: 3],
                                    trophyType: .silver)
        case 4...10:
            return LeaderboardReward(position: position, coins: 100, experience: 75,
                                    powerUps: [.hammer: 1, .swap: 1],
                                    trophyType: .bronze)
        case 11...100:
            return LeaderboardReward(position: position, coins: 25, experience: 25,
                                    powerUps: [:],
                                    trophyType: nil)
        default:
            return LeaderboardReward(position: position, coins: 0, experience: 10,
                                    powerUps: [:],
                                    trophyType: nil)
        }
    }
}
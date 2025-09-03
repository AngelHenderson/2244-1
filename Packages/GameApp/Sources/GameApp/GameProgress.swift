import Foundation

/// Canonical, versioned progress that both local and remote stores persist.
public struct GameProgress: Codable, Equatable, Sendable {
    public static let schemaVersion = 2

    public var version: Int = schemaVersion
    public var highestTile: Int
    public var bestScore: Int
    public var gems: Int
    public var gamesPlayed: Int
    public var achievements: Set<String>
    public var theme: String?
    public var rank: Int?
    public var lastUpdatedAt: Date
    
    // Additional progress fields
    public var totalMerges: Int
    public var totalTimePlayed: TimeInterval
    public var unlockedThemes: Set<String>
    public var completedDailyChallenges: Int
    public var currentWinStreak: Int
    public var bestWinStreak: Int

    public init(
        highestTile: Int = 0,
        bestScore: Int = 0,
        gems: Int = 305, // Starter gems
        gamesPlayed: Int = 0,
        achievements: Set<String> = [],
        theme: String? = "beach",
        rank: Int? = nil,
        lastUpdatedAt: Date = Date(),
        totalMerges: Int = 0,
        totalTimePlayed: TimeInterval = 0,
        unlockedThemes: Set<String> = ["beach", "aqua"],
        completedDailyChallenges: Int = 0,
        currentWinStreak: Int = 0,
        bestWinStreak: Int = 0
    ) {
        self.highestTile = highestTile
        self.bestScore = bestScore
        self.gems = gems
        self.gamesPlayed = gamesPlayed
        self.achievements = achievements
        self.theme = theme
        self.rank = rank
        self.lastUpdatedAt = lastUpdatedAt
        self.totalMerges = totalMerges
        self.totalTimePlayed = totalTimePlayed
        self.unlockedThemes = unlockedThemes
        self.completedDailyChallenges = completedDailyChallenges
        self.currentWinStreak = currentWinStreak
        self.bestWinStreak = bestWinStreak
    }
}

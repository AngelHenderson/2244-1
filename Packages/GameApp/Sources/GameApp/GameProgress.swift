import Foundation
import GameCore

/// Canonical, versioned progress that both local and remote stores persist.
public struct GameProgress: Codable, Equatable, Sendable {
<<<<<<< HEAD
    public static let schemaVersion = 5 // Bumped to v5 for multi-tier score boosts
=======
    public static let schemaVersion = 3 // Bumped to v3 for comprehensive session state
>>>>>>> parent of 4f8a8f4 (Add score boost feature with persistence and UI)

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
<<<<<<< HEAD
    public var activeScoreBoost: ScoreBoostState?
    public var queuedScoreBoostTierID: String?
=======
>>>>>>> parent of 4f8a8f4 (Add score boost feature with persistence and UI)
    
    // MARK: - Comprehensive Session State (v3)
    
    // Current game session
    public var currentSessionState: SessionState?
    
    // Power-up inventory
    public var powerUpInventory: [String: Int]
    
    // JourneyKit state
    public var journeyState: JourneyState
    
    // Session tracking
    public var sessionTracking: SessionTracking
    
    // Achievement tracking
    public var hasInfinityAchievement: Bool
    
    public struct SessionState: Codable, Equatable, Sendable {
        public var board: Board
        public var score: Int
        public var moves: Int
        public var level: Int
        public var highestTile: Int
        public var seed: UInt64?
        public var brokenGlassTiles: [Position]
        public var movesHistory: [[Position]]
        public var lastDailyDateUTC: String?
        
        public init(
            board: Board,
            score: Int = 0,
            moves: Int = 0,
            level: Int = 1,
            highestTile: Int = 0,
            seed: UInt64? = nil,
            brokenGlassTiles: [Position] = [],
            movesHistory: [[Position]] = [],
            lastDailyDateUTC: String? = nil
        ) {
            self.board = board
            self.score = score
            self.moves = moves
            self.level = level
            self.highestTile = highestTile
            self.seed = seed
            self.brokenGlassTiles = brokenGlassTiles
            self.movesHistory = movesHistory
            self.lastDailyDateUTC = lastDailyDateUTC
        }
    }
    
    public struct JourneyState: Codable, Equatable, Sendable {
        public var highestTile: Int
        public var claimedTiles: Set<Int>
        public var claimedAbbreviationTiers: Set<String>
        
        public init(
            highestTile: Int = 0,
            claimedTiles: Set<Int> = [],
            claimedAbbreviationTiers: Set<String> = []
        ) {
            self.highestTile = highestTile
            self.claimedTiles = claimedTiles
            self.claimedAbbreviationTiers = claimedAbbreviationTiers
        }
    }
    
    public struct SessionTracking: Codable, Equatable, Sendable {
        public var sessionStartTime: Date?
        public var currentSessionStartTime: Date?
        public var currentSessionDuration: TimeInterval
        public var sessionMoves: Int
        public var sessionScore: Int
        public var sessionMerges: Int
        public var sessionHighestTile: Int
        public var sessionPowerUpsUsed: Int
        public var sessionEfficiencyScore: Double
        
        public init(
            sessionStartTime: Date? = nil,
            currentSessionStartTime: Date? = nil,
            currentSessionDuration: TimeInterval = 0,
            sessionMoves: Int = 0,
            sessionScore: Int = 0,
            sessionMerges: Int = 0,
            sessionHighestTile: Int = 0,
            sessionPowerUpsUsed: Int = 0,
            sessionEfficiencyScore: Double = 0
        ) {
            self.sessionStartTime = sessionStartTime
            self.currentSessionStartTime = currentSessionStartTime
            self.currentSessionDuration = currentSessionDuration
            self.sessionMoves = sessionMoves
            self.sessionScore = sessionScore
            self.sessionMerges = sessionMerges
            self.sessionHighestTile = sessionHighestTile
            self.sessionPowerUpsUsed = sessionPowerUpsUsed
            self.sessionEfficiencyScore = sessionEfficiencyScore
        }
    }
<<<<<<< HEAD
    
    public struct ScoreBoostState: Codable, Equatable, Sendable {
        public var tierID: String
        public var multiplier: Int
        public var expiresAt: Date
        
        public init(tierID: String, multiplier: Int, expiresAt: Date) {
            self.tierID = tierID
            self.multiplier = multiplier
            self.expiresAt = expiresAt
        }
        
        private enum CodingKeys: String, CodingKey {
            case tierID
            case multiplier
            case expiresAt
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            expiresAt = try container.decode(Date.self, forKey: .expiresAt)
            multiplier = (try? container.decode(Int.self, forKey: .multiplier)) ?? 1
            if let tier = try? container.decode(String.self, forKey: .tierID) {
                tierID = tier
            } else {
                tierID = "boost_\(multiplier)x"
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(tierID, forKey: .tierID)
            try container.encode(multiplier, forKey: .multiplier)
            try container.encode(expiresAt, forKey: .expiresAt)
        }
    }
=======
>>>>>>> parent of 4f8a8f4 (Add score boost feature with persistence and UI)

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
        bestWinStreak: Int = 0,
        currentSessionState: SessionState? = nil,
        powerUpInventory: [String: Int] = ["hammer": 3, "shuffle": 2, "swap": 2, "undo": 1],
        journeyState: JourneyState = JourneyState(),
        sessionTracking: SessionTracking = SessionTracking(),
        hasInfinityAchievement: Bool = false,
        queuedScoreBoostTierID: String? = nil
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
        self.currentSessionState = currentSessionState
        self.powerUpInventory = powerUpInventory
        self.journeyState = journeyState
        self.sessionTracking = sessionTracking
        self.hasInfinityAchievement = hasInfinityAchievement
        self.queuedScoreBoostTierID = queuedScoreBoostTierID
    }
}

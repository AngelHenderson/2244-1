import Foundation
import GameCore

/// Canonical, versioned progress that both local and remote stores persist.
public struct GameProgress: Codable, Equatable, Sendable {
    public static let schemaVersion = 6 // Adds power discount boost persistence

    public var version: Int = schemaVersion
    public var highestTile: Int
    public var highestTileStep: Int
    public var bestScore: Int
    public var bestScoreAlpha: AlphaNumber?
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
    public var activeScoreBoost: ScoreBoostState?
    public var queuedScoreBoostTierID: String?
    public var activePowerDiscount: PowerDiscountState?
    public var queuedPowerDiscountTierID: String?
    
    // MARK: - Comprehensive Session State (v3)
    
    // Current game session
    public var currentSessionState: SessionState?
    
    // Power-up inventory
    public var powerUpInventory: [String: Int]
    
    // Tier mastery progress keyed by abbreviation suffix (K, M, a, bz, ...)
    public var tierMasteryCounts: [String: Int]?
    
    // JourneyKit state
    public var journeyState: JourneyState
    
    // Session tracking
    public var sessionTracking: SessionTracking
    
    // Achievement tracking
    public var hasInfinityAchievement: Bool
    
    // Infinity tile merge count (for Hall of Fame leaderboard)
    public var infinityMergeCount: Int
    
    public struct SessionState: Codable, Equatable, Sendable {
        public var board: Board
        public var score: Int
        public var scoreAlpha: AlphaNumber?
        public var moves: Int
        public var level: Int
        public var highestTile: Int
        public var highestTileStep: Int?
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
            highestTileStep: Int? = nil,
            seed: UInt64? = nil,
            brokenGlassTiles: [Position] = [],
            movesHistory: [[Position]] = [],
            lastDailyDateUTC: String? = nil,
            scoreAlpha: AlphaNumber? = nil
        ) {
            self.board = board
            self.score = score
            self.scoreAlpha = scoreAlpha
            self.moves = moves
            self.level = level
            self.highestTile = highestTile
            self.highestTileStep = highestTileStep
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

    public struct PowerDiscountState: Codable, Equatable, Sendable {
        public var tierID: String
        public var discountPercentage: Int
        public var expiresAt: Date

        public init(tierID: String, discountPercentage: Int, expiresAt: Date) {
            self.tierID = tierID
            self.discountPercentage = discountPercentage
            self.expiresAt = expiresAt
        }

        private enum CodingKeys: String, CodingKey {
            case tierID
            case discountPercentage
            case expiresAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            tierID = (try? container.decode(String.self, forKey: .tierID)) ?? "power_discount_unknown"
            discountPercentage = (try? container.decode(Int.self, forKey: .discountPercentage)) ?? 0
            expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(tierID, forKey: .tierID)
            try container.encode(discountPercentage, forKey: .discountPercentage)
            try container.encode(expiresAt, forKey: .expiresAt)
        }
    }

    public init(
        highestTile: Int = 0,
        highestTileStep: Int = 0,
        bestScore: Int = 0,
        bestScoreAlpha: AlphaNumber? = nil,
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
        activeScoreBoost: ScoreBoostState? = nil,
        powerUpInventory: [String: Int] = ["hammer": 3, "shuffle": 2, "swap": 2, "undo": 1],
        tierMasteryCounts: [String: Int]? = nil,
        journeyState: JourneyState = JourneyState(),
        sessionTracking: SessionTracking = SessionTracking(),
        hasInfinityAchievement: Bool = false,
        infinityMergeCount: Int = 0,
        queuedScoreBoostTierID: String? = nil,
        activePowerDiscount: PowerDiscountState? = nil,
        queuedPowerDiscountTierID: String? = nil
    ) {
        self.highestTile = highestTile
        self.highestTileStep = highestTileStep
        self.bestScore = bestScore
        self.bestScoreAlpha = bestScoreAlpha
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
        self.activeScoreBoost = activeScoreBoost
        self.powerUpInventory = powerUpInventory
        self.tierMasteryCounts = tierMasteryCounts
        self.journeyState = journeyState
        self.sessionTracking = sessionTracking
        self.hasInfinityAchievement = hasInfinityAchievement
        self.infinityMergeCount = infinityMergeCount
        self.queuedScoreBoostTierID = queuedScoreBoostTierID
        self.activePowerDiscount = activePowerDiscount
        self.queuedPowerDiscountTierID = queuedPowerDiscountTierID
    }

    // Custom Decodable that provides defaults for fields missing from older saves
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? container.decode(Int.self, forKey: .version)) ?? Self.schemaVersion
        highestTile = try container.decode(Int.self, forKey: .highestTile)
        highestTileStep = (try? container.decode(Int.self, forKey: .highestTileStep)) ?? 0
        bestScore = try container.decode(Int.self, forKey: .bestScore)
        bestScoreAlpha = try? container.decode(AlphaNumber.self, forKey: .bestScoreAlpha)
        gems = try container.decode(Int.self, forKey: .gems)
        gamesPlayed = try container.decode(Int.self, forKey: .gamesPlayed)
        achievements = (try? container.decode(Set<String>.self, forKey: .achievements)) ?? []
        theme = try? container.decode(String.self, forKey: .theme)
        rank = try? container.decode(Int.self, forKey: .rank)
        lastUpdatedAt = (try? container.decode(Date.self, forKey: .lastUpdatedAt)) ?? Date()
        totalMerges = (try? container.decode(Int.self, forKey: .totalMerges)) ?? 0
        totalTimePlayed = (try? container.decode(TimeInterval.self, forKey: .totalTimePlayed)) ?? 0
        unlockedThemes = (try? container.decode(Set<String>.self, forKey: .unlockedThemes)) ?? ["beach", "aqua"]
        completedDailyChallenges = (try? container.decode(Int.self, forKey: .completedDailyChallenges)) ?? 0
        currentWinStreak = (try? container.decode(Int.self, forKey: .currentWinStreak)) ?? 0
        bestWinStreak = (try? container.decode(Int.self, forKey: .bestWinStreak)) ?? 0
        currentSessionState = try? container.decode(SessionState.self, forKey: .currentSessionState)
        activeScoreBoost = try? container.decode(ScoreBoostState.self, forKey: .activeScoreBoost)
        powerUpInventory = (try? container.decode([String: Int].self, forKey: .powerUpInventory)) ?? ["hammer": 3, "shuffle": 2, "swap": 2, "undo": 1]
        tierMasteryCounts = try? container.decode([String: Int].self, forKey: .tierMasteryCounts)
        journeyState = (try? container.decode(JourneyState.self, forKey: .journeyState)) ?? JourneyState()
        sessionTracking = (try? container.decode(SessionTracking.self, forKey: .sessionTracking)) ?? SessionTracking()
        hasInfinityAchievement = (try? container.decode(Bool.self, forKey: .hasInfinityAchievement)) ?? false
        infinityMergeCount = (try? container.decode(Int.self, forKey: .infinityMergeCount)) ?? 0
        queuedScoreBoostTierID = try? container.decode(String.self, forKey: .queuedScoreBoostTierID)
        activePowerDiscount = try? container.decode(PowerDiscountState.self, forKey: .activePowerDiscount)
        queuedPowerDiscountTierID = try? container.decode(String.self, forKey: .queuedPowerDiscountTierID)
    }
}

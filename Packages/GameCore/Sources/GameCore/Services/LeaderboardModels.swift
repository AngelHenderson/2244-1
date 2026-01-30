import Foundation

// MARK: - Leaderboard Models

/// Represents a leaderboard entry from a remote service.
public struct LeaderboardServiceEntry: Codable, Hashable, Sendable {
    public let uid: String
    public let displayName: String
    public let value: String // Composite score as string to avoid int64 limits
    public let highestTile: Int
    public let movesToHighest: Int
    public let secondsToHighest: Int
    public let runScore: Int
    public let achievedAt: Date?
    
    public init(
        uid: String,
        displayName: String,
        value: String,
        highestTile: Int,
        movesToHighest: Int,
        secondsToHighest: Int,
        runScore: Int,
        achievedAt: Date? = nil
    ) {
        self.uid = uid
        self.displayName = displayName
        self.value = value
        self.highestTile = highestTile
        self.movesToHighest = movesToHighest
        self.secondsToHighest = secondsToHighest
        self.runScore = runScore
        self.achievedAt = achievedAt
    }
}

/// Board identifiers for different leaderboard types
public enum LeaderboardBoard: Sendable {
    case global
    case daily(date: Date)
    case mode(String)
    
    public var identifier: String {
        switch self {
        case .global:
            return "global"
        case .daily(let date):
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            return "daily:\(formatter.string(from: date))"
        case .mode(let modeName):
            return "mode:\(modeName)"
        }
    }
    
    public static var today: LeaderboardBoard {
        .daily(date: Date())
    }
}

/// Composite scoring logic for deterministic ranking
public struct CompositeScore: Sendable {
    public static let BASE_SCORE = 1_000_000
    public static let BASE_MOVES = 1_000
    public static let BASE_TIME = 10_000
    public static let FACTOR = Int64(BASE_SCORE) * Int64(BASE_MOVES) * Int64(BASE_TIME) // 10^13
    
    /// Encodes a composite score that prioritizes:
    /// 1. Highest tile achieved (exponential weight)
    /// 2. Speed (less time is better)
    /// 3. Efficiency (fewer moves is better)
    /// 4. Raw score (tie-breaker)
    public static func encode(
        highestTile: Int,
        seconds: Int,
        moves: Int,
        score: Int
    ) -> Int64 {
        let p = Int64(max(2, Int(floor(log2(Double(max(2, highestTile)))))))
        let t = Int64(max(0, min(BASE_TIME - seconds, BASE_TIME)))
        let m = Int64(max(0, min(BASE_MOVES - moves, BASE_MOVES)))
        let s = Int64(max(0, min(score, BASE_SCORE - 1)))
        
        return p * FACTOR + t * 1_000_000_000 + m * 1_000_000 + s
    }
    
    /// Decodes composite score components for display
    public static func decode(_ composite: Int64) -> (tile: Int, seconds: Int, moves: Int, score: Int) {
        let p = composite / FACTOR
        let remainder = composite % FACTOR
        
        let t = remainder / 1_000_000_000
        let remainder2 = remainder % 1_000_000_000
        
        let m = remainder2 / 1_000_000
        let s = remainder2 % 1_000_000
        
        let tile = Int(pow(2.0, Double(p)))
        let seconds = BASE_TIME - Int(t)
        let moves = BASE_MOVES - Int(m)
        let score = Int(s)
        
        return (tile: tile, seconds: max(0, seconds), moves: max(0, moves), score: score)
    }
}

/// Game run data for leaderboard submission
public struct GameRunData: Sendable {
    public let highestTile: Int
    public let secondsToHighest: Int
    public let movesToHighest: Int
    public let runScore: Int
    
    public init(
        highestTile: Int,
        secondsToHighest: Int,
        movesToHighest: Int,
        runScore: Int
    ) {
        self.highestTile = highestTile
        self.secondsToHighest = secondsToHighest
        self.movesToHighest = movesToHighest
        self.runScore = runScore
    }
    
    public var compositeScore: Int64 {
        CompositeScore.encode(
            highestTile: highestTile,
            seconds: secondsToHighest,
            moves: movesToHighest,
            score: runScore
        )
    }
}

/// Leaderboard submission parameters
public struct LeaderboardSubmission: Sendable {
    public let boardId: String
    public let runData: GameRunData
    public let displayName: String
    
    public init(boardId: String, runData: GameRunData, displayName: String) {
        self.boardId = boardId
        self.runData = runData
        self.displayName = displayName
    }
}

import Foundation

public enum ChallengeStatus: Equatable, Sendable {
    case locked
    case pendingUnlock(unlockDate: Date)  // Unlocks after 1 hour from previous completion
    case active
    case completed
}

public struct ChallengeRule: Sendable, Equatable {
    public var timeLimitSec: Int?
    public var moveLimit: Int?
    public var bannedPowerUps: Set<String>
    
    public init(
        timeLimitSec: Int? = nil,
        moveLimit: Int? = nil,
        bannedPowerUps: Set<String> = []
    ) {
        self.timeLimitSec = timeLimitSec
        self.moveLimit = moveLimit
        self.bannedPowerUps = bannedPowerUps
    }
    
    public var displayText: String {
        var parts: [String] = []
        
        if let timeLimit = timeLimitSec {
            let minutes = timeLimit / 60
            let seconds = timeLimit % 60
            if seconds == 0 {
                parts.append("\(minutes) min")
            } else {
                parts.append("\(minutes):\(String(format: "%02d", seconds))")
            }
        }
        
        if let moveLimit = moveLimit {
            parts.append("\(moveLimit) moves")
        }
        
        if !bannedPowerUps.isEmpty {
            parts.append("No powerups")
        }
        
        return parts.joined(separator: ", ")
    }
}

public struct LegacyChallenge: Identifiable, Sendable, Equatable {
    public let id: Int
    public let targetTileLabel: String
    public let targetTileValue: Int
    public let rule: ChallengeRule
    public let seed: UInt64?
    public let rewardGems: Int
    
    public init(
        id: Int,
        targetTileLabel: String,
        targetTileValue: Int,
        rule: ChallengeRule = ChallengeRule(),
        seed: UInt64? = nil,
        rewardGems: Int = 100
    ) {
        self.id = id
        self.targetTileLabel = targetTileLabel
        self.targetTileValue = targetTileValue
        self.rule = rule
        self.seed = seed
        self.rewardGems = rewardGems
    }
}

public struct ChallengeContext: Sendable {
    public let challenge: LegacyChallenge
    public let startTime: Date
    public var movesUsed: Int = 0
    
    public init(challenge: LegacyChallenge, startTime: Date = Date()) {
        self.challenge = challenge
        self.startTime = startTime
    }
    
    public var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    public var isTimeLimitExceeded: Bool {
        guard let limit = challenge.rule.timeLimitSec else { return false }
        return elapsedTime > Double(limit)
    }
    
    public var isMoveLimitExceeded: Bool {
        guard let limit = challenge.rule.moveLimit else { return false }
        return movesUsed >= limit
    }
    
    public var isCompleted: Bool {
        return false
    }
}
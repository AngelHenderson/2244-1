import Foundation

public enum ChallengeTarget: Hashable, Codable, Sendable {
    case score(Int)
    case tile(Int)          // Value-based (e.g., 1048576 for 1M)
    case tileStep(Int)      // Step-based (e.g., step 19 for 1M)
    case chain(length: Int)
}

public enum TileBucket: String, CaseIterable, Codable, Sendable {
    case low
    case mid
    case high
    
    public var weight: Double {
        switch self {
        case .low: return 1.0
        case .mid: return 1.5
        case .high: return 2.0
        }
    }
}

public struct CustomChallengeConfig: Hashable, Codable, Sendable {
    public var target: ChallengeTarget
    public var timeLimitSeconds: Int
    public var minTileLevel: Int
    public var levels: Int
    public var tileAssignments: [Int: TileBucket]
    public var predictedRewardGems: Int

    // Step-based spawn limits for challenge mode
    public var minSpawnStep: Int?
    public var maxSpawnStep: Int?

    // Challenge ID for milestone tracking (nil for custom/designer challenges)
    public var challengeId: UUID?

    public init(
        target: ChallengeTarget,
        timeLimitSeconds: Int,
        minTileLevel: Int,
        levels: Int,
        tileAssignments: [Int: TileBucket],
        predictedRewardGems: Int,
        minSpawnStep: Int? = nil,
        maxSpawnStep: Int? = nil,
        challengeId: UUID? = nil
    ) {
        self.target = target
        self.timeLimitSeconds = timeLimitSeconds
        self.minTileLevel = minTileLevel
        self.levels = levels
        self.tileAssignments = tileAssignments
        self.predictedRewardGems = predictedRewardGems
        self.minSpawnStep = minSpawnStep
        self.maxSpawnStep = maxSpawnStep
        self.challengeId = challengeId
    }
}

public extension ChallengeTarget {
    func isSatisfied(
        score: Int,
        highestTile: Int,
        highestTileStep: Int,
        containsInfinityTile: Bool,
        longestChainLength: Int
    ) -> Bool {
        switch self {
        case .score(let target):
            score >= target
        case .tile(let target):
            highestTile >= target
        case .tileStep(let targetStep):
            targetStep == Int.max ? containsInfinityTile : highestTileStep >= targetStep
        case .chain(let length):
            longestChainLength >= length
        }
    }
}

public enum DifficultyEstimator {
    public static func estimateReward(
        target: ChallengeTarget,
        timeLimit: Int,
        minTileLevel: Int,
        levels: Int,
        assignments: [Int: TileBucket]
    ) -> Int {
        let baseScore = 1_000_000.0
        let baseTime = 60.0
        
        let targetDifficulty: Double
        switch target {
        case .score(let value):
            targetDifficulty = sqrt(max(0.25, Double(value) / baseScore))
        case .tile(let value):
            targetDifficulty = log2(Double(value)) / 10.0
        case .tileStep(let step):
            // For step-based targets, difficulty increases with step
            targetDifficulty = Double(step) / 20.0
        case .chain(let length):
            targetDifficulty = Double(length) / 5.0
        }
        
        let timeFactor = clamp(baseTime / max(10.0, Double(timeLimit)), min: 0.3, max: 3.0)
        let levelFactor = pow(1.06, Double(max(0, levels - 1)))
        let minTileEase = pow(1.12, Double(max(0, minTileLevel - 10)))
        
        var ease: Double = 1.0
        for (_, bucket) in assignments {
            switch bucket {
            case .low: ease += 0.00
            case .mid: ease += 0.05
            case .high: ease += 0.12
            }
        }
        if !assignments.isEmpty {
            ease /= Double(assignments.count).squareRoot()
        }
        
        let raw = 95.0 * targetDifficulty * timeFactor * levelFactor / (minTileEase * ease)
        let clipped = clamp(raw, min: 5.0, max: 9_999.0)
        return Int(clipped.rounded(.toNearestOrAwayFromZero))
    }
    
    @inline(__always)
    private static func clamp<T: Comparable>(_ v: T, min lo: T, max hi: T) -> T {
        max(lo, min(v, hi))
    }
}

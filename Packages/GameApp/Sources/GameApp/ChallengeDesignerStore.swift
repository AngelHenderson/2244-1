import SwiftUI
import GameCore

@Observable
@MainActor
public final class ChallengeDesignerStore: Sendable {
    private(set) var targetOptions: [Int] = [250_000, 500_000, 1_000_000, 2_000_000, 5_000_000]
    public var targetIndex: Int = 2
    
    public var timeLimitSeconds: Int = 60
    public var minTileLevel: Int = 10
    public var levels: Int = 5
    
    public var tileAssignments: [Int: TileBucket] = [
        64: .low, 128: .low, 256: .low, 512: .low, 1024: .mid
    ]
    
    public init() {}
    
    public var targetValue: Int { targetOptions[targetIndex] }
    
    public var config: CustomChallengeConfig {
        CustomChallengeConfig(
            target: .score(targetValue),
            timeLimitSeconds: timeLimitSeconds,
            minTileLevel: minTileLevel,
            levels: levels,
            tileAssignments: tileAssignments,
            predictedRewardGems: predictedReward
        )
    }
    
    public var isPlayable: Bool { 
        !tileAssignments.isEmpty && timeLimitSeconds > 0 
    }
    
    public func nextTarget() {
        targetIndex = (targetIndex + 1) % targetOptions.count
    }
    
    public func prevTarget() {
        targetIndex = (targetIndex - 1 + targetOptions.count) % targetOptions.count
    }
    
    public func decTime() { 
        timeLimitSeconds = max(15, timeLimitSeconds - 5) 
    }
    
    public func incTime() { 
        timeLimitSeconds = min(600, timeLimitSeconds + 5) 
    }
    
    public func decMinTile() { 
        minTileLevel = max(6, minTileLevel - 1) 
    }
    
    public func incMinTile() { 
        minTileLevel = min(16, minTileLevel + 1) 
    }
    
    public func decLevels() { 
        levels = max(1, levels - 1) 
    }
    
    public func incLevels() { 
        levels = min(10, levels + 1) 
    }
    
    public func cycleBucket(for tile: Int) {
        guard let current = tileAssignments[tile] else {
            tileAssignments[tile] = .low
            return
        }
        switch current {
        case .low: 
            tileAssignments[tile] = .mid
        case .mid: 
            tileAssignments[tile] = .high
        case .high: 
            tileAssignments.removeValue(forKey: tile)
        }
    }
    
    public func addTile(_ value: Int, to bucket: TileBucket) {
        tileAssignments[value] = bucket
    }
    
    public var candidateTiles: [Int] {
        let start = max(6, minTileLevel)
        let end = 16
        return (start...end).map { 1 << $0 }
    }
    
    public var predictedReward: Int {
        DifficultyEstimator.estimateReward(
            target: .score(targetValue),
            timeLimit: timeLimitSeconds,
            minTileLevel: minTileLevel,
            levels: levels,
            assignments: tileAssignments
        )
    }
}

private struct ChallengeDesignerStoreKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = ChallengeDesignerStore()
}

public extension EnvironmentValues {
    var challengeDesignerStore: ChallengeDesignerStore {
        get { self[ChallengeDesignerStoreKey.self] }
        set { self[ChallengeDesignerStoreKey.self] = newValue }
    }
}
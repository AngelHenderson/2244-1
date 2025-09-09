import SwiftUI
import GameCore

@Observable
@MainActor
public final class ChallengeStore: Sendable {
    public var challenges: [Challenge] = []
    public var lastCompletedId: Int = 0
    
    public init() {
        loadChallenges()
    }
    
    public func status(for challenge: Challenge) -> ChallengeStatus {
        if challenge.id <= lastCompletedId {
            return .completed
        } else if challenge.id == lastCompletedId + 1 {
            return .active
        } else {
            return .locked
        }
    }
    
    public var activeChallenge: Challenge? {
        challenges.first { $0.id == lastCompletedId + 1 }
    }
    
    public func markCompleted(_ id: Int) {
        if id == lastCompletedId + 1 {
            lastCompletedId = id
            saveProgress()
        }
    }
    
    private func loadChallenges() {
        challenges = [
            Challenge(id: 1, targetTileLabel: "1a", targetTileValue: 27, 
                     rule: ChallengeRule(timeLimitSec: 300), rewardGems: 50),
            Challenge(id: 2, targetTileLabel: "1b", targetTileValue: 28, 
                     rule: ChallengeRule(timeLimitSec: 240), rewardGems: 75),
            Challenge(id: 3, targetTileLabel: "1c", targetTileValue: 29, 
                     rule: ChallengeRule(timeLimitSec: 180), rewardGems: 100),
            Challenge(id: 4, targetTileLabel: "1d", targetTileValue: 30, 
                     rule: ChallengeRule(moveLimit: 100), rewardGems: 125),
            Challenge(id: 5, targetTileLabel: "1e", targetTileValue: 31, 
                     rule: ChallengeRule(timeLimitSec: 180, bannedPowerUps: ["hammer", "magnet"]), 
                     rewardGems: 150),
            Challenge(id: 6, targetTileLabel: "1f", targetTileValue: 32, 
                     rule: ChallengeRule(timeLimitSec: 150), rewardGems: 175),
            Challenge(id: 7, targetTileLabel: "1g", targetTileValue: 33, 
                     rule: ChallengeRule(moveLimit: 75), rewardGems: 200),
            Challenge(id: 8, targetTileLabel: "1h", targetTileValue: 34, 
                     rule: ChallengeRule(timeLimitSec: 120), rewardGems: 250),
            Challenge(id: 9, targetTileLabel: "1i", targetTileValue: 35, 
                     rule: ChallengeRule(timeLimitSec: 120, moveLimit: 60), rewardGems: 300),
            Challenge(id: 10, targetTileLabel: "1j", targetTileValue: 36, 
                     rule: ChallengeRule(timeLimitSec: 90), rewardGems: 400),
        ]
        
        loadProgress()
    }
    
    private func loadProgress() {
        lastCompletedId = UserDefaults.standard.integer(forKey: "challengeProgress")
    }
    
    private func saveProgress() {
        UserDefaults.standard.set(lastCompletedId, forKey: "challengeProgress")
    }
}

private struct ChallengeStoreKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = ChallengeStore()
}

public extension EnvironmentValues {
    var challengeStore: ChallengeStore {
        get { self[ChallengeStoreKey.self] }
        set { self[ChallengeStoreKey.self] = newValue }
    }
}
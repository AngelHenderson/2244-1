import SwiftUI
import GameCore

@Observable
@MainActor
public final class ChallengeStore: Sendable {
    public var challenges: [Challenge] = []
    public var completedIds: Set<UUID> = []
    private var challengeOrder: [UUID] = []
    
    public init() {
        loadChallenges()
    }
    
    public func status(for challenge: Challenge) -> ChallengeStatus {
        guard let index = challengeOrder.firstIndex(of: challenge.id) else {
            return .locked
        }

        if completedIds.contains(challenge.id) {
            return .completed
        }

        // Check if all previous challenges are completed
        let previousChallenges = challengeOrder.prefix(index)
        if previousChallenges.allSatisfy({ completedIds.contains($0) }) {
            return .active
        }

        return .locked
    }
    
    public var activeChallenge: Challenge? {
        for id in challengeOrder {
            if !completedIds.contains(id) {
                return challenges.first { $0.id == id }
            }
        }
        return nil
    }
    
    public func markCompleted(_ id: UUID) {
        completedIds.insert(id)
        saveProgress()
    }

    public var currentChallengeNumber: Int {
        return completedIds.count + 1
    }
    
    private func loadChallenges() {
        // Generate all milestone challenges programmatically
        // Milestones: 1M, 1B, 1a-1z, 1aa-1az, 1ba-1bz, Infinity
        challenges = generateAllMilestoneChallenges()

        // Set up the order of challenges
        challengeOrder = challenges.map { $0.id }

        loadProgress()
    }

    private func generateAllMilestoneChallenges() -> [Challenge] {
        var allChallenges: [Challenge] = []
        var challengeIndex = 0

        // Helper to create stable UUID from index
        func stableUUID(for index: Int) -> UUID {
            let hex = String(format: "%012X", index)
            return UUID(uuidString: "22449999-0001-4000-8000-\(hex)")!
        }

        // Helper to get difficulty based on milestone position
        func difficulty(for index: Int, total: Int) -> ChallengeDifficulty {
            let progress = Double(index) / Double(total)
            if progress < 0.25 { return .easy }
            if progress < 0.50 { return .medium }
            if progress < 0.75 { return .hard }
            return .expert
        }

        // Helper to calculate reward based on milestone index
        func reward(for index: Int) -> ChallengeReward {
            let baseCoins = 50 + (index * 25)
            let baseXP = 100 + (index * 50)
            return ChallengeReward(coins: baseCoins, experience: baseXP)
        }

        // Calculate the exact step for a "1X" milestone at a given base-1000 tier (hi).
        // For mantissa = 1 at tier hi: step = ceil(hi * log2(1000) - 1)
        // log2(1000) ≈ 9.96578
        // Tier mapping:
        //   hi=2 → M, hi=3 → B
        //   hi=4 → 'a', hi=5 → 'b', ..., hi=29 → 'z'
        //   hi=30 → 'aa', hi=31 → 'ab', ..., hi=55 → 'az'
        //   hi=56 → 'ba', hi=57 → 'bb', ..., hi=81 → 'bz'
        let log2Of1000 = 9.96578428

        func stepForTier(_ hi: Int) -> Int {
            return Int(ceil(Double(hi) * log2Of1000 - 1))
        }

        // 1. 1M milestone (hi=2)
        allChallenges.append(Challenge(
            id: stableUUID(for: challengeIndex),
            name: "Million Milestone",
            description: "Reach the 1M tile",
            mode: .custom,
            difficulty: .easy,
            targetTile: stepForTier(2),
            reward: reward(for: challengeIndex)
        ))
        challengeIndex += 1

        // 2. 1B milestone (hi=3)
        allChallenges.append(Challenge(
            id: stableUUID(for: challengeIndex),
            name: "Billion Milestone",
            description: "Reach the 1B tile",
            mode: .custom,
            difficulty: .easy,
            targetTile: stepForTier(3),
            reward: reward(for: challengeIndex)
        ))
        challengeIndex += 1

        // Total milestones for difficulty calculation
        let totalMilestones = 2 + 26 + 26 + 26 + 1  // M, B, a-z, aa-az, ba-bz, Infinity

        // 3. 1a through 1z (26 milestones)
        // hi = 4 for 'a', hi = 29 for 'z'
        for letterIndex in 0..<26 {
            let letter = String(Character(UnicodeScalar(97 + letterIndex)!))  // 'a' = 97
            let hi = 4 + letterIndex
            allChallenges.append(Challenge(
                id: stableUUID(for: challengeIndex),
                name: "Reach 1\(letter)",
                description: "Reach the 1\(letter) tile",
                mode: .custom,
                difficulty: difficulty(for: challengeIndex, total: totalMilestones),
                targetTile: stepForTier(hi),
                reward: reward(for: challengeIndex)
            ))
            challengeIndex += 1
        }

        // 4. 1aa through 1az (26 milestones)
        // hi = 30 for 'aa', hi = 55 for 'az'
        for letterIndex in 0..<26 {
            let letter = String(Character(UnicodeScalar(97 + letterIndex)!))  // 'a' = 97
            let hi = 30 + letterIndex
            allChallenges.append(Challenge(
                id: stableUUID(for: challengeIndex),
                name: "Reach 1a\(letter)",
                description: "Reach the 1a\(letter) tile",
                mode: .custom,
                difficulty: difficulty(for: challengeIndex, total: totalMilestones),
                targetTile: stepForTier(hi),
                reward: reward(for: challengeIndex)
            ))
            challengeIndex += 1
        }

        // 5. 1ba through 1bz (26 milestones)
        // hi = 56 for 'ba', hi = 81 for 'bz'
        for letterIndex in 0..<26 {
            let letter = String(Character(UnicodeScalar(97 + letterIndex)!))  // 'a' = 97
            let hi = 56 + letterIndex
            allChallenges.append(Challenge(
                id: stableUUID(for: challengeIndex),
                name: "Reach 1b\(letter)",
                description: "Reach the 1b\(letter) tile",
                mode: .custom,
                difficulty: difficulty(for: challengeIndex, total: totalMilestones),
                targetTile: stepForTier(hi),
                reward: reward(for: challengeIndex)
            ))
            challengeIndex += 1
        }

        // 6. Infinity milestone (special case)
        allChallenges.append(Challenge(
            id: stableUUID(for: challengeIndex),
            name: "Infinity",
            description: "Reach the ultimate milestone",
            mode: .custom,
            difficulty: .expert,
            targetTile: Int.max,
            reward: ChallengeReward(coins: 10000, experience: 50000)
        ))

        return allChallenges
    }
    
    private func loadProgress() {
        if let data = UserDefaults.standard.data(forKey: "challengeCompletedIds"),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            completedIds = ids
        }
    }
    
    private func saveProgress() {
        if let data = try? JSONEncoder().encode(completedIds) {
            UserDefaults.standard.set(data, forKey: "challengeCompletedIds")
        }
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


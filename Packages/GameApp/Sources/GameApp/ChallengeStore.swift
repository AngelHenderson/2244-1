import SwiftUI
import GameCore

@Observable
@MainActor
public final class ChallengeStore: Sendable {
    public var challenges: [Challenge] = []
    public var completedIds: Set<UUID> = []
    public var completionTimestamps: [UUID: Date] = [:]  // Tracks when each challenge was completed
    private var challengeOrder: [UUID] = []

    /// Time delay before next challenge unlocks (1 hour)
    public static let unlockDelaySeconds: TimeInterval = 3600  // 1 hour

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
        guard previousChallenges.allSatisfy({ completedIds.contains($0) }) else {
            return .locked
        }

        // First challenge is always active if not completed
        if index == 0 {
            return .active
        }

        // Get the previous challenge's completion timestamp
        let previousChallengeId = challengeOrder[index - 1]
        guard let previousCompletionTime = completionTimestamps[previousChallengeId] else {
            // Previous challenge completed but no timestamp (legacy data), allow active
            return .active
        }

        // Check if 1 hour has passed since previous completion
        let unlockDate = previousCompletionTime.addingTimeInterval(Self.unlockDelaySeconds)
        if Date() >= unlockDate {
            return .active
        }

        return .pendingUnlock(unlockDate: unlockDate)
    }
    
    public var activeChallenge: Challenge? {
        for id in challengeOrder {
            if !completedIds.contains(id) {
                if let challenge = challenges.first(where: { $0.id == id }) {
                    let challengeStatus = status(for: challenge)
                    if challengeStatus == .active {
                        return challenge
                    }
                }
                return nil
            }
        }
        return nil
    }

    /// Returns the next challenge that is pending unlock, if any
    public var pendingUnlockChallenge: (challenge: Challenge, unlockDate: Date)? {
        for id in challengeOrder {
            if !completedIds.contains(id) {
                if let challenge = challenges.first(where: { $0.id == id }) {
                    if case .pendingUnlock(let unlockDate) = status(for: challenge) {
                        return (challenge, unlockDate)
                    }
                }
                return nil
            }
        }
        return nil
    }

    public func markCompleted(_ id: UUID) {
        completedIds.insert(id)
        completionTimestamps[id] = Date()
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

        // Specific rewards for challenges (1M, 1B, 1a-1z, 1aa-1ag)
        // MegaMerge = .magnet power-up
        let specificRewards: [Int: ChallengeReward] = [
            0: ChallengeReward(coins: 50),                                              // 1M: 50 Gems
            1: ChallengeReward(coins: 70),                                              // 1B: 70 Gems
            2: ChallengeReward(powerUps: [.magnet: 1]),                                 // 1a: 1 MegaMerge
            3: ChallengeReward(coins: 60, scoreBoosts: [3: 1]),                         // 1b: 60 Gems, 3X Boost
            4: ChallengeReward(coins: 75, scoreBoosts: [2: 1]),                         // 1c: 75 Gems, 2X Boost
            5: ChallengeReward(coins: 100),                                             // 1d: 100 Gems
            6: ChallengeReward(powerUps: [.hammer: 1]),                                 // 1e: 1 Hammer
            7: ChallengeReward(powerUps: [.swap: 1]),                                   // 1f: 1 Swap
            8: ChallengeReward(scoreBoosts: [2: 1]),                                    // 1g: 2X Boost
            9: ChallengeReward(coins: 90, powerUps: [.swap: 1], scoreBoosts: [2: 1]),   // 1h: 90 Gems, 1 Swap, 2X Boost
            10: ChallengeReward(coins: 95, powerUps: [.magnet: 1], scoreBoosts: [3: 1]),// 1i: 95 Gems, 1 MegaMerge, 3X Boost
            11: ChallengeReward(coins: 105, powerUps: [.hammer: 1], scoreBoosts: [4: 1]),// 1j: 105 Gems, 1 Hammer, 4X Boost
            12: ChallengeReward(spins: 1),                                              // 1k: 1 Spin
            13: ChallengeReward(powerUps: [.magnet: 1]),                                // 1l: 1 MegaMerge
            14: ChallengeReward(powerUps: [.swap: 1]),                                  // 1m: 1 Swap
            15: ChallengeReward(coins: 125, spins: 1),                                  // 1n: 125 Gems, 1 Spin
            16: ChallengeReward(coins: 150),                                            // 1o: 150 Gems
            17: ChallengeReward(coins: 115, powerUps: [.magnet: 1], spins: 1, scoreBoosts: [2: 1, 3: 1]), // 1p: 115 Gems, 1 MegaMerge, 1 Spin, 2X Boost, 3X Boost
            18: ChallengeReward(powerUps: [.magnet: 1]),                                // 1q: 1 MegaMerge
            19: ChallengeReward(powerUps: [.swap: 1]),                                  // 1r: 1 Swap
            20: ChallengeReward(powerUps: [.hammer: 1]),                                // 1s: 1 Hammer
            21: ChallengeReward(spins: 1),                                              // 1t: 1 Spin
            22: ChallengeReward(coins: 200),                                            // 1u: 200 Gems
            23: ChallengeReward(spins: 1, scoreBoosts: [4: 1]),                         // 1v: 1 Spin, 4X Boost
            24: ChallengeReward(coins: 250),                                            // 1w: 250 Gems
            25: ChallengeReward(spins: 1, scoreBoosts: [3: 1]),                         // 1x: 1 Spin, 3X Boost
            26: ChallengeReward(powerUps: [.magnet: 1], scoreBoosts: [2: 1, 3: 1]),     // 1y: 1 MegaMerge, 2X Boost, 3X Boost
            27: ChallengeReward(powerUps: [.hammer: 1, .swap: 1, .magnet: 1], spins: 1),// 1z: 1 Hammer, 1 Swap, 1 MegaMerge, 1 Spin
            28: ChallengeReward(coins: 225, powerUps: [.swap: 1], spins: 1, scoreBoosts: [2: 1, 3: 1]), // 1aa: 225 Gems, 1 Swap, 1 Spin, 2X Boost, 3X Boost
            29: ChallengeReward(coins: 220, spins: 2),                                  // 1ab: 220 Gems, 2 Spins
            30: ChallengeReward(coins: 150, spins: 3),                                  // 1ac: 150 Gems, 3 Spins
            31: ChallengeReward(coins: 220, powerUps: [.magnet: 1], spins: 1, scoreBoosts: [3: 1]), // 1ad: 220 Gems, 1 MegaMerge, 1 Spin, 3X Boost
            32: ChallengeReward(powerUps: [.hammer: 1, .swap: 1], scoreBoosts: [4: 1]), // 1ae: 1 Hammer, 1 Swap, 4X Boost
            33: ChallengeReward(powerUps: [.hammer: 2], spins: 2),                      // 1af: 2 Hammers, 2 Spins
            34: ChallengeReward(coins: 250, powerUps: [.swap: 1])                       // 1ag: 250 Gems, 1 Swap
        ]

        // Helper to get reward - uses specific reward if defined, otherwise falls back to formula
        func reward(for index: Int) -> ChallengeReward {
            if let specific = specificRewards[index] {
                return specific
            }
            // Fallback formula for challenges beyond 1ag
            let baseCoins = 50 + (index * 25)
            return ChallengeReward(coins: baseCoins)
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

        // Calculate spawn limits: max spawn is 6 steps down, min spawn is 12 steps down
        func spawnLimits(for targetStep: Int) -> (maxSpawn: Int, minSpawn: Int) {
            let maxSpawn = max(0, targetStep - 6)
            let minSpawn = max(0, targetStep - 12)
            return (maxSpawn, minSpawn)
        }

        // 1. 1M milestone (hi=2)
        let step1M = stepForTier(2)
        let limits1M = spawnLimits(for: step1M)
        allChallenges.append(Challenge(
            id: stableUUID(for: challengeIndex),
            name: "Million Milestone",
            description: "Reach the 1M tile",
            mode: .custom,
            difficulty: .easy,
            targetTile: step1M,
            reward: reward(for: challengeIndex),
            maxSpawnTile: limits1M.maxSpawn,
            minSpawnTile: limits1M.minSpawn
        ))
        challengeIndex += 1

        // 2. 1B milestone (hi=3)
        let step1B = stepForTier(3)
        let limits1B = spawnLimits(for: step1B)
        allChallenges.append(Challenge(
            id: stableUUID(for: challengeIndex),
            name: "Billion Milestone",
            description: "Reach the 1B tile",
            mode: .custom,
            difficulty: .easy,
            targetTile: step1B,
            reward: reward(for: challengeIndex),
            maxSpawnTile: limits1B.maxSpawn,
            minSpawnTile: limits1B.minSpawn
        ))
        challengeIndex += 1

        // Total milestones for difficulty calculation
        let totalMilestones = 2 + 26 + 26 + 26 + 1  // M, B, a-z, aa-az, ba-bz, Infinity

        // 3. 1a through 1z (26 milestones)
        // hi = 4 for 'a', hi = 29 for 'z'
        for letterIndex in 0..<26 {
            let letter = String(Character(UnicodeScalar(97 + letterIndex)!))  // 'a' = 97
            let hi = 4 + letterIndex
            let step = stepForTier(hi)
            let limits = spawnLimits(for: step)
            allChallenges.append(Challenge(
                id: stableUUID(for: challengeIndex),
                name: "Reach 1\(letter)",
                description: "Reach the 1\(letter) tile",
                mode: .custom,
                difficulty: difficulty(for: challengeIndex, total: totalMilestones),
                targetTile: step,
                reward: reward(for: challengeIndex),
                maxSpawnTile: limits.maxSpawn,
                minSpawnTile: limits.minSpawn
            ))
            challengeIndex += 1
        }

        // 4. 1aa through 1az (26 milestones)
        // hi = 30 for 'aa', hi = 55 for 'az'
        for letterIndex in 0..<26 {
            let letter = String(Character(UnicodeScalar(97 + letterIndex)!))  // 'a' = 97
            let hi = 30 + letterIndex
            let step = stepForTier(hi)
            let limits = spawnLimits(for: step)
            allChallenges.append(Challenge(
                id: stableUUID(for: challengeIndex),
                name: "Reach 1a\(letter)",
                description: "Reach the 1a\(letter) tile",
                mode: .custom,
                difficulty: difficulty(for: challengeIndex, total: totalMilestones),
                targetTile: step,
                reward: reward(for: challengeIndex),
                maxSpawnTile: limits.maxSpawn,
                minSpawnTile: limits.minSpawn
            ))
            challengeIndex += 1
        }

        // 5. 1ba through 1bz (26 milestones)
        // hi = 56 for 'ba', hi = 81 for 'bz'
        for letterIndex in 0..<26 {
            let letter = String(Character(UnicodeScalar(97 + letterIndex)!))  // 'a' = 97
            let hi = 56 + letterIndex
            let step = stepForTier(hi)
            let limits = spawnLimits(for: step)
            allChallenges.append(Challenge(
                id: stableUUID(for: challengeIndex),
                name: "Reach 1b\(letter)",
                description: "Reach the 1b\(letter) tile",
                mode: .custom,
                difficulty: difficulty(for: challengeIndex, total: totalMilestones),
                targetTile: step,
                reward: reward(for: challengeIndex),
                maxSpawnTile: limits.maxSpawn,
                minSpawnTile: limits.minSpawn
            ))
            challengeIndex += 1
        }

        // 6. Infinity milestone (special case - use very high spawn limits)
        allChallenges.append(Challenge(
            id: stableUUID(for: challengeIndex),
            name: "Infinity",
            description: "Reach the ultimate milestone",
            mode: .custom,
            difficulty: .expert,
            targetTile: Int.max,
            reward: ChallengeReward(coins: 10000, experience: 50000),
            maxSpawnTile: stepForTier(81) - 6,  // Same as 1bz max spawn
            minSpawnTile: stepForTier(81) - 12  // Same as 1bz min spawn
        ))

        return allChallenges
    }
    
    private func loadProgress() {
        if let data = UserDefaults.standard.data(forKey: "challengeCompletedIds"),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            completedIds = ids
        }

        // Load completion timestamps
        if let data = UserDefaults.standard.data(forKey: "challengeCompletionTimestamps"),
           let timestamps = try? JSONDecoder().decode([UUID: Date].self, from: data) {
            completionTimestamps = timestamps
        }
    }

    private func saveProgress() {
        if let data = try? JSONEncoder().encode(completedIds) {
            UserDefaults.standard.set(data, forKey: "challengeCompletedIds")
        }

        // Save completion timestamps
        if let data = try? JSONEncoder().encode(completionTimestamps) {
            UserDefaults.standard.set(data, forKey: "challengeCompletionTimestamps")
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


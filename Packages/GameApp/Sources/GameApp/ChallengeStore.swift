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

    /// Returns the reward for a challenge by its UUID
    public func reward(for challengeId: UUID) -> ChallengeReward? {
        guard let index = challengeOrder.firstIndex(of: challengeId) else {
            return nil
        }
        return rewardForIndex(index)
    }

    /// Returns the reward for a challenge at a specific index
    private func rewardForIndex(_ index: Int) -> ChallengeReward {
        // Specific rewards for each challenge (0-indexed)
        let specificRewards: [Int: ChallengeReward] = [
            0: ChallengeReward(coins: 50),                                              // 1M: 50 Gems
            1: ChallengeReward(coins: 75),                                              // 1B: 75 Gems
            2: ChallengeReward(coins: 100),                                             // 1a: 100 Gems
            3: ChallengeReward(powerUps: [.hammer: 1]),                                 // 1b: 1 Hammer
            4: ChallengeReward(coins: 125),                                             // 1c: 125 Gems
            5: ChallengeReward(powerUps: [.swap: 1]),                                   // 1d: 1 Swap
            6: ChallengeReward(coins: 150),                                             // 1e: 150 Gems
            7: ChallengeReward(powerUps: [.magnet: 1]),                                 // 1f: 1 MegaMerge
            8: ChallengeReward(coins: 175),                                             // 1g: 175 Gems
            9: ChallengeReward(spins: 1),                                               // 1h: 1 Spin
            10: ChallengeReward(coins: 200),                                            // 1i: 200 Gems
            11: ChallengeReward(scoreBoosts: [2: 1]),                                   // 1j: 1 2x Boost
            12: ChallengeReward(coins: 225),                                            // 1k: 225 Gems
            13: ChallengeReward(powerUps: [.hammer: 1, .swap: 1]),                      // 1l: 1 Hammer, 1 Swap
            14: ChallengeReward(coins: 250),                                            // 1m: 250 Gems
            15: ChallengeReward(scoreBoosts: [3: 1]),                                   // 1n: 1 3x Boost
            16: ChallengeReward(coins: 275),                                            // 1o: 275 Gems
            17: ChallengeReward(powerUps: [.magnet: 1], spins: 1),                      // 1p: 1 MegaMerge, 1 Spin
            18: ChallengeReward(coins: 300),                                            // 1q: 300 Gems
            19: ChallengeReward(scoreBoosts: [4: 1]),                                   // 1r: 1 4x Boost
            20: ChallengeReward(coins: 325),                                            // 1s: 325 Gems
            21: ChallengeReward(powerUps: [.hammer: 2]),                                // 1t: 2 Hammers
            22: ChallengeReward(coins: 350),                                            // 1u: 350 Gems
            23: ChallengeReward(powerUps: [.swap: 2]),                                  // 1v: 2 Swaps
            24: ChallengeReward(coins: 375),                                            // 1w: 375 Gems
            25: ChallengeReward(powerUps: [.magnet: 2]),                                // 1x: 2 MegaMerges
            26: ChallengeReward(coins: 400),                                            // 1y: 400 Gems
            27: ChallengeReward(spins: 2),                                              // 1z: 2 Spins
            28: ChallengeReward(coins: 425),                                            // 1aa: 425 Gems
            29: ChallengeReward(powerUps: [.hammer: 1, .magnet: 1]),                    // 1ab: 1 Hammer, 1 MegaMerge
            30: ChallengeReward(coins: 450),                                            // 1ac: 450 Gems
            31: ChallengeReward(scoreBoosts: [2: 2]),                                   // 1ad: 2 2x Boosts
            32: ChallengeReward(coins: 475),                                            // 1ae: 475 Gems
            33: ChallengeReward(powerUps: [.swap: 1, .magnet: 1]),                      // 1af: 1 Swap, 1 MegaMerge
            34: ChallengeReward(coins: 500),                                            // 1ag: 500 Gems
            35: ChallengeReward(scoreBoosts: [3: 2]),                                   // 1ah: 2 3x Boosts
            36: ChallengeReward(coins: 525),                                            // 1ai: 525 Gems
            37: ChallengeReward(powerUps: [.hammer: 1, .swap: 1, .magnet: 1]),          // 1aj: 1 Hammer, 1 Swap, 1 MegaMerge
            38: ChallengeReward(coins: 550),                                            // 1ak: 550 Gems
            39: ChallengeReward(scoreBoosts: [4: 2]),                                   // 1al: 2 4x Boosts
            40: ChallengeReward(coins: 575),                                            // 1am: 575 Gems
            41: ChallengeReward(powerUps: [.hammer: 2, .swap: 1]),                      // 1an: 2 Hammers, 1 Swap
            42: ChallengeReward(coins: 600),                                            // 1ao: 600 Gems
            43: ChallengeReward(spins: 1, scoreBoosts: [2: 1]),                         // 1ap: 1 Spin, 1 2x Boost
            44: ChallengeReward(coins: 625),                                            // 1aq: 625 Gems
            45: ChallengeReward(powerUps: [.hammer: 1, .swap: 2]),                      // 1ar: 1 Hammer, 2 Swaps
            46: ChallengeReward(coins: 650),                                            // 1as: 650 Gems
            47: ChallengeReward(spins: 1, scoreBoosts: [3: 1]),                         // 1at: 1 Spin, 1 3x Boost
            48: ChallengeReward(coins: 675),                                            // 1au: 675 Gems
            49: ChallengeReward(powerUps: [.magnet: 2], spins: 1),                      // 1av: 2 MegaMerges, 1 Spin
            50: ChallengeReward(coins: 700),                                            // 1aw: 700 Gems
            51: ChallengeReward(spins: 1, scoreBoosts: [4: 1]),                         // 1ax: 1 Spin, 1 4x Boost
            52: ChallengeReward(coins: 725),                                            // 1ay: 725 Gems
            53: ChallengeReward(powerUps: [.hammer: 2, .swap: 2]),                      // 1az: 2 Hammers, 2 Swaps
            54: ChallengeReward(coins: 750),                                            // 1ba: 750 Gems
            55: ChallengeReward(powerUps: [.hammer: 1, .magnet: 2]),                    // 1bb: 1 Hammer, 2 MegaMerges
            56: ChallengeReward(coins: 775),                                            // 1bc: 775 Gems
            57: ChallengeReward(spins: 2, scoreBoosts: [2: 1]),                         // 1bd: 2 Spins, 1 2x Boost
            58: ChallengeReward(coins: 800),                                            // 1be: 800 Gems
            59: ChallengeReward(powerUps: [.swap: 2, .magnet: 1]),                      // 1bf: 2 Swaps, 1 MegaMerge
            60: ChallengeReward(coins: 825),                                            // 1bg: 825 Gems
            61: ChallengeReward(spins: 2, scoreBoosts: [3: 1]),                         // 1bh: 2 Spins, 1 3x Boost
            62: ChallengeReward(coins: 850),                                            // 1bi: 850 Gems
            63: ChallengeReward(powerUps: [.hammer: 2, .magnet: 2]),                    // 1bj: 2 Hammers, 2 MegaMerges
            64: ChallengeReward(coins: 875),                                            // 1bk: 875 Gems
            65: ChallengeReward(spins: 2, scoreBoosts: [4: 1]),                         // 1bl: 2 Spins, 1 4x Boost
            66: ChallengeReward(coins: 900),                                            // 1bm: 900 Gems
            67: ChallengeReward(powerUps: [.hammer: 1, .swap: 2, .magnet: 1]),          // 1bn: 1 Hammer, 2 Swaps, 1 MegaMerge
            68: ChallengeReward(coins: 925),                                            // 1bo: 925 Gems
            69: ChallengeReward(scoreBoosts: [2: 2, 3: 1]),                             // 1bp: 2 2x Boosts, 1 3x Boost
            70: ChallengeReward(coins: 950),                                            // 1bq: 950 Gems
            71: ChallengeReward(powerUps: [.hammer: 2, .swap: 1, .magnet: 2]),          // 1br: 2 Hammers, 1 Swap, 2 MegaMerges
            72: ChallengeReward(coins: 975),                                            // 1bs: 975 Gems
            73: ChallengeReward(scoreBoosts: [3: 2, 4: 1]),                             // 1bt: 2 3x Boosts, 1 4x Boost
            74: ChallengeReward(coins: 1000),                                           // 1bu: 1000 Gems
            75: ChallengeReward(powerUps: [.hammer: 2, .swap: 2, .magnet: 1], spins: 1), // 1bv: 2 Hammers, 2 Swaps, 1 MegaMerge, 1 Spin
            76: ChallengeReward(coins: 1025),                                           // 1bw: 1025 Gems (unlisted, using formula)
            77: ChallengeReward(spins: 2, scoreBoosts: [2: 1, 3: 1, 4: 1]),             // 1bx: 2 Spins, 1 each Boost
            78: ChallengeReward(coins: 1075),                                           // 1by: 1075 Gems (unlisted, using formula)
            79: ChallengeReward(powerUps: [.hammer: 2, .swap: 2, .magnet: 2], spins: 2), // 1bz: 2 Hammers, 2 Swaps, 2 MegaMerges, 2 Spins
            80: ChallengeReward(coins: 1000)                                            // Infinity: 1000 Gems
        ]

        if let specific = specificRewards[index] {
            return specific
        }
        // Fallback formula for any challenges beyond defined rewards
        let baseCoins = 50 + (index * 25)
        return ChallengeReward(coins: baseCoins)
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

        // Specific rewards for all challenges (1M, 1B, 1a-1z, 1aa-1az, 1ba-1bz, Infinity)
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
            34: ChallengeReward(coins: 250, powerUps: [.swap: 1]),                      // 1ag: 250 Gems, 1 Swap
            35: ChallengeReward(coins: 111, powerUps: [.hammer: 3, .swap: 2, .magnet: 1], scoreBoosts: [3: 1]), // 1ah: 111 Gems, 3 Hammers, 2 Swaps, 1 MegaMerge, 3X Boost
            36: ChallengeReward(spins: 2),                                              // 1ai: 2 Spins
            37: ChallengeReward(spins: 1, scoreBoosts: [4: 1]),                         // 1aj: 1 Spin, 4X Boost
            38: ChallengeReward(powerUps: [.swap: 2], scoreBoosts: [3: 1]),             // 1ak: 2 Swaps, 3X Boost
            39: ChallengeReward(coins: 220),                                            // 1al: 220 Gems
            40: ChallengeReward(coins: 220),                                            // 1am: 220 Gems
            41: ChallengeReward(coins: 270),                                            // 1an: 270 Gems
            42: ChallengeReward(scoreBoosts: [3: 1]),                                   // 1ao: 3X Boost
            43: ChallengeReward(scoreBoosts: [4: 1]),                                   // 1ap: 4X Boost
            44: ChallengeReward(scoreBoosts: [2: 1]),                                   // 1aq: 2X Boost
            45: ChallengeReward(coins: 300, powerUps: [.hammer: 1]),                    // 1ar: 300 Gems, 1 Hammer
            46: ChallengeReward(coins: 150, powerUps: [.hammer: 2, .swap: 2, .magnet: 2], spins: 2), // 1as: 150 Gems, 2 Hammers, 2 Swaps, 2 MegaMerges, 2 Spins
            47: ChallengeReward(powerUps: [.hammer: 2], scoreBoosts: [4: 1]),           // 1at: 2 Hammers, 4X Boost
            48: ChallengeReward(scoreBoosts: [3: 1]),                                   // 1au: 3X Boost
            49: ChallengeReward(coins: 300),                                            // 1av: 300 Gems
            50: ChallengeReward(coins: 255),                                            // 1aw: 255 Gems
            51: ChallengeReward(coins: 225, powerUps: [.hammer: 1, .swap: 1, .magnet: 1], spins: 1, scoreBoosts: [2: 1]), // 1ax: 225 Gems, 1 Hammer, 1 Swap, 1 MegaMerge, 1 Spin, 2X Boost
            52: ChallengeReward(coins: 265, powerUps: [.magnet: 1], scoreBoosts: [4: 1]), // 1ay: 265 Gems, 1 MegaMerge, 4X Boost
            53: ChallengeReward(coins: 280, powerUps: [.hammer: 1], spins: 1),          // 1az: 280 Gems, 1 Hammer, 1 Spin
            54: ChallengeReward(coins: 275, scoreBoosts: [3: 1]),                       // 1ba: 275 Gems, 3X Boost
            55: ChallengeReward(powerUps: [.magnet: 1]),                                // 1bb: 1 MegaMerge
            56: ChallengeReward(spins: 1, scoreBoosts: [2: 1]),                         // 1bc: 1 Spin, 2X Boost
            57: ChallengeReward(powerUps: [.hammer: 1, .swap: 1, .magnet: 1]),          // 1bd: 1 Hammer, 1 Swap, 1 MegaMerge
            58: ChallengeReward(powerUps: [.hammer: 2]),                                // 1be: 2 Hammers
            59: ChallengeReward(coins: 300, powerUps: [.hammer: 1], scoreBoosts: [2: 1]), // 1bf: 300 Gems, 1 Hammer, 2X Boost
            60: ChallengeReward(coins: 180, powerUps: [.hammer: 3]),                    // 1bg: 180 Gems, 3 Hammers
            61: ChallengeReward(powerUps: [.swap: 2]),                                  // 1bh: 2 Swaps
            62: ChallengeReward(coins: 255, powerUps: [.hammer: 1, .magnet: 1]),        // 1bi: 255 Gems, 1 Hammer, 1 MegaMerge
            63: ChallengeReward(spins: 1, scoreBoosts: [3: 1, 4: 1]),                   // 1bj: 1 Spin, 3X Boost, 4X Boost
            64: ChallengeReward(spins: 3),                                              // 1bk: 3 Spins
            65: ChallengeReward(powerUps: [.swap: 2, .magnet: 1], spins: 2),            // 1bl: 2 Swaps, 1 MegaMerge, 2 Spins
            66: ChallengeReward(coins: 350, scoreBoosts: [2: 1]),                       // 1bm: 350 Gems, 2X Boost
            67: ChallengeReward(coins: 650, scoreBoosts: [3: 1]),                       // 1bn: 650 Gems, 3X Boost
            68: ChallengeReward(coins: 800, powerUps: [.magnet: 1]),                    // 1bo: 800 Gems, 1 MegaMerge
            69: ChallengeReward(spins: 1),                                              // 1bp: 1 Spin
            70: ChallengeReward(coins: 600, powerUps: [.hammer: 2, .swap: 1, .magnet: 1], spins: 1, scoreBoosts: [3: 1]), // 1bq: 600 Gems, 2 Hammers, 1 Swap, 1 MegaMerge, 1 Spin, 3X Boost
            71: ChallengeReward(coins: 630, spins: 3),                                  // 1br: 630 Gems, 3 Spins
            72: ChallengeReward(scoreBoosts: [3: 1]),                                   // 1bs: 3X Boost
            73: ChallengeReward(powerUps: [.magnet: 1], scoreBoosts: [2: 1]),           // 1bt: 1 MegaMerge, 2X Boost
            74: ChallengeReward(scoreBoosts: [4: 1]),                                   // 1bu: 4X Boost
            75: ChallengeReward(coins: 875),                                            // 1bv: 875 Gems
            76: ChallengeReward(coins: 950),                                            // 1bw: 950 Gems
            77: ChallengeReward(powerUps: [.swap: 1], scoreBoosts: [2: 1]),             // 1bx: 1 Swap, 2X Boost
            78: ChallengeReward(coins: 700, powerUps: [.hammer: 1, .swap: 1, .magnet: 1], spins: 1, scoreBoosts: [2: 1, 3: 1, 4: 1]), // 1by: 700 Gems, 1 Hammer, 1 Swap, 1 MegaMerge, 1 Spin, 2X Boost, 3X Boost, 4X Boost
            79: ChallengeReward(powerUps: [.hammer: 2, .swap: 2, .magnet: 2], spins: 2), // 1bz: 2 Hammers, 2 Swaps, 2 MegaMerges, 2 Spins
            80: ChallengeReward(coins: 1000)                                            // Infinity: 1000 Gems
        ]

        // Helper to get reward - uses specific reward if defined, otherwise falls back to formula
        func reward(for index: Int) -> ChallengeReward {
            if let specific = specificRewards[index] {
                return specific
            }
            // Fallback formula for any challenges beyond defined rewards
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


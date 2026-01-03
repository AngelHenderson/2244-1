import SwiftUI
import Observation
import GameKit

@MainActor
@Observable
public final class AchievementStore {
    public struct UnlockState: Hashable, Codable {
        public var unlocked: Bool
        public var unlockedAt: Date?
        public var claimed: Bool
        
        public var isClaimable: Bool {
            unlocked && !claimed
        }
    }
    
    public struct ProgressTierDisplay: Sendable {
        public let milestone: Int
        public let level: Int
        public let title: String
        public let description: String
        public let categoryLabel: String
        public let rewards: AchievementDef.Rewards
    }
    
    // Add this nested type to satisfy usages in AchievementsView and progress(for:)
    public struct AchievementProgress: Sendable, Equatable {
        public let current: Double
        public let target: Double

        public init(current: Double, target: Double) {
            self.current = current
            self.target = target
        }

        /// Progress percentage (0.0 to 1.0)
        public var percentage: Double {
            guard target > 0 else { return 0 }
            return min(1.0, current / target)
        }
    }
    
    // MARK: - Tile Progression System
    /// The AlphaMag tiers for progressive tile achievement
    public static let tileTiers: [(suffix: String, label: String, value: Double)] = [
        ("M", "1M", 1_000_000),
        ("B", "1B", 1_000_000_000),
        ("a", "1a", 1e12),
        ("b", "1b", 1e15),
        ("c", "1c", 1e18),
        ("d", "1d", 1e21),
        ("e", "1e", 1e24),
        ("f", "1f", 1e27),
        ("g", "1g", 1e30),
        ("h", "1h", 1e33),
        ("i", "1i", 1e36),
        ("j", "1j", 1e39),
        ("k", "1k", 1e42),
        ("l", "1l", 1e45),
        ("m", "1m", 1e48),
        ("n", "1n", 1e51),
        ("o", "1o", 1e54),
        ("p", "1p", 1e57),
        ("q", "1q", 1e60),
        ("r", "1r", 1e63),
        ("s", "1s", 1e66),
        ("t", "1t", 1e69),
        ("u", "1u", 1e72),
        ("v", "1v", 1e75),
        ("w", "1w", 1e78),
        ("x", "1x", 1e81),
        ("y", "1y", 1e84),
        ("z", "1z", 1e87),
        ("aa", "1aa", 1e90),
        ("ab", "1ab", 1e93),
        ("ac", "1ac", 1e96),
        ("ad", "1ad", 1e99),
        ("ae", "1ae", 1e102),
        ("af", "1af", 1e105),
        ("ag", "1ag", 1e108),
        ("ah", "1ah", 1e111),
        ("ai", "1ai", 1e114),
        ("aj", "1aj", 1e117),
        ("ak", "1ak", 1e120),
        ("al", "1al", 1e123),
        ("am", "1am", 1e126),
        ("an", "1an", 1e129),
        ("ao", "1ao", 1e132),
        ("ap", "1ap", 1e135),
        ("aq", "1aq", 1e138),
        ("ar", "1ar", 1e141),
        ("as", "1as", 1e144),
        ("at", "1at", 1e147),
        ("au", "1au", 1e150),
        ("av", "1av", 1e153),
        ("aw", "1aw", 1e156),
        ("ax", "1ax", 1e159),
        ("ay", "1ay", 1e162),
        ("az", "1az", 1e165),
        ("ba", "1ba", 1e168),
        ("bb", "1bb", 1e171),
        ("bc", "1bc", 1e174),
        ("bd", "1bd", 1e177),
        ("be", "1be", 1e180),
        ("bf", "1bf", 1e183),
        ("bg", "1bg", 1e186),
        ("bh", "1bh", 1e189),
        ("bi", "1bi", 1e192),
        ("bj", "1bj", 1e195),
        ("bk", "1bk", 1e198),
        ("bl", "1bl", 1e201),
        ("bm", "1bm", 1e204),
        ("bn", "1bn", 1e207),
        ("bo", "1bo", 1e210),
        ("bp", "1bp", 1e213),
        ("bq", "1bq", 1e216),
        ("br", "1br", 1e219),
        ("bs", "1bs", 1e222),
        ("bt", "1bt", 1e225),
        ("bu", "1bu", 1e228),
        ("bv", "1bv", 1e231),
        ("bw", "1bw", 1e234),
        ("bx", "1bx", 1e237),
        ("by", "1by", 1e240),
        ("bz", "1bz", 1e243),
        ("∞", "∞", Double.infinity)
    ]
    
    // Tier-specific rewards for tile progression (indexed to tileTiers)
    private static let tileTierRewards: [AchievementDef.Rewards?] = [
        .init(gems: 25),                                  // 1M
        .init(gems: 35, magnets: 1),                      // 1B
        .init(gems: 60, spins: 1),                        // 1a
        .init(gems: 95, swaps: 1),                        // 1b
        .init(gems: 165),                                 // 1c
        .init(gems: 180),                                 // 1d
        .init(boost3x: 1),                                // 1e
        .init(hammers: 1, boost2x: 1),                    // 1f
        .init(gems: 350),                                 // 1g
        .init(gems: 375),                                 // 1h
        .init(gems: 400),                                 // 1i
        .init(gems: 335, magnets: 1),                     // 1j
        .init(spins: 1, hammers: 1),                      // 1k
        .init(gems: 395, swaps: 1),                       // 1l
        .init(spins: 1, magnets: 1, swaps: 1),            // 1m
        .init(gems: 450, spins: 1),                       // 1n
        .init(gems: 475),                                 // 1o
        .init(gems: 450, boost4x: 1),                     // 1p
        .init(gems: 550),                                 // 1q
        .init(hammers: 2),                                // 1r
        .init(gems: 750),                                 // 1s
        .init(gems: 500, spins: 1, magnets: 1, boost2x: 1), // 1t
        .init(gems: 550, magnets: 1, swaps: 1),           // 1u
        .init(gems: 850),                                 // 1v
        .init(gems: 900),                                 // 1w
        .init(magnets: 2),                                // 1x
        .init(gems: 975),                                 // 1y
        .init(gems: 950, spins: 1),                       // 1z
        .init(gems: 950, swaps: 2),                       // 1aa
        .init(spins: 2),                                  // 1ab
        .init(gems: 1000),                                // 1ac
        .init(gems: 1000),                                // 1ad
        .init(gems: 950, swaps: 1),                       // 1ae
        .init(gems: 1100),                                // 1af
        .init(gems: 1150),                                // 1ag
        .init(gems: 850, spins: 1, hammers: 1, boost2x: 1, boost4x: 1), // 1ah
        .init(gems: 950, swaps: 2),                       // 1ai
        .init(gems: 1200),                                // 1aj
        .init(gems: 1250),                                // 1ak
        .init(spins: 2, swaps: 2),                        // 1al
        .init(gems: 1300),                                // 1am
        .init(gems: 1300, hammers: 1),                    // 1an
        .init(gems: 1150, swaps: 1),                      // 1ao
        .init(hammers: 3),                                // 1ap
        .init(gems: 1250, spins: 1),                      // 1aq
        .init(gems: 1050, boost2x: 1, boost3x: 1, boost4x: 1), // 1ar
        .init(swaps: 2, boost4x: 1),                      // 1as
        .init(gems: 1400),                                // 1at
        .init(gems: 1450),                                // 1au
        .init(spins: 2, magnets: 2, boost2x: 1),          // 1av
        .init(gems: nil, spins: 2, hammers: 1, magnets: nil, swaps: 2), // 1aw
        .init(gems: 1500),                                // 1ax
        .init(gems: 1250, spins: 1, swaps: 1, boost4x: 1), // 1ay
        .init(swaps: 3),                                  // 1az
        .init(gems: 1450, hammers: 1),                    // 1ba
        .init(magnets: 2, boost2x: 1, boost3x: 1, boost4x: 1), // 1bb
        .init(spins: 1, swaps: 2, boost2x: 1, boost3x: 1, boost4x: 1), // 1bc
        .init(gems: 1550),                                // 1bd
        .init(spins: 3),                                  // 1be
        .init(gems: 1000, spins: 1, magnets: 3, boost3x: 1), // 1bf
        .init(gems: 1700),                                // 1bg
        .init(gems: 1800),                                // 1bh
        .init(gems: 1650, spins: 1, boost4x: 1),          // 1bi
        .init(swaps: 3),                                  // 1bj
        .init(gems: 1450, hammers: 1),                    // 1bk
        .init(gems: 1350, magnets: 2, boost3x: 1, boost4x: 1), // 1bl
        .init(
            gems: 1000,
            spins: 1,
            hammers: 1,
            magnets: 1,
            swaps: 1,
            boost2x: 1,
            boost3x: 1,
            boost4x: 1
        ),                                                // 1bm
        .init(gems: 1850),                                // 1bn
        .init(gems: 1900),                                // 1bo
        .init(gems: 2000, spins: 1, boost2x: 1),          // 1bp
        .init(gems: 1900, magnets: 1),                    // 1bq
        .init(gems: 2250),                                // 1br
        .init(gems: 2350, spins: 1),                      // 1bs
        .init(hammers: 3, magnets: 1),                    // 1bt
        .init(gems: 2550, spins: 1, hammers: 1, boost4x: 1), // 1bu
        .init(gems: 2700, magnets: 1, boost4x: 1),        // 1bv
        .init(gems: 2600, spins: 1, hammers: nil, magnets: 1, swaps: nil, boost2x: nil, boost3x: 1), // 1bw
        .init(gems: 2850, spins: 1),                      // 1bx
        .init(gems: 2900),                                // 1by
        .init(gems: 2950, magnets: 1),                    // 1bz
        .init(gems: 3000, spins: 2, hammers: 1, magnets: 1, boost3x: 1) // Inf
    ]
    
    // MARK: - Moves Progression System
    public static let movesTiers: [(label: String, value: Double)] = [
        ("25", 25),
        ("50", 50),
        ("100", 100),
        ("200", 200),
        ("500", 500),
        ("1K", 1000),
        ("2K", 2000),
        ("3K", 3000),
        ("5K", 5000),
        ("10K", 10000),
        ("30K", 30000),
        ("50K", 50000),
        ("100K", 100000),
        ("200K", 200000),
        ("300K", 300000),
        ("500K", 500000),
        ("750K", 750000),
        ("1M", 1000000)
    ]

    // Tier-specific rewards for moves progression (indexed to movesTiers)
    private static let movesTierRewards: [AchievementDef.Rewards] = [
        .init(gems: 25),                                  // 25 moves
        .init(gems: 50),                                  // 50 moves
        .init(gems: 75, hammers: 1),                      // 100 moves
        .init(gems: 100, magnets: 1),                     // 200 moves
        .init(gems: 150, spins: 1),                       // 500 moves
        .init(gems: 200, swaps: 1),                       // 1K moves
        .init(gems: 250, boost2x: 1),                     // 2K moves
        .init(gems: 300, boost3x: 1),                     // 3K moves
        .init(gems: 400, hammers: 1, magnets: 1),         // 5K moves
        .init(gems: 500, spins: 1, boost4x: 1),           // 10K moves
        .init(gems: 600, hammers: 2),                     // 30K moves
        .init(gems: 750, magnets: 2),                     // 50K moves
        .init(gems: 1000, spins: 2),                      // 100K moves
        .init(gems: 1250, swaps: 2, boost3x: 1),          // 200K moves
        .init(gems: 1500, hammers: 1, magnets: 1, swaps: 1), // 300K moves
        .init(gems: 2000, spins: 2, boost4x: 1),          // 500K moves
        .init(gems: 2500, hammers: 2, magnets: 2),        // 750K moves
        .init(gems: 3000, spins: 3, boost2x: 1, boost3x: 1, boost4x: 1) // 1M moves
    ]

    private struct ComboTierDefinition {
        let milestone: Int
        let categoryLabel: String
        let rewards: AchievementDef.Rewards
    }
    
    private static let combo610Tiers: [ComboTierDefinition] = [
        // Tiers 1-11 (original)
        .init(milestone: 10, categoryLabel: "10. Good Combo", rewards: .init(gems: 50)),
        .init(milestone: 25, categoryLabel: "25. Great Combo", rewards: .init(gems: 75)),
        .init(milestone: 50, categoryLabel: "50. Amazing Combo", rewards: .init(gems: 100, hammers: 1)),
        .init(milestone: 100, categoryLabel: "100. Glorious Combo", rewards: .init(gems: 100, spins: 1, swaps: 1)),
        .init(milestone: 200, categoryLabel: "200. Combo Master", rewards: .init(gems: 150, hammers: 1, magnets: 1)),
        .init(milestone: 300, categoryLabel: "300. Good Combo Master", rewards: .init(gems: 200, spins: 2)),
        .init(milestone: 400, categoryLabel: "400. Great Combo Master", rewards: .init(gems: 500)),
        .init(milestone: 500, categoryLabel: "500. Glorious Combo Master", rewards: .init(gems: 300, spins: 1, hammers: 1, magnets: 1)),
        .init(milestone: 600, categoryLabel: "600. Unbelievable Combo", rewards: .init(gems: 400, spins: 2, magnets: 1)),
        .init(milestone: 750, categoryLabel: "750. 750 IQ Combo Master", rewards: .init(gems: 1000, hammers: 1, swaps: 2)),
        .init(milestone: 1000, categoryLabel: "1000. 1000 IQ Combo Master", rewards: .init(gems: 1000, spins: 1, boost4x: 1)),
        // Tiers 12-30 (extended)
        .init(milestone: 1250, categoryLabel: "1250 combos", rewards: .init(gems: 1100)),
        .init(milestone: 1500, categoryLabel: "1500 combos", rewards: .init(gems: 1200)),
        .init(milestone: 1750, categoryLabel: "1750 combos", rewards: .init(hammers: 1, magnets: 1)),
        .init(milestone: 2000, categoryLabel: "2000 combos", rewards: .init(spins: 1)),
        .init(milestone: 2250, categoryLabel: "2250 combos", rewards: .init(gems: 1250, boost2x: 1)),
        .init(milestone: 2500, categoryLabel: "2500 combos", rewards: .init(magnets: 1)),
        .init(milestone: 3000, categoryLabel: "3000 combos", rewards: .init(gems: 1300, hammers: 1)),
        .init(milestone: 3500, categoryLabel: "3500 combos", rewards: .init(gems: 1325)),
        .init(milestone: 4000, categoryLabel: "4000 combos", rewards: .init(spins: 1, boost4x: 1)),
        .init(milestone: 4500, categoryLabel: "4500 combos", rewards: .init(gems: 1350)),
        .init(milestone: 5000, categoryLabel: "5000 combos", rewards: .init(hammers: 2)),
        .init(milestone: 6000, categoryLabel: "6000 combos", rewards: .init(swaps: 2)),
        .init(milestone: 7500, categoryLabel: "7500 combos", rewards: .init(magnets: 2)),
        .init(milestone: 10000, categoryLabel: "10000 combos", rewards: .init(spins: 2, boost3x: 1)),
        .init(milestone: 15000, categoryLabel: "15000 combos", rewards: .init(gems: 1500)),
        .init(milestone: 25000, categoryLabel: "25000 combos", rewards: .init(gems: 1750)),
        .init(milestone: 100000, categoryLabel: "100000 combos", rewards: .init(gems: 2000, magnets: 2, boost4x: 1)),
        .init(milestone: 250000, categoryLabel: "250000 combos", rewards: .init(hammers: 2, magnets: 2, swaps: 2)),
        .init(milestone: 500000, categoryLabel: "500000 combos", rewards: .init(gems: 3000))
    ]
    
    private static let combo1115Tiers: [ComboTierDefinition] = [
        // Tiers 1-11 (original)
        .init(milestone: 10, categoryLabel: "10. Good Combo", rewards: .init(gems: 100)),
        .init(milestone: 25, categoryLabel: "25. Great Combo", rewards: .init(gems: 75, magnets: 1)),
        .init(milestone: 50, categoryLabel: "50. Amazing Combo", rewards: .init(hammers: 1, boost2x: 1)),
        .init(milestone: 100, categoryLabel: "100. Glorious Combo", rewards: .init(gems: 250, spins: 1)),
        .init(milestone: 200, categoryLabel: "200. Combo Master", rewards: .init(gems: 300, swaps: 1, boost3x: 1)),
        .init(milestone: 300, categoryLabel: "300. Good Combo Master", rewards: .init(gems: 200, boost2x: 1, boost4x: 1)),
        .init(milestone: 400, categoryLabel: "400. Great Combo Master", rewards: .init(gems: 500, swaps: 1)),
        .init(milestone: 500, categoryLabel: "500. Glorious Combo Master", rewards: .init(gems: 750, spins: 1, magnets: 1)),
        .init(milestone: 600, categoryLabel: "600. Unbelievable Combo", rewards: .init(spins: 2, magnets: 1, boost2x: 1)),
        .init(milestone: 750, categoryLabel: "750. 750 IQ Combo Master", rewards: .init(gems: 500, hammers: 1, magnets: 1, swaps: 1)),
        .init(milestone: 1000, categoryLabel: "1000. 1000 IQ Combo Master", rewards: .init(gems: 800, spins: 1, hammers: 1, boost4x: 1)),
        // Tiers 12-30 (extended)
        .init(milestone: 1250, categoryLabel: "1250 combos", rewards: .init(gems: 900, swaps: 1)),
        .init(milestone: 1500, categoryLabel: "1500 combos", rewards: .init(gems: 1000)),
        .init(milestone: 1750, categoryLabel: "1750 combos", rewards: .init(magnets: 1)),
        .init(milestone: 2000, categoryLabel: "2000 combos", rewards: .init(hammers: 1, boost3x: 1)),
        .init(milestone: 2250, categoryLabel: "2250 combos", rewards: .init(gems: 1150, swaps: 1)),
        .init(milestone: 2500, categoryLabel: "2500 combos", rewards: .init(swaps: 2)),
        .init(milestone: 2750, categoryLabel: "2750 combos", rewards: .init(gems: 1400, hammers: 1)),
        .init(milestone: 3000, categoryLabel: "3000 combos", rewards: .init(gems: 1325, magnets: 1, boost4x: 1)),
        .init(milestone: 3333, categoryLabel: "3333 combos", rewards: .init(gems: 1555, spins: 1, boost4x: 1)),
        .init(milestone: 3666, categoryLabel: "3666 combos", rewards: .init(gems: 1650, swaps: 1, boost2x: 1, boost3x: 1)),
        .init(milestone: 4000, categoryLabel: "4000 combos", rewards: .init(hammers: 1, boost4x: 1)),
        .init(milestone: 4500, categoryLabel: "4500 combos", rewards: .init(swaps: 2, boost3x: 1)),
        .init(milestone: 5000, categoryLabel: "5000 combos", rewards: .init(magnets: 3, boost2x: 1)),
        .init(milestone: 6000, categoryLabel: "6000 combos", rewards: .init(gems: 1900, spins: 1, boost3x: 1)),
        .init(milestone: 8000, categoryLabel: "8000 combos", rewards: .init(gems: 1900, swaps: 3)),
        .init(milestone: 10000, categoryLabel: "10000 combos", rewards: .init(gems: 1950, magnets: 2)),
        .init(milestone: 15000, categoryLabel: "15000 combos", rewards: .init(gems: 2000, spins: 1, magnets: 2)),
        .init(milestone: 25000, categoryLabel: "25000 combos", rewards: .init(spins: 1, hammers: 2, magnets: 2, swaps: 1, boost2x: 1)),
        .init(milestone: 100000, categoryLabel: "100000 combos", rewards: .init(gems: 3000))
    ]
    
    private static let combo1620Tiers: [ComboTierDefinition] = [
        // Tiers 1-12 (original)
        .init(milestone: 10, categoryLabel: "10. Good Combo", rewards: .init(gems: 150)),
        .init(milestone: 25, categoryLabel: "25. Great Combo", rewards: .init(gems: 125, swaps: 1)),
        .init(milestone: 50, categoryLabel: "50. Amazing Combo", rewards: .init(gems: 200, swaps: 1, boost3x: 1)),
        .init(milestone: 100, categoryLabel: "100. Glorious Combo", rewards: .init(spins: 2)),
        .init(milestone: 200, categoryLabel: "200. Combo Master", rewards: .init(magnets: 1, boost4x: 1)),
        .init(milestone: 300, categoryLabel: "300. Good Combo Master", rewards: .init(gems: 500, boost3x: 1)),
        .init(milestone: 400, categoryLabel: "400. Great Combo Master", rewards: .init(gems: 350, spins: 1, magnets: 1, swaps: 1)),
        .init(milestone: 500, categoryLabel: "500. Glorious Combo Master", rewards: .init(gems: 1000, spins: 1)),
        .init(milestone: 600, categoryLabel: "600. Unbelievable Combo", rewards: .init(gems: 650, spins: 1, magnets: 1, swaps: 1, boost2x: 1)),
        .init(milestone: 750, categoryLabel: "750. 750 IQ Combo Master", rewards: .init(gems: 800, hammers: 1, magnets: 1, swaps: 1)),
        .init(milestone: 875, categoryLabel: "875 combos", rewards: .init(gems: 1025)),
        .init(milestone: 1000, categoryLabel: "1000. 1000 IQ Combo Master", rewards: .init(gems: 950, spins: 1, hammers: 1, boost3x: 1, boost4x: 1)),
        // Tiers 13-30 (extended)
        .init(milestone: 1125, categoryLabel: "1125 combos", rewards: .init(gems: 1100)),
        .init(milestone: 1250, categoryLabel: "1250 combos", rewards: .init(gems: 1095, magnets: 1)),
        .init(milestone: 1500, categoryLabel: "1500 combos", rewards: .init(hammers: 2, boost3x: 1)),
        .init(milestone: 2000, categoryLabel: "2000 combos", rewards: .init(magnets: 2, boost2x: 1)),
        .init(milestone: 2500, categoryLabel: "2500 combos", rewards: .init(gems: 1210, swaps: 2, boost3x: 1)),
        .init(milestone: 3000, categoryLabel: "3000 combos", rewards: .init(gems: 1300, hammers: 1)),
        .init(milestone: 3666, categoryLabel: "3666 combos", rewards: .init(gems: 1425, spins: 1, magnets: 1)),
        .init(milestone: 4333, categoryLabel: "4333 combos", rewards: .init(gems: 1650, spins: 1, boost4x: 1)),
        .init(milestone: 5000, categoryLabel: "5000 combos", rewards: .init(gems: 1650, magnets: 3, swaps: 1, boost2x: 1, boost3x: 1, boost4x: 1)),
        .init(milestone: 6000, categoryLabel: "6000 combos", rewards: .init(hammers: 5, boost2x: 1)),
        .init(milestone: 7250, categoryLabel: "7250 combos", rewards: .init(swaps: 4, boost3x: 1)),
        .init(milestone: 8625, categoryLabel: "8625 combos", rewards: .init(magnets: 3, boost4x: 1)),
        .init(milestone: 10000, categoryLabel: "10000 combos", rewards: .init(gems: 1880, magnets: 1, boost3x: 1)),
        .init(milestone: 12500, categoryLabel: "12500 combos", rewards: .init(gems: 1900, swaps: 2)),
        .init(milestone: 25000, categoryLabel: "25000 combos", rewards: .init(gems: 2250, spins: 1, magnets: 2)),
        .init(milestone: 50000, categoryLabel: "50000 combos", rewards: .init(spins: 2, hammers: 2, magnets: 3, boost3x: 1)),
        .init(milestone: 100000, categoryLabel: "100000 combos", rewards: .init(gems: 3300, spins: 2, hammers: 1, magnets: 2, swaps: 2, boost2x: 1, boost4x: 1)),
        .init(milestone: 500000, categoryLabel: "500000 combos", rewards: .init(gems: 5000, boost2x: 1))
    ]

    private static let combo2130Tiers: [ComboTierDefinition] = [
        // Tiers 1-12 (original)
        .init(milestone: 10, categoryLabel: "10. Good Combo", rewards: .init(gems: 500)),
        .init(milestone: 25, categoryLabel: "25. Great Combo", rewards: .init(gems: 400, magnets: 1)),
        .init(milestone: 50, categoryLabel: "50. Amazing Combo", rewards: .init(gems: 500, swaps: 1, boost2x: 1)),
        .init(milestone: 100, categoryLabel: "100. Glorious Combo", rewards: .init(gems: 350, spins: 2)),
        .init(milestone: 200, categoryLabel: "200. Combo Master", rewards: .init(gems: 300, spins: 1, magnets: 1, boost4x: 1)),
        .init(milestone: 300, categoryLabel: "300. Good Combo Master", rewards: .init(gems: 1000, hammers: 1, boost3x: 1)),
        .init(milestone: 400, categoryLabel: "400. Great Combo Master", rewards: .init(gems: 850, spins: 1, magnets: 2)),
        .init(milestone: 500, categoryLabel: "500. Glorious Combo Master", rewards: .init(gems: 1150, spins: 1, boost2x: 1)),
        .init(milestone: 600, categoryLabel: "600. Unbelievable Combo", rewards: .init(gems: 500, spins: 1, magnets: 1, boost3x: 1, boost4x: 1)),
        .init(milestone: 750, categoryLabel: "750. 750 IQ Combo Master", rewards: .init(gems: 1050, magnets: 1)),
        .init(milestone: 1000, categoryLabel: "1000. 1000 IQ Combo Master", rewards: .init(gems: 1200, spins: 1, boost4x: 1)),
        // Tiers 13-30 (extended)
        .init(milestone: 1500, categoryLabel: "1500 combos", rewards: .init(gems: 1400)),
        .init(milestone: 2000, categoryLabel: "2000 combos", rewards: .init(gems: 1395, magnets: 1)),
        .init(milestone: 2500, categoryLabel: "2500 combos", rewards: .init(hammers: 4, boost2x: 1)),
        .init(milestone: 3000, categoryLabel: "3000 combos", rewards: .init(magnets: 3, boost3x: 1)),
        .init(milestone: 4000, categoryLabel: "4000 combos", rewards: .init(gems: 1500, spins: 1, magnets: 2, swaps: 3, boost3x: 1)),
        .init(milestone: 5000, categoryLabel: "5000 combos", rewards: .init(gems: 1800, hammers: 2)),
        .init(milestone: 6666, categoryLabel: "6666 combos", rewards: .init(gems: 1725, spins: 3, magnets: 2, boost2x: 1)),
        .init(milestone: 8333, categoryLabel: "8333 combos", rewards: .init(gems: 2150, spins: 1, boost4x: 1)),
        .init(milestone: 10000, categoryLabel: "10000 combos", rewards: .init(gems: 2150, magnets: 3, swaps: 1, boost2x: 1, boost3x: 1, boost4x: 1)),
        .init(milestone: 15000, categoryLabel: "15000 combos", rewards: .init(hammers: 6, boost2x: 1)),
        .init(milestone: 25000, categoryLabel: "25000 combos", rewards: .init(swaps: 5, boost3x: 1)),
        .init(milestone: 50000, categoryLabel: "50000 combos", rewards: .init(gems: 1850, magnets: 3, boost4x: 1)),
        .init(milestone: 75000, categoryLabel: "75000 combos", rewards: .init(gems: 2150, magnets: 1, boost3x: 1)),
        .init(milestone: 100000, categoryLabel: "100000 combos", rewards: .init(gems: 2300, swaps: 2)),
        .init(milestone: 125000, categoryLabel: "125000 combos", rewards: .init(gems: 2350, spins: 1, magnets: 2)),
        .init(milestone: 150000, categoryLabel: "150000 combos", rewards: .init(gems: 2400, spins: 2, hammers: 2, magnets: 3, boost3x: 1)),
        .init(milestone: 200000, categoryLabel: "200000 combos", rewards: .init(gems: 3300, spins: 2, hammers: 1, magnets: 2, swaps: 2, boost2x: 1, boost4x: 1)),
        .init(milestone: 250000, categoryLabel: "250000 combos", rewards: .init(gems: 5000, boost2x: 1))
    ]
    
    private static let mergeTiers: [ComboTierDefinition] = [
        .init(milestone: 250, categoryLabel: "250 tiles", rewards: .init(gems: 15)),
        .init(milestone: 500, categoryLabel: "500 tiles", rewards: .init(gems: 25)),
        .init(milestone: 1000, categoryLabel: "1000 tiles", rewards: .init(gems: 35, boost2x: 1)),
        .init(milestone: 1500, categoryLabel: "1500 tiles", rewards: .init(gems: 50, hammers: 1)),
        .init(milestone: 2500, categoryLabel: "2500 tiles", rewards: .init(gems: 60, swaps: 1)),
        .init(milestone: 5000, categoryLabel: "5000 tiles", rewards: .init(gems: 75, magnets: 1)),
        .init(milestone: 10000, categoryLabel: "10000 tiles", rewards: .init(gems: 75, hammers: 1, swaps: 1)),
        .init(milestone: 15000, categoryLabel: "15000 tiles", rewards: .init(gems: 75, hammers: 2)),
        .init(milestone: 25000, categoryLabel: "25000 tiles", rewards: .init(gems: 100, spins: 1, hammers: 1, swaps: 1)),
        .init(milestone: 50000, categoryLabel: "50000 tiles", rewards: .init(gems: 500)),
        .init(milestone: 75000, categoryLabel: "75000 tiles", rewards: .init(magnets: 1, swaps: 1, boost4x: 1)),
        .init(milestone: 100000, categoryLabel: "100000 tiles", rewards: .init(gems: 250, spins: 1, magnets: 1)),
        .init(milestone: 150000, categoryLabel: "150000 tiles", rewards: .init(gems: 300, magnets: 1, boost2x: 1)),
        .init(milestone: 250000, categoryLabel: "250000 tiles", rewards: .init(gems: 350, magnets: 2)),
        .init(milestone: 375000, categoryLabel: "375000 tiles", rewards: .init(spins: 1, magnets: 1, boost3x: 1)),
        .init(milestone: 500000, categoryLabel: "500000 tiles", rewards: .init(gems: 350, spins: 1, magnets: 1, swaps: 1, boost2x: 1, boost3x: 1)),
        .init(milestone: 750000, categoryLabel: "750000 tiles", rewards: .init(gems: 550, hammers: 1, magnets: 1, boost2x: 1)),
        .init(milestone: 1000000, categoryLabel: "1000000 tiles", rewards: .init(gems: 750, swaps: 2)),
        .init(milestone: 1250000, categoryLabel: "1250000 tiles", rewards: .init(spins: 1, hammers: 1, boost4x: 1)),
        .init(milestone: 1500000, categoryLabel: "1500000 tiles", rewards: .init(gems: 1075, spins: 1, boost3x: 1, boost4x: 1)),
        .init(milestone: 1750000, categoryLabel: "1750000 tiles", rewards: .init(gems: 1125, swaps: 1)),
        .init(milestone: 2000000, categoryLabel: "2000000 tiles", rewards: .init(gems: 1250, magnets: 1, boost4x: 1)),
        .init(milestone: 2250000, categoryLabel: "2250000 tiles", rewards: .init(gems: 1300, hammers: 1, boost2x: 1)),
        .init(milestone: 2500000, categoryLabel: "2500000 tiles", rewards: .init(gems: 1600)),
        .init(milestone: 3000000, categoryLabel: "3000000 tiles", rewards: .init(magnets: 1)),
        .init(milestone: 3500000, categoryLabel: "3500000 tiles", rewards: .init(boost3x: 1)),
        .init(milestone: 4000000, categoryLabel: "4000000 tiles", rewards: .init(gems: 2000)),
        .init(milestone: 4500000, categoryLabel: "4500000 tiles", rewards: .init(gems: 1900, magnets: 1)),
        .init(milestone: 5000000, categoryLabel: "5000000 tiles", rewards: .init(spins: 1, swaps: 1)),
        .init(milestone: 6000000, categoryLabel: "6000000 tiles", rewards: .init(magnets: 2))
    ]

    private static let swapUseTiers: [ComboTierDefinition] = [
        // Tiers 1-11 (existing)
        .init(milestone: 5, categoryLabel: "Use Swap 5 Times", rewards: .init(gems: 75, swaps: 1)),
        .init(milestone: 10, categoryLabel: "Use Swap 10 Times", rewards: .init(gems: 100, magnets: 1)),
        .init(milestone: 20, categoryLabel: "Use Swap 20 Times", rewards: .init(hammers: 1, boost4x: 1)),
        .init(milestone: 30, categoryLabel: "Use Swap 30 Times", rewards: .init(spins: 1, magnets: 1, swaps: 1)),
        .init(milestone: 50, categoryLabel: "Use Swap 50 Times", rewards: .init(gems: 500, hammers: 1)),
        .init(milestone: 75, categoryLabel: "Use Swap 75 Times", rewards: .init(gems: 500, swaps: 1)),
        .init(milestone: 100, categoryLabel: "Use Swap 100 Times", rewards: .init(gems: 200, boost2x: 1, boost3x: 1, boost4x: 1)),
        .init(milestone: 150, categoryLabel: "Use Swap 150 Times", rewards: .init(gems: 500, boost4x: 1)),
        .init(milestone: 200, categoryLabel: "Use Swap 200 Times", rewards: .init(gems: 500, hammers: 1, magnets: 1, swaps: 1, boost3x: 1)),
        .init(milestone: 250, categoryLabel: "Use Swap 250 Times", rewards: .init(gems: 1000, spins: 1, hammers: 1, swaps: 1)),
        .init(milestone: 300, categoryLabel: "Use Swap 300 Times", rewards: .init(gems: 750, spins: 1, hammers: 2, magnets: 1, swaps: 1)),
        // Tiers 12-30 (extended)
        .init(milestone: 350, categoryLabel: "Use Swap 350 Times", rewards: .init(gems: 725, magnets: 3)),
        .init(milestone: 400, categoryLabel: "Use Swap 400 Times", rewards: .init(spins: 5)),
        .init(milestone: 450, categoryLabel: "Use Swap 450 Times", rewards: .init(magnets: 1, boost2x: 1)),
        .init(milestone: 500, categoryLabel: "Use Swap 500 Times", rewards: .init(magnets: 1, boost3x: 1)),
        .init(milestone: 600, categoryLabel: "Use Swap 600 Times", rewards: .init(gems: 880)),
        .init(milestone: 700, categoryLabel: "Use Swap 700 Times", rewards: .init(gems: 700, spins: 1, hammers: 1, magnets: 1, swaps: 1, boost2x: 1, boost3x: 1, boost4x: 1)),
        .init(milestone: 850, categoryLabel: "Use Swap 850 Times", rewards: .init(hammers: 2, swaps: 1)),
        .init(milestone: 1000, categoryLabel: "Use Swap 1000 Times", rewards: .init(magnets: 1, swaps: 2)),
        .init(milestone: 1250, categoryLabel: "Use Swap 1250 Times", rewards: .init(magnets: 3)),
        .init(milestone: 1500, categoryLabel: "Use Swap 1500 Times", rewards: .init(gems: 400, spins: 3, magnets: 3, boost3x: 1)),
        .init(milestone: 2000, categoryLabel: "Use Swap 2000 Times", rewards: .init(boost3x: 1)),
        .init(milestone: 2500, categoryLabel: "Use Swap 2500 Times", rewards: .init(gems: 600, boost3x: 1)),
        .init(milestone: 3000, categoryLabel: "Use Swap 3000 Times", rewards: .init(gems: 550, spins: 2, hammers: 2, magnets: 2, swaps: 2)),
        .init(milestone: 5000, categoryLabel: "Use Swap 5000 Times", rewards: .init(spins: 4)),
        .init(milestone: 7500, categoryLabel: "Use Swap 7500 Times", rewards: .init(gems: 680, spins: 2, boost2x: 1)),
        .init(milestone: 10000, categoryLabel: "Use Swap 10000 Times", rewards: .init(gems: 800, swaps: 1)),
        .init(milestone: 15000, categoryLabel: "Use Swap 15000 Times", rewards: .init(gems: 950, magnets: 1, swaps: 1, boost2x: 1)),
        .init(milestone: 25000, categoryLabel: "Use Swap 25000 Times", rewards: .init(gems: 1000, boost3x: 1)),
        .init(milestone: 50000, categoryLabel: "Use Swap 50000 Times", rewards: .init(gems: 1050))
    ]
    
    private static let hammerUseTiers: [ComboTierDefinition] = [
        .init(milestone: 5, categoryLabel: "Use Hammer 5 Times", rewards: .init(gems: 250)),
        .init(milestone: 10, categoryLabel: "Use Hammer 10 Times", rewards: .init(gems: 250, magnets: 1)),
        .init(milestone: 20, categoryLabel: "Use Hammer 20 Times", rewards: .init(gems: 200, spins: 1, hammers: 1, boost4x: 1)),
        .init(milestone: 30, categoryLabel: "Use Hammer 30 Times", rewards: .init(spins: 1, hammers: nil, magnets: 1, swaps: 1)),
        .init(milestone: 50, categoryLabel: "Use Hammer 50 Times", rewards: .init(gems: 500, hammers: 1)),
        .init(milestone: 75, categoryLabel: "Use Hammer 75 Times", rewards: .init(gems: 500, swaps: 1)),
        .init(milestone: 100, categoryLabel: "Use Hammer 100 Times", rewards: .init(gems: 200, boost2x: 1, boost3x: 1, boost4x: 1)),
        .init(milestone: 150, categoryLabel: "Use Hammer 150 Times", rewards: .init(gems: 500, boost4x: 1)),
        .init(milestone: 200, categoryLabel: "Use Hammer 200 Times", rewards: .init(gems: 500, hammers: 1, magnets: 1, swaps: 1, boost3x: 1)),
        .init(milestone: 250, categoryLabel: "Use Hammer 250 Times", rewards: .init(gems: 1000, spins: 1, hammers: 1, swaps: 1)),
        .init(milestone: 300, categoryLabel: "Use Hammer 300 Times", rewards: .init(gems: 750, spins: 1, hammers: 2, magnets: 1, swaps: 1))
    ]
    
    private static let magnetUseTiers: [ComboTierDefinition] = [
        .init(milestone: 5, categoryLabel: "Use MegaMerge 5 Times", rewards: .init(gems: 250)),
        .init(milestone: 10, categoryLabel: "Use MegaMerge 10 Times", rewards: .init(gems: 250, magnets: 1)),
        .init(milestone: 20, categoryLabel: "Use MegaMerge 20 Times", rewards: .init(gems: 200, spins: 1, hammers: 1, boost4x: 1)),
        .init(milestone: 30, categoryLabel: "Use MegaMerge 30 Times", rewards: .init(spins: 1, magnets: 1, swaps: 1)),
        .init(milestone: 50, categoryLabel: "Use MegaMerge 50 Times", rewards: .init(gems: 500, hammers: 1)),
        .init(milestone: 75, categoryLabel: "Use MegaMerge 75 Times", rewards: .init(gems: 500, swaps: 1)),
        .init(milestone: 100, categoryLabel: "Use MegaMerge 100 Times", rewards: .init(gems: 200, boost2x: 1, boost3x: 1, boost4x: 1)),
        .init(milestone: 125, categoryLabel: "Use MegaMerge 125 Times", rewards: .init(gems: 500, boost4x: 1)),
        .init(milestone: 150, categoryLabel: "Use MegaMerge 150 Times", rewards: .init(gems: 500, hammers: 1, magnets: 1, swaps: 1, boost3x: 1)),
        .init(milestone: 200, categoryLabel: "Use MegaMerge 200 Times", rewards: .init(gems: 1000, spins: 1, hammers: 1, swaps: 1)),
        .init(milestone: 300, categoryLabel: "Use MegaMerge 300 Times", rewards: .init(gems: 750, spins: 1, hammers: 2, magnets: 1, swaps: 1)),
        // Tiers 12-20
        .init(milestone: 500, categoryLabel: "Use MegaMerge 500 Times", rewards: .init(gems: 1500)),
        .init(milestone: 750, categoryLabel: "Use MegaMerge 750 Times", rewards: .init(gems: 1500, hammers: 1)),
        .init(milestone: 1000, categoryLabel: "Use MegaMerge 1000 Times", rewards: .init(magnets: 2)),
        .init(milestone: 1500, categoryLabel: "Use MegaMerge 1500 Times", rewards: .init(spins: 2, boost4x: 1)),
        .init(milestone: 2000, categoryLabel: "Use MegaMerge 2000 Times", rewards: .init(spins: 2, boost2x: 1, boost4x: 1)),
        .init(milestone: 2500, categoryLabel: "Use MegaMerge 2500 Times", rewards: .init(gems: 2000, magnets: 1)),
        .init(milestone: 3750, categoryLabel: "Use MegaMerge 3750 Times", rewards: .init(gems: 2300)),
        .init(milestone: 5000, categoryLabel: "Use MegaMerge 5000 Times", rewards: .init(gems: 2445, swaps: 1)),
        .init(milestone: 6500, categoryLabel: "Use MegaMerge 6500 Times", rewards: .init(gems: 2500)),
        // Tiers 21-22
        .init(milestone: 8250, categoryLabel: "Use MegaMerge 8250 Times", rewards: .init(hammers: 3)),
        .init(milestone: 10000, categoryLabel: "Use MegaMerge 10000 Times", rewards: .init(spins: 1, hammers: 1, magnets: 1, swaps: 1, boost2x: 1, boost3x: 1, boost4x: 1))
    ]

    private static let spinUseTiers: [ComboTierDefinition] = [
        // Tiers 1-11 (existing)
        .init(milestone: 5, categoryLabel: "Use Spin 5 Times", rewards: .init(gems: 25)),
        .init(milestone: 10, categoryLabel: "Use Spin 10 Times", rewards: .init(gems: 20, magnets: 1)),
        .init(milestone: 15, categoryLabel: "Use Spin 15 Times", rewards: .init(gems: 100, boost4x: 1)),
        .init(milestone: 20, categoryLabel: "Use Spin 20 Times", rewards: .init(gems: 25, spins: 2)),
        .init(milestone: 30, categoryLabel: "Use Spin 30 Times", rewards: .init(gems: 50, hammers: 1, magnets: 1, swaps: 1)),
        .init(milestone: 40, categoryLabel: "Use Spin 40 Times", rewards: .init(gems: 500)),
        .init(milestone: 50, categoryLabel: "Use Spin 50 Times", rewards: .init(boost2x: 1, boost3x: 1, boost4x: 1)),
        .init(milestone: 75, categoryLabel: "Use Spin 75 Times", rewards: .init(gems: 500, boost2x: 1)),
        .init(milestone: 100, categoryLabel: "Use Spin 100 Times", rewards: .init(gems: 500, hammers: 1, magnets: 1, boost3x: 1)),
        .init(milestone: 150, categoryLabel: "Use Spin 150 Times", rewards: .init(gems: 500, spins: 1, hammers: 1, swaps: 1, boost2x: 1)),
        .init(milestone: 200, categoryLabel: "Use Spin 200 Times", rewards: .init(spins: 1, hammers: 1, magnets: 1, swaps: 1, boost3x: 1)),
        // Tiers 12-30 (extended)
        .init(milestone: 250, categoryLabel: "Use Spin 250 Times", rewards: .init(gems: 750)),
        .init(milestone: 300, categoryLabel: "Use Spin 300 Times", rewards: .init(gems: 765, magnets: 1)),
        .init(milestone: 350, categoryLabel: "Use Spin 350 Times", rewards: .init(gems: 800, spins: 1, boost2x: 1)),
        .init(milestone: 400, categoryLabel: "Use Spin 400 Times", rewards: .init(magnets: 1)),
        .init(milestone: 450, categoryLabel: "Use Spin 450 Times", rewards: .init(boost4x: 1)),
        .init(milestone: 500, categoryLabel: "Use Spin 500 Times", rewards: .init(gems: 500, spins: 1, hammers: 1, magnets: 1, swaps: 1, boost2x: 1, boost3x: 1)),
        .init(milestone: 600, categoryLabel: "Use Spin 600 Times", rewards: .init(hammers: 3)),
        .init(milestone: 700, categoryLabel: "Use Spin 700 Times", rewards: .init(swaps: 3)),
        .init(milestone: 800, categoryLabel: "Use Spin 800 Times", rewards: .init(magnets: 3)),
        .init(milestone: 900, categoryLabel: "Use Spin 900 Times", rewards: .init(gems: 350, spins: 3, boost3x: 1)),
        .init(milestone: 1000, categoryLabel: "Use Spin 1000 Times", rewards: .init(boost2x: 1)),
        .init(milestone: 1100, categoryLabel: "Use Spin 1100 Times", rewards: .init(boost3x: 1)),
        .init(milestone: 1250, categoryLabel: "Use Spin 1250 Times", rewards: .init(spins: 2, hammers: 2, swaps: 2, boost2x: 1)),
        .init(milestone: 1500, categoryLabel: "Use Spin 1500 Times", rewards: .init(magnets: 3, boost3x: 1)),
        .init(milestone: 1750, categoryLabel: "Use Spin 1750 Times", rewards: .init(gems: 780, spins: 2, boost4x: 1)),
        .init(milestone: 2000, categoryLabel: "Use Spin 2000 Times", rewards: .init(gems: 800, magnets: 1)),
        .init(milestone: 3000, categoryLabel: "Use Spin 3000 Times", rewards: .init(gems: 850, magnets: 1, swaps: 1)),
        .init(milestone: 5000, categoryLabel: "Use Spin 5000 Times", rewards: .init(gems: 900, boost2x: 1)),
        .init(milestone: 10000, categoryLabel: "Use Spin 10000 Times", rewards: .init(gems: 1000))
    ]
    
    private static let surviveMovesTiers: [ComboTierDefinition] = [
        .init(milestone: 25, categoryLabel: "25 Moves", rewards: .init(gems: 25)),
        .init(milestone: 50, categoryLabel: "50 Moves", rewards: .init(gems: 50)),
        .init(milestone: 150, categoryLabel: "150 Moves", rewards: .init(gems: 100, hammers: 1)),
        .init(milestone: 300, categoryLabel: "300 Moves", rewards: .init(gems: 150, magnets: 1)),
        .init(milestone: 500, categoryLabel: "500 Moves", rewards: .init(gems: 400, spins: 1)),
        .init(milestone: 1000, categoryLabel: "1000 Moves", rewards: .init(gems: 400, spins: nil, hammers: nil, magnets: nil, swaps: 1, boost2x: nil, boost3x: nil, boost4x: 1)),
        .init(milestone: 2000, categoryLabel: "2000 Moves", rewards: .init(gems: 500, spins: 1, hammers: nil, magnets: nil, swaps: 1, boost2x: 1, boost3x: 1, boost4x: nil)),
        .init(milestone: 3000, categoryLabel: "3000 Moves", rewards: .init(gems: 750, spins: 2)),
        .init(milestone: 5000, categoryLabel: "5000 Moves", rewards: .init(gems: nil, spins: 1, hammers: 1, magnets: 1, swaps: 1, boost2x: 1, boost3x: 1, boost4x: 1)),
        .init(milestone: 7500, categoryLabel: "7500 Moves", rewards: .init(gems: 850, spins: 1, hammers: 1, magnets: nil, swaps: nil, boost2x: nil, boost3x: nil, boost4x: 1)),
        .init(milestone: 10000, categoryLabel: "10000 Moves", rewards: .init(gems: 885, spins: 2, swaps: 1)),
        .init(milestone: 20000, categoryLabel: "20000 Moves", rewards: .init(gems: 955, spins: 1, magnets: 2)),
        .init(milestone: 50000, categoryLabel: "50000 Moves", rewards: .init(gems: 1100, spins: 1, swaps: 2))
    ]

    private static let playtimeTiers: [ComboTierDefinition] = [
        // Tiers 1-14 (existing)
        .init(milestone: 5, categoryLabel: "5 min", rewards: .init(gems: 20)),
        .init(milestone: 10, categoryLabel: "10 min", rewards: .init(gems: 25, swaps: 1)),
        .init(milestone: 15, categoryLabel: "15 min", rewards: .init(gems: 30, hammers: 1)),
        .init(milestone: 20, categoryLabel: "20 min", rewards: .init(gems: 40, magnets: 1)),
        .init(milestone: 30, categoryLabel: "30 min", rewards: .init(magnets: 1)),
        .init(milestone: 60, categoryLabel: "1 hr", rewards: .init(boost3x: 1)),
        .init(milestone: 120, categoryLabel: "2 hr", rewards: .init(boost4x: 1)),
        .init(milestone: 240, categoryLabel: "4 hr", rewards: .init(gems: 100, magnets: 1, boost2x: 1)),
        .init(milestone: 480, categoryLabel: "8 hr", rewards: .init(gems: 70, spins: 1, hammers: 1)),
        .init(milestone: 720, categoryLabel: "12 hr", rewards: .init(spins: 1, boost4x: 1)),
        .init(milestone: 1440, categoryLabel: "24 hr", rewards: .init(gems: 1000)),
        .init(milestone: 2880, categoryLabel: "48 hr", rewards: .init(gems: 2000)),
        .init(milestone: 4320, categoryLabel: "72 hr", rewards: .init(gems: 3000)),
        .init(milestone: 5760, categoryLabel: "96 hr", rewards: .init(magnets: 1)),
        // Tiers 15-17 (kept)
        .init(milestone: 7200, categoryLabel: "120 hr", rewards: .init(gems: 5000)),
        .init(milestone: 8640, categoryLabel: "144 hr", rewards: .init(gems: 6000)),
        .init(milestone: 10080, categoryLabel: "168 hr", rewards: .init(gems: 7000)),
        // Tiers 18-23 (new day-based tiers)
        .init(milestone: 11520, categoryLabel: "8 days", rewards: .init(gems: 8300)),
        .init(milestone: 12960, categoryLabel: "9 days", rewards: .init(swaps: 1)),
        .init(milestone: 14400, categoryLabel: "10 days", rewards: .init(gems: 5500, hammers: 1)),
        .init(milestone: 15840, categoryLabel: "11 days", rewards: .init(magnets: 2, boost3x: 1)),
        .init(milestone: 17280, categoryLabel: "12 days", rewards: .init(gems: 6000)),
        .init(milestone: 18720, categoryLabel: "13 days", rewards: .init(magnets: 1, boost2x: 1)),
        // Tier 24 (kept 14 day tier)
        .init(milestone: 20160, categoryLabel: "14 days", rewards: .init(gems: 14000)),
        // Tiers 25-30 (new day-based tiers)
        .init(milestone: 21600, categoryLabel: "15 days", rewards: .init(spins: 1, swaps: 1, boost2x: 1)),
        .init(milestone: 23040, categoryLabel: "16 days", rewards: .init(magnets: 1, boost3x: 1)),
        .init(milestone: 24480, categoryLabel: "17 days", rewards: .init(gems: 9300, magnets: 1)),
        .init(milestone: 25920, categoryLabel: "18 days", rewards: .init(magnets: 1, swaps: 1)),
        .init(milestone: 27360, categoryLabel: "19 days", rewards: .init(gems: 8500, hammers: 1)),
        .init(milestone: 30240, categoryLabel: "21 days", rewards: .init(magnets: 3, boost3x: 1))
    ]
    
    private static let infinityTiers: [ComboTierDefinition] = [
        .init(milestone: 5, categoryLabel: "5 infinities", rewards: .init(gems: 500)),
        .init(milestone: 15, categoryLabel: "15 infinities", rewards: .init(gems: 625, swaps: 1)),
        .init(milestone: 25, categoryLabel: "25 infinities", rewards: .init(gems: 730, hammers: 1)),
        .init(milestone: 50, categoryLabel: "50 infinities", rewards: .init(gems: 840, magnets: 1)),
        .init(milestone: 150, categoryLabel: "150 infinities", rewards: .init(gems: 1100, magnets: 1)),
        .init(milestone: 250, categoryLabel: "250 infinities", rewards: .init(gems: 1200, boost3x: 1)),
        .init(milestone: 500, categoryLabel: "500 infinities", rewards: .init(boost2x: 1, boost3x: 1, boost4x: 1)),
        .init(milestone: 1000, categoryLabel: "1000 infinities", rewards: .init(gems: 1500, boost4x: 1)),
        .init(milestone: 2000, categoryLabel: "2000 infinities", rewards: .init(gems: 2500, magnets: 1, boost2x: 1)),
        .init(milestone: 3000, categoryLabel: "3000 infinities", rewards: .init(gems: 3270, spins: 1, hammers: 1)),
        .init(milestone: 5000, categoryLabel: "5000 infinities", rewards: .init(spins: 3, hammers: 2, magnets: 2, boost3x: 1, boost4x: 1)),
        .init(milestone: 10000, categoryLabel: "10000 infinities", rewards: .init(gems: 5000))
    ]

    private static let boost2xUseTiers: [ComboTierDefinition] = [
        .init(milestone: 5, categoryLabel: "5 uses", rewards: .init(gems: 400)),
        .init(milestone: 10, categoryLabel: "10 uses", rewards: .init(magnets: 1)),
        .init(milestone: 15, categoryLabel: "15 uses", rewards: .init(gems: 800)),
        .init(milestone: 30, categoryLabel: "30 uses", rewards: .init(gems: 1000, hammers: 1)),
        .init(milestone: 50, categoryLabel: "50 uses", rewards: .init(gems: 1300)),
        .init(milestone: 100, categoryLabel: "100 uses", rewards: .init(spins: 1)),
        .init(milestone: 200, categoryLabel: "200 uses", rewards: .init(gems: 3000))
    ]

    private static let boost3xUseTiers: [ComboTierDefinition] = [
        .init(milestone: 5, categoryLabel: "5 uses", rewards: .init(gems: 600)),
        .init(milestone: 10, categoryLabel: "10 uses", rewards: .init(gems: 750, magnets: 1)),
        .init(milestone: 20, categoryLabel: "20 uses", rewards: .init(gems: 1100, hammers: 1)),
        .init(milestone: 50, categoryLabel: "50 uses", rewards: .init(gems: 1600, hammers: 1)),
        .init(milestone: 100, categoryLabel: "100 uses", rewards: .init(gems: 2300)),
        .init(milestone: 150, categoryLabel: "150 uses", rewards: .init(gems: 3125, spins: 1, boost3x: 1)),
        .init(milestone: 200, categoryLabel: "200 uses", rewards: .init(gems: 3000, spins: 1, hammers: 1, magnets: 1, swaps: 1, boost2x: 1, boost3x: 1, boost4x: 1)),
        .init(milestone: 250, categoryLabel: "250 uses", rewards: .init(gems: 5000))
    ]

    private static let boost4xUseTiers: [ComboTierDefinition] = [
        .init(milestone: 5, categoryLabel: "5 uses", rewards: .init(gems: 400, spins: 1)),
        .init(milestone: 15, categoryLabel: "15 uses", rewards: .init(gems: 900)),
        .init(milestone: 30, categoryLabel: "30 uses", rewards: .init(gems: 1150, magnets: 1)),
        .init(milestone: 50, categoryLabel: "50 uses", rewards: .init(gems: 1800, hammers: 1)),
        .init(milestone: 100, categoryLabel: "100 uses", rewards: .init(gems: 2100, swaps: 1)),
        .init(milestone: 200, categoryLabel: "200 uses", rewards: .init(gems: 2700)),
        .init(milestone: 300, categoryLabel: "300 uses", rewards: .init(gems: 3210, spins: 1, boost3x: 1)),
        .init(milestone: 400, categoryLabel: "400 uses", rewards: .init(gems: 3500, hammers: 2, magnets: 1))
    ]

    private static let spinPurchaseTiers: [ComboTierDefinition] = [
        .init(milestone: 1, categoryLabel: "1 purchase", rewards: .init(gems: 10)),
        .init(milestone: 3, categoryLabel: "3 purchases", rewards: .init(gems: 25, hammers: 1)),
        .init(milestone: 5, categoryLabel: "5 purchases", rewards: .init(gems: 50)),
        .init(milestone: 10, categoryLabel: "10 purchases", rewards: .init(gems: 85, spins: 1)),
        .init(milestone: 25, categoryLabel: "25 purchases", rewards: .init(gems: 150, swaps: 1)),
        .init(milestone: 50, categoryLabel: "50 purchases", rewards: .init(gems: 210, spins: 1, boost4x: 1)),
        .init(milestone: 100, categoryLabel: "100 purchases", rewards: .init(gems: 350, magnets: 1)),
        .init(milestone: 200, categoryLabel: "200 purchases", rewards: .init(gems: 500)),
        .init(milestone: 500, categoryLabel: "500 purchases", rewards: .init(gems: 975, magnets: 1)),
        .init(milestone: 1000, categoryLabel: "1000 purchases", rewards: .init(swaps: 3, boost3x: 1)),
        .init(milestone: 2000, categoryLabel: "2000 purchases", rewards: .init(gems: 2000, spins: 2, hammers: 1, magnets: 2))
    ]

    private static let dailyClaimsTiers: [ComboTierDefinition] = [
        .init(milestone: 1, categoryLabel: "1 day", rewards: .init(gems: 5)),
        .init(milestone: 2, categoryLabel: "2 days", rewards: .init(gems: 10)),
        .init(milestone: 3, categoryLabel: "3 days", rewards: .init(hammers: 1)),
        .init(milestone: 5, categoryLabel: "5 days", rewards: .init(gems: 25)),
        .init(milestone: 7, categoryLabel: "7 days", rewards: .init(gems: 35, swaps: 1)),
        .init(milestone: 10, categoryLabel: "10 days", rewards: .init(gems: 23, spins: 1, boost3x: 1)),
        .init(milestone: 14, categoryLabel: "14 days", rewards: .init(gems: 35, magnets: 1, boost2x: 1, boost3x: 1)),
        .init(milestone: 21, categoryLabel: "21 days", rewards: .init(gems: 50)),
        .init(milestone: 30, categoryLabel: "30 days", rewards: .init(magnets: 1)),
        .init(milestone: 98, categoryLabel: "98 days", rewards: .init(boost2x: 1)),
        .init(milestone: 365, categoryLabel: "365 days", rewards: .init(gems: 1000))
    ]

    private static let boost5xUseTiers: [ComboTierDefinition] = [
        .init(milestone: 1, categoryLabel: "1 use", rewards: .init(gems: 250)),
        .init(milestone: 3, categoryLabel: "3 uses", rewards: .init(gems: 750)),
        .init(milestone: 5, categoryLabel: "5 uses", rewards: .init(magnets: 1)),
        .init(milestone: 10, categoryLabel: "10 uses", rewards: .init(gems: 600, boost4x: 1)),
        .init(milestone: 25, categoryLabel: "25 uses", rewards: .init(boost2x: 1, boost3x: 1, boost4x: 1)),
        .init(milestone: 50, categoryLabel: "50 uses", rewards: .init(gems: 1500))
    ]

    private static let boost20xUseTiers: [ComboTierDefinition] = [
        .init(milestone: 1, categoryLabel: "1 use", rewards: .init(gems: 650)),
        .init(milestone: 2, categoryLabel: "2 uses", rewards: .init(magnets: 1)),
        .init(milestone: 3, categoryLabel: "3 uses", rewards: .init(boost4x: 1)),
        .init(milestone: 5, categoryLabel: "5 uses", rewards: .init(gems: 1000, hammers: 1)),
        .init(milestone: 7, categoryLabel: "7 uses", rewards: .init(boost3x: 1)),
        .init(milestone: 10, categoryLabel: "10 uses", rewards: .init(spins: 1)),
        .init(milestone: 15, categoryLabel: "15 uses", rewards: .init(swaps: 1)),
        .init(milestone: 20, categoryLabel: "20 uses", rewards: .init(gems: 1000, magnets: 1, boost3x: 1)),
        .init(milestone: 27, categoryLabel: "27 uses", rewards: .init(gems: 1100)),
        .init(milestone: 35, categoryLabel: "35 uses", rewards: .init(magnets: 2)),
        .init(milestone: 45, categoryLabel: "45 uses", rewards: .init(gems: 1200)),
        .init(milestone: 55, categoryLabel: "55 uses", rewards: .init(gems: 1300)),
        .init(milestone: 70, categoryLabel: "70 uses", rewards: .init(gems: 1350, swaps: 1)),
        .init(milestone: 85, categoryLabel: "85 uses", rewards: .init(gems: 1450)),
        .init(milestone: 100, categoryLabel: "100 uses", rewards: .init(spins: 4))
    ]

    private static let wheelCollectsTiers: [ComboTierDefinition] = [
        .init(milestone: 3, categoryLabel: "3 collects", rewards: .init(gems: 50)),
        .init(milestone: 5, categoryLabel: "5 collects", rewards: .init(gems: 80, swaps: 1)),
        .init(milestone: 10, categoryLabel: "10 collects", rewards: .init(gems: 80, boost4x: 1)),
        .init(milestone: 25, categoryLabel: "25 collects", rewards: .init(magnets: 1, boost4x: 1)),
        .init(milestone: 50, categoryLabel: "50 collects", rewards: .init(gems: 500)),
        .init(milestone: 100, categoryLabel: "100 collects", rewards: .init(gems: 1000)),
        .init(milestone: 250, categoryLabel: "250 collects", rewards: .init(gems: 1500, hammers: 1, magnets: 2)),
        .init(milestone: 500, categoryLabel: "500 collects", rewards: .init(gems: 4500))
    ]

    private static let challengeCreationTiers: [ComboTierDefinition] = [
        .init(milestone: 10, categoryLabel: "Create & complete 10", rewards: .init(gems: 100)),
        .init(milestone: 20, categoryLabel: "Create & complete 20", rewards: .init(gems: 200)),
        .init(milestone: 35, categoryLabel: "Create & complete 35", rewards: .init(gems: 300, hammers: 1)),
        .init(milestone: 50, categoryLabel: "Create & complete 50", rewards: .init(gems: 400, swaps: 1)),
        .init(milestone: 75, categoryLabel: "Create & complete 75", rewards: .init(gems: 500, magnets: 1)),
        .init(milestone: 100, categoryLabel: "Create & complete 100", rewards: .init(boost4x: 1)),
        .init(milestone: 150, categoryLabel: "Create & complete 150", rewards: .init(gems: 500, magnets: 1, boost2x: 1)),
        .init(milestone: 200, categoryLabel: "Create & complete 200", rewards: .init(gems: 700, spins: 1, magnets: 1, boost3x: 1))
    ]
    
    /// Current tier index for the moves progression achievement (persisted)
    public var movesProgressionTier: Int {
        didSet {
            defaults.set(movesProgressionTier, forKey: "movesProgressionTier")
            // Reset unlock state when tier advances
            unlocks["moves_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    /// Get current moves tier info
    public var currentMovesTier: (label: String, value: Double) {
        let index = min(movesProgressionTier, Self.movesTiers.count - 1)
        return Self.movesTiers[index]
    }
    
    /// Check if moves progression is at max tier
    public var isMovesProgressionMaxed: Bool {
        movesProgressionTier >= Self.movesTiers.count - 1
    }
    
    /// Combo 6-10 tier index (persisted)
    public var combo610Tier: Int {
        didSet {
            defaults.set(combo610Tier, forKey: "combo610Tier")
            unlocks["combo_6_10"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    private var currentCombo610Tier: ComboTierDefinition {
        let index = min(combo610Tier, Self.combo610Tiers.count - 1)
        return Self.combo610Tiers[index]
    }
    
    public var combo610Display: ProgressTierDisplay {
        let tier = currentCombo610Tier
        return makeComboDisplay(
            rangeLabel: "6-10",
            tier: tier,
            levelIndex: combo610Tier,
            maxCount: Self.combo610Tiers.count,
            isMaxed: isCombo610Maxed
        )
    }
    
    public var isCombo610Maxed: Bool {
        combo610Tier >= Self.combo610Tiers.count - 1
    }
    
    /// Combo 11-15 tier index (persisted)
    public var combo1115Tier: Int {
        didSet {
            defaults.set(combo1115Tier, forKey: "combo1115Tier")
            unlocks["combo_11_15"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    private var currentCombo1115Tier: ComboTierDefinition {
        let index = min(combo1115Tier, Self.combo1115Tiers.count - 1)
        return Self.combo1115Tiers[index]
    }
    
    public var combo1115Display: ProgressTierDisplay {
        let tier = currentCombo1115Tier
        return makeComboDisplay(
            rangeLabel: "11-15",
            tier: tier,
            levelIndex: combo1115Tier,
            maxCount: Self.combo1115Tiers.count,
            isMaxed: isCombo1115Maxed
        )
    }
    
    public var isCombo1115Maxed: Bool {
        combo1115Tier >= Self.combo1115Tiers.count - 1
    }
    
    /// Combo 16-20 tier index (persisted)
    public var combo1620Tier: Int {
        didSet {
            defaults.set(combo1620Tier, forKey: "combo1620Tier")
            unlocks["combo_16_20"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    private var currentCombo1620Tier: ComboTierDefinition {
        let index = min(combo1620Tier, Self.combo1620Tiers.count - 1)
        return Self.combo1620Tiers[index]
    }
    
    public var combo1620Display: ProgressTierDisplay {
        let tier = currentCombo1620Tier
        return makeComboDisplay(
            rangeLabel: "16-20",
            tier: tier,
            levelIndex: combo1620Tier,
            maxCount: Self.combo1620Tiers.count,
            isMaxed: isCombo1620Maxed
        )
    }
    
    public var isCombo1620Maxed: Bool {
        combo1620Tier >= Self.combo1620Tiers.count - 1
    }
    
    /// Combo 21-30 tier index (persisted)
    public var combo2130Tier: Int {
        didSet {
            defaults.set(combo2130Tier, forKey: "combo2130Tier")
            unlocks["combo_21_30"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    private var currentCombo2130Tier: ComboTierDefinition {
        let index = min(combo2130Tier, Self.combo2130Tiers.count - 1)
        return Self.combo2130Tiers[index]
    }
    
    public var combo2130Display: ProgressTierDisplay {
        let tier = currentCombo2130Tier
        return makeComboDisplay(
            rangeLabel: "21-30",
            tier: tier,
            levelIndex: combo2130Tier,
            maxCount: Self.combo2130Tiers.count,
            isMaxed: isCombo2130Maxed
        )
    }
    
    public var isCombo2130Maxed: Bool {
        combo2130Tier >= Self.combo2130Tiers.count - 1
    }
    
    /// Merge progression tier index (persisted)
    public var mergeProgressionTier: Int {
        didSet {
            defaults.set(mergeProgressionTier, forKey: "mergeProgressionTier")
            unlocks["merge_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    private var currentMergeTier: ComboTierDefinition {
        let index = min(mergeProgressionTier, Self.mergeTiers.count - 1)
        return Self.mergeTiers[index]
    }
    
    public var mergeDisplay: ProgressTierDisplay {
        let tier = currentMergeTier
        return makeMergeDisplay(tier: tier, levelIndex: mergeProgressionTier, isMaxed: isMergeProgressionMaxed)
    }
    
    public var isMergeProgressionMaxed: Bool {
        mergeProgressionTier >= Self.mergeTiers.count - 1
    }
    
    /// Swap usage progression tier index (persisted)
    public var swapUsesProgressionTier: Int {
        didSet {
            defaults.set(swapUsesProgressionTier, forKey: "swapUsesProgressionTier")
            unlocks["swap_usage_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    private var currentSwapUsesTier: ComboTierDefinition {
        let index = min(swapUsesProgressionTier, Self.swapUseTiers.count - 1)
        return Self.swapUseTiers[index]
    }
    
    public var swapUsesDisplay: ProgressTierDisplay {
        makePowerUseDisplay(
            powerUpLabel: "Swap",
            tier: currentSwapUsesTier,
            levelIndex: swapUsesProgressionTier,
            maxCount: Self.swapUseTiers.count,
            isMaxed: isSwapUsesProgressionMaxed
        )
    }
    
    public var isSwapUsesProgressionMaxed: Bool {
        swapUsesProgressionTier >= Self.swapUseTiers.count - 1
    }
    
    /// Hammer usage progression tier index (persisted)
    public var hammerUsesProgressionTier: Int {
        didSet {
            defaults.set(hammerUsesProgressionTier, forKey: "hammerUsesProgressionTier")
            unlocks["hammer_usage_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    private var currentHammerUsesTier: ComboTierDefinition {
        let index = min(hammerUsesProgressionTier, Self.hammerUseTiers.count - 1)
        return Self.hammerUseTiers[index]
    }
    
    public var hammerUsesDisplay: ProgressTierDisplay {
        makePowerUseDisplay(
            powerUpLabel: "Hammer",
            tier: currentHammerUsesTier,
            levelIndex: hammerUsesProgressionTier,
            maxCount: Self.hammerUseTiers.count,
            isMaxed: isHammerUsesProgressionMaxed
        )
    }
    
    public var isHammerUsesProgressionMaxed: Bool {
        hammerUsesProgressionTier >= Self.hammerUseTiers.count - 1
    }
    
    /// MegaMerge (magnet) usage progression tier index (persisted)
    public var magnetUsesProgressionTier: Int {
        didSet {
            defaults.set(magnetUsesProgressionTier, forKey: "magnetUsesProgressionTier")
            unlocks["magnet_usage_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    private var currentMagnetUsesTier: ComboTierDefinition {
        let index = min(magnetUsesProgressionTier, Self.magnetUseTiers.count - 1)
        return Self.magnetUseTiers[index]
    }
    
    public var magnetUsesDisplay: ProgressTierDisplay {
        makePowerUseDisplay(
            powerUpLabel: "MegaMerge",
            tier: currentMagnetUsesTier,
            levelIndex: magnetUsesProgressionTier,
            maxCount: Self.magnetUseTiers.count,
            isMaxed: isMagnetUsesProgressionMaxed
        )
    }
    
    public var isMagnetUsesProgressionMaxed: Bool {
        magnetUsesProgressionTier >= Self.magnetUseTiers.count - 1
    }
    
    /// Spin usage progression tier index (persisted)
    public var spinUsesProgressionTier: Int {
        didSet {
            defaults.set(spinUsesProgressionTier, forKey: "spinUsesProgressionTier")
            unlocks["spin_usage_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    private var currentSpinUsesTier: ComboTierDefinition {
        let index = min(spinUsesProgressionTier, Self.spinUseTiers.count - 1)
        return Self.spinUseTiers[index]
    }
    
    public var spinUsesDisplay: ProgressTierDisplay {
        makePowerUseDisplay(
            powerUpLabel: "Spin",
            tier: currentSpinUsesTier,
            levelIndex: spinUsesProgressionTier,
            maxCount: Self.spinUseTiers.count,
            isMaxed: isSpinUsesProgressionMaxed
        )
    }
    
    public var isSpinUsesProgressionMaxed: Bool {
        spinUsesProgressionTier >= Self.spinUseTiers.count - 1
    }
    
    /// Survive-moves progression tier index (persisted)
    public var surviveMovesProgressionTier: Int {
        didSet {
            defaults.set(surviveMovesProgressionTier, forKey: "surviveMovesProgressionTier")
            unlocks["survive_moves_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    private var currentSurviveMovesTier: ComboTierDefinition {
        let index = min(surviveMovesProgressionTier, Self.surviveMovesTiers.count - 1)
        return Self.surviveMovesTiers[index]
    }
    
    public var surviveMovesDisplay: ProgressTierDisplay {
        let tier = currentSurviveMovesTier
        let clampedIndex = min(surviveMovesProgressionTier, Self.surviveMovesTiers.count - 1)
        let level = clampedIndex + 1
        let isMaxed = surviveMovesProgressionTier >= Self.surviveMovesTiers.count - 1
        let description = isMaxed
            ? "You've mastered surviving moves. Claim your final reward."
            : "Survive \(tier.milestone) moves across all games to unlock the next level."
        let title = "Level \(level): Survive \(tier.milestone) moves"
        return ProgressTierDisplay(
            milestone: tier.milestone,
            level: level,
            title: title,
            description: description,
            categoryLabel: tier.categoryLabel,
            rewards: tier.rewards
        )
    }
    
    public var isSurviveMovesProgressionMaxed: Bool {
        surviveMovesProgressionTier >= Self.surviveMovesTiers.count - 1
    }
    
    /// Playtime progression tier index (persisted)
    public var playtimeProgressionTier: Int {
        didSet {
            defaults.set(playtimeProgressionTier, forKey: "playtimeProgressionTier")
            unlocks["playtime_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    private var currentPlaytimeTier: ComboTierDefinition {
        let index = min(playtimeProgressionTier, Self.playtimeTiers.count - 1)
        return Self.playtimeTiers[index]
    }
    
    public var playtimeDisplay: ProgressTierDisplay {
        let tier = currentPlaytimeTier
        let clampedIndex = min(playtimeProgressionTier, Self.playtimeTiers.count - 1)
        let level = clampedIndex + 1
        let isMaxed = playtimeProgressionTier >= Self.playtimeTiers.count - 1
        let description = isMaxed
            ? "You've mastered playtime. Claim your final reward."
            : "Accumulate \(tier.milestone) minutes of total play to reach the next tier."
        let title = "Level \(level): \(tier.milestone) min played"
        return ProgressTierDisplay(
            milestone: tier.milestone,
            level: level,
            title: title,
            description: description,
            categoryLabel: "Playtime",
            rewards: tier.rewards
        )
    }
    
    public var isPlaytimeProgressionMaxed: Bool {
        playtimeProgressionTier >= Self.playtimeTiers.count - 1
    }
    
    /// Infinity creation progression tier index (persisted)
    public var infinityProgressionTier: Int {
        didSet {
            defaults.set(infinityProgressionTier, forKey: "infinityProgressionTier")
            unlocks["infinity_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    private var currentInfinityTier: ComboTierDefinition {
        let index = min(infinityProgressionTier, Self.infinityTiers.count - 1)
        return Self.infinityTiers[index]
    }
    
    public var infinityDisplay: ProgressTierDisplay {
        let tier = currentInfinityTier
        let clampedIndex = min(infinityProgressionTier, Self.infinityTiers.count - 1)
        let level = clampedIndex + 1
        let isMaxed = infinityProgressionTier >= Self.infinityTiers.count - 1
        let description = isMaxed
            ? "You've mastered creating infinity tiles. Claim your final reward."
            : "Create \(tier.milestone) infinity tiles to reach the next tier."
        let title = "Level \(level): \(tier.milestone) infinities"
        return ProgressTierDisplay(
            milestone: tier.milestone,
            level: level,
            title: title,
            description: description,
            categoryLabel: "Infinity",
            rewards: tier.rewards
        )
    }
    
    public var isInfinityProgressionMaxed: Bool {
        infinityProgressionTier >= Self.infinityTiers.count - 1
    }

    /// 2X Boost usage progression tier index (persisted)
    public var boost2xUsesProgressionTier: Int {
        didSet {
            defaults.set(boost2xUsesProgressionTier, forKey: "boost2xUsesProgressionTier")
            unlocks["boost2x_usage_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }

    private var currentBoost2xUsesTier: ComboTierDefinition {
        let index = min(boost2xUsesProgressionTier, Self.boost2xUseTiers.count - 1)
        return Self.boost2xUseTiers[index]
    }

    public var boost2xUsesDisplay: ProgressTierDisplay {
        let tier = currentBoost2xUsesTier
        let clampedIndex = min(boost2xUsesProgressionTier, Self.boost2xUseTiers.count - 1)
        let level = clampedIndex + 1
        let isMaxed = boost2xUsesProgressionTier >= Self.boost2xUseTiers.count - 1
        let description = isMaxed
            ? "You've mastered using 2X Boosts. Claim your final reward."
            : "Use 2X Boost \(tier.milestone) times to reach the next tier."
        let title = "Level \(level): \(tier.milestone) uses"
        return ProgressTierDisplay(
            milestone: tier.milestone,
            level: level,
            title: title,
            description: description,
            categoryLabel: "2X Boost",
            rewards: tier.rewards
        )
    }

    public var isBoost2xUsesProgressionMaxed: Bool {
        boost2xUsesProgressionTier >= Self.boost2xUseTiers.count - 1
    }

    /// 3X Boost usage progression tier index (persisted)
    public var boost3xUsesProgressionTier: Int {
        didSet {
            defaults.set(boost3xUsesProgressionTier, forKey: "boost3xUsesProgressionTier")
            unlocks["boost3x_usage_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }

    private var currentBoost3xUsesTier: ComboTierDefinition {
        let index = min(boost3xUsesProgressionTier, Self.boost3xUseTiers.count - 1)
        return Self.boost3xUseTiers[index]
    }

    public var boost3xUsesDisplay: ProgressTierDisplay {
        let tier = currentBoost3xUsesTier
        let clampedIndex = min(boost3xUsesProgressionTier, Self.boost3xUseTiers.count - 1)
        let level = clampedIndex + 1
        let isMaxed = boost3xUsesProgressionTier >= Self.boost3xUseTiers.count - 1
        let description = isMaxed
            ? "You've mastered using 3X Boosts. Claim your final reward."
            : "Use 3X Boost \(tier.milestone) times to reach the next tier."
        let title = "Level \(level): \(tier.milestone) uses"
        return ProgressTierDisplay(
            milestone: tier.milestone,
            level: level,
            title: title,
            description: description,
            categoryLabel: "3X Boost",
            rewards: tier.rewards
        )
    }

    public var isBoost3xUsesProgressionMaxed: Bool {
        boost3xUsesProgressionTier >= Self.boost3xUseTiers.count - 1
    }

    /// 4X Boost usage progression tier index (persisted)
    public var boost4xUsesProgressionTier: Int {
        didSet {
            defaults.set(boost4xUsesProgressionTier, forKey: "boost4xUsesProgressionTier")
            unlocks["boost4x_usage_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }

    private var currentBoost4xUsesTier: ComboTierDefinition {
        let index = min(boost4xUsesProgressionTier, Self.boost4xUseTiers.count - 1)
        return Self.boost4xUseTiers[index]
    }

    public var boost4xUsesDisplay: ProgressTierDisplay {
        let tier = currentBoost4xUsesTier
        let clampedIndex = min(boost4xUsesProgressionTier, Self.boost4xUseTiers.count - 1)
        let level = clampedIndex + 1
        let isMaxed = boost4xUsesProgressionTier >= Self.boost4xUseTiers.count - 1
        let description = isMaxed
            ? "You've mastered using 4X Boosts. Claim your final reward."
            : "Use 4X Boost \(tier.milestone) times to reach the next tier."
        let title = "Level \(level): \(tier.milestone) uses"
        return ProgressTierDisplay(
            milestone: tier.milestone,
            level: level,
            title: title,
            description: description,
            categoryLabel: "4X Boost",
            rewards: tier.rewards
        )
    }

    public var isBoost4xUsesProgressionMaxed: Bool {
        boost4xUsesProgressionTier >= Self.boost4xUseTiers.count - 1
    }

    /// Spin purchase progression tier index (persisted)
    public var spinPurchasesProgressionTier: Int {
        didSet {
            defaults.set(spinPurchasesProgressionTier, forKey: "spinPurchasesProgressionTier")
            unlocks["spin_purchases_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }

    private var currentSpinPurchasesTier: ComboTierDefinition {
        let index = min(spinPurchasesProgressionTier, Self.spinPurchaseTiers.count - 1)
        return Self.spinPurchaseTiers[index]
    }

    public var spinPurchasesDisplay: ProgressTierDisplay {
        let tier = currentSpinPurchasesTier
        let clampedIndex = min(spinPurchasesProgressionTier, Self.spinPurchaseTiers.count - 1)
        let level = clampedIndex + 1
        let isMaxed = spinPurchasesProgressionTier >= Self.spinPurchaseTiers.count - 1
        let description = isMaxed
            ? "You've mastered buying spins. Claim your final reward."
            : "Buy \(tier.milestone) spin\(tier.milestone == 1 ? "" : "s") to reach the next tier."
        let title = "Level \(level): \(tier.milestone) purchase\(tier.milestone == 1 ? "" : "s")"
        return ProgressTierDisplay(
            milestone: tier.milestone,
            level: level,
            title: title,
            description: description,
            categoryLabel: "Buy Spins",
            rewards: tier.rewards
        )
    }

    public var isSpinPurchasesProgressionMaxed: Bool {
        spinPurchasesProgressionTier >= Self.spinPurchaseTiers.count - 1
    }

    /// Daily claims progression tier index (persisted)
    public var dailyClaimsProgressionTier: Int {
        didSet {
            defaults.set(dailyClaimsProgressionTier, forKey: "dailyClaimsProgressionTier")
            unlocks["daily_claims_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }

    private var currentDailyClaimsTier: ComboTierDefinition {
        let index = min(dailyClaimsProgressionTier, Self.dailyClaimsTiers.count - 1)
        return Self.dailyClaimsTiers[index]
    }

    public var dailyClaimsDisplay: ProgressTierDisplay {
        let tier = currentDailyClaimsTier
        let clampedIndex = min(dailyClaimsProgressionTier, Self.dailyClaimsTiers.count - 1)
        let level = clampedIndex + 1
        let isMaxed = dailyClaimsProgressionTier >= Self.dailyClaimsTiers.count - 1
        let description = isMaxed
            ? "You've claimed daily rewards for a full year! Claim your final reward."
            : "Claim daily rewards \(tier.milestone) time\(tier.milestone == 1 ? "" : "s") to reach the next tier."
        let title = "Level \(level): \(tier.milestone) day\(tier.milestone == 1 ? "" : "s")"
        return ProgressTierDisplay(
            milestone: tier.milestone,
            level: level,
            title: title,
            description: description,
            categoryLabel: "Daily Rewards",
            rewards: tier.rewards
        )
    }

    public var isDailyClaimsProgressionMaxed: Bool {
        dailyClaimsProgressionTier >= Self.dailyClaimsTiers.count - 1
    }

    /// 5X Score boost usage progression tier index (persisted)
    public var boost5xUsesProgressionTier: Int {
        didSet {
            defaults.set(boost5xUsesProgressionTier, forKey: "boost5xUsesProgressionTier")
            unlocks["boost5x_usage_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }

    private var currentBoost5xUsesTier: ComboTierDefinition {
        let index = min(boost5xUsesProgressionTier, Self.boost5xUseTiers.count - 1)
        return Self.boost5xUseTiers[index]
    }

    public var boost5xUsesDisplay: ProgressTierDisplay {
        let tier = currentBoost5xUsesTier
        let clampedIndex = min(boost5xUsesProgressionTier, Self.boost5xUseTiers.count - 1)
        let level = clampedIndex + 1
        let isMaxed = boost5xUsesProgressionTier >= Self.boost5xUseTiers.count - 1
        let description = isMaxed
            ? "You've mastered using 5X Score Boosts. Claim your final reward."
            : "Use 5X Score Boost \(tier.milestone) time\(tier.milestone == 1 ? "" : "s") to reach the next tier."
        let title = "Level \(level): \(tier.milestone) use\(tier.milestone == 1 ? "" : "s")"
        return ProgressTierDisplay(
            milestone: tier.milestone,
            level: level,
            title: title,
            description: description,
            categoryLabel: "5X Score",
            rewards: tier.rewards
        )
    }

    public var isBoost5xUsesProgressionMaxed: Bool {
        boost5xUsesProgressionTier >= Self.boost5xUseTiers.count - 1
    }

    /// 20X Score boost usage progression tier index (persisted)
    public var boost20xUsesProgressionTier: Int {
        didSet {
            defaults.set(boost20xUsesProgressionTier, forKey: "boost20xUsesProgressionTier")
            unlocks["boost20x_usage_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }

    private var currentBoost20xUsesTier: ComboTierDefinition {
        let index = min(boost20xUsesProgressionTier, Self.boost20xUseTiers.count - 1)
        return Self.boost20xUseTiers[index]
    }

    public var boost20xUsesDisplay: ProgressTierDisplay {
        let tier = currentBoost20xUsesTier
        let clampedIndex = min(boost20xUsesProgressionTier, Self.boost20xUseTiers.count - 1)
        let level = clampedIndex + 1
        let isMaxed = boost20xUsesProgressionTier >= Self.boost20xUseTiers.count - 1
        let description = isMaxed
            ? "You've mastered using 20X Score Boosts. Claim your final reward."
            : "Use 20X Score Boost \(tier.milestone) time\(tier.milestone == 1 ? "" : "s") to reach the next tier."
        let title = "Level \(level): \(tier.milestone) use\(tier.milestone == 1 ? "" : "s")"
        return ProgressTierDisplay(
            milestone: tier.milestone,
            level: level,
            title: title,
            description: description,
            categoryLabel: "20X Score",
            rewards: tier.rewards
        )
    }

    public var isBoost20xUsesProgressionMaxed: Bool {
        boost20xUsesProgressionTier >= Self.boost20xUseTiers.count - 1
    }

    /// Wheel collects progression tier index (persisted)
    public var wheelCollectsProgressionTier: Int {
        didSet {
            defaults.set(wheelCollectsProgressionTier, forKey: "wheelCollectsProgressionTier")
            unlocks["wheel_collects_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }

    private var currentWheelCollectsTier: ComboTierDefinition {
        let index = min(wheelCollectsProgressionTier, Self.wheelCollectsTiers.count - 1)
        return Self.wheelCollectsTiers[index]
    }

    public var wheelCollectsDisplay: ProgressTierDisplay {
        let tier = currentWheelCollectsTier
        let clampedIndex = min(wheelCollectsProgressionTier, Self.wheelCollectsTiers.count - 1)
        let level = clampedIndex + 1
        let isMaxed = wheelCollectsProgressionTier >= Self.wheelCollectsTiers.count - 1
        let description = isMaxed
            ? "You've mastered collecting from the wheel. Claim your final reward."
            : "Collect powerups from the wheel \(tier.milestone) time\(tier.milestone == 1 ? "" : "s") to reach the next tier."
        let title = "Level \(level): \(tier.milestone) collect\(tier.milestone == 1 ? "" : "s")"
        return ProgressTierDisplay(
            milestone: tier.milestone,
            level: level,
            title: title,
            description: description,
            categoryLabel: "Wheel Collects",
            rewards: tier.rewards
        )
    }

    public var isWheelCollectsProgressionMaxed: Bool {
        wheelCollectsProgressionTier >= Self.wheelCollectsTiers.count - 1
    }

    /// Challenge creation progression tier index (persisted)
    public var challengeCreationTier: Int {
        didSet {
            defaults.set(challengeCreationTier, forKey: "challengeCreationTier")
            unlocks["challenge_creation"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    private var currentChallengeCreationTier: ComboTierDefinition {
        let index = min(challengeCreationTier, Self.challengeCreationTiers.count - 1)
        return Self.challengeCreationTiers[index]
    }
    
    public var challengeCreationDisplay: ProgressTierDisplay {
        let tier = currentChallengeCreationTier
        let clampedIndex = min(challengeCreationTier, Self.challengeCreationTiers.count - 1)
        let level = clampedIndex + 1
        let isMaxed = challengeCreationTier >= Self.challengeCreationTiers.count - 1
        let description = isMaxed
            ? "You've mastered creating challenges. Claim your final reward."
            : "Create and complete \(tier.milestone) custom challenges to reach the next tier."
        let title = "Level \(level): \(tier.milestone) completed challenges"
        return ProgressTierDisplay(
            milestone: tier.milestone,
            level: level,
            title: title,
            description: description,
            categoryLabel: tier.categoryLabel,
            rewards: tier.rewards
        )
    }
    
    public var isChallengeCreationMaxed: Bool {
        challengeCreationTier >= Self.challengeCreationTiers.count - 1
    }
    
    private func makeComboDisplay(
        rangeLabel: String,
        tier: ComboTierDefinition,
        levelIndex: Int,
        maxCount: Int,
        isMaxed: Bool
    ) -> ProgressTierDisplay {
        let clampedIndex = min(levelIndex, maxCount - 1)
        let level = clampedIndex + 1
        let description: String
        if isMaxed {
            description = "You've reached the final combo milestone for \(rangeLabel) tiles. Claim your mastery reward."
        } else {
            description = "Trigger combos of \(rangeLabel) tiles \(tier.milestone) times across all games to unlock the next level."
        }
        let title = "Level \(level): \(tier.milestone) combos"
        return ProgressTierDisplay(
            milestone: tier.milestone,
            level: level,
            title: title,
            description: description,
            categoryLabel: tier.categoryLabel,
            rewards: tier.rewards
        )
    }
    
    private func makeMergeDisplay(
        tier: ComboTierDefinition,
        levelIndex: Int,
        isMaxed: Bool
    ) -> ProgressTierDisplay {
        let clampedIndex = min(levelIndex, Self.mergeTiers.count - 1)
        let level = clampedIndex + 1
        let description: String
        if isMaxed {
            description = "You've merged more tiles than anyone! Claim your final mastery reward."
        } else {
            description = "Merge \(tier.milestone) tiles in total to unlock the next reward."
        }
        let title = "Level \(level): Merge \(tier.milestone) tiles"
        return ProgressTierDisplay(
            milestone: tier.milestone,
            level: level,
            title: title,
            description: description,
            categoryLabel: tier.categoryLabel,
            rewards: tier.rewards
        )
    }
    
    private func makePowerUseDisplay(
        powerUpLabel: String,
        tier: ComboTierDefinition,
        levelIndex: Int,
        maxCount: Int,
        isMaxed: Bool
    ) -> ProgressTierDisplay {
        let clampedIndex = min(levelIndex, maxCount - 1)
        let level = clampedIndex + 1
        let description: String
        if isMaxed {
            description = "You've mastered the \(powerUpLabel.lowercased()) power-up. Claim your final reward."
        } else {
            description = "Use \(powerUpLabel.lowercased())s \(tier.milestone) times across all games to reach the next tier."
        }
        let title = "Level \(level): \(tier.milestone) \(powerUpLabel.lowercased()) uses"
        return ProgressTierDisplay(
            milestone: tier.milestone,
            level: level,
            title: title,
            description: description,
            categoryLabel: tier.categoryLabel,
            rewards: tier.rewards
        )
    }
    
    private func tileRewards(for definition: AchievementDef) -> AchievementDef.Rewards? {
        tileReward(forTier: tileProgressionTier) ?? definition.rewards
    }
    
    private func tileReward(forTier tierIndex: Int) -> AchievementDef.Rewards? {
        guard Self.tileTierRewards.indices.contains(tierIndex),
              let tierRewards = Self.tileTierRewards[tierIndex] else { return nil }
        return tierRewards
    }
    
    /// Current tier index for the tile progression achievement (persisted)
    public var tileProgressionTier: Int {
        didSet {
            defaults.set(tileProgressionTier, forKey: "tileProgressionTier")
            // Reset unlock state when tier advances
            unlocks["tile_progression"] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            saveUnlocks()
        }
    }
    
    /// Get current tile tier info
    public var currentTileTier: (suffix: String, label: String, value: Double) {
        let index = min(tileProgressionTier, Self.tileTiers.count - 1)
        return Self.tileTiers[index]
    }
    
    /// Check if tile progression is at max tier
    public var isTileProgressionMaxed: Bool {
        tileProgressionTier >= Self.tileTiers.count - 1
    }
    
    public var tileProgressionDisplay: ProgressTierDisplay {
        let tier = currentTileTier
        let level = min(tileProgressionTier, Self.tileTiers.count - 1) + 1
        let rewards = tileReward(forTier: tileProgressionTier) ?? AchievementDef.Rewards()
        let isMaxed = isTileProgressionMaxed
        let description = isMaxed
            ? "You've mastered tile creation. Claim your final reward."
            : "Reach tile \(tier.label) to unlock the next level."
        // Clamp tier.value to Int.max to prevent overflow for very large tile values (e.g., infinity)
        let safeMilestone = tier.value > Double(Int.max) ? Int.max : Int(tier.value)
        return ProgressTierDisplay(
            milestone: safeMilestone,
            level: level,
            title: "Level \(level): \(tier.label) tile",
            description: description,
            categoryLabel: "HighestTile",
            rewards: rewards
        )
    }
    
    public private(set) var catalog: [AchievementDef] = []
    public private(set) var unlocks: [String: UnlockState] = [:]
    public private(set) var lastEvaluatedSnapshot: GameSnapshot?
    
    private let gc = GameCenterManager.shared
    public var onReward: (@MainActor (AchievementDef.Rewards) -> Void)?
    private let defaults: UserDefaults
    
    private enum SnapshotDefaultsKey {
        static let lastSnapshot = "achievementLastSnapshot"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.tileProgressionTier = defaults.integer(forKey: "tileProgressionTier")
        self.movesProgressionTier = defaults.integer(forKey: "movesProgressionTier")
        self.combo610Tier = defaults.integer(forKey: "combo610Tier")
        self.combo1115Tier = defaults.integer(forKey: "combo1115Tier")
        self.combo1620Tier = defaults.integer(forKey: "combo1620Tier")
        self.combo2130Tier = defaults.integer(forKey: "combo2130Tier")
        self.mergeProgressionTier = defaults.integer(forKey: "mergeProgressionTier")
        self.swapUsesProgressionTier = defaults.integer(forKey: "swapUsesProgressionTier")
        self.hammerUsesProgressionTier = defaults.integer(forKey: "hammerUsesProgressionTier")
        self.magnetUsesProgressionTier = defaults.integer(forKey: "magnetUsesProgressionTier")
        self.spinUsesProgressionTier = defaults.integer(forKey: "spinUsesProgressionTier")
        self.surviveMovesProgressionTier = defaults.integer(forKey: "surviveMovesProgressionTier")
        self.playtimeProgressionTier = defaults.integer(forKey: "playtimeProgressionTier")
        self.infinityProgressionTier = defaults.integer(forKey: "infinityProgressionTier")
        self.boost2xUsesProgressionTier = defaults.integer(forKey: "boost2xUsesProgressionTier")
        self.boost3xUsesProgressionTier = defaults.integer(forKey: "boost3xUsesProgressionTier")
        self.boost4xUsesProgressionTier = defaults.integer(forKey: "boost4xUsesProgressionTier")
        self.spinPurchasesProgressionTier = defaults.integer(forKey: "spinPurchasesProgressionTier")
        self.dailyClaimsProgressionTier = defaults.integer(forKey: "dailyClaimsProgressionTier")
        self.boost5xUsesProgressionTier = defaults.integer(forKey: "boost5xUsesProgressionTier")
        self.boost20xUsesProgressionTier = defaults.integer(forKey: "boost20xUsesProgressionTier")
        self.wheelCollectsProgressionTier = defaults.integer(forKey: "wheelCollectsProgressionTier")
        self.challengeCreationTier = defaults.integer(forKey: "challengeCreationTier")
        loadUnlocks()
        loadPersistedSnapshot()
    }
    
    public func loadCatalogFromBundle(named filename: String = "2244_achievements", in bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: filename, withExtension: "json") else {
            throw NSError(domain: "AchievementStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "JSON '\(filename).json' not found in bundle."])
        }
        try loadCatalog(from: url)
    }
    
    public func loadCatalog(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        catalog = try decoder.decode([AchievementDef].self, from: data)
        
        for def in catalog where unlocks[def.id] == nil {
            unlocks[def.id] = .init(unlocked: false, unlockedAt: nil, claimed: false)
        }
    }
    
    public func syncWithGameCenter() async {
        let existing = await gc.loadExistingAchievements()
        for gk in existing where gk.percentComplete >= 100.0 {
            if let idx = catalog.firstIndex(where: { ($0.gcIdentifier ?? $0.id) == gk.identifier }) {
                let id = catalog[idx].id
                let alreadyClaimed = unlocks[id]?.claimed ?? true
                unlocks[id] = .init(unlocked: true, unlockedAt: gk.lastReportedDate, claimed: alreadyClaimed)
            }
        }
        saveUnlocks()
    }
    
    public func evaluate(snapshot: GameSnapshot, reportToGameCenter: Bool = true) async {
        print("🔍 EVALUATE CALLED with snapshot.max_tile = \(snapshot.max_tile) (\(String(format: "%.2e", snapshot.max_tile)))")
        lastEvaluatedSnapshot = snapshot
        persistSnapshot(snapshot)
        var didUnlock = false
        for def in catalog {
            guard unlocks[def.id]?.unlocked != true else { continue }
            
            // Special handling for tile progression achievement
            if def.id == "tile_progression" {
                let targetValue = currentTileTier.value
                let tierLabel = currentTileTier.label
                print("🎯 TILE PROGRESSION EVALUATION:")
                print("   Current tileProgressionTier index: \(tileProgressionTier)")
                print("   Current tier label: \(tierLabel)")
                print("   Target value: \(targetValue) (\(String(format: "%.2e", targetValue)))")
                print("   Snapshot max_tile: \(snapshot.max_tile) (\(String(format: "%.2e", snapshot.max_tile)))")
                print("   Comparison result: \(snapshot.max_tile >= targetValue ? "PASSED ✓" : "NOT YET (\(String(format: "%.2f", snapshot.max_tile / targetValue * 100))% progress)")")
                if snapshot.max_tile >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                    print("   ✅ TIER UNLOCKED! Ready to claim.")
                }
                continue
            }
            
            // Special handling for moves progression achievement
            if def.id == "moves_progression" {
                let targetValue = currentMovesTier.value
                if Double(snapshot.total_moves) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }
            
            if def.id == "combo_6_10" {
                let targetValue = Double(currentCombo610Tier.milestone)
                if Double(snapshot.combo610Total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }
            
            if def.id == "combo_11_15" {
                let targetValue = Double(currentCombo1115Tier.milestone)
                if Double(snapshot.combo1115Total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }
            
            if def.id == "combo_16_20" {
                let targetValue = Double(currentCombo1620Tier.milestone)
                if Double(snapshot.combo1620Total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }
            
            if def.id == "combo_21_30" {
                let targetValue = Double(currentCombo2130Tier.milestone)
                if Double(snapshot.combo2130Total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }
            
            if def.id == "merge_progression" {
                let targetValue = Double(currentMergeTier.milestone)
                // FIX: compare Double to Double
                if Double(snapshot.merged_tiles_total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }
            
            if def.id == "swap_usage_progression" {
                let targetValue = Double(currentSwapUsesTier.milestone)
                if Double(snapshot.swap_uses_total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }
            
            if def.id == "hammer_usage_progression" {
                let targetValue = Double(currentHammerUsesTier.milestone)
                if Double(snapshot.hammer_uses_total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }
            
            if def.id == "spin_usage_progression" {
                let targetValue = Double(currentSpinUsesTier.milestone)
                if Double(snapshot.spin_uses_total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }
            
            if def.id == "survive_moves_progression" {
                let targetValue = Double(currentSurviveMovesTier.milestone)
                if Double(snapshot.survive_moves_total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }
            
            if def.id == "playtime_progression" {
                let targetValue = Double(currentPlaytimeTier.milestone)
                if Double(snapshot.play_minutes_total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }
            
            if def.id == "infinity_progression" {
                let targetValue = Double(currentInfinityTier.milestone)
                if Double(snapshot.infinity_creations_total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }

            if def.id == "boost2x_usage_progression" {
                let targetValue = Double(currentBoost2xUsesTier.milestone)
                if Double(snapshot.boost2x_uses_total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }

            if def.id == "boost3x_usage_progression" {
                let targetValue = Double(currentBoost3xUsesTier.milestone)
                if Double(snapshot.boost3x_uses_total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }

            if def.id == "boost4x_usage_progression" {
                let targetValue = Double(currentBoost4xUsesTier.milestone)
                if Double(snapshot.boost4x_uses_total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }

            if def.id == "spin_purchases_progression" {
                let targetValue = Double(currentSpinPurchasesTier.milestone)
                if Double(snapshot.spin_purchases_total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }

            if def.id == "daily_claims_progression" {
                let targetValue = Double(currentDailyClaimsTier.milestone)
                if Double(snapshot.daily_claims_total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }

            if def.id == "boost5x_usage_progression" {
                let targetValue = Double(currentBoost5xUsesTier.milestone)
                if Double(snapshot.boost5x_uses_total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }

            if def.id == "boost20x_usage_progression" {
                let targetValue = Double(currentBoost20xUsesTier.milestone)
                if Double(snapshot.boost20x_uses_total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }

            if def.id == "wheel_collects_progression" {
                let targetValue = Double(currentWheelCollectsTier.milestone)
                if Double(snapshot.wheel_collects_total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }

            if def.id == "challenge_creation" {
                let targetValue = Double(currentChallengeCreationTier.milestone)
                if Double(snapshot.challenge_creations_total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }
            
            if def.id == "magnet_usage_progression" {
                let targetValue = Double(currentMagnetUsesTier.milestone)
                if Double(snapshot.magnet_uses_total) >= targetValue {
                    unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    didUnlock = true
                }
                continue
            }
            
            if matches(def: def, snapshot: snapshot) {
                unlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                didUnlock = true
                
                if reportToGameCenter,
                   GKLocalPlayer.local.isAuthenticated {
                    let gcId = def.gcIdentifier ?? def.id
                    await gc.reportUnlock(gcIdentifier: gcId)
                }
            }
        }
        
        if didUnlock {
            saveUnlocks()
        }
    }
    
    public func claim(definition: AchievementDef) {
        guard var state = unlocks[definition.id], state.isClaimable else { return }
        
        // Special handling for tile progression achievement
        if definition.id == "tile_progression" {
            // Grant tier-specific rewards (fallback to definition if unspecified)
            if let rewards = tileRewards(for: definition) {
                if let gems = rewards.gems, gems > 0 {
                    grantGemsDirectly(gems)
                }
                onReward?(rewards)
            }
            
            // Advance to next tier (don't mark as claimed, reset for next tier)
            if !isTileProgressionMaxed {
                tileProgressionTier += 1
                // State is already reset in the didSet of tileProgressionTier
            } else {
                // Max tier reached - mark as fully claimed
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }
        
        // Special handling for moves progression achievement
        if definition.id == "moves_progression" {
            // Grant rewards from tier-specific rewards array
            let rewards = Self.movesTierRewards.indices.contains(movesProgressionTier)
                ? Self.movesTierRewards[movesProgressionTier]
                : AchievementDef.Rewards()
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)

            // Advance to next tier (don't mark as claimed, reset for next tier)
            if !isMovesProgressionMaxed {
                movesProgressionTier += 1
                // State is already reset in the didSet of movesProgressionTier
            } else {
                // Max tier reached - mark as fully claimed
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }
        
        if definition.id == "combo_6_10" {
            let rewards = combo610Display.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)
            
            if !isCombo610Maxed {
                combo610Tier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }
        
        if definition.id == "combo_11_15" {
            let rewards = combo1115Display.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)
            
            if !isCombo1115Maxed {
                combo1115Tier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }
        
        if definition.id == "combo_16_20" {
            let rewards = combo1620Display.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)
            
            if !isCombo1620Maxed {
                combo1620Tier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }
        
        if definition.id == "combo_21_30" {
            let rewards = combo2130Display.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)
            
            if !isCombo2130Maxed {
                combo2130Tier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }
        
        if definition.id == "merge_progression" {
            let rewards = mergeDisplay.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)
            
            if !isMergeProgressionMaxed {
                mergeProgressionTier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }
        
        if definition.id == "swap_usage_progression" {
            let rewards = swapUsesDisplay.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)
            
            if !isSwapUsesProgressionMaxed {
                swapUsesProgressionTier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }
        
        if definition.id == "hammer_usage_progression" {
            let rewards = hammerUsesDisplay.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)
            
            if !isHammerUsesProgressionMaxed {
                hammerUsesProgressionTier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }
        
        if definition.id == "spin_usage_progression" {
            let rewards = spinUsesDisplay.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)
            
            if !isSpinUsesProgressionMaxed {
                spinUsesProgressionTier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }
        
        if definition.id == "survive_moves_progression" {
            let rewards = surviveMovesDisplay.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)
            
            if !isSurviveMovesProgressionMaxed {
                surviveMovesProgressionTier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }

        if definition.id == "playtime_progression" {
            let rewards = playtimeDisplay.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)
            
            if !isPlaytimeProgressionMaxed {
                playtimeProgressionTier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }

        if definition.id == "infinity_progression" {
            let rewards = infinityDisplay.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)

            if !isInfinityProgressionMaxed {
                infinityProgressionTier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }

        if definition.id == "boost2x_usage_progression" {
            let rewards = boost2xUsesDisplay.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)

            if !isBoost2xUsesProgressionMaxed {
                boost2xUsesProgressionTier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }

        if definition.id == "boost3x_usage_progression" {
            let rewards = boost3xUsesDisplay.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)

            if !isBoost3xUsesProgressionMaxed {
                boost3xUsesProgressionTier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }

        if definition.id == "boost4x_usage_progression" {
            let rewards = boost4xUsesDisplay.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)

            if !isBoost4xUsesProgressionMaxed {
                boost4xUsesProgressionTier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }

        if definition.id == "spin_purchases_progression" {
            let rewards = spinPurchasesDisplay.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)

            if !isSpinPurchasesProgressionMaxed {
                spinPurchasesProgressionTier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }

        if definition.id == "daily_claims_progression" {
            let rewards = dailyClaimsDisplay.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)

            if !isDailyClaimsProgressionMaxed {
                dailyClaimsProgressionTier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }

        if definition.id == "boost5x_usage_progression" {
            let rewards = boost5xUsesDisplay.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)

            if !isBoost5xUsesProgressionMaxed {
                boost5xUsesProgressionTier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }

        if definition.id == "boost20x_usage_progression" {
            let rewards = boost20xUsesDisplay.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)

            if !isBoost20xUsesProgressionMaxed {
                boost20xUsesProgressionTier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }

        if definition.id == "wheel_collects_progression" {
            let rewards = wheelCollectsDisplay.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)

            if !isWheelCollectsProgressionMaxed {
                wheelCollectsProgressionTier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }

        if definition.id == "challenge_creation" {
            let rewards = challengeCreationDisplay.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)
            
            if !isChallengeCreationMaxed {
                challengeCreationTier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }
        
        if definition.id == "magnet_usage_progression" {
            let rewards = magnetUsesDisplay.rewards
            if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }
            onReward?(rewards)
            
            if !isMagnetUsesProgressionMaxed {
                magnetUsesProgressionTier += 1
            } else {
                state.claimed = true
                unlocks[definition.id] = state
                saveUnlocks()
            }
            return
        }
        
        // Standard achievement claim
        state.claimed = true
        unlocks[definition.id] = state
        saveUnlocks()
        
        guard let rewards = definition.rewards else { return }
        
        // Always grant gems directly so UI and wallet stay in sync
        if let gems = rewards.gems, gems > 0 {
            grantGemsDirectly(gems)
        }
        
        // Call reward callback for power-ups, spins, etc.
        onReward?(rewards)
    }
    
    public func progress(for definition: AchievementDef) -> AchievementProgress? {
        guard let snapshot = lastEvaluatedSnapshot else { return nil }
        
        func makeProgress(current: Double, target: Double) -> AchievementProgress? {
            guard target > 0 else { return nil }
            return AchievementProgress(current: max(0, current), target: target)
        }
        
        switch definition.id {
        case "tile_progression":
            let current = snapshot.max_tile
            let target = currentTileTier.value
            let pct = target > 0 ? (current / target * 100) : 0
            print("📊 TILE PROGRESS BAR:")
            print("   Current max_tile: \(current) (\(String(format: "%.2e", current)))")
            print("   Target (\(currentTileTier.label)): \(target) (\(String(format: "%.2e", target)))")
            print("   Progress: \(String(format: "%.2f", pct))%")
            return makeProgress(current: current, target: target)
        case "moves_progression":
            return makeProgress(current: Double(snapshot.total_moves), target: currentMovesTier.value)
        case "combo_6_10":
            return makeProgress(current: Double(snapshot.combo610Total), target: Double(currentCombo610Tier.milestone))
        case "combo_11_15":
            return makeProgress(current: Double(snapshot.combo1115Total), target: Double(currentCombo1115Tier.milestone))
        case "combo_16_20":
            return makeProgress(current: Double(snapshot.combo1620Total), target: Double(currentCombo1620Tier.milestone))
        case "combo_21_30":
            return makeProgress(current: Double(snapshot.combo2130Total), target: Double(currentCombo2130Tier.milestone))
        case "merge_progression":
            return makeProgress(current: Double(snapshot.merged_tiles_total), target: Double(currentMergeTier.milestone))
        case "swap_usage_progression":
            return makeProgress(current: Double(snapshot.swap_uses_total), target: Double(currentSwapUsesTier.milestone))
        case "hammer_usage_progression":
            return makeProgress(current: Double(snapshot.hammer_uses_total), target: Double(currentHammerUsesTier.milestone))
        case "spin_usage_progression":
            return makeProgress(current: Double(snapshot.spin_uses_total), target: Double(currentSpinUsesTier.milestone))
        case "survive_moves_progression":
            return makeProgress(current: Double(snapshot.survive_moves_total), target: Double(currentSurviveMovesTier.milestone))
        case "playtime_progression":
            return makeProgress(current: Double(snapshot.play_minutes_total), target: Double(currentPlaytimeTier.milestone))
        case "infinity_progression":
            return makeProgress(current: Double(snapshot.infinity_creations_total), target: Double(currentInfinityTier.milestone))
        case "boost2x_usage_progression":
            return makeProgress(current: Double(snapshot.boost2x_uses_total), target: Double(currentBoost2xUsesTier.milestone))
        case "boost3x_usage_progression":
            return makeProgress(current: Double(snapshot.boost3x_uses_total), target: Double(currentBoost3xUsesTier.milestone))
        case "boost4x_usage_progression":
            return makeProgress(current: Double(snapshot.boost4x_uses_total), target: Double(currentBoost4xUsesTier.milestone))
        case "spin_purchases_progression":
            return makeProgress(current: Double(snapshot.spin_purchases_total), target: Double(currentSpinPurchasesTier.milestone))
        case "daily_claims_progression":
            return makeProgress(current: Double(snapshot.daily_claims_total), target: Double(currentDailyClaimsTier.milestone))
        case "boost5x_usage_progression":
            return makeProgress(current: Double(snapshot.boost5x_uses_total), target: Double(currentBoost5xUsesTier.milestone))
        case "boost20x_usage_progression":
            return makeProgress(current: Double(snapshot.boost20x_uses_total), target: Double(currentBoost20xUsesTier.milestone))
        case "wheel_collects_progression":
            return makeProgress(current: Double(snapshot.wheel_collects_total), target: Double(currentWheelCollectsTier.milestone))
        case "challenge_creation":
            return makeProgress(current: Double(snapshot.challenge_creations_total), target: Double(currentChallengeCreationTier.milestone))
        case "magnet_usage_progression":
            return makeProgress(current: Double(snapshot.magnet_uses_total), target: Double(currentMagnetUsesTier.milestone))
        default:
            break
        }
        
        guard let condition = definition.conditions.first,
              let target = condition.value else {
            return nil
        }
        
        let op = condition.op.trimmingCharacters(in: .whitespaces)
        guard op == ">=" || op == ">" else { return nil }
        
        let currentValue = value(for: condition.field, in: snapshot)
        return makeProgress(current: currentValue, target: target)
    }
    
    public var claimableCount: Int {
        unlocks.values.filter { $0.isClaimable }.count
    }

    /// Claims all currently claimable achievements and returns the merged rewards
    public func claimAll() -> AchievementDef.Rewards {
        var mergedRewards = AchievementDef.Rewards()

        // Find all claimable achievement definitions
        let claimableDefinitions = catalog.filter { def in
            unlocks[def.id]?.isClaimable == true
        }

        // Temporarily disable onReward callback to prevent multiple UI updates
        let originalCallback = onReward
        onReward = nil

        // Claim each achievement and merge rewards
        for def in claimableDefinitions {
            // Get the rewards before claiming (for progressive achievements this gets current tier rewards)
            let rewards = rewardsForClaim(definition: def)
            if let rewards {
                mergedRewards = mergedRewards.merged(with: rewards)
            }

            // Claim the achievement (this handles tier advancement, etc.)
            claim(definition: def)
        }

        // Restore callback and fire once with merged rewards
        onReward = originalCallback
        onReward?(mergedRewards)

        return mergedRewards
    }

    /// Get the rewards that would be granted for claiming a specific achievement
    private func rewardsForClaim(definition: AchievementDef) -> AchievementDef.Rewards? {
        switch definition.id {
        case "tile_progression":
            return tileRewards(for: definition)
        case "moves_progression":
            return Self.movesTierRewards.indices.contains(movesProgressionTier)
                ? Self.movesTierRewards[movesProgressionTier]
                : nil
        case "combo_6_10":
            return combo610Display.rewards
        case "combo_11_15":
            return combo1115Display.rewards
        case "combo_16_20":
            return combo1620Display.rewards
        case "combo_21_30":
            return combo2130Display.rewards
        case "merge_progression":
            return mergeDisplay.rewards
        case "swap_usage_progression":
            return swapUsesDisplay.rewards
        case "hammer_usage_progression":
            return hammerUsesDisplay.rewards
        case "spin_usage_progression":
            return spinUsesDisplay.rewards
        case "survive_moves_progression":
            return surviveMovesDisplay.rewards
        case "playtime_progression":
            return playtimeDisplay.rewards
        case "infinity_progression":
            return infinityDisplay.rewards
        case "boost2x_usage_progression":
            return boost2xUsesDisplay.rewards
        case "boost3x_usage_progression":
            return boost3xUsesDisplay.rewards
        case "boost4x_usage_progression":
            return boost4xUsesDisplay.rewards
        case "spin_purchases_progression":
            return spinPurchasesDisplay.rewards
        case "daily_claims_progression":
            return dailyClaimsDisplay.rewards
        case "boost5x_usage_progression":
            return boost5xUsesDisplay.rewards
        case "boost20x_usage_progression":
            return boost20xUsesDisplay.rewards
        case "wheel_collects_progression":
            return wheelCollectsDisplay.rewards
        case "challenge_creation":
            return challengeCreationDisplay.rewards
        case "magnet_usage_progression":
            return magnetUsesDisplay.rewards
        default:
            return definition.rewards
        }
    }

    private func matches(def: AchievementDef, snapshot s: GameSnapshot) -> Bool {
        def.conditions.allSatisfy { cond in
            let lhs = value(for: cond.field, in: s)
            let rhs = cond.value ?? 0.0
            switch cond.op {
            case "==": return lhs == rhs
            case "!=": return lhs != rhs
            case ">":  return lhs > rhs
            case ">=": return lhs >= rhs
            case "<":  return lhs < rhs
            case "<=": return lhs <= rhs
            default:   return false
            }
        }
    }
    
    private func value(for field: String, in s: GameSnapshot) -> Double {
        func b(_ flag: Bool) -> Double { flag ? 1 : 0 }
        
        switch field {
        case "games_played": return .init(s.games_played)
        case "merges_total": return .init(s.merges_total)
        case "merges_in_single_turn": return .init(s.merges_in_single_turn)
        case "max_chain": return .init(s.max_chain)
        case "score": return .init(s.score)
        case "merge_in_corner": return .init(s.merge_in_corner)
        case "merge_on_edge": return .init(s.merge_on_edge)
        case "merges_first_10": return .init(s.merges_first_10)
        case "reached_core_target": return b(s.reached_core_target)
        case "moves": return .init(s.moves)
        case "total_moves": return .init(s.total_moves)
        case "combo_6_10_total": return .init(s.combo610Total)
        case "combo_11_15_total": return .init(s.combo1115Total)
        case "combo_16_20_total": return .init(s.combo1620Total)
        case "combo_21_30_total": return .init(s.combo2130Total)
        case "merged_tiles_total": return .init(s.merged_tiles_total)
        case "survive_moves_total": return .init(s.survive_moves_total)
        case "undo_used": return .init(s.undo_used)
        case "powerups_used": return .init(s.powerups_used)
        case "session_pauses": return .init(s.session_pauses)
        case "challenge_creations_total": return .init(s.challenge_creations_total)
        case "highest_tile_corner_moves": return .init(s.highest_tile_corner_moves)
        case "free_slots_end": return .init(s.free_slots_end)
        case "invalid_moves": return .init(s.invalid_moves)
        case "run_completed": return b(s.run_completed)
        case "consecutive_merge_turns": return .init(s.consecutive_merge_turns)
        case "score_60s": return .init(s.score_60s)
        case "score_180s": return .init(s.score_180s)
        case "max_tile_120s": return .init(s.max_tile_120s)
        case "merges_10s": return .init(s.merges_10s)
        case "valid_moves_30s": return .init(s.valid_moves_30s)
        case "seconds_elapsed": return .init(s.seconds_elapsed)
        case "seconds_left": return .init(s.seconds_left)
        case "timed_mode": return b(s.timed_mode)
        case "play_minutes_total": return .init(s.play_minutes_total)
        case "infinity_creations_total": return .init(s.infinity_creations_total)
        case "boost2x_uses_total": return .init(s.boost2x_uses_total)
        case "boost3x_uses_total": return .init(s.boost3x_uses_total)
        case "boost4x_uses_total": return .init(s.boost4x_uses_total)
        case "max_chain_60s": return .init(s.max_chain_60s)
        case "max_tile_300s": return .init(s.max_tile_300s)
        case "daily_completed": return .init(s.daily_completed)
        case "daily_streak": return .init(s.daily_streak)
        case "weekend_back_to_back": return b(s.weekend_back_to_back)
        case "prev_losing_streak": return .init(s.prev_losing_streak)
        case "play_streak_days": return .init(s.play_streak_days)
        case "endless_milestone": return .init(s.endless_milestone)
        case "low_free_slots_turns": return .init(s.low_free_slots_turns)
        case "run_minutes": return .init(s.run_minutes)
        case "monotonic_row_or_col_moves": return .init(s.monotonic_row_or_col_moves)
        case "top3_same_quadrant": return b(s.top3_same_quadrant)
        case "edge_descending_no_gaps": return b(s.edge_descending_no_gaps)
        case "merges_from_center": return .init(s.merges_from_center)
        case "square_2x2_identical_value": return .init(s.square_2x2_identical_value)
        case "different_powerups_used": return .init(s.different_powerups_used)
        case "powerups_unused": return .init(s.powerups_unused)
        case "spin_uses_total": return .init(s.spin_uses_total)
        case "free_slots_at_booster_use": return .init(s.free_slots_at_booster_use)
        case "moved_right": return .init(s.moved_right)
        case "moved_left": return .init(s.moved_left)
        case "moved_down": return .init(s.moved_down)
        case "board_monotonic_end": return b(s.board_monotonic_end)
        case "made_2244_square": return b(s.made_2244_square)
        case "max_tile": return .init(s.max_tile)
        case "win": return b(s.win)
        default:
            #if DEBUG
            print("⚠️ Unknown telemetry field: \(field) -> treating as 0")
            #endif
            return 0.0
        }
    }
    
    private func grantGemsDirectly(_ gems: Int) {
        let currentGems = defaults.integer(forKey: "coins")
        let newGems = currentGems + gems
        defaults.set(newGems, forKey: "coins")
        
        NotificationCenter.default.post(
            name: Notification.Name("GemsDidChange"),
            object: nil,
            userInfo: ["newBalance": newGems, "added": gems]
        )
    }
    
    private func persistSnapshot(_ snapshot: GameSnapshot) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(snapshot) {
            defaults.set(data, forKey: SnapshotDefaultsKey.lastSnapshot)
            #if DEBUG
            print("💾 Persisted snapshot - max_tile: \(snapshot.max_tile) (\(String(format: "%.2e", snapshot.max_tile)))")
            #endif
        }
    }
    
    private func loadPersistedSnapshot() {
        guard let data = defaults.data(forKey: SnapshotDefaultsKey.lastSnapshot) else { return }
        let decoder = JSONDecoder()
        do {
            let snapshot = try decoder.decode(GameSnapshot.self, from: data)
            lastEvaluatedSnapshot = snapshot
            #if DEBUG
            print("📂 Loaded persisted snapshot - max_tile: \(snapshot.max_tile) (\(String(format: "%.2e", snapshot.max_tile)))")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ Failed to decode persisted snapshot: \(error)")
            print("   Clearing stale snapshot data...")
            #endif
            // Clear the stale data so next evaluation will persist a fresh snapshot
            defaults.removeObject(forKey: SnapshotDefaultsKey.lastSnapshot)
        }
    }
    
    private func saveUnlocks() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(unlocks) {
            defaults.set(data, forKey: "achievementUnlocks_v2")
            defaults.synchronize()
            print("💾 AchievementStore: Saved \(unlocks.count) unlocks")
        } else {
            print("❌ AchievementStore: Failed to encode unlocks")
        }
    }
    
    private func loadUnlocks() {
        if let data = defaults.data(forKey: "achievementUnlocks_v2") {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                unlocks = try decoder.decode([String: UnlockState].self, from: data)
                print("📂 AchievementStore: Loaded \(unlocks.count) unlocks")
            } catch {
                print("❌ AchievementStore: Failed to decode unlocks: \(error)")
            }
        } else {
            // Fallback to legacy key if v2 missing
            if let data = defaults.data(forKey: "achievementUnlocks") {
                if let saved = try? JSONDecoder().decode([String: UnlockState].self, from: data) {
                    unlocks = saved
                    print("📂 AchievementStore: Migrated \(saved.count) unlocks from legacy")
                    saveUnlocks() // Save to v2 immediately
                }
            } else {
                print("⚠️ AchievementStore: No saved unlocks found")
            }
        }
    }

    // MARK: - All Tiers Display

    /// Represents a single tier in a progression achievement for display purposes
    public struct TierEntry: Identifiable, Sendable {
        public let id: Int  // tier index (0-based)
        public let level: Int  // display level (1-based)
        public let milestone: Int
        public let milestoneLabel: String
        public let title: String
        public let description: String
        public let rewards: AchievementDef.Rewards
        public let isCompleted: Bool
        public let isCurrent: Bool
    }

    /// Get all tiers for a given achievement ID
    public func allTiers(for achievementId: String) -> [TierEntry] {
        switch achievementId {
        case "tile_progression":
            return allTileTiers()
        case "moves_progression":
            return allMovesTiers()
        case "combo_6_10":
            return allComboTiers(tiers: Self.combo610Tiers, currentTierIndex: combo610Tier)
        case "combo_11_15":
            return allComboTiers(tiers: Self.combo1115Tiers, currentTierIndex: combo1115Tier)
        case "combo_16_20":
            return allComboTiers(tiers: Self.combo1620Tiers, currentTierIndex: combo1620Tier)
        case "combo_21_30":
            return allComboTiers(tiers: Self.combo2130Tiers, currentTierIndex: combo2130Tier)
        case "merge_progression":
            return allComboTiers(tiers: Self.mergeTiers, currentTierIndex: mergeProgressionTier)
        case "swap_usage_progression":
            return allComboTiers(tiers: Self.swapUseTiers, currentTierIndex: swapUsesProgressionTier)
        case "hammer_usage_progression":
            return allComboTiers(tiers: Self.hammerUseTiers, currentTierIndex: hammerUsesProgressionTier)
        case "survive_moves_progression":
            return allComboTiers(tiers: Self.surviveMovesTiers, currentTierIndex: surviveMovesProgressionTier)
        case "spin_usage_progression":
            return allComboTiers(tiers: Self.spinUseTiers, currentTierIndex: spinUsesProgressionTier)
        case "magnet_usage_progression":
            return allComboTiers(tiers: Self.magnetUseTiers, currentTierIndex: magnetUsesProgressionTier)
        case "challenge_creation":
            return allComboTiers(tiers: Self.challengeCreationTiers, currentTierIndex: challengeCreationTier)
        case "infinity_progression":
            return allComboTiers(tiers: Self.infinityTiers, currentTierIndex: infinityProgressionTier)
        case "playtime_progression":
            return allPlaytimeTiers()
        case "boost2x_usage_progression":
            return allComboTiers(tiers: Self.boost2xUseTiers, currentTierIndex: boost2xUsesProgressionTier)
        case "boost3x_usage_progression":
            return allComboTiers(tiers: Self.boost3xUseTiers, currentTierIndex: boost3xUsesProgressionTier)
        case "boost4x_usage_progression":
            return allComboTiers(tiers: Self.boost4xUseTiers, currentTierIndex: boost4xUsesProgressionTier)
        case "spin_purchases_progression":
            return allComboTiers(tiers: Self.spinPurchaseTiers, currentTierIndex: spinPurchasesProgressionTier)
        case "daily_claims_progression":
            return allComboTiers(tiers: Self.dailyClaimsTiers, currentTierIndex: dailyClaimsProgressionTier)
        case "boost5x_usage_progression":
            return allComboTiers(tiers: Self.boost5xUseTiers, currentTierIndex: boost5xUsesProgressionTier)
        case "boost20x_usage_progression":
            return allComboTiers(tiers: Self.boost20xUseTiers, currentTierIndex: boost20xUsesProgressionTier)
        case "wheel_collects_progression":
            return allComboTiers(tiers: Self.wheelCollectsTiers, currentTierIndex: wheelCollectsProgressionTier)
        default:
            return []
        }
    }

    /// Check if an achievement has multiple tiers
    public func hasMultipleTiers(for achievementId: String) -> Bool {
        !allTiers(for: achievementId).isEmpty
    }

    private func allTileTiers() -> [TierEntry] {
        Self.tileTiers.enumerated().map { index, tier in
            let rewards = Self.tileTierRewards.indices.contains(index)
                ? (Self.tileTierRewards[index] ?? AchievementDef.Rewards())
                : AchievementDef.Rewards()
            let safeMilestone = tier.value > Double(Int.max) ? Int.max : Int(tier.value)
            return TierEntry(
                id: index,
                level: index + 1,
                milestone: safeMilestone,
                milestoneLabel: tier.label,
                title: "Reach \(tier.label) tile",
                description: tier.label == "∞"
                    ? "Create a tile beyond comprehension."
                    : "Create a \(tier.label) tile.",
                rewards: rewards,
                isCompleted: index < tileProgressionTier,
                isCurrent: index == tileProgressionTier
            )
        }
    }

    private func allMovesTiers() -> [TierEntry] {
        Self.movesTiers.enumerated().map { index, tier in
            let rewards = Self.movesTierRewards.indices.contains(index)
                ? Self.movesTierRewards[index]
                : AchievementDef.Rewards()
            return TierEntry(
                id: index,
                level: index + 1,
                milestone: Int(tier.value),
                milestoneLabel: tier.label,
                title: "Make \(tier.label) moves",
                description: "Accumulate \(tier.label) total moves.",
                rewards: rewards,
                isCompleted: index < movesProgressionTier,
                isCurrent: index == movesProgressionTier
            )
        }
    }

    private func allPlaytimeTiers() -> [TierEntry] {
        Self.playtimeTiers.enumerated().map { index, tier in
            let label = formatPlaytime(tier.milestone)
            return TierEntry(
                id: index,
                level: index + 1,
                milestone: tier.milestone,
                milestoneLabel: label,
                title: "Play for \(label)",
                description: "Accumulate \(label) of total playtime.",
                rewards: tier.rewards,
                isCompleted: index < playtimeProgressionTier,
                isCurrent: index == playtimeProgressionTier
            )
        }
    }

    private func formatPlaytime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else if minutes < 1440 {
            let hours = minutes / 60
            return "\(hours) hr"
        } else {
            let days = minutes / 1440
            return "\(days) day\(days == 1 ? "" : "s")"
        }
    }

    private func allComboTiers(tiers: [ComboTierDefinition], currentTierIndex: Int) -> [TierEntry] {
        tiers.enumerated().map { index, tier in
            TierEntry(
                id: index,
                level: index + 1,
                milestone: tier.milestone,
                milestoneLabel: formatMilestone(tier.milestone),
                title: tier.categoryLabel,
                description: "Reach \(formatMilestone(tier.milestone)) to complete this tier.",
                rewards: tier.rewards,
                isCompleted: index < currentTierIndex,
                isCurrent: index == currentTierIndex
            )
        }
    }

    private func formatMilestone(_ value: Int) -> String {
        if value < 1000 {
            return "\(value)"
        } else if value < 1_000_000 {
            let k = Double(value) / 1000
            return k.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(k))K"
                : String(format: "%.1fK", k)
        } else {
            let m = Double(value) / 1_000_000
            return m.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(m))M"
                : String(format: "%.1fM", m)
        }
    }
}

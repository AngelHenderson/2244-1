import Foundation
import GameCore

/// Generates milestone tiles for the infinite journey road
public enum JourneyTileGenerator {

    /// Milestone spacing configuration - farther apart as requested
    private static let milestoneSteps: [Int] = [
        0,    // 2
        1,    // 4
        2,    // 8
        3,    // 16
        4,    // 32
        5,    // 64
        6,    // 128
        7,    // 256
        8,    // 512
        9,    // 1K
        10,   // 2K
        12,   // 8K    (skip 4K)
        14,   // 32K   (skip 16K)
        16,   // 128K  (skip 64K)
        18,   // 512K  (skip 256K)
        20,   // 2M    (skip 1M)
        23,   // 16M   (skip 4M, 8M)
        26,   // 128M  (skip 32M, 64M)
        29,   // 1B    (skip 256M, 512M)
        32,   // 8B    (skip 2B, 4B)
        35,   // 64B   (skip 16B, 32B)
        38,   // 512B  (skip 128B, 256B)
        42,   // 8T    (skip 1T, 2T, 4T)
        46,   // 128T  (skip 16T, 32T, 64T)
        50,   // 2q    (skip 256T, 512T, 1q)
        55,   // 64q   (skip 4q, 8q, 16q, 32q)
        60,   // 2Q    (skip 128q, 256q, 512q, 1Q)
        65,   // 64Q   (skip 4Q, 8Q, 16Q, 32Q)
        70,   // 2s    (skip 128Q, 256Q, 512Q, 1s)
        75,   // 64s   (skip 4s, 8s, 16s, 32s)
        80,   // 2S    (skip 128s, 256s, 512s, 1S)
        86,   // 128S  (skip 4S, 8S, 16S, 32S, 64S)
        92,   // 2o    (skip 256S, 512S, 1o)
        98,   // 32o   (skip 4o, 8o, 16o)
        104,  // 512o  (skip 64o, 128o, 256o)
        111,  // 16O   (skip 1O, 2O, 4O, 8O)
        118,  // 512O  (skip 32O, 64O, 128O, 256O)
        125,  // 16n   (skip 1n, 2n, 4n, 8n)
        133,  // 1N    (skip 32n, 64n, 128n, 256n, 512n)
        141,  // 64N   (skip 2N, 4N, 8N, 16N, 32N)
        150,  // 8d    (skip 128N, 256N, 512N, 1d, 2d, 4d)
        160,  // 1D    (skip 16d, 32d, 64d, 128d, 256d, 512d)
        170,  // 128D  (skip 2D, 4D, 8D, 16D, 32D, 64D)
        181,  // 32u   (skip 256D, 512D, 1u, 2u, 4u, 8u, 16u)
        193,  // 16U   (skip 64u, 128u, 256u, 512u, 1U, 2U, 4U, 8U)
        206,  // 16v   (skip 32U, 64U, 128U, 256U, 512U, 1v, 2v, 4v, 8v)
        220,  // 32V   (skip 32v, 64v, 128v, 256v, 512v, 1V, 2V, 4V, 8V, 16V)
        235,  // 128g  (skip 64V, 128V, 256V, 512V, 1g, 2g, 4g, 8g, 16g, 32g, 64g)
        251,  // 1G    (skip 256g, 512g)
        268,  // 16G   (skip 2G, 4G, 8G)
        286,  // 512G  (skip 32G, 64G, 128G, 256G)
        305,  // 32h   (skip 1h, 2h, 4h, 8h, 16h)
        325   // 4H    (skip 64h, 128h, 256h, 512h, 1H, 2H)
    ]

    /// Generate journey tiles up to the current highest tile with dynamic lookahead
    public static func generateJourney(highest: Int, stepsAhead: Int) -> [Tile] {
        let currentStep = TileStepLabelFormatter.stepForValue(highest, start: 2) ?? 0

        // Find current position in milestones
        let currentMilestoneIndex = milestoneSteps.firstIndex(where: { $0 >= currentStep }) ?? 0

        // Calculate how many milestones to show ahead based on stepsAhead
        let milestonesToShow = min(
            (stepsAhead / 10) + 5, // Show more milestones as stepsAhead increases
            milestoneSteps.count - currentMilestoneIndex + 10 // But don't go too far beyond infinity
        )

        // Generate tiles for visible milestones
        var tiles: [Tile] = []

        // Start from a few milestones back if we've progressed
        let startIndex = max(0, currentMilestoneIndex - 3)
        let endIndex = min(milestoneSteps.count, currentMilestoneIndex + milestonesToShow)

        for i in startIndex..<endIndex {
            if i < milestoneSteps.count {
                let step = milestoneSteps[i]
                tiles.append(Tile.make(forStep: step))
            }
        }

        // Add infinity at the end if we're close enough
        if endIndex >= milestoneSteps.count - 5 {
            tiles.append(Tile.infinity())
        }

        return tiles
    }

    /// Generate the full journey for preview (all milestones)
    public static func generateFullJourney() -> [Tile] {
        var tiles = milestoneSteps.map { Tile.make(forStep: $0) }
        tiles.append(Tile.infinity())
        return tiles
    }

    /// Format a tile value for display in the journey
    public static func formatTileAtStep(_ step: Int) -> String {
        let tile = Tile.make(forStep: step)
        return formatTileValue(tile.value)
    }

    /// Format tile value using abbreviated notation
    public static func formatTileValue(_ value: Int) -> String {
        // Use the AlphaNumber formatter for consistent display
        let alphaNum = AlphaNumber(value)

        // Get abbreviated string
        if let abbreviated = alphaNum.abbreviatedString() {
            return abbreviated
        }

        // Fallback to simple number format for small values
        if value < 1000 {
            return "\(value)"
        }

        // For larger values, use K/M/B notation
        if value < 1_000_000 {
            let k = Double(value) / 1000.0
            if k == Double(Int(k)) {
                return "\(Int(k))K"
            }
            return String(format: "%.1fK", k)
        }

        if value < 1_000_000_000 {
            let m = Double(value) / 1_000_000.0
            if m == Double(Int(m)) {
                return "\(Int(m))M"
            }
            return String(format: "%.1fM", m)
        }

        let b = Double(value) / 1_000_000_000.0
        if b == Double(Int(b)) {
            return "\(Int(b))B"
        }
        return String(format: "%.1fB", b)
    }
}

// MARK: - Journey Abbreviation Tiers

/// Defines reward tiers for journey milestones
public enum JourneyAbbreviationTier: String, CaseIterable, Sendable {
    case tier1K = "1K"     // Step 9
    case tier32K = "32K"   // Step 14
    case tier1M = "1M"     // Step 19
    case tier128M = "128M" // Step 26
    case tier8B = "8B"     // Step 32
    case tier512B = "512B" // Step 38
    case tier128T = "128T" // Step 46
    case tier64q = "64q"   // Step 55
    case tier64Q = "64Q"   // Step 65
    case tier64s = "64s"   // Step 75
    case tier128S = "128S" // Step 86
    case tier32o = "32o"   // Step 98
    case tier16O = "16O"   // Step 111
    case tier16n = "16n"   // Step 125
    case tier64N = "64N"   // Step 141
    case tier8d = "8d"     // Step 150
    case tier128D = "128D" // Step 170
    case tier32u = "32u"   // Step 181
    case tier16U = "16U"   // Step 193
    case tier16v = "16v"   // Step 206
    case tier32V = "32V"   // Step 220
    case tier128g = "128g" // Step 235
    case tier1G = "1G"     // Step 251
    case tier16G = "16G"   // Step 268
    case tier512G = "512G" // Step 286
    case tier32h = "32h"   // Step 305
    case tier4H = "4H"     // Step 325
}

/// Tier with order for progression
public struct JourneyTierInfo: Sendable {
    public let tier: JourneyAbbreviationTier
    public let order: Int
    public let label: String
    public let step: Int

    public init(tier: JourneyAbbreviationTier, order: Int, label: String, step: Int) {
        self.tier = tier
        self.order = order
        self.label = label
        self.step = step
    }
}

/// Helper to get tier for a tile
public enum JourneyAbbreviationTiers {
    private static let tierMap: [Int: JourneyAbbreviationTier] = [
        9: .tier1K,
        14: .tier32K,
        19: .tier1M,
        26: .tier128M,
        32: .tier8B,
        38: .tier512B,
        46: .tier128T,
        55: .tier64q,
        65: .tier64Q,
        75: .tier64s,
        86: .tier128S,
        98: .tier32o,
        111: .tier16O,
        125: .tier16n,
        141: .tier64N,
        150: .tier8d,
        170: .tier128D,
        181: .tier32u,
        193: .tier16U,
        206: .tier16v,
        220: .tier32V,
        235: .tier128g,
        251: .tier1G,
        268: .tier16G,
        286: .tier512G,
        305: .tier32h,
        325: .tier4H
    ]

    public static let tiers: [JourneyTierInfo] = [
        JourneyTierInfo(tier: .tier1K, order: 0, label: "1K", step: 9),
        JourneyTierInfo(tier: .tier32K, order: 1, label: "32K", step: 14),
        JourneyTierInfo(tier: .tier1M, order: 2, label: "1M", step: 19),
        JourneyTierInfo(tier: .tier128M, order: 3, label: "128M", step: 26),
        JourneyTierInfo(tier: .tier8B, order: 4, label: "8B", step: 32),
        JourneyTierInfo(tier: .tier512B, order: 5, label: "512B", step: 38),
        JourneyTierInfo(tier: .tier128T, order: 6, label: "128T", step: 46),
        JourneyTierInfo(tier: .tier64q, order: 7, label: "64q", step: 55),
        JourneyTierInfo(tier: .tier64Q, order: 8, label: "64Q", step: 65),
        JourneyTierInfo(tier: .tier64s, order: 9, label: "64s", step: 75),
        JourneyTierInfo(tier: .tier128S, order: 10, label: "128S", step: 86),
        JourneyTierInfo(tier: .tier32o, order: 11, label: "32o", step: 98),
        JourneyTierInfo(tier: .tier16O, order: 12, label: "16O", step: 111),
        JourneyTierInfo(tier: .tier16n, order: 13, label: "16n", step: 125),
        JourneyTierInfo(tier: .tier64N, order: 14, label: "64N", step: 141),
        JourneyTierInfo(tier: .tier8d, order: 15, label: "8d", step: 150),
        JourneyTierInfo(tier: .tier128D, order: 16, label: "128D", step: 170),
        JourneyTierInfo(tier: .tier32u, order: 17, label: "32u", step: 181),
        JourneyTierInfo(tier: .tier16U, order: 18, label: "16U", step: 193),
        JourneyTierInfo(tier: .tier16v, order: 19, label: "16v", step: 206),
        JourneyTierInfo(tier: .tier32V, order: 20, label: "32V", step: 220),
        JourneyTierInfo(tier: .tier128g, order: 21, label: "128g", step: 235),
        JourneyTierInfo(tier: .tier1G, order: 22, label: "1G", step: 251),
        JourneyTierInfo(tier: .tier16G, order: 23, label: "16G", step: 268),
        JourneyTierInfo(tier: .tier512G, order: 24, label: "512G", step: 286),
        JourneyTierInfo(tier: .tier32h, order: 25, label: "32h", step: 305),
        JourneyTierInfo(tier: .tier4H, order: 26, label: "4H", step: 325)
    ]

    public static func tier(for tile: Tile) -> JourneyTierInfo? {
        guard let step = tile.stepIndex else { return nil }
        guard let tierEnum = tierMap[step] else { return nil }
        return tiers.first { $0.tier == tierEnum }
    }
}

// MARK: - AlphaMag Helper

/// Helper for formatting large numbers with Alpha-Mag notation
public enum AlphaMag {
    public static func formatTileValue(_ value: Int) -> String {
        return JourneyTileGenerator.formatTileValue(value)
    }
}
import Foundation
import GameCore

/// Generates milestone tiles for the infinite journey road
public enum JourneyTileGenerator {

    /// Milestone spacing configuration - every step for smooth progression
    /// Goes up to step 816 which corresponds to 873bz
    private static let milestoneSteps: [Int] = Array(0...816)

    /// Generate journey tiles up to the current highest tile with dynamic lookahead
    public static func generateJourney(highest: Int, stepsAhead: Int) -> [Tile] {
        let currentStep = TileStepLabelFormatter.stepForValue(highest, start: 2) ?? 0

        // Find current position in milestones
        let currentMilestoneIndex = milestoneSteps.firstIndex(where: { $0 >= currentStep }) ?? (milestoneSteps.count - 1)

        // Show milestones: 10 behind current position, and 15 ahead
        let milestonesBack = 10
        let milestonesAhead = 15

        // Generate tiles for visible milestones
        var tiles: [Tile] = []

        let startIndex = max(0, currentMilestoneIndex - milestonesBack)
        let endIndex = min(milestoneSteps.count, currentMilestoneIndex + milestonesAhead)

        for i in startIndex..<endIndex {
            let step = milestoneSteps[i]
            tiles.append(Tile.make(forStep: step))
        }

        // Add infinity at the very end
        tiles.append(Tile.infinity())

        return tiles
    }

    /// Generate the full journey for preview (all milestones)
    public static func generateFullJourney() -> [Tile] {
        var tiles = milestoneSteps.map { Tile.make(forStep: $0) }
        tiles.append(Tile.infinity())
        return tiles
    }

    /// Format a tile value for display in the journey (full sequence, all steps)
    /// Delegates to the GameCore formatter so every milestone uses the exact value
    /// (e.g., 65K, 131K, 262K, 524K) instead of the rounded powers-of-two labels.
    public static func formatTileAtStep(_ step: Int) -> String {
        return GameCore.JourneyTileGenerator.formatTileAtStep(step)
    }

    /// Format tile value using abbreviated notation (delegates to GameCore for accuracy)
    public static func formatTileValue(_ value: Int) -> String {
        if let tile = Tile.makeFromValue(value), let step = tile.stepIndex {
            return GameCore.JourneyTileGenerator.formatTileAtStep(step)
        }
        return GameCore.AlphaMag.formatTileValue(value)
    }
}

// MARK: - Journey Abbreviation Tiers

/// Defines reward tiers for journey milestones
public enum JourneyAbbreviationTier: String, CaseIterable, Sendable {
    case tier1K = "1K"       // Step 9
    case tier32K = "32K"     // Step 14
    case tier1M = "1M"       // Step 19
    case tier128M = "128M"   // Step 26
    case tier8B = "8B"       // Step 32
    case tier512B = "512B"   // Step 38
    case tier128a = "128a"   // Step 46
    case tier64e = "64e"     // Step 55
    case tier64i = "64i"     // Step 65
    case tier64m = "64m"     // Step 75
    case tier128q = "128q"   // Step 86
    case tier32w = "32w"     // Step 98
    case tier16ac = "16ac"   // Step 111
    case tier16ai = "16ai"   // Step 125
    case tier64ao = "64ao"   // Step 141
    case tier8ar = "8ar"     // Step 150
    case tier128ax = "128ax" // Step 170
    case tier32be = "32be"   // Step 181
    case tier16bk = "16bk"   // Step 193
    case tier16bq = "16bq"   // Step 206
    case tier32bw = "32bw"   // Step 220
    case tier128ca = "128ca" // Step 235
    case tier1cg = "1cg"     // Step 251
    case tier16cm = "16cm"   // Step 268
    case tier512cs = "512cs" // Step 286
    case tier32cy = "32cy"   // Step 305
    case tier4de = "4de"     // Step 325
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
        46: .tier128a,
        55: .tier64e,
        65: .tier64i,
        75: .tier64m,
        86: .tier128q,
        98: .tier32w,
        111: .tier16ac,
        125: .tier16ai,
        141: .tier64ao,
        150: .tier8ar,
        170: .tier128ax,
        181: .tier32be,
        193: .tier16bk,
        206: .tier16bq,
        220: .tier32bw,
        235: .tier128ca,
        251: .tier1cg,
        268: .tier16cm,
        286: .tier512cs,
        305: .tier32cy,
        325: .tier4de
    ]

    public static let tiers: [JourneyTierInfo] = [
        JourneyTierInfo(tier: .tier1K, order: 0, label: "1K", step: 9),
        JourneyTierInfo(tier: .tier32K, order: 1, label: "32K", step: 14),
        JourneyTierInfo(tier: .tier1M, order: 2, label: "1M", step: 19),
        JourneyTierInfo(tier: .tier128M, order: 3, label: "128M", step: 26),
        JourneyTierInfo(tier: .tier8B, order: 4, label: "8B", step: 32),
        JourneyTierInfo(tier: .tier512B, order: 5, label: "512B", step: 38),
        JourneyTierInfo(tier: .tier128a, order: 6, label: "128a", step: 46),
        JourneyTierInfo(tier: .tier64e, order: 7, label: "64e", step: 55),
        JourneyTierInfo(tier: .tier64i, order: 8, label: "64i", step: 65),
        JourneyTierInfo(tier: .tier64m, order: 9, label: "64m", step: 75),
        JourneyTierInfo(tier: .tier128q, order: 10, label: "128q", step: 86),
        JourneyTierInfo(tier: .tier32w, order: 11, label: "32w", step: 98),
        JourneyTierInfo(tier: .tier16ac, order: 12, label: "16ac", step: 111),
        JourneyTierInfo(tier: .tier16ai, order: 13, label: "16ai", step: 125),
        JourneyTierInfo(tier: .tier64ao, order: 14, label: "64ao", step: 141),
        JourneyTierInfo(tier: .tier8ar, order: 15, label: "8ar", step: 150),
        JourneyTierInfo(tier: .tier128ax, order: 16, label: "128ax", step: 170),
        JourneyTierInfo(tier: .tier32be, order: 17, label: "32be", step: 181),
        JourneyTierInfo(tier: .tier16bk, order: 18, label: "16bk", step: 193),
        JourneyTierInfo(tier: .tier16bq, order: 19, label: "16bq", step: 206),
        JourneyTierInfo(tier: .tier32bw, order: 20, label: "32bw", step: 220),
        JourneyTierInfo(tier: .tier128ca, order: 21, label: "128ca", step: 235),
        JourneyTierInfo(tier: .tier1cg, order: 22, label: "1cg", step: 251),
        JourneyTierInfo(tier: .tier16cm, order: 23, label: "16cm", step: 268),
        JourneyTierInfo(tier: .tier512cs, order: 24, label: "512cs", step: 286),
        JourneyTierInfo(tier: .tier32cy, order: 25, label: "32cy", step: 305),
        JourneyTierInfo(tier: .tier4de, order: 26, label: "4de", step: 325)
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
import Foundation

/// Describes major milestone tiers that map to the abbreviated labels shown in the journey panel (1M, 1B, 1a…873bz, ∞).
public struct JourneyAbbreviationTier: Identifiable, Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case standard
        case final
        case infinity
    }
    
    public let id: String
    public let label: String
    public let step: Int?
    public let order: Int
    public let kind: Kind
    
    public var isInfinity: Bool { kind == .infinity }
}

/// Generates and exposes the ordered tier list used by both the game logic and UI.
public enum JourneyAbbreviationTiers {
    public static let maxSupportedStep = 817
    public static let startStep = 19 // 1M (2^20)
    
    public static let tiers: [JourneyAbbreviationTier] = Self.buildTiers()
    
    private static let tiersByStep: [Int: JourneyAbbreviationTier] = {
        tiers.reduce(into: [:]) { partialResult, tier in
            if let step = tier.step {
                partialResult[step] = tier
            }
        }
    }()
    
    private static let tiersByID: [String: JourneyAbbreviationTier] = {
        tiers.reduce(into: [:]) { partialResult, tier in
            partialResult[tier.id.lowercased()] = tier
        }
    }()
    
    public static let infinityTier: JourneyAbbreviationTier = tiers.last(where: { $0.kind == .infinity }) ?? JourneyAbbreviationTier(id: "infinity", label: "∞", step: nil, order: tiers.count, kind: .infinity)
    public static let maxRewardOrder: Int = tiers.filter { $0.kind != .infinity }.map(\.order).max() ?? 0
    
    public static func tier(forStep step: Int) -> JourneyAbbreviationTier? {
        tiersByStep[step]
    }
    
    public static func tier(forLabel label: String) -> JourneyAbbreviationTier? {
        tiersByID[label.lowercased()]
    }
    
    public static func tier(for tile: Tile) -> JourneyAbbreviationTier? {
        switch tile.type {
        case .infinity:
            return infinityTier
        case .highValue(let step):
            return tier(forStep: step)
        default:
            guard let step = TileStepLabelFormatter.stepForValue(tile.value) else { return nil }
            return tier(forStep: step)
        }
    }
    
    private static func buildTiers() -> [JourneyAbbreviationTier] {
        var results: [JourneyAbbreviationTier] = []
        let suffixTargets = buildTargets()
        var suffixIndex = 0
        
        for step in startStep...maxSupportedStep where suffixIndex < suffixTargets.count {
            let label = TileStepLabelFormatter.labelForStep(step)
            if labelMatchesTarget(label, target: suffixTargets[suffixIndex]) {
                let tier = JourneyAbbreviationTier(
                    id: label,
                    label: label,
                    step: step,
                    order: results.count,
                    kind: .standard
                )
                results.append(tier)
                suffixIndex += 1
            }
        }
        
        // Append the special terminal tier (873bz) if it wasn't already captured.
        if !results.contains(where: { $0.label.lowercased() == "873bz" }),
           startStep <= maxSupportedStep {
            let finalTier = JourneyAbbreviationTier(
                id: "873bz",
                label: "873bz",
                step: maxSupportedStep,
                order: results.count,
                kind: .final
            )
            results.append(finalTier)
        }
        
        // Always append the infinity tier as the capstone.
        let infinityTier = JourneyAbbreviationTier(
            id: "infinity",
            label: "∞",
            step: nil,
            order: results.count,
            kind: .infinity
        )
        results.append(infinityTier)
        
        return results
    }
    
    private static func buildTargets() -> [String] {
        var targets: [String] = ["1M", "1B"]
        targets += singleLetterTargets(prefix: "1")
        targets += doubleLetterTargets(prefix: "1", leading: "a")
        targets += doubleLetterTargets(prefix: "1", leading: "b")
        return targets
    }
    
    private static func singleLetterTargets(prefix: String) -> [String] {
        (0..<26).compactMap { offset -> String? in
            guard let scalar = UnicodeScalar(97 + offset) else { return nil }
            return "\(prefix)\(String(scalar))"
        }
    }
    
    private static func doubleLetterTargets(prefix: String, leading: String) -> [String] {
        return (0..<26).compactMap { offset -> String? in
            guard let scalar = UnicodeScalar(97 + offset) else { return nil }
            return "\(prefix)\(leading)\(String(scalar))"
        }
    }
    
    private static func labelMatchesTarget(_ label: String, target: String) -> Bool {
        label.lowercased() == target.lowercased()
    }
}



import Foundation
import GameCore

/// Generates scalable, random reward bundles for journey abbreviation tiers.
enum JourneyAbbreviationRewardCurve {
    static func reward(for tier: JourneyAbbreviationTier) -> GiftReward {
        var items: [GiftRewardItem] = []
        let normalized = normalizedPosition(for: tier)
        
        // Always grant gems with a magnitude that scales with the tier.
        items.append(GiftRewardItem(type: .gems, amount: gemAmount(for: tier, normalized: normalized)))
        
        // Assemble candidate power-ups and choose a random subset.
        var powerUps: [GiftRewardItem] = []
        if let hammer = hammerItem(for: tier) { powerUps.append(hammer) }
        if let magnet = magnetItem(for: tier) { powerUps.append(magnet) }
        if let swap = swapItem(for: tier) { powerUps.append(swap) }
        if let undo = undoItem(for: tier) { powerUps.append(undo) }
        
        if !powerUps.isEmpty {
            powerUps.shuffle()
            let takeCount = min(powerUps.count, max(1, Int.random(in: 1...min(3, powerUps.count))))
            items.append(contentsOf: powerUps.prefix(takeCount))
        }
        
        // Boost multipliers appear more frequently in later tiers.
        if normalized > 0.15, chance(0.25 + normalized * 0.5),
           let boost = boostItem(for: tier, normalized: normalized) {
            items.append(boost)
        }
        
        // Free spins unlock deeper in the ladder.
        if normalized > 0.35, chance(0.15 + normalized * 0.4) {
            let spins = 1 + Int(normalized * 2)
            items.append(GiftRewardItem(type: .bonusSpin, amount: spins))
        }
        
        // Ensure at least one non-gem item so rewards feel meaningful.
        if items.count == 1, let fallback = hammerItem(for: tier) {
            items.append(fallback)
        }
        
        let message = rewardMessage(for: tier)
        return GiftReward(message: message, items: items, isFromGlassShatter: false)
    }
}

private extension JourneyAbbreviationRewardCurve {
    static func normalizedPosition(for tier: JourneyAbbreviationTier) -> Double {
        let denominator = max(1, JourneyAbbreviationTiers.maxRewardOrder)
        let clampedOrder = min(max(0, tier.order), denominator)
        return Double(clampedOrder) / Double(denominator)
    }
    
    static func gemAmount(for tier: JourneyAbbreviationTier, normalized: Double) -> Int {
        let base = 75 + tier.order * 25
        let scale = 1.0 + normalized * 2.0
        return Int(Double(base) * scale)
    }
    
    static func hammerItem(for tier: JourneyAbbreviationTier) -> GiftRewardItem? {
        let count = max(1, 1 + tier.order / 12)
        return GiftRewardItem(type: .hammer, amount: count)
    }
    
    static func magnetItem(for tier: JourneyAbbreviationTier) -> GiftRewardItem? {
        guard tier.order >= 3 else { return nil }
        let count = max(1, 1 + tier.order / 18)
        return GiftRewardItem(type: .magnet, amount: count)
    }
    
    static func swapItem(for tier: JourneyAbbreviationTier) -> GiftRewardItem? {
        guard tier.order >= 12 else { return nil }
        let count = max(1, 1 + tier.order / 24)
        return GiftRewardItem(type: .swap, amount: count)
    }
    
    static func undoItem(for tier: JourneyAbbreviationTier) -> GiftRewardItem? {
        guard tier.order >= 6 else { return nil }
        let count = max(1, 1 + tier.order / 20)
        return GiftRewardItem(type: .undo, amount: count)
    }
    
    static func boostItem(for tier: JourneyAbbreviationTier, normalized: Double) -> GiftRewardItem? {
        let boostType: GiftRewardItem.GiftType
        if normalized > 0.8 {
            boostType = .boost4x
        } else if normalized > 0.45 {
            boostType = .boost3x
        } else {
            boostType = .boost2x
        }
        return GiftRewardItem(type: boostType, amount: 1)
    }
    
    static func chance(_ probability: Double) -> Bool {
        guard probability > 0 else { return false }
        return Double.random(in: 0...1) < min(probability, 1.0)
    }
    
    static func rewardMessage(for tier: JourneyAbbreviationTier) -> String {
        switch tier.kind {
        case .final:
            return "873bz mastered! Enjoy this legendary haul."
        case .infinity:
            return "Infinity achieved. Reality bends to your rewards."
        case .standard:
            return "Milestone \(tier.label) unlocked! Here's your bonus."
        }
    }
}




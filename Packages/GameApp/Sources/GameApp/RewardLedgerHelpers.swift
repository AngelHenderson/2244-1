import Foundation
import GameCore

@MainActor
public extension RewardLedgerStore {
    /// Delivers an `AchievementDef.Rewards` bundle through the ledger, applying each
    /// non-zero amount with a stable per-item idempotency key derived from the caller's
    /// `contextKey` (e.g. `"daily:42"`, `"spin:1700000000"`). The provided `apply`
    /// closure runs once per item — the ledger guarantees a duplicate `contextKey`
    /// will be ignored on subsequent calls.
    ///
    /// `apply` receives the item type and amount so the caller can mutate the right
    /// store (gem wallet, power-up inventory, spin wheel state, etc.).
    func grantRewards(
        _ rewards: AchievementDef.Rewards,
        source: RewardLedgerEntry.Source,
        contextKey: String,
        apply: @MainActor (RewardLedgerEntry.ItemType, Int) -> Void
    ) {
        if let gems = rewards.gems, gems > 0 {
            grantWith(source: source, type: .gems, amount: gems, contextKey: contextKey, apply: apply)
        }
        if let hammers = rewards.hammers, hammers > 0 {
            grantWith(source: source, type: .hammer, amount: hammers, contextKey: contextKey, apply: apply)
        }
        if let magnets = rewards.magnets, magnets > 0 {
            grantWith(source: source, type: .magnet, amount: magnets, contextKey: contextKey, apply: apply)
        }
        if let swaps = rewards.swaps, swaps > 0 {
            grantWith(source: source, type: .swap, amount: swaps, contextKey: contextKey, apply: apply)
        }
        if let spins = rewards.spins, spins > 0 {
            grantWith(source: source, type: .spin, amount: spins, contextKey: contextKey, apply: apply)
        }
        if let boost2x = rewards.boost2x, boost2x > 0 {
            grantWith(source: source, type: .multiplier2x, amount: boost2x, contextKey: contextKey, apply: apply)
        }
        if let boost3x = rewards.boost3x, boost3x > 0 {
            grantWith(source: source, type: .multiplier3x, amount: boost3x, contextKey: contextKey, apply: apply)
        }
        if let boost4x = rewards.boost4x, boost4x > 0 {
            grantWith(source: source, type: .multiplier4x, amount: boost4x, contextKey: contextKey, apply: apply)
        }
    }

    private func grantWith(
        source: RewardLedgerEntry.Source,
        type: RewardLedgerEntry.ItemType,
        amount: Int,
        contextKey: String,
        apply: @MainActor (RewardLedgerEntry.ItemType, Int) -> Void
    ) {
        grant(
            source: source,
            itemType: type,
            amount: amount,
            idempotencyKey: "\(contextKey):\(type.rawValue):\(amount)"
        ) {
            apply(type, amount)
        }
    }
}

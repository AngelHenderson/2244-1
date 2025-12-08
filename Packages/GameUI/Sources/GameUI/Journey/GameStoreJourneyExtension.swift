import Foundation
import GameApp
import GameCore

// Extension to add journey-related methods to GameStore
public extension GameStore {

    /// Check if a journey abbreviation tier is unlocked
    func isAbbreviationTierUnlocked(_ tier: JourneyAbbreviationTier) -> Bool {
        // Get the step required for this tier
        guard let requiredStep = getStepForTier(tier) else { return false }

        // Check if player has reached this step
        let currentStep = TileStepLabelFormatter.stepForValue(state.highestTile, start: 2) ?? 0
        return currentStep >= requiredStep
    }

    /// Check if a journey abbreviation tier reward has been claimed
    func hasClaimedAbbreviationTier(_ tier: JourneyAbbreviationTier) -> Bool {
        // Check UserDefaults for claimed status
        let key = "journey_claimed_\(tier.rawValue)"
        return UserDefaults.standard.bool(forKey: key)
    }

    /// Claim a journey reward with coins
    func claimJourneyReward(coins: Int) {
        addCoins(coins)
        print("🎁 Claimed journey reward: +\(coins) coins")
    }

    /// Present the journey reward for a tier
    func presentJourneyReward(for tier: JourneyAbbreviationTier) {
        // Check if already claimed
        guard !hasClaimedAbbreviationTier(tier) else { return }

        // Check if unlocked
        guard isAbbreviationTierUnlocked(tier) else { return }

        // Mark as claimed
        let key = "journey_claimed_\(tier.rawValue)"
        UserDefaults.standard.set(true, forKey: key)

        // Award reward based on tier
        let reward = getRewardForTier(tier)

        // Add coins
        if reward.coins > 0 {
            addCoins(reward.coins)
            print("🎁 Journey Reward: +\(reward.coins) coins for reaching \(tier.rawValue)")
        }

        // Add power-ups
        for (powerUp, count) in reward.powerUps {
            addPowerUp(powerUp, count: count)
            print("🎁 Journey Reward: +\(count) \(powerUp) for reaching \(tier.rawValue)")
        }

        // Trigger celebration animation (to be implemented in UI)
        NotificationCenter.default.post(
            name: NSNotification.Name("JourneyRewardClaimed"),
            object: nil,
            userInfo: ["tier": tier.rawValue, "reward": reward]
        )
    }

    // MARK: - Private Helpers

    private func getStepForTier(_ tier: JourneyAbbreviationTier) -> Int? {
        switch tier {
        case .tier1K: return 9
        case .tier32K: return 14
        case .tier1M: return 19
        case .tier128M: return 26
        case .tier8B: return 32
        case .tier512B: return 38
        case .tier128T: return 46
        case .tier64q: return 55
        case .tier64Q: return 65
        case .tier64s: return 75
        case .tier128S: return 86
        case .tier32o: return 98
        case .tier16O: return 111
        case .tier16n: return 125
        case .tier64N: return 141
        case .tier8d: return 150
        case .tier128D: return 170
        case .tier32u: return 181
        case .tier16U: return 193
        case .tier16v: return 206
        case .tier32V: return 220
        case .tier128g: return 235
        case .tier1G: return 251
        case .tier16G: return 268
        case .tier512G: return 286
        case .tier32h: return 305
        case .tier4H: return 325
        }
    }

    private func getRewardForTier(_ tier: JourneyAbbreviationTier) -> (coins: Int, powerUps: [(String, Int)]) {
        // Rewards get progressively better as you go further
        switch tier {
        case .tier1K:
            return (coins: 50, powerUps: [("hammer", 1)])
        case .tier32K:
            return (coins: 100, powerUps: [("swap", 1)])
        case .tier1M:
            return (coins: 200, powerUps: [("shuffle", 1)])
        case .tier128M:
            return (coins: 500, powerUps: [("hammer", 2), ("swap", 1)])
        case .tier8B:
            return (coins: 1000, powerUps: [("magnet", 1)])
        case .tier512B:
            return (coins: 2000, powerUps: [("double", 1)])
        case .tier128T:
            return (coins: 5000, powerUps: [("hammer", 3), ("swap", 2)])
        case .tier64q:
            return (coins: 10000, powerUps: [("magnet", 2), ("shuffle", 2)])
        case .tier64Q:
            return (coins: 20000, powerUps: [("double", 2), ("hammer", 5)])
        case .tier64s:
            return (coins: 50000, powerUps: [("magnet", 3), ("swap", 5)])
        case .tier128S:
            return (coins: 100000, powerUps: [("double", 3), ("shuffle", 5)])
        case .tier32o:
            return (coins: 200000, powerUps: [("hammer", 10), ("swap", 10)])
        case .tier16O:
            return (coins: 500000, powerUps: [("magnet", 5), ("double", 5)])
        case .tier16n:
            return (coins: 1000000, powerUps: [("shuffle", 10), ("hammer", 20)])
        case .tier64N:
            return (coins: 2000000, powerUps: [("double", 10), ("magnet", 10)])
        case .tier8d:
            return (coins: 5000000, powerUps: [("swap", 20), ("shuffle", 20)])
        case .tier128D:
            return (coins: 10000000, powerUps: [("hammer", 50), ("double", 20)])
        case .tier32u:
            return (coins: 20000000, powerUps: [("magnet", 20), ("swap", 50)])
        case .tier16U:
            return (coins: 50000000, powerUps: [("shuffle", 50), ("double", 50)])
        case .tier16v:
            return (coins: 100000000, powerUps: [("hammer", 100), ("magnet", 50)])
        case .tier32V:
            return (coins: 200000000, powerUps: [("swap", 100), ("double", 100)])
        case .tier128g:
            return (coins: 500000000, powerUps: [("shuffle", 100), ("hammer", 200)])
        case .tier1G:
            return (coins: 1000000000, powerUps: [("magnet", 100), ("double", 200)])
        case .tier16G:
            return (coins: 2000000000, powerUps: [("swap", 200), ("shuffle", 200)])
        case .tier512G:
            return (coins: 5000000000, powerUps: [("hammer", 500), ("double", 500)])
        case .tier32h:
            return (coins: 10000000000, powerUps: [("magnet", 500), ("swap", 500)])
        case .tier4H:
            return (coins: Int.max / 2, powerUps: [("shuffle", 1000), ("double", 1000)])
        }
    }
}
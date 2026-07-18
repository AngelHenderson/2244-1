import re

with open("Packages/GameCore/Sources/GameCore/Services/AchievementStore.swift", "r") as f:
    content = f.read()

props = """    public var infinityLeaderboardRankTier: Int {
        guard currentInfinityLeaderboardRank > 0 else { return -1 }
        var bestQualifiedIndex = -1
        for (index, tier) in Self.leaderboardRankTiers.enumerated() {
            if currentInfinityLeaderboardRank <= tier.milestone {
                bestQualifiedIndex = index
            } else {
                break
            }
        }
        return bestQualifiedIndex
    }

    private var displayInfinityLeaderboardRankTier: Int {
        let nextTierToClaimIndex = highestClaimedInfinityLeaderboardTier + 1
        let maxTier = Self.leaderboardRankTiers.count - 1
        return min(nextTierToClaimIndex, maxTier)
    }

    private var currentInfinityLeaderboardRankTier: ComboTierDefinition {
        let index = min(displayInfinityLeaderboardRankTier, Self.leaderboardRankTiers.count - 1)
        return Self.leaderboardRankTiers[index]
    }

    public var infinityLeaderboardRankDisplay: ProgressTierDisplay {
        let tier = currentInfinityLeaderboardRankTier
        let clampedIndex = min(displayInfinityLeaderboardRankTier, Self.leaderboardRankTiers.count - 1)
        let level = clampedIndex + 1
        let isMaxed = isInfinityLeaderboardRankMaxed
        let qualifiesForCurrentTier = currentInfinityLeaderboardRank > 0 && currentInfinityLeaderboardRank <= tier.milestone
        let description: String

        if isMaxed {
            description = "You reached the top tier of the Infinity Leaderboard!"
        } else if qualifiesForCurrentTier {
            description = "You reached \\(tier.categoryLabel) on the Infinity Leaderboard! Claim your reward."
        } else {
            description = "Reach \\(tier.categoryLabel) on the Infinity Leaderboard to unlock this."
        }

        return ProgressTierDisplay(
            title: isMaxed ? "Infinity Contender Maxed" : "Infinity Contender \\(level)",
            description: description,
            rewards: tier.rewards,
            isLocked: !isMaxed && !qualifiesForCurrentTier
        )
    }

    public var isInfinityLeaderboardRankMaxed: Bool {
        highestClaimedInfinityLeaderboardTier >= Self.leaderboardRankTiers.count - 1 && unlocks["infinity_leaderboard_rank_progression"]?.claimed == true
    }

    /// Leaderboard rank tier index based on CURRENT rank (not stored, calculated dynamically)"""

content = content.replace("    /// Leaderboard rank tier index based on CURRENT rank (not stored, calculated dynamically)", props)

with open("Packages/GameCore/Sources/GameCore/Services/AchievementStore.swift", "w") as f:
    f.write(content)


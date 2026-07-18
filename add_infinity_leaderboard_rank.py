import re

with open("Packages/GameCore/Sources/GameCore/Services/AchievementStore.swift", "r") as f:
    content = f.read()

# 1. Properties
props_regex = r'    private var highestClaimedLeaderboardTier: Int = -1 \{'
props_replacement = """    /// Current infinity leaderboard rank from Game Center (lower is better)
    public var currentInfinityLeaderboardRank: Int = 0 {
        didSet {
            defaults.set(currentInfinityLeaderboardRank, forKey: "currentInfinityLeaderboardRank")
        }
    }

    private var highestClaimedInfinityLeaderboardTier: Int = -1 {
        didSet {
            defaults.set(highestClaimedInfinityLeaderboardTier, forKey: "highestClaimedInfinityLeaderboardTier")
        }
    }

    private var highestClaimedLeaderboardTier: Int = -1 {"""
content = re.sub(props_regex, props_replacement, content)

# 2. computed properties
computed_regex = r'    public var leaderboardRankTier: Int \{\n        guard currentLeaderboardRank > 0 else \{ return 0 \}\n        for \(index, tier\) in Self\.leaderboardRankTiers\.enumerated\(\) \{'
computed_replacement = """    public var infinityLeaderboardRankTier: Int {
        guard currentInfinityLeaderboardRank > 0 else { return 0 }
        for (index, tier) in Self.leaderboardRankTiers.enumerated() {
            if currentInfinityLeaderboardRank <= tier.milestone {
                // If this is the last tier or the next tier is not met, return this index
                if index == Self.leaderboardRankTiers.count - 1 || currentInfinityLeaderboardRank > Self.leaderboardRankTiers[index + 1].milestone {
                    return index
                }
            }
        }
        return 0
    }

    private var displayInfinityLeaderboardRankTier: Int {
        // Next tier to claim is one after highest claimed
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
            description = "You reached \(tier.categoryLabel) on the Infinity Leaderboard! Claim your reward."
        } else {
            description = "Reach \(tier.categoryLabel) on the Infinity Leaderboard to unlock this."
        }

        return ProgressTierDisplay(
            title: isMaxed ? "Infinity Contender Maxed" : "Infinity Contender \(level)",
            description: description,
            rewards: tier.rewards,
            isLocked: !isMaxed && !qualifiesForCurrentTier
        )
    }

    public var isInfinityLeaderboardRankMaxed: Bool {
        highestClaimedInfinityLeaderboardTier >= Self.leaderboardRankTiers.count - 1 && unlocks["infinity_leaderboard_rank_progression"]?.claimed == true
    }

    public var leaderboardRankTier: Int {
        guard currentLeaderboardRank > 0 else { return 0 }
        for (index, tier) in Self.leaderboardRankTiers.enumerated() {"""
content = re.sub(computed_regex, computed_replacement, content)

# 3. Init loads
init_regex = r'        if defaults\.object\(forKey: "highestClaimedLeaderboardTier"\) != nil \{'
init_replacement = """        if defaults.object(forKey: "highestClaimedInfinityLeaderboardTier") != nil {
            self.highestClaimedInfinityLeaderboardTier = defaults.integer(forKey: "highestClaimedInfinityLeaderboardTier")
        }
        self.currentInfinityLeaderboardRank = defaults.integer(forKey: "currentInfinityLeaderboardRank")

        if defaults.object(forKey: "highestClaimedLeaderboardTier") != nil {"""
content = re.sub(init_regex, init_replacement, content)

# 4. evaluate
evaluate_regex = r'            // Allow tile_progression and leaderboard_rank_progression to be re-evaluated\n            if !\(def\.id == "tile_progression" \|\|\n                  def\.id == "leaderboard_rank_progression"\) && unlockState\.claimed \{'
evaluate_replacement = """            // Allow tile_progression and leaderboard_rank_progression to be re-evaluated
            if !(def.id == "tile_progression" ||
                  def.id == "leaderboard_rank_progression" ||
                  def.id == "infinity_leaderboard_rank_progression") && unlockState.claimed {"""
content = re.sub(evaluate_regex, evaluate_replacement, content)

evaluate_def_regex = r'            if def\.id == "leaderboard_rank_progression" \{\n                if snapshot\.best_leaderboard_rank > 0 \{'
evaluate_def_replacement = """            if def.id == "infinity_leaderboard_rank_progression" {
                // Check prerequisite
                if !isLeaderboardRankMaxed {
                    continue
                }
                if snapshot.best_infinity_leaderboard_rank > 0 {
                    currentInfinityLeaderboardRank = snapshot.best_infinity_leaderboard_rank
                }
                
                let nextTierToClaimIndex = highestClaimedInfinityLeaderboardTier + 1
                if nextTierToClaimIndex < Self.leaderboardRankTiers.count {
                    let qualifyingTier = infinityLeaderboardRankTier
                    if qualifyingTier >= nextTierToClaimIndex {
                        newUnlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    }
                }
                continue
            }

            if def.id == "leaderboard_rank_progression" {
                if snapshot.best_leaderboard_rank > 0 {"""
content = re.sub(evaluate_def_regex, evaluate_def_replacement, content)

# 5. claim
claim_regex = r'        if definition\.id == "leaderboard_rank_progression" \{'
claim_replacement = """        if definition.id == "infinity_leaderboard_rank_progression" {
            let rewards = infinityLeaderboardRankDisplay.rewards
            if let onReward = onReward {
                onReward(rewards)
            } else if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }

            // Mark this tier as claimed by advancing highestClaimedInfinityLeaderboardTier
            let claimedTierIndex = displayInfinityLeaderboardRankTier
            if claimedTierIndex > highestClaimedInfinityLeaderboardTier {
                highestClaimedInfinityLeaderboardTier = claimedTierIndex
            }

            // If there's another tier, unclaim it so the player can work towards it
            if highestClaimedInfinityLeaderboardTier < Self.leaderboardRankTiers.count - 1 {
                unlocks[definition.id] = .init(unlocked: false, unlockedAt: nil, claimed: false)
            } else {
                unlocks[definition.id] = .init(unlocked: true, unlockedAt: Date(), claimed: true)
            }
        }

        if definition.id == "leaderboard_rank_progression" {"""
content = re.sub(claim_regex, claim_replacement, content)

# 6. progress evaluate
prog_eval_regex = r'        case "leaderboard_rank_progression":\n            let nextTierToClaimIndex = highestClaimedLeaderboardTier \+ 1'
prog_eval_replacement = """        case "infinity_leaderboard_rank_progression":
            let nextTierToClaimIndex = highestClaimedInfinityLeaderboardTier + 1
            if nextTierToClaimIndex < Self.leaderboardRankTiers.count {
                let qualifyingTier = infinityLeaderboardRankTier
                if snapshot.best_infinity_leaderboard_rank > 0 &&
                   snapshot.best_infinity_leaderboard_rank <= targetValue &&
                   qualifyingTier >= nextTierToClaimIndex {
                    return 1.0
                }
            }
            return 0.0

        case "leaderboard_rank_progression":
            let nextTierToClaimIndex = highestClaimedLeaderboardTier + 1"""
content = re.sub(prog_eval_regex, prog_eval_replacement, content)

# 7. progressAmount
prog_amt_regex = r'        case "leaderboard_rank_progression":\n            // No progress bar for leaderboard rank\n            return 0'
prog_amt_replacement = """        case "leaderboard_rank_progression":
            // No progress bar for leaderboard rank
            return 0
        case "infinity_leaderboard_rank_progression":
            return 0"""
content = re.sub(prog_amt_regex, prog_amt_replacement, content)

# 8. completions
completions_regex = r'        case "leaderboard_rank_progression":\n            guard snapshot\.best_leaderboard_rank > 0 else \{ return 0 \}\n            \n            let startIndex = max\(0, highestClaimedLeaderboardTier \+ 1\)'
completions_replacement = """        case "infinity_leaderboard_rank_progression":
            guard snapshot.best_infinity_leaderboard_rank > 0 else { return 0 }
            
            let startIndex = max(0, highestClaimedInfinityLeaderboardTier + 1)
            guard startIndex < Self.leaderboardRankTiers.count else { return 0 }
            return Self.leaderboardRankTiers[startIndex...].filter { snapshot.best_infinity_leaderboard_rank <= $0.milestone }.count

        case "leaderboard_rank_progression":
            guard snapshot.best_leaderboard_rank > 0 else { return 0 }
            
            let startIndex = max(0, highestClaimedLeaderboardTier + 1)"""
content = re.sub(completions_regex, completions_replacement, content)

# 9. progressTierDisplay
tier_disp_regex = r'        case "leaderboard_rank_progression":\n            return leaderboardRankDisplay\.rewards'
tier_disp_replacement = """        case "infinity_leaderboard_rank_progression":
            return infinityLeaderboardRankDisplay.rewards
        case "leaderboard_rank_progression":
            return leaderboardRankDisplay.rewards"""
content = re.sub(tier_disp_regex, tier_disp_replacement, content)

# 10. evaluateCondition
eval_cond_regex = r'        case "best_leaderboard_rank": return \.init\(s\.best_leaderboard_rank\)'
eval_cond_replacement = """        case "best_infinity_leaderboard_rank": return .init(s.best_infinity_leaderboard_rank)
        case "best_leaderboard_rank": return .init(s.best_leaderboard_rank)"""
content = re.sub(eval_cond_regex, eval_cond_replacement, content)

# 11. allTiers
all_tiers_regex = r'        case "leaderboard_rank_progression":\n            return allComboTiers\(tiers: Self\.leaderboardRankTiers, currentTierIndex: displayLeaderboardRankTier\)'
all_tiers_replacement = """        case "infinity_leaderboard_rank_progression":
            return allComboTiers(tiers: Self.leaderboardRankTiers, currentTierIndex: displayInfinityLeaderboardRankTier)
        case "leaderboard_rank_progression":
            return allComboTiers(tiers: Self.leaderboardRankTiers, currentTierIndex: displayLeaderboardRankTier)"""
content = re.sub(all_tiers_regex, all_tiers_replacement, content)

# 12. sortedAchievements visibility
sorted_ach_regex = r'    public var sortedAchievements: \[AchievementDisplay\] \{\n        return definitions\.compactMap \{ definition -> AchievementDisplay\? in\n            if definition\.hidden \{ return nil \}'
sorted_ach_replacement = """    public var sortedAchievements: [AchievementDisplay] {
        return definitions.compactMap { definition -> AchievementDisplay? in
            if definition.hidden { return nil }
            if definition.id == "infinity_leaderboard_rank_progression" && !isLeaderboardRankMaxed {
                return nil
            }"""
content = re.sub(sorted_ach_regex, sorted_ach_replacement, content)


with open("Packages/GameCore/Sources/GameCore/Services/AchievementStore.swift", "w") as f:
    f.write(content)


import re

with open("Packages/GameCore/Sources/GameCore/Services/AchievementStore.swift", "r") as f:
    content = f.read()

# 1. Add properties
props = """    @Published public private(set) var displayLeaderboardRankTier: Int = 0
    @Published public private(set) var highestClaimedLeaderboardTier: Int = -1

    @Published public private(set) var displayInfinityLeaderboardRankTier: Int = 0
    @Published public private(set) var highestClaimedInfinityLeaderboardTier: Int = -1"""

content = re.sub(r'    @Published public private\(set\) var displayLeaderboardRankTier: Int = 0\n    @Published public private\(set\) var highestClaimedLeaderboardTier: Int = -1', props, content)

# 2. Add computed properties
computed = """    public var leaderboardRankDisplay: ProgressTierDisplay {
        let clampedIndex = min(displayLeaderboardRankTier, Self.leaderboardRankTiers.count - 1)
        return Self.leaderboardRankTiers[clampedIndex].display
    }

    /// Current infinity leaderboard rank from Game Center (lower is better)
    public var currentInfinityLeaderboardRank: Int = 0 {
        didSet {
            defaults.set(currentInfinityLeaderboardRank, forKey: "currentInfinityLeaderboardRank")
        }
    }

    public var infinityLeaderboardRankTier: Int {
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

    public var currentInfinityLeaderboardTier: ComboTierDefinition {
        let maxTier = Self.leaderboardRankTiers.count - 1
        let index = min(infinityLeaderboardRankTier, maxTier)
        return Self.leaderboardRankTiers[index]
    }

    public var displayInfinityLeaderboardRankTierDefinition: ComboTierDefinition {
        let index = min(displayInfinityLeaderboardRankTier, Self.leaderboardRankTiers.count - 1)
        return Self.leaderboardRankTiers[index]
    }

    public var infinityLeaderboardRankDisplay: ProgressTierDisplay {
        let clampedIndex = min(displayInfinityLeaderboardRankTier, Self.leaderboardRankTiers.count - 1)
        return Self.leaderboardRankTiers[clampedIndex].display
    }"""

content = re.sub(r'    public var leaderboardRankDisplay: ProgressTierDisplay \{\n        let clampedIndex = min\(displayLeaderboardRankTier, Self.leaderboardRankTiers.count - 1\)\n        return Self.leaderboardRankTiers\[clampedIndex\].display\n    \}', computed, content)

# 3. Add to init
init_load = """        self.highestClaimedLeaderboardTier = defaults.integer(forKey: "highestClaimedLeaderboardTier")
        
        self.currentInfinityLeaderboardRank = defaults.integer(forKey: "currentInfinityLeaderboardRank")
        self.displayInfinityLeaderboardRankTier = defaults.integer(forKey: "displayInfinityLeaderboardRankTier")
        self.highestClaimedInfinityLeaderboardTier = defaults.integer(forKey: "highestClaimedInfinityLeaderboardTier")"""

content = re.sub(r'        self.highestClaimedLeaderboardTier = defaults.integer\(forKey: "highestClaimedLeaderboardTier"\)', init_load, content)

# 4. Add to evaluate re-eval
re_eval = """            // Allow tile_progression and leaderboard progressions to be re-evaluated
            if !(def.id == "tile_progression" || 
                  def.id == "leaderboard_rank_progression" || 
                  def.id == "infinity_leaderboard_rank_progression") && unlockState.claimed {"""

content = re.sub(r'            // Allow tile_progression and leaderboard_rank_progression to be re-evaluated\n            if !\(def.id == "tile_progression" \|\| \n                  def.id == "leaderboard_rank_progression"\) && unlockState.claimed \{', re_eval, content)


# 5. Add to evaluate definition logic
eval_def = """            if def.id == "leaderboard_rank_progression" {
                if snapshot.best_leaderboard_rank > 0 {
                    currentLeaderboardRank = snapshot.best_leaderboard_rank
                }
                
                let qualifyingTier = leaderboardRankTier
                
                if qualifyingTier > highestClaimedLeaderboardTier {
                    newUnlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    displayLeaderboardRankTier = qualifyingTier
                } else if qualifyingTier == highestClaimedLeaderboardTier && highestClaimedLeaderboardTier < Self.leaderboardRankTiers.count - 1 {
                    displayLeaderboardRankTier = qualifyingTier + 1
                }
                
                continue
            }
            
            if def.id == "infinity_leaderboard_rank_progression" {
                // Prerequisite check: leaderboard_rank_progression must be maxed out
                let leaderboardMaxed = (highestClaimedLeaderboardTier >= Self.leaderboardRankTiers.count - 1) && (unlocks["leaderboard_rank_progression"]?.claimed == true)
                guard leaderboardMaxed else { continue }
            
                if snapshot.best_infinity_leaderboard_rank > 0 {
                    currentInfinityLeaderboardRank = snapshot.best_infinity_leaderboard_rank
                }
                
                let qualifyingTier = infinityLeaderboardRankTier
                
                if qualifyingTier > highestClaimedInfinityLeaderboardTier {
                    newUnlocks[def.id] = .init(unlocked: true, unlockedAt: Date(), claimed: false)
                    displayInfinityLeaderboardRankTier = qualifyingTier
                } else if qualifyingTier == highestClaimedInfinityLeaderboardTier && highestClaimedInfinityLeaderboardTier < Self.leaderboardRankTiers.count - 1 {
                    displayInfinityLeaderboardRankTier = qualifyingTier + 1
                }
                
                continue
            }"""

content = re.sub(r'            if def.id == "leaderboard_rank_progression" \{\n                if snapshot.best_leaderboard_rank > 0 \{\n                    currentLeaderboardRank = snapshot.best_leaderboard_rank\n                \}\n                \n                let qualifyingTier = leaderboardRankTier\n                \n                if qualifyingTier > highestClaimedLeaderboardTier \{\n                    newUnlocks\[def.id\] = \.init\(unlocked: true, unlockedAt: Date\(\), claimed: false\)\n                    displayLeaderboardRankTier = qualifyingTier\n                \} else if qualifyingTier == highestClaimedLeaderboardTier && highestClaimedLeaderboardTier < Self.leaderboardRankTiers.count - 1 \{\n                    displayLeaderboardRankTier = qualifyingTier \+ 1\n                \}\n                \n                continue\n            \}', eval_def, content)

# 6. claim() logic
claim_def = """        if definition.id == "leaderboard_rank_progression" {
            let rewards = leaderboardRankDisplay.rewards
            if let onReward = onReward {
                onReward(rewards)
            } else if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }

            // Mark this tier as claimed by advancing highestClaimedLeaderboardTier
            let claimedTierIndex = displayLeaderboardRankTier
            if claimedTierIndex > highestClaimedLeaderboardTier {
                highestClaimedLeaderboardTier = claimedTierIndex
            }

            // If there's another tier, unclaim it so the player can work towards it
            if highestClaimedLeaderboardTier < Self.leaderboardRankTiers.count - 1 {
                unlocks[definition.id] = .init(unlocked: false, unlockedAt: nil, claimed: false)
                displayLeaderboardRankTier = highestClaimedLeaderboardTier + 1
            } else {
                unlocks[definition.id] = .init(unlocked: true, unlockedAt: Date(), claimed: true)
                displayLeaderboardRankTier = highestClaimedLeaderboardTier // cap at max
            }
        }
        
        if definition.id == "infinity_leaderboard_rank_progression" {
            let rewards = infinityLeaderboardRankDisplay.rewards
            if let onReward = onReward {
                onReward(rewards)
            } else if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }

            let claimedTierIndex = displayInfinityLeaderboardRankTier
            if claimedTierIndex > highestClaimedInfinityLeaderboardTier {
                highestClaimedInfinityLeaderboardTier = claimedTierIndex
            }

            if highestClaimedInfinityLeaderboardTier < Self.leaderboardRankTiers.count - 1 {
                unlocks[definition.id] = .init(unlocked: false, unlockedAt: nil, claimed: false)
                displayInfinityLeaderboardRankTier = highestClaimedInfinityLeaderboardTier + 1
            } else {
                unlocks[definition.id] = .init(unlocked: true, unlockedAt: Date(), claimed: true)
                displayInfinityLeaderboardRankTier = highestClaimedInfinityLeaderboardTier // cap at max
            }
        }"""

# Using find and replace for claim since regex can be tricky with this much code
claim_target = """        if definition.id == "leaderboard_rank_progression" {
            let rewards = leaderboardRankDisplay.rewards
            if let onReward = onReward {
                onReward(rewards)
            } else if let gems = rewards.gems, gems > 0 {
                grantGemsDirectly(gems)
            }

            // Mark this tier as claimed by advancing highestClaimedLeaderboardTier
            let claimedTierIndex = displayLeaderboardRankTier
            if claimedTierIndex > highestClaimedLeaderboardTier {
                highestClaimedLeaderboardTier = claimedTierIndex
            }

            // If there's another tier, unclaim it so the player can work towards it
            if highestClaimedLeaderboardTier < Self.leaderboardRankTiers.count - 1 {
                unlocks[definition.id] = .init(unlocked: false, unlockedAt: nil, claimed: false)
                displayLeaderboardRankTier = highestClaimedLeaderboardTier + 1
            } else {
                unlocks[definition.id] = .init(unlocked: true, unlockedAt: Date(), claimed: true)
                displayLeaderboardRankTier = highestClaimedLeaderboardTier // cap at max
            }
        }"""

content = content.replace(claim_target, claim_def)

# 7. saveUnlocks
save_unlocks = """        defaults.set(displayLeaderboardRankTier, forKey: "displayLeaderboardRankTier")
        defaults.set(highestClaimedLeaderboardTier, forKey: "highestClaimedLeaderboardTier")
        defaults.set(displayInfinityLeaderboardRankTier, forKey: "displayInfinityLeaderboardRankTier")
        defaults.set(highestClaimedInfinityLeaderboardTier, forKey: "highestClaimedInfinityLeaderboardTier")"""
content = content.replace('        defaults.set(displayLeaderboardRankTier, forKey: "displayLeaderboardRankTier")\n        defaults.set(highestClaimedLeaderboardTier, forKey: "highestClaimedLeaderboardTier")', save_unlocks)


# 8. evaluateProgress
eval_prog = """        case "leaderboard_rank_progression":
            let qualifyingTier = leaderboardRankTier
            
            if snapshot.best_leaderboard_rank > 0 &&
               snapshot.best_leaderboard_rank <= targetValue &&
               qualifyingTier > highestClaimedLeaderboardTier {
                return 1.0
            }
            return 0.0
            
        case "infinity_leaderboard_rank_progression":
            let qualifyingTier = infinityLeaderboardRankTier
            
            if snapshot.best_infinity_leaderboard_rank > 0 &&
               snapshot.best_infinity_leaderboard_rank <= targetValue &&
               qualifyingTier > highestClaimedInfinityLeaderboardTier {
                return 1.0
            }
            return 0.0"""
content = content.replace("""        case "leaderboard_rank_progression":
            let qualifyingTier = leaderboardRankTier
            
            if snapshot.best_leaderboard_rank > 0 &&
               snapshot.best_leaderboard_rank <= targetValue &&
               qualifyingTier > highestClaimedLeaderboardTier {
                return 1.0
            }
            return 0.0""", eval_prog)

# 9. progressAmount
prog_amt = """        case "leaderboard_rank_progression":
            // No progress bar for leaderboard rank
            return 0
        case "infinity_leaderboard_rank_progression":
            return 0"""
content = content.replace("""        case "leaderboard_rank_progression":
            // No progress bar for leaderboard rank
            return 0""", prog_amt)

# 10. completions
completions = """        case "leaderboard_rank_progression":
            guard snapshot.best_leaderboard_rank > 0 else { return 0 }
            
            guard startIndex < Self.leaderboardRankTiers.count else { return 0 }
            return Self.leaderboardRankTiers[startIndex...].filter { snapshot.best_leaderboard_rank <= $0.milestone }.count
        case "infinity_leaderboard_rank_progression":
            guard snapshot.best_infinity_leaderboard_rank > 0 else { return 0 }
            
            guard startIndex < Self.leaderboardRankTiers.count else { return 0 }
            return Self.leaderboardRankTiers[startIndex...].filter { snapshot.best_infinity_leaderboard_rank <= $0.milestone }.count"""
content = content.replace("""        case "leaderboard_rank_progression":
            guard snapshot.best_leaderboard_rank > 0 else { return 0 }
            
            guard startIndex < Self.leaderboardRankTiers.count else { return 0 }
            return Self.leaderboardRankTiers[startIndex...].filter { snapshot.best_leaderboard_rank <= $0.milestone }.count""", completions)

# 11. progressTierDisplay
tier_disp = """        case "leaderboard_rank_progression":
            return leaderboardRankDisplay.rewards
        case "infinity_leaderboard_rank_progression":
            return infinityLeaderboardRankDisplay.rewards"""
content = content.replace("""        case "leaderboard_rank_progression":
            return leaderboardRankDisplay.rewards""", tier_disp)
            
# 12. evaluateCondition
eval_cond = """        case "best_leaderboard_rank": return .init(s.best_leaderboard_rank)
        case "best_infinity_leaderboard_rank": return .init(s.best_infinity_leaderboard_rank)"""
content = content.replace("""        case "best_leaderboard_rank": return .init(s.best_leaderboard_rank)""", eval_cond)

# 13. allTiers
all_tiers = """        case "leaderboard_rank_progression":
            return allComboTiers(tiers: Self.leaderboardRankTiers, currentTierIndex: displayLeaderboardRankTier)
        case "infinity_leaderboard_rank_progression":
            return allComboTiers(tiers: Self.leaderboardRankTiers, currentTierIndex: displayInfinityLeaderboardRankTier)"""
content = content.replace("""        case "leaderboard_rank_progression":
            return allComboTiers(tiers: Self.leaderboardRankTiers, currentTierIndex: displayLeaderboardRankTier)""", all_tiers)
            
# 14. sortedAchievements visibility
sorted_achievements = """    public var sortedAchievements: [AchievementDisplay] {
        let maxLeaderboardTier = Self.leaderboardRankTiers.count - 1
        let leaderboardMaxed = (highestClaimedLeaderboardTier >= maxLeaderboardTier) && (unlocks["leaderboard_rank_progression"]?.claimed == true)
        
        return definitions.compactMap { definition -> AchievementDisplay? in
            if definition.hidden { return nil }
            if definition.id == "infinity_leaderboard_rank_progression" && !leaderboardMaxed {
                return nil
            }
            let isUnlocked = unlocks[definition.id]?.unlocked ?? false"""
content = content.replace("""    public var sortedAchievements: [AchievementDisplay] {
        return definitions.compactMap { definition -> AchievementDisplay? in
            if definition.hidden { return nil }
            let isUnlocked = unlocks[definition.id]?.unlocked ?? false""", sorted_achievements)


with open("Packages/GameCore/Sources/GameCore/Services/AchievementStore.swift", "w") as f:
    f.write(content)


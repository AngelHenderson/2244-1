import Testing
import Foundation
@testable import GameApp
@testable import GameCore

@Suite("Rewards Contract Tests")
struct RewardsContractTests {

    @Test("Spin wheel has weighted rewards")
    func spinWheelWeightedRewards() async {
        let spinWheel = SpinWheelEngine()

        let rewards = spinWheel.availableRewards
        #expect(rewards.count > 0)

        for reward in rewards {
            #expect(reward.weight > 0)
            #expect(reward.weight <= 100)
        }

        let totalWeight = rewards.reduce(0) { $0 + $1.weight }
        #expect(totalWeight == 100)
    }

    @Test("Daily streak rewards increase progressively")
    func dailyStreakProgression() async {
        let streakManager = DailyStreakManager()

        let day1Reward = streakManager.rewardFor(streak: 1)
        let day7Reward = streakManager.rewardFor(streak: 7)
        let day30Reward = streakManager.rewardFor(streak: 30)

        #expect(day1Reward.coins == 10)
        #expect(day7Reward.coins == 100)
        #expect(day30Reward.coins == 500)
    }

    @Test("Milestone rewards unlock at specific levels")
    func milestoneRewards() async {
        let milestoneSystem = MilestoneSystem()

        let level5Reward = milestoneSystem.rewardFor(level: 5)
        let level10Reward = milestoneSystem.rewardFor(level: 10)
        let level25Reward = milestoneSystem.rewardFor(level: 25)

        #expect(level5Reward != nil)
        #expect(level10Reward != nil)
        #expect(level25Reward != nil)

        #expect(level5Reward?.coins == 50)
        #expect(level10Reward?.powerUps[.hammer] == 3)
        #expect(level25Reward?.hasThemeUnlock == true)
    }

    @Test("Achievement rewards are one-time only")
    func achievementRewardsOneTime() async {
        let achievementManager = AchievementManager()

        let firstClaim = achievementManager.claimReward(for: "first_merge")
        let secondClaim = achievementManager.claimReward(for: "first_merge")

        #expect(firstClaim != nil)
        #expect(secondClaim == nil)
    }

    @Test("Chain combo rewards scale with chain length")
    func chainComboRewards() async {
        let rewardCalculator = RewardCalculator()

        let chain3Reward = rewardCalculator.rewardForChain(length: 3)
        let chain5Reward = rewardCalculator.rewardForChain(length: 5)
        let chain7Reward = rewardCalculator.rewardForChain(length: 7)

        #expect(chain3Reward.coins == 6)
        #expect(chain5Reward.coins == 20)
        #expect(chain7Reward.coins == 42)

        #expect(chain3Reward.experience == 15)
        #expect(chain5Reward.experience == 50)
        #expect(chain7Reward.experience == 70)
    }

    @Test("Time-limited offers have expiration")
    func timeLimitedOffers() async {
        let offerManager = OfferManager()

        let currentOffer = offerManager.currentOffer
        #expect(currentOffer != nil)
        #expect(currentOffer!.expiresAt > Date())
        #expect(currentOffer!.discount > 0)
        #expect(currentOffer!.discount <= 50)
    }

    @Test("Leaderboard rewards for top positions")
    func leaderboardRewards() async {
        let leaderboardRewards = LeaderboardRewardSystem()

        let first = leaderboardRewards.rewardFor(position: 1)
        let second = leaderboardRewards.rewardFor(position: 2)
        let third = leaderboardRewards.rewardFor(position: 3)
        let top10 = leaderboardRewards.rewardFor(position: 10)
        let top100 = leaderboardRewards.rewardFor(position: 100)

        #expect(first.coins == 1000)
        #expect(second.coins == 500)
        #expect(third.coins == 250)
        #expect(top10.coins == 100)
        #expect(top100.coins == 25)
    }

    @Test("Project task completion rewards")
    func projectTaskRewards() async {
        let taskManager = ProjectTaskManager()

        let easyTask = taskManager.rewardFor(difficulty: .easy)
        let mediumTask = taskManager.rewardFor(difficulty: .medium)
        let hardTask = taskManager.rewardFor(difficulty: .hard)

        #expect(easyTask.coins == 10)
        #expect(easyTask.experience == 20)

        #expect(mediumTask.coins == 25)
        #expect(mediumTask.experience == 50)

        #expect(hardTask.coins == 50)
        #expect(hardTask.experience == 100)
    }
}

struct SpinWheelReward {
    let type: RewardType
    let weight: Int
    let coins: Int
    let powerUps: [PowerUpType: Int]
}

struct DailyReward {
    let coins: Int
    let powerUps: [PowerUpType: Int]
}

struct MilestoneReward {
    let coins: Int
    let powerUps: [PowerUpType: Int]
    let hasThemeUnlock: Bool
}

struct ChainReward {
    let coins: Int
    let experience: Int
}

struct LeaderboardReward {
    let coins: Int
    let powerUps: [PowerUpType: Int]
}

struct TaskReward {
    let coins: Int
    let experience: Int
}

enum RewardType {
    case coins
    case powerUp
    case theme
    case experience
}

enum TaskDifficulty {
    case easy
    case medium
    case hard
}

class SpinWheelEngine {
    var availableRewards: [SpinWheelReward] = [
        SpinWheelReward(type: .coins, weight: 50, coins: 10, powerUps: [:]),
        SpinWheelReward(type: .coins, weight: 30, coins: 25, powerUps: [:]),
        SpinWheelReward(type: .powerUp, weight: 15, coins: 0, powerUps: [.hammer: 1]),
        SpinWheelReward(type: .powerUp, weight: 5, coins: 0, powerUps: [.undo: 2])
    ]
}

class DailyStreakManager {
    func rewardFor(streak: Int) -> DailyReward {
        switch streak {
        case 1: return DailyReward(coins: 10, powerUps: [:])
        case 7: return DailyReward(coins: 100, powerUps: [.hammer: 1])
        case 30: return DailyReward(coins: 500, powerUps: [.hammer: 3, .swap: 2])
        default: return DailyReward(coins: 10, powerUps: [:])
        }
    }
}

class MilestoneSystem {
    func rewardFor(level: Int) -> MilestoneReward? {
        switch level {
        case 5: return MilestoneReward(coins: 50, powerUps: [:], hasThemeUnlock: false)
        case 10: return MilestoneReward(coins: 100, powerUps: [.hammer: 3], hasThemeUnlock: false)
        case 25: return MilestoneReward(coins: 250, powerUps: [.hammer: 5, .swap: 3], hasThemeUnlock: true)
        default: return nil
        }
    }
}

class AchievementManager {
    private var claimedAchievements: Set<String> = []

    func claimReward(for achievementId: String) -> TaskReward? {
        guard !claimedAchievements.contains(achievementId) else {
            return nil
        }
        claimedAchievements.insert(achievementId)
        return TaskReward(coins: 25, experience: 50)
    }
}

class RewardCalculator {
    func rewardForChain(length: Int) -> ChainReward {
        let coins = length * length - length
        let experience = length * 5 + (length > 4 ? length * 5 : 0)
        return ChainReward(coins: coins, experience: experience)
    }
}

struct TimeLimitedOffer {
    let expiresAt: Date
    let discount: Int
}

class OfferManager {
    var currentOffer: TimeLimitedOffer? {
        return TimeLimitedOffer(
            expiresAt: Date().addingTimeInterval(86400),
            discount: 30
        )
    }
}

class LeaderboardRewardSystem {
    func rewardFor(position: Int) -> LeaderboardReward {
        switch position {
        case 1: return LeaderboardReward(coins: 1000, powerUps: [.hammer: 10])
        case 2: return LeaderboardReward(coins: 500, powerUps: [.hammer: 5])
        case 3: return LeaderboardReward(coins: 250, powerUps: [.hammer: 3])
        case 4...10: return LeaderboardReward(coins: 100, powerUps: [.hammer: 1])
        case 11...100: return LeaderboardReward(coins: 25, powerUps: [:])
        default: return LeaderboardReward(coins: 0, powerUps: [:])
        }
    }
}

class ProjectTaskManager {
    func rewardFor(difficulty: TaskDifficulty) -> TaskReward {
        switch difficulty {
        case .easy: return TaskReward(coins: 10, experience: 20)
        case .medium: return TaskReward(coins: 25, experience: 50)
        case .hard: return TaskReward(coins: 50, experience: 100)
        }
    }
}

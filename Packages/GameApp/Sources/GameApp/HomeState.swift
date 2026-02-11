import Foundation
import Observation

private let kCreateUnlockedKey = "com.game2244.createUnlocked"
private let kChallengeUnlockedKey = "com.game2244.challengeUnlocked"

@MainActor
@Observable
public final class HomeState {
    // Top HUD
    public var rank: Int = 4564  // Default for "16M" milestone, will be updated on load
    public var gems: Int = 305

    // Progression
    public var highestTile: Int = 2048
    public var highestTileStep: Int = 0  // Step index for milestone-based calculations
    public var milestoneBelow: Int = 1024
    public var lockedMilestones: [Int] = [4096, 8192]

    // Badges & locks
    public var hasDailyBadge = true
    public var hasFreeSpinBadge = true
    public var hasShopBadge = true
    public var hasProfileBadge = true
    public var achievementsBadgeCount: Int = 0
    // Unlock thresholds (power-of-two milestones)
    public var createUnlockAt: Int = 1_048_576 // 2^20 (1M)
    public var challengeUnlockAt: Int = 1_073_741_824 // 2^30 (1B)

    /// Whether the Create button is locked (persisted - once unlocked, stays unlocked)
    public var isCreateLocked: Bool {
        get { !UserDefaults.standard.bool(forKey: kCreateUnlockedKey) }
        set { UserDefaults.standard.set(!newValue, forKey: kCreateUnlockedKey) }
    }

    /// Whether the Challenge button is locked (persisted - once unlocked, stays unlocked)
    public var isChallengeLocked: Bool {
        get { !UserDefaults.standard.bool(forKey: kChallengeUnlockedKey) }
        set { UserDefaults.standard.set(!newValue, forKey: kChallengeUnlockedKey) }
    }

    /// Check if Create should be unlocked based on highest tile achieved
    public func checkCreateUnlock(highestTileEver: Int) {
        if highestTileEver >= createUnlockAt && isCreateLocked {
            isCreateLocked = false
        }
    }

    /// Check if Challenge should be unlocked based on highest tile achieved
    public func checkChallengeUnlock(highestTileEver: Int) {
        if highestTileEver >= challengeUnlockAt && isChallengeLocked {
            isChallengeLocked = false
        }
    }

    // Live-ops
    /// Ad reward starts at 50 gems and increases by +3 for each milestone starting from 512 (step 8)
    public var adReward: Int {
        let milestonesAbove512 = max(0, highestTileStep - 8)
        return 50 + (milestonesAbove512 * 3)
    }

    /// Current weekly offer deadline (Saturday 11:59:59 PM)
    public var bestOfferDeadline: Date? {
        WeeklyOfferManager.currentOfferDeadline()
    }

    /// Current weekly offer
    public var currentWeeklyOffer: WeeklyOfferManager.WeeklyOffer {
        WeeklyOfferManager.currentOffer()
    }

    // Personalization
    public var themesLeftName = "Beach"
    public var themesRightName = "Aqua"
    public var isMusicOn = true

    // Mutations
    public func addGems(_ amount: Int) { gems = max(0, gems + amount) }
    public func spendGems(_ amount: Int) { gems = max(0, gems - amount) }
    
    public init() {}
}

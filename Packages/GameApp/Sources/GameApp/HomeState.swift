import Foundation
import Observation

@MainActor
@Observable
public final class HomeState {
    // Top HUD
    public var rank: Int = 4564  // Default for "16M" milestone, will be updated on load
    public var gems: Int = 305

    // Progression
    public var highestTile: Int = 2048
    public var milestoneBelow: Int = 1024
    public var lockedMilestones: [Int] = [4096, 8192]

    // Badges & locks
    public var hasDailyBadge = true
    public var hasFreeSpinBadge = true
    public var hasShopBadge = true
    public var hasProfileBadge = true
    public var achievementsBadgeCount: Int = 0
    public var isCreateLocked = true
    public var isChallengeLocked = true
    // Unlock thresholds (power-of-two milestones)
    public var createUnlockAt: Int = 1_048_576 // 2^20
    public var challengeUnlockAt: Int = 1_048_576 // 2^20

    // Live-ops
    public var adReward: Int = 68

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

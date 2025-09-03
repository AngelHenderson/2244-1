import Foundation
import Observation

@MainActor
@Observable
public final class HomeState {
    // Top HUD
    public var rank: Int = 231_105
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
    public var hasAchievementsBadge = true
    public var isCreateLocked = true
    public var isChallengeLocked = true

    // Live-ops
    public var adReward: Int = 68
    public var bestOfferDeadline: Date? = Date().addingTimeInterval(49*60) // ~49m demo

    // Personalization
    public var themesLeftName = "Beach"
    public var themesRightName = "Aqua"
    public var isMusicOn = true

    // Mutations
    public func addGems(_ amount: Int) { gems = max(0, gems + amount) }
    public func spendGems(_ amount: Int) { gems = max(0, gems - amount) }
    
    public init() {}
}

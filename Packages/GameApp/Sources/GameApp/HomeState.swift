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

    // Ban state
    /// Whether the player is currently banned. When true, all app functionality is disabled.
    /// This would be set by a backend check on login, not hardcoded.
    public var isBanned: Bool = false
    /// The reason for the ban (shown in the alert)
    public var banReasonText: String = ""
    /// The ban duration text (shown in the alert)
    public var banDurationText: String = ""
    /// Controls visibility of the ban alert popup
    public var showBanAlert: Bool = false

    // Pre-ban warning system (first offense only — 3 chances before first ban)
    /// Warnings remaining before the first ban (starts at 3)
    public var warningsRemaining: Int = 3
    /// Controls visibility of the warning alert popup
    public var showWarningAlert: Bool = false
    /// How many times this player has been banned (determines escalation)
    public var offenseCount: Int = 0

    // Ban escalation ladder: each subsequent ban gets longer
    // 1d → 2d → 3d → 1wk → 2wk → 3wk → 1mo → 2mo → 6mo → 1yr → 2yr → 3yr → 4yr → 5yr → permanent
    private static let escalationLadder: [(days: Int, label: String)] = [
        (1, "1 day"),
        (2, "2 days"),
        (3, "3 days"),
        (7, "1 week"),
        (14, "2 weeks"),
        (21, "3 weeks"),
        (30, "1 month"),
        (60, "2 months"),
        (180, "6 months"),
        (365, "1 year"),
        (730, "2 years"),
        (1095, "3 years"),
        (1460, "4 years"),
        (1825, "5 years"),
        (Int.max, "permanently")
    ]

    /// Look up the ban duration for the given offense number (1-based).
    private static func banDuration(forOffense offense: Int) -> String {
        let index = min(offense - 1, escalationLadder.count - 1)
        let tier = escalationLadder[max(0, index)]
        if tier.days == Int.max {
            return "Your account has been permanently banned."
        }
        return "Your account has been suspended for \(tier.label)."
    }

    /// Issue a warning. Players get 3 chances before their first ban.
    /// After warnings are exhausted, a ban is applied using the escalation ladder.
    public func issueWarning(reason: String) {
        if warningsRemaining > 1 {
            warningsRemaining -= 1
            showWarningAlert = true
        } else {
            // Out of chances — activate the ban
            warningsRemaining = 0
            offenseCount += 1
            isBanned = true
            banReasonText = reason
            banDurationText = HomeState.banDuration(forOffense: offenseCount)
            showBanAlert = true
        }
    }
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

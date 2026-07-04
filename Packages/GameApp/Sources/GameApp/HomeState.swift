import Foundation
import Observation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

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

    /// Whether the player is banned specifically from comments/feed
    public var isBannedFromComments: Bool = false
    /// Controls visibility of the comment ban alert popup
    public var showCommentBanAlert: Bool = false
    /// Exact timestamp when the ban started (used for precise unban timing)
    public var banStartDate: Date? = nil
    /// Exact timestamp when the ban ends (nil = permanent)
    /// Ban/unban uses exact time — banned at 8:34 AM means unbanned at exactly 8:34 AM.
    public var banEndDate: Date? = nil

    // MARK: - Local moderation (block/hide list)
    /// IDs of players the local user has chosen to hide. Persisted via UserDefaults
    /// so the list survives between sessions. Reports go to the cloud through
    /// `ReportService`; the block list is a separate purely-local affordance.
    public private(set) var blockedPlayerIDs: Set<String> = HomeState.loadBlockedIDs()

    public func block(playerID: String) {
        guard !playerID.isEmpty else { return }
        blockedPlayerIDs.insert(playerID)
        Self.persistBlockedIDs(blockedPlayerIDs)
        pushBlockedToCloud()
    }

    public func unblock(playerID: String) {
        blockedPlayerIDs.remove(playerID)
        Self.persistBlockedIDs(blockedPlayerIDs)
        pushBlockedToCloud()
    }

    public func isBlocked(playerID: String) -> Bool {
        blockedPlayerIDs.contains(playerID)
    }

    /// Bootstrap block-list cloud sync. Call after Firebase Auth has signed
    /// the user in. The first run merges the remote set into the local set
    /// (union semantics) and pushes the merged result back; subsequent
    /// `block` / `unblock` calls write through.
    public func startBlockedPlayersCloudSync() async {
        #if canImport(FirebaseFirestore)
        guard FirebaseApp.app() != nil,
              let uid = currentAuthUID(),
              !uid.isEmpty
        else { return }
        let firestore = Firestore.firestore()
        let doc = firestore.collection("players")
            .document(uid)
            .collection("progress")
            .document("blocked")
        blockedPlayersDoc = doc
        do {
            let snapshot = try await doc.getDocument()
            let remote: [String]
            if let array = snapshot.data()?["ids"] as? [String] {
                remote = array
            } else {
                remote = []
            }
            let merged = blockedPlayerIDs.union(remote)
            if merged != blockedPlayerIDs {
                blockedPlayerIDs = merged
                Self.persistBlockedIDs(blockedPlayerIDs)
            }
            try await doc.setData([
                "ids": Array(merged).sorted(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            #if DEBUG
            print("⚠️ HomeState block-list cloud sync failed: \(error.localizedDescription)")
            #endif
        }
        #endif
    }

    private func pushBlockedToCloud() {
        #if canImport(FirebaseFirestore)
        guard let doc = blockedPlayersDoc else { return }
        let snapshot = Array(blockedPlayerIDs).sorted()
        Task {
            do {
                try await doc.setData([
                    "ids": snapshot,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
            } catch {
                #if DEBUG
                print("⚠️ HomeState block-list cloud push failed: \(error.localizedDescription)")
                #endif
            }
        }
        #endif
    }

    #if canImport(FirebaseFirestore)
    private var blockedPlayersDoc: DocumentReference?
    #endif

    private func currentAuthUID() -> String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }

    private static let blockedPlayersKey = "com.game2244.blockedPlayerIDs"

    private static func loadBlockedIDs() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: blockedPlayersKey) ?? []
        return Set(array)
    }

    private static func persistBlockedIDs(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: blockedPlayersKey)
    }

    // Pre-ban warning system (first offense only — 3 chances before first ban)
    /// Warnings remaining before the first ban (starts at 3)
    public var warningsRemaining: Int = 3
    /// Controls visibility of the warning alert popup
    public var showWarningAlert: Bool = false
    /// How many times this player has been banned (determines escalation)
    public var offenseCount: Int = 0

    // Ban escalation ladder: each subsequent ban gets longer
    // 1d → 2d → 3d → 1wk → 2wk → 3wk → 1mo → 2mo → 6mo → 1yr → 2yr → 5yr → permanent
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
        (1825, "5 years"),
        (Int.max, "permanently")
    ]

    /// Look up the ban tier for the given offense number (1-based).
    private static func banTier(forOffense offense: Int) -> (days: Int, label: String) {
        let index = min(offense - 1, escalationLadder.count - 1)
        return escalationLadder[max(0, index)]
    }

    /// Check if the ban has expired at the exact timestamp. Call this on app launch / timer.
    /// If the ban end time has passed, automatically unban the player.
    public func checkBanExpiry() {
        guard isBanned, let endDate = banEndDate else { return }
        if Date() >= endDate {
            isBanned = false
            banReasonText = ""
            banDurationText = ""
            banStartDate = nil
            banEndDate = nil
        }
    }

    /// Human-readable remaining ban time (e.g. "2d 6h 48m 52s remaining")
    public var banTimeRemainingText: String? {
        guard isBanned, let endDate = banEndDate else {
            if isBanned && banEndDate == nil { return "Permanent" }
            return nil
        }
        let remaining = endDate.timeIntervalSince(Date())
        guard remaining > 0 else { return "Expiring..." }
        let total = Int(remaining)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m \(seconds)s remaining"
        } else {
            return "\(hours)h \(minutes)m \(seconds)s remaining"
        }
    }

    /// Issue a warning. Players get 3 chances before their first ban.
    /// After warnings are exhausted, a ban is applied using the escalation ladder
    /// with exact timestamps — banned at 8:34 AM means unbanned at exactly 8:34 AM.
    public func issueWarning(reason: String) {
        if warningsRemaining > 1 {
            warningsRemaining -= 1
            showWarningAlert = true
        } else {
            // Out of chances — activate the ban with exact timestamp
            warningsRemaining = 0
            offenseCount += 1
            let tier = HomeState.banTier(forOffense: offenseCount)
            let now = Date()

            isBanned = true
            banReasonText = reason
            banStartDate = now

            if tier.days == Int.max {
                // Permanent ban — no end date
                banEndDate = nil
                banDurationText = "Your account has been permanently banned."
            } else {
                // Calculate exact unban time: now + tier.days (same time of day)
                banEndDate = Calendar.current.date(byAdding: .day, value: tier.days, to: now)
                banDurationText = "Your account has been suspended for \(tier.label)."
            }
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
    
    // Badge calculation for NPC replies
    public var npcRepliesBadgeCount: Int = 0

    public func updateNpcRepliesBadgeCount() {
        let defaults = UserDefaults.standard
        guard let items = MockSocialService.loadUserPosts() else {
            self.npcRepliesBadgeCount = 0
            return
        }
        
        let lastViewed = defaults.object(forKey: "socialFeed.lastViewedDate") as? Date ?? Date.distantPast
        
        let playerName = defaults.string(forKey: "profilePlayerName") ?? "Player"
        let playerDisplayNameAlt = defaults.string(forKey: "player.displayName") ?? "Player"
        
        let isPlayer: (String) -> Bool = { name in
            name.lowercased() == playerName.lowercased() || name.lowercased() == playerDisplayNameAlt.lowercased()
        }
        
        let mentionsPlayer: (String) -> Bool = { text in
            let lower = text.lowercased()
            return lower.contains("@\(playerName.lowercased())") || lower.contains("@\(playerDisplayNameAlt.lowercased())")
        }
        
        var count = 0
        let now = Date()
        for post in items {
            for comment in post.comments {
                guard comment.createdAt <= now else { continue }
                guard comment.createdAt > lastViewed else { continue }
                if isPlayer(comment.authorName) { continue }
                
                if isPlayer(post.authorName) {
                    count += 1
                } else {
                    if mentionsPlayer(comment.text) {
                        count += 1
                    }
                }
            }
        }
        self.npcRepliesBadgeCount = count
    }
    
    public init() {
        updateNpcRepliesBadgeCount()
    }
}


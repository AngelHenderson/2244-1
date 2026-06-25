import Foundation

/// Lightweight helper that publishes real player events to the social feed.
/// Call these methods from UI views when the player achieves something.
@MainActor
public final class SocialFeedPublisher {
    private let socialService: any SocialService

    public init(socialService: any SocialService) {
        self.socialService = socialService
    }

    // MARK: - Deduplication

    private static let postedEventsKey = "socialFeed.postedEvents"

    /// Prevents posting the same event type more than once per day.
    private func shouldPost(eventKey: String) -> Bool {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        let dict = defaults.dictionary(forKey: Self.postedEventsKey) as? [String: Double] ?? [:]
        if let lastPosted = dict[eventKey], lastPosted == today {
            return false
        }
        return true
    }

    private func markPosted(eventKey: String) {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        var dict = defaults.dictionary(forKey: Self.postedEventsKey) as? [String: Double] ?? [:]
        dict[eventKey] = today
        defaults.set(dict, forKey: Self.postedEventsKey)
    }

    // MARK: - Event Publishers

    /// Post when the player reaches a new highest tile in Endless mode.
    public func postEndlessMilestone(tileName: String) {
        let key = "endless_\(tileName)"
        guard shouldPost(eventKey: key) else { return }
        markPosted(eventKey: key)

        let templates = [
            "Reached the \(tileName) tile in the game!",
            "Just hit \(tileName) for the first time!",
            "NEW personal best — \(tileName) tile unlocked in game!",
            "\(tileName) tile reached! The grind never stops.",
            "Finally broke through to \(tileName) in the gameplay!",
            "After so many attempts… \(tileName) is MINE!",
        ]
        let stats = [
            "puzzlepiece.fill|New tile · Endless",
            "medal|Milestone · \(tileName)",
            "chart.bar.fill|Personal best · Endless",
            "flame|Breakthrough · \(tileName)",
        ]
        Task {
            try? await socialService.postEvent(
                message: templates.randomElement()!,
                statText: stats.randomElement()!
            )
        }
    }

    /// Post when the player completes the daily timed challenge.
    public func postTimedChallengeComplete(timeString: String) {
        let key = "timed_challenge"
        guard shouldPost(eventKey: key) else { return }
        markPosted(eventKey: key)

        let templates = [
            "Finished the daily timed challenge in \(timeString)!",
            "Crushed today's speed run in \(timeString) flat.",
            "Beat the clock: \(timeString).",
            "Cleared the timed challenge in \(timeString).",
            "Completed the daily speed challenge with a time of \(timeString).",
        ]
        let stats = [
            "timer|Timed challenge · \(timeString)",
            "flag.fill|Daily challenge · Done",
            "bolt|Speed clear · \(timeString)",
            "target|Challenge · \(timeString) finish",
        ]
        Task {
            try? await socialService.postEvent(
                message: templates.randomElement()!,
                statText: stats.randomElement()!
            )
        }
    }

    /// Post when the player's daily streak is maintained.
    public func postStreakMaintained(days: Int) {
        let key = "streak_\(days)"
        guard shouldPost(eventKey: key) else { return }
        markPosted(eventKey: key)

        let templates: [String] = [
            "Protected a \(days)-day streak!",
            "Saved my \(days)-day streak.",
            "Kept the streak alive at \(days) days.",
            "Extended my streak to \(days) days.",
            "Another day, another streak point. (\(days) days)",
        ]
        let stat = days >= 100 ? "flame.fill|\(days)-day streak · Legend" :
                  days >= 30 ? "flame|\(days)-day streak · Dedicated" :
                  "shield|Streak protected · \(days) days"

        Task {
            try? await socialService.postEvent(
                message: templates.randomElement()!,
                statText: stat
            )
        }
    }

    /// Post when the player reaches the Hall of Fame.
    public func postHallOfFame(infinityCount: Int) {
        let key = "hof_\(infinityCount)"
        guard shouldPost(eventKey: key) else { return }
        markPosted(eventKey: key)

        let templates: [String]
        if infinityCount <= 1 {
            templates = [
                "Made it into the Hall of Fame!",
                "Joined the infinity club.",
                "Unlocked Hall of Fame status.",
                "Earned a spot on the legends board.",
            ]
        } else {
            templates = [
                "Made it into HoF glory — \(infinityCount) infinities strong.",
                "Made it into the infinity club with \(infinityCount) infinities. Legendary!",
                "Hall of Fame update: \(infinityCount) infinities and climbing!",
            ]
        }
        let stat = "infinity|Hall of Fame · \(infinityCount) \(infinityCount == 1 ? "infinity" : "infinities")"
        Task {
            try? await socialService.postEvent(
                message: templates.randomElement()!,
                statText: stat
            )
        }
    }

    /// Post when the player equips a new theme.
    public func postThemeEquipped(themeName: String) {
        // Theme customization reactions and feed posts are not in distribution.
    }

    /// Post when the player completes all daily quests.
    public func postDailyQuestsComplete(chestTier: String? = nil) {
        // Daily quest reactions and feed posts are not in distribution.
    }
}

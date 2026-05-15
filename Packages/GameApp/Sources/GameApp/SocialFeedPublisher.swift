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
            "Reached the \(tileName) tile in Endless!",
            "Just hit \(tileName) for the first time! 🎯",
            "NEW personal best — \(tileName) tile unlocked in Endless!",
            "\(tileName) tile reached! The grind never stops.",
            "Finally broke through to \(tileName) in Endless mode!",
            "After so many attempts… \(tileName) is MINE! 🏆",
        ]
        let stats = [
            "🧩 New tile · Endless",
            "🏅 Milestone · \(tileName)",
            "📈 Personal best · Endless",
            "🔥 Breakthrough · \(tileName)",
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
            "Finished today's timed challenge in \(timeString)!",
            "Crushed the daily timed challenge with \(timeString) clear time ⏱️",
            "Beat the clock! Timed challenge done in \(timeString).",
            "Today's timed challenge wasn't even close. \(timeString).",
            "Cleared the timed challenge clocking \(timeString) 🚀",
        ]
        let stats = [
            "⏱️ Timed challenge · \(timeString)",
            "🏁 Daily challenge · Done",
            "⚡ Speed clear · \(timeString)",
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

        let templates: [String]
        if days >= 100 {
            templates = [
                "Defended \(days) days running. Legendary commitment! 🏆",
                "Maintained a \(days)-day streak. Triple digits! 💯",
                "Day \(days) — still going strong. Unstoppable.",
                "\(days) days straight. This streak is a lifestyle. 🔥",
            ]
        } else {
            templates = [
                "Defended \(days) days running. Steady progress!",
                "Maintained a \(days)-day streak. Day by day 🔥",
                "Protected a \(days)-day streak. Can't stop, won't stop!",
                "\(days) consecutive days. Consistency is key!",
            ]
        }
        let emoji = days >= 100 ? "🏆" : (days >= 30 ? "🔥" : "✅")
        let label = days >= 100 ? "Legendary" : (days >= 30 ? "Dedicated" : "Active")
        let stat = "\(emoji) \(days)-day streak · \(label)"

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
                "Entered the Hall of Fame! Infinity reached! ∞",
                "Unlocked the Hall of Fame. Still pushing for more.",
                "Made it to the Hall of Fame — the ultimate milestone! 🏆",
            ]
        } else {
            templates = [
                "Made it into HoF glory — \(infinityCount) infinities strong. 💎",
                "Made it into the infinity club with ∞×\(infinityCount). Legendary!",
                "Hall of Fame update: \(infinityCount) infinity counts and climbing!",
            ]
        }
        let stat = "💎 HoF · \(infinityCount) \(infinityCount == 1 ? "infinity" : "infinities")"
        Task {
            try? await socialService.postEvent(
                message: templates.randomElement()!,
                statText: stat
            )
        }
    }

    /// Post when the player equips a new theme.
    public func postThemeEquipped(themeName: String) {
        let key = "theme_\(themeName)"
        guard shouldPost(eventKey: key) else { return }
        markPosted(eventKey: key)

        let templates = [
            "Switched to the \(themeName) style 🎨 Fresh look alert!",
            "Equipped the \(themeName) aesthetic — time to play in style.",
            "Activated the \(themeName) style. Even better than I expected!",
            "Switched to the \(themeName) color palette. New look, who dis?",
        ]
        let stat = "🎨 New theme · \(themeName)"
        Task {
            try? await socialService.postEvent(
                message: templates.randomElement()!,
                statText: stat
            )
        }
    }

    /// Post when the player completes all daily quests.
    public func postQuestsComplete(chestTier: String? = nil) {
        let key = "quests_complete"
        guard shouldPost(eventKey: key) else { return }
        markPosted(eventKey: key)

        let tierText = chestTier ?? "reward"
        let templates = [
            "All daily quests complete! \(tierText) chest earned 🎁",
            "Finished every quest today. Clean sweep!",
            "Daily quests demolished — time to collect! 💰",
            "Quest objectives cleared. Another day, another chest!",
        ]
        let stat = "🎯 Daily Quests · Complete"
        Task {
            try? await socialService.postEvent(
                message: templates.randomElement()!,
                statText: stat
            )
        }
    }
}

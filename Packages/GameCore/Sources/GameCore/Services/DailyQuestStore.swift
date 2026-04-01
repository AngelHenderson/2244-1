import Foundation

@MainActor
@Observable
public final class DailyQuestStore {

    // MARK: - Types

    public struct Quest: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let description: String
        public let target: Int
        public var current: Int
        public let rewards: AchievementDef.Rewards
        public var claimed: Bool

        public var isComplete: Bool { current >= target }
        public var isClaimable: Bool { isComplete && !claimed }
        public var progress: Double {
            guard target > 0 else { return 0 }
            return min(1.0, Double(current) / Double(target))
        }
    }

    // MARK: - Public State

    public private(set) var quests: [Quest] = []
    public var onReward: (@MainActor (AchievementDef.Rewards) -> Void)?

    /// The tile step target for quest #3

    /// locked in at the start of each day
    public private(set) var tileQuestTargetStep: Int = 0

    // MARK: - Persistence Keys

    private static let lastResetDateKey = "dailyQuests.lastResetDate"
    private static let questProgressPrefix = "dailyQuests.progress."
    private static let questClaimedPrefix = "dailyQuests.claimed."
    private static let tileTargetStepKey = "dailyQuests.tileTargetStep"

    private let defaults: UserDefaults

    // MARK: - Init

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        resetIfNewDay()
    }

    // MARK: - Quest Definitions

    private static func makeQuestDefinitions() -> [Quest] {
        [
            Quest(
                id: "daily_merge_tiles",
                title: "Merge 2,000 Tiles",
                description: "Merge a total of 2,000 tiles today.",
                target: 2000,
                current: 0,
                rewards: AchievementDef.Rewards(
                    gems: 500, spins: 1, hammers: 1, swaps: 1, boost3x: 1
                ),
                claimed: false
            ),
            Quest(
                id: "daily_use_powerups",
                title: "Use Powerups 5 Times",
                description: "Use any powerup 5 times today.",
                target: 5,
                current: 0,
                rewards: AchievementDef.Rewards(
                    spins: 1, magnets: 1
                ),
                claimed: false
            ),
            Quest(
                id: "daily_tile_reach",
                title: "Reach a New Tile Height",
                description: "Create a tile 10 steps above your highest.",
                target: 1,  // Binary: 0 or 1 (reached or not)
                current: 0,
                rewards: AchievementDef.Rewards(
                    spins: 1, swaps: 1, boost4x: 1
                ),
                claimed: false
            ),
            Quest(
                id: "daily_create_challenge",
                title: "Create & Complete a Challenge",
                description: "Create at least 1 custom challenge and complete it.",
                target: 1,
                current: 0,
                rewards: AchievementDef.Rewards(
                    spins: 2
                ),
                claimed: false
            ),
            Quest(
                id: "daily_complete_challenge",
                title: "Complete a Challenge",
                description: "Complete at least one challenge in challenge mode.",
                target: 1,
                current: 0,
                rewards: AchievementDef.Rewards(
                    gems: 780, magnets: 1, boost2x: 1, boost3x: 1
                ),
                claimed: false
            ),
            Quest(
                id: "daily_complete_all",
                title: "Complete All Quests",
                description: "Complete all 5 daily quests.",
                target: 5,
                current: 0,
                rewards: AchievementDef.Rewards(
                    gems: 5000, spins: 1, hammers: 1, magnets: 1, swaps: 1, boost2x: 1, boost3x: 1, boost4x: 1
                ),
                claimed: false
            )
        ]
    }

    // MARK: - Progress Recording

    public func recordMerges(_ count: Int) {
        resetIfNewDay()
        guard let idx = quests.firstIndex(where: { $0.id == "daily_merge_tiles" }) else { return }
        quests[idx].current += count
        saveProgress(for: quests[idx])
        updateMetaQuest()
    }

    public func recordPowerUpUse(count: Int = 1) {
        resetIfNewDay()
        guard let idx = quests.firstIndex(where: { $0.id == "daily_use_powerups" }) else { return }
        quests[idx].current += count
        saveProgress(for: quests[idx])
        updateMetaQuest()
    }

    public func recordTileReached(step: Int) {
        resetIfNewDay()
        // Auto-initialize the target if it hasn't been set yet (e.g., player
        // started a game before returning to the Home screen after a day reset).
        if tileQuestTargetStep == 0 && step > 0 {
            setHighestTileStep(step)
        }
        guard tileQuestTargetStep > 0 else { return }
        guard let idx = quests.firstIndex(where: { $0.id == "daily_tile_reach" }) else { return }
        if step >= tileQuestTargetStep {
            quests[idx].current = 1
            saveProgress(for: quests[idx])
            updateMetaQuest()
        }
    }

    public func recordChallengeCreated(count: Int = 1) {
        resetIfNewDay()
        guard let idx = quests.firstIndex(where: { $0.id == "daily_create_challenge" }) else { return }
        quests[idx].current += count
        saveProgress(for: quests[idx])
        updateMetaQuest()
    }

    public func recordChallengeCompleted(count: Int = 1) {
        resetIfNewDay()
        guard let idx = quests.firstIndex(where: { $0.id == "daily_complete_challenge" }) else { return }
        quests[idx].current += count
        saveProgress(for: quests[idx])
        updateMetaQuest()
    }

    /// Updates the meta "Complete All Quests" quest based on how many other quests are complete
    private func updateMetaQuest() {
        guard let idx = quests.firstIndex(where: { $0.id == "daily_complete_all" }) else { return }
        let completedCount = quests.filter { $0.id != "daily_complete_all" && $0.isComplete }.count
        quests[idx].current = completedCount
        saveProgress(for: quests[idx])
    }

    // MARK: - Claiming

    public func claim(questId: String) {
        guard let idx = quests.firstIndex(where: { $0.id == questId }),
              quests[idx].isClaimable else { return }

        quests[idx].claimed = true
        defaults.set(true, forKey: Self.questClaimedPrefix + questId)

        let rewards = quests[idx].rewards

        // Grant gems directly
        if let gems = rewards.gems, gems > 0 {
            let currentGems = defaults.integer(forKey: "coins")
            defaults.set(currentGems + gems, forKey: "coins")
            NotificationCenter.default.post(
                name: Notification.Name("GemsDidChange"),
                object: nil,
                userInfo: ["newBalance": currentGems + gems, "added": gems]
            )
        }

        onReward?(rewards)
    }

    public var claimableCount: Int {
        quests.filter(\.isClaimable).count
    }

    public var allComplete: Bool {
        quests.allSatisfy(\.claimed)
    }

    // MARK: - Daily Reset

    /// Returns the time interval until the next midnight reset
    public func timeUntilReset() -> TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return 86400
        }
        return max(0, tomorrow.timeIntervalSince(now))
    }

    /// Sets the tile quest target based on the player's current highest tile step.
    /// Called externally when the store is wired up (e.g., from RootGameView).
    public func setHighestTileStep(_ step: Int) {
        // Only set if we haven't already locked in a target for today
        if tileQuestTargetStep == 0 {
            tileQuestTargetStep = step + 10
            defaults.set(tileQuestTargetStep, forKey: Self.tileTargetStepKey)
            // Update the quest description with the actual target
            if let idx = quests.firstIndex(where: { $0.id == "daily_tile_reach" }) {
                let label = formatTileStep(tileQuestTargetStep)
                quests[idx] = Quest(
                    id: quests[idx].id,
                    title: "Reach the \(label) Tile",
                    description: "Create a tile worth \(label) or higher.",
                    target: 1,
                    current: quests[idx].current,
                    rewards: quests[idx].rewards,
                    claimed: quests[idx].claimed
                )
            }
        }
    }

    // MARK: - Private Helpers

    private func resetIfNewDay() {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        if let lastReset = defaults.object(forKey: Self.lastResetDateKey) as? Double {
            let lastResetDate = Date(timeIntervalSince1970: lastReset)
            let lastStart = calendar.startOfDay(for: lastResetDate)
            if lastStart == todayStart {
                // Same day, just load saved state if quests are empty
                if quests.isEmpty {
                    loadQuests()
                }
                return
            }
        }

        // New day — reset everything
        quests = Self.makeQuestDefinitions()
        tileQuestTargetStep = 0
        defaults.removeObject(forKey: Self.tileTargetStepKey)
        defaults.set(todayStart.timeIntervalSince1970, forKey: Self.lastResetDateKey)

        // Clear saved progress
        for quest in quests {
            defaults.removeObject(forKey: Self.questProgressPrefix + quest.id)
            defaults.removeObject(forKey: Self.questClaimedPrefix + quest.id)
        }
    }

    private func loadQuests() {
        quests = Self.makeQuestDefinitions()
        tileQuestTargetStep = defaults.integer(forKey: Self.tileTargetStepKey)

        for idx in quests.indices {
            let id = quests[idx].id
            quests[idx].current = defaults.integer(forKey: Self.questProgressPrefix + id)
            quests[idx].claimed = defaults.bool(forKey: Self.questClaimedPrefix + id)
        }

        // Update tile quest description if target was set
        if tileQuestTargetStep > 0,
           let idx = quests.firstIndex(where: { $0.id == "daily_tile_reach" }) {
            let label = formatTileStep(tileQuestTargetStep)
            quests[idx] = Quest(
                id: quests[idx].id,
                title: "Reach the \(label) Tile",
                description: "Create a tile worth \(label) or higher.",
                target: 1,
                current: quests[idx].current,
                rewards: quests[idx].rewards,
                claimed: quests[idx].claimed
            )
        }
    }

    private func saveProgress(for quest: Quest) {
        defaults.set(quest.current, forKey: Self.questProgressPrefix + quest.id)
    }

    /// Format tile step using the game's standard label system (K/M/B/a/b/c...)
    private func formatTileStep(_ step: Int) -> String {
        TileStepLabelFormatter.labelForStep(step, start: 2)
    }
}

import Foundation
import GameCore
import Observation

public enum HomeFeature: String, CaseIterable, Codable, Sendable {
    case play
    case journey
    case daily
    case freeSpin
    case shop
    case music
    case boosts
    case create
    case challenge
    case bestOffer
    case theme
    case profile
    case achievements
    case leaderboard
    case settings
    case adBonus
}

public enum NextBestAction: String, Codable, Sendable, Identifiable, Equatable {
    case tutorial
    case play
    case claimDaily
    case freeSpin
    case nextMilestone
    case unlockCreate
    case unlockChallenge
    case lowInventoryShop
    case settingsPrivacy

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .tutorial: "Learn the merge"
        case .play: "Start your first run"
        case .claimDaily: "Claim your daily reward"
        case .freeSpin: "Use your free spin"
        case .nextMilestone: "Chase the next tile"
        case .unlockCreate: "Reach 1M to unlock Create"
        case .unlockChallenge: "Reach 1B to unlock Challenges"
        case .lowInventoryShop: "Restock your tools"
        case .settingsPrivacy: "Review privacy choices"
        }
    }

    public var subtitle: String {
        switch self {
        case .tutorial:
            "Connect matching tiles, release, and watch the number jump."
        case .play:
            "One run is enough to unlock your daily rhythm."
        case .claimDaily:
            "A quick reward is waiting before your next run."
        case .freeSpin:
            "Spin once for a bonus, then get back to merging."
        case .nextMilestone:
            "Make a bigger tile and keep the journey moving."
        case .unlockCreate:
            "Create opens once your board proves it can handle bigger tiles."
        case .unlockChallenge:
            "Challenges unlock when milestone chasing is second nature."
        case .lowInventoryShop:
            "Grab a deterministic bundle or save your gems for later."
        case .settingsPrivacy:
            "Ad privacy choices are available from Settings."
        }
    }
}

public struct PlayerReadinessSnapshot: Codable, Equatable, Sendable {
    public var hasCompletedTutorial: Bool
    public var sessionsStarted: Int
    public var completedRuns: Int
    public var totalMerges: Int
    public var hasEarnedFirstReward: Bool
    public var visibleFeatures: Set<HomeFeature>
    public var dismissedRecommendations: Set<NextBestAction>
    public var lastRecordedRunID: String?

    public init(
        hasCompletedTutorial: Bool = false,
        sessionsStarted: Int = 0,
        completedRuns: Int = 0,
        totalMerges: Int = 0,
        hasEarnedFirstReward: Bool = false,
        visibleFeatures: Set<HomeFeature> = [.play, .journey, .settings],
        dismissedRecommendations: Set<NextBestAction> = [],
        lastRecordedRunID: String? = nil
    ) {
        self.hasCompletedTutorial = hasCompletedTutorial
        self.sessionsStarted = sessionsStarted
        self.completedRuns = completedRuns
        self.totalMerges = totalMerges
        self.hasEarnedFirstReward = hasEarnedFirstReward
        self.visibleFeatures = visibleFeatures
        self.dismissedRecommendations = dismissedRecommendations
        self.lastRecordedRunID = lastRecordedRunID
    }
}

public enum FirstLaunchTutorialGate: Sendable {
    public static var automaticPresentationAllowedInCurrentBuild: Bool {
        #if DEBUG
        false
        #else
        true
        #endif
    }

    public static func shouldPresent(
        hasCompletedTutorial: Bool,
        automaticPresentationAllowed: Bool
    ) -> Bool {
        automaticPresentationAllowed && !hasCompletedTutorial
    }

    public static func shouldPresentInCurrentBuild(hasCompletedTutorial: Bool) -> Bool {
        shouldPresent(
            hasCompletedTutorial: hasCompletedTutorial,
            automaticPresentationAllowed: automaticPresentationAllowedInCurrentBuild
        )
    }
}

public protocol PlayerReadinessStorage: Sendable {
    func load() -> PlayerReadinessSnapshot
    func save(_ snapshot: PlayerReadinessSnapshot)
}

public struct UserDefaultsPlayerReadinessStorage: PlayerReadinessStorage, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "playerReadiness.snapshot.v1"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> PlayerReadinessSnapshot {
        guard let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(PlayerReadinessSnapshot.self, from: data)
        else {
            return PlayerReadinessSnapshot()
        }
        return snapshot
    }

    public func save(_ snapshot: PlayerReadinessSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
}

@MainActor
@Observable
public final class PlayerReadinessStore {
    private let storage: PlayerReadinessStorage
    public private(set) var snapshot: PlayerReadinessSnapshot

    public init(storage: PlayerReadinessStorage = UserDefaultsPlayerReadinessStorage()) {
        self.storage = storage
        self.snapshot = storage.load()
    }

    public var hasCompletedTutorial: Bool { snapshot.hasCompletedTutorial }
    public var sessionsStarted: Int { snapshot.sessionsStarted }
    public var completedRuns: Int { snapshot.completedRuns }
    public var totalMerges: Int { snapshot.totalMerges }
    public var hasEarnedFirstReward: Bool { snapshot.hasEarnedFirstReward }

    public func isVisible(_ feature: HomeFeature) -> Bool {
        snapshot.visibleFeatures.contains(feature)
    }

    public func recordSessionStarted() {
        snapshot.sessionsStarted += 1
        persist()
    }

    public func markTutorialCompleted() {
        snapshot.hasCompletedTutorial = true
        recomputeVisibleFeatures(highestTile: 2, highestTileStep: 0)
    }

    public func recordMerge(count: Int = 1, highestTile: Int, highestTileStep: Int) {
        snapshot.totalMerges += max(0, count)
        recomputeVisibleFeatures(highestTile: highestTile, highestTileStep: highestTileStep)
    }

    public func recordRewardEarned(highestTile: Int, highestTileStep: Int) {
        snapshot.hasEarnedFirstReward = true
        recomputeVisibleFeatures(highestTile: highestTile, highestTileStep: highestTileStep)
    }

    public func recordRunCompleted(_ summary: GameRunSummary) {
        guard snapshot.lastRecordedRunID != summary.id, summary.moves > 0 else { return }
        snapshot.completedRuns += 1
        snapshot.lastRecordedRunID = summary.id
        recomputeVisibleFeatures(
            highestTile: summary.highestTile,
            highestTileStep: summary.highestTileStep
        )
    }

    public func dismissRecommendation(_ action: NextBestAction) {
        snapshot.dismissedRecommendations.insert(action)
        persist()
    }

    public func nextBestAction(
        highestTile: Int,
        highestTileStep: Int,
        gems: Int,
        canClaimDaily: Bool,
        bonusSpins: Int,
        isPrivacyOptionsRequired: Bool
    ) -> NextBestAction {
        if !snapshot.hasCompletedTutorial {
            return .tutorial
        }
        if snapshot.completedRuns == 0 {
            return .play
        }
        if isPrivacyOptionsRequired && !snapshot.dismissedRecommendations.contains(.settingsPrivacy) {
            return .settingsPrivacy
        }
        if canClaimDaily && isVisible(.daily) {
            return .claimDaily
        }
        if bonusSpins > 0 && isVisible(.freeSpin) {
            return .freeSpin
        }
        if isVisible(.create) && !hasReachedCreateUnlock(highestTile: highestTile, highestTileStep: highestTileStep) {
            return .unlockCreate
        }
        if isVisible(.challenge) && !hasReachedChallengeUnlock(highestTile: highestTile, highestTileStep: highestTileStep) {
            return .unlockChallenge
        }
        if gems < 100 && isVisible(.shop) && !snapshot.dismissedRecommendations.contains(.lowInventoryShop) {
            return .lowInventoryShop
        }
        return .nextMilestone
    }

    public func recomputeVisibleFeatures(highestTile: Int, highestTileStep: Int) {
        var features: Set<HomeFeature> = [.play, .journey, .settings]

        if snapshot.completedRuns > 0 {
            features.insert(.daily)
        }

        if snapshot.hasEarnedFirstReward {
            features.formUnion([.shop, .freeSpin, .music, .theme, .profile, .adBonus])
        }

        if snapshot.totalMerges >= 10 || highestTileStep >= 10 {
            features.formUnion([.achievements, .leaderboard, .boosts])
        }

        if highestTileStep >= 15 || highestTile >= 65_536 {
            features.insert(.create)
        }

        if highestTileStep >= 25 || highestTile >= 67_108_864 {
            features.insert(.challenge)
        }

        if snapshot.sessionsStarted >= 3 && snapshot.hasEarnedFirstReward {
            features.insert(.bestOffer)
        }

        snapshot.visibleFeatures = features
        persist()
    }

    private func persist() {
        storage.save(snapshot)
    }

    private func hasReachedCreateUnlock(highestTile: Int, highestTileStep: Int) -> Bool {
        highestTile >= 1_048_576 || highestTileStep >= 19
    }

    private func hasReachedChallengeUnlock(highestTile: Int, highestTileStep: Int) -> Bool {
        highestTile >= 1_073_741_824 || highestTileStep >= 29
    }
}

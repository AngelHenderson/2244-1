import Testing
import Foundation
@testable import GameApp
@testable import GameCore

@MainActor
@Suite("PlayerReadinessStore")
struct PlayerReadinessStoreTests {
    private final class InMemoryStorage: PlayerReadinessStorage, @unchecked Sendable {
        var snapshot: PlayerReadinessSnapshot
        init(snapshot: PlayerReadinessSnapshot = PlayerReadinessSnapshot()) {
            self.snapshot = snapshot
        }
        func load() -> PlayerReadinessSnapshot { snapshot }
        func save(_ snapshot: PlayerReadinessSnapshot) {
            self.snapshot = snapshot
        }
    }

    @Test("Default snapshot only exposes Play / Journey / Settings")
    func defaultVisibleFeaturesAreMinimal() {
        let store = PlayerReadinessStore(storage: InMemoryStorage())
        #expect(store.isVisible(.play))
        #expect(store.isVisible(.journey))
        #expect(store.isVisible(.settings))
        #expect(!store.isVisible(.daily))
        #expect(!store.isVisible(.shop))
        #expect(!store.isVisible(.bestOffer))
        #expect(!store.isVisible(.create))
        #expect(!store.isVisible(.challenge))
        #expect(!store.isVisible(.achievements))
        #expect(!store.isVisible(.leaderboard))
        #expect(!store.isVisible(.adBonus))
    }

    @Test("Daily appears after first completed run")
    func dailyAfterFirstRun() {
        let store = PlayerReadinessStore(storage: InMemoryStorage())
        store.recordRunCompleted(GameRunSummary(
            score: 100,
            scoreAlpha: AlphaNumber(100),
            highestTile: 4,
            highestTileStep: 1,
            moves: 5,
            duration: 30,
            seed: 1,
            infinityMergeCount: 0
        ))
        #expect(store.isVisible(.daily))
        // Shop only appears after first earned reward, not just first run.
        #expect(!store.isVisible(.shop))
    }

    @Test("Shop / Free Spin / Music / AdBonus appear after first earned reward")
    func shopAndSpinAfterFirstReward() {
        let store = PlayerReadinessStore(storage: InMemoryStorage())
        store.recordRewardEarned(highestTile: 4, highestTileStep: 1)
        #expect(store.isVisible(.shop))
        #expect(store.isVisible(.freeSpin))
        #expect(store.isVisible(.music))
        #expect(store.isVisible(.theme))
        #expect(store.isVisible(.adBonus))
    }

    @Test("Achievements / Daily Quests / Boosts unlock after 10 merges OR step 10")
    func achievementsAfterMergeThreshold() {
        let store = PlayerReadinessStore(storage: InMemoryStorage())
        store.recordMerge(count: 9, highestTile: 16, highestTileStep: 3)
        #expect(!store.isVisible(.achievements))
        #expect(!store.isVisible(.leaderboard))
        store.recordMerge(count: 1, highestTile: 32, highestTileStep: 4)
        #expect(store.isVisible(.achievements))
        #expect(store.isVisible(.leaderboard))
        #expect(store.isVisible(.boosts))
    }

    @Test("Create / Challenge respect step thresholds")
    func createChallengeStepThresholds() {
        let store = PlayerReadinessStore(storage: InMemoryStorage())
        // step 14 -> not yet (need step 15)
        store.recomputeVisibleFeatures(highestTile: 16384, highestTileStep: 14)
        #expect(!store.isVisible(.create))
        // step 15 -> Create visible (locked guidance)
        store.recomputeVisibleFeatures(highestTile: 32768, highestTileStep: 15)
        #expect(store.isVisible(.create))
        // step 25 -> Challenge visible
        store.recomputeVisibleFeatures(highestTile: 33_554_432, highestTileStep: 25)
        #expect(store.isVisible(.challenge))
    }

    @Test("Best Offer never appears before session 3 with first reward")
    func bestOfferGate() {
        let store = PlayerReadinessStore(storage: InMemoryStorage())
        store.recordRewardEarned(highestTile: 4, highestTileStep: 1)
        store.recordSessionStarted()
        store.recordSessionStarted()
        #expect(!store.isVisible(.bestOffer))
        store.recordSessionStarted()
        store.recomputeVisibleFeatures(highestTile: 4, highestTileStep: 1)
        #expect(store.isVisible(.bestOffer))
    }

    @Test("nextBestAction priority: tutorial > play > privacy > daily > spin > milestone")
    func nextBestActionPriority() {
        let store = PlayerReadinessStore(storage: InMemoryStorage())
        // Default: needs tutorial
        #expect(store.nextBestAction(
            highestTile: 2, highestTileStep: 0,
            gems: 500, canClaimDaily: true, bonusSpins: 1, isPrivacyOptionsRequired: true
        ) == .tutorial)

        store.markTutorialCompleted()
        // Then needs play (no completed runs yet)
        #expect(store.nextBestAction(
            highestTile: 2, highestTileStep: 0,
            gems: 500, canClaimDaily: true, bonusSpins: 1, isPrivacyOptionsRequired: false
        ) == .play)

        store.recordRunCompleted(GameRunSummary(
            score: 100, scoreAlpha: AlphaNumber(100),
            highestTile: 4, highestTileStep: 1,
            moves: 5, duration: 30, seed: 1, infinityMergeCount: 0
        ))
        // Privacy ranks above daily.
        #expect(store.nextBestAction(
            highestTile: 4, highestTileStep: 1,
            gems: 500, canClaimDaily: true, bonusSpins: 0, isPrivacyOptionsRequired: true
        ) == .settingsPrivacy)
        // Without privacy, daily wins (we're past first run so daily is visible).
        #expect(store.nextBestAction(
            highestTile: 4, highestTileStep: 1,
            gems: 500, canClaimDaily: true, bonusSpins: 0, isPrivacyOptionsRequired: false
        ) == .claimDaily)

        // Once daily is gone and we have spins, free spin wins (after first reward unlocks it).
        store.recordRewardEarned(highestTile: 4, highestTileStep: 1)
        #expect(store.nextBestAction(
            highestTile: 4, highestTileStep: 1,
            gems: 500, canClaimDaily: false, bonusSpins: 2, isPrivacyOptionsRequired: false
        ) == .freeSpin)

        // Otherwise, milestone is the fallback.
        #expect(store.nextBestAction(
            highestTile: 4, highestTileStep: 1,
            gems: 500, canClaimDaily: false, bonusSpins: 0, isPrivacyOptionsRequired: false
        ) == .nextMilestone)
    }

    @Test("Tutorial completion persists through storage")
    func tutorialPersistsThroughStorage() {
        let storage = InMemoryStorage()
        do {
            let first = PlayerReadinessStore(storage: storage)
            first.markTutorialCompleted()
            #expect(first.hasCompletedTutorial)
        }
        let reloaded = PlayerReadinessStore(storage: storage)
        #expect(reloaded.hasCompletedTutorial)
    }

    @Test("First launch tutorial gate is testable for release-only behavior")
    func firstLaunchTutorialGateCanValidateReleaseBehavior() {
        #expect(FirstLaunchTutorialGate.shouldPresent(
            hasCompletedTutorial: false,
            automaticPresentationAllowed: true
        ))
        #expect(!FirstLaunchTutorialGate.shouldPresent(
            hasCompletedTutorial: true,
            automaticPresentationAllowed: true
        ))
        #expect(!FirstLaunchTutorialGate.shouldPresent(
            hasCompletedTutorial: false,
            automaticPresentationAllowed: false
        ))
    }

    @Test("Recommendation dismissal sticks")
    func dismissRecommendationSticks() {
        let store = PlayerReadinessStore(storage: InMemoryStorage())
        store.markTutorialCompleted()
        store.recordRunCompleted(GameRunSummary(
            score: 100, scoreAlpha: AlphaNumber(100),
            highestTile: 4, highestTileStep: 1,
            moves: 5, duration: 30, seed: 1, infinityMergeCount: 0
        ))
        store.dismissRecommendation(.lowInventoryShop)
        store.recordRewardEarned(highestTile: 4, highestTileStep: 1)
        // Even with low gems we should NOT recommend shop because it was dismissed.
        let action = store.nextBestAction(
            highestTile: 4, highestTileStep: 1,
            gems: 0, canClaimDaily: false, bonusSpins: 0, isPrivacyOptionsRequired: false
        )
        #expect(action != .lowInventoryShop)
    }
}

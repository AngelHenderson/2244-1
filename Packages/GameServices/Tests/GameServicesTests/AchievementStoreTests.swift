import Testing
import Foundation
@testable import GameCore

@MainActor
@Suite("AchievementStore")
struct AchievementStoreTests {
    @Test("Claim invokes the reward handler and still persists gems")
    func claimUsesRewardHandlerWhenPresent() async throws {
        let defaults = makeDefaults(for: "AchievementStoreTests.callback")
        defer { clearDefaults(for: "AchievementStoreTests.callback") }

        let store = AchievementStore(defaults: defaults)
        try store.loadCatalog(from: makeCatalog(gems: 15))

        await store.evaluate(snapshot: GameSnapshot(), reportToGameCenter: false)
        #expect(store.claimableCount == 1)

        var grantedGems = 0
        store.onReward = { rewards in
            grantedGems = rewards.gems ?? 0
        }

        let first = try #require(store.catalog.first)
        store.claim(definition: first)

        #expect(grantedGems == 15)
        #expect(defaults.integer(forKey: "coins") == 15)
    }

    @Test("Claim falls back to direct gem grant when no handler is set")
    func claimFallsBackToDirectGemGrant() async throws {
        let defaults = makeDefaults(for: "AchievementStoreTests.fallback")
        defer { clearDefaults(for: "AchievementStoreTests.fallback") }

        let store = AchievementStore(defaults: defaults)
        try store.loadCatalog(from: makeCatalog(gems: 20))

        await store.evaluate(snapshot: GameSnapshot(), reportToGameCenter: false)
        #expect(store.claimableCount == 1)

        let first = try #require(store.catalog.first)
        store.claim(definition: first)

        #expect(defaults.integer(forKey: "coins") == 20)
    }

    // MARK: - Helpers

    private func makeCatalog(gems: Int) throws -> URL {
        let json: [String: Any] = [
            "id": "test_achievement",
            "gcIdentifier": "test_achievement",
            "title": "Test Achievement",
            "description": "Unlocks instantly for testing.",
            "category": "Testing",
            "rewards": ["gems": gems],
            "hidden": false,
            "conditionExpr": "",
            "conditions": []
        ]

        let data = try JSONSerialization.data(withJSONObject: [json], options: [.prettyPrinted])
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        try data.write(to: url)
        return url
    }

    private func makeDefaults(for suite: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func clearDefaults(for suite: String) {
        if let defaults = UserDefaults(suiteName: suite) {
            defaults.removePersistentDomain(forName: suite)
        }
    }
}

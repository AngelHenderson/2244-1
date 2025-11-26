import XCTest
@testable import GameServices

@MainActor
final class AchievementStoreTests: XCTestCase {
    func testClaimUsesRewardHandlerWhenPresent() async throws {
        let defaults = makeDefaults(for: "AchievementStoreTests.callback")
        defer { clearDefaults(for: "AchievementStoreTests.callback") }
        
        let store = AchievementStore(defaults: defaults)
        try store.loadCatalog(from: makeCatalog(gems: 15))
        
        await store.evaluate(snapshot: GameSnapshot(), reportToGameCenter: false)
        XCTAssertEqual(store.claimableCount, 1)
        
        var grantedGems = 0
        store.onReward = { rewards in
            grantedGems = rewards.gems ?? 0
        }
        
        store.claim(definition: try XCTUnwrap(store.catalog.first))
        
        XCTAssertEqual(grantedGems, 15, "Reward handler should receive gem amount")
        XCTAssertEqual(defaults.integer(forKey: "coins"), 0, "Direct fallback should not run when handler is set")
    }
    
    func testClaimFallsBackToDirectGemGrant() async throws {
        let defaults = makeDefaults(for: "AchievementStoreTests.fallback")
        defer { clearDefaults(for: "AchievementStoreTests.fallback") }
        
        let store = AchievementStore(defaults: defaults)
        try store.loadCatalog(from: makeCatalog(gems: 20))
        
        await store.evaluate(snapshot: GameSnapshot(), reportToGameCenter: false)
        XCTAssertEqual(store.claimableCount, 1)
        
        store.claim(definition: try XCTUnwrap(store.catalog.first))
        
        XCTAssertEqual(defaults.integer(forKey: "coins"), 20, "Fallback path should deposit gems into storage")
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
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
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

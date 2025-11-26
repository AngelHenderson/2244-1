import XCTest
@testable import GameServices

@MainActor
final class DailyClaimsStoreTests: XCTestCase {
    func testWeeklyRewardsRepeatEverySevenDays() async throws {
        let suite = "DailyClaimsStoreTests.repeat"
        let store = makeStore(suite: suite)
        defer { clearStore(for: suite) }
        
        await store.loadCatalogs()
        store.updateAvailability()
        
        let day1 = store.dailyClaims.first(where: { $0.day == 1 })?.rewards
        let day8 = store.dailyClaims.first(where: { $0.day == 8 })?.rewards
        
        XCTAssertNotNil(day1)
        XCTAssertEqual(day1, day8, "Rewards should repeat every seven days")
    }
    
    func testClaimingAdvancesStreakAndLocksUntilTomorrow() async throws {
        let suite = "DailyClaimsStoreTests.claim"
        let store = makeStore(suite: suite)
        defer { clearStore(for: suite) }
        
        await store.loadCatalogs()
        store.updateAvailability()
        
        XCTAssertTrue(store.canClaimToday, "First session should allow claiming")
        XCTAssertEqual(store.getNextClaimableDay(), 1)
        
        store.claimDailyReward()
        
        XCTAssertEqual(store.currentClaimDay, 1)
        XCTAssertFalse(store.canClaimToday, "Claiming should lock rewards until the next day")
        
        // Extend the catalog and verify it now includes the next week's entries.
        let initialCount = store.dailyClaims.count
        store.ensureClaimsCovering(pageIndex: 5)
        XCTAssertGreaterThan(store.dailyClaims.count, initialCount)
    }
    
    func testMissingDayDoesNotResetRewardProgress() async throws {
        let suite = "DailyClaimsStoreTests.break"
        let store = makeStore(suite: suite)
        defer { clearStore(for: suite) }
        
        await store.loadCatalogs()
        store.updateAvailability()
        
        store.claimDailyReward()
        XCTAssertEqual(store.currentClaimDay, 1)
        
        // Simulate skipping more than a day by moving the last claim timestamp back.
        let defaults = userDefaults(for: suite)
        let twoDaysAgo = Date().addingTimeInterval(-172_800)
        defaults.set(twoDaysAgo.timeIntervalSince1970, forKey: "lastClaimDate")
        
        let storeAfterBreak = makeStore(suite: suite, clearing: false)
        await storeAfterBreak.loadCatalogs()
        storeAfterBreak.updateAvailability()
        
        XCTAssertTrue(storeAfterBreak.canClaimToday)
        XCTAssertEqual(storeAfterBreak.currentClaimDay, 1)
        XCTAssertEqual(storeAfterBreak.getNextClaimableDay(), 2)
    }
    
    // MARK: - Helpers
    
    private func makeStore(suite: String, clearing: Bool = true) -> DailyClaimsStore {
        let defaults = userDefaults(for: suite)
        if clearing {
            defaults.removePersistentDomain(forName: suite)
        }
        return DailyClaimsStore(storage: defaults)
    }
    
    private func clearStore(for suite: String) {
        if let defaults = UserDefaults(suiteName: suite) {
            defaults.removePersistentDomain(forName: suite)
        }
    }
    
    private func userDefaults(for suite: String) -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("Unable to create defaults for suite \(suite)")
        }
        return defaults
    }
}

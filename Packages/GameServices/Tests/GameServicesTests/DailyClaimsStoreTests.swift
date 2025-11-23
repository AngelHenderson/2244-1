import XCTest
@testable import GameServices

@MainActor
final class DailyClaimsStoreTests: XCTestCase {
    func testWeeklyRewardsRepeatEverySevenDays() async throws {
        let store = makeStore(suite: "DailyClaimsStoreTests.repeat")
        defer { clearStore(for: "DailyClaimsStoreTests.repeat") }
        
        await store.loadCatalogs()
        store.updateAvailability()
        
        let day1 = store.dailyClaims.first(where: { $0.day == 1 })?.rewards
        let day8 = store.dailyClaims.first(where: { $0.day == 8 })?.rewards
        
        XCTAssertNotNil(day1)
        XCTAssertEqual(day1, day8, "Rewards should repeat every seven days")
    }
    
    func testClaimingAdvancesStreakAndLocksUntilTomorrow() async throws {
        let store = makeStore(suite: "DailyClaimsStoreTests.claim")
        defer { clearStore(for: "DailyClaimsStoreTests.claim") }
        
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
    
    // MARK: - Helpers
    
    private func makeStore(suite: String) -> DailyClaimsStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return DailyClaimsStore(storage: defaults)
    }
    
    private func clearStore(for suite: String) {
        if let defaults = UserDefaults(suiteName: suite) {
            defaults.removePersistentDomain(forName: suite)
        }
    }
}

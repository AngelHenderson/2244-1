import XCTest
@testable import GameCore

@MainActor
final class DailyClaimsStoreTests: XCTestCase {
    func testYearlyRewardsRepeatAndScaleAfterDay365() async throws {
        let suite = "DailyClaimsStoreTests.repeat"
        let store = makeStore(suite: suite)
        defer { clearStore(for: suite) }
        
        await store.loadCatalogs()
        store.ensureClaimsCovering(pageIndex: 53)
        store.updateAvailability()
        
        guard
            let day1 = store.dailyClaims.first(where: { $0.day == 1 })?.rewards,
            let day366 = store.dailyClaims.first(where: { $0.day == 366 })?.rewards
        else {
            XCTFail("Rewards unavailable for comparison")
            return
        }
        
        XCTAssertEqual(rewardKinds(day1), rewardKinds(day366), "Reward composition should repeat yearly")
        
        for entry in day1.entries {
            let nextAmount = amount(of: entry.kind, in: day366) ?? 0
            XCTAssertGreaterThanOrEqual(nextAmount, entry.amount, "Amounts should grow over time for \(entry.kind)")
        }
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
    
    func testRewardsIncreaseOverTime() async throws {
        let suite = "DailyClaimsStoreTests.increase"
        let store = makeStore(suite: suite)
        defer { clearStore(for: suite) }
        
        await store.loadCatalogs()
        store.ensureClaimsCovering(pageIndex: 53)
        
        guard
            let day1 = store.dailyClaims.first(where: { $0.day == 1 }),
            let day366 = store.dailyClaims.first(where: { $0.day == 366 })
        else {
            XCTFail("Failed to load comparison claims")
            return
        }
        
        XCTAssertGreaterThan(day366.rewards.gems ?? 0, day1.rewards.gems ?? 0)
        if let startHammers = day1.rewards.hammers, let endHammers = day366.rewards.hammers {
            XCTAssertGreaterThanOrEqual(endHammers, startHammers)
        }
        if let startSpins = day1.rewards.spins, let endSpins = day366.rewards.spins {
            XCTAssertGreaterThanOrEqual(endSpins, startSpins)
        }
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
    
    private func rewardKinds(_ rewards: AchievementDef.Rewards) -> Set<AchievementDef.Rewards.Entry.Kind> {
        Set(rewards.entries.map(\.kind))
    }
    
    private func amount(of kind: AchievementDef.Rewards.Entry.Kind, in rewards: AchievementDef.Rewards) -> Int? {
        rewards.entries.first(where: { $0.kind == kind })?.amount
    }
}

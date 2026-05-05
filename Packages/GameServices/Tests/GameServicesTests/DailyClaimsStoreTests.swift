import Testing
import Foundation
@testable import GameCore

@MainActor
@Suite("DailyClaimsStore")
struct DailyClaimsStoreTests {
    @Test("Yearly rewards repeat composition and scale up after day 365")
    func yearlyRewardsRepeatAndScale() async {
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
            Issue.record("Rewards unavailable for comparison")
            return
        }

        #expect(rewardKinds(day1) == rewardKinds(day366),
                "Reward composition should repeat yearly")

        for entry in day1.entries {
            let nextAmount = amount(of: entry.kind, in: day366) ?? 0
            #expect(nextAmount >= entry.amount,
                    "Amounts should grow over time for \(entry.kind)")
        }
    }

    @Test("Claiming advances streak and locks until tomorrow")
    func claimingLocksUntilTomorrow() async {
        let suite = "DailyClaimsStoreTests.claim"
        let store = makeStore(suite: suite)
        defer { clearStore(for: suite) }

        await store.loadCatalogs()
        store.updateAvailability()

        #expect(store.canClaimToday)
        #expect(store.getNextClaimableDay() == 1)

        store.claimDailyReward()

        #expect(store.currentClaimDay == 1)
        #expect(!store.canClaimToday)

        let initialCount = store.dailyClaims.count
        store.ensureClaimsCovering(pageIndex: 5)
        #expect(store.dailyClaims.count > initialCount)
    }

    @Test("Missing a day does not roll back claim progress")
    func missingDayDoesNotResetProgress() async {
        let suite = "DailyClaimsStoreTests.break"
        let store = makeStore(suite: suite)
        defer { clearStore(for: suite) }

        await store.loadCatalogs()
        store.updateAvailability()

        store.claimDailyReward()
        #expect(store.currentClaimDay == 1)

        let defaults = userDefaults(for: suite)
        let twoDaysAgo = Date().addingTimeInterval(-172_800)
        defaults.set(twoDaysAgo.timeIntervalSince1970, forKey: "lastClaimDate")

        let storeAfterBreak = makeStore(suite: suite, clearing: false)
        await storeAfterBreak.loadCatalogs()
        storeAfterBreak.updateAvailability()

        #expect(storeAfterBreak.canClaimToday)
        #expect(storeAfterBreak.currentClaimDay == 1)
        #expect(storeAfterBreak.getNextClaimableDay() == 2)
    }

    @Test("Reward amounts grow year over year")
    func rewardsIncreaseOverTime() async {
        let suite = "DailyClaimsStoreTests.increase"
        let store = makeStore(suite: suite)
        defer { clearStore(for: suite) }

        await store.loadCatalogs()
        store.ensureClaimsCovering(pageIndex: 53)

        guard
            let day1 = store.dailyClaims.first(where: { $0.day == 1 }),
            let day366 = store.dailyClaims.first(where: { $0.day == 366 })
        else {
            Issue.record("Failed to load comparison claims")
            return
        }

        #expect((day366.rewards.gems ?? 0) > (day1.rewards.gems ?? 0))
        if let startHammers = day1.rewards.hammers, let endHammers = day366.rewards.hammers {
            #expect(endHammers >= startHammers)
        }
        if let startSpins = day1.rewards.spins, let endSpins = day366.rewards.spins {
            #expect(endSpins >= startSpins)
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

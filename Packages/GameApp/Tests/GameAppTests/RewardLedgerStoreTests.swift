import Testing
import Foundation
@testable import GameApp
@testable import GameCore

@MainActor
@Suite("RewardLedgerStore")
struct RewardLedgerStoreTests {
    private final class InMemoryStorage: RewardLedgerStorage, @unchecked Sendable {
        var entries: [RewardLedgerEntry]
        init(entries: [RewardLedgerEntry] = []) {
            self.entries = entries
        }
        func load() -> [RewardLedgerEntry] { entries }
        func save(_ entries: [RewardLedgerEntry]) { self.entries = entries }
    }

    @Test("First grant for an idempotency key applies and persists")
    func firstGrantAppliesAndPersists() {
        let storage = InMemoryStorage()
        let store = RewardLedgerStore(storage: storage)
        var applied = 0
        let granted = store.grant(
            source: .achievement,
            itemType: .gems,
            amount: 10,
            idempotencyKey: "achievement:firstWin:gems:10"
        ) {
            applied += 1
        }
        #expect(granted)
        #expect(applied == 1)
        #expect(storage.entries.count == 1)
        #expect(storage.entries.first?.idempotencyKey == "achievement:firstWin:gems:10")
    }

    @Test("Duplicate idempotency key is rejected and apply does not run")
    func duplicateKeyIsIgnored() {
        let store = RewardLedgerStore(storage: InMemoryStorage())
        var applied = 0
        store.grant(
            source: .dailyClaim,
            itemType: .gems,
            amount: 25,
            idempotencyKey: "claim:day-7:gems:25"
        ) {
            applied += 1
        }
        let granted = store.grant(
            source: .dailyClaim,
            itemType: .gems,
            amount: 25,
            idempotencyKey: "claim:day-7:gems:25"
        ) {
            applied += 1
        }
        #expect(!granted)
        #expect(applied == 1)
    }

    @Test("Empty key is rejected")
    func emptyKeyIsRejected() {
        let store = RewardLedgerStore(storage: InMemoryStorage())
        var applied = 0
        let granted = store.grant(
            source: .ad,
            itemType: .gems,
            amount: 5,
            idempotencyKey: ""
        ) {
            applied += 1
        }
        #expect(!granted)
        #expect(applied == 0)
    }

    @Test("Zero or negative amount is rejected")
    func nonPositiveAmountIsRejected() {
        let store = RewardLedgerStore(storage: InMemoryStorage())
        var applied = 0
        let granted = store.grant(
            source: .gift,
            itemType: .hammer,
            amount: 0,
            idempotencyKey: "gift:test:0"
        ) {
            applied += 1
        }
        #expect(!granted)
        #expect(applied == 0)
    }

    @Test("Loading an existing ledger seeds the dedup set")
    func reloadingPreservesIdempotency() {
        let entry = RewardLedgerEntry(
            source: .purchase,
            itemType: .adFree,
            amount: 1,
            idempotencyKey: "tx-abc:adFree:1"
        )
        let storage = InMemoryStorage(entries: [entry])
        let store = RewardLedgerStore(storage: storage)
        #expect(store.contains(idempotencyKey: "tx-abc:adFree:1"))
        var applied = 0
        let granted = store.grant(
            source: .purchase,
            itemType: .adFree,
            amount: 1,
            idempotencyKey: "tx-abc:adFree:1"
        ) {
            applied += 1
        }
        #expect(!granted)
        #expect(applied == 0)
    }

    @Test("grantRewards routes each non-zero field through the ledger exactly once")
    func grantRewardsRoutesEachNonZeroField() {
        let store = RewardLedgerStore(storage: InMemoryStorage())
        let bundle = AchievementDef.Rewards(
            gems: 50,
            spins: 1,
            hammers: 2,
            magnets: 0,
            swaps: 1,
            boost2x: 1,
            boost3x: nil,
            boost4x: 0
        )
        var seen: [RewardLedgerEntry.ItemType: Int] = [:]
        store.grantRewards(bundle, source: .dailyClaim, contextKey: "claim:day-3") { type, amount in
            seen[type, default: 0] += amount
        }
        #expect(seen[.gems] == 50)
        #expect(seen[.hammer] == 2)
        #expect(seen[.swap] == 1)
        #expect(seen[.spin] == 1)
        #expect(seen[.multiplier2x] == 1)
        #expect(seen[.magnet] == nil)
        #expect(seen[.multiplier3x] == nil)
        #expect(seen[.multiplier4x] == nil)

        // Replaying the same context is a no-op.
        var replay: [RewardLedgerEntry.ItemType: Int] = [:]
        store.grantRewards(bundle, source: .dailyClaim, contextKey: "claim:day-3") { type, amount in
            replay[type, default: 0] += amount
        }
        #expect(replay.isEmpty)
    }
}

import Testing
import Foundation
@testable import GameApp
@testable import GameCore

@MainActor
@Suite("ShopStore IAP grants route through RewardLedger")
struct ShopStoreLedgerTests {
    private final class InMemoryStorage: RewardLedgerStorage, @unchecked Sendable {
        var entries: [RewardLedgerEntry] = []
        func load() -> [RewardLedgerEntry] { entries }
        func save(_ entries: [RewardLedgerEntry]) { self.entries = entries }
    }

    @Test("Coin pouch purchase records exactly one ledger entry per item")
    func coinPouchEmitsLedgerEntries() {
        let storage = InMemoryStorage()
        let ledger = RewardLedgerStore(storage: storage)
        let store = makeShopStore(ledger: ledger)

        // Coin Pouch is a single-line consumable: 500 coins.
        let purchase = VerifiedPurchase(
            productID: "com.game2244.coins.small",
            transactionID: "tx-coinpouch-1",
            isRestored: false
        )
        store._applyVerifiedPurchaseForTesting(purchase)

        #expect(storage.entries.count == 1)
        #expect(storage.entries.first?.itemType == .gems)
        #expect(storage.entries.first?.amount == 500)
        #expect(storage.entries.first?.idempotencyKey.hasPrefix("tx-coinpouch-1:") == true)
    }

    @Test("Replaying the same transaction grants nothing twice")
    func duplicateTransactionIsIdempotent() {
        let storage = InMemoryStorage()
        let ledger = RewardLedgerStore(storage: storage)
        let store = makeShopStore(ledger: ledger)

        let purchase = VerifiedPurchase(
            productID: "com.game2244.coins.small",
            transactionID: "tx-replay-1",
            isRestored: false
        )
        store._applyVerifiedPurchaseForTesting(purchase)
        store._applyVerifiedPurchaseForTesting(purchase) // simulate replay
        #expect(storage.entries.count == 1)
    }

    @Test("Power-Up Pack records one ledger entry per item line, with stable per-line keys")
    func powerUpPackRecordsAllItems() {
        let storage = InMemoryStorage()
        let ledger = RewardLedgerStore(storage: storage)
        let store = makeShopStore(ledger: ledger)

        let purchase = VerifiedPurchase(
            productID: "com.game2244.powerup.bundle",
            transactionID: "tx-powerup-9",
            isRestored: false
        )
        store._applyVerifiedPurchaseForTesting(purchase)

        // The catalog says Power-Up Pack contains 6 line items: hammer, swap,
        // undo, shuffle, magnet, double. Confirm one ledger entry per line and
        // that all keys are unique and prefixed with the transaction id.
        let pack = IAPProduct.product(for: "com.game2244.powerup.bundle")
        let powerUpLineCount = pack?.items.count ?? 0
        #expect(storage.entries.count == powerUpLineCount)
        let keys = Set(storage.entries.map(\.idempotencyKey))
        #expect(keys.count == powerUpLineCount)
        #expect(storage.entries.allSatisfy { $0.idempotencyKey.hasPrefix("tx-powerup-9:") })
    }

    private func makeShopStore(ledger: RewardLedgerStore) -> ShopStore {
        ShopStore(
            journeyStore: JourneyKit.Store(),
            purchaseService: nil,
            gemWallet: nil,
            gameStore: nil,
            rewardLedger: ledger
        )
    }
}

import Foundation
import Testing
@testable import GameApp
@testable import GameCore
@testable import GameServices

struct GameStoreTests {
    @Test
    @MainActor
    func testInitialState() {
        resetUserDefaultsDomain()
        let store = GameStore()
        #expect(store.state.score == 0)
        #expect(store.state.moves == 0)
        #expect(!store.state.isGameOver)
    }
    
    @Test
    @MainActor
    func testSaveLoadRoundTrip() async {
        resetUserDefaultsDomain()
        let store = GameStore()
        // Make one move for a non-empty score sometimes
        if let start = Position(row: 0, col: 0).isValid(for: store.state.board) ? Position(row: 0, col: 0) : nil {
            store.beginPath(at: start)
            if let neighbor = store.state.board.neighbors(of: start).first(where: { pos in
                if let a = store.state.board[start]?.value, let b = store.state.board[pos]?.value { return a == b }
                return false
            }) {
                store.extendPath(to: neighbor)
                store.commitPath()
            } else {
                store.cancelPath()
            }
        }
        
        let suite = "com.angelhenderson.game2248.storage.test.GameApp.\(UUID().uuidString)"
        let storage = UserDefaultsStorageService(suiteName: suite)
        await store.save(to: "slotA", using: storage, theme: "classic")
        let savedBest = await storage.bestScore()
        #expect(savedBest >= store.state.score)
        
        // New store instance should be able to load
        let store2 = GameStore()
        let loaded = await store2.load(from: "slotA", using: storage)
        #expect(loaded)
        #expect(store2.state.board.width == store.state.board.width)
        #expect(store2.state.board.height == store.state.board.height)
        #expect(store2.state.score == store.state.score)
        
        // Cleanup
        await store2.deleteSlot("slotA", using: storage)
        let after = await storage.load(slotId: "slotA")
        #expect(after == nil)
    }
    
    @Test
    @MainActor
    func testUnlockRewardUsesMilestoneFormula() {
        resetUserDefaultsDomain()
        let cases: [(tile: Int, expectedBase: Int)] = [
            (512, 50),
            (1024, 52),
            (2048, 54),
            (8_388_608, 78),
        ]
        
        for scenario in cases {
            let store = GameStore()
            store.coins = 0
            let previousHigh = scenario.tile / 2
            store._setHighestTileForTesting(previousHigh)
            
            store._testTriggerUnlockReward(newHigh: scenario.tile, previousHigh: previousHigh)
            
            #expect(
                store.pendingUnlockRewardBase == scenario.expectedBase,
                "Tile \(scenario.tile) should pay \(scenario.expectedBase) gems"
            )
            store.claimPendingUnlockReward(multiplier: 3)
            #expect(store.coins == scenario.expectedBase * 3)
            #expect(store.pendingUnlockRewardBase == nil)
        }
    }
    
    @Test
    @MainActor
    func testGemRewardPersistsAfterNextMerge() {
        resetUserDefaultsDomain()
        let store = GameStore()
        let initialGems = store.coins
        let reward = 280
        store.addCoins(reward)
        
        guard let (start, neighbor) = firstMergeablePair(in: store.state.board) else {
            #expect(Bool(false), "Test board did not contain a mergeable adjacent pair")
            return
        }
        
        store.beginPath(at: start)
        store.extendPath(to: neighbor)
        store.commitPath()
        
        #expect(
            store.coins >= initialGems + reward,
            "Gem reward should persist after the next merge"
        )
    }
    
    @Test
    @MainActor
    func testScoreBoostPurchaseConsumesGemsAndExpires() {
        resetUserDefaultsDomain()
        let store = GameStore()
        store.coins = 2_000
        let now = Date()
        #expect(store.purchaseScoreBoost(now: now))
        #expect(store.isScoreBoostActive)
        #expect(store.coins == 1_000)
        #expect(store.scoreBoostExpiresAt != nil)
        
        store._refreshScoreBoost(now: now.addingTimeInterval((15 * 60) + 1))
        #expect(!store.isScoreBoostActive, "Boost should expire after 15 minutes of real time")
    }
    
    @Test
    @MainActor
    func testScoreBoostRepurchaseExtendsDuration() {
        resetUserDefaultsDomain()
        let store = GameStore()
        store.coins = 4_000
        let firstStart = Date()
        #expect(store.purchaseScoreBoost(now: firstStart))
        guard let firstExpiration = store.scoreBoostExpiresAt else {
            Issue.record("Missing first expiration")
            return
        }
        
        let secondStart = firstStart.addingTimeInterval(60)
        #expect(store.purchaseScoreBoost(now: secondStart))
        guard let secondExpiration = store.scoreBoostExpiresAt else {
            Issue.record("Missing second expiration")
            return
        }
        
        #expect(secondExpiration > firstExpiration, "Repurchase should extend the timer")
        let expected = secondStart.addingTimeInterval(15 * 60)
        #expect(abs(secondExpiration.timeIntervalSince(expected)) < 0.5, "Expiration should reset to 15 minutes from latest purchase")
        #expect(store.coins == 2_000, "Two purchases should consume 2,000 gems total")
    }
}

private func firstMergeablePair(in board: Board) -> (Position, Position)? {
    for row in 0..<board.height {
        for col in 0..<board.width {
            let origin = Position(row: row, col: col)
            guard let originTile = board[origin] else { continue }
            for neighbor in board.neighbors(of: origin) {
                guard let neighborTile = board[neighbor] else { continue }
                if neighborTile.value == originTile.value {
                    return (origin, neighbor)
                }
            }
        }
    }
    return nil
}

private func resetUserDefaultsDomain() {
    let defaults = UserDefaults.standard
    if let bundleID = Bundle.main.bundleIdentifier {
        defaults.removePersistentDomain(forName: bundleID)
    } else {
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
    }
    defaults.synchronize()
}
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
    func testUnlockRewardUsesShiftedFormula() {
        resetUserDefaultsDomain()
        let store = GameStore()
        store.coins = 0
        let previousHigh = 65_536
        let newHigh = 131_072
        store._setHighestTileForTesting(previousHigh)
        
        store._testTriggerUnlockReward(newHigh: newHigh, previousHigh: previousHigh)
        
        #expect(store.pendingUnlockRewardBase == newHigh >> 7)
        #expect(store.pendingUnlockTile == newHigh)
        #expect(store.coins == 0)
        
        store.claimPendingUnlockReward(multiplier: 4)
        #expect(store.coins == (newHigh >> 7) * 4)
        #expect(store.pendingUnlockRewardBase == nil)
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
import Foundation
import Testing
@testable import GameApp
@testable import GameCore
@testable import GameServices

struct GameStoreTests {
    @Test
    @MainActor
    func testInitialState() {
        let store = GameStore()
        #expect(store.state.score == 0)
        #expect(store.state.moves == 0)
        #expect(!store.state.isGameOver)
    }
    
    @Test
    @MainActor
    func testSaveLoadRoundTrip() async {
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
        let store = GameStore()
        store._clearBoardForTesting()
        
        let first = Position(row: 2, col: 0)
        let second = Position(row: 2, col: 1)
        store._setTileForTesting(at: first, value: 65_536)
        store._setTileForTesting(at: second, value: 65_536)
        store._setHighestTileForTesting(65_536)
        store.coins = 0
        
        store.beginPath(at: first)
        store.extendPath(to: second)
        store.commitPath()
        
        #expect(store.pendingUnlockRewardBase == 131_072 >> 7)
        #expect(store.pendingUnlockTile == 131_072)
        #expect(store.coins == 0)
        
        store.claimPendingUnlockReward(multiplier: 4)
        #expect(store.coins == (131_072 >> 7) * 4)
        #expect(store.pendingUnlockRewardBase == nil)
    }
}
import Foundation
import Testing
@testable import GameCore

struct StorageServiceTests {
    private func makeIsolatedSuiteName() -> String {
        "com.angelhenderson.game2248.storage.test." + UUID().uuidString
    }
    
    @Test
    func testRoundTripSaveLoadAndDelete() async throws {
        let suite = makeIsolatedSuiteName()
        let service = UserDefaultsStorageService(suiteName: suite)
        let slotId = "slot1"
        let now = Date()
        let payload = SaveData(
            board: [2,4,8,16],
            width: 2,
            height: 2,
            score: 120,
            best: 150,
            seed: 123456789,
            theme: "classic",
            timestamp: now
        )
        
        await service.save(slotId: slotId, data: payload)
        
        // Slots list should include meta
        let slots = await service.loadSlots()
        #expect(slots.contains { $0.id == slotId })
        
        // Load round-trip
        let loaded = await service.load(slotId: slotId)
        #expect(loaded == payload)
        
        // Best score updated based on saved data
        let best = await service.bestScore()
        #expect(best == max(payload.best, payload.score))
        
        // Delete and verify removal
        await service.delete(slotId: slotId)
        let afterDelete = await service.load(slotId: slotId)
        #expect(afterDelete == nil)
        let slotsAfterDelete = await service.loadSlots()
        #expect(!slotsAfterDelete.contains { $0.id == slotId })
    }
    
    @Test
    func testBestScoreSetAndGet() async {
        let suite = makeIsolatedSuiteName()
        let service = UserDefaultsStorageService(suiteName: suite)
        #expect(await service.bestScore() == 0)
        await service.setBestScore(999)
        #expect(await service.bestScore() == 999)
    }
}


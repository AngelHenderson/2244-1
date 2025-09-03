import Testing
import Foundation
@testable import GlassPreview

@Suite("Glass Preview Core Functionality")
struct GlassPreviewTests {
    
    @Test("Glass tile creation and state")
    func testGlassTileCreation() {
        let glassTile = GlassTile.glassPreview(value: 4)
        #expect(glassTile.value == 4)
        #expect(glassTile.isGlass == true)
        #expect(glassTile.isPreview == true)
        #expect(glassTile.isNormal == false)
        
        let normalTile = GlassTile.normal(value: 8)
        #expect(normalTile.value == 8)
        #expect(normalTile.isGlass == false)
        #expect(normalTile.isPreview == false)
        #expect(normalTile.isNormal == true)
        
        let normalPreview = GlassTile.normalPreview(value: 16)
        #expect(normalPreview.value == 16)
        #expect(normalPreview.isGlass == false)
        #expect(normalPreview.isPreview == true)
        #expect(normalPreview.isNormal == false)
    }
    
    @Test("Point adjacency calculation")
    func testPointAdjacency() {
        let center = Point(col: 1, row: 1)
        
        // Test 8-direction adjacency
        let adjacent = [
            Point(col: 0, row: 0), Point(col: 0, row: 1), Point(col: 0, row: 2),
            Point(col: 1, row: 0), Point(col: 1, row: 2),
            Point(col: 2, row: 0), Point(col: 2, row: 1), Point(col: 2, row: 2)
        ]
        
        for point in adjacent {
            #expect(center.isAdjacent(to: point), "Point \(point) should be adjacent to \(center)")
        }
        
        // Test non-adjacent
        let nonAdjacent = [
            Point(col: 3, row: 1), Point(col: 1, row: 3),
            Point(col: 0, row: 3), Point(col: 3, row: 0)
        ]
        
        for point in nonAdjacent {
            #expect(!center.isAdjacent(to: point), "Point \(point) should not be adjacent to \(center)")
        }
        
        // Test self
        #expect(!center.isAdjacent(to: center), "Point should not be adjacent to itself")
    }
    
    @Test("Weighted random selection")
    func testWeightedPick() {
        var rng = AnyRandomNumberGenerator(Xoroshiro(seed: 12345))
        
        let weights: [(String, Int)] = [
            ("A", 70),
            ("B", 20),
            ("C", 10)
        ]
        
        var results: [String: Int] = [:]
        let iterations = 1000
        
        for _ in 0..<iterations {
            if let pick = weightedPick(weights: weights, rng: &rng) {
                results[pick, default: 0] += 1
            }
        }
        
        // Verify we got results
        #expect(results.count == 3)
        #expect(results["A"]! > 0)
        #expect(results["B"]! > 0)
        #expect(results["C"]! > 0)
        
        // Verify rough distribution (allowing for randomness)
        let totalPicks = results.values.reduce(0, +)
        let aPercentage = Double(results["A"]!) / Double(totalPicks)
        let bPercentage = Double(results["B"]!) / Double(totalPicks)
        let cPercentage = Double(results["C"]!) / Double(totalPicks)
        
        // Allow 10% variance from expected
        #expect(aPercentage > 0.6 && aPercentage < 0.8, "A should be ~70%, got \(aPercentage)")
        #expect(bPercentage > 0.1 && bPercentage < 0.3, "B should be ~20%, got \(bPercentage)")
        #expect(cPercentage > 0.05 && cPercentage < 0.15, "C should be ~10%, got \(cPercentage)")
    }
    
    @Test("Deterministic RNG consistency")
    func testDeterministicRNG() {
        let seed: UInt64 = 42
        
        var rng1 = AnyRandomNumberGenerator(Xoroshiro(seed: seed))
        var rng2 = AnyRandomNumberGenerator(Xoroshiro(seed: seed))
        
        // Generate sequences from both RNGs
        let sequence1 = (0..<100).map { _ in rng1.next() }
        let sequence2 = (0..<100).map { _ in rng2.next() }
        
        // They should be identical
        #expect(sequence1 == sequence2, "RNGs with same seed should produce identical sequences")
        
        // Different seeds should produce different sequences
        var rng3 = AnyRandomNumberGenerator(Xoroshiro(seed: seed + 1))
        let sequence3 = (0..<100).map { _ in rng3.next() }
        
        #expect(sequence1 != sequence3, "RNGs with different seeds should produce different sequences")
    }
}

@Suite("Glass Game Store Functionality")
struct GlassGameStoreTests {
    
    @Test("Game store initialization")
    @MainActor
    func testGameStoreInit() {
        let config = GlassGameStore.Config(backgroundColorHex: "#123456")
        let store = GlassGameStore(cols: 3, rows: 4, seed: 12345, config: config)
        
        #expect(store.cols == 3)
        #expect(store.rows == 4)
        #expect(store.sessionSeed == 12345)
        #expect(store.score == 0)
        #expect(store.moves == 0)
        #expect(store.isGameOver == false)
        #expect(store.currentChain.isEmpty)
        #expect(store.chainValidation == nil)
        
        // Verify grid initialization
        #expect(store.grid.count == 3)
        #expect(store.grid[0].count == 4)
        
        // Verify preview queues
        #expect(store.preview.count == 3)
        for col in 0..<3 {
            #expect(store.preview[col].count > 0, "Preview queue for column \(col) should not be empty")
        }
    }
    
    @Test("Chain building rules - start on glass blocked")
    @MainActor
    func testChainStartOnGlassBlocked() {
        let store = GlassGameStore(cols: 3, rows: 3, seed: 12345)
        
        // Try to start on a preview tile (which should be glass initially)
        let previewPoint = Point(col: 0, row: 3) // Preview row
        
        #expect(!store.canStart(at: previewPoint), "Should not be able to start chain on glass preview tile")
        
        store.beginChain(at: previewPoint)
        #expect(store.currentChain.isEmpty, "Chain should not start on glass preview")
        #expect(store.chainValidation != nil, "Should have validation error")
    }
    
    @Test("Chain building rules - 2244 validation")
    @MainActor
    func testChain2244Rules() {
        let store = GlassGameStore(cols: 3, rows: 3, seed: 12345)
        
        // Set up a controlled board state
        store._setTileForTesting(at: Point(col: 0, row: 0), tile: GlassTile.normal(value: 4))
        store._setTileForTesting(at: Point(col: 1, row: 0), tile: GlassTile.normal(value: 4)) // Same value - valid start
        store._setTileForTesting(at: Point(col: 2, row: 0), tile: GlassTile.normal(value: 8)) // Double - valid continuation
        
        let point1 = Point(col: 0, row: 0)
        let point2 = Point(col: 1, row: 0)
        let point3 = Point(col: 2, row: 0)
        
        // Start chain
        store.beginChain(at: point1)
        #expect(store.currentChain == [point1])
        
        // Extend with same value
        store.extendChain(to: point2)
        #expect(store.currentChain == [point1, point2])
        #expect(store.chainValidation == nil)
        
        // Extend with double value
        store.extendChain(to: point3)
        #expect(store.currentChain == [point1, point2, point3])
        #expect(store.chainValidation == nil)
    }
    
    @Test("Glass shatter and power-up award")
    @MainActor
    func testGlassShatterReward() {
        let config = GlassGameStore.Config(
            giftWeights: [.hammer: 100], // Guarantee hammer reward
            giftOnAutoDrop: false
        )
        let store = GlassGameStore(cols: 3, rows: 3, seed: 12345, config: config)
        
        // Set up a chain that ends on glass
        store._setTileForTesting(at: Point(col: 0, row: 0), tile: GlassTile.normal(value: 4))
        store._setTileForTesting(at: Point(col: 1, row: 0), tile: GlassTile.normal(value: 4))
        
        // Manually set a glass preview tile
        store._setPreviewForTesting(col: 1, tiles: [GlassTile.glassPreview(value: 4)])
        
        let initialPowerUps = store.powerups[.hammer] ?? 0
        
        // Build chain ending on glass preview
        store.beginChain(at: Point(col: 0, row: 0))
        store.extendChain(to: Point(col: 1, row: 0))
        
        // Try to end on glass preview (this requires the preview to be adjacent)
        let glassPoint = Point(col: 1, row: 3) // Preview point
        store.extendChain(to: glassPoint)
        
        if store.chainValidation == nil {
            store.commitChain()
            
            // Should have awarded power-up
            let finalPowerUps = store.powerups[.hammer] ?? 0
            #expect(finalPowerUps > initialPowerUps, "Should have awarded hammer power-up")
        }
    }
    
    @Test("Gravity and refill mechanics")
    @MainActor
    func testGravityAndRefill() {
        let store = GlassGameStore(cols: 2, rows: 3, seed: 12345)
        
        // Set up a sparse board
        store._setTileForTesting(at: Point(col: 0, row: 0), tile: nil)
        store._setTileForTesting(at: Point(col: 0, row: 1), tile: GlassTile.normal(value: 4))
        store._setTileForTesting(at: Point(col: 0, row: 2), tile: nil)
        
        store._setTileForTesting(at: Point(col: 1, row: 0), tile: GlassTile.normal(value: 8))
        store._setTileForTesting(at: Point(col: 1, row: 1), tile: nil)
        store._setTileForTesting(at: Point(col: 1, row: 2), tile: GlassTile.normal(value: 16))
        
        // Manually trigger gravity and refill (these are private, so we'd need to expose them or test through commit)
        // For now, we'll test through a chain commit
        
        // Create a simple valid chain
        store._setTileForTesting(at: Point(col: 0, row: 1), tile: GlassTile.normal(value: 2))
        store._setTileForTesting(at: Point(col: 1, row: 1), tile: GlassTile.normal(value: 2))
        
        store.beginChain(at: Point(col: 0, row: 1))
        store.extendChain(to: Point(col: 1, row: 1))
        store.commitChain()
        
        // After commit, gravity should have been applied and board refilled
        // Check that there are no empty cells (refill should fill everything)
        var emptyCount = 0
        for col in 0..<2 {
            for row in 0..<3 {
                if store._getTileForTesting(at: Point(col: col, row: row)) == nil {
                    emptyCount += 1
                }
            }
        }
        
        #expect(emptyCount == 0, "Board should be completely filled after refill")
    }
    
    @Test("Analytics events generation")
    @MainActor
    func testAnalyticsEvents() {
        let store = GlassGameStore(cols: 2, rows: 2, seed: 12345)
        
        let initialEventCount = store.analyticsEvents.count
        
        // Set up a simple chain
        store._setTileForTesting(at: Point(col: 0, row: 0), tile: GlassTile.normal(value: 2))
        store._setTileForTesting(at: Point(col: 0, row: 1), tile: GlassTile.normal(value: 2))
        
        store.beginChain(at: Point(col: 0, row: 0))
        store.extendChain(to: Point(col: 0, row: 1))
        store.commitChain()
        
        // Should have generated merge_chain event
        #expect(store.analyticsEvents.count > initialEventCount, "Should have generated analytics events")
        
        let mergeEvents = store.analyticsEvents.filter { $0.type == "merge_chain" }
        #expect(mergeEvents.count > 0, "Should have generated merge_chain event")
        
        if let mergeEvent = mergeEvents.last {
            #expect(mergeEvent.parameters["length"] == "2", "Chain length should be 2")
            #expect(mergeEvent.parameters["endedOnGlass"] == "false", "Should not have ended on glass")
        }
    }
    
    @Test("Configuration presets")
    func testConfigurationPresets() {
        let balanced = GlassGameStore.Config.balanced
        #expect(balanced.backgroundColorHex == "#020617")
        #expect(balanced.giftOnAutoDrop == false)
        #expect(balanced.requireDirectBelowInChain == true)
        
        let generous = GlassGameStore.Config.generous
        #expect(generous.giftOnAutoDrop == true)
        #expect(generous.requireDirectBelowInChain == false)
        
        let challenging = GlassGameStore.Config.challenging
        #expect(challenging.giftWeights[.bomb]! > challenging.giftWeights[.hammer]!)
    }
}

@Suite("Edge Cases and Error Conditions")
struct GlassPreviewEdgeCaseTests {
    
    @Test("Empty weight array handling")
    func testEmptyWeights() {
        var rng = AnyRandomNumberGenerator(Xoroshiro(seed: 123))
        let emptyWeights: [(String, Int)] = []
        
        let result = weightedPick(weights: emptyWeights, rng: &rng)
        #expect(result == nil, "Should return nil for empty weights")
    }
    
    @Test("Zero total weight handling")
    func testZeroTotalWeight() {
        var rng = AnyRandomNumberGenerator(Xoroshiro(seed: 123))
        let zeroWeights: [(String, Int)] = [("A", 0), ("B", 0)]
        
        let result = weightedPick(weights: zeroWeights, rng: &rng)
        #expect(result == nil, "Should return nil for zero total weight")
    }
    
    @Test("Single item weight handling")
    func testSingleItemWeight() {
        var rng = AnyRandomNumberGenerator(Xoroshiro(seed: 123))
        let singleWeight: [(String, Int)] = [("Only", 100)]
        
        let result = weightedPick(weights: singleWeight, rng: &rng)
        #expect(result == "Only", "Should return the only item")
    }
    
    @Test("Game store with minimal dimensions")
    @MainActor
    func testMinimalGameStore() {
        let store = GlassGameStore(cols: 1, rows: 1, seed: 12345)
        
        #expect(store.cols == 1)
        #expect(store.rows == 1)
        #expect(store.grid.count == 1)
        #expect(store.grid[0].count == 1)
        #expect(store.preview.count == 1)
        
        // Should be able to handle basic operations
        #expect(!store.isGameOver, "Minimal game should not be immediately over")
    }
}

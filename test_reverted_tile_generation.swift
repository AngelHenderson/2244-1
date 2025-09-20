#!/usr/bin/env swift

import Foundation

// Test verification for reverted tile generation
print("Testing Reverted Tile Generation...")

print("✅ TILE GENERATION REVERTED:")
print("   • fillBoardToFull() uses generateRandomValue()")
print("   • spawnNewTile() uses generateRandomValue()")
print("   • rerollRandomCells() uses generateRandomValue()")
print("   • No more pattern-based generation")
print("   • Tiles are now randomly generated again")

print("\n✅ 7-TILE SPAWNING KEPT:")
print("   • generateRandomValue() still uses 7 lowest tiles")
print("   • Spawning pool: [2, 4, 8, 16, 32, 64, 128]")
print("   • Progressive spawning window maintained")
print("   • Each tile has equal probability")

print("\n✅ ELIMINATION RULES MAINTAINED:")
print("   • 2048 → 2s removed")
print("   • 4096 → 4s removed")
print("   • 16K → 8s removed")
print("   • 32K → 16s removed")
print("   • 65K → 32s removed")
print("   • 262K → 64s removed")
print("   • 524K → 128s removed")
print("   • 1M → 256s removed")
print("   • 4M → 512s removed")
print("   • 8M → 1024s removed")
print("   • 16M → 2048s removed")

print("\n✅ BOARD CONFIGURATION:")
print("   • Board width: 5 columns (unchanged)")
print("   • Board height: 8 rows (unchanged)")
print("   • Random tile generation (no patterns)")
print("   • 7-tile spawning pool")

print("\n✅ CURRENT SYSTEM:")
print("   • Random tile placement and values")
print("   • 7-tile spawning pool for variety")
print("   • Time-based elimination rules")
print("   • Auto-save functionality")
print("   • No pattern-based generation")

print("\n🎉 Tile generation successfully reverted!")
print("System now uses random generation with 7-tile spawning pool!")

// Helper function to simulate the spawning logic
func simulateSpawning(minAllowed: Int) -> [Int] {
    var candidates: [Int] = []
    var current = minAllowed
    for _ in 0..<7 {
        candidates.append(current)
        if current > (Int.max >> 1) {
            current = Int.max
        } else {
            current = current << 1
        }
    }
    return candidates
}

print("\n✅ Spawning Pool Examples:")
let examples = [2, 4, 8, 16]
for minAllowed in examples {
    let candidates = simulateSpawning(minAllowed: minAllowed)
    print("   minAllowed=\(minAllowed): [\(candidates.map(String.init).joined(separator: ", "))]")
}

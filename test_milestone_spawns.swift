#!/usr/bin/env swift

// Demonstration of milestone spawn pool changes

print("=" * 70)
print("MILESTONE SPAWN POOL DEMONSTRATION")
print("=" * 70)

func showMilestoneEffects(milestone: Int, eliminates: Int?) {
    print("\n📍 Milestone: \(milestone)")
    print("-" * 50)

    if let elim = eliminates {
        print("  ❌ Eliminates: \(elim)")

        // The spawn pool starts at elim * 2 and includes 7 tiles
        let minSpawn = elim * 2
        var spawnRange: [Int] = []
        var current = minSpawn
        for _ in 0..<7 {
            spawnRange.append(current)
            if current <= Int.max / 2 {
                current *= 2
            } else {
                break
            }
        }

        print("  📦 New spawn pool (7 tiles):")
        print("     \(spawnRange)")

        // The "added" notification shows the tile 7 steps above eliminated
        let addedNotification = elim * 128  // 2^7 = 128
        print("  ➕ Added notification shows: \(addedNotification)")
        print("     (This is 7 doublings above \(elim))")
    } else {
        print("  ⏭️  SKIP MILESTONE - No changes to spawn pool")
        print("  📬 Only shows UNLOCK notification")
    }
}

print("\n🎮 EXAMPLES:")
print("=" * 70)

// Example milestones
showMilestoneEffects(milestone: 2048, eliminates: 2)
showMilestoneEffects(milestone: 4096, eliminates: 4)
showMilestoneEffects(milestone: 8192, eliminates: nil)  // Skip
showMilestoneEffects(milestone: 16384, eliminates: 8)
showMilestoneEffects(milestone: 32768, eliminates: 16)
showMilestoneEffects(milestone: 65536, eliminates: 32)
showMilestoneEffects(milestone: 131072, eliminates: nil)  // Skip

print("\n" + "=" * 70)
print("📝 SUMMARY:")
print("  • When eliminating value X:")
print("    - Spawn pool starts at X*2 and includes 7 consecutive doublings")
print("    - The 'Added' notification shows X*128 (the 7th doubling)")
print("  • Skip milestones show no added/eliminated notifications")
print("=" * 70)

// Extension for string repetition
extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
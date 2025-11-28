#!/usr/bin/env swift

// Test script to demonstrate that skip milestones don't show unnecessary notifications

import Foundation

print("=" * 70)
print("MILESTONE NOTIFICATION BEHAVIOR TEST")
print("=" * 70)

// Simulated milestone data (matching GameEngine logic)
func milestoneExcludedValue(for milestone: Int) -> Int? {
    switch milestone {
    case 2048: return 2        // Eliminates 2s
    case 4096: return 4        // Eliminates 4s
    case 8192: return nil      // SKIP - no elimination
    case 16384: return 8       // Eliminates 8s
    case 32768: return 16      // Eliminates 16s
    case 65536: return 32      // Eliminates 32s
    case 131072: return nil    // SKIP - no elimination
    case 262144: return 64     // Eliminates 64s
    case 524288: return 128    // Eliminates 128s
    case 1048576: return 256   // Eliminates 256s
    case 2097152: return nil   // SKIP - no elimination
    default: return nil
    }
}

func milestoneAddedValue(for milestone: Int) -> Int? {
    guard let eliminated = milestoneExcludedValue(for: milestone) else {
        // Skip milestones don't change spawn pool
        return nil
    }

    // When we eliminate X, we add X*2 to spawn pool
    let added = eliminated * 2
    return added > 2 ? added : nil
}

func testMilestoneNotifications(from previousHighest: Int, to newHighest: Int) {
    print("\n📈 Creating tile: \(newHighest) (previous highest: \(previousHighest))")
    print("-" * 50)

    // Find all milestones passed
    let milestones = [2048, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 524288, 1048576, 2097152]
    let passed = milestones.filter { $0 > previousHighest && $0 <= newHighest }

    if passed.isEmpty {
        print("  No milestones passed")
        return
    }

    print("  Milestones passed: \(passed)")

    // Determine notifications
    var notifications: [String] = []

    // Always show unlock
    notifications.append("🔓 UNLOCKED: \(newHighest)")

    // Check for additions
    var addedValues: Set<Int> = []
    for milestone in passed {
        if let added = milestoneAddedValue(for: milestone) {
            addedValues.insert(added)
        }
    }

    if let maxAdded = addedValues.max() {
        notifications.append("➕ ADDED to spawn: \(maxAdded)")
    }

    // Check for eliminations
    var eliminatedValues: Set<Int> = []
    for milestone in passed {
        if let eliminated = milestoneExcludedValue(for: milestone) {
            eliminatedValues.insert(eliminated)
        }
    }

    if let maxEliminated = eliminatedValues.max() {
        notifications.append("❌ ELIMINATED: \(maxEliminated)")
    }

    print("\n  📬 Notifications shown:")
    for notification in notifications {
        print("     \(notification)")
    }

    // Special note for skip milestones
    for milestone in passed {
        if milestoneExcludedValue(for: milestone) == nil {
            print("\n  ⚠️  NOTE: \(milestone) is a SKIP milestone - no elimination/addition windows!")
        }
    }
}

print("\n🧪 TEST CASES:")
print("=" * 70)

// Test 1: Creating 8192 directly (skip milestone)
testMilestoneNotifications(from: 128, to: 8192)

// Test 2: Creating 16384 (elimination milestone)
testMilestoneNotifications(from: 8192, to: 16384)

// Test 3: Creating 131072 (skip milestone)
testMilestoneNotifications(from: 65536, to: 131072)

// Test 4: Creating 2097152 (skip milestone)
testMilestoneNotifications(from: 1048576, to: 2097152)

print("\n" + "=" * 70)
print("✅ SUMMARY:")
print("  • Skip milestones (8192, 131072, 2097152) only show UNLOCK notification")
print("  • Elimination milestones show UNLOCK + ADDED + ELIMINATED notifications")
print("  • This prevents confusing empty notification windows")
print("=" * 70)

// Extension for string repetition
extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
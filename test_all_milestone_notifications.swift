#!/usr/bin/env swift

// Test all milestones to verify they show proper notifications

import Foundation

// Simulate the milestone functions
func milestoneExcludedValue(for milestone: Int) -> Int? {
    let skipMilestones = [8192, 131072, 2097152, 33554432]
    if skipMilestones.contains(milestone) {
        return nil
    }

    switch milestone {
    case 128: return 1
    case 256: return 1
    case 512: return 1
    case 1024: return 1
    case 2048: return 2
    case 4096: return 4
    case 16384: return 8
    case 32768: return 16
    case 65536: return 32
    case 262144: return 64
    case 524288: return 128
    case 1048576: return 256
    case 4194304: return 512
    case 8388608: return 1024
    case 16777216: return 2048
    case 67108864: return 4096
    case 134217728: return 8192
    default:
        if milestone >= 268435456 {
            let log67M = 26
            let logMilestone = Int(log2(Double(milestone)))
            let position = logMilestone - log67M
            if position % 3 == 2 {
                return nil // Skip
            }
            return milestone >> 14
        }
        return nil
    }
}

func milestoneAddedValue(for milestone: Int) -> Int? {
    let skipMilestones = [8192, 131072, 2097152, 33554432]
    if skipMilestones.contains(milestone) {
        return nil
    }

    if milestone >= 268435456 {
        let log67M = 26
        let logMilestone = Int(log2(Double(milestone)))
        let position = logMilestone - log67M
        if position % 3 == 2 {
            return nil
        }
    }

    if let eliminated = milestoneExcludedValue(for: milestone) {
        return eliminated * 128  // 7 steps above
    }

    if milestone >= 128 {
        let implicitEliminated = milestone / 16
        if implicitEliminated >= 1 {
            return implicitEliminated * 128
        }
    }

    return nil
}

print("=" * 80)
print("MILESTONE NOTIFICATION VERIFICATION")
print("=" * 80)

let allMilestones = [
    128, 256, 512, 1024, 2048, 4096, 8192,
    16384, 32768, 65536, 131072,
    262144, 524288, 1048576, 2097152,
    4194304, 8388608, 16777216, 33554432,
    67108864, 134217728
]

print("\n📊 MILESTONE ANALYSIS:")
print("-" * 80)

var skipCount = 0
var fullNotificationCount = 0

for milestone in allMilestones {
    let eliminated = milestoneExcludedValue(for: milestone)
    let added = milestoneAddedValue(for: milestone)

    let isSkip = (eliminated == nil && added == nil)

    if isSkip {
        print("\n⏭️  \(milestone):")
        print("    Type: SKIP MILESTONE")
        print("    Windows: [✅ Unlocked] only")
        skipCount += 1
    } else {
        print("\n🎯 \(milestone):")
        print("    Type: Regular Milestone")

        var windows: [String] = ["✅ Unlocked"]

        if let add = added {
            windows.append("➕ Added: \(add)")
        } else {
            windows.append("⚠️ MISSING Added")
        }

        if let elim = eliminated {
            windows.append("❌ Eliminated: \(elim)")
        } else {
            windows.append("⚠️ MISSING Eliminated")
        }

        print("    Windows: \(windows.joined(separator: ", "))")

        if eliminated != nil && added != nil {
            fullNotificationCount += 1
        }
    }
}

print("\n" + "=" * 80)
print("📈 SUMMARY:")
print("  • Total milestones: \(allMilestones.count)")
print("  • Skip milestones: \(skipCount) (should be 4: 8192, 131072, 2097152, 33554432)")
print("  • Regular milestones with all 3 windows: \(fullNotificationCount) (should be \(allMilestones.count - 4))")
print("  • Expected behavior:")
print("    - Skip milestones show ONLY Unlocked")
print("    - ALL other milestones show Unlocked + Added + Eliminated")
print("=" * 80)

// Extension for string repetition
extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
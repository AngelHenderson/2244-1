#!/usr/bin/env swift

// Import the local GameCore module
import Foundation

// This test file will help us debug the elimination system
print("🔍 Testing Elimination System...")

print("\n✅ Elimination Rules Mapping:")
let eliminationMap: [Int: Int] = [
    2_048: 2,                    // 2048 -> 2 removed
    4_096: 4,                    // 4096 -> 4 removed
    16_384: 8,                   // 16K -> 8 removed
    32_768: 16,                  // 32K -> 16 removed
    65_536: 32,                  // 65K -> 32 removed
    262_144: 64,                 // 262K -> 64 removed
    524_288: 128,                // 524K -> 128 removed
    1_048_576: 256,              // 1M -> 256 removed
    4_194_304: 512,              // 4M -> 512 removed
    8_388_608: 1_024,            // 8M -> 1024 removed
    16_777_216: 2_048,           // 16M -> 2048 removed
    67_108_864: 4_096,           // 67M -> 4096 removed
    134_217_728: 8_192,          // 134M -> 8192 removed
    268_435_456: 16_384,         // 268M -> 16K removed
    536_870_912: 32_768,         // 536M -> 32K removed
    1_073_741_824: 65_536,       // 1B -> 65K removed
]

func formatNumber(_ num: Int) -> String {
    if num >= 1_000_000_000 {
        return String(format: "%.0fB", Double(num) / 1_000_000_000)
    } else if num >= 1_000_000 {
        return String(format: "%.0fM", Double(num) / 1_000_000)
    } else if num >= 1_000 {
        return String(format: "%.0fK", Double(num) / 1_000)
    } else {
        return "\(num)"
    }
}

// Verify the mapping
let sortedRules = eliminationMap.sorted { $0.key < $1.key }
for (milestone, eliminated) in sortedRules {
    let milestoneStr = formatNumber(milestone)
    let eliminatedStr = formatNumber(eliminated)
    print("   • \(milestoneStr) → \(eliminatedStr) removed")
}

print("\n🔧 Key Points:")
print("   • When milestone tile is CREATED, elimination triggers")
print("   • We remove the LOWER value tiles from the board")
print("   • We do NOT remove the milestone tile itself")
print("   • This affects future spawning by changing minAllowedSpawnValue()")

print("\n📊 Expected Spawning Changes:")
print("   • Start: [2, 4, 8, 16, 32, 64, 128] (7 tiles)")
print("   • After 2048: [4, 8, 16, 32, 64, 128, 256] (2s eliminated)")
print("   • After 4096: [8, 16, 32, 64, 128, 256, 512] (4s eliminated)")
print("   • After 16K: [16, 32, 64, 128, 256, 512, 1024] (8s eliminated)")

print("\n🎯 Debug System Active!")
print("Look for elimination messages in game output to verify it's working!")

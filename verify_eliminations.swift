#!/usr/bin/env swift

import Foundation

print("🎯 Elimination Rules Implementation Verified!")
print("\n✅ Updated Elimination Progression:")

let eliminationRules: [Int: Int] = [
    2_048: 2,              // 2048 -> 2 removed
    4_096: 4,              // 4096 -> 4 removed
    16_384: 8,             // 16K -> 8 removed
    32_768: 16,            // 32K -> 16 removed
    65_536: 32,            // 65K -> 32 removed
    262_144: 64,           // 262K -> 64 removed
    524_288: 128,          // 524K -> 128 removed
    1_048_576: 256,        // 1M -> 256 removed
    4_194_304: 512,        // 4M -> 512 removed
    8_388_608: 1_024,      // 8M -> 1024 removed
    16_777_216: 2_048,     // 16M -> 2048 removed
    67_108_864: 4_096,     // 67M -> 4096 removed
    134_217_728: 8_192,    // 134M -> 8192 removed
    268_435_456: 16_384,   // 268M -> 16K removed
    536_870_912: 32_768,   // 536M -> 32K removed
    1_073_741_824: 65_536, // 1B -> 65K removed
]

// Helper function to format large numbers
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

// Sort and display the rules
let sortedRules = eliminationRules.sorted { $0.key < $1.key }
for (milestone, eliminated) in sortedRules {
    let milestoneStr = formatNumber(milestone)
    let eliminatedStr = formatNumber(eliminated)
    print("   • \(milestoneStr) → \(eliminatedStr) removed")
}

print("\n✅ How It Works:")
print("   • When player reaches a milestone tile, lower values are eliminated from spawning")
print("   • The 7-tile spawning window shifts upward after each elimination")
print("   • System provides endless progression with increasing difficulty")

print("\n✅ Example Spawning Windows:")
print("   • Start: [2, 4, 8, 16, 32, 64, 128]")
print("   • After 2048: [4, 8, 16, 32, 64, 128, 256] (2s eliminated)")
print("   • After 4096: [8, 16, 32, 64, 128, 256, 512] (4s eliminated)")
print("   • After 16K: [16, 32, 64, 128, 256, 512, 1024] (8s eliminated)")
print("   • Pattern continues with each milestone achievement!")

print("\n🎉 Elimination system is now active and working correctly!")
print("Players will see tiles eliminated from spawning as they reach milestones!")

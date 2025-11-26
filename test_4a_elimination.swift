#!/usr/bin/env swift
import Foundation

// 4a is approximately 4 trillion = 4 * 10^12 ≈ 2^42
let fourTrillion = 4_398_046_511_104 // 2^42 exactly

print("When reaching 4a (≈2^42 = \(fourTrillion)):")
print("")

// Calculate what should be eliminated
let eliminated = fourTrillion >> 14  // 14 steps down
print("Eliminated value: \(eliminated) (which is \(eliminated / 1_000_000)M)")

// Check if 33M and 67M should be eliminated
let thirtyThreeM = 33_554_432  // 33M
let sixtySevenM = 67_108_864   // 67M

print("")
print("Should 33M (\(thirtyThreeM)) be eliminated? \(thirtyThreeM == eliminated ? "YES" : "NO - 33M is larger than \(eliminated)")")
print("Should 67M (\(sixtySevenM)) be eliminated? \(sixtySevenM == eliminated ? "YES" : "NO - 67M is larger than \(eliminated)")")

print("")
print("Actually, when 4a is created:")
print("  - It eliminates all tiles with value \(eliminated) (268M)")
print("  - 33M and 67M are SMALLER than 268M, but that's not what gets eliminated")
print("  - The pattern eliminates a SPECIFIC value, not all values below it")

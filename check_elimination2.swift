#!/usr/bin/env swift
import Foundation

// What milestone would eliminate 33M and 67M?
let thirtyThreeM = 33_554_432  // 33M = 2^25
let sixtySevenM = 67_108_864   // 67M = 2^26

// If eliminated value = milestone >> 14, then
// milestone = eliminated value << 14

let milestoneFor33M = thirtyThreeM << 14  // What milestone eliminates 33M?
let milestoneFor67M = sixtySevenM << 14   // What milestone eliminates 67M?

print("To eliminate 33M (33,554,432 = 2^25):")
print("  Need milestone: \(milestoneFor33M) (2^39)")
print("  In readable form: \(Double(milestoneFor33M) / 1_000_000_000_000)a")
print("")
print("To eliminate 67M (67,108,864 = 2^26):")
print("  Need milestone: \(milestoneFor67M) (2^40)")
print("  In readable form: \(Double(milestoneFor67M) / 1_000_000_000_000)a")
print("")

// But wait - the user reached 4a and still sees 33M and 67M
// This suggests we should be eliminating ALL values below a certain threshold
// not just one specific value

print("Current system: Each milestone eliminates ONE specific value")
print("Expected behavior: Eliminate ALL values below some threshold?")
print("")
print("If we wanted to eliminate all tiles 14 steps below the milestone:")
let fourA = 4_398_046_511_104 // 2^42
let threshold = fourA >> 14
print("  4a (2^42) >> 14 = \(threshold) (268M)")
print("  This would eliminate everything < 268M")
print("  Including: 2, 4, 8, 16, 32... up to 134M")

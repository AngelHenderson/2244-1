#!/usr/bin/env swift
import Foundation

// What milestone would eliminate 33M and 67M?
let thirtyThreeM = 33_554_432  // 33M = 2^25
let sixtySevenM = 67_108_864   // 67M = 2^26

// If eliminated value = milestone >> 14, then
// milestone = eliminated value << 14

let milestoneFor33M = thirtyThreeM << 14  // What milestone eliminates 33M?
let milestoneFor67M = sixtySevenM << 14   // What milestone eliminates 67M?

print("To eliminate 33M (\(thirtyThreeM)):")
print("  Need milestone: \(milestoneFor33M)")
print("  Which is 2^\(Int(log2(Double(milestoneFor33M))))")
print("  That's approximately \(milestoneFor33M / 1_000_000_000_000) trillion")
print("")
print("To eliminate 67M (\(sixtySevenM)):")
print("  Need milestone: \(milestoneFor67M)")  
print("  Which is 2^\(Int(log2(Double(milestoneFor67M))))")
print("  That's approximately \(milestoneFor67M / 1_000_000_000_000) trillion")
print("")
print("Since 4a ≈ 4 trillion (2^42):")
print("  4a would eliminate: \((4_398_046_511_104) >> 14) = 268M")
print("  To eliminate 33M: need 549 trillion (549a or 1b)")
print("  To eliminate 67M: need 1098 trillion (1098a or 1b)")

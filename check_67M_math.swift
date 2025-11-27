#!/usr/bin/env swift
import Foundation

let sixtySevenM = 67_108_864  // 67M = 2^26

let eliminationThreshold = sixtySevenM >> 14  // 14 steps down
let spawnBase = sixtySevenM >> 7  // 7 steps down

print("67M = \(sixtySevenM)")
print("Elimination threshold (67M >> 14) = \(eliminationThreshold)")
print("Spawn base (67M >> 7) = \(spawnBase)")
print("")
print("This means:")
print("  - Eliminate all tiles < \(eliminationThreshold)")
print("  - Spawn tiles starting from \(spawnBase)")
print("")
print("The issue: spawn base (\(spawnBase)) > elimination threshold (\(eliminationThreshold))")
print("So spawning from \(spawnBase) is correct - it's well above the elimination threshold")

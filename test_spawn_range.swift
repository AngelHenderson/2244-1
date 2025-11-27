#!/usr/bin/env swift
import Foundation

// Test spawn range for various milestones
func testSpawnRange(milestone: Int, label: String) {
    let maxSpawn = milestone >> 1  // 1 step down
    let minSpawn = milestone >> 7  // 7 steps down
    
    print("\n\(label) (milestone = \(milestone)):")
    print("  Spawn range: \(minSpawn) to \(maxSpawn)")
    
    // Show the actual values that would spawn
    var candidates: [Int] = []
    var current = minSpawn
    for i in 0..<7 {
        if current <= maxSpawn {
            candidates.append(current)
            print("    Candidate \(i+1): \(formatValue(current))")
        }
        current = current << 1
    }
}

func formatValue(_ value: Int) -> String {
    if value >= 1_000_000_000_000_000_000 {
        return "\(value / 1_000_000_000_000_000_000)c"
    } else if value >= 1_000_000_000_000_000 {
        return "\(value / 1_000_000_000_000_000)b"
    } else if value >= 1_000_000_000_000 {
        return "\(value / 1_000_000_000_000)a"
    } else if value >= 1_000_000_000 {
        return "\(value / 1_000_000_000)B"
    } else if value >= 1_000_000 {
        return "\(value / 1_000_000)M"
    } else if value >= 1_000 {
        return "\(value / 1_000)K"
    } else {
        return "\(value)"
    }
}

// Test with various milestones
testSpawnRange(milestone: 67_108_864, label: "67M")
testSpawnRange(milestone: 1_000_000_000_000, label: "1T (1a)")
testSpawnRange(milestone: 4_000_000_000_000, label: "4T (4a)")

// Simulate 9c scenario
let nineC = 9_000_000_000_000_000_000  // 9 quintillion
testSpawnRange(milestone: nineC, label: "9c")

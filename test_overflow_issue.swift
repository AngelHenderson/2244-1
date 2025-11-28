#!/usr/bin/env swift
import Foundation

// Test overflow behavior with large numbers
let largeValues: [Int] = [
    1_000_000_000_000_000_000,  // 1 quintillion (1c)
    4_500_000_000_000_000_000,  // 4.5 quintillion
    9_000_000_000_000_000_000   // 9 quintillion (9c)
]

print("Testing overflow behavior:")
print("Int.max = \(Int.max)")
print("Int.max >> 1 = \(Int.max >> 1)")
print()

for value in largeValues {
    print("Value: \(value) (\(value / 1_000_000_000_000_000_000)c)")
    print("  value > (Int.max >> 1): \(value > (Int.max >> 1))")
    print("  value << 1 = \(value << 1)")
    print("  value * 2 = \(value &* 2)")  // Using overflow operator
    print()
}

// Simulate the game logic
func simulateSpawnLogic(highestTile: Int) -> [Int] {
    let maxSpawn = highestTile >> 1    // 1 step down
    let minSpawn = highestTile >> 7    // 7 steps down

    print("Simulating spawn logic for highest tile: \(highestTile)")
    print("  maxSpawn: \(maxSpawn)")
    print("  minSpawn: \(minSpawn)")

    var candidates: [Int] = []
    var current = minSpawn
    for i in 0..<7 {
        if current <= maxSpawn {
            candidates.append(current)
            print("  Candidate \(i): \(current)")
        }
        if current > (Int.max >> 1) {
            print("  Breaking due to overflow risk at iteration \(i)")
            break
        } else {
            let nextValue = current << 1
            print("  Next value would be: \(nextValue) (negative: \(nextValue < 0))")
            current = nextValue
        }
    }

    return candidates
}

print("\n--- Testing with 9 quintillion ---")
let nineQuintillion = 9_000_000_000_000_000_000
let candidates = simulateSpawnLogic(highestTile: nineQuintillion)
print("Final candidates: \(candidates)")
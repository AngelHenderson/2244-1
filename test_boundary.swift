#!/usr/bin/env swift

// Check the exact boundary where normal tiles end

let maxSafeDouble = Int.max >> 1  // Max value we can double without overflow

print("Boundary analysis:")
print("==================")
print("Int.max = \(Int.max)")
print("Int.max = 2^63 - 1")
print("Int.max >> 1 = \(maxSafeDouble)")
print("Int.max >> 1 = 2^62 - 1")
print()

// What's the largest power of 2 that fits?
var current = 1
var exponent = 0
while current <= maxSafeDouble && current > 0 {
    let next = current << 1
    if next > maxSafeDouble || next < 0 {
        break
    }
    current = next
    exponent += 1
}

print("Largest power of 2 that fits: 2^\(exponent) = \(current)")
print()

// Simulate JourneyTileGenerator
print("JourneyTileGenerator simulation:")
print("================================")
current = 2
var step = 1
var lastNormalStep = 0

while current > 0 && current <= maxSafeDouble {
    print("Step \(step): value = 2^\(current.trailingZeroBitCount) = \(current)")
    lastNormalStep = step
    current = current << 1
    step += 1

    if step > 63 { break }  // Stop after a few iterations
}

print("\nLast normal tile: step \(lastNormalStep)")
print("First highValue tile: step \(lastNormalStep + 1)")
print()
print("So the last normal tile is 2^62 at step 62")
print("The first highValue tile is 2^63 at step 63")
print()
print("This means JourneyTileGenerator assigns step = exponent!")
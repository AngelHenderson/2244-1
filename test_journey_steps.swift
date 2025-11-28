#!/usr/bin/env swift

// Check what step numbers JourneyTileGenerator actually assigns

print("JourneyTileGenerator step assignments:")
print("======================================")

// Simulate JourneyTileGenerator logic
var current = 2
var step = 1
var tiles: [(value: Int, step: Int)] = []

// Generate tiles up to 2^62
while current > 0 && current <= (Int.max >> 1) {
    tiles.append((value: current, step: step))
    current = current << 1
    step += 1
}

// Show some key values
print("\nNormal tiles (value stored directly):")
print("Value\tExponent\tStep from Generator")
print("-----\t--------\t------------------")

let interestingValues = [2, 4, 2048, 4096, 262144, 524288, 1048576]
for (value, step) in tiles {
    if interestingValues.contains(value) {
        let exponent = value.trailingZeroBitCount
        print("2^\(exponent)\t\(exponent)\t\t\(step)")
    }
}

// After step 62, highValue tiles are created
print("\nHighValue tiles (step stored, value = Int.max):")
print("Label\tExponent\tStep from Generator")
print("-----\t--------\t------------------")

// These would be created as .highValue(step: N)
let highValueSteps = [
    ("1c", 60, 60),
    ("2c", 61, 61),
    ("4c", 62, 62),
    ("9c", 63, 63),
    ("18c", 64, 64),
    ("36c", 65, 65),
]

for (label, exponent, expectedStep) in highValueSteps {
    print("\(label)\t\(exponent)\t\t\(expectedStep)")
}

print("\nAnalysis:")
print("=========")
print("JourneyTileGenerator assigns step numbers that equal the exponent!")
print("- 2^11 (2048) gets step 11")
print("- 2^60 (1c) gets step 60")
print("- 2^63 (9c) gets step 63")
print()
print("But wait, that's wrong! Let me check the actual step assignments...")
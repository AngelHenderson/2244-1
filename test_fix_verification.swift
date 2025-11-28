#!/usr/bin/env swift

// Verify the fix works correctly

func bucketIndex(forExponent exp: Int) -> Int {
    let e = max(1, exp)
    return (e - 1) % 25
}

func colorForStep(_ step: Int) -> Int {
    // After fix: exponent = step
    let exponent = step
    return bucketIndex(forExponent: exponent)
}

print("Verifying color fix for c-tier values:")
print("======================================")

let testCases = [
    ("2", 1, 2),
    ("2048", 11, 2048),
    ("4096", 12, 4096),
    ("8192", 13, 8192),
    ("16K", 14, 16384),
    ("32K", 15, 32768),
    ("1c", 60, 1024),   // Should match 2^10 = 1024
    ("2c", 61, 2048),   // Should match 2^11 = 2048
    ("4c", 62, 4096),   // Should match 2^12 = 4096
    ("9c", 63, 8192),   // Should match 2^13 = 8192
    ("18c", 64, 16384), // Should match 2^14 = 16K
    ("36c", 65, 32768), // Should match 2^15 = 32K
]

for (label, step, expectedMatch) in testCases {
    let paletteIndex = colorForStep(step)
    let matchesValue = 1 << (paletteIndex + 1)

    let status = (matchesValue == expectedMatch) ? "✓" : "✗"

    print("\(status) \(label) (step \(step)): palette index \(paletteIndex), matches 2^\(paletteIndex + 1) = \(matchesValue)")

    if matchesValue != expectedMatch {
        print("  ERROR: Expected to match \(expectedMatch)")
    }
}

print("\n25-cycle verification:")
print("======================")

let cyclePairs = [
    ("2048 and 2c", 11, 61),
    ("4096 and 4c", 12, 62),
    ("8192 and 9c", 13, 63),
    ("16K and 18c", 14, 64),
    ("32K and 36c", 15, 65),
]

for (pair, step1, step2) in cyclePairs {
    let index1 = colorForStep(step1)
    let index2 = colorForStep(step2)

    if index1 == index2 {
        print("✓ \(pair) both use palette index \(index1)")
    } else {
        print("✗ \(pair) have different indices: \(index1) vs \(index2)")
    }
}
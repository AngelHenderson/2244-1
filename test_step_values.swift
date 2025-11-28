#!/usr/bin/env swift

// Test what step values correspond to c-tier values

// Step = exponent - 1 (since step 1 = 2^1 = 2)
// So for 2^60 (1c), step = 60 - 1 = 59? No, step = 60

let cValues = [
    ("1c", 60, 59),   // 2^60, step 59
    ("2c", 61, 60),   // 2^61, step 60
    ("4c", 62, 61),   // 2^62, step 61
    ("9c", 63, 62),   // 2^63, step 62 (note: should be 8c)
    ("18c", 64, 63),  // 2^64, step 63
    ("36c", 65, 64),  // 2^65, step 64
]

print("C-tier values and their step numbers:")
print("=====================================")

for (label, exponent, step) in cValues {
    print("\(label):")
    print("  Exponent: \(exponent) (2^\(exponent))")
    print("  Step: \(step)")

    // When colorForStep is called with this step, what happens?
    // exponent = step + 1
    let calculatedExponent = step + 1
    print("  colorForStep calculates: exponent = \(step) + 1 = \(calculatedExponent)")

    // Then paletteEntry uses (exponent - 1) % 25
    let paletteIndex = (calculatedExponent - 1) % 25
    print("  Palette index: (\(calculatedExponent) - 1) % 25 = \(paletteIndex)")
    print()
}

print("\nExpected vs Actual palette indices:")
print("===================================")
print("4c: Expected index 11 (4096), Getting index \((61 - 1) % 25) = \(60 % 25) = 10")
print("9c: Expected index 12 (8192), Getting index \((62 - 1) % 25) = \(61 % 25) = 11")
print("18c: Expected index 13 (16K), Getting index \((63 - 1) % 25) = \(62 % 25) = 12")
print("36c: Expected index 14 (32K), Getting index \((64 - 1) % 25) = \(63 % 25) = 13")

print("\nThe problem: Steps are off by 1!")
print("=================================")
print("Step should equal exponent, not exponent - 1")
print("When tile value is 2^62 (4c), the step should be 62, not 61")
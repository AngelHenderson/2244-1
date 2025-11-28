#!/usr/bin/env swift

// Check the exponents and expected palette indices for c-tier values

let values: [(name: String, exponent: Int)] = [
    ("1c", 60),
    ("2c", 61),
    ("4c", 62),
    ("9c", 63),  // Note: This should be 8c (2^63), but the game shows 9c
    ("18c", 64),
    ("36c", 65),
    ("73c", 66),
    ("146c", 67)
]

print("C-tier values and their palette indices:")
print("=========================================")

for value in values {
    let paletteIndex = (value.exponent - 1) % 25
    let cycleNumber = (value.exponent - 1) / 25

    print("\(value.name) (2^\(value.exponent)):")
    print("  Palette index: \(paletteIndex)")
    print("  Cycle: \(cycleNumber)")

    // Show what value in the first 25 this corresponds to
    let correspondingExponent = paletteIndex + 1
    let correspondingValue = 1 << correspondingExponent
    print("  Should match color of 2^\(correspondingExponent) = \(correspondingValue)")
    print()
}

print("\nExpected color matches based on 25-cycle:")
print("==========================================")
print("4c (2^62) should match 2^12 = 4096")
print("8c/9c (2^63) should match 2^13 = 8192")
print("18c (2^64) should match 2^14 = 16K")
print("36c (2^65) should match 2^15 = 32K")

print("\nPalette indices for reference:")
print("==============================")
print("Index 9: 2^10 = 1024")
print("Index 10: 2^11 = 2048")
print("Index 11: 2^12 = 4096")
print("Index 12: 2^13 = 8192")
print("Index 13: 2^14 = 16K")
print("Index 14: 2^15 = 32K")
print("Index 15: 2^16 = 64K")
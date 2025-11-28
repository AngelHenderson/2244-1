#!/usr/bin/env swift

// Test the complete fix

func bucketIndex(forExponent exp: Int) -> Int {
    let e = max(1, exp)
    return (e - 1) % 25
}

// colorForStep now correctly uses: exponent = step + 1
func colorForStep(_ step: Int) -> Int {
    let exponent = step + 1
    return bucketIndex(forExponent: exponent)
}

let palette25Names = [
    "Azure",          // 0
    "Orange",         // 1
    "Hot Pink",       // 2
    "Pinned/16",      // 3
    "Muted Red",      // 4
    "Purple",         // 5
    "Dark Teal",      // 6
    "Red",            // 7
    "Pink",           // 8
    "Bright Green",   // 9
    "Vivid Pink",     // 10
    "Blue",           // 11
    "Cream",          // 12
    "Purple",         // 13
    "Cyan",           // 14
    "Yellow",         // 15
    "Coral Red",      // 16
    "Light Cyan",     // 17
    "Green",          // 18
    "Magenta",        // 19
    "Deep Purple",    // 20
    "Red",            // 21
    "Dark Blue",      // 22
    "Orange",         // 23
    "Lime"            // 24
]

print("Final verification of color assignments:")
print("========================================")
print()

print("Normal values (using 0-based steps from stepForValue):")
print("Value\tExponent\tStep\tIndex\tColor")
print("-----\t--------\t----\t-----\t-----")

let normalValues = [
    (2, "2"),
    (2048, "2048"),
    (4096, "4096"),
    (8192, "8192"),
    (16384, "16K"),
    (32768, "32K"),
    (262144, "262K"),
    (524288, "524K"),
    (1048576, "1M"),
]

for (value, label) in normalValues {
    let exponent = value.trailingZeroBitCount
    let step = exponent - 1  // stepForValue returns this
    let index = colorForStep(step)
    let color = palette25Names[index]

    print("\(label)\t\(exponent)\t\t\(step)\t\(index)\t\(color)")
}

print("\nHighValue tiles (using 0-based steps from JourneyTileGenerator):")
print("Label\tExponent\tStep\tIndex\tColor")
print("-----\t--------\t----\t-----\t-----")

let highValues = [
    ("1c", 60),
    ("2c", 61),
    ("4c", 62),
    ("9c", 63),
    ("18c", 64),
    ("36c", 65),
]

for (label, exponent) in highValues {
    let step = exponent - 1  // JourneyTileGenerator now stores this
    let index = colorForStep(step)
    let color = palette25Names[index]

    print("\(label)\t\(exponent)\t\t\(step)\t\(index)\t\(color)")
}

print("\n25-cycle verification:")
print("======================")

let pairs = [
    ("262K and 17B", 18, 43),  // 2^18 and 2^43
    ("524K and 35B", 19, 44),  // 2^19 and 2^44
    ("1M and 35a", 20, 45),    // 2^20 and 2^45
    ("2048 and 2c", 11, 61),   // 2^11 and 2^61
    ("4096 and 4c", 12, 62),   // 2^12 and 2^62
    ("8192 and 9c", 13, 63),   // 2^13 and 2^63
    ("16K and 18c", 14, 64),   // 2^14 and 2^64
    ("32K and 36c", 15, 65),   // 2^15 and 2^65
]

for (names, exp1, exp2) in pairs {
    let step1 = exp1 - 1
    let step2 = exp2 - 1
    let index1 = colorForStep(step1)
    let index2 = colorForStep(step2)

    if index1 == index2 {
        print("✓ \(names): both index \(index1) (\(palette25Names[index1]))")
    } else {
        print("✗ \(names): different indices \(index1) vs \(index2)")
    }
}
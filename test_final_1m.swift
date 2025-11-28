#!/usr/bin/env swift

// Final verification that 1M and its repetitions have the same color

let palette25 = [
    "#2FA7E4", // 0: Azure
    "#F49A3E", // 1: Orange
    "#F16597", // 2: Hot Pink
    "#BA6597", // 3: Pinned/16
    "#9E3A46", // 4: Muted Red
    "#9674FF", // 5: Purple
    "#03524B", // 6: Dark Teal
    "#FF0039", // 7: Red
    "#FF6F96", // 8: Pink
    "#07F901", // 9: Bright Green
    "#FF3B7B", // 10: Vivid Pink
    "#55B9FF", // 11: Blue
    "#FFFFEB", // 12: Cream
    "#8849D1", // 13: Purple
    "#00FFE5", // 14: Cyan
    "#FFD300", // 15: Yellow
    "#F05B59", // 16: Coral Red
    "#55DFFE", // 17: Light Cyan
    "#39B54A", // 18: Green
    "#E91E63", // 19: Magenta
    "#673AB7", // 20: Deep Purple
    "#F44336", // 21: Red
    "#1565C0", // 22: Dark Blue
    "#EF6C00", // 23: Orange
    "#C0CA33"  // 24: Lime
]

func paletteIndex(forExponent exp: Int) -> Int {
    return (exp - 1) % 25
}

print("1M and all its 25-exponent repetitions:")
print("========================================")

// Values that repeat every 25 exponents from 1M
let values = [
    ("1M", 20),      // 2^20
    ("35a", 45),     // 2^45 (20 + 25)
    ("1.1b", 70),    // 2^70 (20 + 50)
    ("37b", 95),     // 2^95 (20 + 75)
    ("1.2c", 120),   // 2^120 (20 + 100)
]

var allSameColor = true
var firstIndex = -1
var firstColor = ""

for (label, exponent) in values {
    let index = paletteIndex(forExponent: exponent)
    let color = palette25[index]

    print("\n\(label) (2^\(exponent)):")
    print("  Exponent % 25 = \(exponent % 25)")
    print("  Palette index: \(index)")
    print("  Color: \(color)")

    if firstIndex == -1 {
        firstIndex = index
        firstColor = color
    } else if index != firstIndex {
        allSameColor = false
        print("  ✗ ERROR: Different from 1M!")
    } else {
        print("  ✓ Same as 1M")
    }
}

print("\n========================================")
if allSameColor {
    print("✓ SUCCESS: All 1M repetitions have the same color!")
    print("Color: \(firstColor) at palette index \(firstIndex)")
} else {
    print("✗ FAILURE: Not all 1M repetitions have the same color!")
}

print("\n\nOther important values to check:")
print("=================================")

let otherTests = [
    ("2048", 11),
    ("2c", 61),     // Should match 2048
    ("4096", 12),
    ("4c", 62),     // Should match 4096
]

for (label, exponent) in otherTests {
    let index = paletteIndex(forExponent: exponent)
    print("\(label) (2^\(exponent)): index \(index) = \(palette25[index])")
}
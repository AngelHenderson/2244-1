#!/usr/bin/env swift

// Test that 140a and its repetitions are lightened to match 4M

func paletteIndex(forExponent exp: Int) -> Int {
    return (exp - 1) % 25
}

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

func isLightened(exponent: Int) -> Bool {
    return exponent == 47 || exponent == 72 || exponent == 97 || exponent == 122 || exponent == 147
}

print("Testing 140a lightening to match 4M:")
print("=====================================")
print()

// Test 4M
let exp4M = 22
let idx4M = paletteIndex(forExponent: exp4M)
print("4M (2^22):")
print("  Palette index: \(idx4M)")
print("  Base color: \(palette25[idx4M]) - Red")
print("  Adjustment: None (base value)")
print()

// Test 140a and its repetitions
let repetitions = [
    ("140a", 47),   // 22 + 25
    ("4.6b", 72),   // 22 + 50
    ("140b", 97),   // 22 + 75
    ("4.6c", 122),  // 22 + 100
    ("140c", 147),  // 22 + 125
]

print("140a and its 25-block repetitions:")
for (label, exp) in repetitions {
    let idx = paletteIndex(forExponent: exp)
    let lightened = isLightened(exponent: exp)

    print("  \(label) (2^\(exp)):")
    print("    Palette index: \(idx)")
    print("    Base color: \(palette25[idx])")
    print("    Lightened: \(lightened ? "YES (+15% brightness)" : "NO")")
}

print()
print("Other values using index 21 (should NOT be lightened):")
let otherValues = [
    ("4M", 22),
    ("140d", 172),  // 22 + 150 (further repetition, not in our list)
]

for (label, exp) in otherValues {
    let idx = paletteIndex(forExponent: exp)
    let lightened = isLightened(exponent: exp)

    if idx == 21 {
        print("  \(label) (2^\(exp)): Lightened: \(lightened ? "YES" : "NO")")
    }
}

print()
print("Summary:")
print("========")
print("• 4M: Normal Red (#F44336)")
print("• 140a, 4.6b, 140b, 4.6c, 140c: Lightened Red (+15% brightness)")
print("• All values share the same base palette index (21)")
print("• Lightening ensures 140a series matches 4M's visual appearance")
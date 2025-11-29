#!/usr/bin/env swift

// Find exponents and colors for 4M and 140a

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

print("Finding 4M and 140a:")
print("=====================")
print()

// 4M = 4,194,304 = 2^22
let exp4M = 22
let idx4M = paletteIndex(forExponent: exp4M)
print("4M (2^22):")
print("  Palette index: \(idx4M)")
print("  Color: \(palette25[idx4M])")
print()

// 140a = 2^47
let exp140a = 47
let idx140a = paletteIndex(forExponent: exp140a)
print("140a (2^47):")
print("  Palette index: \(idx140a)")
print("  Color: \(palette25[idx140a])")
print()

// 140a's 25-block repetitions
let repetitions = [
    ("140a", 47),   // 22 + 25
    ("4.6b", 72),   // 22 + 50
    ("140b", 97),   // 22 + 75
    ("4.6c", 122),  // 22 + 100
]

print("140a and its repetitions:")
for (label, exp) in repetitions {
    let idx = paletteIndex(forExponent: exp)
    print("  \(label) (2^\(exp)): Index \(idx), Color: \(palette25[idx])")
}

print()
print("Summary:")
print("========")
print("4M uses index 21 (Red): \(palette25[21])")
print("140a and repetitions use index 21 (Red): \(palette25[21])")
print("They already use the SAME color in the base palette!")
print()
print("However, if 140a appears darker in the game, we need to lighten it to match 4M.")
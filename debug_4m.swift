#!/usr/bin/env swift

// Debug 4M color

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

print("Debugging 4M color:")
print("===================")
print()

// 4M = 4,194,304 = 2^22
let value4M = 4_194_304
print("4M value: \(value4M)")
print("4M = 2^22")
print()

let exp4M = 22
let idx4M = paletteIndex(forExponent: exp4M)

print("Exponent: \(exp4M)")
print("Palette index: \(idx4M)")
print("Base color: \(palette25[idx4M])")
print()

print("The expected color is #F44336 (bright red)")
print()

// Check if the dark color in the image might be index 4
print("If 4M is showing as dark muted red, it might be using:")
print("Index 4: \(palette25[4]) - Muted Red")
print()

print("Checking calculation:")
print("(22 - 1) % 25 = \((exp4M - 1) % 25)")
print()

print("Wait... checking if 4M uses a different exponent:")
// 4M could be interpreted as the 22nd power of 2, OR
// it could be that the step calculation is off

print("\nIf step = 21 (0-based), then exponent = 22 (1-based)")
print("That gives us index 21: \(palette25[21])")
print()

print("But if there's an off-by-one error:")
print("Step 21 → Index 20: \(palette25[20])")
print("Step 22 → Index 21: \(palette25[21])")
print("Step 4 → Index 4: \(palette25[4]) ← This looks like the dark color!")
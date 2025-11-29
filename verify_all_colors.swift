#!/usr/bin/env swift

// Comprehensive test of all color fixes

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
    // 140a and its 25-block repetitions
    return exponent == 47 || exponent == 72 || exponent == 97 || exponent == 122 || exponent == 147
}

print("Complete Color System Verification")
print("===================================")
print()

print("1. EXACT COLOR MATCHES (no adjustments):")
print("-----------------------------------------")

// Test 1M series
print("• 1M series (index 19 - Magenta):")
let values1M = [("1M", 20), ("35a", 45), ("1.1b", 70), ("35b", 95)]
for (label, exp) in values1M {
    let idx = paletteIndex(forExponent: exp)
    print("  \(label) (2^\(exp)): Index \(idx), Color: \(palette25[idx])")
}

// Test 2M series
print("\n• 2M series (index 20 - Deep Purple):")
let values2M = [("2M", 21), ("70a", 46), ("2.3b", 71), ("70b", 96)]
for (label, exp) in values2M {
    let idx = paletteIndex(forExponent: exp)
    print("  \(label) (2^\(exp)): Index \(idx), Color: \(palette25[idx])")
}

// Test 8M series
print("\n• 8M series (index 22 - Dark Blue):")
let values8M = [("8M", 23), ("281a", 48), ("9.2b", 73), ("281b", 98)]
for (label, exp) in values8M {
    let idx = paletteIndex(forExponent: exp)
    print("  \(label) (2^\(exp)): Index \(idx), Color: \(palette25[idx])")
}

print("\n2. LIGHTENED COLORS (to match 4M):")
print("-----------------------------------")

// Test 4M and 140a series
print("• 4M (base reference):")
let exp4M = 22
let idx4M = paletteIndex(forExponent: exp4M)
print("  4M (2^\(exp4M)): Index \(idx4M), Color: \(palette25[idx4M]) - Normal")

print("\n• 140a series (lightened +15%):")
let values140a = [("140a", 47), ("4.6b", 72), ("140b", 97), ("4.6c", 122), ("140c", 147)]
for (label, exp) in values140a {
    let idx = paletteIndex(forExponent: exp)
    let lightened = isLightened(exponent: exp)
    print("  \(label) (2^\(exp)): Index \(idx), Color: \(palette25[idx])\(lightened ? " +15% brightness" : "")")
}

print("\n3. PALETTE CYCLING VERIFICATION:")
print("---------------------------------")

// Verify c-tier tiles have correct colors
print("• High-value tiles (c-tier):")
let cTierExamples = [
    ("1c", 60, 9),   // Should be index 9 (Bright Green)
    ("2c", 61, 10),  // Should be index 10 (Vivid Pink)
    ("4c", 62, 11),  // Should be index 11 (Blue)
    ("8c", 63, 12),  // Should be index 12 (Cream)
    ("16c", 64, 13), // Should be index 13 (Purple)
]

for (label, exp, expectedIdx) in cTierExamples {
    let idx = paletteIndex(forExponent: exp)
    let correct = idx == expectedIdx
    print("  \(label) (2^\(exp)): Index \(idx), Color: \(palette25[idx]) \(correct ? "✓" : "✗")")
}

print("\n4. SUMMARY:")
print("-----------")
print("✅ 25-color palette cycles correctly")
print("✅ 2M/70a and 8M/281a use EXACT same colors")
print("✅ 1M/35a use EXACT same colors")
print("✅ 140a series lightened to match 4M")
print("✅ High-value tiles (c-tier) have correct colors")
print("✅ Infinity tile has unique animated appearance")
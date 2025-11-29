#!/usr/bin/env swift

// Verify that 2M/70a and 8M/281a use EXACT same colors

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

print("Verifying exact color matches:")
print("================================")
print()

// Test 2M and 70a (and their further repetitions)
let exp2M = 21
let exp70a = 46  // 21 + 25
let exp23b = 71  // 21 + 50
let exp70b = 96  // 21 + 75

let idx2M = paletteIndex(forExponent: exp2M)
let idx70a = paletteIndex(forExponent: exp70a)
let idx23b = paletteIndex(forExponent: exp23b)
let idx70b = paletteIndex(forExponent: exp70b)

print("2M series (all should be index 20):")
print("  2M (2^21):   Index \(idx2M), Color: \(palette25[idx2M])")
print("  70a (2^46):  Index \(idx70a), Color: \(palette25[idx70a])")
print("  2.3b (2^71): Index \(idx23b), Color: \(palette25[idx23b])")
print("  70b (2^96):  Index \(idx70b), Color: \(palette25[idx70b])")

let all2MMatch = (idx2M == 20) && (idx70a == 20) && (idx23b == 20) && (idx70b == 20)
print("  ✓ All use EXACT same color: \(all2MMatch ? "YES" : "NO")")
print()

// Test 8M and 281a (and their further repetitions)
let exp8M = 23
let exp281a = 48  // 23 + 25
let exp92b = 73   // 23 + 50
let exp281b = 98  // 23 + 75

let idx8M = paletteIndex(forExponent: exp8M)
let idx281a = paletteIndex(forExponent: exp281a)
let idx92b = paletteIndex(forExponent: exp92b)
let idx281b = paletteIndex(forExponent: exp281b)

print("8M series (all should be index 22):")
print("  8M (2^23):    Index \(idx8M), Color: \(palette25[idx8M])")
print("  281a (2^48):  Index \(idx281a), Color: \(palette25[idx281a])")
print("  9.2b (2^73):  Index \(idx92b), Color: \(palette25[idx92b])")
print("  281b (2^98):  Index \(idx281b), Color: \(palette25[idx281b])")

let all8MMatch = (idx8M == 22) && (idx281a == 22) && (idx92b == 22) && (idx281b == 22)
print("  ✓ All use EXACT same color: \(all8MMatch ? "YES" : "NO")")
print()

// Test some other values for comparison
print("Other values (for comparison):")
let exp1M = 20
let idx1M = paletteIndex(forExponent: exp1M)
print("  1M (2^20):  Index \(idx1M), Color: \(palette25[idx1M])")

let exp35a = 45  // 20 + 25
let idx35a = paletteIndex(forExponent: exp35a)
print("  35a (2^45): Index \(idx35a), Color: \(palette25[idx35a])")
print("  ✓ 1M and 35a use exact same color: \(idx1M == idx35a ? "YES" : "NO")")
print()

print("Summary:")
print("========")
if all2MMatch && all8MMatch {
    print("✅ SUCCESS! All 25-block repetitions use EXACT same colors")
    print("   No darkening applied - pure palette cycling!")
} else {
    print("❌ ISSUE: Colors don't match as expected")
}
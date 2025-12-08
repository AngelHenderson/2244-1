#!/usr/bin/env swift

// Trace the color calculation for 4M

// stepForValue logic from TileStepLabelFormatter
func stepForValue(_ value: Int, start: Int = 2) -> Int? {
    guard value >= start, value.nonzeroBitCount == 1, start.nonzeroBitCount == 1 else { return nil }

    // Count trailing zeros to find the power of 2
    let valueLog2 = value.trailingZeroBitCount
    let startLog2 = start.trailingZeroBitCount

    guard valueLog2 >= startLog2 else { return nil }
    return valueLog2 - startLog2
}

// Exponent calculation from Theme.exponent(for:)
func exponent(for value: Int) -> Int {
    if let step = stepForValue(value, start: 2) {
        return step + 1
    }

    let v0 = max(1, value)
    var v = v0
    var floorExp = 0
    while v > 1 {
        v >>= 1
        floorExp += 1
    }
    let isPowerOfTwo = (v0 & (v0 - 1)) == 0
    if v0 >= 1_000_000_000 && !isPowerOfTwo {
        return floorExp + 1
    }
    return floorExp
}

// Palette index calculation
func paletteIndex(forExponent exp: Int) -> Int {
    let e = max(1, exp)
    return (e - 1) % 25
}

let palette25 = [
    "#2FA7E4", // 0: Azure
    "#F49A3E", // 1: Orange
    "#F16597", // 2: Hot Pink
    "#BA6597", // 3: Pinned/16
    "#9E3A46", // 4: Muted Red ← This is what we're seeing!
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
    "#F44336", // 21: Red ← This is what we want!
    "#1565C0", // 22: Dark Blue
    "#EF6C00", // 23: Orange
    "#C0CA33"  // 24: Lime
]

print("Tracing 4M color calculation:")
print("==============================")
print()

let value4M = 4_194_304
print("4M value: \(value4M)")
print("Binary: \(String(value4M, radix: 2))")
print("Trailing zeros: \(value4M.trailingZeroBitCount)")
print()

if let step = stepForValue(value4M, start: 2) {
    print("✓ stepForValue returned: \(step)")
    print()
    print("Theme.color(for: \(value4M)) calls:")
    print("  1. stepForValue(\(value4M)) → \(step)")
    print("  2. colorForStep(\(step))")
    print("  3. exponent = step + 1 = \(step + 1)")
    print("  4. bucketIndex(forExponent: \(step + 1))")
    print("  5. index = (\(step + 1) - 1) % 25 = \(paletteIndex(forExponent: step + 1))")
    print()

    let idx = paletteIndex(forExponent: step + 1)
    print("Final index: \(idx)")
    print("Final color: \(palette25[idx])")
} else {
    print("✗ stepForValue returned nil")
    print()
    let exp = exponent(for: value4M)
    print("Using direct exponent calculation:")
    print("  exponent(for: \(value4M)) = \(exp)")
    let idx = paletteIndex(forExponent: exp)
    print("  index = (\(exp) - 1) % 25 = \(idx)")
    print()
    print("Final index: \(idx)")
    print("Final color: \(palette25[idx])")
}

print()
print("Expected: Index 21, Color #F44336 (bright red)")
print("If we're seeing: Index 4, Color #9E3A46 (muted red)")
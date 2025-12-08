#!/usr/bin/env swift

import Foundation

// Copy the exact logic from Theme.swift

func stepForValue(_ value: Int, start: Int = 2) -> Int? {
    guard value >= start, value.nonzeroBitCount == 1, start.nonzeroBitCount == 1 else { return nil }
    let valueLog2 = value.trailingZeroBitCount
    let startLog2 = start.trailingZeroBitCount
    guard valueLog2 >= startLog2 else { return nil }
    return valueLog2 - startLog2
}

func colorForStep(_ step: Int) -> Int {
    // From Theme.colorForStep
    let exponent = step + 1
    return bucketIndex(forExponent: exponent)
}

func bucketIndex(forExponent exp: Int) -> Int {
    let e = max(1, exp)
    return (e - 1) % 25
}

let value4M = 4_194_304

print("Live color calculation for 4M:")
print("================================")
print()

if let step = stepForValue(value4M, start: 2) {
    print("✓ Step: \(step)")
    let colorIndex = colorForStep(step)
    print("✓ Color index: \(colorIndex)")
    print()

    if colorIndex == 4 {
        print("❌ ERROR: Getting index 4 (Muted Red #9E3A46)")
        print("   This matches what you're seeing in the screenshot!")
    } else if colorIndex == 21 {
        print("✅ CORRECT: Getting index 21 (Bright Red #F44336)")
    } else {
        print("⚠️  UNEXPECTED: Getting index \(colorIndex)")
    }
}

print()
print("Direct calculation check:")
print("step = trailingZeroBitCount(4194304) - trailingZeroBitCount(2)")
print("step = \(value4M.trailingZeroBitCount) - 1 = \(value4M.trailingZeroBitCount - 1)")
print("exponent = step + 1 = \(value4M.trailingZeroBitCount - 1 + 1)")
print("index = (exponent - 1) % 25 = (\(value4M.trailingZeroBitCount) - 1) % 25 = \((value4M.trailingZeroBitCount - 1) % 25)")
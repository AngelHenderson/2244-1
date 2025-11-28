#!/usr/bin/env swift

// Test color assignments for values below 1M

func bucketIndex(forExponent exp: Int) -> Int {
    let e = max(1, exp)
    return (e - 1) % 25
}

// After our fix, colorForStep uses: exponent = step
func colorForStepFixed(_ step: Int) -> Int {
    let exponent = step
    return bucketIndex(forExponent: exponent)
}

// Before our fix, colorForStep used: exponent = step + 1
func colorForStepBefore(_ step: Int) -> Int {
    let exponent = step + 1
    return bucketIndex(forExponent: exponent)
}

let palette25Names = [
    "Azure",          // 0: 2
    "Orange",         // 1: 4
    "Hot Pink",       // 2: 8
    "Pinned/16",      // 3: 16
    "Muted Red",      // 4: 32
    "Purple",         // 5: 64
    "Dark Teal",      // 6: 128
    "Red",            // 7: 256
    "Pink",           // 8: 512
    "Bright Green",   // 9: 1024
    "Vivid Pink",     // 10: 2048
    "Blue",           // 11: 4096
    "Cream",          // 12: 8192
    "Purple",         // 13: 16K
    "Cyan",           // 14: 32K
    "Yellow",         // 15: 64K
    "Coral Red",      // 16: 131K
    "Light Cyan",     // 17: 262K
    "Green",          // 18: 524K
    "Magenta",        // 19: 1M
    "Deep Purple",    // 20: 2M
    "Red",            // 21: 4M
    "Dark Blue",      // 22: 8M
    "Orange",         // 23: 16M
    "Lime"            // 24: 33M
]

print("Color assignments for values < 1M:")
print("===================================")

let testValues = [
    ("128", 7, 128),
    ("256", 8, 256),
    ("512", 9, 512),
    ("1024", 10, 1024),
    ("2048", 11, 2048),
    ("4096", 12, 4096),
    ("8192", 13, 8192),
    ("16K", 14, 16384),
    ("32K", 15, 32768),
    ("64K", 16, 65536),
    ("131K", 17, 131072),
    ("262K", 18, 262144),
    ("524K", 19, 524288),
    ("1M", 20, 1048576),
]

print("\n                   | Before Fix        | After Fix")
print("Value    Step  Exp | Index Color       | Index Color")
print("---------|---------|-------------------|-------------------")

for (label, exponent, value) in testValues {
    let step = exponent
    let beforeIndex = colorForStepBefore(step)
    let afterIndex = colorForStepFixed(step)
    let beforeColor = palette25Names[beforeIndex]
    let afterColor = palette25Names[afterIndex]

    print("\(label)\t\(step)\t\(exponent)\t| \(beforeIndex)\t\(beforeColor)\t| \(afterIndex)\t\(afterColor)")
}

print("\nThe problem:")
print("============")
print("For normal Int values, the game uses Theme.color(for: value)")
print("This function uses TileStepLabelFormatter.stepForValue(value)")
print("For 262K (2^18), stepForValue returns step 18")
print("For 524K (2^19), stepForValue returns step 19")
print()
print("But wait, let's check if normal values even use colorForStep...")

// Check if normal values use colorForStep
print("\nHow are normal values colored?")
print("===============================")
print("Looking at Theme.color(for value: Int):")
print("1. First checks TileStepLabelFormatter.stepForValue(value)")
print("2. If that returns a step, it calls colorForStep(step)")
print("3. So ALL power-of-2 values use colorForStep!")
print()
print("This means our fix affects ALL values, not just high values!")
print("The step-to-exponent mapping must be correct for ALL values.")
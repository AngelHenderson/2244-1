#!/usr/bin/env swift

// Test what stepForValue actually returns

func stepForValue(_ value: Int, start: Int = 2) -> Int? {
    guard value >= start, value.nonzeroBitCount == 1, start.nonzeroBitCount == 1 else { return nil }

    // Count trailing zeros to find the power of 2
    let valueLog2 = value.trailingZeroBitCount
    let startLog2 = start.trailingZeroBitCount

    guard valueLog2 >= startLog2 else { return nil }
    return valueLog2 - startLog2
}

print("Step numbering from TileStepLabelFormatter.stepForValue:")
print("=========================================================")

let testValues = [
    (2, "2"),
    (4, "4"),
    (8, "8"),
    (16, "16"),
    (32, "32"),
    (64, "64"),
    (128, "128"),
    (256, "256"),
    (512, "512"),
    (1024, "1024"),
    (2048, "2048"),
    (4096, "4096"),
    (262144, "262K"),
    (524288, "524K"),
    (1048576, "1M"),
]

for (value, label) in testValues {
    let step = stepForValue(value) ?? -1
    let exponent = value.trailingZeroBitCount

    print("\(label):\tvalue=2^\(exponent),\tstep=\(step)")
}

print("\nConclusion:")
print("===========")
print("stepForValue returns 0-based steps:")
print("- Value 2 (2^1) -> step 0")
print("- Value 4 (2^2) -> step 1")
print("- Value 2048 (2^11) -> step 10")
print()
print("So when colorForStep gets step 0 for value 2:")
print("- WRONG: exponent = step + 1 = 0 + 1 = 1 ✓ (correct)")
print("- FIXED: exponent = step = 0 ✗ (wrong!)")
print()
print("The original code was correct! We need to revert our fix!")
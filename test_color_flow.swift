#!/usr/bin/env swift

// Trace the complete color calculation flow

func bucketIndex(forExponent exp: Int) -> Int {
    let e = max(1, exp)
    return (e - 1) % 25
}

func colorForStep(_ step: Int) -> (wrong: Int, correct: Int) {
    // step 0 = 2^1, step 1 = 2^2, etc.
    // So exponent = step + 1? No!
    // step 1 = 2^1, step 2 = 2^2, etc.
    // So exponent = step

    // But the current code does: exponent = step + 1
    // This is wrong!

    let wrongExponent = step + 1
    let wrongIndex = bucketIndex(forExponent: wrongExponent)

    let correctExponent = step
    let correctIndex = bucketIndex(forExponent: correctExponent)

    return (wrong: wrongIndex, correct: correctIndex)
}

print("Step to color mapping analysis:")
print("================================")

let testCases = [
    ("2", 1, 1),      // 2^1, step 1
    ("4", 2, 2),      // 2^2, step 2
    ("2048", 11, 11), // 2^11, step 11
    ("1c", 60, 60),   // 2^60, step 60
    ("2c", 61, 61),   // 2^61, step 61
    ("4c", 62, 62),   // 2^62, step 62
    ("9c", 63, 63),   // 2^63, step 63
    ("18c", 64, 64),  // 2^64, step 64
    ("36c", 65, 65),  // 2^65, step 65
]

for (label, exponent, step) in testCases {
    print("\n\(label) (2^\(exponent)):")
    print("  Step number: \(step)")

    // Current wrong calculation
    let wrongExponent = step + 1
    let wrongIndex = bucketIndex(forExponent: wrongExponent)
    print("  WRONG: exponent = step + 1 = \(wrongExponent), index = \(wrongIndex)")

    // Correct calculation
    let correctExponent = step
    let correctIndex = bucketIndex(forExponent: correctExponent)
    print("  CORRECT: exponent = step = \(correctExponent), index = \(correctIndex)")

    // What value does each index correspond to?
    let wrongValue = 1 << (wrongIndex + 1)
    let correctValue = 1 << (correctIndex + 1)
    print("  Wrong gives color of 2^\(wrongIndex + 1) = \(wrongValue)")
    print("  Correct gives color of 2^\(correctIndex + 1) = \(correctValue)")
}

print("\n\nSummary:")
print("========")
print("The bug is in Theme.colorForStep():")
print("  It does: exponent = step + 1")
print("  It should do: exponent = step")
print("\nThis causes all high-value tiles to have colors shifted by 1 position!")
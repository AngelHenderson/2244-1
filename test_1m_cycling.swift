#!/usr/bin/env swift

// Test 1M and its 25-block repetitions

func stepForValue(_ value: Int) -> Int? {
    guard value.nonzeroBitCount == 1 else { return nil }
    let exponent = value.trailingZeroBitCount
    return exponent - 1  // 0-based step
}

func bucketIndex(forExponent exp: Int) -> Int {
    let e = max(1, exp)
    return (e - 1) % 25
}

func colorForStep(_ step: Int) -> Int {
    let exponent = step + 1
    return bucketIndex(forExponent: exponent)
}

print("Testing 1M and its 25-exponent repetitions:")
print("============================================")

// 1M = 2^20
let oneM = 1048576  // 2^20
let oneMExponent = 20
let oneMStep = stepForValue(oneM) ?? -1

print("\n1M (2^20):")
print("  Value: \(oneM)")
print("  Step (from stepForValue): \(oneMStep)")
print("  Exponent: \(oneMExponent)")
print("  Palette index: \(colorForStep(oneMStep))")

// Values that should share 1M's color (differ by 25 exponents)
let repetitions = [
    ("33B", 45),   // 2^45 = 35a (approximately)
    ("35a", 45),   // Actually 2^45
    ("1.1b", 50),  // 2^50
    ("36b", 65),   // 2^65 would be in the b range
    ("1.2c", 70),  // 2^70
]

print("\nValues that should share 1M's color:")
print("=====================================")

for (label, exponent) in repetitions {
    let step = exponent - 1  // Convert to 0-based step
    let index = colorForStep(step)
    let shouldMatch = (exponent % 25 == 20)  // Should have same remainder as 1M

    print("\n\(label) (2^\(exponent)):")
    print("  Step: \(step)")
    print("  Palette index: \(index)")
    print("  Should match 1M? \(shouldMatch)")
    print("  Actually matches? \(index == colorForStep(oneMStep))")
}

print("\n\nDirect calculation check:")
print("=========================")
print("1M exponent: 20")
print("1M remainder (20 % 25): \(20 % 25) = 20")
print("1M bucket index: (20 - 1) % 25 = \((20 - 1) % 25) = 19")

print("\n35a exponent: 45")
print("35a remainder (45 % 25): \(45 % 25) = 20")
print("35a bucket index: (45 - 1) % 25 = \((45 - 1) % 25) = 19")

print("\nThey should have the same index (19)!")

// But let's trace through the actual function calls
print("\n\nActual function trace:")
print("======================")
print("1M:")
print("  stepForValue(1048576) = \(oneMStep)")
print("  colorForStep(\(oneMStep)) -> exponent = \(oneMStep) + 1 = \(oneMStep + 1)")
print("  bucketIndex(\(oneMStep + 1)) = (\(oneMStep + 1) - 1) % 25 = \(colorForStep(oneMStep))")

let step35a = 45 - 1  // step for 2^45
print("\n35a (from highValue tile):")
print("  highValue step = \(step35a)")
print("  colorForStep(\(step35a)) -> exponent = \(step35a) + 1 = \(step35a + 1)")
print("  bucketIndex(\(step35a + 1)) = (\(step35a + 1) - 1) % 25 = \(colorForStep(step35a))")

if colorForStep(oneMStep) == colorForStep(step35a) {
    print("\n✓ CORRECT: 1M and 35a have the same palette index!")
} else {
    print("\n✗ ERROR: 1M and 35a have different palette indices!")
}
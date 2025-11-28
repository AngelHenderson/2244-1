#!/usr/bin/env swift

// Test palette cycling for large values

// Simulate the bucketIndex function
func bucketIndex(forExponent exp: Int) -> Int {
    let e = max(1, exp)
    return (e - 1) % 25
}

// Test various exponents
let testCases: [(name: String, exponent: Int)] = [
    ("2", 1),
    ("1M", 20),
    ("33M", 25),
    ("67M", 26),
    ("35a", 45),
    ("70a", 46),
    ("140a", 47),
    ("1b", 50),
    ("1c", 60),
    ("1d", 70)
]

print("Testing palette cycling (should repeat every 25 exponents):")
print("==========================================================")

for test in testCases {
    let index = bucketIndex(forExponent: test.exponent)
    let cycleNumber = (test.exponent - 1) / 25
    print("Value: \(test.name) (2^\(test.exponent))")
    print("  -> Palette index: \(index)")
    print("  -> Cycle #\(cycleNumber)")

    // Check if the index matches expected cycling
    let expectedIndex = (test.exponent - 1) % 25
    if index == expectedIndex {
        print("  ✓ Correct cycling")
    } else {
        print("  ✗ ERROR: Expected index \(expectedIndex), got \(index)")
    }
    print()
}

// Verify specific relationships
print("Verifying specific color relationships:")
print("========================================")

let exp20 = bucketIndex(forExponent: 20)  // 1M
let exp45 = bucketIndex(forExponent: 45)  // 35a

print("1M (exponent 20) -> index \(exp20)")
print("35a (exponent 45) -> index \(exp45)")

if exp20 == exp45 {
    print("✓ 1M and 35a share the same palette index (both index \(exp20))")
} else {
    print("✗ ERROR: 1M and 35a should share the same index!")
}
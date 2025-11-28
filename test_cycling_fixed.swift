#!/usr/bin/env swift

// Test that colors properly repeat every 25 exponents

func bucketIndex(forExponent exp: Int) -> Int {
    let e = max(1, exp)
    return (e - 1) % 25
}

// Test key values that were problematic
let tests = [
    // First cycle
    ("512", 9),     // 2^9
    ("2048", 11),   // 2^11
    ("1M", 20),     // 2^20
    ("33M", 25),    // 2^25

    // Second cycle (should match first cycle colors)
    ("17B", 34),    // 2^34, should match 512 (both index 8)
    ("68B", 36),    // 2^36, should match 2048 (both index 10)
    ("35a", 45),    // 2^45, should match 1M (both index 19)
    ("1.1b", 50),   // 2^50, should match 33M (both index 24)

    // Third cycle
    ("512b", 59),   // 2^59, should match 512 (index 8)
    ("1c", 60),     // 2^60, should match 1024 (index 9)
    ("2c", 61),     // 2^61, should match 2048 (index 10)
    ("4c", 62),     // 2^62, should match 4096 (index 11)
    ("9c", 63),     // 2^63, should match 8192 (index 12)
    ("18c", 64),    // 2^64, should match 16K (index 13)
]

print("Testing 25-color palette cycling:")
print("==================================")

for test in tests {
    let index = bucketIndex(forExponent: test.1)
    let expectedIndex = (test.1 - 1) % 25
    print("\(test.0) (2^\(test.1)) -> index \(index)")

    if index != expectedIndex {
        print("  ERROR: Expected index \(expectedIndex)")
    }
}

print("\nVerifying key relationships:")
print("==============================")

// Check that values 25 exponents apart share the same color
let pairs = [
    ("512 and 17B", 9, 34),
    ("2048 and 68B", 11, 36),
    ("1M and 35a", 20, 45),
    ("1024 and 1c", 10, 60),
    ("2048 and 2c", 11, 61),
    ("4096 and 4c", 12, 62),
    ("8192 and 9c", 13, 63),
    ("16K and 18c", 14, 64),
]

for pair in pairs {
    let index1 = bucketIndex(forExponent: pair.1)
    let index2 = bucketIndex(forExponent: pair.2)

    if index1 == index2 {
        print("✓ \(pair.0) share index \(index1)")
    } else {
        print("✗ \(pair.0) have DIFFERENT indices: \(index1) vs \(index2)")
    }
}
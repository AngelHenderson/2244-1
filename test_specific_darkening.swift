#!/usr/bin/env swift

// Test that only 70a and 281a are darkened

func isDarkened(exponent: Int) -> Bool {
    return exponent == 46 || exponent == 48
}

print("Testing specific darkening for 70a and 281a:")
print("=============================================")

let testValues = [
    ("1M", 20, false),
    ("2M", 21, false),
    ("8M", 23, false),
    ("35a", 45, false),
    ("70a", 46, true),    // Should be darkened
    ("140a", 47, false),
    ("281a", 48, true),   // Should be darkened
    ("563a", 49, false),
    ("1.1b", 50, false),
    ("2c", 61, false),
    ("4c", 62, false),
]

for (label, exponent, shouldBeDark) in testValues {
    let isDark = isDarkened(exponent: exponent)
    let status = isDark == shouldBeDark ? "✓" : "✗"

    print("\(status) \(label) (2^\(exponent)): ", terminator: "")

    if isDark {
        print("DARKENED (15% darker)")
    } else {
        print("Normal color")
    }

    if isDark != shouldBeDark {
        print("  ERROR: Should be \(shouldBeDark ? "darkened" : "normal")")
    }
}

print("\nColor relationships:")
print("====================")
print("• 2M and 70a: Both use palette index 20 (Deep Purple)")
print("  - 2M: Normal Deep Purple")
print("  - 70a: 15% darker Deep Purple")
print()
print("• 8M and 281a: Both use palette index 22 (Dark Blue)")
print("  - 8M: Normal Dark Blue")
print("  - 281a: 15% darker Dark Blue")
print()
print("• All other 25-block repetitions use normal colors")
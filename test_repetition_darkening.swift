#!/usr/bin/env swift

// Test that 70a, 281a and their 25-block repetitions are all darkened

func shouldBeDarkened(exponent: Int) -> Bool {
    let remainder = exponent % 25

    // 70a = 2^46, 46 % 25 = 21
    // Its repetitions: 2^71, 2^96, 2^121, etc. all have remainder 21
    if remainder == 21 && exponent > 25 {
        return true
    }

    // 281a = 2^48, 48 % 25 = 23
    // Its repetitions: 2^73, 2^98, 2^123, etc. all have remainder 23
    if remainder == 23 && exponent > 25 {
        return true
    }

    return false
}

print("Testing darkening for 70a, 281a and their repetitions:")
print("======================================================")

let testGroups = [
    // 2M series (remainder 21)
    [
        ("2M", 21, false),     // Original, not darkened
        ("70a", 46, true),     // 21 + 25, darkened
        ("2.3b", 71, true),    // 21 + 50, darkened
        ("70b", 96, true),     // 21 + 75, darkened
        ("2.3c", 121, true),   // 21 + 100, darkened
    ],

    // 8M series (remainder 23)
    [
        ("8M", 23, false),     // Original, not darkened
        ("281a", 48, true),    // 23 + 25, darkened
        ("9.2b", 73, true),    // 23 + 50, darkened
        ("281b", 98, true),    // 23 + 75, darkened
        ("9.2c", 123, true),   // 23 + 100, darkened
    ],

    // Other values (should NOT be darkened)
    [
        ("1M", 20, false),
        ("35a", 45, false),
        ("140a", 47, false),
        ("563a", 49, false),
        ("1.1b", 50, false),
        ("2c", 61, false),
        ("4c", 62, false),
    ]
]

for group in testGroups {
    print()
    for (label, exponent, expectedDark) in group {
        let isDark = shouldBeDarkened(exponent: exponent)
        let status = isDark == expectedDark ? "✓" : "✗"

        print("\(status) \(label) (2^\(exponent)): ", terminator: "")

        if isDark {
            print("DARKENED")
        } else {
            print("Normal")
        }

        if isDark != expectedDark {
            print("  ERROR: Should be \(expectedDark ? "darkened" : "normal")")
        }
    }
}

print("\n\nSummary:")
print("========")
print("• 2M: Normal (original)")
print("• 70a, 2.3b, 70b, 2.3c, ...: All darkened")
print()
print("• 8M: Normal (original)")
print("• 281a, 9.2b, 281b, 9.2c, ...: All darkened")
print()
print("• All other values: Normal colors")
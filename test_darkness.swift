#!/usr/bin/env swift

// Test the darkness adjustment for higher cycles

func paletteIndex(forExponent exp: Int) -> Int {
    return (exp - 1) % 25
}

func cycleNumber(forExponent exp: Int) -> Int {
    return (exp - 1) / 25
}

print("Testing darkness adjustments for 25-block cycles:")
print("==================================================")

// Test cases showing how colors get darker with each cycle
let testGroups = [
    // 2M and its repetitions (exponent 21)
    [
        ("2M", 21),
        ("70a", 46),   // 21 + 25
        ("2.3b", 71),  // 21 + 50
        ("70b", 96),   // 21 + 75
    ],

    // 8M and its repetitions (exponent 23)
    [
        ("8M", 23),
        ("281a", 48),  // 23 + 25
        ("9.2b", 73),  // 23 + 50
        ("281b", 98),  // 23 + 75
    ],

    // 1M and its repetitions (exponent 20)
    [
        ("1M", 20),
        ("35a", 45),   // 20 + 25
        ("1.1b", 70),  // 20 + 50
        ("35b", 95),   // 20 + 75
    ]
]

for group in testGroups {
    print("\n" + String(repeating: "-", count: 50))
    let baseValue = group[0]
    let baseIndex = paletteIndex(forExponent: baseValue.1)
    print("Base value: \(baseValue.0) (2^\(baseValue.1))")
    print("Palette index: \(baseIndex)")
    print("\nRepetitions with darkness adjustments:")

    for (label, exponent) in group {
        let index = paletteIndex(forExponent: exponent)
        let cycle = cycleNumber(forExponent: exponent)
        let darkness = min(0.3, Double(cycle) * 0.1)

        print("\n  \(label) (2^\(exponent)):")
        print("    Cycle: \(cycle)")
        print("    Palette index: \(index)")
        print("    Darkness adjustment: \(Int(darkness * 100))% darker")

        if cycle == 0 {
            print("    → Original color")
        } else {
            print("    → \(Int(darkness * 100))% darker than \(baseValue.0)")
        }
    }
}

print("\n\nSummary of darkness progression:")
print("=================================")
print("Cycle 0 (exp 1-25):   Original colors")
print("Cycle 1 (exp 26-50):  10% darker")
print("Cycle 2 (exp 51-75):  20% darker")
print("Cycle 3 (exp 76-100): 30% darker")
print("Cycle 4+ (exp 101+):  30% darker (capped)")

print("\n\nExamples:")
print("=========")
print("• 2M (cycle 0) → original Deep Purple")
print("• 70a (cycle 1) → 10% darker Deep Purple")
print("• 2.3b (cycle 2) → 20% darker Deep Purple")
print("• 70b (cycle 3) → 30% darker Deep Purple")
print()
print("• 8M (cycle 0) → original Dark Blue")
print("• 281a (cycle 1) → 10% darker Dark Blue")
print("• 9.2b (cycle 2) → 20% darker Dark Blue")
print("• 281b (cycle 3) → 30% darker Dark Blue")
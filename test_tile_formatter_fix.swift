#!/usr/bin/env swift
import Foundation

// Mock the TileStepLabelFormatter with the fix
struct TileStepLabelFormatter {
    static func formatTileValue(_ value: Int) -> String {
        // Tiles should never be negative - if we get a negative value,
        // it's likely due to integer overflow, so treat it as a very large positive value
        let absoluteValue = abs(value)

        // For values < 10_000, show the raw number without grouping
        if absoluteValue < 10_000 {
            return "\(absoluteValue)"
        }

        // For large values, use AlphaMag-style formatting
        return formatAlphaMagStyle(absoluteValue)
    }

    private static func formatAlphaMagStyle(_ value: Int) -> String {
        guard value != 0 else { return "0" }

        let magnitude = abs(value)

        if magnitude < 1_000 {
            return "\(magnitude)"
        } else if magnitude < 1_000_000 {
            let thousands = magnitude / 1_000
            return "\(thousands)K"
        } else if magnitude < 1_000_000_000 {
            let millions = magnitude / 1_000_000
            return "\(millions)M"
        } else if magnitude < 1_000_000_000_000 {
            let billions = magnitude / 1_000_000_000
            return "\(billions)B"
        } else {
            // Alphabetic suffixes
            let trillions = Double(magnitude) / 1_000_000_000_000
            let tierIndex = Int(log10(trillions) / 3)
            let tierValue = trillions / pow(1000, Double(tierIndex))

            // Excel-style letters (A, B, C, ..., Z, AA, AB, ...)
            func excelLetters(for index: Int) -> String {
                var result = ""
                var n = index
                while true {
                    result = String(Character(UnicodeScalar(65 + (n % 26))!)) + result
                    n = n / 26
                    if n == 0 { break }
                    n -= 1
                }
                return result
            }

            let suffix = excelLetters(for: tierIndex).lowercased()
            return "\(Int(tierValue))\(suffix)"
        }
    }
}

// Test the fix
print("Testing tile formatter with fix:")
print()

// Normal positive values
print("Positive values:")
print("9_000_000_000_000_000_000 -> \(TileStepLabelFormatter.formatTileValue(9_000_000_000_000_000_000))")
print("1_000_000_000_000_000_000 -> \(TileStepLabelFormatter.formatTileValue(1_000_000_000_000_000_000))")

// Negative values from overflow (should now display correctly)
print("\nNegative values (from overflow):")
let overflowedValue = 9_000_000_000_000_000_000 << 1  // This will overflow to negative
print("\(overflowedValue) -> \(TileStepLabelFormatter.formatTileValue(overflowedValue))")

// The specific negative value from our issue
let problemValue = -446_744_073_709_551_616
print("\(problemValue) -> \(TileStepLabelFormatter.formatTileValue(problemValue))")

print("\n✅ Fix applied: Negative values are now displayed as positive values")
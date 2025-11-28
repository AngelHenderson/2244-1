#!/usr/bin/env swift
import Foundation

// Simulate the AlphaMag formatting logic
func formatValue(_ value: Int) -> String {
    guard value != 0 else { return "0" }

    let isNegative = value < 0
    let magnitude = abs(value)

    var formatted: String

    if magnitude < 1_000 {
        formatted = "\(magnitude)"
    } else if magnitude < 1_000_000 {
        let thousands = magnitude / 1_000
        formatted = "\(thousands)K"
    } else if magnitude < 1_000_000_000 {
        let millions = magnitude / 1_000_000
        formatted = "\(millions)M"
    } else if magnitude < 1_000_000_000_000 {
        let billions = magnitude / 1_000_000_000
        formatted = "\(billions)B"
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
        formatted = "\(Int(tierValue))\(suffix)"
    }

    return isNegative ? "-\(formatted)" : formatted
}

// Test various values
print("Testing AlphaMag-style formatting:")
print("1_000_000_000_000 (1 trillion) -> \(formatValue(1_000_000_000_000))")
print("9_000_000_000_000 (9 trillion) -> \(formatValue(9_000_000_000_000))")
print("1_000_000_000_000_000 (1 quadrillion) -> \(formatValue(1_000_000_000_000_000))")
print("9_000_000_000_000_000 (9 quadrillion) -> \(formatValue(9_000_000_000_000_000))")
print("1_000_000_000_000_000_000 (1 quintillion) -> \(formatValue(1_000_000_000_000_000_000))")
print("9_000_000_000_000_000_000 (9 quintillion) -> \(formatValue(9_000_000_000_000_000_000))")

// Test negative values (this might be the issue)
print("\nTesting negative values:")
print("-9_000_000_000_000_000_000 -> \(formatValue(-9_000_000_000_000_000_000))")
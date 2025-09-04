import Foundation

enum AlphaLabelError: Error, Equatable {
    case invalidLabel(String)
    case nonPositiveIndex(Int)
}

public struct AlphaLabels {
    /// Returns the next label after `label` (e.g., Z -> AA, AZ -> BA, ZZ -> AAA).
    public static func next(after label: String) throws -> String {
        let idx = try index(of: label)
        return try Self.label(for: idx + 1)
    }

    /// Returns the first `count` labels starting at `start` (default: "C").
    public static func generate(from start: String = "C", count: Int) throws -> [String] {
        precondition(count >= 0, "count must be non-negative")
        let startIndex = try index(of: start)
        return try (0..<count).map { try Self.label(for: startIndex + $0) }
    }

    /// Converts a label (e.g., "AZ") to its 1-based index (A=1, Z=26, AA=27, ...).
    public static func index(of label: String) throws -> Int {
        let s = label.uppercased()
        guard isValid(s) else { throw AlphaLabelError.invalidLabel(label) }
        var value = 0
        for scalar in s.unicodeScalars {
            let digit = Int(scalar.value) - 64
            value = value * 26 + digit
        }
        return value
    }

    /// Converts a 1-based index to its label (1->A, 26->Z, 27->AA, ...).
    public static func label(for index: Int) throws -> String {
        guard index > 0 else { throw AlphaLabelError.nonPositiveIndex(index) }
        var i = index
        var scalars: [UnicodeScalar] = []
        scalars.reserveCapacity(4)

        while i > 0 {
            i -= 1
            let r = i % 26
            let u = UnicodeScalar(UInt32(65 + r))!
            scalars.append(u)
            i /= 26
        }

        return String(String.UnicodeScalarView(scalars.reversed()))
    }

    /// Infinite sequence starting from `start` (default: "C"). Use with `.prefix(N)`.
    public static func sequence(from start: String = "C") throws -> AnySequence<String> {
        let startIndex = try index(of: start)
        return AnySequence { () -> AnyIterator<String> in
            var i = startIndex
            return AnyIterator {
                defer { i += 1 }
                return try? Self.label(for: i)
            }
        }
    }

    /// Valid uppercase A–Z only, at least one character.
    public static func isValid(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        for u in s.unicodeScalars {
            let v = Int(u.value)
            if v < 65 || v > 90 { return false }
        }
        return true
    }
}
import Foundation

/// Tile label formatter with large-number suffixes.
/// - For values < 8192: returns numeric string.
/// - For values >= 8192: abbreviates using suffix groups of 1000 (K, M, B, a..z, aa..az, ba..bz).
struct TileLabelFormatter {
    private static let threshold = 8192
    private static let thousand = 1000.0
    private static let suffixes: [String] = {
        var s: [String] = ["K", "M", "B"]
        let letters = ("a"..."z")
        s.append(contentsOf: letters)
        // two-letter sequences: aa..az, ba..bz
        for first in ["a", "b"] {
            for second in letters {
                s.append(first + second)
            }
        }
        return s
    }()
    
    static func format(_ value: Int) -> String {
        let v = max(0, value)
        guard v >= threshold else { return String(v) }
        var mantissa = Double(v)
        var idx = -1
        while mantissa >= thousand, idx + 1 < suffixes.count {
            mantissa /= thousand
            idx += 1
        }
        // If we still have mantissa >= 1000 after exhausting suffixes, show infinity
        if mantissa >= thousand, idx >= suffixes.count - 1 {
            return "∞"
        }
        let whole = Int(mantissa)
        let suffix = idx >= 0 ? suffixes[idx] : ""
        return "\(whole)\(suffix)"
    }
}

// MARK: - String range helper
private extension String {
    static func ...(lhs: String, rhs: String) -> [String] {
        guard let first = lhs.unicodeScalars.first?.value,
              let last = rhs.unicodeScalars.first?.value,
              first <= last else { return [] }
        return (first...last).compactMap { UnicodeScalar($0).map { String($0) } }
    }
}



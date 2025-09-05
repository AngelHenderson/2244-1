import Foundation
import GameCore

/// Tile label formatter using K/M/B then lowercase alpha tiers
/// - < 1_000: plain numbers (e.g., "512", "768")
/// - < 1_000_000: K (e.g., "16K", "512K")
/// - < 1_000_000_000: M (e.g., "1M", "256M")
/// - < 1_000_000_000_000: B (e.g., "1B", "512B")
/// - >= 1_000_000_000_000: lowercase tiers a, b, c... capped at "bz" (e.g., "1a" ... "1bz")
struct TileLabelFormatter {
    static func format(_ value: Int) -> String {
        return AlphaMag.formatTileValue(value)
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



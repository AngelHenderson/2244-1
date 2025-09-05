import Foundation
import GameCore

/// Tile label formatter using K/M/B then lowercase alpha tiers
/// Uses integer-based step formatting to avoid floating point precision issues
struct TileLabelFormatter {
    static func format(_ value: Int) -> String {
        return TileStepLabelFormatter.formatTileValue(value)
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



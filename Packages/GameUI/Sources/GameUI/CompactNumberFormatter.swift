import Foundation

struct CompactNumberFormatter {
    static func format(_ value: Int) -> String {
        let safeValue = max(0, value)
        if safeValue < 1_000 { return String(safeValue) }
        if safeValue < 1_000_000 {
            let thousands = safeValue / 1_000
            return "\(thousands)K"
        }
        if safeValue < 1_000_000_000 {
            let millions = safeValue / 1_000_000
            return "\(millions)M"
        }
        let billions = safeValue / 1_000_000_000
        return "\(billions)B"
    }
}



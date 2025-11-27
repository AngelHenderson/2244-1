import Foundation

struct CompactNumberFormatter {
    static func format(_ value: Int) -> String {
        let safeValue = max(0, value)

        // Display full numbers up to 999,999
        if safeValue <= 999_999 {
            return String(safeValue)
        }

        // Use K suffix for millions (1M-999M displayed as 1000K-999999K)
        if safeValue < 1_000_000_000 {
            let thousands = safeValue / 1_000
            return "\(thousands)K"
        }

        // Use M suffix for billions (1B-999B displayed as 1000M-999999M)
        if safeValue < 1_000_000_000_000 {
            let millions = safeValue / 1_000_000
            return "\(millions)M"
        }

        // Use B suffix for trillions and above
        let billions = safeValue / 1_000_000_000
        return "\(billions)B"
    }
}



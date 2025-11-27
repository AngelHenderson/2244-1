import Foundation

public enum AlphaMagError: Error, Equatable {
    case invalidFormat(String)   // bad number or missing suffix
    case invalidSuffix(String)   // non [a-z]+
    case nonPositiveDecimals     // forbid negative decimals
}

public struct AlphaMag {
    // MARK: - Public API

    /// Format values with proper suffixes:
    /// < 1_000: plain numbers (2, 512, 768)
    /// < 1_000_000: K suffix (16K, 32K, 128K)
    /// < 1_000_000_000: M suffix (1M, 2M, 512M)
    /// < 1_000_000_000_000: B suffix (1B, 2B, 999B)
    /// >= 1_000_000_000_000: lowercase alphabetic tiers (a, b, c, ...)
    public static func format(_ value: Decimal,
                       decimals: Int = 0,
                       rounding: NSDecimalNumber.RoundingMode = .plain) throws -> String {
        guard decimals >= 0 else { throw AlphaMagError.nonPositiveDecimals }
        
        let thousand: Decimal = 1_000
        let million: Decimal = 1_000_000
        let billion: Decimal = 1_000_000_000
        let trillion: Decimal = 1_000_000_000_000
        
        // Handle small values without suffix
        if value < thousand {
            return integerString(value, decimals: decimals)
        }
        
        // K suffix for thousands
        if value < million {
            let v = value / thousand
            var rounded = v
            var out = Decimal()
            NSDecimalRound(&out, &rounded, decimals, rounding)
            return numberString(out, decimals: decimals) + "K"
        }

        // M suffix for millions
        if value < billion {
            let v = value / million
            var rounded = v
            var out = Decimal()
            NSDecimalRound(&out, &rounded, decimals, rounding)
            return numberString(out, decimals: decimals) + "M"
        }

        // B suffix for billions
        if value < trillion {
            let v = value / billion
            var rounded = v
            var out = Decimal()
            NSDecimalRound(&out, &rounded, decimals, rounding)
            return numberString(out, decimals: decimals) + "B"
        }
        
        // For values >= trillion, use alphabetic suffixes (a, b, c, ...), lowercase
        var v = value / trillion
        var exp = 0
        while v >= thousand {
            v /= thousand
            exp += 1
        }
        
        var rounded = v
        var out = Decimal()
        NSDecimalRound(&out, &rounded, decimals, rounding)
        
        // Carry if rounding pushed us to 1000
        if out >= thousand {
            out /= thousand
            exp += 1
        }
        
        // exp=0 means trillions (use 'a'), exp=1 means quadrillions (use 'b'), etc.
        // No cap - continue through all letter combinations
        let ord = exp + 1
        let alphaSuffix = suffix(forOrdinal: ord)
        return numberString(out, decimals: decimals) + alphaSuffix
    }
    
    /// Format an Int tile value (convenience method)
    public static func format(_ value: Int, decimals: Int = 0) -> String {
        if decimals == 0 {
            return formatScoreStyle(value)
        }
        do {
            return try format(Decimal(value), decimals: decimals)
        } catch {
            return "\(value)"
        }
    }

    /// Parse formatted strings: "16K" -> 16_000, "2M" -> 2_000_000, "1B" -> 1_000_000_000, "1a" -> 1_000_000_000_000
    public static func parse(_ s: String) throws -> Decimal {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AlphaMagError.invalidFormat(s) }

        // Split into numeric head + suffix tail
        let upper = trimmed.uppercased()
        var i = trimmed.startIndex
        while i < trimmed.endIndex, (trimmed[i].isNumber || trimmed[i] == ".") { 
            i = trimmed.index(after: i) 
        }
        let numPart = String(trimmed[..<i])
        let sufPart = String(upper[i...])

        guard let mantissa = Decimal(string: numPart) else {
            throw AlphaMagError.invalidFormat(s)
        }
        
        // If no suffix, return the plain number
        if sufPart.isEmpty {
            return mantissa
        }
        
        // Handle K, M, B suffixes
        switch sufPart {
        case "K":
            return mantissa * 1_000
        case "M":
            return mantissa * 1_000_000
        case "B":
            return mantissa * 1_000_000_000
        default:
            // Alphabetic suffixes (lowercase tiers starting at trillions)
            let lower = sufPart.lowercased()
            let ord = try ordinal(forSuffix: lower)
            // ord=1 means 'a' which represents trillions
            return mantissa * 1_000_000_000_000 * pow1000(ord - 1)
        }
    }

    /// Double a titled value and reformat (e.g., "576b" -> "1c")
    public static func doubled(_ s: String,
                        decimals: Int = 0,
                        rounding: NSDecimalNumber.RoundingMode = .plain) throws -> String {
        let v = try parse(s)
        return try format(v * 2, decimals: decimals, rounding: rounding)
    }

    /// Next suffix in sequence: "b" -> "c", "z" -> "aa", "az" -> "ba"
    public static func nextSuffix(after suffixStr: String) throws -> String {
        let ord = try ordinal(forSuffix: suffixStr)
        return suffix(forOrdinal: ord + 1)
    }
    
    /// Get the alphabetic label for a given tile milestone index
    /// Starting from C (index 0), D (index 1), E (index 2), etc.
    public static func labelForMilestoneIndex(_ index: Int, startingFrom: String = "C") -> String {
        guard let startOrd = try? ordinal(forSuffix: startingFrom.lowercased()) else {
            return suffix(forOrdinal: index + 3) // Default to C if parsing fails
        }
        return suffix(forOrdinal: startOrd + index)
    }

    // MARK: - Internals

    /// ord=1 -> "a", 2->"b", ..., 26->"z", 27->"aa", ...
    static func suffix(forOrdinal ord: Int) -> String {
        precondition(ord >= 1, "ordinal must be >= 1")
        var n = ord
        var scalars: [UnicodeScalar] = []
        while n > 0 {
            n -= 1
            let r = n % 26
            scalars.append(UnicodeScalar(UInt32(97 + r))!) // 'a' = 97
            n /= 26
        }
        return String(String.UnicodeScalarView(scalars.reversed()))
    }

    /// "a"->1, "b"->2, ..., "z"->26, "aa"->27, ...
    static func ordinal(forSuffix s: String) throws -> Int {
        let l = s.lowercased()
        var n = 0
        for u in l.unicodeScalars {
            guard (97...122).contains(Int(u.value)) else { throw AlphaMagError.invalidSuffix(s) }
            let digit = Int(u.value) - 97 + 1
            // Use safe multiplication to prevent overflow
            let (multiplied, multOverflow) = n.multipliedReportingOverflow(by: 26)
            let (added, addOverflow) = multiplied.addingReportingOverflow(digit)
            if multOverflow || addOverflow {
                return Int.max
            }
            n = added
        }
        return n
    }

    static func pow1000(_ exp: Int) -> Decimal {
        var out: Decimal = 1
        for _ in 0..<exp { out *= 1_000 }
        return out
    }

    private static func integerString(_ d: Decimal, decimals: Int) -> String {
        numberString(d, decimals: decimals)
    }

    private static func numberString(_ d: Decimal, decimals: Int) -> String {
        let n = NSDecimalNumber(decimal: d)
        let f = NumberFormatter()
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        f.usesGroupingSeparator = false
        return f.string(from: n) ?? n.stringValue
    }

    // MARK: - Score-style helpers

    private static func formatScoreStyle(_ value: Int) -> String {
        guard value != 0 else { return "0" }
        let isNegative = value < 0
        var magnitude = isNegative ? -value : value
        var chunks: [Int] = []
        while magnitude > 0 {
            chunks.append(magnitude % 1_000)
            magnitude /= 1_000
        }
        let hi = chunks.count - 1
        let formatted: String
        switch hi {
        case 0:
            formatted = groupedInt(chunks[0])
        case 1:
            formatted = "\(chunks[1])K"
        case 2:
            formatted = "\(chunks[2])M"
        case 3:
            formatted = "\(chunks[3])B"
        default:
            let tierIndex = hi - 3
            let suffix = TileStepLabelFormatter.excelLetters(for: tierIndex).lowercased()
            formatted = "\(chunks[hi])\(suffix)"
        }
        return isNegative ? "-" + formatted : formatted
    }

    private static func groupedInt(_ value: Int) -> String {
        String(value)
    }

    private static func padded(_ value: Int) -> String {
        String(format: "%03d", value)
    }
}

// MARK: - Score Display Helpers

private let scoreMillionsFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.usesGroupingSeparator = true
    formatter.groupingSize = 3
    formatter.groupingSeparator = ","
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

public extension AlphaMag {
    /// Scoreboard-friendly format with K/M/B/a/b/c... notation with full precision
    /// Examples:
    /// - 999 -> "999"
    /// - 1,500 -> "1K" or "2K" (depends on rounding)
    /// - 950,000,000 -> "950M"
    /// - 710,000,000,000 -> "710B"
    /// - 394,567,000,000,000 -> "394,567a" (394,567 trillion)
    /// - 2,040,584,000,000 -> "2,041a" (2,041 trillion)
    /// - 5,500,000,000,000,000 -> "5,500b" (5,500 quadrillion)
    static func formatScoreDisplay(_ value: Int) -> String {
        guard value != 0 else { return "0" }
        let isNegative = value < 0
        let magnitude = abs(value)

        // Format using K/M/B/alphabetic notation
        let formatted: String

        if magnitude < 1_000 {
            // Display as-is for values under 1K
            formatted = "\(magnitude)"
        } else if magnitude < 10_000 {
            // For 1K-9K, show rounded K value
            let thousands = magnitude / 1_000
            formatted = "\(thousands)K"
        } else if magnitude < 1_000_000 {
            // For 10K-999K, show full value with K
            let thousands = magnitude / 1_000
            formatted = "\(thousands)K"
        } else if magnitude < 1_000_000_000 {
            // For millions, show full value with M
            let millions = magnitude / 1_000_000
            formatted = "\(millions)M"
        } else if magnitude < 1_000_000_000_000 {
            // For billions, show full value with B
            let billions = magnitude / 1_000_000_000
            formatted = "\(billions)B"
        } else {
            // For trillions and beyond, use alphabetic suffixes with full precision
            // Determine which tier we're in
            let trillion: Int = 1_000_000_000_000
            let quadrillion: Int = 1_000_000_000_000_000

            var divisor: Int
            var suffixChar: String

            if magnitude < quadrillion {
                // Trillions - use 'a' suffix
                // Divide by billion to get the value in thousands of billions (which becomes the number before 'a')
                divisor = 1_000_000_000  // Divide by billion, not trillion
                suffixChar = "a"
            } else if magnitude / 1_000 < quadrillion {
                // Quadrillions - use 'b' suffix (use division to avoid overflow)
                // Divide by trillion to get the value in thousands of trillions (which becomes the number before 'b')
                divisor = trillion
                suffixChar = "b"
            } else {
                // For higher values, calculate the tier
                var tierIndex = 2  // Start at 'c' (quintillions)
                divisor = quadrillion  // Divide by quadrillion for 'c'

                // Keep adjusting for higher tiers
                // Use division instead of multiplication to avoid integer overflow
                // (divisor * 1_000_000 can overflow Int.max)
                while magnitude / 1_000_000 >= divisor && tierIndex < 25 {
                    // Check for potential overflow before multiplying
                    if divisor > Int.max / 1_000 {
                        break
                    }
                    divisor *= 1_000
                    tierIndex += 1
                }

                suffixChar = suffix(forOrdinal: tierIndex + 1)
            }

            // Calculate the value in this tier
            // For 'a': we're dividing by billion, so 2,040,584,000,000 / 1,000,000,000 = 2,040
            // For 'b': we're dividing by trillion, so 5,500,000,000,000,000 / 1,000,000,000,000 = 5,500
            let tierValue = magnitude / divisor

            // Format with comma separator
            let formattedNumber = scoreMillionsFormatter.string(from: NSNumber(value: tierValue)) ?? "\(tierValue)"
            formatted = "\(formattedNumber)\(suffixChar)"
        }

        return isNegative ? "-" + formatted : formatted
    }
}

// MARK: - Tile Value Extensions

public extension AlphaMag {
    /// Check if a tile value should use AlphaMag formatting
    /// We start using suffixes at 16384 (16K) to keep the doubling sequence clean
    static func shouldUseAlphaMagFormatting(for value: Int) -> Bool {
        return value >= 16384
    }
    
    /// Format a tile value appropriately 
    /// < 16384: plain numbers without grouping (2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192)
    /// >= 16384: AlphaMag format (16K, 32K, 64K, 128K, 256K, 512K, 1M, 2M, 4M, 8M, 16M, 32M, 64M, 128M, 256M, 512M, 1B, 2B, 4B, 8B, etc.)
    static func formatTileValue(_ value: Int) -> String {
        if shouldUseAlphaMagFormatting(for: value) {
            return format(value)
        } else {
            return "\(value)"
        }
    }
}
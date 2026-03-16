import Foundation

/// Step-index-based labeler for the 2244 journey.
/// - Doubling only (each step = previous * 2)
/// - Floors at every unit (no rounding)
/// - K/M/B, then lowercase Excel-style suffixes starting at `a` (trillions), then `b`, ..., `z`, `aa` ... `bz`.
/// - Shows full number without grouping for values < 10_000.
public enum TileStepLabelFormatter {

    // MARK: Public API

    /// Returns the label for the given step, starting from an initial value (default 2).
    /// Step 0 -> `start`, Step 1 -> `start*2`, etc.
    public static func labelForStep(_ step: Int, start: UInt64 = 2) -> String {
        precondition(step >= 0, "step must be >= 0")
        // Step 817+ is infinity (beyond the last finite tile in the journey)
        if step >= 817 { return "∞" }
        var chunks = splitBase1000(start)
        if step > 0 {
            doubleTimes(&chunks, step)
        }
        return label(fromChunks: chunks)
    }
    
    /// Convert a tile value to its step index (assuming start = 2)
    /// Returns nil if value is not a power of 2 starting from the start value
    public static func stepForValue(_ value: Int, start: Int = 2) -> Int? {
        guard value >= start, value.nonzeroBitCount == 1, start.nonzeroBitCount == 1 else { return nil }
        
        // Count trailing zeros to find the power of 2
        let valueLog2 = value.trailingZeroBitCount
        let startLog2 = start.trailingZeroBitCount
        
        guard valueLog2 >= startLog2 else { return nil }
        return valueLog2 - startLog2
    }
    
    /// Format a tile value (convenience method that converts value to step)
    public static func formatTileValue(_ value: Int) -> String {
        // Tiles should never be negative - if we get a negative value,
        // it's likely due to integer overflow, so treat it as a very large positive value
        // Note: abs(Int.min) overflows, so handle that case specially
        let absoluteValue = value == Int.min ? Int.max : abs(value)

        // For values < 10_000, show the raw number without grouping
        if absoluteValue < 10_000 {
            return "\(absoluteValue)"
        }

        // For values >= 10_000, use step-based formatting if it's a power of 2
        if let step = stepForValue(absoluteValue, start: 2) {
            return labelForStep(step, start: 2)
        }

        // Fallback for non-power-of-2 values (e.g., overflow clamps) using AlphaMag formatting
        return AlphaMag.format(absoluteValue)
    }

    // MARK: Internal formatting (shared with value-based path if you want)

    /// Labels a positive integer already represented as base-1000 chunks (little-endian).
    /// chunks[i] is the i-th 1000^i block, each in 0...999; last chunk is non-zero.
    static func label(fromChunks chunks: [Int]) -> String {
        let hi = chunks.count - 1

        // < 10_000 → show full without grouping (e.g., "8192")
        if hi == 0 {
            return grouped(chunks[0])
        }
        if hi == 1 {
            let total = chunks[1] * 1_000 + chunks[0]
            if total < 10_000 {
                return grouped(total)
            } else {
                // K (floor)
                return "\(chunks[1])K"
            }
        }

        // M and B (floor)
        if hi == 2 { return "\(chunks[2])M" }
        if hi == 3 { return "\(chunks[3])B" }

        // Beyond billions → letters: a,b,...,z,aa,...,bz (lowercase)
        let tierIndex = hi - 3            // 1 -> a (trillion), 2 -> b, ..., 26 -> z, 27 -> aa, ...
        let suffix = excelLetters(for: tierIndex).lowercased()
        let mantissa = chunks[hi]
        return "\(mantissa)\(suffix)"
    }

    // MARK: Big-integer-by-1000 core

    /// Split UInt64 into base-1000 chunks (little-endian).
    private static func splitBase1000(_ n: UInt64) -> [Int] {
        precondition(n > 0)
        var x = n
        var out: [Int] = []
        while x > 0 {
            out.append(Int(x % 1_000))
            x /= 1_000
        }
        return out
    }

    /// Multiply by 2, `times` times, in base-1000 with carry.
    private static func doubleTimes(_ chunks: inout [Int], _ times: Int) {
        for _ in 0..<times {
            var carry = 0
            for i in 0..<chunks.count {
                let v = chunks[i] * 2 + carry
                chunks[i] = v % 1_000
                carry = v / 1_000
            }
            if carry > 0 { chunks.append(carry) }
        }
    }

    // MARK: Utilities

    /// Excel-style letters, 1-indexed: 1->"A", 26->"Z", 27->"AA", ..., 52->"AZ", 53->"BA", 78->"BZ".
    static func excelLetters(for index: Int) -> String {
        precondition(index >= 1)
        var i = index
        var result = ""
        while i > 0 {
            let rem = (i - 1) % 26
            let scalar = UnicodeScalar(65 + rem)! // 'A'..'Z'
            result = String(scalar) + result
            i = (i - 1) / 26
        }
        return result
    }

    /// Plain decimal string for small totals (e.g., 8192 -> "8192").
    private static func grouped(_ n: Int) -> String {
        String(n)
    }
    
}

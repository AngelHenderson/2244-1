
import Foundation

// --- Mocking Color ---
struct Color {
    let hex: String
    init(hex: String) { self.hex = hex }
}

// --- TileStepLabelFormatter ---
enum TileStepLabelFormatter {
    static func stepForValue(_ value: Int, start: Int = 2) -> Int? {
        guard value >= start, value.nonzeroBitCount == 1, start.nonzeroBitCount == 1 else { return nil }
        let valueLog2 = value.trailingZeroBitCount
        let startLog2 = start.trailingZeroBitCount
        guard valueLog2 >= startLog2 else { return nil }
        return valueLog2 - startLog2
    }
}

// --- Theme ---
struct Theme {
    static let palette25: [(color: Color, darkText: Bool)] = [
        (Color(hex: "2FA7E4"), false), // 1: azure
        (Color(hex: "F49A3E"), false), // 2: orange
        (Color(hex: "F16597"), false), // 3: hot pink
        (Color(hex: "BA6597"), false), // 4: pinned for 16
        (Color(hex: "#9E3A46"), false), // 5: Muted Red
        (Color(hex: "#9674FF"), false), // 6: Purple
        (Color(hex: "#03524B"), false), // 7: Dark Teal
        (Color(hex: "#FF0039"), false), // 8: Red
        (Color(hex: "#FF6F96"), true),  // 9: Pink (dark text)
        (Color(hex: "#07F901"), false), // 10: Bright Green
        (Color(hex: "#FF3B7B"), false), // 11: Vivid Pink
        (Color(hex: "#55B9FF"), false), // 12: Blue
        (Color(hex: "#FFFFEB"), true),  // 13: Cream (dark text)
        (Color(hex: "#8849D1"), false), // 14: Purple
        (Color(hex: "#00FFE5"), true),  // 15: Cyan (dark text)
        (Color(hex: "#FFD300"), true),  // 16: Yellow (dark text)
        (Color(hex: "#F05B59"), false), // 17: Coral Red
        (Color(hex: "#55DFFE"), true),  // 18: Light Cyan / Blue (dark text)
        (Color(hex: "#39B54A"), true),  // 19: Green (dark text)
        (Color(hex: "#E91E63"), false), // 20: Magenta
        (Color(hex: "#673AB7"), false), // 21: Deep Purple
        (Color(hex: "#F44336"), false), // 22: Red
        (Color(hex: "#1565C0"), false), // 23: Dark Blue
        (Color(hex: "#EF6C00"), false), // 24: Orange
        (Color(hex: "#C0CA33"), true)   // 25: Lime (dark text)
    ]
    
    static let stepOverrides: [Int: (color: Color, darkText: Bool)] = [:]
    static let overridesByExactValue: [Int: (color: Color, darkText: Bool)] = [:]
    
    static func color(for value: Int) -> Color {
        if let step = TileStepLabelFormatter.stepForValue(value, start: 2) {
            if let override = stepOverrides[step] {
                return override.color
            }
            return colorForStep(step)
        }
        if let o = overridesByExactValue[value] { return o.color }
        let entry = paletteEntry(forExponent: exponent(for: value))
        return entry.color
    }
    
    static func colorForStep(_ step: Int) -> Color {
        if let override = stepOverrides[step] { return override.color }
        let exponent = step + 1
        return paletteEntry(forExponent: exponent).color
    }

    static func exponent(for value: Int) -> Int {
        if let step = TileStepLabelFormatter.stepForValue(value, start: 2) {
            return step + 1
        }
        let v0 = max(1, value)
        var v = v0
        var floorExp = 0
        while v > 1 {
            v >>= 1
            floorExp += 1
        }
        let isPowerOfTwo = (v0 & (v0 - 1)) == 0
        if v0 >= 1_000_000_000 && !isPowerOfTwo {
            return floorExp + 1
        }
        return floorExp
    }

    static func bucketIndex(forExponent exp: Int) -> Int {
        let e = max(1, exp)
        guard !palette25.isEmpty else { return 0 }
        return (e - 1) % 25
    }
    
    static func paletteEntry(forExponent exponent: Int) -> (color: Color, darkText: Bool) {
        let e = max(1, exponent)
        let idx = bucketIndex(forExponent: e)
        let entry = palette25[idx]
        return entry
    }
}

// --- Test ---
let value = 4_194_304
let color = Theme.color(for: value)
print("Value: \(value)")
print("Color Hex: \(color.hex)")

let step = TileStepLabelFormatter.stepForValue(value)!
print("Step: \(step)")
let exp = Theme.exponent(for: value)
print("Exponent: \(exp)")
let idx = Theme.bucketIndex(forExponent: exp)
print("Index: \(idx)")

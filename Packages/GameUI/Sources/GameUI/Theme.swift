import SwiftUI
import GameCore

@MainActor
public struct Theme {
    public static var colorBlindMode = false
    
    // 25-step palette (repeats every 25 exponent levels). Index 0 corresponds to e%25==1 (value 2),
    // index 24 corresponds to e%25==0 (value 2^25, ~33M). Step 3 (e==4, value 16) is pinned to #BC0077.
    private static let palette25: [(color: Color, darkText: Bool)] = [
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
    
    // Exact value overrides - keeping only special cases
    private static let overridesByExactValue: [Int: (color: Color, darkText: Bool)] = [
        1_000_000_000: (Color(hex: "6F0000"), false),
        36_000_000_000: (Color(hex: "6F0000"), false),
        68_000_000_000: (Color(hex: "FF3B7B"), false), // Match 2048 styling for 68B request
        274_000_000_000: (Color(hex: "C275FF"), true), // Journey request: vivid purple with black text
        549_000_000_000: (Color(hex: "C275FF"), true),
        576_460_752_303_423_488: (Color(hex: "FF3B7B"), false), // 576b legacy pink (2^59)
        1_152_921_504_606_846_976: (Color(hex: "39B54A"), false), // 1c legacy green (2^60)
        2_305_843_009_213_693_952: (Color(hex: "F05B59"), false), // 2c legacy red (2^61)
        4_611_686_018_427_387_904: (Color(hex: "55B9FF"), false), // 4c legacy blue (2^62)
        1_000_000_000_000_000_000: (Color(hex: "6F0000"), false)
    ]

    // Remainder-based overrides removed since they duplicate palette25
    // The base palette25 already has these exact colors
    private static let overridesByRemainder: [Int: (color: Color, darkText: Bool)] = [:]

    // Conditional remainder overrides
    private static let remainder6F0000Thresholds: [Int: Int] = [
        5: 30,
        10: 60
    ]
    
    // Step overrides removed to maintain proper 25-color cycling
    // The palette should repeat consistently every 25 exponents
    private static let stepOverrides: [Int: (color: Color, darkText: Bool)] = [:]
    
    public static func color(for value: Int) -> Color {
        if let step = TileStepLabelFormatter.stepForValue(value, start: 2) {
            // Check step overrides first
            if let override = stepOverrides[step] {
                return override.color
            }
            // Use step-based palette lookup for consistent cycling
            return colorForStep(step)
        }
        if let o = overridesByExactValue[value] { return o.color }
        let entry = paletteEntry(forExponent: exponent(for: value))
        return entry.color
    }
    
    public static func textColor(for value: Int) -> Color {
        if let step = TileStepLabelFormatter.stepForValue(value, start: 2) {
            if let override = stepOverrides[step] {
                return override.darkText ? .black : .white
            }
            return textColorForStep(step)
        }
        if let o = overridesByExactValue[value] { return o.darkText ? .black : .white }
        let entry = paletteEntry(forExponent: exponent(for: value))
        return entry.darkText ? .black : .white
    }
    
    // MARK: - Step-based APIs (for highValue tiles) to repeat the palette by step % 25
    public static func colorForStep(_ step: Int) -> Color {
        if let override = stepOverrides[step] { return override.color }
        
        // Calculate exponent from step (step 0 = 2^1, step 1 = 2^2, etc.)
        // But palette is 1-based on exponent?
        // palette25[0] is for exponent 1 (value 2).
        // step 0 (value 2) -> exponent 1.
        
        let exponent = step + 1
        return paletteEntry(forExponent: exponent).color
    }
    
    public static func textColorForStep(_ step: Int) -> Color {
        if let override = stepOverrides[step] { return override.darkText ? .black : .white }
        let exponent = step + 1
        return paletteEntry(forExponent: exponent).darkText ? .black : .white
    }
    
    private static func colorBucketIndex(for value: Int) -> Int {
        let exp = exponent(for: value)
        return bucketIndex(forExponent: exp)
    }

    private static func exponent(for value: Int) -> Int {
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

    private static func bucketIndex(forExponent exp: Int) -> Int {
        let e = max(1, exp) // Ensure we start at 1
        guard !palette25.isEmpty else { return 0 }
        
        // Calculate 0-based index from 1-based exponent
        // Exponent 1 -> Index 0
        // Exponent 25 -> Index 24
        // Exponent 26 -> Index 0
        return (e - 1) % 25
    }
    
    private static func paletteEntry(forExponent exponent: Int) -> (color: Color, darkText: Bool) {
        let e = max(1, exponent)
        let idx = bucketIndex(forExponent: e)
        return palette25[idx]
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

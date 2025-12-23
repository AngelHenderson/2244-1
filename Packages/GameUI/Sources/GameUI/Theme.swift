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
        (Color(hex: "#9C27B0"), false), // 20: Purple (1M)
        (Color(hex: "#673AB7"), false), // 21: Deep Purple (2M)
        (Color(hex: "#F05B59"), false), // 22: Coral Red (4M) - same as 226u
        (Color(hex: "#1565C0"), false), // 23: Dark Blue
        (Color(hex: "#EF6C00"), false), // 24: Orange
        (Color(hex: "#C0CA33"), true)   // 25: Lime (dark text)
    ]
    
    // Removed exact value overrides to preserve consistent 25-color cycling
    // All values now use the palette cycling for consistency
    private static let overridesByExactValue: [Int: (color: Color, darkText: Bool)] = [:]

    // Remainder-based overrides removed since they duplicate palette25
    // The base palette25 already has these exact colors
    private static let overridesByRemainder: [Int: (color: Color, darkText: Bool)] = [:]

    // Conditional remainder overrides
    private static let remainder6F0000Thresholds: [Int: Int] = [
        5: 30,
        10: 60
    ]

    // MARK: - Simple Sage Palette (25-step, nature-inspired muted tones)
    public static let simpleSagePalette: [(color: Color, darkText: Bool)] = [
        (Color(hex: "A7B4BE"), true),   // 1 (2): Gray-blue
        (Color(hex: "F2A355"), false),  // 2 (4): Peach/Orange
        (Color(hex: "3B8B8B"), false),  // 3 (8): Dark teal
        (Color(hex: "9CA880"), true),   // 4 (16): Sage green
        (Color(hex: "A97B7B"), false),  // 5 (32): Dusty rose
        (Color(hex: "E8A5A3"), true),   // 6 (64): Salmon pink
        (Color(hex: "A783B2"), false),  // 7 (128): Lavender
        (Color(hex: "3FD0E7"), true),   // 8 (256): Cyan
        (Color(hex: "A9C54A"), true),   // 9 (512): Yellow-green
        (Color(hex: "E55C5C"), false),  // 10 (1024): Coral red
        (Color(hex: "7378D6"), false),  // 11 (2048): Blue-purple
        (Color(hex: "E8A5C2"), true),   // 12 (4096): Pink
        (Color(hex: "D65B8F"), false),  // 13 (8192): Magenta
        (Color(hex: "384E7A"), false),  // 14 (16K): Dark blue
        (Color(hex: "808A5C"), false),  // 15 (32K): Olive
        (Color(hex: "CD7C5C"), false),  // 16 (65K): Terracotta
        (Color(hex: "6E4378"), false),  // 17 (131K): Purple
        (Color(hex: "8E9957"), true),   // 18 (262K): Yellow-olive
        (Color(hex: "F5B880"), true),   // 19 (524K): Light peach
        (Color(hex: "522A2B"), false),  // 20 (1M): Burgundy
        (Color(hex: "2B5555"), false),  // 21 (2M): Dark teal
        (Color(hex: "3B5533"), false),  // 22 (4M): Dark green
        (Color(hex: "6AC5B8"), true),   // 23 (8M): Mint
        (Color(hex: "C87B3E"), false),  // 24 (16M): Burnt orange
        (Color(hex: "8B5EA0"), false),  // 25 (33M): Purple
    ]

    public static func simpleSageColor(for value: Int) -> Color {
        if let step = TileStepLabelFormatter.stepForValue(value, start: 2) {
            let exponent = step + 1
            let idx = (max(1, exponent) - 1) % 25
            return simpleSagePalette[idx].color
        }
        let exp = exponent(for: value)
        let idx = (max(1, exp) - 1) % 25
        return simpleSagePalette[idx].color
    }

    public static func simpleSageTextColor(for value: Int) -> Color {
        if let step = TileStepLabelFormatter.stepForValue(value, start: 2) {
            let exponent = step + 1
            let idx = (max(1, exponent) - 1) % 25
            return simpleSagePalette[idx].darkText ? .black : .white
        }
        let exp = exponent(for: value)
        let idx = (max(1, exp) - 1) % 25
        return simpleSagePalette[idx].darkText ? .black : .white
    }

    // MARK: - Mellow Yellow Palette (25-step, warm earth tones with yellow accents)
    public static let mellowYellowPalette: [(color: Color, darkText: Bool)] = [
        (Color(hex: "4A6FA5"), false),  // 1 (2): Dark blue
        (Color(hex: "8B7B8B"), false),  // 2 (4): Grayish purple
        (Color(hex: "C4B454"), true),   // 3 (8): Yellow/olive
        (Color(hex: "B87B7B"), false),  // 4 (16): Dusty rose
        (Color(hex: "5B8DC9"), false),  // 5 (32): Medium blue
        (Color(hex: "E07B6B"), false),  // 6 (64): Coral/salmon
        (Color(hex: "9CA896"), true),   // 7 (128): Gray/sage
        (Color(hex: "8B6B8B"), false),  // 8 (256): Mauve/purple
        (Color(hex: "5DAA68"), false),  // 9 (512): Green
        (Color(hex: "CC9966"), true),   // 10 (1024): Orange/tan
        (Color(hex: "D95B5B"), false),  // 11 (2048): Red/coral
        (Color(hex: "9B4DCA"), false),  // 12 (4096): Purple/magenta
        (Color(hex: "5BB8B8"), true),   // 13 (8192): Teal/cyan
        (Color(hex: "A4B545"), true),   // 14 (16K): Yellow-green
        (Color(hex: "9A9A6B"), true),   // 15 (32K): Olive/khaki
        (Color(hex: "7B5BA5"), false),  // 16 (65K): Purple/violet
        (Color(hex: "4D9B5D"), false),  // 17 (131K): Green
        (Color(hex: "8B5B7B"), false),  // 18 (262K): Mauve/purple
        (Color(hex: "A5A56B"), true),   // 19 (524K): Olive/khaki
        (Color(hex: "6B8B5B"), false),  // 20 (1M): Green/olive
        (Color(hex: "CCA07B"), true),   // 21 (2M): Tan/orange
        (Color(hex: "E08B7B"), false),  // 22 (4M): Coral/salmon
        (Color(hex: "9B5BA5"), false),  // 23 (8M): Purple/magenta
        (Color(hex: "6B5BAB"), false),  // 24 (16M): Blue/indigo
        (Color(hex: "A07B8B"), false),  // 25 (33M): Dusty rose/mauve
    ]

    public static func mellowYellowColor(for value: Int) -> Color {
        if let step = TileStepLabelFormatter.stepForValue(value, start: 2) {
            let exponent = step + 1
            let idx = (max(1, exponent) - 1) % 25
            return mellowYellowPalette[idx].color
        }
        let exp = exponent(for: value)
        let idx = (max(1, exp) - 1) % 25
        return mellowYellowPalette[idx].color
    }

    public static func mellowYellowTextColor(for value: Int) -> Color {
        if let step = TileStepLabelFormatter.stepForValue(value, start: 2) {
            let exponent = step + 1
            let idx = (max(1, exponent) - 1) % 25
            return mellowYellowPalette[idx].darkText ? .black : .white
        }
        let exp = exponent(for: value)
        let idx = (max(1, exp) - 1) % 25
        return mellowYellowPalette[idx].darkText ? .black : .white
    }
    
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

        // Step numbering depends on the context:
        // - From stepForValue: step 0 = 2^1, step 1 = 2^2 (0-based)
        // - From JourneyTileGenerator highValue: step 1 = 2^1, step 2 = 2^2 (1-based)
        // We need to detect which system is being used.

        // For normal values (step < 63), stepForValue returns 0-based steps
        // For highValue tiles (step >= 63), JourneyTileGenerator uses 1-based steps
        // But actually, JourneyTileGenerator uses 1-based for ALL steps!

        // The issue: When Theme.color(for: value) calls stepForValue, it gets 0-based steps
        // But when TileView renders a highValue tile, the step is 1-based

        // Solution: Always add 1 to convert 0-based to 1-based (matching exponent)
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

        // Get the base color from the palette
        let entry = palette25[idx]

        // Special case: Lighten 140a (2^47) and its repetitions to match 4M (2^22)
        // Both use palette index 21, but 140a might need lightening
        if e == 47 || e == 72 || e == 97 || e == 122 || e == 147 {
            // These are 140a and its 25-block repetitions
            // Return a lightened version to match 4M's appearance
            let lightenedColor = entry.color.lightened(by: 0.15)
            return (lightenedColor, entry.darkText)
        }

        return entry
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

    func lightened(by percentage: Double) -> Color {
        #if canImport(UIKit)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Increase brightness, capping at 1.0
        let newBrightness = min(1.0, brightness + CGFloat(percentage))

        return Color(UIColor(hue: hue, saturation: saturation, brightness: newBrightness, alpha: alpha))
        #else
        // For macOS or other platforms, use a simple RGB lightening
        // This is an approximation since we don't have HSB conversion readily available
        return self.opacity(1.0 - percentage * 0.5)
        #endif
    }
}

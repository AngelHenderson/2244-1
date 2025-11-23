import SwiftUI

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
        (Color(hex: "154F7F"), false), // 5: deep blue
        (Color(hex: "F05B59"), false), // 6: coral red
        (Color(hex: "39B54A"), false), // 7: green
        (Color(hex: "7C4DFF"), false), // 8: violet
        (Color(hex: "FFD300"), true),  // 9: yellow (dark text)
        (Color(hex: "00C7B7"), false), // 10: teal
        (Color(hex: "FF6F00"), false), // 11: deep orange
        (Color(hex: "9C27B0"), false), // 12: purple
        (Color(hex: "4CAF50"), false), // 13: green
        (Color(hex: "2196F3"), false), // 14: blue
        (Color(hex: "E91E63"), false), // 15: magenta
        (Color(hex: "D4E04A"), true),  // 16: lime (dark text)
        (Color(hex: "3F51B5"), false), // 17: indigo
        (Color(hex: "FF5722"), false), // 18: orange red
        (Color(hex: "03A9F4"), false), // 19: light blue
        (Color(hex: "8BC34A"), true),  // 20: light green (dark text)
        (Color(hex: "00BCD4"), false), // 21: cyan
        (Color(hex: "CDDC39"), true),  // 22: chartreuse (dark text)
        (Color(hex: "673AB7"), false), // 23: deep purple
        (Color(hex: "F44336"), false), // 24: red
        (Color(hex: "009688"), false)  // 25: teal
    ]
    
    // Exact value overrides - keeping only special cases
    private static let overridesByExactValue: [Int: (color: Color, darkText: Bool)] = [
        1_000_000_000: (Color(hex: "6F0000"), false),
        36_000_000_000: (Color(hex: "6F0000"), false),
        68_000_000_000: (Color(hex: "FF3B7B"), false), // Match 2048 styling for 68B request
        1_000_000_000_000_000_000: (Color(hex: "6F0000"), false)
    ]

    // Remainder-based overrides (e % 25) - these colors repeat every 25 blocks!
    private static let overridesByRemainder: [Int: (color: Color, darkText: Bool)] = [
        5: (Color(hex: "6F0000"), false),      // 32, 32×2^25, 32×2^50... → Dark red
        6: (Color(hex: "9674FF"), false),      // 64, 64×2^25, 64×2^50... → Purple
        7: (Color(hex: "03524B"), false),      // 128, 128×2^25... → Dark teal
        8: (Color(hex: "FF0039"), false),      // 256, 256×2^25... → Red
        9: (Color(hex: "FF6F96"), false),      // 512, 512×2^25... → Pink
        10: (Color(hex: "07F901"), false),     // 1024, 1024×2^25... → Bright green
        11: (Color(hex: "FF3B7B"), false),     // 2048, 2048×2^25... → Vivid pink (was FF0027)
        12: (Color(hex: "55B9FF"), false),     // 4096, 4096×2^25... → Blue
        13: (Color(hex: "FFFFEB"), true),      // 8192, 8192×2^25... → Cream (dark text)
        14: (Color(hex: "8849D1"), false),     // 16K, 16K×2^25... → Purple
        15: (Color(hex: "00FFE5"), true),      // 32K, 32K×2^25... → Bright cyan (dark text)
        16: (Color(hex: "FFD300"), true),      // 64K, 64K×2^25... → Yellow (dark text)
        17: (Color(hex: "F05B59"), false),     // 131K, 131K×2^25... → Coral red
        18: (Color(hex: "55DFFE"), true),      // 262K, 262K×2^25... → Light cyan (dark text)
        19: (Color(hex: "39B54A"), true),      // 524K, 524K×2^25... → Green (dark text)
        4: (Color(hex: "BA6597"), false),      // 16, 16×2^25... → Pink (existing)
        23: (Color(hex: "FF0027"), false)      // Kept for backwards compatibility
    ]

    // Conditional remainder overrides
    private static let remainder6F0000Thresholds: [Int: Int] = [
        5: 30,
        10: 60
    ]
    
    public static func color(for value: Int) -> Color {
        if let o = overridesByExactValue[value] { return o.color }
        let e = exponent(for: value)
        let r = e % 25
        if let minE = remainder6F0000Thresholds[r], e >= minE { return Color(hex: "6F0000") }
        if let o = overridesByRemainder[r] { return o.color }
        let idx = colorBucketIndex(for: value)
        return palette25[idx].color
    }
    
    public static func textColor(for value: Int) -> Color {
        if let o = overridesByExactValue[value] { return o.darkText ? .black : .white }
        let e = exponent(for: value)
        let r = e % 25
        if let minE = remainder6F0000Thresholds[r], e >= minE { return .white }
        if let o = overridesByRemainder[r] { return o.darkText ? .black : .white }
        let idx = colorBucketIndex(for: value)
        return palette25[idx].darkText ? .black : .white
    }
    
    // MARK: - Step-based APIs (for highValue tiles) to repeat the palette by step % 25
    public static func colorForStep(_ step: Int) -> Color {
        let e = max(0, step)
        let r = e % 25
        if let minE = remainder6F0000Thresholds[r], e >= minE { return Color(hex: "6F0000") }
        if let o = overridesByRemainder[r] { return o.color }
        let idx = bucketIndex(forExponent: e)
        return palette25[idx].color
    }
    
    public static func textColorForStep(_ step: Int) -> Color {
        let e = max(0, step)
        let r = e % 25
        if let minE = remainder6F0000Thresholds[r], e >= minE { return .white }
        if let o = overridesByRemainder[r] { return o.darkText ? .black : .white }
        let idx = bucketIndex(forExponent: e)
        return palette25[idx].darkText ? .black : .white
    }
    
    private static func colorBucketIndex(for value: Int) -> Int {
        let exp = exponent(for: value)
        return bucketIndex(forExponent: exp)
    }

    private static func exponent(for value: Int) -> Int {
        let v0 = max(1, value)
        var v = v0
        var floorExp = 0
        while v > 1 { v >>= 1; floorExp += 1 }
        let isPowerOfTwo = (v0 & (v0 - 1)) == 0
        if v0 >= 1_000_000_000 && !isPowerOfTwo {
            return floorExp + 1
        }
        return floorExp
    }

    private static func bucketIndex(forExponent exp: Int) -> Int {
        let e = max(0, exp)
        guard !palette25.isEmpty else { return 0 }
        if e == 0 { return 0 }
        let r = e % 25
        if r == 0 { return 24 }
        return r - 1
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

import SwiftUI
import Foundation

@MainActor
public struct ThemeDescriptor {
    public enum TileShape: String {
        case rounded
        case square
    }
    
    public enum TileStyle: String {
        case flat      // Original flat style
        case raised3D  // New 3D raised style
    }

    public let id: String
    public let name: String
    public let tileShape: TileShape
    public let tileStyle: TileStyle

    private let colorProvider: (Int) -> Color

    public init(
        id: String,
        name: String,
        tileShape: TileShape,
        tileStyle: TileStyle = .flat,
        color: @escaping (Int) -> Color
    ) {
        self.id = id
        self.name = name
        self.tileShape = tileShape
        self.tileStyle = tileStyle
        self.colorProvider = color
    }

    public func color(for value: Int) -> Color {
        colorProvider(value)
    }
}

@MainActor
public struct ThemeRegistry {
    private var descriptorsById: [String: ThemeDescriptor]
    public var defaultDescriptor: ThemeDescriptor

    public init(descriptors: [ThemeDescriptor], defaultId: String) {
        var mapping: [String: ThemeDescriptor] = [:]
        for descriptor in descriptors {
            mapping[descriptor.id] = descriptor
        }
        self.descriptorsById = mapping
        self.defaultDescriptor = mapping[defaultId] ?? descriptors.first!
    }

    public func descriptor(for id: String?) -> ThemeDescriptor {
        guard let id, let descriptor = descriptorsById[id] else {
            return defaultDescriptor
        }
        return descriptor
    }

    public func allDescriptors() -> [ThemeDescriptor] {
        Array(descriptorsById.values).sorted { $0.name < $1.name }
    }
}

extension ThemeRegistry {
    public static var Default: ThemeRegistry {
        let classic = ThemeDescriptor(
            id: "classic",
            name: "Classic",
            tileShape: .rounded,
            tileStyle: .flat,
            color: { value in
                Theme.color(for: value)
            }
        )

        let classicSquare = ThemeDescriptor(
            id: "classic-square",
            name: "Classic Square",
            tileShape: .square,
            tileStyle: .flat,
            color: { value in
                Theme.color(for: value)
            }
        )
        
        let raised3D = ThemeDescriptor(
            id: "raised-3d",
            name: "3D Raised",
            tileShape: .rounded,
            tileStyle: .raised3D,
            color: { value in
                Theme.color(for: value)
            }
        )
        
        let raised3DSquare = ThemeDescriptor(
            id: "raised-3d-square",
            name: "3D Raised Square",
            tileShape: .square,
            tileStyle: .raised3D,
            color: { value in
                Theme.color(for: value)
            }
        )

        // Neon theme
        let neonPalette: [Color] = [
            Color(hex: "39FF14"), // neon green
            Color(hex: "00E5FF"), // neon cyan
            Color(hex: "FF2079"), // neon magenta
            Color(hex: "FFD300"), // neon yellow
            Color(hex: "7C4DFF")  // neon violet
        ]
        let neon = ThemeDescriptor(
            id: "neon",
            name: "Neon",
            tileShape: .rounded,
            tileStyle: .flat,
            color: { value in
                var v = max(1, value)
                var e = 0
                while v > 1 { v >>= 1; e += 1 }
                let idx = e == 0 ? 0 : (e - 1) % neonPalette.count
                return neonPalette[idx]
            }
        )

        // Pastel theme
        let pastelPalette: [Color] = [
            Color(hex: "AEC6CF"), // pastel blue
            Color(hex: "FFB3BA"), // pastel pink
            Color(hex: "B5EAD7"), // pastel mint
            Color(hex: "FFDFBA"), // pastel orange
            Color(hex: "C7CEEA")  // pastel purple
        ]
        let pastel = ThemeDescriptor(
            id: "pastel",
            name: "Pastel",
            tileShape: .rounded,
            tileStyle: .flat,
            color: { value in
                var v = max(1, value)
                var e = 0
                while v > 1 { v >>= 1; e += 1 }
                let idx = e == 0 ? 0 : (e - 1) % pastelPalette.count
                return pastelPalette[idx]
            }
        )

        // Monochrome theme (shades of gray by exponent)
        let mono = ThemeDescriptor(
            id: "mono",
            name: "Monochrome",
            tileShape: .square,
            tileStyle: .flat,
            color: { value in
                var v = max(1, value)
                var e = 0
                while v > 1 { v >>= 1; e += 1 }
                let shadeIndex = e == 0 ? 0 : (e - 1) % 10
                let t = Double(shadeIndex) / 10.0
                return Color(white: 0.2 + 0.7 * t)
            }
        )

        // High Contrast theme (few bold colors)
        let hcPalette: [Color] = [
            .red, .blue, .green, .orange, .purple, .pink, .yellow
        ]
        let highContrast = ThemeDescriptor(
            id: "high-contrast",
            name: "High Contrast",
            tileShape: .square,
            tileStyle: .raised3D,
            color: { value in
                var v = max(1, value)
                var e = 0
                while v > 1 { v >>= 1; e += 1 }
                let idx = e == 0 ? 0 : (e - 1) % hcPalette.count
                return hcPalette[idx]
            }
        )

        // Simple Sage theme (nature-inspired muted tones)
        let simpleSage = ThemeDescriptor(
            id: "simple-sage",
            name: "Simple Sage",
            tileShape: .rounded,
            tileStyle: .flat,
            color: { value in
                Theme.simpleSageColor(for: value)
            }
        )

        let simpleSageSquare = ThemeDescriptor(
            id: "simple-sage-square",
            name: "Simple Sage Square",
            tileShape: .square,
            tileStyle: .flat,
            color: { value in
                Theme.simpleSageColor(for: value)
            }
        )

        let simpleSage3D = ThemeDescriptor(
            id: "simple-sage-3d",
            name: "Simple Sage 3D",
            tileShape: .rounded,
            tileStyle: .raised3D,
            color: { value in
                Theme.simpleSageColor(for: value)
            }
        )

        let simpleSage3DSquare = ThemeDescriptor(
            id: "simple-sage-3d-square",
            name: "Simple Sage 3D Square",
            tileShape: .square,
            tileStyle: .raised3D,
            color: { value in
                Theme.simpleSageColor(for: value)
            }
        )

        // Mellow Yellow theme (warm earth tones with yellow accents)
        let mellowYellow = ThemeDescriptor(
            id: "mellow-yellow",
            name: "Mellow Yellow",
            tileShape: .rounded,
            tileStyle: .flat,
            color: { value in
                Theme.mellowYellowColor(for: value)
            }
        )

        let mellowYellowSquare = ThemeDescriptor(
            id: "mellow-yellow-square",
            name: "Mellow Yellow Square",
            tileShape: .square,
            tileStyle: .flat,
            color: { value in
                Theme.mellowYellowColor(for: value)
            }
        )

        let mellowYellow3D = ThemeDescriptor(
            id: "mellow-yellow-3d",
            name: "Mellow Yellow 3D",
            tileShape: .rounded,
            tileStyle: .raised3D,
            color: { value in
                Theme.mellowYellowColor(for: value)
            }
        )

        let mellowYellow3DSquare = ThemeDescriptor(
            id: "mellow-yellow-3d-square",
            name: "Mellow Yellow 3D Square",
            tileShape: .square,
            tileStyle: .raised3D,
            color: { value in
                Theme.mellowYellowColor(for: value)
            }
        )

        // Relaxed Rust theme (earthy tones and rusts)
        let relaxedRust = ThemeDescriptor(
            id: "relaxed-rust",
            name: "Relaxed Rust",
            tileShape: .rounded,
            tileStyle: .flat,
            color: { value in
                Theme.relaxedRustColor(for: value)
            }
        )

        let relaxedRustSquare = ThemeDescriptor(
            id: "relaxed-rust-square",
            name: "Relaxed Rust Square",
            tileShape: .square,
            tileStyle: .flat,
            color: { value in
                Theme.relaxedRustColor(for: value)
            }
        )

        let relaxedRust3D = ThemeDescriptor(
            id: "relaxed-rust-3d",
            name: "Relaxed Rust 3D",
            tileShape: .rounded,
            tileStyle: .raised3D,
            color: { value in
                Theme.relaxedRustColor(for: value)
            }
        )

        let relaxedRust3DSquare = ThemeDescriptor(
            id: "relaxed-rust-3d-square",
            name: "Relaxed Rust 3D Square",
            tileShape: .square,
            tileStyle: .raised3D,
            color: { value in
                Theme.relaxedRustColor(for: value)
            }
        )

        return ThemeRegistry(
            descriptors: [classic, classicSquare, raised3D, raised3DSquare, neon, pastel, mono, highContrast, simpleSage, simpleSageSquare, simpleSage3D, simpleSage3DSquare, mellowYellow, mellowYellowSquare, mellowYellow3D, mellowYellow3DSquare, relaxedRust, relaxedRustSquare, relaxedRust3D, relaxedRust3DSquare],
            defaultId: "raised-3d-square"
        )
    }
}



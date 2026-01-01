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
    private let stepColorProvider: (Int) -> Color
    private let stepTextColorProvider: (Int) -> Color

    public init(
        id: String,
        name: String,
        tileShape: TileShape,
        tileStyle: TileStyle = .flat,
        color: @escaping (Int) -> Color,
        colorForStep: @escaping (Int) -> Color = { Theme.colorForStep($0) },
        textColorForStep: @escaping (Int) -> Color = { Theme.textColorForStep($0) }
    ) {
        self.id = id
        self.name = name
        self.tileShape = tileShape
        self.tileStyle = tileStyle
        self.colorProvider = color
        self.stepColorProvider = colorForStep
        self.stepTextColorProvider = textColorForStep
    }

    public func color(for value: Int) -> Color {
        colorProvider(value)
    }

    public func colorForStep(_ step: Int) -> Color {
        stepColorProvider(step)
    }

    public func textColorForStep(_ step: Int) -> Color {
        stepTextColorProvider(step)
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

        // Cozy Coral theme (warm pinks, peaches, and corals)
        let cozyCoral = ThemeDescriptor(
            id: "cozy-coral",
            name: "Cozy Coral",
            tileShape: .rounded,
            tileStyle: .flat,
            color: { value in
                Theme.cozyCoralColor(for: value)
            }
        )

        let cozyCoralSquare = ThemeDescriptor(
            id: "cozy-coral-square",
            name: "Cozy Coral Square",
            tileShape: .square,
            tileStyle: .flat,
            color: { value in
                Theme.cozyCoralColor(for: value)
            }
        )

        let cozyCoral3D = ThemeDescriptor(
            id: "cozy-coral-3d",
            name: "Cozy Coral 3D",
            tileShape: .rounded,
            tileStyle: .raised3D,
            color: { value in
                Theme.cozyCoralColor(for: value)
            }
        )

        let cozyCoral3DSquare = ThemeDescriptor(
            id: "cozy-coral-3d-square",
            name: "Cozy Coral 3D Square",
            tileShape: .square,
            tileStyle: .raised3D,
            color: { value in
                Theme.cozyCoralColor(for: value)
            }
        )

        return ThemeRegistry(
            descriptors: [classic, classicSquare, raised3D, raised3DSquare, simpleSage, simpleSageSquare, simpleSage3D, simpleSage3DSquare, mellowYellow, mellowYellowSquare, mellowYellow3D, mellowYellow3DSquare, relaxedRust, relaxedRustSquare, relaxedRust3D, relaxedRust3DSquare, cozyCoral, cozyCoralSquare, cozyCoral3D, cozyCoral3DSquare],
            defaultId: "raised-3d-square"
        )
    }
}



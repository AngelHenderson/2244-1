import SwiftUI

/// A raised, pressable tile button style with a 3-D look and physical press motion.
struct TileButtonStyle: ButtonStyle {
    var base: Color
    var corner: CGFloat = 12  // Reduced from 24 to ensure rounded squares, not circles
    var depth: CGFloat = 10        // visual height of the tile above the surface
    var shadowOpacity: Double = 0.35
    var highlightOpacity: Double = 0.40
    var font: Font = .system(size: 44, weight: .semibold, design: .rounded)

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        // Surfaces
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

        // Main face with subtle vertical sheen
        let face = LinearGradient(
            colors: [
                base.opacity(0.98),
                base.opacity(0.88)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        // A soft top-left highlight and bottom-right inner shade to sell the bevel
        let bevel = shape
            .fill(.clear)
            .overlay(
                shape
                    .strokeBorder(.white.opacity(highlightOpacity), lineWidth: 1.2)
                    .blendMode(.overlay)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                shape
                    .strokeBorder(.black.opacity(0.25), lineWidth: 1)
                    .blendMode(.multiply)
                    .mask(
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )

        // The "ledge" shadow beneath the tile. We keep it fixed while the tile moves down.
        let ledgeShadow = shape
            .fill(base.opacity(0.001)) // invisible hit area alignment
            .shadow(color: .black.opacity(shadowOpacity), radius: depth, x: 0, y: depth)

        return ZStack(alignment: .center) {
            ledgeShadow

            // Face that physically moves down on press
            shape
                .fill(face)
                .overlay(bevel)
                .overlay(
                    configuration.label
                        .font(font)
                        //.foregroundStyle(.white)
                        .shadow(radius: pressed ? 0 : 1.5)
                        .animation(.default, value: pressed)
                )
                .shadow(color: .black.opacity(shadowOpacity * 0.66),
                        radius: pressed ? depth * 0.4 : depth * 0.8,
                        x: 0,
                        y: pressed ? depth * 0.3 : depth * 0.8)
                .offset(y: pressed ? depth * 0.55 : 0)              // physical press-down
                .scaleEffect(pressed ? 0.985 : 1)                   // tiny squeeze
                .animation(.spring(response: 0.22, dampingFraction: 0.9, blendDuration: 0.15),
                           value: pressed)
        }
        .contentShape(shape) // precise hit testing
        .accessibilityAddTraits(.isButton)
        // Optional haptic "pop" on press begin
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: configuration.isPressed)
    }
}

/// 3D tile style for static display (non-button tiles)
struct Tile3DStyle: ViewModifier {
    let baseColor: Color
    let isSelected: Bool
    let isValid: Bool
    let tileShape: ThemeDescriptor.TileShape
    let depth: CGFloat = 8
    
    var cornerRadius: CGFloat {
        switch tileShape {
        case .rounded:
            return 12  // Reduced from 24 to ensure rounded squares, not circles
        case .square:
            return 8
        }
    }
    
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        
        // Main face with gradient
        let face = LinearGradient(
            colors: [
                baseColor.opacity(0.98),
                baseColor.opacity(0.88)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        
        // Bevel effect
        let bevel = shape
            .fill(.clear)
            .overlay(
                shape
                    .strokeBorder(.white.opacity(0.40), lineWidth: 1.2)
                    .blendMode(.overlay)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                shape
                    .strokeBorder(.black.opacity(0.25), lineWidth: 1)
                    .blendMode(.multiply)
                    .mask(
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )
        
        ZStack {
            // Base shadow layer
            shape
                .fill(baseColor.opacity(0.001))
                .shadow(color: .black.opacity(0.35), radius: depth, x: 0, y: depth)
            
            // Main tile face
            shape
                .fill(face)
                .overlay(bevel)
                .overlay(content)
                .shadow(
                    color: .black.opacity(0.23),
                    radius: depth * 0.8,
                    x: 0,
                    y: depth * 0.8
                )
                .conditionalOverlay(isSelected) {
                    shape.strokeBorder(
                        isValid ? Color.green : Color.red,
                        lineWidth: 3
                    )
                }
        }
    }
}

private extension View {
    @ViewBuilder
    func conditionalOverlay<Overlay: View>(_ condition: Bool, @ViewBuilder _ overlay: () -> Overlay) -> some View {
        if condition {
            self.overlay(overlay())
        } else {
            self
        }
    }
}

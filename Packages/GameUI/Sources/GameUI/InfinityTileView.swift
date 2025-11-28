import SwiftUI

/// A specialized view for rendering the infinity tile with unique visual effects
struct InfinityTileView: View {
    let size: CGFloat
    let isSelected: Bool
    let isValid: Bool

    @State private var animationPhase: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3

    private let gradientColors = [
        Color(hex: "#FFD700"), // Gold
        Color(hex: "#FFA500"), // Orange
        Color(hex: "#FF69B4"), // Hot Pink
        Color(hex: "#9370DB"), // Medium Purple
        Color(hex: "#4169E1"), // Royal Blue
        Color(hex: "#00CED1"), // Dark Turquoise
        Color(hex: "#32CD32"), // Lime Green
        Color(hex: "#FFD700"), // Back to Gold for smooth loop
    ]

    var body: some View {
        ZStack {
            // Background with animated gradient
            RoundedRectangle(cornerRadius: size * 0.1)
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: gradientColors),
                        center: .center,
                        startAngle: .degrees(animationPhase),
                        endAngle: .degrees(animationPhase + 360)
                    )
                )
                .overlay(
                    // Inner glow effect
                    RoundedRectangle(cornerRadius: size * 0.1)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.8),
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .overlay(
                    // Outer glow/bloom effect
                    RoundedRectangle(cornerRadius: size * 0.1)
                        .stroke(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(glowOpacity),
                                    Color.purple.opacity(glowOpacity * 0.5),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: size * 0.5
                            ),
                            lineWidth: 4
                        )
                        .blur(radius: 4)
                )

            // Selection border
            if isSelected {
                RoundedRectangle(cornerRadius: size * 0.1)
                    .strokeBorder(isValid ? Color.green : Color.red, lineWidth: 3)
            }

            // Infinity symbol with special effects
            ZStack {
                // Shadow/glow behind symbol
                Image(systemName: "infinity")
                    .font(.system(size: size * 0.5, weight: .black))
                    .foregroundColor(.white)
                    .blur(radius: 8)
                    .opacity(0.8)
                    .scaleEffect(pulseScale * 1.1)

                // Main infinity symbol
                Image(systemName: "infinity")
                    .font(.system(size: size * 0.5, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(hex: "#F0F0F0")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(pulseScale)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)

                // Sparkle effects
                ForEach(0..<4) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.08, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(glowOpacity * 2)
                        .offset(
                            x: cos(animationPhase * .pi / 180 + Double(index) * .pi / 2) * size * 0.3,
                            y: sin(animationPhase * .pi / 180 + Double(index) * .pi / 2) * size * 0.3
                        )
                        .rotationEffect(.degrees(animationPhase + Double(index * 90)))
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            // Start animations
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                animationPhase = 360
            }

            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
                glowOpacity = 0.6
            }
        }
    }
}

// Preview
struct InfinityTileView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                InfinityTileView(size: 80, isSelected: false, isValid: true)
                InfinityTileView(size: 80, isSelected: true, isValid: true)
                InfinityTileView(size: 80, isSelected: true, isValid: false)
            }

            HStack(spacing: 20) {
                InfinityTileView(size: 60, isSelected: false, isValid: true)
                InfinityTileView(size: 100, isSelected: false, isValid: true)
                InfinityTileView(size: 120, isSelected: false, isValid: true)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }
}
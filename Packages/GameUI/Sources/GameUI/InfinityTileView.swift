import SwiftUI
import GameCore

/// A specialized view for rendering the infinity tile with unique visual effects
struct InfinityTileView: View {
    let size: CGFloat
    let isSelected: Bool
    let isValid: Bool
    var useSubtleAnimation: Bool = false  // Option for less intensive animation

    @State private var animationPhase: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3

    // Use the 262K palette color for infinity (request: blue 262K)
    private let infinityBaseColor = Theme.color(for: 262_144)
    
    private var gradientColors: [Color] {
        [
            infinityBaseColor,
            infinityBaseColor.opacity(0.85),
            infinityBaseColor.opacity(0.7),
            infinityBaseColor
        ]
    }

    private var staticGradientColors: [Color] {
        [
            infinityBaseColor.opacity(0.9),
            infinityBaseColor.opacity(0.75),
            infinityBaseColor.opacity(0.6)
        ]
    }

    var body: some View {
        ZStack {
            backgroundView
                .overlay(innerGlowOverlay)
                .overlay(outerGlowOverlay)

            if isSelected {
                selectionBorder
            }

            infinitySymbol
                .frame(width: size, height: size)
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

    // MARK: - Subviews

    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: size * 0.1)
            .strokeBorder(isValid ? Color.green : Color.red, lineWidth: 3)
    }

    private var innerGlowOverlay: some View {
        let corner = size * 0.1
        let lineWidth: CGFloat = 2

        let strokeGradient = LinearGradient(
            colors: [
                Color.white.opacity(0.8),
                Color.white.opacity(0.3),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        return RoundedRectangle(cornerRadius: corner)
            .stroke(strokeGradient, lineWidth: lineWidth)
    }

    private var outerGlowOverlay: some View {
        let corner = size * 0.1
        let lineWidth: CGFloat = 4

        let radial = RadialGradient(
            colors: [
                Color.white.opacity(glowOpacity),
                Color.purple.opacity(glowOpacity * 0.5),
                Color.clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: size * 0.5
        )

        return RoundedRectangle(cornerRadius: corner)
            .stroke(radial, lineWidth: lineWidth)
            .blur(radius: 4)
    }

    private var infinitySymbol: some View {
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
                .foregroundStyle(mainSymbolGradient)
                .scaleEffect(pulseScale)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)

            sparkles
        }
    }

    private var mainSymbolGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white,
                Color(hex: "#F0F0F0")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var sparkles: some View {
        ZStack {
            ForEach(0..<4) { index in
                sparkle(at: index)
            }
        }
    }

    private func sparkle(at index: Int) -> some View {
        let angleRadians = (animationPhase * .pi / 180) + Double(index) * .pi / 2
        let distance = size * 0.3
        let x = cos(angleRadians) * distance
        let y = sin(angleRadians) * distance
        let rotation = animationPhase + Double(index * 90)

        return Image(systemName: "sparkle")
            .font(.system(size: size * 0.08, weight: .bold))
            .foregroundColor(.white)
            .opacity(glowOpacity * 2)
            .offset(x: x, y: y)
            .rotationEffect(.degrees(rotation))
    }

    // MARK: - Background builder

    @ViewBuilder
    private var backgroundView: some View {
        let corner = size * 0.1

        if useSubtleAnimation {
            let gradient = LinearGradient(
                gradient: Gradient(colors: staticGradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: corner)
                .fill(gradient)
        } else {
            let start: Angle = .degrees(animationPhase)
            let end: Angle = .degrees(animationPhase + 360)
            let angular = AngularGradient(
                gradient: Gradient(colors: gradientColors),
                center: .center,
                startAngle: start,
                endAngle: end
            )

            RoundedRectangle(cornerRadius: corner)
                .fill(angular)
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

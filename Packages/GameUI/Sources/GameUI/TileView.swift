import SwiftUI
import GameCore

private enum MilestoneAppearance {
    // Exact milestone values: 1M, 2M, 4M, 8M, 16M, 33M
    static let milestones: [Int: Color] = [
        1 << 20: Color(hex: "D31AAE"),  // 1M - Pink/Magenta
        1 << 21: Color(hex: "4A2890"),  // 2M - Darker Purple (was 6C3EBF)
        1 << 22: Color(hex: "FF6B6B"),  // 4M - Red
        1 << 23: Color(hex: "0F4A85"),  // 8M - Darker Blue (was 1E73C6)
        1 << 24: Color(hex: "F47C20"),  // 16M - Orange
        1 << 25: Color(hex: "C4D018")   // 33M - Yellow-Green
    ]
    
    // Text color overrides for milestone tiles
    static let whiteTextMilestones: Set<Int> = [
        1 << 20,  // 1M - White text
        1 << 21,  // 2M - White text
        1 << 22,  // 4M - White text
        1 << 23,  // 8M - White text
        1 << 24   // 16M - White text
    ]
    
    static let blackTextMilestones: Set<Int> = [
        1 << 25   // 33M - Black text (on yellow-green background)
    ]
    
    static func colorOverride(for value: Int) -> Color? {
        milestones[value]
    }
    
    static func textColorOverride(for value: Int) -> Color? {
        if whiteTextMilestones.contains(value) {
            return .white
        }
        if blackTextMilestones.contains(value) {
            return .black
        }
        return nil
    }
}

struct TileView: View {
    let tile: Tile?
    let isSelected: Bool
    let isValid: Bool
    let size: CGFloat
    var colorBlindMode: Bool = false
    var theme: ThemeDescriptor? = nil
    var useLegacyTypography: Bool = false   // NEW: allows restoring the old look
    
    var body: some View {
        // Special handling for infinity tile
        if tile?.isInfinity == true {
            InfinityTileView(size: size, isSelected: isSelected, isValid: isValid)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: tile?.value)
                .animation(.easeInOut(duration: 0.1), value: isSelected)
        } else {
            let content = AnyView(
                Group {
                    if let tile = tile {
                        if tile.isLocked {
                        ZStack {
                            numberText(for: tile.value, locked: true)
                            Image("lockpic")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                        }
                    } else if case .bomb(let turns) = tile.type {
                        ZStack {
                            numberText(for: tile.value, scale: 0.8)
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: size * 0.25, height: size * 0.25)
                                        Text("\(turns)")
                                            .font(.system(size: size * 0.15, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding(4)
                        }
                    } else if case .highValue(let step) = tile.type {
                        Text(JourneyTileGenerator.formatTileAtStep(step))
                            .font(baseFont(weight: .heavy, size: fontSize))
                            .foregroundColor(textColor)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText())
                            .kerning(kerning(for: Int.max))
                            .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                            .conditionalOverlay(colorBlindMode) { patternOverlay }
                    } else {
                        numberText(for: tile.value)
                            .conditionalOverlay(colorBlindMode) { patternOverlay }
                    }
                } else {
                    EmptyView()
                }
            }
        )
        
        ZStack {
            let maxRadius = size * 0.15
            
            if theme?.tileStyle == .raised3D {
                let radius = min(12, maxRadius)
                RoundedRectangle(cornerRadius: radius)
                    .fill(Color.clear)
                    .modifier(Tile3DStyle(
                        baseColor: backgroundColor,
                        isSelected: isSelected,
                        isValid: isValid,
                        tileShape: theme?.tileShape ?? .rounded
                    ))
                    .overlay(content)
            } else {
                let radius: CGFloat = {
                    let baseRadius: CGFloat
                    switch theme?.tileShape {
                    case .square: baseRadius = 8
                    case .rounded, .none: baseRadius = 12
                    }
                    return min(baseRadius, maxRadius)
                }()
                RoundedRectangle(cornerRadius: radius)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .strokeBorder(borderColor, lineWidth: isSelected ? 3 : 0)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                    .overlay(content)
            }
        }
        .frame(width: max(CGFloat(0), isFinite(size)), height: max(CGFloat(0), isFinite(size)))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: tile?.value)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
    }
    
    // MARK: - Number text builder
    
    @ViewBuilder
    private func numberText(for value: Int, locked: Bool = false, scale: CGFloat = 1.0) -> some View {
        let fontWeight: Font.Weight = .heavy
        let effectiveSize = fontSize * scale
        
        Text(TileLabelFormatter.format(value))
            .font(baseFont(weight: fontWeight, size: effectiveSize))
            .foregroundColor(locked ? textColor.opacity(0.5) : textColor)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText())
            .kerning(kerning(for: value))
            .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
    }
    
    private func baseFont(weight: Font.Weight, size: CGFloat) -> Font {
        var font = Font.system(size: size, weight: weight, design: .rounded)
        if useLegacyTypography {
            font = font.monospacedDigit()
        }
        return font
    }
    
    // MARK: - Colors and sizes
    
    private var backgroundColor: Color {
        guard let tile = tile else { return .gray.opacity(0.3) }
        if tile.isInfinity { return Color.purple }
        if tile.isLocked { return Color.gray.opacity(0.6) }
        if tile.isBomb { return Color.orange.opacity(0.8) }
        if case .highValue(let step) = tile.type {
            // For high-value (beyond Int.max), repeat the palette by step
            return Theme.colorForStep(step)
        }
        if let override = MilestoneAppearance.colorOverride(for: tile.value) { return override }
        if let theme { return theme.color(for: tile.value) }
        return Theme.color(for: tile.value)
    }
    
    private var borderColor: Color {
        guard isSelected else { return .clear }
        return isValid ? .green : .red
    }
    
    private var textColor: Color {
        guard let tile = tile else { return .clear }
        if case .highValue(let step) = tile.type {
            // Match text contrast for step-based color
            return Theme.textColorForStep(step)
        }
        // Check for milestone text color override first
        if let override = MilestoneAppearance.textColorOverride(for: tile.value) {
            return override
        }
        return Theme.textColor(for: tile.value)
    }
    
    private var fontSize: CGFloat {
        guard let tile = tile else { return size * 0.4 }
        let label: String = {
            switch tile.type {
            case .highValue(let step):
                return TileStepLabelFormatter.labelForStep(step)
            default:
                return TileLabelFormatter.format(tile.value)
            }
        }()
        let digitCount = label.count
        if useLegacyTypography {
            // Original mapping
            if digitCount <= 2 { return size * 0.40 }
            if digitCount == 3 { return size * 0.36 }
            if digitCount == 4 { return size * 0.32 }
            return size * 0.28
        } else {
            // Improved 8192 readability
            if digitCount <= 2 { return size * 0.40 }
            if digitCount == 3 { return size * 0.36 }
            if digitCount == 4 { return size * 0.34 }
            return size * 0.28
        }
    }
    
    private func kerning(for value: Int) -> CGFloat {
        guard !useLegacyTypography else { return 0.0 }
        let label: String
        if case .highValue(let step) = tile?.type {
            label = TileStepLabelFormatter.labelForStep(step)
        } else {
            label = TileLabelFormatter.format(value)
        }
        let count = label.count
        if count == 4 { return -1.0 }
        if count >= 5 { return -0.6 }
        return 0.0
    }
    
    private func isFinite(_ value: CGFloat) -> CGFloat {
        value.isFinite ? value : 0
    }
    
    private var patternOverlay: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            Path { path in
                var y: CGFloat = 0
                while y < h {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: w, y: y))
                    y += 6
                }
            }
            .stroke(Color.white.opacity(0.2), lineWidth: 1)
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

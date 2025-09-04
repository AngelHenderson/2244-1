import SwiftUI
import GameCore

struct TileView: View {
    let tile: Tile?
    let isSelected: Bool
    let isValid: Bool
    let size: CGFloat
    var colorBlindMode: Bool = false
    var theme: ThemeDescriptor? = nil
    
    var body: some View {
        let content = Group {
            if let tile = tile {
                if tile.isInfinity {
                    Image(systemName: "infinity")
                        .font(.system(size: fontSize * 1.2, weight: .bold))
                        .foregroundColor(textColor)
                } else if tile.isLocked {
                    ZStack {
                        Text(TileLabelFormatter.format(tile.value))
                            .font(.system(size: fontSize, weight: .bold, design: .rounded))
                            .foregroundColor(textColor.opacity(0.5))
                            .minimumScaleFactor(0.5)
                        Image("lockpic")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                    }
                } else if case .bomb(let turns) = tile.type {
                    ZStack {
                        Text(TileLabelFormatter.format(tile.value))
                            .font(.system(size: fontSize * 0.8, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                            .minimumScaleFactor(0.5)
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
                } else {
                    Text(TileLabelFormatter.format(tile.value))
                        .font(.system(size: fontSize, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundColor(textColor)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                        .overlay(
                            colorBlindMode ? patternOverlay : nil
                        )
                }
            }
        }
        
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
                    case .square:
                        baseRadius = 8
                    case .rounded, .none:
                        baseRadius = 12
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
    
    private var backgroundColor: Color {
        guard let tile = tile else { return .gray.opacity(0.3) }
        if tile.isInfinity {
            return Color.purple
        } else if tile.isLocked {
            return Color.gray.opacity(0.6)
        } else if tile.isBomb {
            return Color.orange.opacity(0.8)
        }
        if let theme { return theme.color(for: tile.value) }
        return Theme.color(for: tile.value)
    }
    
    private var borderColor: Color {
        guard isSelected else { return .clear }
        return isValid ? .green : .red
    }
    
    private var textColor: Color {
        guard let tile = tile else { return .clear }
        return Theme.textColor(for: tile.value)
    }
    
    private var fontSize: CGFloat {
        guard let tile = tile else { return size * 0.4 }
        let label = TileLabelFormatter.format(tile.value)
        let digitCount = label.count
        if digitCount <= 2 { return size * 0.40 }
        if digitCount == 3 { return size * 0.36 }
        if digitCount == 4 { return size * 0.32 }
        return size * 0.28
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

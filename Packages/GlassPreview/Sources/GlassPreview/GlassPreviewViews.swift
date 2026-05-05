import SwiftUI

// MARK: - Glass Preview UI Components

/// Main glass preview game view
public struct GlassGameView: View {
    @State private var gameStore: GlassGameStore
    @State private var showDebugHUD = false
    
    public init(gameStore: GlassGameStore = GlassGameStore()) {
        self._gameStore = State(wrappedValue: gameStore)
    }
    
    public var body: some View {
        ZStack {
            // Solid background color as specified
            Color(hex: gameStore.config.backgroundColorHex)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Score and stats
                HStack {
                    VStack(alignment: .leading) {
                        Text("Score: \(gameStore.score)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Moves: \(gameStore.moves)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Power-ups display
                    HStack {
                        ForEach(PowerUp.allCases, id: \.self) { powerUp in
                            if let count = gameStore.powerups[powerUp], count > 0 {
                                VStack {
                                    Text(powerUp.rawValue.capitalized)
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                    Text("\(count)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                                .padding(4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Preview row (above the main grid)
                GlassPreviewRow(gameStore: gameStore)
                
                // Main game grid
                GlassGameGrid(gameStore: gameStore)
                
                // Controls
                HStack {
                    Button("Reset") {
                        gameStore = GlassGameStore(seed: gameStore.sessionSeed + 1)
                    }
                    .padding()
                    .background(Color.red.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Button("Debug") {
                        showDebugHUD.toggle()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            
            // Debug HUD overlay
            if showDebugHUD {
                GlassDebugHUD(gameStore: gameStore, isVisible: $showDebugHUD)
            }
            
            // Game over overlay
            if gameStore.isGameOver {
                GameOverOverlay(gameStore: gameStore)
            }
        }
    }
}

/// Preview row showing upcoming tiles with glass effects
struct GlassPreviewRow: View {
    let gameStore: GlassGameStore
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<gameStore.cols, id: \.self) { col in
                VStack(spacing: 2) {
                    // Show next 1-2 preview tiles for this column
                    ForEach(0..<min(2, gameStore.preview[col].count), id: \.self) { index in
                        let tile = gameStore.preview[col][index]
                        GlassTileView(tile: tile, size: 40)
                            .onTapGesture {
                                if !tile.isGlass {
                                    // Allow interaction with non-glass preview tiles
                                    handlePreviewTileTap(col: col, index: index)
                                }
                            }
                    }
                }
                .frame(minWidth: 44)
            }
        }
        .padding(.horizontal)
    }
    
    private func handlePreviewTileTap(col: Int, index: Int) {
        // Create a preview point for chain building
        let previewPoint = Point(col: col, row: gameStore.rows + index)
        
        if gameStore.currentChain.isEmpty {
            // Can't start on preview tiles
            return
        } else {
            // Try to extend chain to preview tile
            gameStore.extendChain(to: previewPoint)
        }
    }
}

/// Main game grid with drag gesture support
struct GlassGameGrid: View {
    let gameStore: GlassGameStore
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<gameStore.rows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<gameStore.cols, id: \.self) { col in
                        let point = Point(col: col, row: row)
                        let tile = gameStore.grid[col][row].tile
                        let isInChain = gameStore.currentChain.contains(point)
                        
                        GlassTileView(
                            tile: tile,
                            size: 60,
                            isHighlighted: isInChain,
                            isEmpty: tile == nil
                        )
                        .onTapGesture {
                            handleTileTap(at: point)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .padding(.horizontal)
        .gesture(
            DragGesture(coordinateSpace: .local)
                .onChanged { value in
                    // Preview keeps drag state for visual feedback; tile
                    // selection in this demo uses taps for deterministic QA.
                    dragOffset = value.translation
                }
                .onEnded { _ in
                    dragOffset = .zero
                    if !gameStore.currentChain.isEmpty {
                        gameStore.commitChain()
                    }
                }
        )
        
        // Chain validation feedback
        if let validation = gameStore.chainValidation {
            Text(validation)
                .font(.caption)
                .foregroundColor(.red)
                .padding(.horizontal)
        }
    }
    
    private func handleTileTap(at point: Point) {
        if gameStore.currentChain.isEmpty {
            gameStore.beginChain(at: point)
        } else if gameStore.currentChain.contains(point) {
            // Tapped on existing chain tile - commit or cancel
            gameStore.commitChain()
        } else {
            gameStore.extendChain(to: point)
        }
    }
}

/// Individual tile view with glass effect
struct GlassTileView: View {
    let tile: GlassTile?
    let size: CGFloat
    var isHighlighted: Bool = false
    var isEmpty: Bool = false
    
    var body: some View {
        ZStack {
            // Base tile
            RoundedRectangle(cornerRadius: 8)
                .fill(tileColor)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isHighlighted ? Color.yellow : Color.clear, lineWidth: 2)
                )
            
            // Tile value
            if let tile = tile {
                Text("\(tile.value)")
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Glass overlay effect
            if let tile = tile, tile.isGlass {
                GlassOverlay(size: size)
            }
        }
        .scaleEffect(isHighlighted ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHighlighted)
    }
    
    private var tileColor: Color {
        guard let tile = tile else {
            return Color.gray.opacity(0.3)
        }
        
        // Color based on tile value
        switch tile.value {
        case 2: return Color.orange
        case 4: return Color.orange.opacity(0.8)
        case 8: return Color.pink
        case 16: return Color.purple.opacity(0.8)
        case 32: return Color.red.opacity(0.8)
        case 64: return Color.purple
        case 128: return Color.teal
        case 256: return Color.red
        case 512: return Color.yellow.opacity(0.8)
        case 1024: return Color.green
        case 2048: return Color.red
        case 4096: return Color.blue
        default: return Color.gray
        }
    }
}

/// Glass overlay effect for preview tiles
struct GlassOverlay: View {
    let size: CGFloat
    @State private var shimmer: Bool = false
    
    var body: some View {
        ZStack {
            // Glass reflection effect
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Shimmer animation
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(shimmer ? 0.6 : 0.2),
                            Color.clear
                        ],
                        startPoint: shimmer ? .topLeading : .bottomTrailing,
                        endPoint: shimmer ? .bottomTrailing : .topLeading
                    )
                )
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                shimmer.toggle()
            }
        }
    }
}

/// Game over overlay
struct GameOverOverlay: View {
    let gameStore: GlassGameStore
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Game Over")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Final Score: \(gameStore.score)")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Moves: \(gameStore.moves)")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                
                Button("Play Again") {
                    // Reset game - this would need to be handled by parent view
                    // let newStore = GlassGameStore(seed: gameStore.sessionSeed + 1)
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

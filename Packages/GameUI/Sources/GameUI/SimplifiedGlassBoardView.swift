import SwiftUI
import GameCore
import GameApp

// MARK: - Simplified Glass Board View (Visual Only)
public struct SimplifiedGlassBoardView: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.hapticsService) private var haptics
    @Environment(\.colorBlindMode) private var colorBlindMode
    @Environment(\.currentTheme) private var currentTheme
    
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging = false
    @State private var glassPreviewValues: [Int] = []
    
    private let spacing: CGFloat = 6
    private let cornerRadius: CGFloat = 12
    private let onTileTap: ((Position) -> Void)?
    
    public init(onTileTap: ((Position) -> Void)? = nil) {
        self.onTileTap = onTileTap
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let tileSize = calculateTileSize(in: geometry.size)
            
            ZStack(alignment: .top) {
                // Main Board (existing implementation) - no background, transparent
                ZStack {
                    boardGrid(tileSize: tileSize, containerSize: geometry.size)
                    pathOverlay(tileSize: tileSize, containerSize: geometry.size)
                }
                .zIndex(0)

                // Glass Preview Row overlay at the top with subtle glass effect
                SimpleGlassPreviewRow(
                    tileSize: min(tileSize, 52),
                    spacing: spacing,
                    columnCount: gameStore.state.board.width
                )
                .padding(.horizontal, spacing)
                .padding(.top, 4)
                .background(
                    // Very subtle glass effect that doesn't block the theme
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.05))
                        .blur(radius: 1)
                )
                .opacity(0.96)
                .allowsHitTesting(false)
                .zIndex(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
    }
    
    @ViewBuilder
    private func boardGrid(tileSize: CGFloat, containerSize: CGSize) -> some View {
        VStack(spacing: spacing) {
            let currentMax: Int = {
                var maxVal = 0
                for r in 0..<gameStore.state.board.height {
                    for c in 0..<gameStore.state.board.width {
                        let p = Position(row: r, col: c)
                        if let t = gameStore.state.board[p], t.value > maxVal { maxVal = t.value }
                    }
                }
                return maxVal
            }()
            
            ForEach(0..<gameStore.state.board.height, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<gameStore.state.board.width, id: \.self) { col in
                        let position = Position(row: row, col: col)
                        ZStack {
                            TileView(
                                tile: gameStore.state.board[position],
                                isSelected: gameStore.currentPath.contains(position),
                                isValid: gameStore.pathValidation.isValid,
                                size: tileSize,
                                colorBlindMode: colorBlindMode,
                                theme: currentTheme
                            )
                            if let t = gameStore.state.board[position], t.value == currentMax {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: max(10, tileSize * 0.28), weight: .bold))
                                    .foregroundStyle(.yellow)
                                    .offset(y: -tileSize * 0.45)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTileTap?(position)
                        }
                    }
                }
            }
        }
        .padding(spacing)
        .contentShape(Rectangle())
        .simultaneousGesture(
            dragGesture(
                tileSize: tileSize,
                containerSize: gridFrameSize(for: tileSize)
            )
        )
    }
    
    @ViewBuilder
    private func pathOverlay(tileSize: CGFloat, containerSize: CGSize) -> some View {
        if tileSize > 0, !gameStore.currentPath.isEmpty {
            Path { path in
                for (index, position) in gameStore.currentPath.enumerated() {
                    let point = centerPoint(for: position, tileSize: tileSize, containerSize: containerSize)
                    
                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(style: StrokeStyle(lineWidth: Tokens.Size.pathWidth, lineCap: .round, lineJoin: .round))
            .foregroundStyle(
                LinearGradient(
                    colors: gameStore.pathValidation.isValid ? [Color.white.opacity(0.9), Color.green] : [Color.white.opacity(0.9), Color.red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .shadow(color: (gameStore.pathValidation.isValid ? Color.green : Color.red).opacity(0.45), radius: 6)
            .animation(.easeInOut(duration: 0.1), value: gameStore.currentPath)
            .allowsHitTesting(false)
        }
    }
    
    // Rest of implementation (drag gesture, calculations) same as BoardView...
    private func dragGesture(tileSize: CGFloat, containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard tileSize > 0 else { return }
                let position = gridPosition(from: value.location, tileSize: tileSize, containerSize: containerSize)
                
                if !isDragging {
                    isDragging = true
                    if let position = position, gameStore.state.board[position] != nil {
                        gameStore.beginPath(at: position)
                        haptics.lightImpact()
                    }
                } else if let position = position, gameStore.state.board[position] != nil {
                    if let existingIndex = gameStore.currentPath.firstIndex(of: position) {
                        while gameStore.currentPath.count > existingIndex + 1 {
                            gameStore.backtrackPath()
                        }
                        haptics.lightImpact()
                    } else {
                        gameStore.extendPath(to: position)
                        if gameStore.pathValidation.isValid {
                            haptics.lightImpact()
                        } else {
                            haptics.warning()
                        }
                    }
                }
                
                dragLocation = value.location
            }
            .onEnded { _ in
                if gameStore.pathValidation.isValid && gameStore.currentPath.count >= 2 {
                    gameStore.commitPath()
                    haptics.success()
                } else {
                    gameStore.cancelPath()
                    if gameStore.currentPath.count >= 2 {
                        haptics.error()
                    }
                }
                isDragging = false
            }
    }
    
    private func calculateTileSize(in size: CGSize) -> CGFloat {
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return 0 }
        let widthCount = max(1, gameStore.state.board.width)
        let heightCount = max(1, gameStore.state.board.height)
        
        // No need to reserve space - glass row is overlaid
        let adjustedHeight = size.height
        
        let totalSpacingW = spacing * CGFloat(widthCount + 1)
        let totalSpacingH = spacing * CGFloat(heightCount + 1)
        let availableWidth = max(0, size.width - totalSpacingW)
        let availableHeight = max(0, adjustedHeight - totalSpacingH)
        let tileWidth = availableWidth / CGFloat(widthCount)
        let tileHeight = availableHeight / CGFloat(heightCount)
        let candidate = min(tileWidth, tileHeight)
        return candidate.isFinite ? max(0, candidate) : 0
    }
    
    private func gridPosition(from location: CGPoint, tileSize: CGFloat, containerSize: CGSize) -> Position? {
        let origin = gridOrigin(in: containerSize, tileSize: tileSize)
        let localX = location.x - origin.x
        let localY = location.y - origin.y
        
        var foundCol: Int? = nil
        var foundRow: Int? = nil
        
        for col in 0..<gameStore.state.board.width {
            let tileStartX = spacing + CGFloat(col) * (tileSize + spacing)
            let tileEndX = tileStartX + tileSize
            
            if localX >= tileStartX && localX <= tileEndX {
                foundCol = col
                break
            }
        }
        
        for row in 0..<gameStore.state.board.height {
            let tileStartY = spacing + CGFloat(row) * (tileSize + spacing)
            let tileEndY = tileStartY + tileSize
            
            if localY >= tileStartY && localY <= tileEndY {
                foundRow = row
                break
            }
        }
        
        guard let col = foundCol, let row = foundRow else { return nil }
        
        let position = Position(row: row, col: col)
        return position.isValid(for: gameStore.state.board) ? position : nil
    }
    
    private func centerPoint(for position: Position, tileSize: CGFloat, containerSize: CGSize) -> CGPoint {
        let origin = gridOrigin(in: containerSize, tileSize: tileSize)
        let x = origin.x + spacing + CGFloat(position.col) * (tileSize + spacing) + tileSize / 2
        let y = origin.y + spacing + CGFloat(position.row) * (tileSize + spacing) + tileSize / 2
        return CGPoint(x: x, y: y)
    }
    
    private func gridOrigin(in containerSize: CGSize, tileSize: CGFloat) -> CGPoint {
        let widthCount = max(1, gameStore.state.board.width)
        let heightCount = max(1, gameStore.state.board.height)
        let totalTilesWidth = CGFloat(widthCount) * tileSize + CGFloat(max(0, widthCount - 1)) * spacing
        let totalTilesHeight = CGFloat(heightCount) * tileSize + CGFloat(max(0, heightCount - 1)) * spacing
        let boardWidth = totalTilesWidth + 2 * spacing
        let boardHeight = totalTilesHeight + 2 * spacing
        let originX = (containerSize.width - boardWidth) / 2
        let originY = (containerSize.height - boardHeight) / 2
        return CGPoint(x: originX, y: originY)
    }

    private func gridFrameSize(for tileSize: CGFloat) -> CGSize {
        let widthCount = max(1, gameStore.state.board.width)
        let heightCount = max(1, gameStore.state.board.height)
        let totalTilesWidth = CGFloat(widthCount) * tileSize + CGFloat(max(0, widthCount - 1)) * spacing
        let totalTilesHeight = CGFloat(heightCount) * tileSize + CGFloat(max(0, heightCount - 1)) * spacing
        let boardWidth = totalTilesWidth + 2 * spacing
        let boardHeight = totalTilesHeight + 2 * spacing
        return CGSize(width: boardWidth, height: boardHeight)
    }
}


// MARK: - Simple Glass Preview Row (Visual Only)

struct SimpleGlassPreviewRow: View {
    let tileSize: CGFloat
    let spacing: CGFloat
    let columnCount: Int
    
    @State private var previewValues: [Int] = []
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<columnCount, id: \.self) { col in
                SimpleGlassPreviewTile(
                    value: previewValue(for: col),
                    size: tileSize
                )
            }
        }
        .onAppear {
            generatePreviewValues()
        }
    }
    
    private func previewValue(for column: Int) -> Int {
        guard column < previewValues.count else {
            return [2, 4, 8, 16, 32, 64, 128].randomElement() ?? 2
        }
        return previewValues[column]
    }
    
    private func generatePreviewValues() {
        previewValues = (0..<columnCount).map { _ in
            [2, 4, 8, 16, 32, 64, 128].randomElement() ?? 2
        }
    }
}

// MARK: - Simple Glass Preview Tile

struct SimpleGlassPreviewTile: View {
    let value: Int
    let size: CGFloat
    
    @State private var shimmer = false
    @State private var anchorPulse = false
    
    var body: some View {
        // Use 15% of tile size for corner radius to ensure rounded squares, not circles
        let cornerRadius = min(size * 0.15, 12) // Cap at 12 points max
        
        ZStack {
            // Base tile
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(tileColor)
                .frame(width: size, height: size)
                .shadow(color: Color.black.opacity(0.35), radius: 8, y: 3)
            
            // Value text
            Text(TileLabelFormatter.format(value))
                .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
            
            // Enhanced glass effect
            ZStack {
                // Glass base with bubble effect
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.cyan.opacity(0.15),
                                Color.white.opacity(0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Enhanced shimmer
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(shimmer ? 0.5 : 0.15),
                                Color.clear
                            ],
                            startPoint: shimmer ? .topLeading : .bottomTrailing,
                            endPoint: shimmer ? .bottomTrailing : .topLeading
                        )
                    )
                    .onAppear {
                        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                            shimmer.toggle()
                        }
                    }
                
                // Glass bubble highlights
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: size * 0.3
                        )
                    )
                    .frame(width: size * 0.5, height: size * 0.5)
                    .offset(x: -size * 0.2, y: -size * 0.2)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.clear
                            ],
                            center: .bottomTrailing,
                            startRadius: 0,
                            endRadius: size * 0.2
                        )
                    )
                    .frame(width: size * 0.3, height: size * 0.3)
                    .offset(x: size * 0.25, y: size * 0.25)
                
                // Glass edge
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.8),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
            }
            .frame(width: size, height: size)
            
            // Gift indicator
            Image(systemName: "gift.fill")
                .font(.system(size: size * 0.2))
                .foregroundColor(.yellow)
                .shadow(color: .black.opacity(0.3), radius: 2)
                .offset(x: size * 0.3, y: -size * 0.3)
        }
        .opacity(0.98)
    }
    
    private var tileColor: Color {
        Theme.color(for: value)
    }
}

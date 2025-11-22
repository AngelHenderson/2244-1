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
    @State private var magnetAnimations: [MagnetAnimationModel] = []
    @Namespace private var tileNamespace
    
    private let spacing: CGFloat = 12
    private let cornerRadius: CGFloat = 12
    private let onTileTap: ((Position) -> Void)?
    
    public init(onTileTap: ((Position) -> Void)? = nil) {
        self.onTileTap = onTileTap
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let tileSize = calculateTileSize(in: geometry.size)
            
            ZStack {
                boardGrid(tileSize: tileSize, containerSize: geometry.size)
                pathOverlay(tileSize: tileSize, containerSize: geometry.size)
                mergeAnimationOverlay(tileSize: tileSize, containerSize: geometry.size)
                magnetOverlay(tileSize: tileSize, containerSize: geometry.size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                dragGesture(
                    tileSize: tileSize,
                    containerSize: gridFrameSize(for: tileSize)
                ),
                including: .all
            )
            .onChange(of: gameStore.lastMagnetEvent) { _, newValue in
                if let event = newValue {
                    startMagnetAnimations(for: event)
                }
            }
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
            
            // All board rows including glass preview row as first row
            ForEach(0..<gameStore.state.board.height, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<gameStore.state.board.width, id: \.self) { col in
                        let position = Position(row: row, col: col)
                        
                        if row == 0 {
                            // First row with glass effect
                            ZStack {
                                if let tile = gameStore.state.board[position] {
                                    TileView(
                                        tile: tile,
                                        isSelected: gameStore.currentPath.contains(position),
                                        isValid: gameStore.pathValidation.isValid,
                                        size: tileSize,
                                        colorBlindMode: colorBlindMode,
                                        theme: currentTheme
                                    )
                                    .opacity((isAnimating(position) || gameStore.pendingGiftBoxes[position] != nil) ? 0 : 1)
                                    .matchedGeometryEffect(id: tile.id, in: tileNamespace)
                                }
                                
                                // Glass overlay effect - only show if glass hasn't been broken
                                if !gameStore.brokenGlassTiles.contains(position) {
                                    glassOverlay(for: tileSize)
                                }
                                
                                // Gift indicator (only while glass intact)
                                if gameStore.pendingGiftBoxes[position] == nil {
                                    Image(systemName: "gift.fill")
                                        .font(.system(size: tileSize * 0.2))
                                        .foregroundColor(.yellow)
                                        .shadow(color: .black.opacity(0.3), radius: 2)
                                        .offset(x: tileSize * 0.3, y: -tileSize * 0.3)
                                }
                                
                                if let t = gameStore.state.board[position], t.value == currentMax {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: max(10, tileSize * 0.28), weight: .bold))
                                        .foregroundStyle(.yellow)
                                        .offset(y: -tileSize * 0.45)
                                }
                                
                                if gameStore.pendingGiftBoxes[position] != nil {
                                    GiftBoxOverlay(size: tileSize)
                                        .onTapGesture {
                                            haptics.success()
                                            gameStore.tapGiftBox(at: position)
                                        }
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard gameStore.pendingGiftBoxes[position] == nil else { return }
                                onTileTap?(position)
                            }
                        } else {
                            // Regular tiles for other rows
                            ZStack {
                                if let tile = gameStore.state.board[position] {
                                    TileView(
                                        tile: tile,
                                        isSelected: gameStore.currentPath.contains(position),
                                        isValid: gameStore.pathValidation.isValid,
                                        size: tileSize,
                                        colorBlindMode: colorBlindMode,
                                        theme: currentTheme
                                    )
                                    .opacity((isAnimating(position) || gameStore.pendingGiftBoxes[position] != nil) ? 0 : 1)
                                    .matchedGeometryEffect(id: tile.id, in: tileNamespace)
                                }
                                if let t = gameStore.state.board[position], t.value == currentMax {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: max(10, tileSize * 0.28), weight: .bold))
                                        .foregroundStyle(.yellow)
                                        .offset(y: -tileSize * 0.45)
                                }
                                
                                if gameStore.pendingGiftBoxes[position] != nil {
                                    GiftBoxOverlay(size: tileSize)
                                        .onTapGesture {
                                            haptics.success()
                                            gameStore.tapGiftBox(at: position)
                                        }
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard gameStore.pendingGiftBoxes[position] == nil else { return }
                                onTileTap?(position)
                            }
                        }
                    }
                }
            }
        }
        .padding(spacing)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: gameStore.state.board)
    }
    
    @ViewBuilder
    private func glassOverlay(for size: CGFloat) -> some View {
        let cornerRadius = min(size * 0.15, 12)
        
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
        .opacity(0.98)
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
                    colors: [Color.white.opacity(0.9), Color.green],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .shadow(color: Color.green.opacity(0.45), radius: 6)
            .animation(.easeInOut(duration: 0.1), value: gameStore.currentPath)
            .allowsHitTesting(false)
        }
    }
    
    @ViewBuilder
    private func magnetOverlay(tileSize: CGFloat, containerSize: CGSize) -> some View {
        if tileSize > 0, !magnetAnimations.isEmpty {
            ForEach(magnetAnimations) { animation in
                let startPoint = centerPoint(for: animation.start, tileSize: tileSize, containerSize: containerSize)
                let endPoint = centerPoint(for: animation.target, tileSize: tileSize, containerSize: containerSize)

                // Calculate the current position based on the animation's progress.
                let currentPoint = CGPoint(
                    x: startPoint.x + (endPoint.x - startPoint.x) * animation.progress,
                    y: startPoint.y + (endPoint.y - startPoint.y) * animation.progress
                )
                
                TileView(
                    tile: Tile(value: animation.value),
                    isSelected: false,
                    isValid: true,
                    size: tileSize,
                    colorBlindMode: colorBlindMode,
                    theme: currentTheme
                )
                .position(currentPoint)
                .opacity(1.0 - animation.progress) // Fades out as it nears the target
            }
        }
    }
    
    @ViewBuilder
    private func mergeAnimationOverlay(tileSize: CGFloat, containerSize: CGSize) -> some View {
        if let state = gameStore.mergeAnimationState {
            MergeAnimationView(
                state: state,
                tileSize: tileSize,
                spacing: spacing,
                containerSize: containerSize,
                boardWidth: gameStore.state.board.width,
                boardHeight: gameStore.state.board.height
            )
        }
    }
    
    // Rest of implementation (drag gesture, calculations) same as BoardView...
    private func dragGesture(tileSize: CGFloat, containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard tileSize > 0 else { return }
                guard !gameStore.isInputLocked else { return }
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
        
        let totalSpacingW = spacing * CGFloat(widthCount + 1)
        let totalSpacingH = spacing * CGFloat(heightCount + 1)
        let availableWidth = max(0, size.width - totalSpacingW)
        let availableHeight = max(0, size.height - totalSpacingH)
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
    
    private func startMagnetAnimations(for event: GameStore.MagnetEvent) {
        let contributors = event.sources.filter { $0 != event.target }
        guard !contributors.isEmpty else {
            gameStore.clearLastMagnetEvent()
            return
        }
        magnetAnimations = contributors.map { MagnetAnimationModel(value: event.value, start: $0, target: event.target, progress: 0) }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.35)) {
                for index in magnetAnimations.indices {
                    magnetAnimations[index].progress = 1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                magnetAnimations.removeAll()
                gameStore.clearLastMagnetEvent()
            }
        }
    }
    
    private func isAnimating(_ position: Position) -> Bool {
        guard let state = gameStore.mergeAnimationState else { return false }
        return state.sourcePositions.contains(position)
    }
}

private struct MagnetAnimationModel: Identifiable, Equatable {
    let id = UUID()
    let value: Int
    let start: Position
    let target: Position
    var progress: CGFloat
}


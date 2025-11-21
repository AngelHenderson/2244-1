import SwiftUI
import GameCore
import GameApp
import GameServices

public struct BoardView: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.hapticsService) private var haptics
    @Environment(\.colorBlindMode) private var colorBlindMode
    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.audio) private var audioService
    
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging = false
    
    private let spacing: CGFloat = 8
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
    }
    
    @ViewBuilder
    private func boardGrid(tileSize: CGFloat, containerSize: CGSize) -> some View {
        VStack(spacing: spacing) {
            // Compute current max tile value
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
                            .opacity(isAnimating(position) ? 0 : 1)
                            if let t = gameStore.state.board[position], t.value == currentMax {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: max(10, tileSize * 0.28), weight: .bold))
                                    .foregroundStyle(.yellow)
                                    .offset(y: -tileSize * 0.45)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task { await audioService.playSfx(name: "tap") }
                            onTileTap?(position)
                        }
                    }
                }
            }
        }
        .padding(spacing)
        .contentShape(Rectangle())
        // IMPORTANT: The drag gesture is attached to this grid view, whose
        // coordinate space is the grid's local bounds (including its padding).
        // To correctly map touch locations to tiles, pass the grid's own size,
        // not the outer GeometryReader size. This keeps gridOrigin at (0,0).
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
                    colors: [Color.white.opacity(0.9), Color.green],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .shadow(color: Color.green.opacity(0.45), radius: 6)
            .animation(.easeInOut(duration: 0.1), value: gameStore.currentPath)
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
    
    private func isAnimating(_ position: Position) -> Bool {
        guard let state = gameStore.mergeAnimationState else { return false }
        return state.sourcePositions.contains(position)
    }
    
    private func dragGesture(tileSize: CGFloat, containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !gameStore.isInputLocked else { return }
                guard tileSize > 0 else { return }
                let position = gridPosition(from: value.location, tileSize: tileSize, containerSize: containerSize)
                
                if !isDragging {
                    isDragging = true
                    if let position = position, gameStore.state.board[position] != nil {
                        gameStore.beginPath(at: position)
                        haptics.lightImpact()
                        Task { await audioService.playSfx(name: "select") }
                    }
                } else if let position = position, gameStore.state.board[position] != nil {
                    // Backtrack while dragging: if moving to a previously selected tile,
                    // prune the path back to that tile; otherwise extend when adjacent.
                    if let existingIndex = gameStore.currentPath.firstIndex(of: position) {
                        // If we moved back to an earlier tile, prune back
                        while gameStore.currentPath.count > existingIndex + 1 {
                            gameStore.backtrackPath()
                        }
                        haptics.lightImpact()
                    } else {
                        gameStore.extendPath(to: position)
                        if gameStore.pathValidation.isValid {
                            haptics.lightImpact()
                            Task { await audioService.playSfx(name: "drag") }
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
        // Find which tile contains this touch point
        // Each tile starts at: spacing + index * (tileSize + spacing)
        // And extends for tileSize pixels
        
        let origin = gridOrigin(in: containerSize, tileSize: tileSize)
        let localX = location.x - origin.x
        let localY = location.y - origin.y
        
        var foundCol: Int? = nil
        var foundRow: Int? = nil
        
        // Check each column to find which tile contains the x coordinate
        for col in 0..<gameStore.state.board.width {
            let tileStartX = spacing + CGFloat(col) * (tileSize + spacing)
            let tileEndX = tileStartX + tileSize
            
            if localX >= tileStartX && localX <= tileEndX {
                foundCol = col
                break
            }
        }
        
        // Check each row to find which tile contains the y coordinate
        for row in 0..<gameStore.state.board.height {
            let tileStartY = spacing + CGFloat(row) * (tileSize + spacing)
            let tileEndY = tileStartY + tileSize
            
            if localY >= tileStartY && localY <= tileEndY {
                foundRow = row
                break
            }
        }
        
        // Only return a position if we found both a valid row and column
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
        let boardWidth = totalTilesWidth + 2 * spacing // account for .padding(spacing)
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
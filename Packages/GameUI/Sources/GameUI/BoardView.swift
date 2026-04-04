import SwiftUI
import GameCore
import GameApp

/// Pairs a tile with its board position for the ZStack tile layer
private struct BoardTileItem: Identifiable {
    let id: UUID
    let tile: Tile
    let position: Position
}

public struct BoardView: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.hapticsService) private var haptics
    @Environment(\.colorBlindMode) private var colorBlindMode
    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.audio) private var audioService
    
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging = false
    @State private var magnetAnimations: [MagnetAnimationModel] = []
    
    private let spacing: CGFloat = 8
    private let cornerRadius: CGFloat = 12
    private let onTileTap: ((Position) -> Void)?
    private let isPowerUpActive: Bool

    public init(onTileTap: ((Position) -> Void)? = nil, isPowerUpActive: Bool = false) {
        self.onTileTap = onTileTap
        self.isPowerUpActive = isPowerUpActive
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let tileSize = calculateTileSize(in: geometry.size)
            
            ZStack {
                boardGrid(tileSize: tileSize, containerSize: geometry.size)
                pathOverlay(tileSize: tileSize, containerSize: geometry.size)
                mergeAnimationOverlay(tileSize: tileSize, containerSize: geometry.size)
                magnetOverlay(tileSize: tileSize, containerSize: geometry.size)
                hammerOverlay(tileSize: tileSize, containerSize: geometry.size)
                milestoneEliminationOverlay(tileSize: tileSize, containerSize: geometry.size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onChange(of: gameStore.lastMagnetEvent) { _, newValue in
                if let event = newValue {
                    startMagnetAnimations(for: event, tileSize: tileSize)
                }
            }
            .onChange(of: gameStore.hammerAnimationState?.phase) { _, newPhase in
                if newPhase == .impact {
                    Task { await audioService.playSfx(name: "hammer") }
                }
            }
        }
    }
    
    /// Compute current max tile step on the board (handles highValue tiles correctly)
    private var currentMaxStep: Int {
        var maxStep = -1
        for r in 0..<gameStore.state.board.height {
            for c in 0..<gameStore.state.board.width {
                let p = Position(row: r, col: c)
                if let t = gameStore.state.board[p], let step = t.stepIndex, step > maxStep {
                    maxStep = step
                }
            }
        }
        return maxStep
    }

    @ViewBuilder
    private func boardGrid(tileSize: CGFloat, containerSize: CGSize) -> some View {
        let maxStep = currentMaxStep  // Capture for use in view builder
        ZStack {
            // Layer 1: Cell backgrounds, tap handlers, crowns, gift boxes
            VStack(spacing: spacing) {
                ForEach(0..<gameStore.state.board.height, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<gameStore.state.board.width, id: \.self) { col in
                            let position = Position(row: row, col: col)
                            ZStack {
                                // Empty cell background
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .fill(Color.white.opacity(0.08))

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
                                if !isPowerUpActive {
                                    Task { await audioService.playSfx(name: "tap") }
                                }
                                onTileTap?(position)
                            }
                        }
                    }
                }
            }
            .padding(spacing)

            // Layer 2: Tiles in a ZStack, identified by tile UUID
            ForEach(allTilesWithPositions, id: \.id) { item in
                TileView(
                    tile: item.tile,
                    isSelected: gameStore.currentPath.contains(item.position),
                    isValid: gameStore.pathValidation.isValid,
                    size: tileSize,
                    colorBlindMode: colorBlindMode,
                    theme: currentTheme
                )
                .frame(width: tileSize, height: tileSize)
                .saturation(gameStore.gameOverConfirmed ? 0.0 : 1.0)
                .opacity(shouldHideTile(at: item.position) ? 0 : 1)
                .position(centerPoint(for: item.position, tileSize: tileSize, containerSize: containerSize))
                .transition(.identity)
                // Position animation
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: item.position)
                // Game over grayscale animation
                .animation(.easeInOut(duration: 1.5), value: gameStore.state.isGameOver)
                .allowsHitTesting(false)
            }

            // Layer 3: Crown indicators (above tiles)
            ForEach(0..<gameStore.state.board.height, id: \.self) { row in
                ForEach(0..<gameStore.state.board.width, id: \.self) { col in
                    let position = Position(row: row, col: col)
                    if let t = gameStore.state.board[position], t.stepIndex == maxStep {
                        Image(systemName: "crown.fill")
                            .font(.system(size: max(10, tileSize * 0.28), weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(white: 0.85), Color(white: 0.55)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .position(
                                x: centerPoint(for: position, tileSize: tileSize, containerSize: containerSize).x,
                                y: centerPoint(for: position, tileSize: tileSize, containerSize: containerSize).y - tileSize * 0.45
                            )
                            .allowsHitTesting(false)
                    }
                }
            }
        }
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

    /// All tiles currently on the board with their positions, for the ZStack tile layer
    private var allTilesWithPositions: [BoardTileItem] {
        var items: [BoardTileItem] = []
        for row in 0..<gameStore.state.board.height {
            for col in 0..<gameStore.state.board.width {
                let pos = Position(row: row, col: col)
                if let tile = gameStore.state.board[pos] {
                    items.append(BoardTileItem(id: tile.id, tile: tile, position: pos))
                }
            }
        }
        return items
    }
    
    @ViewBuilder
    private func pathOverlay(tileSize: CGFloat, containerSize: CGSize) -> some View {
        if tileSize > 0, !gameStore.currentPath.isEmpty {
            Path { path in
                // Draw lines between established connected tiles
                for (index, position) in gameStore.currentPath.enumerated() {
                    let point = centerPoint(for: position, tileSize: tileSize, containerSize: containerSize)
                    
                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
                
                // If the user is dragging, draw an extension "pipe" to the finger
                if isDragging, gameStore.currentPath.last != nil {
                    path.addLine(to: dragLocation)
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
            .allowsHitTesting(false)
        }
    }
    
    @ViewBuilder
    private func magnetOverlay(tileSize: CGFloat, containerSize: CGSize) -> some View {
        if tileSize > 0, !magnetAnimations.isEmpty {
            ZStack {
                ForEach(magnetAnimations) { animation in
                    let startPoint = centerPoint(for: animation.start, tileSize: tileSize, containerSize: containerSize)
                    let endPoint = centerPoint(for: animation.target, tileSize: tileSize, containerSize: containerSize)
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
                    .opacity(1.0 - animation.progress)
                }
            }
            .allowsHitTesting(false)
        }
    }
    
    @ViewBuilder
    private func hammerOverlay(tileSize: CGFloat, containerSize: CGSize) -> some View {
        if tileSize > 0, let state = gameStore.hammerAnimationState {
            let center = centerPoint(for: state.target, tileSize: tileSize, containerSize: containerSize)
            let offset = hammerOffset(for: state.phase, tileSize: tileSize)
            let rotation = hammerRotation(for: state.phase)
            let hammerSize = max(24, tileSize * 0.8)
            
            Image(systemName: "hammer.fill")
                .font(.system(size: hammerSize))
                .foregroundStyle(Color.orange)
                .shadow(color: .orange.opacity(0.4), radius: 6, x: 0, y: 4)
                .rotationEffect(rotation)
                .position(x: center.x + offset.width, y: center.y + offset.height)
                .animation(.easeInOut(duration: 0.18), value: state.phase)
                .allowsHitTesting(false)
        }
    }
    
    private func isAnimating(_ position: Position) -> Bool {
        guard let state = gameStore.mergeAnimationState else { return false }
        return state.sourcePositions.contains(position)
    }
    
    private func shouldHideTile(at position: Position) -> Bool {
        if isAnimating(position) { return true }
        if gameStore.pendingGiftBoxes[position] != nil { return true }
        if gameStore.pendingRefillPositions.contains(position) { return true }
        return false
    }

    @ViewBuilder
    private func milestoneEliminationOverlay(tileSize: CGFloat, containerSize: CGSize) -> some View {
        // Show ghost tiles for eliminated tiles (they fade out after milestone elimination)
        // These tiles have already been removed from the board, so we render them as an overlay
        if tileSize > 0 {
            ZStack {
                ForEach(gameStore.milestoneEliminatedTiles, id: \.position) { info in
                    let center = centerPoint(for: info.position, tileSize: tileSize, containerSize: containerSize)
                    EliminationGhostTile(
                        value: info.value,
                        size: tileSize,
                        colorBlindMode: colorBlindMode,
                        theme: currentTheme
                    )
                    .position(center)
                }
            }
            .allowsHitTesting(false)
        }
    }
    
    private func dragGesture(tileSize: CGFloat, containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                debugLog("drag changed", extra: "location=\(value.location)")
                guard !gameStore.isInputLocked else {
                    debugLog("drag ignored - input locked")
                    return
                }
                guard tileSize > 0 else {
                    debugLog("drag ignored - tileSize <= 0")
                    return
                }
                let position = gridPosition(from: value.location, tileSize: tileSize, containerSize: containerSize)
                
                if !isDragging {
                    isDragging = true
                    guard !isPowerUpActive else { return }
                    if let position = position, gameStore.state.board[position] != nil {
                        gameStore.beginPath(at: position)
                        haptics.lightImpact()
                        Task { await audioService.playSfx(name: "select") }
                    }
                } else if let position = position, gameStore.state.board[position] != nil {
                    // Backtrack while dragging: only prune back when the finger
                    // returns to the second-to-last tile (the immediate predecessor).
                    // This prevents the path from snapping back when the finger
                    // casually crosses distant earlier tiles while dragging forward.
                    if let existingIndex = gameStore.currentPath.firstIndex(of: position),
                       existingIndex == gameStore.currentPath.count - 2 {
                        // Moved back to the immediately previous tile — undo one step
                        gameStore.backtrackPath()
                        haptics.lightImpact()
                    } else if gameStore.currentPath.contains(position) {
                        // Finger is over a tile already in the path but NOT the predecessor —
                        // just update dragLocation so the pipe visually extends over it.
                        // Do nothing to the path.
                    } else {
                        let appended = gameStore.extendPath(to: position)
                        if appended {
                            haptics.lightImpact()
                            Task { await audioService.playSfx(name: "chain") }
                        }
                    }
                }
                
                dragLocation = value.location
            }
            .onEnded { _ in
                debugLog("drag ended", extra: "valid=\(gameStore.pathValidation.isValid) pathCount=\(gameStore.currentPath.count)")
                if gameStore.pathValidation.isValid && gameStore.currentPath.count >= 2 {
                    let tileCount = gameStore.currentPath.count
                    gameStore.commitPath()
                    haptics.success()
                    Task { await audioService.playMergeSfx(tileCount: tileCount) }
                } else {
                    gameStore.cancelPath()
                    if gameStore.currentPath.count >= 2 {
                        haptics.error()
                    }
                }
                isDragging = false
            }
    }
    
    private func debugLog(_ message: String, extra: String = "") {
        #if DEBUG
        print("[BoardView]", message,
              "| isInputLocked:", gameStore.isInputLocked,
              "| pathCount:", gameStore.currentPath.count,
              extra.isEmpty ? "" : "| \(extra)")
        #endif
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
        // Snap to the nearest tile center instead of rejecting touches in spacing gaps.
        // This makes diagonal connections as easy as orthogonal ones.
        let localX = location.x - spacing
        let localY = location.y - spacing

        guard localX >= -spacing / 2, localY >= -spacing / 2 else { return nil }

        let blockWidth = tileSize + spacing
        let blockHeight = tileSize + spacing

        // Round to the nearest tile index (snap to closest tile center).
        let col = Int(round((localX - tileSize / 2) / blockWidth))
        let row = Int(round((localY - tileSize / 2) / blockHeight))

        guard col >= 0, col < gameStore.state.board.width,
              row >= 0, row < gameStore.state.board.height else {
            return nil
        }

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
    
    private func startMagnetAnimations(for event: GameStore.MagnetEvent, tileSize: CGFloat) {
        let contributors = event.sources.filter { $0 != event.target }
        guard !contributors.isEmpty else {
            gameStore.clearLastMagnetEvent()
            return
        }
        magnetAnimations = contributors.map { MagnetAnimationModel(value: event.value, start: $0, target: event.target, progress: 0) }

        // Play electric sound when magnet starts sucking
        Task { await audioService.playSfx(name: "electric") }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.35)) {
                for index in magnetAnimations.indices {
                    magnetAnimations[index].progress = 1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                magnetAnimations.removeAll()
                gameStore.clearLastMagnetEvent()
                // Play single merge sound when magnet completes
                Task { await audioService.playSfx(name: "merge") }
            }
        }
    }
    
    private func hammerOffset(for phase: GameStore.HammerAnimationState.Phase, tileSize: CGFloat) -> CGSize {
        switch phase {
        case .windUp:
            return CGSize(width: tileSize * 0.9, height: -tileSize * 0.9)
        case .impact:
            return CGSize(width: tileSize * 0.3, height: -tileSize * 0.2)
        }
    }
    
    private func hammerRotation(for phase: GameStore.HammerAnimationState.Phase) -> Angle {
        switch phase {
        case .windUp:
            return Angle(degrees: -35)
        case .impact:
            return Angle(degrees: 15)
        }
    }
}

/// Ghost tile that animates fade-out when appearing (for milestone elimination)
private struct EliminationGhostTile: View {
    let value: Int
    let size: CGFloat
    let colorBlindMode: Bool
    let theme: ThemeDescriptor?

    @State private var opacity: Double = 1.0
    @State private var scale: Double = 1.0

    var body: some View {
        TileView(
            tile: Tile(value: value),
            isSelected: false,
            isValid: true,
            size: size,
            colorBlindMode: colorBlindMode,
            theme: theme
        )
        .opacity(opacity)
        .scaleEffect(scale)
        .onAppear {
            // Start the fade-out animation when the ghost tile appears
            withAnimation(.easeOut(duration: 0.4)) {
                opacity = 0
                scale = 0.3
            }
        }
    }
}

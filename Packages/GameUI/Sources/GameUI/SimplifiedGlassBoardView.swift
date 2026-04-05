import SwiftUI
import GameCore
import GameApp
import OSLog

/// Pairs a tile with its board position for the ZStack tile layer
private struct TilePositionItem: Identifiable {
    let id: UUID
    let tile: Tile
    let position: Position
}

// MARK: - Simplified Glass Board View (Visual Only)
public struct SimplifiedGlassBoardView: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.hapticsService) private var haptics
    @Environment(\.colorBlindMode) private var colorBlindMode
    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.audio) private var audioService
    
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging = false
    @State private var glassPreviewValues: [Int] = []
    @State private var magnetAnimations: [MagnetAnimationModel] = []
    private let gestureLogger = Logger(subsystem: "com.game2244", category: "BoardGesture")
    
    private let spacing: CGFloat = 12
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: gameStore.lastMagnetEvent) { _, newValue in
                if let event = newValue {
                    startMagnetAnimations(for: event)
                }
            }
            .onChange(of: gameStore.hammerAnimationState?.phase) { _, newPhase in
                if newPhase == .impact {
                    Task { await audioService.playSfx(name: "hammer") }
                }
            }
            .onAppear {
                print("🎵 SimplifiedGlassBoardView audioService type: \(type(of: audioService))")
            }
        }
    }

    @ViewBuilder
    private func boardGrid(tileSize: CGFloat, containerSize: CGSize) -> some View {
        // Crown appears on ALL tiles with the highest value currently on the board
        // Uses stepIndex for accurate comparison of high-value tiles
        let crownPositions: Set<Position> = {
            var maxStep = -1
            var positions: Set<Position> = []
            // First pass: find the max step
            for r in 0..<gameStore.state.board.height {
                for c in 0..<gameStore.state.board.width {
                    let p = Position(row: r, col: c)
                    if let t = gameStore.state.board[p] {
                        let step = t.stepIndex ?? 0
                        if step > maxStep {
                            maxStep = step
                        }
                    }
                }
            }
            // Second pass: collect all positions with max step
            for r in 0..<gameStore.state.board.height {
                for c in 0..<gameStore.state.board.width {
                    let p = Position(row: r, col: c)
                    if let t = gameStore.state.board[p] {
                        let step = t.stepIndex ?? 0
                        if step == maxStep {
                            positions.insert(p)
                        }
                    }
                }
            }
            return positions
        }()

        ZStack {
            // Layer 1: Cell backgrounds, tap handlers, glass overlays, gift boxes, crowns
            // (VStack/HStack grid, but WITHOUT TileViews)
            VStack(spacing: spacing) {
                ForEach(0..<gameStore.state.board.height, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<gameStore.state.board.width, id: \.self) { col in
                            let position = Position(row: row, col: col)

                            ZStack {
                                // Empty cell background
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .fill(Color.white.opacity(0.08))

                                if row == 0 {
                                    // Glass overlay effect (row 0 only)
                                    if !gameStore.sandboxed && !gameStore.brokenGlassTiles.contains(position) {
                                        glassOverlay(for: tileSize)
                                    }

                                    // Gift indicator (only while glass intact)
                                    if !gameStore.sandboxed && gameStore.pendingGiftBoxes[position] == nil {
                                        Image(systemName: "gift.fill")
                                            .font(.system(size: tileSize * 0.2))
                                            .foregroundColor(.yellow)
                                            .shadow(color: .black.opacity(0.3), radius: 2)
                                            .offset(x: tileSize * 0.3, y: -tileSize * 0.3)
                                    }
                                }


                                // Gift box overlay (all rows)
                                if !gameStore.sandboxed && gameStore.pendingGiftBoxes[position] != nil {
                                    GiftBoxOverlay(size: tileSize)
                                        .onTapGesture {
                                            haptics.success()
                                            gameStore.tapGiftBox(at: position)
                                        }
                                }
                            }
                            .frame(width: tileSize, height: tileSize)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard gameStore.pendingGiftBoxes[position] == nil else { return }
                                onTileTap?(position)
                            }
                        }
                    }
                }
            }
            .padding(spacing)

            // Layer 2: Tiles in a ZStack, identified by tile UUID
            // When gravity changes a tile's position, SwiftUI animates .position() smoothly
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
                .animation(.easeInOut(duration: 2.5), value: gameStore.gameOverConfirmed)
                .allowsHitTesting(false)
            }

            // Layer 3: Crown indicators (above tiles)
            ForEach(Array(crownPositions), id: \.self) { position in
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
        .contentShape(Rectangle())
        .simultaneousGesture(
            dragGesture(
                tileSize: tileSize,
                containerSize: containerSize
            )
        )
    }

    /// All tiles currently on the board with their positions, for the ZStack tile layer
    private var allTilesWithPositions: [TilePositionItem] {
        var items: [TilePositionItem] = []
        for row in 0..<gameStore.state.board.height {
            for col in 0..<gameStore.state.board.width {
                let pos = Position(row: row, col: col)
                if let tile = gameStore.state.board[pos] {
                    items.append(TilePositionItem(id: tile.id, tile: tile, position: pos))
                }
            }
        }
        return items
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
    private func magnetOverlay(tileSize: CGFloat, containerSize: CGSize) -> some View {
        if tileSize > 0, !magnetAnimations.isEmpty {
            ZStack {
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
    
    // Rest of implementation (drag gesture, calculations) same as BoardView...
    private func dragGesture(tileSize: CGFloat, containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                gestureLogger.info("drag changed | loc=\(self.describe(value.location)) locked=\(self.gameStore.isInputLocked)")
                guard tileSize > 0 else {
                    gestureLogger.warning("drag ignored | tileSize <= 0")
                    return
                }
                guard !gameStore.isInputLocked else {
                    gestureLogger.info("drag ignored | input locked")
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
                        gestureLogger.info("beginPath @ row=\(position.row) col=\(position.col)")
                    } else {
                        gestureLogger.info("beginPath skipped | position nil or empty")
                    }
                } else if let position = position, gameStore.state.board[position] != nil {
                    if let existingIndex = gameStore.currentPath.firstIndex(of: position),
                       existingIndex == gameStore.currentPath.count - 2 {
                        // Moved back to the immediately previous tile — undo one step
                        gameStore.backtrackPath()
                        haptics.lightImpact()
                        gestureLogger.info("backtrack to index \(existingIndex)")
                    } else if gameStore.currentPath.contains(position) {
                        // Finger is over a tile already in the path but NOT the predecessor —
                        // just update dragLocation so the pipe visually extends over it.
                    } else {
                        let appended = gameStore.extendPath(to: position)
                        if appended {
                            haptics.lightImpact()
                            Task { await audioService.playSfx(name: "chain") }
                            gestureLogger.info("extendPath valid | row=\(position.row) col=\(position.col) count=\(self.gameStore.currentPath.count)")
                        } else {
                            gestureLogger.warning("extendPath ignored/invalid")
                        }
                    }
                } else {
                    gestureLogger.info("move ignored | position nil or empty")
                }
                
                dragLocation = value.location
            }
            .onEnded { _ in
                gestureLogger.info("drag ended | valid=\(self.gameStore.pathValidation.isValid) count=\(self.gameStore.currentPath.count)")
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
    
    private func gridFrameSize(for tileSize: CGFloat) -> CGSize {
        let widthCount = max(1, gameStore.state.board.width)
        let heightCount = max(1, gameStore.state.board.height)
        let totalTilesWidth = CGFloat(widthCount) * tileSize + CGFloat(max(0, widthCount - 1)) * spacing
        let totalTilesHeight = CGFloat(heightCount) * tileSize + CGFloat(max(0, heightCount - 1)) * spacing
        let boardWidth = totalTilesWidth + 2 * spacing
        let boardHeight = totalTilesHeight + 2 * spacing
        return CGSize(width: boardWidth, height: boardHeight)
    }
    
    private func gridPosition(from location: CGPoint, tileSize: CGFloat, containerSize: CGSize) -> Position? {
        // Snap to the nearest tile center instead of rejecting touches in spacing gaps.
        // This makes diagonal connections as easy as orthogonal ones.
        let origin = gridOrigin(in: containerSize, tileSize: tileSize)
        let localX = location.x - origin.x - spacing
        let localY = location.y - origin.y - spacing

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
        let boardWidth = totalTilesWidth + 2 * spacing
        let boardHeight = totalTilesHeight + 2 * spacing
        let originX = (containerSize.width - boardWidth) / 2
        let originY = (containerSize.height - boardHeight) / 2
        return CGPoint(x: originX, y: originY)
    }

    private func describe(_ point: CGPoint) -> String {
        "(\(String(format: "%.1f", point.x)), \(String(format: "%.1f", point.y)))"
    }
    
    private func startMagnetAnimations(for event: GameStore.MagnetEvent) {
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
}


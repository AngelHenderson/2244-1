import SwiftUI

public struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    /// Called when tutorial is completed (for first-launch flow)
    public var onComplete: (() -> Void)?

    private let pages: [TutorialPage] = [
        TutorialPage(
            title: "Welcome to 2244!",
            subtitle: "Learn the basics",
            description: "Connect tiles to create chains and merge them into higher values. Let's learn how!",
            systemImage: "hand.wave.fill",
            imageColor: .blue
        ),
        TutorialPage(
            title: "Connect Tiles",
            subtitle: "Part A: Start a chain",
            description: "Start by connecting 2 tiles of the same value.",
            systemImage: "hand.draw.fill",
            imageColor: .green
        ),
        TutorialPage(
            title: "Connect Tiles",
            subtitle: "Part B: Same or double",
            description: "After the first two tiles, you can connect the same value or double.",
            systemImage: "hand.draw.fill",
            imageColor: .green
        ),
        TutorialPage(
            title: "8 Directions",
            subtitle: "Connect any way",
            description: "Connect tiles horizontally, vertically, and diagonally - all 8 directions!",
            systemImage: "arrow.up.left.and.arrow.down.right",
            imageColor: .orange
        ),
        TutorialPage(
            title: "Merge & Score",
            subtitle: "Watch them combine",
            description: "When you release your chain, all tiles merge into one! Longer chains = higher values!",
            systemImage: "arrow.triangle.merge",
            imageColor: .purple
        ),
        TutorialPage(
            title: "Hammer",
            subtitle: "Power-Up",
            description: "Remove any single tile from the board.",
            systemImage: "hammer.fill",
            imageColor: .red
        ),
        TutorialPage(
            title: "Swap",
            subtitle: "Power-Up",
            description: "Switch the positions of two tiles on the board.",
            systemImage: "arrow.left.arrow.right",
            imageColor: .cyan
        ),
        TutorialPage(
            title: "MegaMerge",
            subtitle: "Power-Up",
            description: "Merge all tiles of the same value on the board at once!",
            systemImage: "sparkles",
            imageColor: .yellow
        ),
        TutorialPage(
            title: "You're Ready!",
            subtitle: "Start playing",
            description: "Reach higher tile values to climb the leaderboard and get infinity. Good luck!",
            systemImage: "trophy.fill",
            imageColor: .mint
        )
    ]

    public init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack {
            // Full screen background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with title and skip button
                HStack {
                    Spacer()
                    Text("How to Play")
                        .font(.headline)
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    Button("Skip") {
                        if let onComplete {
                            onComplete()
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(.secondary)
                    .padding(.trailing)
                }
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Page content - takes all available space
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        if index == 1 {
                            // Page 2 Part A: Interactive tile demo (two 2s)
                            ConnectTilesPartAPage(page: pages[index])
                                .tag(index)
                        } else if index == 2 {
                            // Page 3 Part B: Same or double (2,2,4,8,8,16)
                            ConnectTilesPartBPage(page: pages[index])
                                .tag(index)
                        } else if index == 3 {
                            // Page 4: 8 Directions snake pattern
                            EightDirectionsPage(page: pages[index])
                                .tag(index)
                        } else if index == 4 {
                            // Page 5: Merge & Score demo
                            MergeAndScorePage(page: pages[index])
                                .tag(index)
                        } else if index == 5 {
                            // Page 6: Hammer demo
                            HammerPage(page: pages[index])
                                .tag(index)
                        } else if index == 6 {
                            // Page 7: Swap demo
                            SwapPage(page: pages[index])
                                .tag(index)
                        } else if index == 7 {
                            // Page 8: MegaMerge demo
                            MegaMergePage(page: pages[index])
                                .tag(index)
                        } else {
                            TutorialPageView(page: pages[index])
                                .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Page indicator and buttons
                VStack(spacing: 20) {
                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut, value: currentPage)
                        }
                    }

                    // Navigation buttons
                    HStack(spacing: 16) {
                        if currentPage > 0 {
                            Button("Back") {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()

                        if currentPage < pages.count - 1 {
                            Button("Next") {
                                withAnimation {
                                    currentPage += 1
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Let's Play!") {
                                if let onComplete {
                                    onComplete()
                                } else {
                                    dismiss()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Tutorial Page Model

private struct TutorialPage {
    let title: String
    let subtitle: String
    let description: String
    let systemImage: String
    let imageColor: Color
}

// MARK: - Tutorial Page View

private struct TutorialPageView: View {
    let page: TutorialPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: page.systemImage)
                .font(.system(size: 80))
                .foregroundStyle(page.imageColor)
                .padding(.bottom, 16)

            // Title
            Text(page.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            // Subtitle
            Text(page.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)

            // Description
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Connect Tiles Part A (Interactive Demo)

private struct ConnectTilesPartAPage: View {
    let page: TutorialPage
    @State private var connectedTileIds: Set<Int> = []
    @State private var showMergeResult = false
    @State private var isDragging = false

    private let tileSize: CGFloat = 70
    private let tileSpacing: CGFloat = 16
    private var totalWidth: CGFloat { tileSize * 2 + tileSpacing }

    /// Find which tile (0 or 1) is at the given location
    private func tileAt(location: CGPoint) -> Int? {
        // Tiles are laid out horizontally: tile 0 at x=0, tile 1 at x=(tileSize + spacing)
        let x = location.x
        let y = location.y

        // Check y is within tile height
        guard y >= 0 && y <= tileSize else { return nil }

        // Check which tile based on x
        if x >= 0 && x <= tileSize {
            return 0
        } else if x >= tileSize + tileSpacing && x <= totalWidth {
            return 1
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Title
            Text(page.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            // Subtitle
            Text(page.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)

            // Interactive tiles demo
            VStack(spacing: 16) {
                if showMergeResult {
                    // Show merged result: single 4 tile
                    TutorialTile(value: "4", color: Theme.colorForStep(1))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Show two 2 tiles horizontally with connection line
                    ZStack {
                        // Connection line when both tiles are connected
                        if connectedTileIds.count == 2 {
                            Rectangle()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: tileSpacing + 20, height: 3)
                        }

                        HStack(spacing: tileSpacing) {
                            TutorialTile(
                                value: "2",
                                color: Theme.colorForStep(0),
                                isHighlighted: connectedTileIds.contains(0),
                                size: tileSize
                            )

                            TutorialTile(
                                value: "2",
                                color: Theme.colorForStep(0),
                                isHighlighted: connectedTileIds.contains(1),
                                size: tileSize
                            )
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true

                                // Check if we're over a tile
                                if let tileId = tileAt(location: value.location) {
                                    if connectedTileIds.isEmpty {
                                        // Can start with either tile
                                        connectedTileIds.insert(tileId)
                                    } else if !connectedTileIds.contains(tileId) {
                                        // Add the other tile if not already connected
                                        connectedTileIds.insert(tileId)
                                    }
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                if connectedTileIds.count == 2 {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        showMergeResult = true
                                    }
                                    // Reset after delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation {
                                            showMergeResult = false
                                            connectedTileIds.removeAll()
                                        }
                                    }
                                } else {
                                    connectedTileIds.removeAll()
                                }
                            }
                    )
                }

                Text(showMergeResult ? "They merged into 4!" : "Drag across both tiles to connect them")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            .padding(.vertical, 24)

            // Description
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Eight Directions Page

private struct EightDirectionsPage: View {
    let page: TutorialPage
    @State private var connectedTileIds: Set<Int> = []
    @State private var showMergeResult = false
    @State private var isDragging = false

    // Tile positions following the snake path starting from left:
    // 1. 2 at (1,1) - starts at left
    // 2. 2 at (1,2) → horizontal right
    // 3. 4 at (2,2) ↓ vertical down
    // 4. 4 at (3,3) ↘ diagonal bottom-right
    // 5. 8 at (2,4) ↗ diagonal top-right
    // 6. 16 at (1,3) ↖ diagonal top-left
    // 7. 32 at (0,3) ↑ vertical up
    // 8. 64 at (0,2) ← horizontal left
    // 9. 128 at (0,1) ← horizontal left again
    // 10. 256 at (1,0) ↙ diagonal bottom-left

    private struct TilePosition: Identifiable {
        let id: Int
        let row: Int
        let col: Int
        let value: Int
        let step: Int
    }

    private let tiles: [TilePosition] = [
        TilePosition(id: 0, row: 1, col: 1, value: 2, step: 0),      // Start at left
        TilePosition(id: 1, row: 1, col: 2, value: 2, step: 0),      // → right
        TilePosition(id: 2, row: 2, col: 2, value: 4, step: 1),      // ↓ down
        TilePosition(id: 3, row: 3, col: 3, value: 4, step: 1),      // ↘ bottom-right
        TilePosition(id: 4, row: 2, col: 4, value: 8, step: 2),      // ↗ top-right
        TilePosition(id: 5, row: 1, col: 3, value: 16, step: 3),     // ↖ top-left
        TilePosition(id: 6, row: 0, col: 3, value: 32, step: 4),     // ↑ up
        TilePosition(id: 7, row: 0, col: 2, value: 64, step: 5),     // ← left
        TilePosition(id: 8, row: 0, col: 1, value: 128, step: 6),    // ← left again
        TilePosition(id: 9, row: 1, col: 0, value: 256, step: 7),    // ↙ bottom-left
    ]

    private let gridRows = 4
    private let gridCols = 5
    private let tileSize: CGFloat = 48
    private var cellSize: CGFloat { tileSize + 4 }

    /// Find which tile is at the given position
    private func tileAt(location: CGPoint) -> TilePosition? {
        let col = Int(location.x / cellSize)
        let row = Int(location.y / cellSize)
        return tiles.first { $0.row == row && $0.col == col }
    }

    /// Check if two tiles are adjacent (including diagonals)
    private func areAdjacent(_ tile1: TilePosition, _ tile2: TilePosition) -> Bool {
        let rowDiff = abs(tile1.row - tile2.row)
        let colDiff = abs(tile1.col - tile2.col)
        return rowDiff <= 1 && colDiff <= 1 && !(rowDiff == 0 && colDiff == 0)
    }

    /// Get the highest connected tile id in sequence
    private var connectedCount: Int {
        var count = 0
        for i in 0..<tiles.count {
            if connectedTileIds.contains(i) {
                count = i + 1
            } else {
                break
            }
        }
        return count
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Title
            Text(page.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            // Subtitle
            Text(page.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)

            // Grid demo - aligned to left
            HStack {
                VStack(spacing: 8) {
                    if showMergeResult {
                        TutorialTile(value: "1024", color: Theme.colorForStep(9))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        // Grid with tiles
                        ZStack {
                            // Draw connection lines
                            Canvas { context, size in
                                var path = Path()
                                let connected = connectedCount

                                for (index, tile) in tiles.prefix(connected).enumerated() {
                                    let x = CGFloat(tile.col) * cellSize + cellSize / 2
                                    let y = CGFloat(tile.row) * cellSize + cellSize / 2

                                    if index == 0 {
                                        path.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }

                                context.stroke(path, with: .color(.white.opacity(0.8)), lineWidth: 3)
                            }
                            .frame(width: CGFloat(gridCols) * cellSize, height: CGFloat(gridRows) * cellSize)

                            // Grid of tiles
                            VStack(spacing: 4) {
                                ForEach(0..<gridRows, id: \.self) { row in
                                    HStack(spacing: 4) {
                                        ForEach(0..<gridCols, id: \.self) { col in
                                            if let tile = tiles.first(where: { $0.row == row && $0.col == col }) {
                                                TutorialTile(
                                                    value: "\(tile.value)",
                                                    color: Theme.colorForStep(tile.step),
                                                    isHighlighted: connectedTileIds.contains(tile.id),
                                                    size: tileSize
                                                )
                                            } else {
                                                Color.clear
                                                    .frame(width: tileSize, height: tileSize)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true

                                    // Check if we're over a tile
                                    if let tile = tileAt(location: value.location) {
                                        // If this is the first tile or adjacent to the last connected tile
                                        if connectedTileIds.isEmpty {
                                            // Must start with tile 0
                                            if tile.id == 0 {
                                                connectedTileIds.insert(tile.id)
                                            }
                                        } else {
                                            // Check if this tile is the next in sequence
                                            let nextExpectedId = connectedCount
                                            if tile.id == nextExpectedId && nextExpectedId < tiles.count {
                                                // Check if adjacent to the previous tile
                                                let prevTile = tiles[nextExpectedId - 1]
                                                if areAdjacent(prevTile, tile) {
                                                    connectedTileIds.insert(tile.id)
                                                }
                                            }
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    if connectedCount >= 4 {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            showMergeResult = true
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            withAnimation {
                                                showMergeResult = false
                                                connectedTileIds.removeAll()
                                            }
                                        }
                                    } else {
                                        connectedTileIds.removeAll()
                                    }
                                }
                        )
                    }

                    Text(showMergeResult ? "Merged into 1024!" : "Drag across tiles to connect them")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding(.leading, 16)

                Spacer()
            }
            .padding(.vertical, 16)

            // Description
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Merge And Score Page

private struct MergeAndScorePage: View {
    let page: TutorialPage
    @State private var connectedTileIds: Set<Int> = []
    @State private var showMergeResult = false
    @State private var isDragging = false
    @State private var score: Int = 100
    @State private var lastMergeScore: Int = 0

    // Tiles: 2-2-4-4-8-16-16-32-64
    private struct TileInfo: Identifiable {
        let id: Int
        let value: Int
        let step: Int
    }

    private let tiles: [TileInfo] = [
        TileInfo(id: 0, value: 2, step: 0),
        TileInfo(id: 1, value: 2, step: 0),
        TileInfo(id: 2, value: 4, step: 1),
        TileInfo(id: 3, value: 4, step: 1),
        TileInfo(id: 4, value: 8, step: 2),
        TileInfo(id: 5, value: 16, step: 3),
        TileInfo(id: 6, value: 16, step: 3),
        TileInfo(id: 7, value: 32, step: 4),
        TileInfo(id: 8, value: 64, step: 5),
    ]

    private let tileSize: CGFloat = 36
    private let tileSpacing: CGFloat = 4
    private var totalWidth: CGFloat { CGFloat(tiles.count) * tileSize + CGFloat(tiles.count - 1) * tileSpacing }

    /// Find which tile is at the given x location
    private func tileAt(location: CGPoint) -> Int? {
        let y = location.y
        guard y >= 0 && y <= tileSize else { return nil }

        let cellWidth = tileSize + tileSpacing
        let x = location.x

        for i in 0..<tiles.count {
            let tileStart = CGFloat(i) * cellWidth
            let tileEnd = tileStart + tileSize
            if x >= tileStart && x <= tileEnd {
                return i
            }
        }
        return nil
    }

    /// Get the count of consecutively connected tiles from the start
    private var connectedCount: Int {
        var count = 0
        for i in 0..<tiles.count {
            if connectedTileIds.contains(i) {
                count = i + 1
            } else {
                break
            }
        }
        return count
    }

    /// Calculate merge score based on merged tile value (sum rounded up to next power of 2)
    private var mergeScore: Int {
        let connected = connectedCount
        guard connected >= 2 else { return 0 }
        // Sum all connected tile values
        let sum = tiles.prefix(connected).reduce(0) { $0 + $1.value }
        // Round up to next power of 2
        var power = 1
        while power < sum {
            power *= 2
        }
        return power
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Title
            Text(page.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            // Subtitle
            Text(page.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)

            // Score display
            HStack {
                Text("Score:")
                    .font(.title2.bold())
                Text("\(score)")
                    .font(.title2.bold())
                    .foregroundStyle(.orange)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: score)
            }
            .padding(.vertical, 8)

            // Interactive tiles demo
            VStack(spacing: 12) {
                if showMergeResult {
                    // Show merged result: 256 tile (sum of 148 rounds up to 256)
                    TutorialTile(value: "256", color: Theme.colorForStep(7))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Show tiles in horizontal row with connection line
                    ZStack {
                        // Connection line
                        if connectedCount >= 2 {
                            let lineWidth = CGFloat(connectedCount - 1) * (tileSize + tileSpacing) + tileSize
                            Rectangle()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: lineWidth, height: 3)
                                .offset(x: -(totalWidth - lineWidth) / 2)
                        }

                        HStack(spacing: tileSpacing) {
                            ForEach(tiles) { tile in
                                TutorialTile(
                                    value: "\(tile.value)",
                                    color: Theme.colorForStep(tile.step),
                                    isHighlighted: connectedTileIds.contains(tile.id),
                                    size: tileSize
                                )
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true

                                if let tileId = tileAt(location: value.location) {
                                    if connectedTileIds.isEmpty {
                                        // Must start with first tile
                                        if tileId == 0 {
                                            connectedTileIds.insert(tileId)
                                        }
                                    } else {
                                        // Add next tile in sequence
                                        let nextExpectedId = connectedCount
                                        if tileId == nextExpectedId && nextExpectedId < tiles.count {
                                            connectedTileIds.insert(tileId)
                                        }
                                    }
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                if connectedCount >= 2 {
                                    // Save and add merge score
                                    let points = mergeScore
                                    lastMergeScore = points
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        showMergeResult = true
                                        score += points
                                    }
                                    // Reset after delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation {
                                            showMergeResult = false
                                            connectedTileIds.removeAll()
                                            score = 100
                                        }
                                    }
                                } else {
                                    connectedTileIds.removeAll()
                                }
                            }
                    )
                }

                Text(showMergeResult ? "Merged! +\(lastMergeScore) points!" : "Drag across tiles to connect and score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(.vertical, 16)

            // Description
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Hammer Page

private struct HammerPage: View {
    let page: TutorialPage
    @State private var show256: Bool = true
    @State private var showMergeResult: Bool = false
    @State private var connectedTileIds: Set<Int> = []
    @State private var hammerActive: Bool = true

    private let tileSize: CGFloat = 60
    private let tileSpacing: CGFloat = 8

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Title
            Text(page.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            // Subtitle
            Text(page.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)

            // Interactive demo
            VStack(spacing: 16) {
                if showMergeResult {
                    // Show merged result: 4 tile
                    TutorialTile(value: "4", color: Theme.colorForStep(1))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Vertical stack: 2, 256, 2
                    VStack(spacing: tileSpacing) {
                        // Top 2
                        TutorialTile(
                            value: "2",
                            color: Theme.colorForStep(0),
                            isHighlighted: connectedTileIds.contains(0),
                            size: tileSize
                        )
                        .onTapGesture {
                            if !hammerActive && !show256 {
                                handleTileTap(id: 0)
                            }
                        }

                        // Middle 256 (removable with hammer)
                        if show256 {
                            TutorialTile(
                                value: "256",
                                color: Theme.colorForStep(7),
                                isHighlighted: hammerActive,
                                size: tileSize
                            )
                            .overlay(
                                hammerActive ?
                                Image(systemName: "hammer.fill")
                                    .font(.title2)
                                    .foregroundStyle(.red)
                                    .offset(x: 25, y: -25)
                                : nil
                            )
                            .onTapGesture {
                                if hammerActive {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        show256 = false
                                        hammerActive = false
                                    }
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }

                        // Bottom 2
                        TutorialTile(
                            value: "2",
                            color: Theme.colorForStep(0),
                            isHighlighted: connectedTileIds.contains(1),
                            size: tileSize
                        )
                        .onTapGesture {
                            if !hammerActive && !show256 {
                                handleTileTap(id: 1)
                            }
                        }
                    }
                }

                // Instruction text
                Text(instructionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(.vertical, 16)

            // Description
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Spacer()
        }
        .padding()
    }

    private var instructionText: String {
        if showMergeResult {
            return "The 2s merged into 4!"
        } else if hammerActive {
            return "Tap the 256 to remove it with the hammer"
        } else if !show256 && connectedTileIds.isEmpty {
            return "Now tap both 2s to connect and merge them"
        } else if connectedTileIds.count == 1 {
            return "Tap the other 2 to complete the chain"
        } else {
            return "Tap tiles to connect them"
        }
    }

    private func handleTileTap(id: Int) {
        if connectedTileIds.contains(id) {
            return
        }

        connectedTileIds.insert(id)

        // If both tiles are connected, merge them
        if connectedTileIds.count == 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showMergeResult = true
                }
                // Reset after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        showMergeResult = false
                        show256 = true
                        hammerActive = true
                        connectedTileIds.removeAll()
                    }
                }
            }
        }
    }
}

// MARK: - Swap Page

private struct SwapPage: View {
    let page: TutorialPage
    @State private var swapped: Bool = false
    @State private var showMergeResult: Bool = false
    @State private var connectedTileIds: Set<Int> = []
    @State private var firstSwapTile: Int? = nil

    // Tiles: 2-2-2-4-8-32-16-64-128-256-512 (32 and 16 are swapped - need to fix)
    // After swap: 2-2-2-4-8-16-32-64-128-256-512
    private struct TileInfo: Identifiable {
        let id: Int
        var value: Int
        var step: Int
    }

    // Initial state with 32 and 16 in wrong positions
    private var tiles: [TileInfo] {
        if swapped {
            // Correct order after swap
            return [
                TileInfo(id: 0, value: 2, step: 0),
                TileInfo(id: 1, value: 2, step: 0),
                TileInfo(id: 2, value: 2, step: 0),
                TileInfo(id: 3, value: 4, step: 1),
                TileInfo(id: 4, value: 8, step: 2),
                TileInfo(id: 5, value: 16, step: 3),   // Swapped
                TileInfo(id: 6, value: 32, step: 4),   // Swapped
                TileInfo(id: 7, value: 64, step: 5),
                TileInfo(id: 8, value: 128, step: 6),
                TileInfo(id: 9, value: 256, step: 7),
                TileInfo(id: 10, value: 512, step: 8),
            ]
        } else {
            // Wrong order - 32 and 16 need to be swapped
            return [
                TileInfo(id: 0, value: 2, step: 0),
                TileInfo(id: 1, value: 2, step: 0),
                TileInfo(id: 2, value: 2, step: 0),
                TileInfo(id: 3, value: 4, step: 1),
                TileInfo(id: 4, value: 8, step: 2),
                TileInfo(id: 5, value: 32, step: 4),   // Wrong position
                TileInfo(id: 6, value: 16, step: 3),   // Wrong position
                TileInfo(id: 7, value: 64, step: 5),
                TileInfo(id: 8, value: 128, step: 6),
                TileInfo(id: 9, value: 256, step: 7),
                TileInfo(id: 10, value: 512, step: 8),
            ]
        }
    }

    private let tileSize: CGFloat = 32
    private let tileSpacing: CGFloat = 3
    private var totalWidth: CGFloat { CGFloat(tiles.count) * tileSize + CGFloat(tiles.count - 1) * tileSpacing }

    /// Find which tile is at the given x location
    private func tileAt(location: CGPoint) -> Int? {
        let y = location.y
        guard y >= 0 && y <= tileSize else { return nil }

        let cellWidth = tileSize + tileSpacing
        let x = location.x

        for i in 0..<tiles.count {
            let tileStart = CGFloat(i) * cellWidth
            let tileEnd = tileStart + tileSize
            if x >= tileStart && x <= tileEnd {
                return i
            }
        }
        return nil
    }

    /// Get the count of consecutively connected tiles from the start
    private var connectedCount: Int {
        var count = 0
        for i in 0..<tiles.count {
            if connectedTileIds.contains(i) {
                count = i + 1
            } else {
                break
            }
        }
        return count
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Title
            Text(page.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            // Subtitle
            Text(page.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)

            // Interactive demo
            VStack(spacing: 12) {
                if showMergeResult {
                    // Show merged result: 2048 tile
                    TutorialTile(value: "2048", color: Theme.colorForStep(10))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Horizontal tiles with swap indicators
                    ZStack {
                        // Connection line when merging
                        if swapped && connectedCount >= 2 {
                            let lineWidth = CGFloat(connectedCount - 1) * (tileSize + tileSpacing) + tileSize
                            Rectangle()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: lineWidth, height: 2)
                                .offset(x: -(totalWidth - lineWidth) / 2)
                        }

                        HStack(spacing: tileSpacing) {
                            ForEach(tiles) { tile in
                                TutorialTile(
                                    value: "\(tile.value)",
                                    color: Theme.colorForStep(tile.step),
                                    isHighlighted: !swapped ? (tile.id == 5 || tile.id == 6) : connectedTileIds.contains(tile.id),
                                    size: tileSize
                                )
                                .overlay(
                                    // Show swap arrows on 32 and 16 before swap
                                    !swapped && (tile.id == 5 || tile.id == 6) ?
                                    Image(systemName: tile.id == 5 ? "arrow.right" : "arrow.left")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.cyan)
                                        .offset(y: tileSize / 2 + 8)
                                    : nil
                                )
                                .onTapGesture {
                                    if !swapped {
                                        handleSwapTap(tileId: tile.id)
                                    }
                                }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        swapped ?
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if let tileId = tileAt(location: value.location) {
                                    if connectedTileIds.isEmpty {
                                        if tileId == 0 {
                                            connectedTileIds.insert(tileId)
                                        }
                                    } else {
                                        let nextExpectedId = connectedCount
                                        if tileId == nextExpectedId && nextExpectedId < tiles.count {
                                            connectedTileIds.insert(tileId)
                                        }
                                    }
                                }
                            }
                            .onEnded { _ in
                                if connectedCount >= 2 {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        showMergeResult = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation {
                                            showMergeResult = false
                                            swapped = false
                                            connectedTileIds.removeAll()
                                            firstSwapTile = nil
                                        }
                                    }
                                } else {
                                    connectedTileIds.removeAll()
                                }
                            }
                        : nil
                    )
                }

                // Instruction text
                Text(instructionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.vertical, 12)

            // Description
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Spacer()
        }
        .padding()
    }

    private var instructionText: String {
        if showMergeResult {
            return "Merged into 2048!"
        } else if !swapped {
            if firstSwapTile == nil {
                return "Tap the 32 or 16 to swap them"
            } else {
                return "Now tap the other tile to complete the swap"
            }
        } else {
            return "Now drag across all tiles to merge into 2048"
        }
    }

    private func handleSwapTap(tileId: Int) {
        // Only allow tapping 32 (id 5) or 16 (id 6)
        guard tileId == 5 || tileId == 6 else { return }

        if firstSwapTile == nil {
            firstSwapTile = tileId
        } else if firstSwapTile != tileId {
            // Complete the swap
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                swapped = true
                firstSwapTile = nil
            }
        }
    }
}

// MARK: - Connect Tiles Part B (Same or Double Demo)

private struct ConnectTilesPartBPage: View {
    let page: TutorialPage
    @State private var connectedTileIds: Set<Int> = []
    @State private var showMergeResult = false
    @State private var isDragging = false

    // Tiles: 2, 2, 4, 8, 8, 16
    private struct TileInfo: Identifiable {
        let id: Int
        let value: Int
        let step: Int
    }

    private let tiles: [TileInfo] = [
        TileInfo(id: 0, value: 2, step: 0),
        TileInfo(id: 1, value: 2, step: 0),
        TileInfo(id: 2, value: 4, step: 1),
        TileInfo(id: 3, value: 8, step: 2),
        TileInfo(id: 4, value: 8, step: 2),
        TileInfo(id: 5, value: 16, step: 3),
    ]

    private let tileSize: CGFloat = 52
    private let tileSpacing: CGFloat = 8
    private var totalWidth: CGFloat { CGFloat(tiles.count) * tileSize + CGFloat(tiles.count - 1) * tileSpacing }

    /// Find which tile is at the given x location
    private func tileAt(location: CGPoint) -> Int? {
        let y = location.y
        guard y >= 0 && y <= tileSize else { return nil }

        let cellWidth = tileSize + tileSpacing
        let x = location.x

        for i in 0..<tiles.count {
            let tileStart = CGFloat(i) * cellWidth
            let tileEnd = tileStart + tileSize
            if x >= tileStart && x <= tileEnd {
                return i
            }
        }
        return nil
    }

    /// Get the count of consecutively connected tiles from the start
    private var connectedCount: Int {
        var count = 0
        for i in 0..<tiles.count {
            if connectedTileIds.contains(i) {
                count = i + 1
            } else {
                break
            }
        }
        return count
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Title
            Text(page.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            // Subtitle
            Text(page.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)

            // Interactive tiles demo
            VStack(spacing: 16) {
                if showMergeResult {
                    // Show merged result: 64 tile (sum 2+2+4+8+8+16=40, rounds to 64)
                    TutorialTile(value: "64", color: Theme.colorForStep(5))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Show tiles: 2, 2, 4, 8, 8, 16 with connection line
                    ZStack {
                        // Connection line
                        if connectedCount >= 2 {
                            let lineWidth = CGFloat(connectedCount - 1) * (tileSize + tileSpacing) + tileSize
                            Rectangle()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: lineWidth, height: 3)
                                .offset(x: -(totalWidth - lineWidth) / 2)
                        }

                        HStack(spacing: tileSpacing) {
                            ForEach(tiles) { tile in
                                TutorialTile(
                                    value: "\(tile.value)",
                                    color: Theme.colorForStep(tile.step),
                                    isHighlighted: connectedTileIds.contains(tile.id),
                                    size: tileSize
                                )
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true

                                if let tileId = tileAt(location: value.location) {
                                    if connectedTileIds.isEmpty {
                                        // Must start with first tile
                                        if tileId == 0 {
                                            connectedTileIds.insert(tileId)
                                        }
                                    } else {
                                        // Add next tile in sequence
                                        let nextExpectedId = connectedCount
                                        if tileId == nextExpectedId && nextExpectedId < tiles.count {
                                            connectedTileIds.insert(tileId)
                                        }
                                    }
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                if connectedCount >= 2 {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        showMergeResult = true
                                    }
                                    // Reset after delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation {
                                            showMergeResult = false
                                            connectedTileIds.removeAll()
                                        }
                                    }
                                } else {
                                    connectedTileIds.removeAll()
                                }
                            }
                    )
                }

                Text(showMergeResult ? "Merged into 64!" : "Drag across to connect same or double values")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            .padding(.vertical, 24)

            // Description
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Tutorial Tile

private struct TutorialTile: View {
    let value: String
    let color: Color
    var isHighlighted: Bool = false
    var size: CGFloat = 70

    var body: some View {
        Text(value)
            .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: size * 0.17))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.17)
                    .stroke(isHighlighted ? Color.white : Color.clear, lineWidth: 3)
            )
            .shadow(color: isHighlighted ? color.opacity(0.6) : .clear, radius: 8)
            .scaleEffect(isHighlighted ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHighlighted)
    }
}

#Preview {
    HowToPlayView()
}

#Preview("First Launch") {
    HowToPlayView(onComplete: {
        print("Tutorial completed!")
    })
}

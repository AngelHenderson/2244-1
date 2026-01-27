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
            subtitle: "Part B: Extend your chain",
            description: "After the first two tiles, you can connect tiles that are the same value or double the previous tile.",
            systemImage: "hand.draw.fill",
            imageColor: .green
        ),
        TutorialPage(
            title: "8 Directions",
            subtitle: "Connect anywhere",
            description: "Connect tiles in all 8 directions - horizontal, vertical, and diagonal.",
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
                            // Page 2 Part B: Interactive tile demo (2, 2, 4, 8, 8, 16)
                            ConnectTilesPartBPage(page: pages[index])
                                .tag(index)
                        } else if index == 3 {
                            // Page 4: 8 Directions demo
                            EightDirectionsPage(page: pages[index])
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
    @State private var isConnected = false
    @State private var showMergeResult = false
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

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
                    // Show two 2 tiles horizontally
                    HStack(spacing: 16) {
                        TutorialTile(
                            value: "2",
                            color: Theme.colorForStep(0),
                            isHighlighted: isConnected || isDragging
                        )

                        TutorialTile(
                            value: "2",
                            color: Theme.colorForStep(0),
                            isHighlighted: isConnected
                        )
                    }
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { _ in
                                isDragging = true
                                isConnected = true
                            }
                            .onEnded { _ in
                                isDragging = false
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    showMergeResult = true
                                }
                                // Reset after delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation {
                                        showMergeResult = false
                                        isConnected = false
                                    }
                                }
                            }
                    )
                }

                Text(showMergeResult ? "They merged into 4!" : "Swipe across the tiles to connect them")
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
    @State private var connectedCount = 0
    @State private var showMergeResult = false
    @State private var isDragging = false

    // Grid layout: 5 rows x 5 cols
    // Tile positions and values following the path:
    // 1. 2 at (2,0), 2. 2 at (2,1) →right, 3. 4 at (3,1) ↓down
    // 4. 4 at (4,2) ↘bottom-right, 5. 8 at (3,3) ↗top-right, 6. 16 at (2,2) ↖top-left
    // 7. 32 at (1,2) ↑up, 8. 64 at (1,1) ←left, 9. 128 at (2,0) ↙bottom-left (ends at start)

    private struct TilePosition: Identifiable {
        let id: Int
        let row: Int
        let col: Int
        let value: Int
        let step: Int
    }

    private let tiles: [TilePosition] = [
        TilePosition(id: 0, row: 2, col: 0, value: 2, step: 0),
        TilePosition(id: 1, row: 2, col: 1, value: 2, step: 0),
        TilePosition(id: 2, row: 3, col: 1, value: 4, step: 1),
        TilePosition(id: 3, row: 4, col: 2, value: 4, step: 1),
        TilePosition(id: 4, row: 3, col: 3, value: 8, step: 2),
        TilePosition(id: 5, row: 2, col: 2, value: 16, step: 3),
        TilePosition(id: 6, row: 1, col: 2, value: 32, step: 4),
        TilePosition(id: 7, row: 1, col: 1, value: 64, step: 5),
        TilePosition(id: 8, row: 2, col: 0, value: 128, step: 6),  // Overlaps with first, shown as end
    ]

    private let gridSize = 5
    private let tileSize: CGFloat = 48

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

            // Grid demo
            VStack(spacing: 8) {
                if showMergeResult {
                    TutorialTile(value: "512", color: Theme.colorForStep(8))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Grid with tiles
                    ZStack {
                        // Draw connection lines
                        Canvas { context, size in
                            let cellSize = tileSize + 4
                            var path = Path()

                            for (index, tile) in tiles.dropLast().enumerated() {
                                let nextTile = tiles[index + 1]
                                let startX = CGFloat(tile.col) * cellSize + cellSize / 2
                                let startY = CGFloat(tile.row) * cellSize + cellSize / 2
                                let endX = CGFloat(nextTile.col) * cellSize + cellSize / 2
                                let endY = CGFloat(nextTile.row) * cellSize + cellSize / 2

                                if index < connectedCount {
                                    if index == 0 {
                                        path.move(to: CGPoint(x: startX, y: startY))
                                    }
                                    path.addLine(to: CGPoint(x: endX, y: endY))
                                }
                            }

                            context.stroke(path, with: .color(.white.opacity(0.8)), lineWidth: 3)
                        }
                        .frame(width: CGFloat(gridSize) * (tileSize + 4), height: CGFloat(gridSize) * (tileSize + 4))

                        // Grid of tiles
                        VStack(spacing: 4) {
                            ForEach(0..<gridSize, id: \.self) { row in
                                HStack(spacing: 4) {
                                    ForEach(0..<gridSize, id: \.self) { col in
                                        if let tile = tiles.first(where: { $0.row == row && $0.col == col && $0.id < 8 }) {
                                            TutorialTile(
                                                value: "\(tile.value)",
                                                color: Theme.colorForStep(tile.step),
                                                isHighlighted: tile.id <= connectedCount,
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
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                isDragging = true
                                let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                                let tilesConnected = min(8, max(0, Int(dragDistance / 30)))
                                connectedCount = tilesConnected
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
                                            connectedCount = 0
                                        }
                                    }
                                } else {
                                    connectedCount = 0
                                }
                            }
                    )
                }

                Text(showMergeResult ? "Merged into 512!" : "Swipe to connect in all 8 directions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
}

// MARK: - Connect Tiles Part B (Same or Double Demo)

private struct ConnectTilesPartBPage: View {
    let page: TutorialPage
    @State private var connectedCount = 0
    @State private var showMergeResult = false
    @State private var isDragging = false

    // Tiles: 2, 2, 4, 8, 8, 16
    private let tileValues = [2, 2, 4, 8, 8, 16]
    private let tileSteps = [0, 0, 1, 2, 2, 3]  // Steps for colors

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
                    // Show merged result: 64 tile
                    TutorialTile(value: "64", color: Theme.colorForStep(5))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Show tiles: 2, 2, 4, 8, 8, 16
                    HStack(spacing: 8) {
                        ForEach(0..<tileValues.count, id: \.self) { index in
                            TutorialTile(
                                value: "\(tileValues[index])",
                                color: Theme.colorForStep(tileSteps[index]),
                                isHighlighted: index < connectedCount,
                                size: 52
                            )
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                isDragging = true
                                // Calculate how many tiles are covered based on drag distance
                                let tileWidth: CGFloat = 60  // tile + spacing
                                let dragDistance = value.translation.width
                                let tilesConnected = min(6, max(1, Int(dragDistance / tileWidth) + 1))
                                connectedCount = tilesConnected
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
                                            connectedCount = 0
                                        }
                                    }
                                } else {
                                    connectedCount = 0
                                }
                            }
                    )
                }

                Text(showMergeResult ? "All tiles merged into 64!" : "Swipe across to connect same or double values")
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

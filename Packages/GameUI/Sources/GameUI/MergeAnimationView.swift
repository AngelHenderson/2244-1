import SwiftUI
import GameCore
import GameApp

public struct MergeAnimationView: View {
    let state: GameStore.MergeAnimationState
    let tileSize: CGFloat
    let spacing: CGFloat
    let containerSize: CGSize
    let boardWidth: Int
    let boardHeight: Int
    
    public init(state: GameStore.MergeAnimationState, tileSize: CGFloat, spacing: CGFloat, containerSize: CGSize, boardWidth: Int, boardHeight: Int) {
        self.state = state
        self.tileSize = tileSize
        self.spacing = spacing
        self.containerSize = containerSize
        self.boardWidth = boardWidth
        self.boardHeight = boardHeight
    }
    
    public var body: some View {
        ZStack {
            ForEach(state.sourcePositions, id: \.self) { position in
                ParticleGroup(
                    start: position,
                    end: state.targetPosition,
                    value: state.value,
                    tileSize: tileSize,
                    spacing: spacing,
                    containerSize: containerSize,
                    boardWidth: boardWidth,
                    boardHeight: boardHeight
                )
            }
        }
    }
}

private struct ParticleGroup: View {
    let start: Position
    let end: Position
    let value: Int
    let tileSize: CGFloat
    let spacing: CGFloat
    let containerSize: CGSize
    let boardWidth: Int
    let boardHeight: Int
    
    @State private var progress: CGFloat = 0
    
    var body: some View {
        let startPoint = centerPoint(for: start)
        let endPoint = centerPoint(for: end)
        
        return ZStack {
            // 4 particles representing the broken block
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.color(for: value))
                    .frame(width: tileSize / 2 - 2, height: tileSize / 2 - 2)
                    // Initial position relative to the tile center
                    .offset(
                        x: (i % 2 == 0 ? -1 : 1) * tileSize / 4,
                        y: (i < 2 ? -1 : 1) * tileSize / 4
                    )
                    // Explode out slightly first
                    .offset(
                        x: (i % 2 == 0 ? -1 : 1) * (1 - progress) * (tileSize * 0.2),
                        y: (i < 2 ? -1 : 1) * (1 - progress) * (tileSize * 0.2)
                    )
                    // Move to target
                    .position(
                        x: startPoint.x + (endPoint.x - startPoint.x) * progress,
                        y: startPoint.y + (endPoint.y - startPoint.y) * progress
                    )
                    .scaleEffect(max(0.2, 1 - progress * 0.6)) // Shrink as they get sucked in
                    .opacity(1 - progress * 0.1) // Stay mostly visible until the end
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.35)) {
                progress = 1.0
            }
        }
    }
    
    // Helper to calculate center point of a tile in the container
    private func centerPoint(for position: Position) -> CGPoint {
        let origin = gridOrigin(in: containerSize, tileSize: tileSize)
        let x = origin.x + spacing + CGFloat(position.col) * (tileSize + spacing) + tileSize / 2
        let y = origin.y + spacing + CGFloat(position.row) * (tileSize + spacing) + tileSize / 2
        return CGPoint(x: x, y: y)
    }
    
    private func gridOrigin(in containerSize: CGSize, tileSize: CGFloat) -> CGPoint {
        let widthCount = max(1, boardWidth)
        let heightCount = max(1, boardHeight)
        let totalTilesWidth = CGFloat(widthCount) * tileSize + CGFloat(max(0, widthCount - 1)) * spacing
        let totalTilesHeight = CGFloat(heightCount) * tileSize + CGFloat(max(0, heightCount - 1)) * spacing
        let boardWidthPx = totalTilesWidth + 2 * spacing
        let boardHeightPx = totalTilesHeight + 2 * spacing
        let originX = (containerSize.width - boardWidthPx) / 2
        let originY = (containerSize.height - boardHeightPx) / 2
        return CGPoint(x: originX, y: originY)
    }
}

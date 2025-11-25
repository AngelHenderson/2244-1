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
                    boardHeight: boardHeight,
                    phase: state.phase
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
    
    let phase: GameStore.MergePhase
    
    @State private var progress: CGFloat = 0
    
    var body: some View {
        let startPoint = centerPoint(for: start)
        let endPoint = centerPoint(for: end)
        
        return ZStack {
            // 4 particles representing the broken block
            ForEach(0..<4) { i in
                particleView(index: i, startPoint: startPoint, endPoint: endPoint)
            }
        }
        .onAppear {
            // Adjust duration based on phase
            let duration = (phase == .shatter) ? 0.2 : 0.35
            withAnimation(.easeIn(duration: duration)) {
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
    
    @ViewBuilder
    private func particleView(index: Int, startPoint: CGPoint, endPoint: CGPoint) -> some View {
        let horizontalSign: CGFloat = (index % 2 == 0) ? -1.0 : 1.0
        let verticalSign: CGFloat = (index < 2) ? -1.0 : 1.0
        let baseOffset = CGSize(width: horizontalSign * tileSize * 0.25,
                                height: verticalSign * tileSize * 0.25)
        
        // Calculate explosion and movement based on phase
        let explodeMagnitude: CGFloat
        let currentX: CGFloat
        let currentY: CGFloat
        let currentScale: CGFloat
        let currentOpacity: CGFloat
        
        switch phase {
        case .shatter:
            // Expand out
            explodeMagnitude = tileSize * 0.2 * progress
            
            let explodeOffset = CGSize(width: horizontalSign * explodeMagnitude,
                                       height: verticalSign * explodeMagnitude)
            
            // Stay at start point
            currentX = startPoint.x + baseOffset.width + explodeOffset.width
            currentY = startPoint.y + baseOffset.height + explodeOffset.height
            
            // Scale down slightly as it breaks? Or just stay 1?
            // Let's keep it 1 or slightly smaller to show separation
            currentScale = 1.0 - (progress * 0.1)
            currentOpacity = 1.0
            
        case .fly:
            // Start exploded, move to target
            // Collapse explosion as we move? Or keep it?
            // Let's collapse it to simulate merging into the target
            explodeMagnitude = tileSize * 0.2 * (1 - progress)
            
            let explodeOffset = CGSize(width: horizontalSign * explodeMagnitude,
                                       height: verticalSign * explodeMagnitude)
            
            let startAnchorX = startPoint.x + baseOffset.width + explodeOffset.width
            let startAnchorY = startPoint.y + baseOffset.height + explodeOffset.height
            
            currentX = startAnchorX + (endPoint.x - startAnchorX) * progress
            currentY = startAnchorY + (endPoint.y - startAnchorY) * progress
            
            currentScale = max(0.2, 0.9 - progress * 0.6)
            currentOpacity = 1 - progress * 0.1
        }
        
        return RoundedRectangle(cornerRadius: 4)
            .fill(Theme.color(for: value))
            .frame(width: tileSize / 2 - 2, height: tileSize / 2 - 2)
            .position(x: currentX, y: currentY)
            .scaleEffect(currentScale)
            .opacity(currentOpacity)
    }
}

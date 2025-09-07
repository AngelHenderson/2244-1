import SwiftUI
import GameCore
import GameApp

public struct TileScrollerView: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.tileJourney) private var journey
    @Environment(\.homeActions) private var actions
    @State private var focusedTileID: Int? = nil
    @State private var showAnimation = false
    
    private let itemSpacing: CGFloat = 24
    private let tileSize: CGFloat = 140
    
    private var tiles: [(id: Int, tile: Tile)] {
        // Generate tiles and reverse so infinity is at top, starting from 2 at bottom
        let journeyTiles = JourneyTileGenerator.generateFullJourney().reversed()
        return journeyTiles.enumerated().map { (index, tile) in
            (id: index, tile: tile)
        }
    }
    
    private var highestUnlockedIndex: Int? {
        let highestValue = gameStore.state.highestTile
        return tiles.firstIndex { $0.tile.value == highestValue }
    }
    
    public init() {}
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: itemSpacing) {
                ForEach(tiles, id: \.id) { item in
                    TileRowItem(
                        tile: item.tile,
                        isLocked: isLocked(item.tile),
                        tileSize: tileSize
                    )
                    .id(item.id)
                    .scrollTransition(.interactive, axis: .vertical) { view, phase in
                        view
                            .scaleEffect(phase.isIdentity ? 1.0 : 0.92)
                            .opacity(phase.isIdentity ? 1.0 : 0.85)
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, UIScreen.main.bounds.height * 0.4)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $focusedTileID, anchor: .center)
        .contentMargins(.vertical, 150, for: .scrollContent)
        .background(Color.black.opacity(0.001))
        .task {
            // Initial position: scroll to highest achieved tile
            if focusedTileID == nil, let highestIndex = highestUnlockedIndex {
                focusedTileID = highestIndex
                // Fallback: dispatch async to ensure scroll position is set after layout
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if focusedTileID != highestIndex {
                        focusedTileID = highestIndex
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                showAnimation = true
            }
        }
    }
    
    private func isLocked(_ tile: Tile) -> Bool {
        // Infinity is always "locked" as it's the ultimate goal
        if tile.isInfinity {
            return true
        }
        return tile.value > gameStore.state.highestTile
    }
}

private struct TileRowItem: View {
    let tile: Tile
    let isLocked: Bool
    let tileSize: CGFloat
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                TileView(
                    tile: tile,
                    isSelected: false,
                    isValid: true,
                    size: tileSize
                )
                .saturation(isLocked ? 0.0 : 1.0)
                .opacity(isLocked ? 0.55 : 1.0)
                .animation(.snappy(duration: 0.25), value: isLocked)
                
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.7))
                        .shadow(radius: 2)
                }
            }
            
            if tile.isInfinity {
                Text("Ultimate Goal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            } else if !isLocked {
                // Show label only for significant milestones
                if tile.value >= 256 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                        Text("Reached")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.green)
                    .opacity(0.7)
                }
            } else {
                // Don't show "Locked" for every tile, too cluttered
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 80)
    }
}

#Preview {
    TileScrollerView()
        .environment(\.gameStore, GameStore())
        .environment(\.tileJourney, JourneyKit.Store(config: .init(minPower: 8, maxPower: 22)))
}
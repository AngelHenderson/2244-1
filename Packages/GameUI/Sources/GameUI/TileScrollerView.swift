import SwiftUI
import GameCore
import GameApp

public struct TileScrollerView: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.tileJourney) private var journey
    @Environment(\.homeActions) private var actions
    @State private var focusedTileID: Int? = nil
    @State private var showAnimation = false
    
    private var currentHighestTile: Int {
        max(2, gameStore.state.highestTile)
    }
    
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
        let highestValue = max(2, gameStore.state.highestTile)
        // Find the index of the user's highest tile in the reversed array
        return tiles.firstIndex { tile in
            !tile.tile.isInfinity && tile.tile.value == highestValue
        }
    }
    
    public init() {}
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: itemSpacing) {
                ForEach(tiles, id: \.id) { item in
                    TileRowItem(
                        tile: item.tile,
                        isLocked: isLocked(item.tile),
                        isCurrentHighest: item.tile.value == currentHighestTile && !item.tile.isInfinity,
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
            // Initial position: scroll to user's current highest tile
            await setInitialScrollPosition()
        }
        .onChange(of: gameStore.state.highestTile) { _, newValue in
            // Update scroll position if user achieves a new highest tile
            if let newIndex = tiles.firstIndex(where: { !$0.tile.isInfinity && $0.tile.value == newValue }) {
                withAnimation(.snappy(duration: 0.3)) {
                    focusedTileID = newIndex
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
    
    @MainActor
    private func setInitialScrollPosition() async {
        // Find the user's current position in the journey
        if let currentIndex = highestUnlockedIndex {
            focusedTileID = currentIndex
            
            // Double-check after a brief delay to ensure layout is complete
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            if focusedTileID != currentIndex {
                focusedTileID = currentIndex
            }
        } else {
            // Fallback: if no highest tile found, start near the bottom (tile 2)
            if let firstTileIndex = tiles.firstIndex(where: { $0.tile.value == 2 }) {
                focusedTileID = firstTileIndex
            }
        }
    }
}

private struct TileRowItem: View {
    let tile: Tile
    let isLocked: Bool
    let isCurrentHighest: Bool
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
                .overlay(
                    isCurrentHighest ?
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .shadow(color: .orange.opacity(0.5), radius: 8)
                    : nil
                )
                .animation(.snappy(duration: 0.25), value: isLocked)
                .animation(.snappy(duration: 0.25), value: isCurrentHighest)
                
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
            } else if isCurrentHighest {
                // Highlight current position
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                    Text("Current")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            } else if !isLocked && tile.value >= 256 {
                // Show label only for significant milestones
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                    Text("Reached")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.green)
                .opacity(0.7)
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
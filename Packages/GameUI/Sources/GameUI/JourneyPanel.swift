import SwiftUI
import GameApp
import GameCore

struct JourneyPanel: View {
    @Environment(\.gameStore) private var gameStore
    let showAll: Bool
    
    init(showAll: Bool = false) {
        self.showAll = showAll
    }
    
    private func journeyValues() -> [Tile] {
        var tiles: [Tile] = []
        var current = 2
        if showAll {
            // Build a long list up to a reasonable limit, then infinity
            let limit = 60
            for _ in 0..<limit {
                tiles.append(Tile(value: current))
                if current > (Int.max >> 1) { break }
                current = current << 1
            }
            tiles.append(Tile(value: 0, type: .infinity))
            return tiles
        }
        let highest = max(2, gameStore.state.highestTile)
        // Show up to 8 steps beyond current highest, capped to avoid overflow
        let cap: Int = {
            if highest > (Int.max >> 5) { return Int.max }
            var v = highest
            for _ in 0..<8 {
                if v > (Int.max >> 1) { return Int.max }
                v = v << 1
            }
            return v
        }()
        while current > 0 && current <= cap {
            tiles.append(Tile(value: current))
            if current > (Int.max >> 1) { break }
            current = current << 1
        }
        tiles.append(Tile(value: 0, type: .infinity))
        return tiles
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                let highest = max(2, gameStore.state.highestTile)
                let tiles = Array(journeyValues().reversed())
                ForEach(tiles.indices, id: \.self) { index in
                    let tile = tiles[index]
                    VStack(spacing: 4) {
                        TileView(
                            tile: tile,
                            isSelected: false,
                            isValid: true,
                            size: 120
                        )
                        if tile.value == highest {
                            Text("Highest Tile")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    if index < tiles.count - 1 {
                        JourneyDotTrail(height: 64, dotCount: 4, dotSize: 6)
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
        }
    }
}

private struct JourneyDotTrail: View {
    let height: CGFloat
    let dotCount: Int
    let dotSize: CGFloat

    var body: some View {
        let clampedCount = max(1, min(dotCount, 4))
        let totalDotsHeight = CGFloat(clampedCount) * dotSize
        let spacing = max(4, (height - totalDotsHeight) / CGFloat(clampedCount + 1))

        VStack(spacing: spacing) {
            ForEach(0..<clampedCount, id: \.self) { _ in
                Circle()
                    .frame(width: dotSize, height: dotSize)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: height, alignment: .center)
    }
}




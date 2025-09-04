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
            LazyVStack(spacing: 64) {
                let highest = max(2, gameStore.state.highestTile)
                let values = journeyValues()
                // Show higher values toward the top (reverse order)
                ForEach(values.reversed(), id: \.id) { tile in
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
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
        }
    }
}




import SwiftUI
import GameApp
import GameCore

struct JourneyPreview: View {
    @Environment(\.gameStore) private var gameStore
    
    private func fiveTileWindow() -> [Tile] {
        let highest = gameStore.state.highestTile
        // If no highest yet, default preview window
        if highest <= 0 {
            return [2, 4, 8, 16, 32].map { Tile(value: $0) }
        }
        // Compute two lower and two higher around highest
        func lower(_ v: Int, steps: Int) -> Int {
            guard v > 0 else { return 2 }
            var x = v
            for _ in 0..<steps { x = max(2, x / 2) }
            return max(2, x)
        }
        func higher(_ v: Int, steps: Int) -> Int {
            guard v > 0 else { return 2 }
            var x = v
            for _ in 0..<steps {
                if x > (Int.max >> 1) { return Int.max }
                x = x << 1
            }
            return x
        }
        let l2 = lower(highest, steps: 2)
        let l1 = lower(highest, steps: 1)
        let h1 = higher(highest, steps: 1)
        let h2 = higher(highest, steps: 2)
        return [l2, l1, highest, h1, h2].map { value in
            if value == Int.max { return Tile(value: 0, type: .infinity) }
            return Tile(value: value)
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(fiveTileWindow().enumerated()), id: \.0) { _, tile in
                TileView(
                    tile: tile,
                    isSelected: false,
                    isValid: true,
                    size: 56
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}



import SwiftUI
import GameApp
import GameCore

struct HomeButton: View {
    @Environment(\.gameStore) private var gameStore
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onTap?() }) {
            VStack(spacing: 8) {
                let highest = gameStore.state.highestTile
                if highest > 0 {
                    TileView(tile: Tile(value: highest), isSelected: false, isValid: true, size: 72)
                } else {
                    TileView(tile: nil, isSelected: false, isValid: true, size: 72)
                }
                Text("Highest Tile")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Home")
    }
}




import SwiftUI
import GameApp
import GameCore

struct MergeInfoBoard: View {
    @Environment(\.gameStore) private var gameStore
    let info: GameStore.MergeInfo
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("New Tile Unlocked")
                .font(.title2.weight(.bold))
            // Unlocked block (first)
            tileCard(title: "Unlocked", value: info.unlocked, highlight: true)

            // Added block (second)
            tileCard(title: "Added", value: info.added, highlight: false)

            // Eliminated block (last)
            tileCard(title: "Eliminated", value: info.excluded, highlight: false)

            Button("Continue") { onClose() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding(24)
        .presentationDetents([.height(460)])
        .presentationDragIndicator(.visible)
    }
}

private extension MergeInfoBoard {
    @ViewBuilder
    func tileCard(title: String, value: Int?, highlight: Bool) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if let value { Text(CompactNumberFormatter.format(value)).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity)

            if let v = value {
                TileView(tile: Tile(value: v), isSelected: false, isValid: true, size: highlight ? 88 : 72)
                    .accessibilityLabel("Tile \(v)")
            } else {
                Text("-").font(.title2.weight(.bold)).frame(height: highlight ? 88 : 72)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}



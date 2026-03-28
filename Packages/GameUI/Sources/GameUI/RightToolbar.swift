import SwiftUI
import GameApp

struct RightToolbar: View {
    @Environment(\.gameStore) private var gameStore
    let onHammer: () -> Void
    let onSwap: () -> Void
    let onMagnet: () -> Void
    
    var body: some View {
        VStack(spacing: Tokens.Spacing.xl) {
            // Break Any Tile On The Board (Hammer)
            boosterButton(
                assetName: "hammer",
                count: gameStore.powerUpInventory["hammer", default: 0],
                price: gameStore.powerUpPrice("hammer"),
                action: onHammer
            )
            // Swap Any 2 Tiles With Each Other (Restart/Swap)
            boosterButton(
                assetName: "restart",
                count: gameStore.powerUpInventory["swap", default: 0],
                price: gameStore.powerUpPrice("swap"),
                action: onSwap
            )
            // Merge Same Tiles On The Board (Magnet)
            boosterButton(
                assetName: "magnet",
                count: gameStore.powerUpInventory["magnet", default: 0],
                price: gameStore.powerUpPrice("magnet"),
                action: onMagnet
            )
        }
    }
    
    private func boosterButton(assetName: String, count: Int, price: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .frame(width: Tokens.Size.toolbarButton, height: Tokens.Size.toolbarButton)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.blue, in: Circle())
                        .offset(x: 8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            HStack(spacing: 6) {
                Image("gems")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text("\(price)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.6), in: Capsule())
            .offset(x: 78)
        }
    }

}



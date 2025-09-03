import SwiftUI
import GameApp

struct RightToolbar: View {
    @Environment(\.gameStore) private var gameStore
    let onHammer: () -> Void
    let onShuffle: () -> Void
    let onMagnet: () -> Void
    
    var body: some View {
        VStack(spacing: Tokens.Spacing.xl) {
            boosterButton(system: "hammer.fill", count: 3, price: GameStore.PowerUpCost.hammer, action: onHammer)
            boosterButton(system: "arrow.triangle.2.circlepath", count: 2, price: GameStore.PowerUpCost.shuffle, action: onShuffle)
            boosterButton(system: "scope", count: 2, price: 75, action: onMagnet)
        }
    }
    
    private func boosterButton(system: String, count: Int, price: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = assetImage(for: system) {
                        img
                    } else {
                        Image(systemName: system)
                    }
                }
                .font(.system(size: 22, weight: .bold))
                .frame(width: Tokens.Size.toolbarButton, height: Tokens.Size.toolbarButton)
                .foregroundStyle(.white)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(6)
                        .background(Color.blue, in: Circle())
                        .foregroundStyle(.white)
                        .offset(x: 8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            HStack(spacing: 6) {
                Image(systemName: "diamond.fill").foregroundStyle(.mint)
                Text("\(price)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.6), in: Capsule())
            .offset(x: 78)
        }
    }

    private func assetImage(for system: String) -> Image? {
        // Map common system names to expected asset names for replacement
        let map: [String: String] = [
            "hammer.fill": "booster_hammer",
            "arrow.triangle.2.circlepath": "booster_shuffle",
            "scope": "booster_magnet"
        ]
        let target = map[system]
        #if canImport(UIKit)
        if let name = target, let img = UIImage(named: name) { return Image(uiImage: img) }
        #elseif canImport(AppKit)
        if let name = target, let img = NSImage(named: name) { return Image(nsImage: img) }
        #endif
        return nil
    }
}



import SwiftUI
import GameApp

struct PlayButton: View {
    @Environment(\.gameStore) private var gameStore
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onTap?() ?? gameStore.resetGame() }) {
            VStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Color.green, in: Circle())
                Text("Play")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play")
    }
}




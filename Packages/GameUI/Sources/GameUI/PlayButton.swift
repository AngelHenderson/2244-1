import SwiftUI
import GameApp

struct PlayButton: View {
    @Environment(\.gameStore) private var gameStore
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            gameStore.resetGame()
            onTap?()
        }) {
            VStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    //.foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Color.green, in: Circle())
                Text("Play")
                    .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play")
    }
}




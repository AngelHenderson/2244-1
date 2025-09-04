import SwiftUI
import GameApp

struct HUDTopBar: View {
    @Environment(HomeState.self) private var state
    @Environment(\.homeActions) private var actions

    var body: some View {
        HStack {
            Button(action: { actions.openLeaderboard() }) {
                Text("Rank: \(state.rank)")
                    .font(.headline)
                    .padding(.horizontal, 12).padding(.vertical, 6)
            }
            .modifier(GlassButtonCompat())
            .accessibilityLabel("Rank \(state.rank). Open leaderboard.")

            Spacer()

            Button(action: { actions.openShop() }) {
                HStack(spacing: 8) {
                    Image("gem")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                    Text("\(state.gems)")
                        .font(.title3.monospacedDigit())
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.medium)
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
            }
            .modifier(GlassButtonCompat())
            .accessibilityLabel("Gems \(state.gems). Open shop.")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private struct GlassButtonCompat: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.plain)
        }
    }
}

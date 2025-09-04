import SwiftUI
import GameApp

struct HUDTopBar: View {
    @Environment(HomeState.self) private var state
    @Environment(\.homeActions) private var actions

    var body: some View {
        HStack {
            // Rank badge
            if #available(iOS 26.0, macOS 26.0, *) {
                Button(action: { actions.openLeaderboard() }) {
                    Text("Rank: \(state.rank)")
                        .font(.headline)
                    //.foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                    
                }
//                .glassEffectCompat(cornerRadius: 8)
                .buttonStyle(.glass)
                .accessibilityLabel("Rank \(state.rank). Open leaderboard.")
            } else {
                // Fallback on earlier versions
            }

            Spacer()

            // Gems counter (tappable) – opens shop
            if #available(iOS 26.0, macOS 26.0, *) {
                Button(action: { actions.openShop() }) {
                    HStack(spacing: 8) {
                        Image("gem")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                        Text("\(state.gems)")
                            .font(.title3.monospacedDigit())
                        //.foregroundStyle(.white)
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.medium)
                            .foregroundStyle(.green)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                }
//                .glassEffectCompat(cornerRadius: 8)
                .buttonStyle(.glass)
                .accessibilityLabel("Gems \(state.gems). Open shop.")
            } else {
                // Fallback on earlier versions
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

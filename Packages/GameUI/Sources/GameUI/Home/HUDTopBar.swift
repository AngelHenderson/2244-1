import SwiftUI
import GameApp

struct HUDTopBar: View {
    @Environment(HomeState.self) private var state
    @Environment(\.homeActions) private var actions

    var body: some View {
        HStack {
            // Rank badge
            Text("Rank: \(state.rank)")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .accessibilityLabel("Rank \(state.rank)")

            Spacer()

            // Gems counter with buy button
            HStack(spacing: 8) {
                Image("gem")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text("\(state.gems)")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.white)
                Button(action: { actions.buyGems() }) {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(.green)
                }
                .accessibilityLabel("Buy gems")
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Gems \(state.gems). Buy more.")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

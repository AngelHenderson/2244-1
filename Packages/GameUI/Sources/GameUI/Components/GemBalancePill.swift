import SwiftUI
import GameApp

/// A compact pill showing the user's current gem balance.
/// Reads `HomeState.gems` from the environment so callers don't need to pass gems explicitly.
public struct GemBalancePill: View {
    @Environment(HomeState.self) private var homeState

    public init() {}

    public var body: some View {
        HStack(spacing: 6) {
            Image("gem", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            Text(verbatim: String(homeState.gems))
                .font(.avenirNext(size: 14, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
    }
}

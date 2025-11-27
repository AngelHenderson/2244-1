import SwiftUI
import GameApp
import GameCore
#if canImport(GameKit)
import GameKit
#endif
import Foundation

struct HUDTopBar: View {
    @Environment(HomeState.self) private var state
    @Environment(\.homeActions) private var actions
    @Environment(\.gameStore) private var gameStore
    var score: Int? = nil  // Optional score for game context

    var body: some View {
        HStack(spacing: 8) {
            scoreBoostButton
            // Game Center profile button (shown only if available / authenticated)
            gameCenterButton
            
            Button(action: { actions.openLeaderboard() }) {
                HStack(spacing: 4) {
                    Text("Rank:")
                    Text(verbatim: String(state.rank))
                        .monospacedDigit()
                }
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .modifier(GlassButtonCompat())
            .accessibilityLabel("Rank \(String(state.rank)). Open leaderboard.")

            // Score display (only shown if provided)
            if let score = score {
                VStack(spacing: 2) {
                    Text("Score")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    // Use AlphaMag 1_000-step units: K, M, B, a, b, c, ...
                    Text(AlphaMag.formatScoreDisplay(score))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .modifier(GlassButtonCompat())
            }

            Spacer()

            Button(action: { actions.openShop() }) {
                HStack(spacing: 8) {
                    Image("gem")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                    Text(verbatim: String(state.gems))
                        .font(.title3.monospacedDigit())
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.medium)
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
            }
            .modifier(GlassButtonCompat())
            .accessibilityLabel("Gems \(String(state.gems)). Open shop.")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var gameCenterButton: some View {
        #if canImport(GameKit)
        if GKLocalPlayer.local.isAuthenticated {
            GameCenterAvatarButton(action: { actions.openLeaderboard() })
                .accessibilityLabel("Game Center profile. Open leaderboard.")
        }
        #else
        EmptyView()
        #endif
    }
    
    private var scoreBoostButton: some View {
        Button(action: { _ = gameStore.purchaseScoreBoost() }) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.headline)
                    .foregroundStyle(gameStore.isScoreBoostActive ? .yellow : .white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("5× Score • \(gameStore.scoreBoostCost) Gems")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(gameStore.scoreBoostCountdownText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(gameStore.isScoreBoostActive ? .green : .white.opacity(0.8))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .modifier(GlassButtonCompat())
        .opacity(gameStore.canPurchaseScoreBoost ? 1.0 : 0.7)
        .disabled(!gameStore.canPurchaseScoreBoost)
        .accessibilityLabel("Five times score boost. \(gameStore.scoreBoostCountdownText)")
    }

#if canImport(GameKit)
private struct GameCenterAvatarButton: View {
    let action: () -> Void
    @State private var avatar: UIImage? = nil
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color.white.opacity(0.08))
                Group {
                    if let avatar {
                        Image(uiImage: avatar)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .clipShape(Circle())
            }
            .frame(width: 36, height: 36)
            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .task { await loadAvatar() }
    }
    
    @MainActor
    private func loadAvatar() async {
        guard avatar == nil else { return }
        let player = GKLocalPlayer.local
        guard player.isAuthenticated else { return }
        let image = await withCheckedContinuation { (cont: CheckedContinuation<UIImage?, Never>) in
            player.loadPhoto(for: .small) { image, _ in
                cont.resume(returning: image)
            }
        }
        self.avatar = image
    }
}
#endif
}

private struct GlassButtonCompat: ViewModifier {
    @Environment(\.gameStore) private var gameStore
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .buttonStyle(.glass)
        } else {
            content.buttonStyle(.plain)
        }
    }
    
}

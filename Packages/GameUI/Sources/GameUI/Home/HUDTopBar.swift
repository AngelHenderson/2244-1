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
    var scoreText: String? = nil  // Optional score for game context

    private func playtimeText(at date: Date) -> String {
        let savedSeconds = UserDefaults.standard.integer(forKey: "playtime.totalSeconds")
        let sessionStart = gameStore.achievementEvaluator?.sessionStartTime ?? date
        let currentSessionSeconds = Int(date.timeIntervalSince(sessionStart))
        let totalSeconds = savedSeconds + currentSessionSeconds
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "⏱️ %d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 6) {
            // Rank button (left side)
            Button(action: { actions.openLeaderboard() }) {
                HStack(spacing: 3) {
                    Text("#")
                        .foregroundStyle(.white)
                    Text(verbatim: String(state.rank))
                        .foregroundStyle(.white)
                }
                .font(.subheadline.bold())
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .modifier(GlassButtonCompat())
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Rank \(String(state.rank)). Open leaderboard.")

            // Game Center profile button (shown only if available / authenticated)
            gameCenterButton

            Spacer()

            // Compact boost status button
//            BoostStatusButton()

            // Score display (only shown if provided)
            if let scoreText = scoreText {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 1) {
                        Text(playtimeText(at: context.date))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.yellow.opacity(0.9))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Text("Score")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                        Text(scoreText)
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .modifier(GlassButtonCompat())
            }

            Button(action: { actions.openShop() }) {
                HStack(spacing: 6) {
                    Image("gem")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    Text(verbatim: String(state.gems))
                        .font(.subheadline.bold().monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.small)
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .fixedSize(horizontal: true, vertical: false)
            }
            .modifier(GlassButtonCompat())
            .accessibilityLabel("Gems \(String(state.gems)). Open shop.")
        }
        .padding(.horizontal, 12)
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

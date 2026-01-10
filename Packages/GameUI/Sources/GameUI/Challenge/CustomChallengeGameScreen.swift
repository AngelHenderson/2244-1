import SwiftUI
import GameCore
import GameApp

/// Dedicated screen for playing custom challenges (separate from regular gameplay)
public struct CustomChallengeGameScreen: View {
    let config: CustomChallengeConfig
    let onDismiss: () -> Void

    // Challenge has its own sandboxed GameStore - doesn't persist to main game
    @State private var challengeGameStore: GameStore
    @Environment(HomeState.self) private var homeState
    @State private var timeRemaining: Int
    @State private var isTimerActive = true
    @State private var showResult = false
    @State private var challengeWon = false

    public init(config: CustomChallengeConfig, onDismiss: @escaping () -> Void) {
        self.config = config
        self.onDismiss = onDismiss
        self._timeRemaining = State(initialValue: config.timeLimitSeconds)
        // Use sandboxed GameStore to prevent challenge progress from affecting main game
        self._challengeGameStore = State(initialValue: GameStore.sandboxed())
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Challenge header with timer and target
                challengeHeader

                // Game board - uses challenge's own GameStore
                BoardView()
                    .environment(\.gameStore, challengeGameStore)

                Spacer()
            }

            // Result overlay
            if showResult {
                resultOverlay
            }
        }
        .onAppear {
            startChallenge()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard isTimerActive else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                endChallenge(won: checkWinCondition())
            }
        }
        .onChange(of: challengeGameStore.state.scoreValue) { _, _ in
            // Check if target reached
            if checkWinCondition() {
                endChallenge(won: true)
            }
        }
    }

    private var challengeHeader: some View {
        HStack {
            // Back button
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Target display
            VStack(spacing: 2) {
                Text("TARGET")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(targetLabel)
                    .font(.system(.title3, design: .rounded).bold())
            }

            Spacer()

            // Timer display
            VStack(spacing: 2) {
                Text("TIME")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(formatTime(timeRemaining))
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(timeRemaining <= 10 ? .red : .primary)
            }

            Spacer()

            // Current score
            VStack(spacing: 2) {
                Text("SCORE")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(formatScore(challengeGameStore.state.scoreValue.toInt()))
                    .font(.system(.title3, design: .rounded).bold())
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(challengeWon ? "CHALLENGE COMPLETE!" : "TIME'S UP!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(challengeWon ? .green : .red)

                if challengeWon {
                    HStack(spacing: 8) {
                        Image(systemName: "diamond.fill")
                            .foregroundStyle(.mint)
                        Text("+\(config.predictedRewardGems)")
                            .font(.system(.title, design: .rounded).bold())
                    }
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(.blue))
                        .foregroundStyle(.white)
                }
            }
            .padding(32)
            .background(RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial))
        }
    }

    private var targetLabel: String {
        switch config.target {
        case .score(let value):
            return value == Int.max ? "∞" : formatScore(value)
        case .tile(let value):
            return AlphaMag.formatTileValue(value)
        case .tileStep(let step):
            // Use TileStepLabelFormatter for step-based targets
            if step == Int.max {
                return "∞"
            }
            return TileStepLabelFormatter.labelForStep(step, start: 2)
        case .chain(let length):
            return "\(length) chain"
        }
    }

    private func formatScore(_ value: Int) -> String {
        if value >= 1_000_000_000 { return "\(value / 1_000_000_000)B" }
        if value >= 1_000_000 { return "\(value / 1_000_000)M" }
        if value >= 1_000 { return "\(value / 1_000)K" }
        return "\(value)"
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func startChallenge() {
        // Reset challenge game state with spawn limits from config
        let gameConfig = GameConfig(
            minSpawnStep: config.minSpawnStep,
            maxSpawnStep: config.maxSpawnStep
        )
        challengeGameStore.resetGame(with: gameConfig)
        isTimerActive = true
    }

    private func checkWinCondition() -> Bool {
        switch config.target {
        case .score(let target):
            return challengeGameStore.state.scoreValue.toInt() >= target
        case .tile(let target):
            return challengeGameStore.state.highestTile >= target
        case .tileStep(let targetStep):
            // Compare using step values
            return challengeGameStore.state.highestTileStep >= targetStep
        case .chain:
            // Check if any chain of required length was made
            return false // TODO: Track chain lengths
        }
    }

    private func endChallenge(won: Bool) {
        isTimerActive = false
        challengeWon = won

        if won {
            // Award gems
            homeState.addGems(config.predictedRewardGems)
        }

        withAnimation {
            showResult = true
        }
    }
}

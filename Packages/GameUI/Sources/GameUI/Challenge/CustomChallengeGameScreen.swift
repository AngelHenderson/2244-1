import SwiftUI
import GameCore
import GameApp
import GameServices

/// Dedicated screen for playing custom challenges (separate from regular gameplay)
public struct CustomChallengeGameScreen: View {
    let config: CustomChallengeConfig
    let onDismiss: () -> Void

    // Challenge has its own sandboxed GameStore - doesn't persist to main game
    @State private var challengeGameStore: GameStore
    @Environment(HomeState.self) private var homeState
    @Environment(\.hapticsService) private var haptics
    @Environment(\.challengeStore) private var challengeStore
    @State private var timeRemaining: Int
    @State private var isTimerActive = true
    @State private var showResult = false
    @State private var challengeWon = false

    // Power-up selection modes
    @State private var isHammerMode = false
    @State private var isSwapMode = false
    @State private var isMagnetMode = false
    @State private var firstSwapPosition: Position? = nil

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

                // Power-up dock
                powerUpDock
                    .padding(.top, 8)

                // Game board - uses challenge's own GameStore
                ZStack {
                    SimplifiedGlassBoardView(onTileTap: handleTileTap)
                        .environment(\.gameStore, challengeGameStore)
                        .padding(.horizontal, 8)

                    // Mode overlay indicators
                    if isHammerMode || isSwapMode || isMagnetMode {
                        ModeOverlay(
                            isHammerMode: isHammerMode,
                            isSwapMode: isSwapMode,
                            isMagnetMode: isMagnetMode,
                            firstSwapPosition: firstSwapPosition,
                            onCancel: cancelAllModes
                        )
                    }
                }

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
        .onChange(of: challengeGameStore.coins) { _, newValue in
            // Sync gem spending back to player's inventory
            homeState.gems = newValue
        }
    }

    // MARK: - Power-up Dock

    private var powerUpDock: some View {
        HStack(spacing: 12) {
            // Hammer
            powerupItem(
                assetName: "hammer",
                badge: challengeGameStore.powerUpInventory["hammer", default: 0],
                price: challengeGameStore.powerUpPrice("hammer"),
                isEnabled: challengeGameStore.isPowerUpAvailable("hammer"),
                action: handleHammer
            )

            // Swap
            powerupItem(
                assetName: "restart",
                badge: challengeGameStore.powerUpInventory["swap", default: 0],
                price: challengeGameStore.powerUpPrice("swap"),
                isEnabled: challengeGameStore.isPowerUpAvailable("swap"),
                action: handleSwap
            )

            // Magnet
            powerupItem(
                assetName: "magnet",
                badge: challengeGameStore.powerUpInventory["magnet", default: 0],
                price: challengeGameStore.powerUpPrice("magnet"),
                isEnabled: challengeGameStore.isPowerUpAvailable("magnet"),
                action: handleMagnet
            )

            // Undo
            powerupItem(
                icon: "arrow.uturn.backward",
                isEnabled: challengeGameStore.state.undoAvailable,
                action: handleUndo
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 4)
        )
    }

    private func powerupItem(
        icon: String,
        badge: Int = 0,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .frame(width: 40, height: 40)
                    .foregroundStyle(isEnabled ? .primary : .tertiary)

                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue, in: Capsule())
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }

    private func powerupItem(
        assetName: String,
        badge: Int = 0,
        price: Int? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .frame(width: 40, height: 40)
                    .opacity(isEnabled ? 1.0 : 0.4)

                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue, in: Capsule())
                        .offset(x: 4, y: -4)
                } else if let price = price {
                    HStack(spacing: 1) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 7))
                        Text("\(price)")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.6), in: Capsule())
                    .offset(x: 10, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }

    // MARK: - Power-up Handlers

    private func handleHammer() {
        if challengeGameStore.isPowerUpAvailable("hammer") {
            cancelAllModes()
            isHammerMode = true
            haptics.lightImpact()
        } else {
            haptics.error()
        }
    }

    private func handleSwap() {
        if challengeGameStore.isPowerUpAvailable("swap") {
            cancelAllModes()
            isSwapMode = true
            firstSwapPosition = nil
            haptics.lightImpact()
        } else {
            haptics.error()
        }
    }

    private func handleMagnet() {
        if challengeGameStore.isPowerUpAvailable("magnet") {
            cancelAllModes()
            isMagnetMode = true
            haptics.lightImpact()
        } else {
            haptics.error()
        }
    }

    private func handleUndo() {
        if challengeGameStore.state.undoAvailable {
            _ = challengeGameStore.useUndo()
            haptics.lightImpact()
        } else {
            haptics.error()
        }
    }

    private func handleTileTap(at position: Position) {
        // Handle hammer mode
        if isHammerMode {
            if challengeGameStore.state.board[position] != nil {
                _ = challengeGameStore.useHammer(at: position)
                haptics.success()
                isHammerMode = false
            } else {
                haptics.error()
            }
            return
        }

        // Handle swap mode
        if isSwapMode {
            if challengeGameStore.state.board[position] != nil {
                if let first = firstSwapPosition {
                    if first != position {
                        _ = challengeGameStore.useSwap(first, position)
                        haptics.success()
                        isSwapMode = false
                        firstSwapPosition = nil
                    } else {
                        firstSwapPosition = nil
                        haptics.lightImpact()
                    }
                } else {
                    firstSwapPosition = position
                    haptics.lightImpact()
                }
            } else {
                haptics.error()
            }
            return
        }

        // Handle magnet mode
        if isMagnetMode {
            if let tile = challengeGameStore.state.board[position] {
                let success = challengeGameStore.useMagnet(value: tile.value, to: position)
                if success {
                    haptics.success()
                } else {
                    haptics.warning()
                }
                isMagnetMode = false
            } else {
                haptics.error()
            }
            return
        }
    }

    private func cancelAllModes() {
        isHammerMode = false
        isSwapMode = false
        isMagnetMode = false
        firstSwapPosition = nil
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
            if value == Int.max { return "∞" }
            return formatLargeNumber(value)
        case .tile(let value):
            return TileStepLabelFormatter.formatTileValue(value)
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
        return formatLargeNumber(value)
    }

    /// Format large numbers with K, M, B, a, b, c... suffixes
    private func formatLargeNumber(_ value: Int) -> String {
        if value < 1_000 { return "\(value)" }
        if value < 1_000_000 { return "\(value / 1_000)K" }
        if value < 1_000_000_000 { return "\(value / 1_000_000)M" }
        if value < 1_000_000_000_000 { return "\(value / 1_000_000_000)B" }

        // For trillions and beyond, use alphabetic suffixes
        let trillion = 1_000_000_000_000
        var remaining = value
        var tier = 0

        while remaining >= trillion {
            remaining /= 1_000
            tier += 1
        }

        // tier 1 = a (trillions), tier 2 = b (quadrillions), etc.
        let suffix = alphabeticSuffix(for: tier)
        return "\(remaining / 1_000_000_000)\(suffix)"
    }

    private func alphabeticSuffix(for tier: Int) -> String {
        guard tier >= 1 else { return "" }
        var n = tier
        var result = ""
        while n > 0 {
            n -= 1
            let char = Character(UnicodeScalar(97 + (n % 26))!) // 'a' = 97
            result = String(char) + result
            n /= 26
        }
        return result
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

        // Initialize gems from player's inventory AFTER reset (since reset clears state)
        challengeGameStore.coins = homeState.gems

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

            // Mark challenge as completed for milestone tracking (triggers 1hr unlock delay)
            if let challengeId = config.challengeId {
                challengeStore.markCompleted(challengeId)
            }
        }

        withAnimation {
            showResult = true
        }
    }
}

import SwiftUI
import GameCore
import GameApp
import GameServices

/// Wraps HybridGameScreen with challenge-specific overlays (timer, win/loss, recovery).
/// Injects a sandboxed GameStore so challenge gameplay doesn't affect the main game.
public struct ChallengeGameWrapper: View {
    let config: CustomChallengeConfig
    let onDismiss: () -> Void

    // Challenge has its own sandboxed GameStore
    @State private var challengeGameStore: GameStore
    @Environment(HomeState.self) private var homeState
    @Environment(\.hapticsService) private var haptics
    @Environment(\.challengeStore) private var challengeStore
    @Environment(\.gameStore) private var mainGameStore
    @Environment(\.socialFeedPublisher) private var socialFeedPublisher

    // Timer state
    @State private var startTime = Date()
    private let totalDuration: Int

    // Challenge outcome
    @State private var showResult = false
    @State private var challengeWon = false
    @State private var challengeEnded = false
    @State private var frozenTimeRemaining: Int?
    @State private var longestChainLength = 0

    // Time recovery
    @State private var isShowingTimeRecovery = false
    @State private var isShowingInsufficientGemsAlert = false
    @State private var hasUsedTimeRecovery = false

    // Store player's highest tile/step for consistent power-up pricing
    private let playerHighestTile: Int
    private let playerHighestTileStep: Int

    public init(
        config: CustomChallengeConfig,
        playerHighestTile: Int = 0,
        playerHighestTileStep: Int = 0,
        initialGems: Int = 0,
        onDismiss: @escaping () -> Void
    ) {
        self.config = config
        self.onDismiss = onDismiss
        self.playerHighestTile = playerHighestTile
        self.playerHighestTileStep = playerHighestTileStep
        self.totalDuration = config.timeLimitSeconds

        self._challengeGameStore = State(
            initialValue: GameStore.sandboxed(
                initialGems: initialGems,
                playerHighestTile: playerHighestTile,
                playerHighestTileStep: playerHighestTileStep
            )
        )
    }

    // MARK: - Timer

    private func timeRemainingAt(_ date: Date) -> Int {
        if let frozen = frozenTimeRemaining { return frozen }
        let elapsed = Int(date.timeIntervalSince(startTime))
        return max(0, totalDuration - elapsed)
    }

    private var timeRemaining: Int {
        timeRemainingAt(Date())
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // The main gameplay screen, using the sandboxed challenge store
            HybridGameScreen(isPlayingDismiss: {
                // "Home" from the power-up overlay should end the challenge as a loss
                if !challengeEnded {
                    endChallenge(won: false)
                }
            })
            .environment(\.gameStore, challengeGameStore)

            // Challenge timer overlay (top)
            if !showResult {
                VStack {
                    challengeTimerBanner
                    Spacer()
                }
            }

            // Time recovery overlay
            if isShowingTimeRecovery {
                timeRecoveryOverlay
            }

            // Result overlay (covers everything)
            if showResult {
                resultOverlay
            }
        }
        .onAppear {
            startChallenge()
        }
        // Win condition: score or tile target reached
        .onChange(of: challengeGameStore.state.scoreValue) { _, _ in
            if checkWinCondition() {
                endChallenge(won: true)
            }
        }
        .onChange(of: challengeGameStore.state.highestTileStep) { _, _ in
            if checkWinCondition() {
                endChallenge(won: true)
            }
        }
        // Gem sync: deduct spending from homeState + mainGameStore
        .onChange(of: challengeGameStore.coins) { oldValue, newValue in
            if newValue < oldValue {
                let spent = oldValue - newValue
                homeState.gems -= spent
                _ = mainGameStore.spendCoins(spent)
            }
        }
        // Power-up sync: mirror inventory changes back to main store
        .onChange(of: challengeGameStore.powerUpInventory) { oldInventory, newInventory in
            for (type, newCount) in newInventory {
                let oldCount = oldInventory[type, default: 0]
                if newCount < oldCount {
                    // Power-up was consumed — deduct from main store too
                    let used = oldCount - newCount
                    for _ in 0..<used {
                        mainGameStore.consumePowerUp(type)
                    }
                }
            }
        }
        // Track chain length for chain-target challenges + achievements
        .onChange(of: challengeGameStore.lastChainLength) { _, chainLength in
            if chainLength > 0 {
                longestChainLength = max(longestChainLength, chainLength)
                mainGameStore.achievementEvaluator?.onTilesMerged(count: chainLength)
                if checkWinCondition() {
                    endChallenge(won: true)
                }
            }
        }
        // Track moves for achievements
        .onChange(of: challengeGameStore.state.moves) { oldMoves, newMoves in
            if newMoves > oldMoves {
                mainGameStore.achievementEvaluator?.onMoveSurvived()
            }
        }
        .alert("Can't Afford Recovery Item", isPresented: $isShowingInsufficientGemsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            let needed = timeRecoveryCost - homeState.gems
            Text("You need \(timeRecoveryCost) gems to recover time, but you only have \(homeState.gems). You need \(needed) more gems.")
        }
        .trackScreen(.customChallengeGameplay)
    }

    // MARK: - Timer Banner

    private var challengeTimerBanner: some View {
        TimelineView(.animation(minimumInterval: 0.5, paused: false)) { context in
            let remaining = timeRemainingAt(context.date)
            HStack(spacing: 16) {
                // Timer
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 14, weight: .bold))
                    Text(formatTime(remaining))
                        .font(.system(.subheadline, design: .monospaced).bold())
                        .contentTransition(.numericText())
                }
                .foregroundStyle(remaining <= 10 ? .red : .white)

                Spacer()

                // Target
                HStack(spacing: 6) {
                    Text("TARGET")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(targetLabel)
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.55))
                    .overlay(
                        Capsule()
                            .strokeBorder(remaining <= 10 ? Color.red.opacity(0.6) : Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .onChange(of: remaining <= 0) { _, isExpired in
                if isExpired && !challengeEnded {
                    if checkWinCondition() {
                        endChallenge(won: true)
                    } else if !hasUsedTimeRecovery {
                        frozenTimeRemaining = 0
                        isShowingTimeRecovery = true
                    } else {
                        endChallenge(won: false)
                    }
                }
            }
        }
    }

    // MARK: - Time Recovery

    private var timeRecoveryCost: Int {
        if let challengeId = config.challengeId,
           let index = challengeStore.challenges.firstIndex(where: { $0.id == challengeId }) {
            return 500 * (index + 1)
        }
        return 1500
    }

    private let timeRecoveryBonus = 30

    private var timeRecoveryOverlay: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture { /* block taps */ }

            VStack(spacing: 20) {
                Text("Time's Up!")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Text("Add +\(timeRecoveryBonus)s to keep going?")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))

                Button {
                    purchaseTimeRecovery()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 20, weight: .bold))
                        Text("+\(timeRecoveryBonus)s")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                        Text("·")
                            .foregroundColor(.white.opacity(0.5))
                        Image("gem")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                        Text("\(timeRecoveryCost)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.35, green: 0.78, blue: 0.25), Color(red: 0.26, green: 0.62, blue: 0.18)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color(red: 0.45, green: 0.88, blue: 0.35), lineWidth: 2)
                    )
                }
                .opacity(homeState.gems >= timeRecoveryCost ? 1.0 : 0.4)

                if homeState.gems < timeRecoveryCost {
                    Text("Not enough gems")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.red.opacity(0.8))
                }

                Button {
                    isShowingTimeRecovery = false
                    endChallenge(won: false)
                } label: {
                    VStack(spacing: 2) {
                        Text("No Thanks")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)
                    }
                    .fixedSize()
                }
                .padding(.top, 4)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color(white: 0.25), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
            .padding(.horizontal, 30)
        }
    }

    private func purchaseTimeRecovery() {
        guard homeState.gems >= timeRecoveryCost else {
            isShowingInsufficientGemsAlert = true
            return
        }

        homeState.gems -= timeRecoveryCost
        _ = mainGameStore.spendCoins(timeRecoveryCost)
        challengeGameStore.coins -= timeRecoveryCost

        hasUsedTimeRecovery = true
        isShowingTimeRecovery = false

        // Reset timer so remaining = exactly timeRecoveryBonus seconds from now
        startTime = Date().addingTimeInterval(-Double(totalDuration - timeRecoveryBonus))
        frozenTimeRemaining = nil

        haptics.success()
    }

    // MARK: - Result Overlay

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(challengeWon ? "CHALLENGE COMPLETE!" : "TIME'S UP!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(challengeWon ? .green : .red)

                if challengeWon {
                    let fullReward: ChallengeReward? = {
                        if let challengeId = config.challengeId {
                            return challengeStore.reward(for: challengeId)
                        }
                        return nil
                    }()

                    VStack(spacing: 12) {
                        let gemAmount = fullReward?.coins ?? config.predictedRewardGems
                        if gemAmount > 0 {
                            HStack(spacing: 8) {
                                Image("gem")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Text("+\(gemAmount) Gems")
                                    .font(.system(.title3, design: .rounded).bold())
                                    .foregroundStyle(.white)
                            }
                        }

                        if let powerUps = fullReward?.powerUps, !powerUps.isEmpty {
                            ForEach(Array(powerUps.sorted(by: { $0.key.rawValue < $1.key.rawValue })), id: \.key) { type, count in
                                HStack(spacing: 8) {
                                    if type == .hammer || type == .swap || type == .magnet {
                                        Image(powerUpIcon(for: type))
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Image(systemName: powerUpIcon(for: type))
                                            .foregroundStyle(.yellow)
                                    }
                                    Text("+\(count) \(powerUpName(for: type))")
                                        .font(.system(.title3, design: .rounded).bold())
                                        .foregroundStyle(.white)
                                }
                            }
                        }

                        if let spins = fullReward?.spins, spins > 0 {
                            HStack(spacing: 8) {
                                Image("spinthewheel")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Text("+\(spins) \(spins == 1 ? "Spin" : "Spins")")
                                    .font(.system(.title3, design: .rounded).bold())
                                    .foregroundStyle(.white)
                            }
                        }

                        if let boosts = fullReward?.scoreBoosts, !boosts.isEmpty {
                            ForEach(Array(boosts.sorted(by: { $0.key < $1.key })), id: \.key) { multiplier, count in
                                HStack(spacing: 8) {
                                    Image("boost\(multiplier)x")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                    Text("+\(count) \(multiplier)X Boost")
                                        .font(.system(.title3, design: .rounded).bold())
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                }

                Button {
                    onDismiss()
                } label: {
                    Text(challengeWon ? "Continue" : "Try Again")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(.blue))
                        .foregroundStyle(.white)
                }
            }
            .padding(32)
        }
    }

    // MARK: - Helpers

    private func powerUpIcon(for type: PowerUpType) -> String {
        switch type {
        case .hammer: return "hammer"
        case .swap: return "swap"
        case .magnet: return "magnet"
        case .undo: return "arrow.uturn.backward"
        default: return "star.fill"
        }
    }

    private func powerUpName(for type: PowerUpType) -> String {
        switch type {
        case .hammer: return "Hammer"
        case .swap: return "Swap"
        case .magnet: return "MegaMerge"
        case .undo: return "Undo"
        default: return type.rawValue.capitalized
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
            if step == Int.max { return "∞" }
            return TileStepLabelFormatter.labelForStep(step, start: 2)
        case .chain(let length):
            return "\(length) chain"
        }
    }

    private func formatLargeNumber(_ value: Int) -> String {
        if value < 1_000 { return "\(value)" }
        if value < 1_000_000 { return "\(value / 1_000)K" }
        if value < 1_000_000_000 { return "\(value / 1_000_000)M" }
        if value < 1_000_000_000_000 { return "\(value / 1_000_000_000)B" }

        let trillion = 1_000_000_000_000
        var remaining = value
        var tier = 0
        while remaining >= trillion {
            remaining /= 1_000
            tier += 1
        }
        let suffix = alphabeticSuffix(for: tier)
        return "\(remaining / 1_000_000_000)\(suffix)"
    }

    private func alphabeticSuffix(for tier: Int) -> String {
        guard tier >= 1 else { return "" }
        var n = tier
        var result = ""
        while n > 0 {
            n -= 1
            let char = Character(UnicodeScalar(97 + (n % 26))!)
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

    // MARK: - Challenge Lifecycle

    private func startChallenge() {
        let gameConfig = GameConfig(
            minSpawnStep: config.minSpawnStep,
            maxSpawnStep: config.maxSpawnStep,
            disableElimination: true
        )
        challengeGameStore.resetGame(with: gameConfig)

        // Restore player's highest tile/step for consistent power-up pricing
        challengeGameStore.playerHighestTile = playerHighestTile
        challengeGameStore.playerHighestTileStep = playerHighestTileStep

        // Initialize gems from player's inventory AFTER reset
        challengeGameStore.coins = homeState.gems

        // Copy the player's actual power-up inventory so challenge shows real counts
        challengeGameStore.copyPowerUpInventory(from: mainGameStore)

        startTime = Date()
        challengeEnded = false
        longestChainLength = 0
    }

    private func checkWinCondition() -> Bool {
        let containsInfinityTile = challengeGameStore.state.board.cells.contains { row in
            row.contains { $0.tile?.isInfinity == true }
        }
        return config.target.isSatisfied(
            score: challengeGameStore.state.scoreValue.toInt(),
            highestTile: challengeGameStore.state.highestTile,
            highestTileStep: challengeGameStore.state.highestTileStep,
            containsInfinityTile: containsInfinityTile,
            longestChainLength: longestChainLength
        )
    }

    private func endChallenge(won: Bool) {
        guard !challengeEnded else { return }
        frozenTimeRemaining = timeRemaining
        challengeEnded = true
        challengeWon = won

        if won {
            let elapsed = totalDuration - (frozenTimeRemaining ?? 0)
            let mins = elapsed / 60
            let secs = elapsed % 60
            let timeStr = "\(mins):\(String(format: "%02d", secs))"
            socialFeedPublisher.postTimedChallengeComplete(timeString: timeStr)

            if let challengeId = config.challengeId,
               let reward = challengeStore.reward(for: challengeId) {
                mainGameStore.grantChallengeReward(reward)
                if reward.coins > 0 {
                    homeState.gems += reward.coins
                }
            } else {
                homeState.addGems(config.predictedRewardGems)
            }

            if let challengeId = config.challengeId {
                challengeStore.markCompleted(challengeId)
            }
        }

        withAnimation {
            showResult = true
        }
    }
}

#if DEBUG
#Preview("Challenge Game Wrapper") {
    GameUIScreenPreviewHost {
        ChallengeGameWrapper(
            config: ScreenPreviewFixtures.challengeConfig,
            playerHighestTile: 1_048_576,
            playerHighestTileStep: 19,
            initialGems: 1_240,
            onDismiss: {}
        )
    }
}
#endif

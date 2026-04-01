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
    @Environment(\.hapticsService) private var haptics
    @Environment(\.challengeStore) private var challengeStore
    // Reference to main game store for achievement tracking
    @Environment(\.gameStore) private var mainGameStore
    @State private var showResult = false
    @State private var challengeWon = false
    @State private var challengeEnded = false
    @State private var frozenTimeRemaining: Int?

    // Use start time + duration for reliable timer that doesn't stop during merges
    @State private var startTime: Date = Date()
    private let totalDuration: Int

    // Power-up selection modes
    @State private var isHammerMode = false
    @State private var isSwapMode = false
    @State private var isMagnetMode = false
    @State private var firstSwapPosition: Position? = nil

    // Move alert states
    @State private var isShowingOutOfMoves = false
    @State private var isShowingLowOnMoves = false
    @State private var isShowingPowerUpRecovery = false
    @State private var lowMovesWarningArmed = true

    // Store player's highest tile/step for re-applying after game reset
    private let playerHighestTile: Int
    private let playerHighestTileStep: Int

    public init(config: CustomChallengeConfig, playerHighestTile: Int = 0, playerHighestTileStep: Int = 0, initialGems: Int = 0, onDismiss: @escaping () -> Void) {
        self.config = config
        self.onDismiss = onDismiss
        self.playerHighestTile = playerHighestTile
        self.playerHighestTileStep = playerHighestTileStep
        self.totalDuration = config.timeLimitSeconds

        // Use sandboxed GameStore with player's actual highest tile step for consistent pricing
        self._challengeGameStore = State(initialValue: GameStore.sandboxed(initialGems: initialGems, playerHighestTile: playerHighestTile, playerHighestTileStep: playerHighestTileStep))
    }

    // Computed time remaining based on start time - takes a date parameter for TimelineView
    private func timeRemainingAt(_ date: Date) -> Int {
        if let frozen = frozenTimeRemaining { return frozen }
        let elapsed = Int(date.timeIntervalSince(startTime))
        return max(0, totalDuration - elapsed)
    }

    // Convenience for current time
    private var timeRemaining: Int {
        timeRemainingAt(Date())
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
                    SimplifiedGlassBoardView(onTileTap: handleTileTap, isPowerUpActive: isHammerMode || isSwapMode || isMagnetMode)
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



            // Power-up recovery selection overlay
            if isShowingPowerUpRecovery {
                powerUpRecoveryOverlay
            }
        }
        .onAppear {
            startChallenge()
        }
        .onChange(of: challengeGameStore.state.scoreValue) { _, _ in
            // Check if target reached
            if checkWinCondition() {
                endChallenge(won: true)
            }
        }
        .onChange(of: challengeGameStore.coins) { oldValue, newValue in
            // Only sync actual power-up spending back to player's inventory
            // Ignore gems earned during the challenge (chain bonuses, gifts, etc.)
            if newValue < oldValue {
                let spent = oldValue - newValue
                homeState.gems -= spent
            }
        }
        .onChange(of: challengeGameStore.state.moves) { oldMoves, newMoves in
            // Track moves/move survival for achievements using main game store
            if newMoves > oldMoves {
                mainGameStore.achievementEvaluator?.onMoveSurvived()
            }
        }
        .onChange(of: challengeGameStore.lastChainLength) { _, chainLength in
            // Track merged tiles for achievements using main game store
            if chainLength > 0 {
                mainGameStore.achievementEvaluator?.onTilesMerged(count: chainLength)
            }
        }
        .onChange(of: challengeGameStore.state.isGameOver) { _, isGameOver in
            if isGameOver && !isShowingOutOfMoves && !challengeEnded {
                isShowingOutOfMoves = true
            } else if !isGameOver {
                // Game recovered (e.g., power-up created new moves)
                isShowingOutOfMoves = false
                isShowingPowerUpRecovery = false
            }
        }
        .onChange(of: challengeGameStore.validMovesCount) { _, newCount in
            // Show low-on-moves warning when moves drop to 5 or below
            // Re-arms when moves go back above 5 (e.g., after using a powerup)
            if newCount > 5 {
                lowMovesWarningArmed = true
            } else if newCount > 0 && newCount <= 5 && lowMovesWarningArmed && !challengeGameStore.state.isGameOver && !isShowingOutOfMoves && !challengeEnded {
                lowMovesWarningArmed = false
                isShowingLowOnMoves = true
            }
        }
        .onChange(of: isShowingOutOfMoves) { _, isShowing in
            // If alert dismissed and not entering recovery, execute game over
            if !isShowing && !isShowingPowerUpRecovery && challengeGameStore.state.isGameOver && !challengeEnded {
                endChallenge(won: false)
            }
        }
        .onChange(of: isShowingPowerUpRecovery) { _, isShowing in
            // If recovery dismissed without using a powerup, execute game over
            if !isShowing && challengeGameStore.state.isGameOver && !isShowingOutOfMoves && !challengeEnded {
                endChallenge(won: false)
            }
        }
        .alert("Low On Moves", isPresented: $isShowingLowOnMoves) {
            Button("Use Powerup") {
                isShowingPowerUpRecovery = true
            }
            Button("Continue", role: .cancel) { }
        } message: {
            Text("You are low on moves. Want to use a powerup to free up moves?")
        }
        .alert("Out Of Moves", isPresented: $isShowingOutOfMoves) {
            Button("Use Powerup") {
                isShowingPowerUpRecovery = true
            }
            Button("End Challenge", role: .destructive) {
                endChallenge(won: false)
            }
        } message: {
            Text("You have no moves. Want to use a powerup to revive?")
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
                assetName: "swap",
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

            // Gem wallet
            HStack(spacing: 4) {
                gemImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                Text("\(challengeGameStore.coins)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .padding(.leading, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 4)
        )
    }

    private var gemImage: Image {
        #if canImport(UIKit)
        if let img = UIImage(named: "gem") { return Image(uiImage: img) }
        #elseif canImport(AppKit)
        if let img = NSImage(named: "gem") { return Image(nsImage: img) }
        #endif
        return Image("gem")
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
                        Image("gem")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 8, height: 8)
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
            // Track achievement progress using main game store
            mainGameStore.achievementEvaluator?.onUndoUsed()
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
                // Track achievement progress using main game store
                mainGameStore.achievementEvaluator?.onPowerUpUsed(type: "hammer")
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
                        // Track achievement progress using main game store
                        mainGameStore.achievementEvaluator?.onPowerUpUsed(type: "swap")
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
                    // Track achievement progress using main game store
                    mainGameStore.achievementEvaluator?.onPowerUpUsed(type: "magnet")
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

    private var explicitInstructionText: String? {
        guard config.challengeId != nil else { return nil }

        let timeText = "\(config.timeLimitSeconds) seconds"
        
        switch config.target {
        case .score:
            return "Reach \(targetLabel) score in \(timeText)"
        case .tile, .tileStep:
            if targetLabel == "∞" {
                return "Reach infinity in \(timeText)"
            }
            return "Reach \(targetLabel) in \(timeText)"
        case .chain:
            return "Create a \(targetLabel) in \(timeText)"
        }
    }

    private var challengeHeader: some View {
        VStack(spacing: 12) {
            if let instructions = explicitInstructionText {
                Text(instructions)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }

            HStack {
                // Timer and Target (left, stacked)
            VStack(spacing: 8) {
                // Timer display - uses TimelineView with animation schedule to never pause
                TimelineView(.animation(minimumInterval: 0.5, paused: false)) { context in
                    let remaining = timeRemainingAt(context.date)
                    VStack(spacing: 2) {
                        Text("TIME")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatTime(remaining))
                            .font(.system(.title3, design: .monospaced).bold())
                            .foregroundStyle(remaining <= 10 ? .red : .primary)
                            .contentTransition(.numericText())
                    }
                    .onChange(of: remaining <= 0) { _, isExpired in
                        if isExpired && !challengeEnded {
                            endChallenge(won: checkWinCondition())
                        }
                    }
                }

                VStack(spacing: 2) {
                    Text("TARGET")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(targetLabel)
                        .font(.system(.title3, design: .rounded).bold())
                }
            }

            Spacer()

            // Valid moves count (center)
            VStack(spacing: 2) {
                Text("\(challengeGameStore.validMovesCount)")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(validMovesColor)
                    .contentTransition(.numericText())
                Text("moves")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Gem balance + Exit button (right)
            HStack(spacing: 12) {
                GemBalancePill()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(challengeWon ? "CHALLENGE COMPLETE!" : "TIME'S UP!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(challengeWon ? .green : .red)

                if challengeWon {
                    // Look up the full reward to display all components
                    let fullReward: ChallengeReward? = {
                        if let challengeId = config.challengeId {
                            return challengeStore.reward(for: challengeId)
                        }
                        return nil
                    }()

                    VStack(spacing: 12) {
                        // Gems
                        let gemAmount = fullReward?.coins ?? config.predictedRewardGems
                        if gemAmount > 0 {
                            HStack(spacing: 8) {
                                Image("gem")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Text("+\(gemAmount) Gems")
                                    .font(.system(.title3, design: .rounded).bold())
                            }
                        }

                        // Power-ups
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
                                }
                            }
                        }

                        // Spins
                        if let spins = fullReward?.spins, spins > 0 {
                            HStack(spacing: 8) {
                                Image("spinthewheel")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Text("+\(spins) \(spins == 1 ? "Spin" : "Spins")")
                                    .font(.system(.title3, design: .rounded).bold())
                            }
                        }

                        // Score boosts
                        if let boosts = fullReward?.scoreBoosts, !boosts.isEmpty {
                            ForEach(Array(boosts.sorted(by: { $0.key < $1.key })), id: \.key) { multiplier, count in
                                HStack(spacing: 8) {
                                    let iconName = "boost-\(multiplier)x"
                                    #if canImport(UIKit)
                                    if UIImage(named: iconName) != nil {
                                        Image(iconName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Image(systemName: "bolt.fill")
                                            .foregroundStyle(.orange)
                                    }
                                    #else
                                    Image(iconName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                    #endif
                                    Text("+\(count) \(multiplier)X Boost")
                                        .font(.system(.title3, design: .rounded).bold())
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

    private var validMovesColor: Color {
        let count = challengeGameStore.validMovesCount
        if count == 0 { return .red }
        else if count < 10 { return .orange }
        else if count < 20 { return .yellow }
        else { return .green }
    }

    // MARK: - Move Alert Overlays



    private var powerUpRecoveryOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Choose a power-up to continue")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack(spacing: 16) {
                    recoveryPowerUpButton(name: "Hammer", icon: "hammer") {
                        isShowingPowerUpRecovery = false
                        isHammerMode = true
                    }

                    recoveryPowerUpButton(name: "Shuffle", icon: "shuffle", isSystemIcon: true) {
                        isShowingPowerUpRecovery = false
                        if challengeGameStore.useShuffle() {
                            // Shuffle successful - game continues
                        } else {
                            // Not enough gems - end challenge
                            endChallenge(won: false)
                        }
                    }

                    recoveryPowerUpButton(name: "Magnet", icon: "magnet") {
                        isShowingPowerUpRecovery = false
                        isMagnetMode = true
                    }
                }

                Button("Cancel") {
                    isShowingPowerUpRecovery = false
                    endChallenge(won: false)
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 10)
            }
            .padding(30)
        }
    }

    private func recoveryPowerUpButton(name: String, icon: String, isSystemIcon: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if isSystemIcon {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                } else {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
                Text(name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(width: 80, height: 80)
            .background(Color.white.opacity(0.2))
            .cornerRadius(12)
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
            maxSpawnStep: config.maxSpawnStep,
            disableElimination: true
        )
        challengeGameStore.resetGame(with: gameConfig)

        // Restore player's highest tile/step for consistent power-up pricing after reset
        challengeGameStore.playerHighestTile = playerHighestTile
        challengeGameStore.playerHighestTileStep = playerHighestTileStep

        // Initialize gems from player's inventory AFTER reset (since reset clears state)
        challengeGameStore.coins = homeState.gems

        // Start the timer
        startTime = Date()
        challengeEnded = false
    }

    private func checkWinCondition() -> Bool {
        switch config.target {
        case .score(let target):
            return challengeGameStore.state.scoreValue.toInt() >= target
        case .tile(let target):
            return challengeGameStore.state.highestTile >= target
        case .tileStep(let targetStep):
            // Special case: infinity target — check if any infinity tile exists on the board
            if targetStep == Int.max {
                return challengeGameStore.state.board.cells.contains { row in 
                    row.contains { $0.tile?.isInfinity == true } 
                }
            }
            // Compare using step values
            return challengeGameStore.state.highestTileStep >= targetStep
        case .chain:
            // Check if any chain of required length was made
            return false // TODO: Track chain lengths
        }
    }

    private func endChallenge(won: Bool) {
        guard !challengeEnded else { return } // Prevent multiple calls
        frozenTimeRemaining = timeRemaining
        challengeEnded = true
        challengeWon = won

        if won {
            // Grant the full challenge reward (gems, power-ups, spins, boosts)
            if let challengeId = config.challengeId,
               let reward = challengeStore.reward(for: challengeId) {
                mainGameStore.grantChallengeReward(reward)
            } else {
                // Fallback to just gems if no challenge ID or reward found
                homeState.addGems(config.predictedRewardGems)
            }

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

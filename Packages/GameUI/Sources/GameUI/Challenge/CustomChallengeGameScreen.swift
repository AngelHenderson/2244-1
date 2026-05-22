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
    // Reference to main game store for achievement tracking
    @Environment(\.gameStore) private var mainGameStore
    @Environment(\.socialFeedPublisher) private var socialFeedPublisher
    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.adService) private var adService
    @Environment(\.purchaseService) private var purchaseService

    // Wallpaper selection stored in AppStorage (for gameplay background)
    @AppStorage("selectedWallpaperId") private var selectedWallpaperId: String = "wallpaper_default"

    private var currentWallpaper: WallpaperTheme {
        WallpaperThemeRegistry.Default.wallpaper(for: selectedWallpaperId)
    }
    @State private var showResult = false
    @State private var challengeWon = false
    @State private var challengeEnded = false
    @State private var frozenTimeRemaining: Int?
    @State private var longestChainLength = 0

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
    @State private var isShowingTimeRecovery = false
    @State private var isShowingInsufficientGemsAlert = false
    @State private var hasUsedTimeRecovery = false
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
        let gameplayView = challengeGameplayLayout
            .environment(\.gameStore, challengeGameStore)

        return NavigationStack {
            ZStack {
                challengeWallpaperBackground
                    .ignoresSafeArea()

                gameplayView

                if showResult { resultOverlay }
                if isShowingPowerUpRecovery { powerUpRecoveryOverlay }
                if isShowingTimeRecovery { timeRecoveryOverlay }
            }
            .navigationTitle("")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar { challengeNavigationToolbar }
            .gameplayNavigationBarBackground()
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
                // Also sync to main game store so updateHomeFromGameProgress()
                // doesn't overwrite homeState.gems with stale value
                _ = mainGameStore.spendCoins(spent)
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
                longestChainLength = max(longestChainLength, chainLength)
                mainGameStore.achievementEvaluator?.onTilesMerged(count: chainLength)
                if checkWinCondition() {
                    endChallenge(won: true)
                }
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
        .alert("Can't Afford Recovery Item", isPresented: $isShowingInsufficientGemsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            let needed = timeRecoveryCost - homeState.gems
            Text("You need \(timeRecoveryCost) gems to recover time, but you only have \(homeState.gems). You need \(needed) more gems.")
        }
        .trackScreen(.customChallengeGameplay)

    }

    // MARK: - Navigation Toolbar

    @ToolbarContentBuilder
    private var challengeNavigationToolbar: some ToolbarContent {
        #if os(macOS)
        ToolbarItem(placement: .navigation) { challengeNavLeading }
        ToolbarItem(placement: .principal) { challengeNavStatus }
        ToolbarItem(placement: .primaryAction) { challengeNavGems }
        #else
        ToolbarItem(placement: .topBarLeading) { challengeNavLeading }
        ToolbarItem(placement: .principal) { challengeNavStatus }
        ToolbarItem(placement: .topBarTrailing) { challengeNavGems }
        #endif
    }

    private var challengeNavLeading: some View {
        Button(action: { onDismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .glassEffectCompat(cornerRadius: 10)
        .foregroundStyle(.white)
        .accessibilityLabel("Exit challenge")
    }

    private var challengeNavStatus: some View {
        TimelineView(.animation(minimumInterval: 0.5, paused: false)) { context in
            let remaining = timeRemainingAt(context.date)
            HStack(spacing: 7) {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .bold))
                Text(formatTime(remaining))
                    .monospacedDigit()
                Text("Goal \(targetLabel)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
            .foregroundStyle(remaining <= 10 ? .red : .white)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .glassEffectCompat(cornerRadius: 10)
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

    private var challengeNavGems: some View {
        HStack(spacing: 4) {
            Image("gem")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            Text("\(challengeGameStore.coins)")
                .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
        .foregroundStyle(.white)
        .glassEffectCompat(cornerRadius: 10)
        .accessibilityLabel("Gems \(challengeGameStore.coins)")
    }

    // MARK: - Gameplay Layout

    @ViewBuilder
    private var challengeGameplayLayout: some View {
        GeometryReader { proxy in
            let metrics = PuzzleScreenMetrics(
                container: proxy.size,
                safeArea: proxy.safeAreaInsets,
                rows: challengeGameStore.state.board.height,
                columns: challengeGameStore.state.board.width
            )
            VStack(spacing: metrics.sectionSpacing) {
                challengeInfoPanel(isCompact: metrics.compression != .expanded)
                    .frame(height: metrics.objectiveHeight)

                challengeGameBoard(metrics: metrics)
                    .frame(width: metrics.boardSize.width, height: metrics.boardSize.height)
                    .layoutPriority(10)

                HorizontalPowerupDock(
                    isCollapsed: metrics.shouldCollapseTools,
                    onHammer: handleHammer,
                    onSwap: handleSwap,
                    onMagnet: handleMagnet,
                    onUndo: handleUndo
                )
                .frame(
                    width: metrics.shouldCollapseTools ? nil : metrics.boardSize.width,
                    height: metrics.toolTrayHeight
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, metrics.margin)
            .padding(.vertical, metrics.margin)
        }
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
            mainGameStore.achievementEvaluator?.onUndoUsed()
            haptics.lightImpact()
        } else {
            haptics.error()
        }
    }

    private func handleTileTap(at position: Position) {
        if isHammerMode {
            if challengeGameStore.state.board[position] != nil {
                _ = challengeGameStore.useHammer(at: position)
                mainGameStore.achievementEvaluator?.onPowerUpUsed(type: "hammer")
                haptics.success()
                isHammerMode = false
            } else {
                haptics.error()
            }
            return
        }

        if isSwapMode {
            if challengeGameStore.state.board[position] != nil {
                if let first = firstSwapPosition {
                    if first != position {
                        _ = challengeGameStore.useSwap(first, position)
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

        if isMagnetMode {
            if let tile = challengeGameStore.state.board[position] {
                let merges = challengeGameStore.useMagnet(value: tile.value, to: position)
                if merges > 0 {
                    mainGameStore.achievementEvaluator?.onMagnetUsed(mergeCount: merges)
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

    // MARK: - Challenge Info Panel

    @ViewBuilder
    private func challengeInfoPanel(isCompact: Bool) -> some View {
        let bestStep = max(0, challengeGameStore.state.highestTileStep)
        let goalStep = challengeTargetStep
        let bestLabel = JourneyTileGenerator.formatTileAtStep(bestStep)
        let bestColor = currentTheme?.colorForStep(bestStep) ?? .green
        let goalColor = currentTheme?.colorForStep(goalStep) ?? .orange
        let progressFraction: CGFloat = goalStep > 0
            ? min(1.0, CGFloat(bestStep) / CGFloat(goalStep)) : 0

        VStack(spacing: isCompact ? 6 : 8) {
            VStack(spacing: isCompact ? 4 : 5) {
                HStack(spacing: 8) {
                    MilestoneValuePill(title: "Best", value: bestLabel, color: bestColor)
                    Spacer(minLength: 8)
                    MilestoneValuePill(title: "Goal", value: targetLabel, color: goalColor)
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.16))
                        Capsule().fill(bestColor)
                            .frame(width: max(5, geometry.size.width * progressFraction))
                    }
                }
                .frame(height: isCompact ? 4 : 5)
            }

            HStack(spacing: isCompact ? 6 : 8) {
                GameplayInfoStat(title: "Moves", value: "\(challengeGameStore.state.moves)",
                    systemImage: "arrow.triangle.2.circlepath", isCompact: isCompact)
                GameplayInfoStat(title: "Valid", value: "\(challengeGameStore.validMovesCount)",
                    systemImage: "point.3.connected.trianglepath.dotted", isCompact: isCompact,
                    valueColor: validMovesColor)
                GameplayInfoStat(title: "Highest",
                    value: JourneyTileGenerator.formatTileAtStep(max(0, challengeGameStore.state.highestTileStep)),
                    systemImage: "crown.fill", isCompact: isCompact)
            }
        }
        .padding(.horizontal, isCompact ? 10 : 12)
        .padding(.vertical, isCompact ? 8 : 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var challengeTargetStep: Int {
        switch config.target {
        case .tileStep(let step): return step
        case .tile(let value):
            var s = 0; var v = 2
            while v < value && s < 1000 { v *= 2; s += 1 }
            return s
        case .score: return 20
        case .chain: return 10
        }
    }

    // MARK: - Game Board

    @ViewBuilder
    private func challengeGameBoard(metrics: PuzzleScreenMetrics) -> some View {
        ZStack {
            SimplifiedGlassBoardView(
                onTileTap: { position in handleTileTap(at: position) },
                isPowerUpActive: isHammerMode || isSwapMode || isMagnetMode,
                maxTileSize: metrics.maxTileSize,
                gridSpacing: metrics.gridSpacing
            )
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
    }

    // MARK: - Wallpaper Background

    @ViewBuilder
    private var challengeWallpaperBackground: some View {
        GeometryReader { geo in
            ZStack {
                if currentWallpaper.imageName.isEmpty {
                    LinearGradient(
                        colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                } else {
                    Image(currentWallpaper.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                    if currentWallpaper.overlayOpacity > 0 {
                        Color.black.opacity(currentWallpaper.overlayOpacity)
                    }
                }
            }
        }
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
                                    .foregroundStyle(.white)
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
                                        .foregroundStyle(.white)
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
                                    .foregroundStyle(.white)
                            }
                        }

                        // Score boosts
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

    // MARK: - Time Recovery Overlay

    private var timeRecoveryCost: Int {
        if let challengeId = config.challengeId,
           let index = challengeStore.challenges.firstIndex(where: { $0.id == challengeId }) {
            return 500 * (index + 1)
        }
        return 1500 // fallback for custom challenges
    }
    private let timeRecoveryBonus = 30 // seconds

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

                // Purchase button
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

        // Deduct gems from both homeState and challenge store
        homeState.gems -= timeRecoveryCost
        _ = mainGameStore.spendCoins(timeRecoveryCost)
        challengeGameStore.coins -= timeRecoveryCost

        // Mark as used (one-time only)
        hasUsedTimeRecovery = true
        isShowingTimeRecovery = false

        // Reset timer so remaining = exactly timeRecoveryBonus seconds from now
        // Formula: timeRemaining = totalDuration - (now - startTime)
        // We want timeRemaining = timeRecoveryBonus, so:
        // startTime = now - (totalDuration - timeRecoveryBonus)
        startTime = Date().addingTimeInterval(-Double(totalDuration - timeRecoveryBonus))
        frozenTimeRemaining = nil // Unfreeze the timer

        haptics.success()
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
        guard !challengeEnded else { return } // Prevent multiple calls
        frozenTimeRemaining = timeRemaining
        challengeEnded = true
        challengeWon = won

        if won {
            // Post to social feed
            let elapsed = totalDuration - (frozenTimeRemaining ?? 0)
            let mins = elapsed / 60
            let secs = elapsed % 60
            let timeStr = "\(mins):\(String(format: "%02d", secs))"
            socialFeedPublisher.postTimedChallengeComplete(timeString: timeStr)

            // Grant the full challenge reward (gems, power-ups, spins, boosts)
            if let challengeId = config.challengeId,
               let reward = challengeStore.reward(for: challengeId) {
                mainGameStore.grantChallengeReward(reward)
                // Also sync reward gems to homeState so the displayed balance updates
                if reward.coins > 0 {
                    homeState.gems += reward.coins
                }
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

#if DEBUG
#Preview("Custom Challenge Game") {
    GameUIScreenPreviewHost {
        CustomChallengeGameScreen(
            config: ScreenPreviewFixtures.challengeConfig,
            playerHighestTile: 1_048_576,
            playerHighestTileStep: 19,
            initialGems: 1_240,
            onDismiss: {}
        )
    }
}
#endif

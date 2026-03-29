import SwiftUI
import GameApp
import GameCore
#if os(macOS)
import AppKit
#endif

// MARK: - Modern Theme Tokens

enum ModernTheme {
    static let bg = Color(red: 0.05, green: 0.06, blue: 0.09)            // #0C0E16
    static let boardPlate = Color(red: 0.06, green: 0.08, blue: 0.13)     // #0F1422
    static let gutter: CGFloat = 8
    static let hudHeight: CGFloat = 56
    static let dockHeight: CGFloat = 76
    static let boardInset: CGFloat = 12
    static let gridGap: CGFloat = 6
    static let tileRadius: CGFloat = 12
    static let boardRadius: CGFloat = 20
}

/// Hybrid screen combining original GameScreen mechanics with modern styling
public struct HybridGameScreen: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.adService) private var adService
    @Environment(\.hapticsService) private var haptics
    @Environment(\.gameCenter) private var gameCenter
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.leaderboardClient) private var leaderboardClient
    @Environment(\.currentTheme) private var currentTheme

    @State private var isShowingTopMergeTile: Bool = false
    @State private var topMergeTileValue: Int? = nil
    @State private var isShowingDoublePrompt: Bool = false
    @State private var isShowingPause = false
    @State private var isShowingShop = false
    @State private var isShowingLeaderboard = false
    @State private var isShowingUnlockReward = false

    // Game over flow states
    @State private var isShowingOutOfMoves = false
    @State private var isShowingGameOverText = false
    @State private var isShowingPowerUpRecovery = false
    @State private var isShowingMilestoneStart = false
    @State private var isShowingInsufficientGemsAlert = false
    @State private var isShowingMilestoneTooLowAlert = false
    @State private var selectedMilestoneIndex: Int = 0
    @State private var gameOverResetTask: Task<Void, Never>? = nil
    @State private var isShowingLowOnMoves = false
    @State private var lowMovesWarningArmed = true

    // Temporary HomeState for HUDTopBar (initialized with game values)
    @State private var tempHomeState: HomeState = {
        let state = HomeState()
        state.rank = UserLeaderboardData.globalRank
        return state
    }()

    // Power-up selection modes
    @State private var isHammerMode = false
    @State private var isSwapMode = false
    @State private var isMagnetMode = false
    @State private var firstSwapPosition: Position? = nil
    @State private var magnetTargetValue: Int? = nil

    // Wallpaper selection stored in AppStorage (for gameplay background)
    @AppStorage("selectedWallpaperId") private var selectedWallpaperId: String = "wallpaper_default"

    private var currentWallpaper: WallpaperTheme {
        WallpaperThemeRegistry.Default.wallpaper(for: selectedWallpaperId)
    }

    private var shopIcon: Image {
        #if canImport(UIKit)
        if let path = Bundle.module.path(forResource: "ShopIcon", ofType: "png"),
           let uiImage = UIImage(contentsOfFile: path) {
            return Image(uiImage: uiImage)
        }
        #elseif canImport(AppKit)
        if let path = Bundle.module.path(forResource: "ShopIcon", ofType: "png"),
           let nsImage = NSImage(contentsOfFile: path) {
            return Image(nsImage: nsImage)
        }
        #endif
        return Image(systemName: "cart.fill")
    }
    
    // Closure injected by parent to dismiss gameplay (return to Home)
    public var isPlayingDismiss: (() -> Void)? = nil
    
    public init(isPlayingDismiss: (() -> Void)? = nil) {
        self.isPlayingDismiss = isPlayingDismiss
    }
    
    public var body: some View {
        let topHUD = HUDTopBar(scoreText: gameStore.state.scoreValue.formattedWithCommas())
            .environment(tempHomeState)
            .environment(\.homeActions, makeGameActions())

        let horizontalDock = HorizontalPowerupDock(
            onHammer: handleHammer,
            onSwap: handleSwap,
            onMagnet: handleMagnet,
            onUndo: handleUndo,
            onHome: { isPlayingDismiss?() }
        )

        let verticalDock = SimplePowerupDock(
            onHammer: handleHammer,
            onSwap: handleSwap,
            onMagnet: handleMagnet,
            onUndo: handleUndo,
            onHome: { isPlayingDismiss?() }
        )

        let giftRewardBinding = Binding(
            get: { gameStore.pendingGiftReward != nil },
            set: { newValue in if !newValue { gameStore.dismissGiftReward() } }
        )

        let notificationBinding = Binding(
            get: { gameStore.currentNotification != nil },
            set: { newValue in if !newValue { gameStore.dismissCurrentNotification() } }
        )

        // Break down the complex expression into smaller parts
        // iPhone (compact): horizontal dock below HUD
        // iPad (regular): vertical dock on trailing edge (using HStack)
        let isCompact = horizontalSizeClass == .compact

        let gameContent = mainGameView
            .safeAreaInset(edge: .top) {
                Group {
                    if isCompact {
                        VStack(spacing: 8) {
                            topHUD
                            MilestoneProgressBar()
                            horizontalDock
                        }
                    } else {
                        VStack(spacing: 8) {
                            topHUD
                            MilestoneProgressBar()
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                Group {
                    if isShowingTopMergeTile, let v = topMergeTileValue {
                        TopMergeTileView(value: v)
                    }
                }
            }

        // iPad: Use HStack to place dock on the right without overlapping
        let baseView: some View = Group {
            if isCompact {
                gameContent
            } else {
                HStack(spacing: 0) {
                    gameContent
                    VStack {
                        Spacer()
                            .frame(height: 120)
                        verticalDock

                        // Shop button below power-ups
                        Button {
                            isShowingShop = true
                        } label: {
                            shopIcon
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .shadow(radius: 4)
                        )
                        .padding(.trailing, 8)

                        Spacer()
                    }
                }
            }
        }
        
        let pauseSheet = baseView
            .adaptiveSheet(isPresented: $isShowingPause) {
                PauseSheet(
                    onResume: { isShowingPause = false },
                    onRestart: {
                        gameStore.resetGame()
                        isShowingPause = false
                    }
                )
            }

        let shopSheet = pauseSheet
            .adaptiveSheet(isPresented: $isShowingShop) {
                ShopView(initialTab: .gems)
            }

        let leaderboardSheet = shopSheet
            .adaptiveSheet(isPresented: $isShowingLeaderboard) {
                LeaderboardView(client: leaderboardClient)
            }

        let giftSheet = leaderboardSheet
            .adaptiveSheet(isPresented: giftRewardBinding) {
                if let giftReward = gameStore.pendingGiftReward {
                    GiftRewardView(giftReward: giftReward) {
                        gameStore.claimGiftReward()
                    }
                }
            }

        let unlockSheet = giftSheet
            .adaptiveSheet(isPresented: $isShowingUnlockReward) {
                if let baseAmount = gameStore.pendingUnlockRewardBase,
                   let tileValue = gameStore.pendingUnlockTile {
                    RewardSpinnerView(
                        baseAmount: baseAmount,
                        tileValue: tileValue,
                        onClose: { isShowingUnlockReward = false }
                    )
                } else {
                    EmptyView()
                }
            }

        // Use regular sheet (not adaptiveSheet) for notifications so they don't cover the whole screen
        let notificationSheet = unlockSheet
            .sheet(isPresented: notificationBinding) {
                if let notification = gameStore.currentNotification {
                    Group {
                        switch notification {
                        case .unlocked(let value):
                            UnlockedNotificationView(value: value, onClose: { gameStore.dismissCurrentNotification() })
                        case .added(let value):
                            AddedNotificationView(value: value, onClose: { gameStore.dismissCurrentNotification() })
                        case .excluded(let value):
                            ExcludedNotificationView(value: value, onClose: { gameStore.dismissCurrentNotification() })
                        }
                    }
                }
            }
        
        let alertView = notificationSheet
            .alert("Double your tile?", isPresented: $isShowingDoublePrompt) {
                Button("No", role: .cancel) { gameStore.clearPendingDoubleOffer() }
                Button("Yes") { gameStore.applyPendingDouble() }
            } message: {
                if let baseStep = gameStore.pendingDoubleBaseStep {
                    // Use step-based formatting for accurate display of high-value tiles
                    let doubledStep = baseStep + 1
                    let formattedValue = TileStepLabelFormatter.labelForStep(doubledStep)
                    Text("Double the tile to \(formattedValue)?")
                } else if let base = gameStore.pendingDoubleBase {
                    // Fallback to value-based formatting
                    let safeDoubled = base <= (Int.max >> 1) ? base * 2 : Int.max
                    let formattedValue = TileStepLabelFormatter.formatTileValue(safeDoubled)
                    Text("Double the tile to \(formattedValue)?")
                } else {
                    Text("Double the tile?")
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
                Button("End Game", role: .destructive) {
                    showGameOverAndReset()
                }
            } message: {
                Text("You have no moves. Want to use a powerup to revive?")
            }
        
        let changeHandlers = alertView
            .onChange(of: gameStore.lastAddedTileValue) { _, newValue in
                handleLastAddedTileChange(newValue)
            }
            .onChange(of: gameStore.pendingDoubleBase) { _, newValue in
                isShowingDoublePrompt = (newValue != nil)
            }
            .onChange(of: gameStore.coins) { _, newValue in
                tempHomeState.gems = newValue
            }
            .onChange(of: gameStore.state.highestTileStep) { _, newStep in
                // Only update rank if this session's milestone beats or equals the all-time saved milestone
                // This prevents the rank from getting worse when starting a new game session
                let savedHighestStep = UserDefaults.standard.integer(forKey: "savedHighestTileStep")
                if newStep >= savedHighestStep {
                    // Compute milestone directly from step to avoid UserDefaults delay
                    let milestone = TileStepLabelFormatter.labelForStep(newStep, start: 2)
                    tempHomeState.rank = UserLeaderboardData.globalRank(for: milestone)
                }
            }
        
        let sessionTracking = changeHandlers
            .onAppear {
                // Initialize tempHomeState with current values
                tempHomeState.gems = gameStore.coins
                tempHomeState.rank = UserLeaderboardData.globalRank
                // Only show unlock reward if there's no notification already pending
                let hasUnlockNotification = gameStore.currentNotification != nil
                isShowingUnlockReward = gameStore.pendingUnlockRewardBase != nil && !hasUnlockNotification

                // Initialize comprehensive session tracking
                gameStore.initializeSessionTracking()

                // Check if game is already over on appear
                if gameStore.state.isGameOver {
                    isShowingOutOfMoves = true
                }
            }
            .onDisappear {
                // Cancel any pending game over reset
                gameOverResetTask?.cancel()
                gameOverResetTask = nil
            }
            // Enhanced auto-save triggers for comprehensive session data
            .onChange(of: gameStore.state.moves) { _, _ in
                // Auto-save on every move with comprehensive session data
                gameStore.saveProgressImmediately(newTile: nil)
            }
            .onChange(of: gameStore.pendingUnlockRewardBase) { _, newValue in
                // Only show unlock reward sheet if there's no unlock notification already showing
                // The UnlockedNotificationView already handles the reward claiming
                let hasUnlockNotification = gameStore.currentNotification != nil
                let shouldShow = newValue != nil && !hasUnlockNotification
                if shouldShow != isShowingUnlockReward {
                    isShowingUnlockReward = shouldShow
                }
            }
            .onChange(of: gameStore.state.score) { _, newScore in
                // Update session analytics on score change
                gameStore.updateSessionAnalytics()
            }
            .onChange(of: gameStore.coins) { _, _ in
                // Auto-save when gems change
                gameStore.saveProgressImmediately(newTile: nil)
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Comprehensive auto-save when app goes to background
                if newPhase != .active {
                    gameStore.saveProgressImmediately(newTile: nil)
                }
            }
            .onChange(of: gameStore.state.isGameOver) { _, isGameOver in
                if isGameOver && !isShowingOutOfMoves && !isShowingGameOverText {
                    // Show out of moves dialog when game ends
                    isShowingOutOfMoves = true
                } else if !isGameOver {
                    // Game recovered (e.g., power-up created new moves)
                    // Cancel any pending reset and hide overlays
                    gameOverResetTask?.cancel()
                    gameOverResetTask = nil
                    isShowingOutOfMoves = false
                    isShowingGameOverText = false
                    isShowingPowerUpRecovery = false
                }
            }
            .onChange(of: gameStore.validMovesCount) { _, newCount in
                // Show low-on-moves warning when moves drop to 5 or below
                // Re-arms when moves go back above 5 (e.g., after using a powerup)
                if newCount > 5 {
                    lowMovesWarningArmed = true
                } else if newCount > 0 && newCount <= 5 && lowMovesWarningArmed && !gameStore.state.isGameOver && !isShowingOutOfMoves {
                    lowMovesWarningArmed = false
                    isShowingLowOnMoves = true
                }
            }
            .onChange(of: isShowingOutOfMoves) { _, isShowing in
                // If alert dismissed and not entering recovery, execute game over
                if !isShowing && !isShowingPowerUpRecovery && gameStore.state.isGameOver && !isShowingGameOverText {
                    showGameOverAndReset()
                }
            }
            .onChange(of: isShowingPowerUpRecovery) { _, isShowing in
                // If recovery dismissed without using a powerup, execute game over
                if !isShowing && gameStore.state.isGameOver && !isShowingGameOverText && !isShowingOutOfMoves {
                    showGameOverAndReset()
                }
            }

        // Wrap everything with full-screen wallpaper background
        return ZStack {
            wallpaperBackground
                .ignoresSafeArea()
            sessionTracking



            // Game over text overlay
            if isShowingGameOverText {
                gameOverTextOverlay
            }

            // Milestone start picker overlay
            if isShowingMilestoneStart {
                milestoneStartOverlay
            }

            // Power-up recovery selection overlay
            if isShowingPowerUpRecovery {
                powerUpRecoveryOverlay
            }
        }
    }

    // MARK: - Game Over Views



    private var gameOverTextOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            Text("GAME OVER")
                .font(.avenirNext(size: 48, weight: .heavy))
                .foregroundColor(.white)
        }
    }

    private var powerUpRecoveryOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Choose a power-up to continue")
                    .font(.avenirNext(size: GameFonts.title2Size, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 16) {
                    recoveryPowerUpButton(name: "Hammer", icon: "hammer.fill", action: {
                        isShowingPowerUpRecovery = false
                        isHammerMode = true
                    })

                    recoveryPowerUpButton(name: "Shuffle", icon: "shuffle", action: {
                        isShowingPowerUpRecovery = false
                        if gameStore.useShuffle() {
                            // Shuffle successful - game continues
                        } else {
                            // Not enough gems - show game over
                            showGameOverAndReset()
                        }
                    })

                    recoveryPowerUpButton(name: "Magnet", icon: "magnet", action: {
                        isShowingPowerUpRecovery = false
                        isMagnetMode = true
                    })
                }

                Button("Cancel") {
                    isShowingPowerUpRecovery = false
                    showGameOverAndReset()
                }
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 10)
            }
            .padding(30)
        }
    }

    private func recoveryPowerUpButton(name: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.avenirNext(size: GameFonts.title1Size, weight: .regular))
                Text(name)
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(width: 80, height: 80)
            .background(Color.white.opacity(0.2))
            .cornerRadius(12)
        }
    }

    private func showGameOverAndReset() {
        isShowingGameOverText = true

        // Cancel any existing reset task
        gameOverResetTask?.cancel()

        // Show GAME OVER for 2 seconds, then transition to milestone picker
        gameOverResetTask = Task {
            try? await Task.sleep(for: .seconds(2))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                isShowingGameOverText = false
                selectedMilestoneIndex = 0
                isShowingMilestoneStart = true
            }
        }
    }

    private func startAtMilestone(_ tier: MilestoneTier) {
        if tier.gemCost > 0 {
            guard gameStore.spendCoins(tier.gemCost) else { return }
        }
        isShowingMilestoneStart = false
        if tier.step == 0 {
            gameStore.resetGame()
        } else {
            gameStore.resetGameAtMilestone(step: tier.step)
        }
    }

    private func makeGameActions() -> HomeActions {
        HomeActions(
            play: { },
            openShop: { isShowingShop = true },
            buyGems: { },
            watchAd: { 50 },
            openDaily: { },
            openFreeSpin: { },
            openMusic: { },
            openChallenge: { },
            openCreate: { },
            openProfile: { },
            openAchievements: { },
            openLeaderboard: { isShowingLeaderboard = true },
            openSettings: { },
            openThemeLeft: { },
            openThemeRight: { },
            openSaleOffer: { }
        )
    }
    
    @ViewBuilder
    private var mainGameView: some View {
        ZStack {
            // Board container with glass preview (clear background)
            SimplifiedGlassBoardView(
                onTileTap: { position in handleTileTap(at: position) },
                isPowerUpActive: isHammerMode || isSwapMode || isMagnetMode
            )
            .padding(.horizontal, ModernTheme.gutter)
            .padding(.bottom, 8)
            .accessibilityLabel("Game board with glass preview")

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
    }

    @ViewBuilder
    private var wallpaperBackground: some View {
        GeometryReader { geo in
            ZStack {
                if currentWallpaper.imageName.isEmpty {
                    // Default gradient background
                    LinearGradient(
                        colors: [
                            Color(hex: "1a1a2e"),
                            Color(hex: "16213e")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    // Image wallpaper
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
    
    private func handleLastAddedTileChange(_ newValue: Int?) {
        guard let v = newValue else { return }
        let highest = max(0, gameStore.state.highestTile)
        let oneBeforeHighest = highest >= 4 ? highest / 2 : 0
        guard oneBeforeHighest > 0, v == oneBeforeHighest else { return }
        topMergeTileValue = v
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isShowingTopMergeTile = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                isShowingTopMergeTile = false
            }
        }
    }
    
    
    // MARK: - Power-up Handlers
    
    private func handleHammer() {
        if gameStore.isPowerUpAvailable("hammer") {
            cancelAllModes()
            isHammerMode = true
            haptics.lightImpact()
            // Track power-up selection for analytics
            gameStore.trackPowerUpAnalytics(action: .hammer(Position(row: 0, col: 0))) // Placeholder position
        } else {
            haptics.error()
        }
    }
    
    private func handleShuffle() {
        if gameStore.isPowerUpAvailable("shuffle") {
            _ = gameStore.useShuffle()
            haptics.success()
        } else {
            haptics.error()
        }
    }
    
    private func handleSwap() {
        if gameStore.isPowerUpAvailable("swap") {
            cancelAllModes()
            isSwapMode = true
            firstSwapPosition = nil
            haptics.lightImpact()
            // Track power-up selection for analytics
            gameStore.trackPowerUpAnalytics(action: .swap(Position(row: 0, col: 0), Position(row: 0, col: 1))) // Placeholder positions
        } else {
            haptics.error()
        }
    }
    
    private func handleUndo() {
        if gameStore.state.undoAvailable {
            _ = gameStore.useUndo()
            haptics.lightImpact()
        } else {
            haptics.error()
        }
    }
    
    private func handleMagnet() {
        cancelAllModes()
        isMagnetMode = true
        haptics.lightImpact()
        // Track power-up selection for analytics
        gameStore.trackPowerUpAnalytics(action: .shuffle) // Use shuffle as placeholder for magnet
    }
    
    private func handleTileTap(at position: Position) {
        // Track tile interaction for analytics
        gameStore.trackMoveAnalytics(move: [position])
        
        // Handle double tile power-up first
        if gameStore.pendingDoubleBase != nil {
            _ = gameStore.applyDouble(to: position)
            isShowingDoublePrompt = false
            return
        }
        
        // Handle hammer mode
        if isHammerMode {
            if gameStore.state.board[position] != nil {
                _ = gameStore.useHammer(at: position)
                haptics.success()
                isHammerMode = false
            } else {
                haptics.error()
            }
            return
        }
        
        // Handle swap mode
        if isSwapMode {
            if gameStore.state.board[position] != nil {
                if let first = firstSwapPosition {
                    // Second selection - perform swap (can swap ANY two tiles)
                    if first != position {
                        _ = gameStore.useSwap(first, position)
                        haptics.success()
                        isSwapMode = false
                        firstSwapPosition = nil
                    } else {
                        // Same tile, just clear selection
                        firstSwapPosition = nil
                        haptics.lightImpact()
                    }
                } else {
                    // First selection
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
            if let tile = gameStore.state.board[position] {
                let success = gameStore.useMagnet(value: tile.value, to: position)
                if success {
                    haptics.success()
                } else {
                    haptics.warning() // No matching tiles found
                }
                isMagnetMode = false
                magnetTargetValue = nil
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
        magnetTargetValue = nil
    }
}


// MARK: - Horizontal Power-up Dock (for iPhone)

struct HorizontalPowerupDock: View {
    @Environment(\.gameStore) private var gameStore
    let onHammer: () -> Void
    let onSwap: () -> Void
    let onMagnet: () -> Void
    let onUndo: () -> Void
    let onHome: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Home button
            powerupItem(
                icon: "house.fill",
                action: onHome
            )

            Divider()
                .frame(height: 30)
                .opacity(0.3)

            // Hammer
            powerupItem(
                assetName: "hammer",
                badge: gameStore.powerUpInventory["hammer", default: 0],
                price: gameStore.powerUpPrice("hammer"),
                isEnabled: gameStore.isPowerUpAvailable("hammer"),
                action: onHammer
            )

            // Swap
            powerupItem(
                assetName: "swap",
                badge: gameStore.powerUpInventory["swap", default: 0],
                price: gameStore.powerUpPrice("swap"),
                isEnabled: gameStore.isPowerUpAvailable("swap"),
                action: onSwap
            )

            // Magnet
            powerupItem(
                assetName: "magnet",
                badge: gameStore.powerUpInventory["magnet", default: 0],
                price: gameStore.powerUpPrice("magnet"),
                isEnabled: gameStore.isPowerUpAvailable("magnet"),
                action: onMagnet
            )

            // Undo
            powerupItem(
                icon: "arrow.uturn.backward",
                isEnabled: gameStore.state.undoAvailable,
                action: onUndo
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
                    .font(.avenirNext(size: 20, weight: .regular))
                    .frame(width: 40, height: 40)
                    .foregroundStyle(isEnabled ? .primary : .tertiary)

                if badge > 0 {
                    badgeLabel(for: badge)
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .glassEffectCompat(cornerRadius: 10)
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
                    badgeLabel(for: badge)
                        .offset(x: 4, y: -4)
                } else if let price = price {
                    HStack(spacing: 1) {
                        Image("gem")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 8, height: 8)
                        Text("\(price)")
                            .font(.avenirNext(size: 8, weight: .bold))
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
        .glassEffectCompat(cornerRadius: 10)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }

    private func badgeLabel(for count: Int) -> some View {
        Text("\(count)")
            .font(.avenirNext(size: 10, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.blue, in: Capsule())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

// MARK: - Simple Power-up Dock (vertical, for reference)

struct SimplePowerupDock: View {
    @Environment(\.gameStore) private var gameStore
    let onHammer: () -> Void
    let onSwap: () -> Void
    let onMagnet: () -> Void
    let onUndo: () -> Void
    let onHome: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Home button
            powerupDockItem(
                icon: "house.fill",
                action: onHome
            )

            Divider()
                .frame(width: 30)
                .opacity(0.3)

            // Break Any Tile On The Board (Hammer)
            powerupDockItem(
                assetName: "hammer",
                badge: gameStore.powerUpInventory["hammer", default: 0],
                price: gameStore.powerUpPrice("hammer"),
                isEnabled: gameStore.isPowerUpAvailable("hammer"),
                action: onHammer
            )

            // Swap Any 2 Tiles With Each Other (Restart/Swap)
            powerupDockItem(
                assetName: "swap",
                badge: gameStore.powerUpInventory["swap", default: 0],
                price: gameStore.powerUpPrice("swap"),
                isEnabled: gameStore.isPowerUpAvailable("swap"),
                action: onSwap
            )

            // Merge Same Tiles On The Board (Magnet)
            powerupDockItem(
                assetName: "magnet",
                badge: gameStore.powerUpInventory["magnet", default: 0],
                price: gameStore.powerUpPrice("magnet"),
                isEnabled: gameStore.isPowerUpAvailable("magnet"),
                action: onMagnet
            )

            // Undo button
            powerupDockItem(
                icon: "arrow.uturn.backward",
                isEnabled: gameStore.state.undoAvailable,
                action: onUndo
            )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 4)
        )
        .padding(.trailing, 8)
    }
    
    private func powerupDockItem(
        icon: String,
        badge: Int = 0,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.avenirNext(size: 22, weight: .regular))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(isEnabled ? .primary : .tertiary)

                // Badge for inventory count
                if badge > 0 {
                    badgeLabel(for: badge)
                        .offset(x: 4, y: -4)
                }
            }
            .padding(3)
        }
        .buttonStyle(.plain)
        .glassEffectCompat(cornerRadius: 10)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }

    private func powerupDockItem(
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
                    .frame(width: 22, height: 22)
                    .frame(width: 44, height: 44)
                    .opacity(isEnabled ? 1.0 : 0.4)

                // Badge for inventory count or Price
                if badge > 0 {
                    badgeLabel(for: badge)
                        .offset(x: 4, y: -4)
                } else if let price = price {
                    HStack(spacing: 1) {
                        Image("gem")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 9, height: 9)
                        Text("\(price)")
                            .font(.avenirNext(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6), in: Capsule())
                    .offset(x: 12, y: -8)
                }
            }
            .padding(3)
        }
        .buttonStyle(.plain)
        .glassEffectCompat(cornerRadius: 10)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }

    private func badgeLabel(for count: Int) -> some View {
        Text("\(count)")
            .font(.avenirNext(size: 11, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.blue, in: Capsule())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

// MARK: - Supporting Views

struct TopMergeTileView: View {
    let value: Int

    var body: some View {
        let currentLabel = CompactNumberFormatter.format(value)
        let nextVal = value > 0 && value <= (Int.max >> 1) ? value * 2 : value
        let nextLabel = CompactNumberFormatter.format(nextVal)

        HStack {
            Spacer()
            Text("\(currentLabel) >> \(nextLabel)")
                .font(.avenirNext(size: GameFonts.title3Size, weight: .heavy))
                //.foregroundStyle(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                )
                .shadow(radius: 6)
                .padding(.top, 8)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Mode Overlay

struct ModeOverlay: View {
    let isHammerMode: Bool
    let isSwapMode: Bool
    let isMagnetMode: Bool
    let firstSwapPosition: Position?
    let onCancel: () -> Void
    
    var modeText: String {
        if isHammerMode { return "Tap a tile to destroy" }
        if isSwapMode { 
            if firstSwapPosition != nil {
                return "Tap an adjacent tile to swap"
            } else {
                return "Select first tile to swap"
            }
        }
        if isMagnetMode { return "Select a number to MegaMerge" }
        return ""
    }
    
    var modeColor: Color {
        if isHammerMode { return .red }
        if isSwapMode { return .blue }
        if isMagnetMode { return .purple }
        return .clear
    }
    
    var body: some View {
        VStack {
            // Mode banner at top
            HStack {
                Text(modeText)
                    .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                    //.foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(modeColor)
                    .cornerRadius(20)

                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                //.foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray)
                .cornerRadius(20)
            }
            .padding()

            Spacer()
        }

        // Subtle overlay dimming
        .background(
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
        .animation(.easeInOut(duration: 0.2), value: isHammerMode || isSwapMode || isMagnetMode)
    }
}

// MARK: - Milestone Progress Bar

struct MilestoneProgressBar: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.currentTheme) private var currentTheme

    /// Dynamic minimum spawn step based on current game state (elimination threshold)
    private var minSpawnStep: Int {
        gameStore.minSpawnStep
    }

    private var minSpawnLabel: String {
        JourneyTileGenerator.formatTileAtStep(minSpawnStep)
    }

    private var highestStep: Int {
        max(0, gameStore.state.highestTileStep)
    }

    private var currentLabel: String {
        JourneyTileGenerator.formatTileAtStep(highestStep)
    }

    private var nextLabel: String {
        JourneyTileGenerator.formatTileAtStep(highestStep + 1)
    }

    private var nextStep: Int {
        highestStep + 1
    }

    // Progress from minSpawn to current (0.0 to 1.0)
    private var progressToCurrentRatio: CGFloat {
        guard highestStep > minSpawnStep else { return 0 }
        // Normalize: current position relative to a reasonable max (e.g., 100 steps)
        return min(1.0, CGFloat(highestStep - minSpawnStep) / 100.0)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: minSpawn (lowest tile)
            MiniTileView(label: minSpawnLabel, step: minSpawnStep, isLocked: false, theme: currentTheme)

            // Progress line to current
            ProgressLine(progress: 1.0, accentColor: currentTheme?.colorForStep(highestStep) ?? .green)

            // Middle: current highest tile with crown
            MiniTileView(label: currentLabel, step: highestStep, isCurrent: true, theme: currentTheme)
                .overlay(alignment: .top) {
                    Image(systemName: "crown.fill")
                        .font(.avenirNext(size: 10, weight: .regular))
                        .foregroundStyle(.yellow)
                        .offset(y: -8)
                }

            // Progress line to next (empty)
            ProgressLine(progress: 0.0, accentColor: currentTheme?.colorForStep(highestStep) ?? .green)

            // Right: next tile after current (locked)
            MiniTileView(label: nextLabel, step: nextStep, isLocked: true, theme: currentTheme)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

private struct MiniTileView: View {
    let label: String
    let step: Int
    var isCurrent: Bool = false
    var isLocked: Bool = false
    var theme: ThemeDescriptor? = nil

    private var tileColor: Color {
        if let theme { return theme.colorForStep(step) }
        return Theme.colorForStep(step)
    }

    private var textColor: Color {
        if let theme { return theme.textColorForStep(step) }
        return Theme.textColorForStep(step)
    }

    var body: some View {
        ZStack {
            Text(label)
                .font(.avenirNext(size: 10, weight: .bold))
                .foregroundStyle(textColor)
                .minimumScaleFactor(0.5)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(tileColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isCurrent ? Color.yellow : Color.white.opacity(0.2), lineWidth: isCurrent ? 2 : 1)
                )

            // Dim overlay for locked tiles
            if isLocked {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 36, height: 36)
            }
        }
    }
}

private struct ProgressLine: View {
    let progress: CGFloat
    var accentColor: Color = .green

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background line
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 3)

                // Progress fill
                Rectangle()
                    .fill(accentColor)
                    .frame(width: geo.size.width * progress, height: 3)
            }
        }
        .frame(height: 3)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Milestone Start Data

struct MilestoneTier: Identifiable {
    let id: Int  // index
    let step: Int
    let gemCost: Int
    let label: String

    static let allTiers: [MilestoneTier] = [
        MilestoneTier(id: 0,  step: 0,   gemCost: 0,       label: "2"),
        MilestoneTier(id: 1,  step: 9,   gemCost: 50,      label: "1024"),
        MilestoneTier(id: 2,  step: 10,  gemCost: 100,     label: "2048"),
        MilestoneTier(id: 3,  step: 11,  gemCost: 150,     label: "4096"),
        MilestoneTier(id: 4,  step: 12,  gemCost: 200,     label: "8192"),
        MilestoneTier(id: 5,  step: 13,  gemCost: 250,     label: "16K"),
        MilestoneTier(id: 6,  step: 19,  gemCost: 500,     label: "1M"),
        MilestoneTier(id: 7,  step: 29,  gemCost: 750,     label: "1B"),
        MilestoneTier(id: 8,  step: 39,  gemCost: 1_000,   label: "1a"),
        MilestoneTier(id: 9,  step: 49,  gemCost: 1_250,   label: "1b"),
        MilestoneTier(id: 10, step: 59,  gemCost: 1_500,   label: "1c"),
        MilestoneTier(id: 11, step: 298, gemCost: 50_000,  label: "1aa"),
        MilestoneTier(id: 12, step: 587, gemCost: 200_000, label: "1bd"),
    ]
}

// MARK: - Milestone Start Overlay

extension HybridGameScreen {
    var milestoneStartOverlay: some View {
        // Use the current session's highest tile step — not all-time record
        let sessionHighestStep = gameStore.state.highestTileStep

        return ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Replay")
                    .font(.avenirNext(size: 32, weight: .heavy))
                    .foregroundColor(.white)

                // Selected milestone preview tile
                let selectedTier = MilestoneTier.allTiers[selectedMilestoneIndex]
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 120, height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 3
                                )
                        )

                    TileView(
                        tile: Tile.make(forStep: selectedTier.step),
                        isSelected: false,
                        isValid: true,
                        size: 100,
                        theme: currentTheme
                    )

                    // Crown
                    Image(systemName: "crown.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .offset(y: -62)
                }
                .padding(.bottom, 4)

                // Scrollable tile picker row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(MilestoneTier.allTiers) { tier in
                            let reachedMilestone = tier.step == 0 || tier.step <= sessionHighestStep
                            let canAfford = tier.gemCost == 0 || gameStore.coins >= tier.gemCost
                            let isAvailable = reachedMilestone && canAfford
                            let isSelected = selectedMilestoneIndex == tier.id

                            VStack(spacing: 6) {
                                ZStack {
                                    TileView(
                                        tile: Tile.make(forStep: tier.step),
                                        isSelected: false,
                                        isValid: true,
                                        size: 56,
                                        theme: currentTheme
                                    )
                                    .saturation(isAvailable ? 1.0 : 0.0)
                                    .opacity(isAvailable ? 1.0 : 0.5)

                                    if !isAvailable {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                                .frame(width: 60, height: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(
                                            isSelected ? Color.green : Color.clear,
                                            lineWidth: 3
                                        )
                                )

                                // Price label
                                if tier.gemCost == 0 {
                                    Text("FREE")
                                        .font(.avenirNext(size: 10, weight: .bold))
                                        .foregroundColor(.green)
                                } else if reachedMilestone {
                                    HStack(spacing: 2) {
                                        Image("gems")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 12, height: 12)
                                        Text(tier.gemCost >= 1000 ? "\(tier.gemCost / 1000)K" : "\(tier.gemCost)")
                                            .font(.avenirNext(size: 10, weight: .bold))
                                            .foregroundColor(canAfford ? .white : .red)
                                    }
                                } else {
                                    Text("🔒")
                                        .font(.system(size: 10))
                                }
                            }
                            .onTapGesture {
                                guard reachedMilestone else {
                                    isShowingMilestoneTooLowAlert = true
                                    return
                                }
                                guard canAfford else {
                                    isShowingInsufficientGemsAlert = true
                                    return
                                }
                                selectedMilestoneIndex = tier.id
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 90)

                // Action buttons
                HStack(spacing: 16) {
                    // OK button to start
                    Button {
                        let tier = MilestoneTier.allTiers[selectedMilestoneIndex]
                        startAtMilestone(tier)
                    } label: {
                        Text("OK")
                            .font(.avenirNext(size: 20, weight: .heavy))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green)
                            )
                    }
                }
                .padding(.horizontal, 30)
            }
            .padding(.vertical, 30)
        }
        .transition(.opacity)
        .alert("You Can’t Afford This!", isPresented: $isShowingInsufficientGemsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You cannot start from this tile because you have insufficient gems. Pick a new tile to start from where you have enough gems for it.")
        }
        .alert("Milestone Is Too Low", isPresented: $isShowingMilestoneTooLowAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You cannot start from this tile because you have a milestone too low. Pick a new tile to start from where your milestone is high enough.")
        }
    }
}

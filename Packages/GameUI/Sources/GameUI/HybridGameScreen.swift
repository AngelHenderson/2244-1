import SwiftUI
import GameApp
import GameCore
import GameServices

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
    @Environment(\.audio) private var audioService
    @Environment(\.gameCenter) private var gameCenter
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @Environment(\.leaderboardClient) private var leaderboardClient
    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.purchaseService) private var purchaseService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PlayerReadinessStore.self) private var playerReadiness
    @Environment(\.rewardLedgerOptional) private var rewardLedger
    @Environment(\.socialFeedPublisher) private var socialFeedPublisher

    @State private var isShowingTopMergeTile: Bool = false
    @State private var topMergeTileValue: Int? = nil
    @State private var isShowingDoublePrompt: Bool = false
    @State private var presentedSheet: GameplaySheetDestination?
    @State private var isShowingUnlockReward = false

    enum PowerUpOverlayContext {
        case outOfMoves
        case lowOnMoves
    }
    @State private var powerUpOverlayContext: PowerUpOverlayContext?
    @State private var isShowingPowerUpOverlay = false
    @State private var isShowingGameOverText = false

    @State private var isShowingMilestoneStart = false
    @State private var isShowingInsufficientGemsAlert = false
    @State private var isShowingMilestoneTooLowAlert = false
    @State private var pendingMilestoneSpend: MilestoneTier?
    @State private var selectedMilestoneIndex: Int = 0
    @State private var gameOverResetTask: Task<Void, Never>? = nil
    @State private var isShowingLowOnMoves = false
    @State private var lowMovesWarningArmed = true
    @State private var isShowingQuitConfirmation = false
    @State private var pendingGameSummary: GameSummaryPresentation?
    @State private var runBestScoreAtStart: AlphaNumber = .zero
    @AppStorage("hasSeenFirstGameSummary") private var hasSeenFirstGameSummary = false

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

    // Closure injected by parent to dismiss gameplay (return to Home)
    public var isPlayingDismiss: (() -> Void)? = nil
    
    public init(isPlayingDismiss: (() -> Void)? = nil) {
        self.isPlayingDismiss = isPlayingDismiss
    }
    
    public var body: some View {
        let giftRewardBinding = Binding(
            get: { gameStore.pendingGiftReward != nil },
            set: { newValue in if !newValue { gameStore.dismissGiftReward() } }
        )

        let milestoneSpendBinding = Binding(
            get: { pendingMilestoneSpend != nil },
            set: { newValue in if !newValue { pendingMilestoneSpend = nil } }
        )

        let baseView = gameplayLayout
            .safeAreaInset(edge: .bottom) {
                if !purchaseService.isAdFreePurchased {
                    LiveBannerAdView()
                }
            }
            .overlay(alignment: .top) {
                Group {
                    if isShowingTopMergeTile, let v = topMergeTileValue {
                        TopMergeTileView(value: v)
                    }
                }
            }
            .overlay(alignment: .top) {
                if let reason = gameStore.lastInvalidChainReason {
                    InvalidChainBanner(message: reason, reduceMotion: reduceMotion)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .accessibilityAddTraits(.isStaticText)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        .id(reason)
                }
            }
        
        // Single host for the three mutually-exclusive user-triggered
        // sheets (pause, shop, leaderboard). Auto-triggered sheets below
        // (giftReward, unlockReward, notification) keep their own
        // bindings because they can fire mid-gameplay independent of
        // the user destination and use distinct presentation rules.
        let userSheetHost = baseView
            .adaptiveSheet(item: $presentedSheet) { destination in
                switch destination {
                case .pause:
                    PauseSheet(
                        onResume: { presentedSheet = nil },
                        onRestart: {
                            gameStore.resetGame()
                            presentedSheet = nil
                        },
                        onHome: {
                            presentedSheet = nil
                            isPlayingDismiss?()
                        }
                    )
                case .shop:
                    ShopView(initialTab: .gems)
                case .leaderboard:
                    LeaderboardView(client: leaderboardClient)
                }
            }

        let giftSheet = userSheetHost
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

        // Notification overlay — uses overlay instead of .sheet to avoid SwiftUI's
        // sheet stacking limitation (only one sheet per hierarchy level). Notification
        // views have their own card background (.ultraThinMaterial) so they render
        // properly as overlays.
        let notificationSheet = unlockSheet
            .overlay {
                if gameStore.currentNotification != nil {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { /* block taps on background */ }
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) {
                if let notification = gameStore.currentNotification {
                    Group {
                        switch notification {
                        case .unlocked(let value, let phrase):
                            UnlockedNotificationView(value: value, celebrationPhrase: phrase, onClose: { gameStore.dismissCurrentNotification() })
                        case .added(let value, let phrase):
                            AddedNotificationView(value: value, celebrationPhrase: phrase, onClose: { gameStore.dismissCurrentNotification() })
                        case .excluded(let value, let phrase):
                            ExcludedNotificationView(value: value, celebrationPhrase: phrase, onClose: { gameStore.dismissCurrentNotification() })
                        }
                    }
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: gameStore.currentNotification != nil)
        
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
                Button("No", role: .cancel) { }
                Button("Yes") {
                    powerUpOverlayContext = .lowOnMoves
                    isShowingPowerUpOverlay = true
                }
            } message: {
                Text("You are low on moves. Want to use a powerup to free up moves?")
            }
            .alert("Are you sure you want to quit?", isPresented: $isShowingQuitConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Quit", role: .destructive) {
                    isShowingPowerUpOverlay = false
                    showGameOverAndReset()
                }
            } message: {
                Text("This will restart all of your progress.")
            }
            .alert(
                "Can't Afford \(gameStore.insufficientGemsAlert?.powerUpName ?? "Power-Up")",
                isPresented: Binding(
                    get: { gameStore.insufficientGemsAlert != nil },
                    set: { if !$0 { gameStore.insufficientGemsAlert = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    gameStore.insufficientGemsAlert = nil
                }
            } message: {
                if let alert = gameStore.insufficientGemsAlert {
                    Text("You need \(alert.cost) gems, but you only have \(alert.balance). You need \(alert.deficit) more gems.")
                }
            }

        
        let changeHandlers = alertView
            .onChange(of: gameStore.lastAddedTileValue) { _, newValue in
                handleLastAddedTileChange(newValue)
            }
            .onChange(of: gameStore.pendingDoubleBase) { _, newValue in
                if newValue != nil {
                    // Defer double prompt until all milestone notifications are dismissed.
                    // Showing the alert while an overlay notification is active covers the
                    // notification, causing it to be invisible to the user.
                    if !gameStore.hasActiveNotifications {
                        isShowingDoublePrompt = true
                    }
                    // else: will be triggered by onChange(of: hasActiveNotifications) below
                } else {
                    isShowingDoublePrompt = false
                }
            }
            .onChange(of: gameStore.hasActiveNotifications) { _, isActive in
                // When all notifications clear and a double offer is pending, show the prompt
                if !isActive, gameStore.pendingDoubleBase != nil, !isShowingDoublePrompt {
                    isShowingDoublePrompt = true
                }
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
            .onChange(of: gameStore.didCreateFirstInfinity) { _, isFirst in
                if isFirst {
                    Task { await audioService.playSfx(name: "cheer") }
                    gameStore.clearFirstInfinityEvent()
                }
            }
            .onChange(of: gameStore.lastChainLength) { _, newLength in
                // Each commit produces a chain of at least 2 tiles; treat that as one merge event.
                guard newLength >= 2 else { return }
                playerReadiness.recordMerge(
                    count: 1,
                    highestTile: gameStore.state.highestTile,
                    highestTileStep: gameStore.state.highestTileStep
                )
            }
            .onChange(of: gameStore.lastInvalidChainReason) { _, newValue in
                // Light tap when the player tries an invalid extension; throttled to once per appearance.
                if newValue != nil {
                    haptics.warning()
                }
            }
        
        let sessionTracking = changeHandlers
            .onAppear {
                // Clear any stale input-lock / animation state from a previous
                // session so the very first chain on this visit works correctly.
                gameStore.resetInputState()

                // Initialize tempHomeState with current values
                tempHomeState.gems = gameStore.coins
                tempHomeState.rank = UserLeaderboardData.globalRank
                captureRunStartBaselines()
                // Only show unlock reward if there's no notification already pending
                let hasUnlockNotification = gameStore.currentNotification != nil
                isShowingUnlockReward = gameStore.pendingUnlockRewardBase != nil && !hasUnlockNotification

                // Initialize comprehensive session tracking
                gameStore.initializeSessionTracking()
                Task { await adService.showBanner() }

                // Check if game is already over on appear
                if gameStore.state.isGameOver {
                    powerUpOverlayContext = .outOfMoves
                    isShowingPowerUpOverlay = true
                }
            }
            .onDisappear {
                // Cancel any pending game over reset
                gameOverResetTask?.cancel()
                gameOverResetTask = nil
                Task { await adService.hideBanner() }
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
                if newPhase != ScenePhase.active {
                    gameStore.saveProgressImmediately(newTile: nil)
                }
            }
            .onChange(of: purchaseService.isAdFreePurchased) { _, isAdFree in
                if isAdFree {
                    Task { await adService.hideBanner() }
                }
            }
            .onChange(of: gameStore.state.isGameOver) { _, isGameOver in
                if isGameOver && !isShowingPowerUpOverlay && !isShowingGameOverText && pendingGameSummary == nil {
                    // Show out of moves dialog when game ends
                    powerUpOverlayContext = .outOfMoves
                    isShowingPowerUpOverlay = true
                } else if !isGameOver {
                    // Game recovered (e.g., power-up created new moves)
                    // Cancel any pending reset and hide overlays
                    gameOverResetTask?.cancel()
                    gameOverResetTask = nil
                    isShowingPowerUpOverlay = false
                    isShowingGameOverText = false
                    pendingGameSummary = nil
                }
            }
            .onChange(of: gameStore.validMovesCount) { _, newCount in
                // Show low-on-moves warning when moves drop to 5 or below
                // Re-arms when moves go back above 5 (e.g., after using a powerup)
                if newCount > 5 {
                    lowMovesWarningArmed = true
                } else if newCount > 0 && newCount <= 5 && lowMovesWarningArmed && !gameStore.state.isGameOver && !isShowingPowerUpOverlay {
                    lowMovesWarningArmed = false
                    isShowingLowOnMoves = true
                }
            }


        // Wrap everything with full-screen wallpaper background
        return NavigationStack {
            ZStack {
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

                // Power-up recovery overlay (for out of moves / low on moves)
                if isShowingPowerUpOverlay {
                    powerUpOverlay
                }

                if let presentation = pendingGameSummary {
                    GameSummaryView(
                        summary: presentation.summary,
                        isFirstRun: presentation.isFirstRun,
                        isPersonalBest: presentation.isPersonalBest,
                        isSandboxed: gameStore.sandboxed,
                        onPlayAgain: { playAgainFromSummary() },
                        onReplayFromMilestone: { replayFromMilestoneAfterSummary() },
                        onHome: { returnHomeFromSummary() }
                    )
                }
            }
            .navigationTitle("")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar { gameplayNavigationToolbar }
            .gameplayNavigationBarBackground()
        }
        .alert("Spend Gems?", isPresented: milestoneSpendBinding, presenting: pendingMilestoneSpend) { tier in
            Button("Cancel", role: .cancel) {
                pendingMilestoneSpend = nil
            }
            Button("Spend \(tier.gemCost) Gems") {
                confirmMilestoneSpend(tier)
            }
        } message: { tier in
            Text("Spend \(tier.gemCost) gems to replay from \(tier.label)?")
        }
        .trackScreen(.gameplay)
    }

    @ToolbarContentBuilder
    private var gameplayNavigationToolbar: some ToolbarContent {
        #if os(macOS)
        ToolbarItem(placement: .navigation) {
            GameplayNavigationLeading(
                rank: tempHomeState.rank,
                showsRank: showsNavigationRank,
                onPause: { presentedSheet = .pause },
                onLeaderboard: { presentedSheet = .leaderboard }
            )
        }
        ToolbarItem(placement: .principal) {
            GameplayNavigationStatus()
        }
        ToolbarItem(placement: .primaryAction) {
            GameplayNavigationGemButton(onShop: { presentedSheet = .shop })
        }
        #else
        ToolbarItem(placement: .topBarLeading) {
            GameplayNavigationLeading(
                rank: tempHomeState.rank,
                showsRank: showsNavigationRank,
                onPause: { presentedSheet = .pause },
                onLeaderboard: { presentedSheet = .leaderboard }
            )
        }
        ToolbarItem(placement: .principal) {
            GameplayNavigationStatus()
        }
        ToolbarItem(placement: .topBarTrailing) {
            GameplayNavigationGemButton(onShop: { presentedSheet = .shop })
        }
        #endif
    }

    private var showsNavigationRank: Bool {
        #if os(iOS)
        horizontalSizeClass == .regular
        #else
        true
        #endif
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

    // MARK: - Power Up Recovery Overlay (Out of Moves & Low on Moves)

    private var powerUpOverlay: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture { /* block taps */ }

            powerUpCard
        }
    }

    private var powerUpCard: some View {
        VStack(spacing: 0) {
            // Title
            Text(powerUpOverlayContext == .outOfMoves ? "Out of Moves!" : "Low on Moves!")
                .font(.avenirNext(size: 28, weight: .heavy))
                .foregroundColor(.white)
                .padding(.top, 28)

            // Subtitle
            Text(powerUpOverlayContext == .outOfMoves ? "Continue?" : "Need a boost?")
                .font(.avenirNext(size: 20, weight: .bold))
                .foregroundColor(.white.opacity(0.85))
                .padding(.top, 16)

            // Power-up purchase row
            powerUpIconRow
                .padding(.top, 24)
                .padding(.horizontal, 20)

            // Bottom row: No Thanks + FREE AD
            powerUpBottomRow
                .padding(.top, 24)
                .padding(.bottom, 20)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: 360)
        .overlay(alignment: .topTrailing) {
            // Home button — go back without choosing
            if powerUpOverlayContext == .outOfMoves {
                Button {
                    isShowingPowerUpOverlay = false
                    isPlayingDismiss?()
                } label: {
                    Image(systemName: "house.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .padding(12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .inset(by: 4)
                .stroke(Color(white: 0.28), lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.6), radius: 20, y: 10)
    }

    private var powerUpIconRow: some View {
        HStack(spacing: 12) {
            powerUpCardView(
                assetName: "hammer",
                cost: gameStore.powerUpPrice("hammer"),
                hasInventory: gameStore.powerUpInventory["hammer", default: 0] > 0
            ) {
                isShowingPowerUpOverlay = false
                isHammerMode = true
            }

            powerUpCardView(
                assetName: "swap",
                cost: gameStore.powerUpPrice("swap"),
                hasInventory: gameStore.powerUpInventory["swap", default: 0] > 0
            ) {
                isShowingPowerUpOverlay = false
                isSwapMode = true
            }

            powerUpCardView(
                assetName: "magnet",
                cost: gameStore.powerUpPrice("magnet"),
                hasInventory: gameStore.powerUpInventory["magnet", default: 0] > 0
            ) {
                isShowingPowerUpOverlay = false
                isMagnetMode = true
            }
        }
    }

    private func powerUpCardView(
        assetName: String,
        cost: Int,
        hasInventory: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                // Green gradient background
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.78, blue: 0.25),
                                Color(red: 0.26, green: 0.62, blue: 0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Power-up icon
                VStack {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                    Spacer(minLength: 0)
                }
                .padding(.top, 10)

                // Gem cost badge
                HStack(spacing: 4) {
                    Image("gem")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                    Text(hasInventory ? "FREE" : "\(cost)")
                        .font(.avenirNext(size: 14, weight: .heavy))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(Color.black.opacity(0.35))
                )
                .padding(.bottom, 6)
            }
            .frame(width: 95, height: 100)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(red: 0.45, green: 0.88, blue: 0.35), lineWidth: 2)
            )
        }
    }

    private var powerUpBottomRow: some View {
        HStack {
            // No Thanks button
            Button {
                if powerUpOverlayContext == .outOfMoves {
                    isShowingQuitConfirmation = true
                } else {
                    isShowingPowerUpOverlay = false
                }
            } label: {
                VStack(spacing: 2) {
                    Text("No Thanks")
                        .font(.avenirNext(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(height: 1.5)
                }
            }

            Spacer()

            if !purchaseService.isAdFreePurchased {
                // FREE AD button
                Button {
                    Task {
                        let _ = await adService.showRewarded {
                            grantAdGems(135)
                            haptics.success()
                        }
                        isShowingPowerUpOverlay = false
                    }
                } label: {
                    VStack(spacing: 0) {
                        Text("FREE")
                            .font(.avenirNext(size: 11, weight: .heavy))
                            .foregroundColor(.white)
                        HStack(spacing: 2) {
                            Image("gem")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                            Text("+135")
                                .font(.avenirNext(size: 15, weight: .bold))
                                .foregroundColor(.white)
                        }
                        HStack(spacing: 3) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 8))
                            Text("AD")
                                .font(.avenirNext(size: 9, weight: .heavy))
                        }
                        .foregroundColor(.white)
                        .padding(.top, 1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.85, green: 0.65, blue: 0.1))
                    )
                }
            }
        }
    }

    private func showGameOverAndReset() {
        gameStore.gameOverConfirmed = true
        isShowingGameOverText = true
        isShowingPowerUpOverlay = false

        // Post the player's highest tile to the social feed
        let step = gameStore.state.highestTileStep
        let tileName = TileStepLabelFormatter.labelForStep(step, start: 2)
        socialFeedPublisher.postEndlessMilestone(tileName: tileName)

        // Cancel any existing reset task
        gameOverResetTask?.cancel()

        // Show GAME OVER briefly, then transition into the run payoff summary.
        gameOverResetTask = Task {
            try? await Task.sleep(for: .seconds(2))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                isShowingGameOverText = false
                pendingGameSummary = makeGameSummaryPresentation()
            }
        }
    }

    private func startAtMilestone(_ tier: MilestoneTier) {
        if tier.gemCost > 0 {
            pendingMilestoneSpend = tier
            return
        }
        startAtMilestoneAfterSpend(tier)
    }

    private func confirmMilestoneSpend(_ tier: MilestoneTier) {
        pendingMilestoneSpend = nil
        guard gameStore.spendCoins(tier.gemCost) else {
            isShowingInsufficientGemsAlert = true
            return
        }
        startAtMilestoneAfterSpend(tier)
    }

    private func startAtMilestoneAfterSpend(_ tier: MilestoneTier) {
        isShowingMilestoneStart = false
        isShowingQuitConfirmation = false
        pendingGameSummary = nil
        lowMovesWarningArmed = true
        if tier.step == 0 {
            gameStore.resetGame()
        } else {
            gameStore.resetGameAtMilestone(step: tier.step)
        }
        captureRunStartBaselines()
    }

    private func makeGameSummaryPresentation() -> GameSummaryPresentation {
        let summary = gameStore.currentRunSummary()
        let presentation = GameSummaryPresentation(
            summary: summary,
            isFirstRun: !hasSeenFirstGameSummary,
            isPersonalBest: !gameStore.sandboxed && !summary.scoreAlpha.isZero && summary.scoreAlpha > runBestScoreAtStart
        )
        hasSeenFirstGameSummary = true
        return presentation
    }

    private func playAgainFromSummary() {
        pendingGameSummary = nil
        selectedMilestoneIndex = 0
        startAtMilestoneAfterSpend(MilestoneTier.allTiers[0])
    }

    private func replayFromMilestoneAfterSummary() {
        pendingGameSummary = nil
        selectedMilestoneIndex = 0
        isShowingPowerUpOverlay = false
        isShowingQuitConfirmation = false
        isShowingMilestoneStart = true
    }

    private func returnHomeFromSummary() {
        pendingGameSummary = nil
        isShowingPowerUpOverlay = false
        isShowingMilestoneStart = false
        isShowingQuitConfirmation = false
        isPlayingDismiss?()
    }

    private func captureRunStartBaselines() {
        runBestScoreAtStart = savedBestScoreAlpha()
    }

    private func savedBestScoreAlpha() -> AlphaNumber {
        if let string = UserDefaults.standard.string(forKey: "savedBestScoreAlpha"),
           let alpha = AlphaNumber(decimalString: string) {
            return alpha
        }
        return AlphaNumber(UserDefaults.standard.integer(forKey: "savedBestScore"))
    }

    @ViewBuilder
    private var gameplayLayout: some View {
        GeometryReader { proxy in
            let metrics = PuzzleScreenMetrics(
                container: proxy.size,
                safeArea: proxy.safeAreaInsets,
                rows: gameStore.state.board.height,
                columns: gameStore.state.board.width
            )

            gameplayContent(metrics: metrics)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    @ViewBuilder
    private func gameplayContent(metrics: PuzzleScreenMetrics) -> some View {
        switch metrics.placement {
        case .sidebar:
            HStack(alignment: .center, spacing: PuzzleScreenMetrics.sidebarGap) {
                gameBoard(metrics: metrics)
                    .frame(width: metrics.boardSize.width, height: metrics.boardSize.height)
                    .layoutPriority(10)

                GameplaySidePanel(
                    scoreText: gameStore.state.scoreValue.formattedWithCommas(),
                    rank: tempHomeState.rank,
                    isCompact: metrics.compression != .expanded,
                    onPause: { presentedSheet = .pause },
                    onShop: { presentedSheet = .shop },
                    onLeaderboard: { presentedSheet = .leaderboard },
                    onHammer: handleHammer,
                    onSwap: handleSwap,
                    onMagnet: handleMagnet,
                    onUndo: handleUndo
                )
                .frame(width: metrics.sidePanelWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(metrics.margin)

        case .compact, .compactCompressed, .centered:
            VStack(spacing: metrics.sectionSpacing) {
                gameplayObjective(metrics: metrics)
                    .frame(height: metrics.objectiveHeight)

                gameBoard(metrics: metrics)
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

    @ViewBuilder
    private func gameplayObjective(metrics: PuzzleScreenMetrics) -> some View {
        if metrics.compression == .collapsed {
            ObjectiveProgressBand(isCompact: true)
        } else {
            GameplayInfoPanel(isCompact: metrics.compression == .compact)
        }
    }

    @ViewBuilder
    private func gameBoard(metrics: PuzzleScreenMetrics) -> some View {
        ZStack {
            // Board container with glass preview (clear background)
            SimplifiedGlassBoardView(
                onTileTap: { position in handleTileTap(at: position) },
                isPowerUpActive: isHammerMode || isSwapMode || isMagnetMode,
                maxTileSize: metrics.maxTileSize,
                gridSpacing: metrics.gridSpacing
            )
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
                let merges = gameStore.useMagnet(value: tile.value, to: position)
                if merges > 0 {
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

    @MainActor
    private func grantAdGems(_ amount: Int) {
        guard amount > 0 else { return }
        let key = "ad:gameplay:\(amount):\(Int(Date().timeIntervalSince1970))"
        if let rewardLedger {
            rewardLedger.grant(
                source: .ad,
                itemType: .gems,
                amount: amount,
                idempotencyKey: key
            ) {
                gameStore.addCoins(amount)
            }
        } else {
            gameStore.addCoins(amount)
        }
    }
}

#Preview("Gameplay - iPhone SE") {
    hybridGameScreenPreview(size: CGSize(width: 375, height: 667))
}

#Preview("Gameplay - iPhone Pro Max") {
    hybridGameScreenPreview(size: CGSize(width: 430, height: 932))
}

#Preview("Gameplay - iPad Portrait") {
    hybridGameScreenPreview(size: CGSize(width: 820, height: 1180))
}

#Preview("Gameplay - iPad Landscape") {
    hybridGameScreenPreview(size: CGSize(width: 1180, height: 820))
}

#Preview("Gameplay - Split View") {
    hybridGameScreenPreview(size: CGSize(width: 650, height: 900))
}

@MainActor
@ViewBuilder
private func hybridGameScreenPreview(size: CGSize) -> some View {
    let gameStore = GameStore()
    let readiness = PlayerReadinessStore()

    HybridGameScreen(isPlayingDismiss: {})
        .environment(\.gameStore, gameStore)
        .environment(\.currentTheme, ThemeRegistry.Default.descriptor(for: "raised-3d-square"))
        .environment(DailyQuestStore())
        .environment(readiness)
        .frame(width: size.width, height: size.height)
}


// MARK: - Gameplay Navigation Bar

struct GameplayNavigationLeading: View {
    let rank: Int
    let showsRank: Bool
    let onPause: () -> Void
    let onLeaderboard: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onPause) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .glassEffectCompat(cornerRadius: 10)
            .accessibilityLabel("Pause")

            if showsRank {
                Button(action: onLeaderboard) {
                    Text("#\(rank)")
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .padding(.horizontal, 9)
                        .frame(height: 34)
                }
                .buttonStyle(.plain)
                .glassEffectCompat(cornerRadius: 10)
                .accessibilityLabel("Rank \(rank). Open leaderboard.")
            }
        }
        .foregroundStyle(.white)
    }
}

struct GameplayNavigationStatus: View {
    @Environment(\.gameStore) private var gameStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 5) {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .bold))
                Text(playtimeText(at: context.date))
                    .monospacedDigit()
            }
            .font(.avenirNext(size: GameFonts.calloutSize, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(minHeight: 34)
            .glassEffectCompat(cornerRadius: 10)
            .accessibilityLabel("Time \(playtimeText(at: context.date))")
        }
    }

    private func playtimeText(at date: Date) -> String {
        let savedSeconds = UserDefaults.standard.integer(forKey: "playtime.totalSeconds")
        let sessionStart = gameStore.achievementEvaluator?.sessionStartTime ?? date
        let totalSeconds = savedSeconds + Int(date.timeIntervalSince(sessionStart))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

struct GameplayNavigationGemButton: View {
    @Environment(\.gameStore) private var gameStore
    let onShop: () -> Void

    var body: some View {
        Button(action: onShop) {
            HStack(spacing: 4) {
                Image("gem")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text("\(gameStore.coins)")
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 8)
            .frame(height: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffectCompat(cornerRadius: 10)
        .accessibilityLabel("Gems \(gameStore.coins). Open shop.")
    }
}

extension View {
    @ViewBuilder
    func gameplayNavigationBarBackground() -> some View {
        #if os(iOS)
        self
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        #else
        self
        #endif
    }
}


// MARK: - Gameplay Layout Chrome

struct GameplayInfoPanel: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.currentTheme) private var currentTheme
    @Environment(DailyQuestStore.self) private var dailyQuestStore

    let isCompact: Bool

    private var bestStep: Int {
        max(0, gameStore.state.highestTileStep)
    }

    private var goalStep: Int {
        bestStep + 1
    }

    private var bestLabel: String {
        JourneyTileGenerator.formatTileAtStep(bestStep)
    }

    private var goalLabel: String {
        JourneyTileGenerator.formatTileAtStep(goalStep)
    }

    private var featuredQuest: DailyQuestStore.Quest? {
        dailyQuestStore.quests.first(where: { !$0.claimed && !$0.isComplete })
        ?? dailyQuestStore.quests.first(where: { $0.isClaimable })
        ?? dailyQuestStore.quests.first(where: { !$0.claimed })
        ?? dailyQuestStore.quests.first
    }

    private var validMovesColor: Color {
        let count = gameStore.validMovesCount
        if count == 0 { return .red }
        if count < 10 { return .orange }
        if count < 20 { return .yellow }
        return .green
    }

    var body: some View {
        VStack(spacing: isCompact ? 6 : 8) {
            milestoneProgress
            runStats
            if let featuredQuest {
                DailyQuestStatusRow(quest: featuredQuest, isCompact: isCompact)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Best \(bestLabel), goal \(goalLabel), \(gameStore.state.moves) moves, \(gameStore.validMovesCount) valid moves"
        )
    }

    private var milestoneProgress: some View {
        VStack(spacing: isCompact ? 4 : 5) {
            HStack(spacing: 8) {
                MilestoneValuePill(
                    title: "Best",
                    value: bestLabel,
                    color: currentTheme?.colorForStep(bestStep) ?? .green
                )

                Spacer(minLength: 8)

                MilestoneValuePill(
                    title: "Goal",
                    value: goalLabel,
                    color: currentTheme?.colorForStep(goalStep) ?? .orange
                )
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                    Capsule()
                        .fill(currentTheme?.colorForStep(bestStep) ?? .green)
                        .frame(width: max(5, geometry.size.width * 0.5))
                }
            }
            .frame(height: isCompact ? 4 : 5)
        }
    }

    private var scoreLabel: String {
        gameStore.state.scoreValue.formattedWithCommas()
    }

    private var runStats: some View {
        HStack(spacing: isCompact ? 6 : 8) {
            GameplayInfoStat(
                title: "Moves",
                value: "\(gameStore.state.moves)",
                systemImage: "arrow.triangle.2.circlepath",
                isCompact: isCompact
            )
            GameplayInfoStat(
                title: "Valid Moves",
                value: "\(gameStore.validMovesCount)",
                systemImage: "point.3.connected.trianglepath.dotted",
                isCompact: isCompact,
                valueColor: validMovesColor
            )
            GameplayInfoStat(
                title: "Highest",
                value: bestLabel,
                systemImage: "crown.fill",
                isCompact: isCompact
            )
            if !gameStore.sandboxed {
                GameplayInfoStat(
                    title: "Score",
                    value: scoreLabel,
                    systemImage: "number",
                    isCompact: isCompact
                )
            }
        }
    }
}

struct MilestoneValuePill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
    }
}

struct GameplayInfoStat: View {
    let title: String
    let value: String
    let systemImage: String
    let isCompact: Bool
    var valueColor: Color = .white

    var body: some View {
        HStack(spacing: isCompact ? 5 : 6) {
            Image(systemName: systemImage)
                .font(.system(size: isCompact ? 12 : 13, weight: .semibold))
                .frame(width: isCompact ? 14 : 16)
                .foregroundStyle(.white.opacity(0.68))

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.avenirNext(size: GameFonts.caption2Size, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
                Text(value)
                    .font(.avenirNext(size: isCompact ? GameFonts.caption1Size : GameFonts.subheadlineSize, weight: .heavy))
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, isCompact ? 7 : 8)
        .frame(height: isCompact ? 30 : 34)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

struct DailyQuestStatusRow: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(DailyQuestStore.self) private var dailyQuestStore

    let quest: DailyQuestStore.Quest
    let isCompact: Bool

    private var accentColor: Color {
        if quest.isClaimable {
            return .green
        }
        if quest.isComplete {
            return .blue
        }
        return .cyan
    }

    private var progressText: String? {
        if quest.claimed {
            return "Claimed"
        }
        if quest.isClaimable {
            return "Ready"
        }
        if quest.id == "daily_tile_reach" && dailyQuestStore.tileQuestTargetStep > 0 {
            return nil
        }
        let current = CompactNumberFormatter.format(min(quest.current, quest.target))
        let target = CompactNumberFormatter.format(quest.target)
        return "\(current)/\(target)"
    }

    var body: some View {
        HStack(spacing: isCompact ? 7 : 9) {
            Image(systemName: quest.isClaimable ? "gift.fill" : "checklist")
                .font(.system(size: isCompact ? 13 : 14, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Daily")
                        .font(.avenirNext(size: GameFonts.caption2Size, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.54))
                    Text(quest.title)
                        .font(.avenirNext(size: isCompact ? GameFonts.caption2Size : GameFonts.caption1Size, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Spacer(minLength: 4)
                    if let progressText {
                        Text(progressText)
                            .font(.avenirNext(size: GameFonts.caption2Size, weight: .heavy))
                            .foregroundStyle(quest.isClaimable ? .green : .white.opacity(0.74))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                }

                if quest.id == "daily_tile_reach" && dailyQuestStore.tileQuestTargetStep > 0 {
                    QuestMilestoneBar(
                        startStep: dailyQuestStore.tileQuestTargetStep - 10,
                        targetStep: dailyQuestStore.tileQuestTargetStep,
                        currentStep: gameStore.state.highestTileStep
                    )
                    .frame(height: 16)
                    .padding(.top, 4)
                } else {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                            Capsule()
                                .fill(accentColor)
                                .frame(width: max(4, geometry.size.width * quest.progress))
                        }
                    }
                    .frame(height: isCompact ? 3 : 4)
                }
            }
        }
        .padding(.horizontal, isCompact ? 8 : 10)
        .frame(height: isCompact ? 28 : 32)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

struct ObjectiveProgressBand: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.currentTheme) private var currentTheme

    let isCompact: Bool

    private var bestStep: Int {
        max(0, gameStore.state.highestTileStep)
    }

    private var goalStep: Int {
        bestStep + 1
    }

    private var bestLabel: String {
        JourneyTileGenerator.formatTileAtStep(bestStep)
    }

    private var goalLabel: String {
        JourneyTileGenerator.formatTileAtStep(goalStep)
    }

    var body: some View {
        VStack(spacing: isCompact ? 3 : 5) {
            HStack {
                Text("Best \(bestLabel)")
                Spacer(minLength: 12)
                Text("Goal \(goalLabel)")
            }
            .font(.avenirNext(size: isCompact ? GameFonts.caption2Size : GameFonts.caption1Size, weight: .bold))
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                    Capsule()
                        .fill(currentTheme?.colorForStep(bestStep) ?? .green)
                        .frame(width: max(isCompact ? 4 : 5, geometry.size.width * 0.5))
                }
            }
            .frame(height: isCompact ? 4 : 6)
        }
        .padding(.horizontal, isCompact ? 10 : 12)
        .padding(.vertical, isCompact ? 4 : 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Best \(bestLabel), goal \(goalLabel)")
    }
}

private struct GameplaySidePanel: View {
    @Environment(\.gameStore) private var gameStore

    let scoreText: String
    let rank: Int
    let isCompact: Bool
    let onPause: () -> Void
    let onShop: () -> Void
    let onLeaderboard: () -> Void
    let onHammer: () -> Void
    let onSwap: () -> Void
    let onMagnet: () -> Void
    let onUndo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
            HStack(spacing: 10) {
                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .glassEffectCompat(cornerRadius: 10)
                .accessibilityLabel("Pause")

                Button(action: onLeaderboard) {
                    Text("#\(rank)")
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .padding(.horizontal, 10)
                        .frame(height: 38)
                }
                .buttonStyle(.plain)
                .glassEffectCompat(cornerRadius: 10)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    SidePanelStat(
                        title: "Timer",
                        value: playtimeText(at: context.date),
                        systemImage: "timer"
                    )
                }
                if !gameStore.sandboxed {
                    SidePanelStat(title: "Score", value: scoreText, systemImage: "number")
                }
                SidePanelStat(title: "Moves", value: "\(gameStore.validMovesCount)", systemImage: "point.3.connected.trianglepath.dotted")
            }

            ObjectiveProgressBand(isCompact: false)
                .frame(height: 58)

            SidebarPowerupPanel(
                onHammer: onHammer,
                onSwap: onSwap,
                onMagnet: onMagnet,
                onUndo: onUndo
            )

            Spacer(minLength: 0)

            Button(action: onShop) {
                HStack(spacing: 8) {
                    Image("gem")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                    Text("\(gameStore.coins)")
                        .font(.avenirNext(size: GameFonts.headlineSize, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Image(systemName: "cart.fill")
                        .imageScale(.medium)
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .glassEffectCompat(cornerRadius: 12)
            .accessibilityLabel("Gems \(gameStore.coins). Open shop.")
        }
        .padding(16)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.2))
        )
    }

    private func playtimeText(at date: Date) -> String {
        let savedSeconds = UserDefaults.standard.integer(forKey: "playtime.totalSeconds")
        let sessionStart = gameStore.achievementEvaluator?.sessionStartTime ?? date
        let totalSeconds = savedSeconds + Int(date.timeIntervalSince(sessionStart))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private struct SidePanelStat: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 24)
                .foregroundStyle(.white.opacity(0.75))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.avenirNext(size: GameFonts.caption2Size, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                Text(value)
                    .font(.avenirNext(size: GameFonts.headlineSize, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private struct SidebarPowerupPanel: View {
    @Environment(\.gameStore) private var gameStore

    let onHammer: () -> Void
    let onSwap: () -> Void
    let onMagnet: () -> Void
    let onUndo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Powerups")
                .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                .foregroundStyle(.white.opacity(0.75))

            SidebarPowerupCard(
                title: "Hammer",
                assetName: "hammer",
                count: gameStore.powerUpInventory["hammer", default: 0],
                price: gameStore.powerUpPrice("hammer"),
                isEnabled: gameStore.isPowerUpAvailable("hammer"),
                action: onHammer
            )

            SidebarPowerupCard(
                title: "Swap",
                assetName: "swap",
                count: gameStore.powerUpInventory["swap", default: 0],
                price: gameStore.powerUpPrice("swap"),
                isEnabled: gameStore.isPowerUpAvailable("swap"),
                action: onSwap
            )

            SidebarPowerupCard(
                title: "Magnet",
                assetName: "magnet",
                count: gameStore.powerUpInventory["magnet", default: 0],
                price: gameStore.powerUpPrice("magnet"),
                isEnabled: gameStore.isPowerUpAvailable("magnet"),
                action: onMagnet
            )

            SidebarPowerupCard(
                title: "Undo",
                systemImage: "arrow.uturn.backward",
                count: gameStore.state.undoAvailable ? 1 : 0,
                price: nil,
                isEnabled: gameStore.state.undoAvailable,
                action: onUndo
            )
        }
    }
}

private struct SidebarPowerupCard: View {
    let title: String
    var assetName: String? = nil
    var systemImage: String? = nil
    let count: Int
    let price: Int?
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon
                    .frame(width: 30, height: 30)

                Text(title)
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 8)

                inventoryLabel
            }
            .padding(.horizontal, 10)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.48)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    @ViewBuilder
    private var icon: some View {
        if let assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
        } else if let systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    @ViewBuilder
    private var inventoryLabel: some View {
        if count > 0 {
            Text("x\(count)")
                .font(.avenirNext(size: GameFonts.caption2Size, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.blue, in: Capsule())
        } else if let price {
            HStack(spacing: 3) {
                Image("gem")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                Text("\(price)")
                    .font(.avenirNext(size: GameFonts.caption2Size, weight: .bold))
            }
            .foregroundStyle(.white)
        }
    }
}


// MARK: - Horizontal Power-up Dock (for iPhone)

struct HorizontalPowerupDock: View {
    @Environment(\.gameStore) private var gameStore
    let isCollapsed: Bool
    let onHammer: () -> Void
    let onSwap: () -> Void
    let onMagnet: () -> Void
    let onUndo: () -> Void

    var body: some View {
        Group {
            if isCollapsed {
                collapsedContent
            } else {
                expandedContent
            }
        }
        .padding(.horizontal, isCollapsed ? 10 : 16)
        .padding(.vertical, isCollapsed ? 5 : 8)
        .frame(maxWidth: isCollapsed ? nil : .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 4)
        )
    }

    private var collapsedContent: some View {
        HStack(spacing: 10) {
            Menu {
                Button("Hammer", action: onHammer)
                    .disabled(!gameStore.isPowerUpAvailable("hammer"))
                Button("Swap", action: onSwap)
                    .disabled(!gameStore.isPowerUpAvailable("swap"))
                Button("Magnet", action: onMagnet)
                    .disabled(!gameStore.isPowerUpAvailable("magnet"))
            } label: {
                Label("Powerups", systemImage: "bolt.fill")
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
            }
            .buttonStyle(.plain)
            .glassEffectCompat(cornerRadius: 12)

            powerupItem(
                icon: "arrow.uturn.backward",
                isEnabled: gameStore.state.undoAvailable,
                action: onUndo
            )
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Powerups", systemImage: "bolt.fill")
                .font(.avenirNext(size: GameFonts.caption2Size, weight: .heavy))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)

            HStack(spacing: 8) {
                expandedPowerupButton(
                    title: "Hammer",
                    assetName: "hammer",
                    badge: gameStore.powerUpInventory["hammer", default: 0],
                    price: gameStore.powerUpPrice("hammer"),
                    isEnabled: gameStore.isPowerUpAvailable("hammer"),
                    action: onHammer
                )

                expandedPowerupButton(
                    title: "Swap",
                    assetName: "swap",
                    badge: gameStore.powerUpInventory["swap", default: 0],
                    price: gameStore.powerUpPrice("swap"),
                    isEnabled: gameStore.isPowerUpAvailable("swap"),
                    action: onSwap
                )

                expandedPowerupButton(
                    title: "Magnet",
                    assetName: "magnet",
                    badge: gameStore.powerUpInventory["magnet", default: 0],
                    price: gameStore.powerUpPrice("magnet"),
                    isEnabled: gameStore.isPowerUpAvailable("magnet"),
                    action: onMagnet
                )

                expandedPowerupButton(
                    title: "Undo",
                    systemImage: "arrow.uturn.backward",
                    badge: gameStore.state.undoAvailable ? 1 : 0,
                    price: nil,
                    isEnabled: gameStore.state.undoAvailable,
                    action: onUndo
                )
            }
        }
    }

    private func expandedPowerupButton(
        title: String,
        assetName: String? = nil,
        systemImage: String? = nil,
        badge: Int,
        price: Int?,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                powerupIcon(assetName: assetName, systemImage: systemImage, isEnabled: isEnabled)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.avenirNext(size: GameFonts.caption2Size, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    statusBadge(badge: badge, price: price)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 38)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(isEnabled ? 0.1 : 0.05))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
        .accessibilityLabel("\(title) powerup")
    }

    @ViewBuilder
    private func powerupIcon(assetName: String?, systemImage: String?, isEnabled: Bool) -> some View {
        if let assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .opacity(isEnabled ? 1.0 : 0.45)
        } else if let systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(isEnabled ? .white : .white.opacity(0.45))
        }
    }

    @ViewBuilder
    private func statusBadge(badge: Int, price: Int?) -> some View {
        if badge > 0 {
            Text("x\(badge)")
                .font(.avenirNext(size: 10, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.blue, in: Capsule())
                .lineLimit(1)
        } else if let price {
            HStack(spacing: 2) {
                Image("gem")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 9, height: 9)
                Text("\(price)")
                    .font(.avenirNext(size: 10, weight: .bold))
                    .monospacedDigit()
            }
            .foregroundStyle(.white.opacity(0.84))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
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

// MARK: - Invalid Chain Banner

struct InvalidChainBanner: View {
    let message: String
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.avenirNext(size: GameFonts.caption1Size, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .accessibilityLabel(Text("Invalid chain: \(message)"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.55), lineWidth: 1)
        )
        .shadow(radius: reduceMotion ? 0 : 4)
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
                return "Tap a tile to swap"
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

private struct GameSummaryPresentation: Identifiable {
    let summary: GameRunSummary
    let isFirstRun: Bool
    let isPersonalBest: Bool

    var id: String { summary.id }
}

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
        MilestoneTier(id: 12, step: 587, gemCost: 100_000, label: "1bd"),
    ]
}

// MARK: - Milestone Start Overlay

extension HybridGameScreen {
    var milestoneStartOverlay: some View {
        let sessionHighestStep = gameStore.state.highestTileStep

        return ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Replay")
                    .font(.avenirNext(size: 32, weight: .heavy))
                    .foregroundColor(.white)

                milestoneStartPreviewTile
                milestoneStartPickerRow(sessionHighestStep: sessionHighestStep)
                milestoneStartActionButtons
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

    private var milestoneStartPreviewTile: some View {
        let selectedTier = MilestoneTier.allTiers[selectedMilestoneIndex]
        return ZStack {
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
                            lineWidth: 6
                        )
                )

            TileView(
                tile: Tile.make(forStep: selectedTier.step),
                isSelected: false,
                isValid: true,
                size: 96,
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
    }

    private func milestoneStartPickerRow(sessionHighestStep: Int) -> some View {
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
                                size: 60,
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
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    isSelected ? Color.green : Color.clear,
                                    lineWidth: 4
                                )
                        )

                        // Price label
                        if tier.gemCost == 0 {
                            Text("FREE")
                                .font(.avenirNext(size: 12, weight: .bold))
                                .foregroundColor(.green)
                        } else if reachedMilestone {
                            HStack(spacing: 2) {
                                Image("gem")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                                Text(tier.gemCost >= 1000 ? "\(tier.gemCost / 1000)K" : "\(tier.gemCost)")
                                    .font(.avenirNext(size: 14, weight: .bold))
                                    .foregroundColor(canAfford ? .white : .red)
                            }
                        } else {
                            Text("🔒")
                                .font(.system(size: 12))
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
                        haptics.selectionChanged()
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 100)
    }

    private var milestoneStartActionButtons: some View {
        HStack(spacing: 12) {
            // OK button to start
            Button {
                let tier = MilestoneTier.allTiers[selectedMilestoneIndex]
                startAtMilestone(tier)
            } label: {
                Text("OK")
                    .font(.avenirNext(size: 24, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.38, green: 0.82, blue: 0.32)) // Bright green like image
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(red: 0.6, green: 0.9, blue: 0.5), lineWidth: 2) // Lighter top edge fake 3d
                    )
            }

            if !purchaseService.isAdFreePurchased {
                // FREE +120 AD button
                Button {
                    Task {
                        let _ = await adService.showRewarded {
                            grantAdGems(120)
                            haptics.success()
                        }
                    }
                } label: {
                    VStack(spacing: 0) {
                        Text("FREE")
                            .font(.avenirNext(size: 12, weight: .heavy))
                            .foregroundColor(.white)
                        HStack(spacing: 2) {
                            Image("gem")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                            Text("+120")
                                .font(.avenirNext(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 8))
                            Text("AD")
                                .font(.avenirNext(size: 10, weight: .black))
                        }
                        .foregroundColor(.black.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(4)
                        .padding(.top, 2)
                    }
                    .frame(width: 80, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 1.0, green: 0.75, blue: 0.0)) // Golden yellow
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(red: 1.0, green: 0.9, blue: 0.4), lineWidth: 2)
                    )
                }
            }
        }
        .padding(.horizontal, 24)
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

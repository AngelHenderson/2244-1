import SwiftUI
import GameApp
import GameCore
#if canImport(FirebaseCore)
import FirebaseCore
#endif

/// Root view that manages the flow between Home and Game screens
public struct RootGameView: View {
    private let managesBackground: Bool
    @Environment(HomeState.self) private var homeState
    @Environment(PlayerReadinessStore.self) private var playerReadiness
    @Environment(\.gameStore) private var gameStore
    @Environment(\.tileJourney) private var journey
    @Environment(\.adService) private var adService
    @Environment(\.purchaseService) private var purchaseService
    @Environment(\.rewardLedgerOptional) private var rewardLedger
    @Environment(\.deepLinkRouter) private var deepLinkRouter
    @State private var isPlaying = false
    @State private var hasLoadedInitialState = false
    @State private var showDailyClaims = false
    @State private var showDailyStreaks = false
    @State private var showShop = false
    @State private var showFreeSpin = false
    @State private var showChallenge = false
    @State private var showChallengeDesigner = false
    @State private var isPlayingCustomChallenge = false
    @State private var customChallengeConfig: CustomChallengeConfig?
    @State private var capturedChallengeCreationMultiplier: Int = 1
    @State private var wheelEngine = WheelEngine()
    @State private var challengeStore = ChallengeStore()
    @State private var challengeDesignerStore = ChallengeDesignerStore()
    @State private var isShowingTutorial = false

    @Environment(DailyClaimsStore.self) private var dailyClaimsStore
    @Environment(DailyQuestStore.self) private var dailyQuestStore
    @Environment(\.backgroundThemeRegistry) private var backgroundThemeRegistry
    @Environment(\.currentBackgroundTheme) private var currentBackgroundTheme
    
    // Progress management
    private let planner: MilestonePlanner = PowerOfTwoPlanner()
    private let progressCoordinator: ProgressSyncCoordinator
    
    public init(managesBackground: Bool = true) {
        self.managesBackground = managesBackground
        let localStore = UserDefaultsProgressStore()
        // Best-effort cloud sync: only attaches the Firestore store when Firebase
        // is configured. The coordinator merges local↔remote with a max policy,
        // so a missing remote degrades cleanly to local-only.
        let remoteStore: ProgressStore? = Self.makeRemoteStore()
        self.progressCoordinator = ProgressSyncCoordinator(
            local: localStore,
            remote: remoteStore,
            seed: .init(starterGems: 305, starterTheme: "beach")
        )
    }

    private static func makeRemoteStore() -> ProgressStore? {
        #if canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else { return nil }
        return FirestoreProgressStore()
        #else
        return nil
        #endif
    }
    
    public var body: some View {
        ZStack {
            if managesBackground {
                HomeBackgroundLayer(theme: currentBackgroundTheme)
                    .ignoresSafeArea()
                    .zIndex(-1)
            }
            if isPlayingCustomChallenge, let config = customChallengeConfig {
                // Dedicated challenge gameplay screen (separate from regular gameplay)
                // Challenge uses its own GameStore internally - doesn't affect regular gameplay
                CustomChallengeGameScreen(
                    config: config,
                    playerHighestTile: gameStore.state.highestTile,
                    playerHighestTileStep: gameStore.state.highestTileStep,
                    initialGems: homeState.gems,
                    onDismiss: {
                        // CRITICAL: Sync final gem balance from homeState → gameStore
                        // During the challenge, homeState.gems was decremented for each power-up use.
                        // We must push this final value into gameStore (and thus UserDefaults + progress store)
                        // BEFORE HomeView reappears and loadProgressWithCoordinator overwrites homeState.gems.
                        gameStore.coins = homeState.gems
                        gameStore.saveProgressToStore()
                        
                        // Track challenge completion for achievement progress
                        // (both custom-created and pre-made challenge mode challenges count)
                        gameStore.registerChallengeCreationCompleted(withCapturedMultiplier: capturedChallengeCreationMultiplier)
                        // Track challenge completion for daily quests (with boost multiplier)
                        if config.challengeId != nil {
                            // Pre-made challenge completed
                            dailyQuestStore.recordChallengeCompleted(count: capturedChallengeCreationMultiplier)
                        } else {
                            // Custom challenge created and completed
                            dailyQuestStore.recordChallengeCreated(count: capturedChallengeCreationMultiplier)
                        }
                        // Reset captured multiplier after use
                        capturedChallengeCreationMultiplier = 1
                        // Remember if this was a designer-created challenge before clearing config
                        let wasDesignerChallenge = config.challengeId == nil
                        // Remember if this was a pre-made challenge (from challenge list)
                        let wasFromChallengeList = config.challengeId != nil
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPlayingCustomChallenge = false
                            customChallengeConfig = nil
                        }
                        // Re-open the challenge list so the player can see progress / pick next
                        if wasFromChallengeList {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                showChallenge = true
                            }
                        }
                        // Re-open the challenge designer so the user can tweak and play again
                        if wasDesignerChallenge {
                            showChallengeDesigner = true
                        }
                    }
                )
                .environment(homeState)
                .environment(\.challengeStore, challengeStore)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if isPlaying {
                HybridGameScreen(isPlayingDismiss: {
                    // Return to home
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPlaying = false
                    }
                    // Update home state with latest game progress
                    updateHomeFromGameProgress()
                })
                .environment(\.gameStore, gameStore)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                HomeView(managesBackground: false)
                    .environment(\.homeActions, makeHomeActions())
                    .environment(\.challengeStore, challengeStore)
                    .environment(\.challengeDesignerStore, challengeDesignerStore)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .task {
                        // Load saved progress when Home appears
                        await loadProgressWithCoordinator()
                        // Update daily claims availability
                        dailyClaimsStore.updateAvailability()
                        // Refresh tile quest target (evaluator wiring happens at app level)
                        dailyQuestStore.setHighestTileStep(gameStore.state.highestTileStep)
                    }
                    .adaptiveSheet(isPresented: $showShop) {
                        ShopView(initialTab: .gems)
                    }
                    .adaptiveSheet(isPresented: $showDailyClaims) {
                        DailyClaimsView()
                            .environment(dailyClaimsStore)
                    }
                    .adaptiveSheet(isPresented: $showDailyStreaks) {
                        DailyStreaksView()
                            .environment(dailyClaimsStore)
                    }
                    .adaptiveSheet(isPresented: $showFreeSpin) {
                        SpinWheelView()
                            .environment(\.wheelEngine, wheelEngine)
                            .environment(homeState)
                    }
                    .adaptiveSheet(isPresented: $showChallenge) {
                        ChallengeModeView { challenge in
                            // Convert Challenge to CustomChallengeConfig
                            // targetTile is step-based, so use .tileStep
                            let config = CustomChallengeConfig(
                                target: challenge.targetTile.map { .tileStep($0) } ?? .score(1_000_000),
                                timeLimitSeconds: Int(challenge.timeLimit ?? 180),
                                minTileLevel: challenge.minSpawnTile ?? 0,
                                levels: 7,
                                tileAssignments: [:],
                                predictedRewardGems: challenge.reward.coins,
                                minSpawnStep: challenge.minSpawnTile,
                                maxSpawnStep: challenge.maxSpawnTile,
                                challengeId: challenge.id
                            )
                            showChallenge = false
                            customChallengeConfig = config
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPlayingCustomChallenge = true
                            }
                        }
                        .environment(\.challengeStore, challengeStore)
                    }
                    .adaptiveSheet(isPresented: $showChallengeDesigner) {
                        ChallengeDesignerView { config in
                            // Capture the achievement boost multiplier NOW, at challenge creation start
                            // This ensures the boost counts even if it expires before challenge completion
                            capturedChallengeCreationMultiplier = gameStore.achievementBoostMultiplier
                            // Start custom challenge in dedicated screen
                            print("Starting custom challenge with config: \(config)")
                            showChallengeDesigner = false
                            customChallengeConfig = config
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPlayingCustomChallenge = true
                            }
                        }
                        .environment(\.challengeDesignerStore, challengeDesignerStore)
                    }
            }
        }
        .task {
            if FirstLaunchTutorialGate.shouldPresentInCurrentBuild(
                hasCompletedTutorial: playerReadiness.hasCompletedTutorial
            ) {
                isShowingTutorial = true
            }
        }
        .platformFullScreenCover(isPresented: $isShowingTutorial) {
            OnboardingFlowView(onComplete: { preferences in
                playerReadiness.updateOnboardingPreferences(preferences)
                if preferences.completedAt == nil {
                    playerReadiness.markTutorialCompleted()
                }
                isShowingTutorial = false
            })
        }
        .onChange(of: deepLinkRouter.pendingRoute) { _, route in
            consumeDeepLinkIfOwned(route)
        }
    }

    /// Routes RootGameView owns. HomeView consumes the rest (settings,
    /// profile, achievements, leaderboard, theme, music) via its own
    /// observer.
    @MainActor
    private func consumeDeepLinkIfOwned(_ route: AppRoute?) {
        guard let route else { return }
        switch route {
        case .shop:
            showShop = true
        case .daily:
            showDailyClaims = true
        case .dailyStreaks:
            showDailyStreaks = true
        case .spin:
            showFreeSpin = true
        case .challenge:
            showChallenge = true
        case .tutorial:
            isShowingTutorial = true
        case .gameplay:
            if gameStore.state.isGameOver { gameStore.resetGame() }
            withAnimation(.easeInOut(duration: 0.3)) { isPlaying = true }
        case .settings:
            // Owned by HomeView's presentedSheet; do not consume here.
            return
        case .dailyQuests, .practice, .modes, .feed, .friends, .account, .subscription,
             .reminders, .widgetPromo, .yearReview, .proCoach, .profile, .achievements,
             .leaderboard, .theme, .music:
            // Owned by HomeView's presentedSheet; do not consume here.
            return
        }
        deepLinkRouter.consume()
    }
    


    @MainActor
    private func makeHomeActions() -> HomeActions {
        // Only actions that RootGameView actually owns are wired here.
        // Profile / achievements / leaderboard / settings / theme / sale-offer are
        // presented from HomeView's own sheet state, so their HomeActions fields
        // stay at their default no-op values.
        HomeActions(
            play: {
                // Only reset if the game is over, otherwise resume current session
                if gameStore.state.isGameOver {
                    gameStore.resetGame()
                }
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPlaying = true
                }
            },
            openShop: {
                showShop = true
            },
            buyGems: {
                homeState.addGems(120) // Demo: add some gems
                saveProgress()
            },
            watchAd: {
                guard !purchaseService.isAdFreePurchased else { return 0 }
                let reward = homeState.adReward
                let key = "ad:home:\(reward):\(Int(Date().timeIntervalSince1970))"
                let didReward = await adService.showRewardedInterstitial { [reward] in
                    if let rewardLedger {
                        rewardLedger.grant(
                            source: .ad,
                            itemType: .gems,
                            amount: reward,
                            idempotencyKey: key
                        ) {
                            homeState.addGems(reward)
                            saveProgress()
                        }
                    } else {
                        homeState.addGems(reward)
                        saveProgress()
                    }
                }
                return didReward ? reward : 0
            },
            openDaily: {
                showDailyClaims = true
            },
            openDailyStreaks: {
                showDailyStreaks = true
            },
            openFreeSpin: {
                showFreeSpin = true
            },
            openMusic: {
                homeState.isMusicOn.toggle()
                saveProgress()
            },
            openChallenge: {
                showChallenge = true
            },
            openCreate: {
                showChallengeDesigner = true
            }
        )
    }
    
    private func updateHomeFromGameProgress() {
        // Capture values from MainActor-isolated properties
        let highestTile = gameStore.state.highestTile
        let highestTileStep = gameStore.state.highestTileStep
        let bestScoreAlpha = gameStore.state.scoreValue
        let gems = gameStore.coins
        
        // Also sync the journey highest tile
        journey.didReach(tile: highestTile)
        
        Task {
            do {
                // Update progress with game state
                let progress = try await progressCoordinator.apply({ p in
                    p.highestTile = max(p.highestTile, highestTile)
                    p.highestTileStep = max(p.highestTileStep, highestTileStep)
                    let currentAlpha = p.bestScoreAlpha ?? AlphaNumber(p.bestScore)
                    let updatedAlpha = bestScoreAlpha > currentAlpha ? bestScoreAlpha : currentAlpha
                    p.bestScoreAlpha = updatedAlpha
                    p.bestScore = updatedAlpha.toInt()
                    p.gems = gems
                    p.gamesPlayed += 1
                    p.lastUpdatedAt = Date()
                }, userIsSignedIn: false)
                
                // Update home state
                await MainActor.run {
                    homeState.apply(progress: progress, planner: planner)
                    // Ensure journey is synced
                    journey.didReach(tile: progress.highestTile)
                    // Update rank from UserLeaderboardData (based on milestone)
                    homeState.rank = UserLeaderboardData.globalRank
                }
            } catch {
                print("Failed to update progress from game: \(error)")
            }
        }
    }
    
    private func loadProgressWithCoordinator() async {
        do {
            // Bootstrap or load existing progress
            let progress = try await progressCoordinator.bootstrap(userIsSignedIn: false)
            
            // Check if there's any saved game state
            let finalHighestTile: Int
            if progress.highestTile > 0 {
                finalHighestTile = progress.highestTile
            } else {
                let storage = UserDefaultsStorageService()
                if let savedData = await storage.load(slotId: "autosave") {
                    // Use the highest tile from the saved game
                    finalHighestTile = savedData.board.max { $0 < $1 } ?? 2
                } else {
                    // No saved state, start fresh
                    finalHighestTile = 2
                }
            }
            
            // Apply to home state
            await MainActor.run {
                homeState.apply(progress: progress, planner: planner)
                // Only update coins if gameStore has no coins (fresh start)
                // Otherwise keep the current gameStore value as it's more recent
                if gameStore.coins == 0 && progress.gems > 0 {
                    gameStore.coins = progress.gems
                    print("📱 Restored gems from progress: \(progress.gems)")
                } else if gameStore.coins != progress.gems {
                    print("⚠️ Gem sync issue - GameStore: \(gameStore.coins), Progress: \(progress.gems). Keeping GameStore value.")
                    // Update progress to match current gameStore value
                    let currentGems = gameStore.coins
                    Task {
                        try? await progressCoordinator.apply({ progress in
                            progress.gems = currentGems
                        }, userIsSignedIn: false)
                    }
                }
                
                // CRITICAL: Sync JourneyKit with the actual highest tile
                journey.didReach(tile: finalHighestTile)
                if progress.highestTile == 0 && finalHighestTile > 2 {
                    homeState.highestTile = finalHighestTile
                }

                // Update rank from UserLeaderboardData (based on milestone in UserDefaults)
                homeState.rank = UserLeaderboardData.globalRank

                hasLoadedInitialState = true
            }
        } catch {
            print("Failed to load progress: \(error)")
            // Use defaults if loading fails
            await MainActor.run {
                homeState.gems = 305
                homeState.highestTile = 2
                homeState.milestoneBelow = 0
                homeState.lockedMilestones = [1024, 2048]
                homeState.rank = UserLeaderboardData.globalRank
                journey.didReach(tile: 2)
                hasLoadedInitialState = true
            }
        }
    }
    
    @MainActor
    private func saveProgress() {
        // Capture values from MainActor-isolated properties
        let gems = homeState.gems
        let highestTile = homeState.highestTile
        let rank = homeState.rank
        let theme = homeState.isMusicOn ? homeState.themesLeftName.lowercased() : nil
        
        Task {
            do {
                // Save current state as progress
                let progress = try await progressCoordinator.apply({ p in
                    p.gems = gems
                    p.highestTile = highestTile
                    p.rank = rank
                    p.theme = theme
                    p.lastUpdatedAt = Date()
                }, userIsSignedIn: false)
                
                print("Progress saved: gems=\(progress.gems), highest=\(progress.highestTile)")
            } catch {
                print("Failed to save progress: \(error)")
            }
        }
    }
}

#if DEBUG
#Preview("Root Game") {
    GameUIScreenPreviewHost {
        RootGameView()
    }
}
#endif

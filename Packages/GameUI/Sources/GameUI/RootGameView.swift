import SwiftUI
import GameApp
import GameCore
import GameServices

/// Root view that manages the flow between Home and Game screens
public struct RootGameView: View {
    private let managesBackground: Bool
    @Environment(HomeState.self) private var homeState
    @Environment(\.gameStore) private var gameStore
    @Environment(\.tileJourney) private var journey
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
    @State private var leaderboardService = LeaderboardService()

    @Environment(DailyClaimsStore.self) private var dailyClaimsStore
    @Environment(\.backgroundThemeRegistry) private var backgroundThemeRegistry
    @Environment(\.currentBackgroundTheme) private var currentBackgroundTheme
    
    // Progress management
    private let planner: MilestonePlanner = PowerOfTwoPlanner()
    private let progressCoordinator: ProgressSyncCoordinator
    
    public init(managesBackground: Bool = true) {
        self.managesBackground = managesBackground
        let localStore = UserDefaultsProgressStore()
        let remoteStore: ProgressStore? = nil // TODO: Add CloudKit/Firebase store
        self.progressCoordinator = ProgressSyncCoordinator(
            local: localStore,
            remote: remoteStore,
            seed: .init(starterGems: 305, starterTheme: "beach")
        )
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
                    initialGems: homeState.gems,
                    onDismiss: {
                        // Only track challenge creation completion for newly created challenges
                        // (not for playing existing challenges from the challenge list)
                        if config.challengeId == nil {
                            // Pass the captured multiplier so the boost counts even if it expired during gameplay
                            gameStore.registerChallengeCreationCompleted(withCapturedMultiplier: capturedChallengeCreationMultiplier)
                        }
                        // Reset captured multiplier after use
                        capturedChallengeCreationMultiplier = 1
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPlayingCustomChallenge = false
                            customChallengeConfig = nil
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
                    .environment(\.leaderboardService, leaderboardService)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .task {
                        // Load saved progress when Home appears
                        await loadProgressWithCoordinator()
                        // Update daily claims availability
                        dailyClaimsStore.updateAvailability()
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
    }
    
    @MainActor
    private func makeHomeActions() -> HomeActions {
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
                print("Open Shop")
                showShop = true
            },
            buyGems: {
                print("Buy Gems")
                homeState.addGems(120) // Demo: add some gems
                saveProgress()
            },
            watchAd: {
                print("Watch Ad")
                // Simulate ad watch
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                let reward = 68
                homeState.addGems(reward)
                saveProgress()
                return reward
            },
            openDaily: {
                print("Open Daily")
                showDailyClaims = true
            },
            openFreeSpin: {
                showFreeSpin = true
            },
            openMusic: {
                print("Toggle Music")
                homeState.isMusicOn.toggle()
                saveProgress()
            },
            openChallenge: {
                showChallenge = true
            },
            openCreate: {
                showChallengeDesigner = true
            },
            openProfile: {
                print("Open Profile")
                // TODO: Implement profile
            },
            openAchievements: {
                print("Open Achievements")
                // TODO: Implement achievements
            },
            openLeaderboard: {
                print("Open Leaderboard")
                // TODO: Implement leaderboard
            },
            openSettings: {
                print("Open Settings")
                // TODO: Implement settings
            },
            openThemeLeft: {
                print("Select theme: \(homeState.themesLeftName)")
                // TODO: Apply theme
            },
            openThemeRight: {
                print("Select theme: \(homeState.themesRightName)")
                // TODO: Apply theme
            },
            openSaleOffer: {
                print("Open Sale Offer")
                // TODO: Implement sale offer
            }
        )
    }
    
    private func updateHomeFromGameProgress() {
        // Capture values from MainActor-isolated properties
        let highestTile = gameStore.state.highestTile
        let bestScoreAlpha = gameStore.state.scoreValue
        let gems = gameStore.coins
        
        // Also sync the journey highest tile
        journey.didReach(tile: highestTile)
        
        Task {
            do {
                // Update progress with game state
                let progress = try await progressCoordinator.apply({ p in
                    p.highestTile = max(p.highestTile, highestTile)
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

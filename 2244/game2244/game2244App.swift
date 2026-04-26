//
//  game2244App.swift
//  game2244
//
//  Created by Angel Henderson on 8/11/25.
//

import SwiftUI
import GameApp
import GameServices
import GameUI
import GameCore
import GameKit
import FirebaseCore

@main
struct game2244App: App {
    // Register AppDelegate for SwiftUI
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        configureNavigationBarAppearance()
    }

    private func configureNavigationBarAppearance() {
        // Configure Avenir Next for navigation bar titles
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()

        // Large title (used when .navigationBarTitleDisplayMode(.large))
        if let largeTitleFont = UIFont(name: "AvenirNext-Bold", size: 34) {
            appearance.largeTitleTextAttributes = [.font: largeTitleFont]
        }

        // Inline title (used when .navigationBarTitleDisplayMode(.inline))
        if let titleFont = UIFont(name: "AvenirNext-DemiBold", size: 17) {
            appearance.titleTextAttributes = [.font: titleFont]
        }

        // Apply to all navigation bars
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    @State private var gameStore = GameStore()
    @State private var homeState = HomeState()
    @State private var purchaseService = PurchaseService()
    @State private var adService = DummyAdService()
    @State private var hapticsService = HapticsService()
    @State private var audioService = LiveAudioService()
    @State private var gameCenterService = DefaultGameCenterService()
    @State private var themeRegistry = ThemeRegistry.Default
    @State private var backgroundThemeRegistry = BackgroundThemeRegistry.Default
    @AppStorage("selectedThemeId") private var selectedThemeId: String = "raised-3d-square"
    @AppStorage("selectedBackgroundThemeId") private var selectedBackgroundThemeId: String = "city_1"
    @AppStorage("useGlassPreview") private var useGlassPreview: Bool = true
    @State private var isPlaying: Bool = false
    @State private var storageService = UserDefaultsStorageService()
    @State private var achievementStore = AchievementStore()
    @State private var dailyClaimsStore = DailyClaimsStore()
    @State private var gemWallet = GemWallet()
    @State private var shopStore: ShopStore? = nil
    @State private var challengeStore = ChallengeStore()
    @State private var challengeDesignerStore = ChallengeDesignerStore()
    @State private var spinWheelState = SpinWheelState()
    @State private var dailyQuestStore = DailyQuestStore()

    // First-launch tutorial tracking
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial: Bool = false
    @State private var isShowingTutorial: Bool = false

    private let planner: MilestonePlanner = PowerOfTwoPlanner()
    
    
    private var currentBackgroundTheme: BackgroundTheme {
        backgroundThemeRegistry.theme(for: selectedBackgroundThemeId)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                HomeBackgroundLayer(theme: currentBackgroundTheme)
                    .ignoresSafeArea()
                    .zIndex(0)

                RootGameView(managesBackground: false)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GemsDidChange"))) { notification in
                if let newBalance = notification.userInfo?["newBalance"] as? Int {
                    homeState.gems = newBalance
                    gameStore.coins = newBalance
                }
            }
                .environment(\.gameStore, gameStore)
                .environment(\.purchaseService, purchaseService)
                .environment(\.adService, adService)
                .environment(\.hapticsService, hapticsService)
                .environment(\.audio, audioService)
                .environment(\.gameCenter, gameCenterService)
                .environment(\.storage, storageService)
                .environment(\.currentTheme, themeRegistry.descriptor(for: selectedThemeId))
                .environment(\.backgroundThemeRegistry, backgroundThemeRegistry)
                .environment(\.currentBackgroundTheme, backgroundThemeRegistry.theme(for: selectedBackgroundThemeId))
                .environment(\.tileJourney, gameStore.journey)
                // TODO(Batch C): swap `.mock` for `.firebase(LeaderboardService())` or `.gameCenter()`
                // once the real leaderboard backend is wired. `.mock` returns synthetic data;
                // `submitScore` is a silent no-op. `.empty` is available for a truly blank state.
                .environment(\.leaderboardClient, .mock)
                .environment(homeState)
                .environment(achievementStore)
                .environment(dailyClaimsStore)
                .environment(dailyQuestStore)
                .environment(
                    \.shopStore,
                    shopStore ?? ShopStore(
                        journeyStore: gameStore.journey,
                        purchaseService: purchaseService,
                        gemWallet: gemWallet
                    )
                )
                .environment(\.challengeStore, challengeStore)
                .environment(\.challengeDesignerStore, challengeDesignerStore)
                .environment(\.spinWheelState, spinWheelState)
                .task {
                    gemWallet.attach(gameStore: gameStore, homeState: homeState)
                    gemWallet.bootstrapFromLocal()
                    gameStore.spinWheelState = spinWheelState
                    
                    FirebaseService.shared.initialize()
                    if FirebaseApp.app() != nil {
                        try? await FirebaseService.shared.signInAnonymously()
                        await gemWallet.startCloudSync()
                    } else {
                        #if DEBUG
                        print("⚠️ Firebase not configured; skipping gem cloud sync.")
                        #endif
                    }
                    
                    // Initialize shop store
                    shopStore = ShopStore(
                        journeyStore: gameStore.journey,
                        purchaseService: purchaseService,
                        gemWallet: gemWallet
                    )
                    
                    // Suppress simulator-specific warnings in console
                    if ProcessInfo.processInfo.environment.keys.contains("SIMULATOR_DEVICE_NAME") {
                        // Running in simulator - some warnings are expected
                        print("🧪 Running in iOS Simulator - some system warnings are expected")
                    }
                    
                    // Honor ad-free state persisted
                    if UserDefaults.standard.bool(forKey: "isAdFreePurchased") {
                        adService.setAdFree(true)
                    }
                    _ = await gameCenterService.authenticate()
                    
                    // Load achievements
                    try? achievementStore.loadCatalogFromBundle(named: "2244_achievements")
                    
                    // Setup Game Center (place access point away from Rank button)
                    GameCenterManager.shared.configureAccessPoint(active: true, location: .topTrailing)
                    #if canImport(UIKit)
                    GameCenterManager.shared.authenticateIfNeeded {
                        UIApplication.shared.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .first?.windows.first?.rootViewController
                    }
                    #endif
                    await achievementStore.syncWithGameCenter()
                    
                    // Enable audio by default if not set
                    if UserDefaults.standard.object(forKey: "musicEnabled") == nil {
                        await audioService.setMusicEnabled(true)
                    }
                    if UserDefaults.standard.object(forKey: "sfxEnabled") == nil {
                        await audioService.setSfxEnabled(true)
                    }
                    
                    let applyRewards: @MainActor @Sendable (AchievementDef.Rewards) -> Void = { rewards in
                        // Gems (also granted directly via AchievementStore, but keep for wallet sync)
                        if let gems = rewards.gems, gems > 0 {
                            gemWallet.deposit(gems, source: .achievement)
                        }
                        
                        // Power-ups
                        if let hammers = rewards.hammers, hammers > 0 {
                            gameStore.addPowerUp("hammer", count: hammers)
                        }
                        if let magnets = rewards.magnets, magnets > 0 {
                            gameStore.addPowerUp("magnet", count: magnets)
                        }
                        if let swaps = rewards.swaps, swaps > 0 {
                            gameStore.addPowerUp("swap", count: swaps)
                        }
                        
                        // Spins & multipliers
                        if let spins = rewards.spins, spins > 0 {
                            spinWheelState.addBonusSpins(spins)
                        }
                        if let boost2x = rewards.boost2x, boost2x > 0 {
                            spinWheelState.addMultiplier(.twoX, count: boost2x)
                        }
                        if let boost3x = rewards.boost3x, boost3x > 0 {
                            spinWheelState.addMultiplier(.threeX, count: boost3x)
                        }
                        if let boost4x = rewards.boost4x, boost4x > 0 {
                            spinWheelState.addMultiplier(.fourX, count: boost4x)
                        }
                    }
                    
                    // Setup achievement evaluator with reward handler
                    achievementStore.onReward = applyRewards

                    let evaluator = AchievementEvaluator(achievementStore: achievementStore)
                    gameStore.achievementEvaluator = evaluator

                    // Wire daily quest store into evaluator (same task = guaranteed order)
                    evaluator.dailyQuestStore = dailyQuestStore
                    dailyQuestStore.setHighestTileStep(gameStore.state.highestTileStep)
                    dailyQuestStore.onReward = { rewards in
                        applyRewards(rewards)
                        homeState.addGems(0) // trigger UI refresh
                    }

                    // Start tracking playtime for the initial session
                    evaluator.onGameStart(state: gameStore.state)

                    // Setup daily claims reward handler
                    dailyClaimsStore.onReward = applyRewards
                    
                    // Load daily claims catalogs
                    await dailyClaimsStore.loadCatalogs()

                    // One-time fix for corrupted score data from sandboxed challenges
                    if !UserDefaults.standard.bool(forKey: "hasResetCorruptedScore_v1") {
                        gameStore.resetCorruptedScoreData()
                        UserDefaults.standard.set(true, forKey: "hasResetCorruptedScore_v1")
                    }

                    // Load initial progress
                    loadInitialProgress()

                    // Show tutorial on first launch (skip for debug/Xcode builds)
                    #if !DEBUG
                    if !hasCompletedTutorial {
                        await MainActor.run {
                            isShowingTutorial = true
                        }
                    }
                    #endif
                }
                .fullScreenCover(isPresented: $isShowingTutorial) {
                    HowToPlayView(onComplete: {
                        hasCompletedTutorial = true
                        isShowingTutorial = false
                    })
                }
        }
    }
    
    private func loadInitialProgress() {
        let defaults = UserDefaults.standard
        
        // Load gems
        if defaults.object(forKey: "coins") != nil {
            let gems = defaults.integer(forKey: "coins")
            homeState.gems = gems
            gameStore.coins = gems
        }
        
        // Load highest tile and calculate milestones
        let highest = gameStore.state.highestTile
        let highestStep = gameStore.state.highestTileStep
        if highest > 0 {
            let milestones = planner.milestones(for: highest)
            homeState.highestTile = milestones.current
            homeState.highestTileStep = highestStep
            homeState.milestoneBelow = milestones.below ?? 1024
            homeState.lockedMilestones = milestones.above
        }
    }
}

// Extension to handle platform-specific presentation
extension View {
    @ViewBuilder
    func gamePresentation<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        self.fullScreenCover(isPresented: isPresented, content: content)
        #else
        self.sheet(isPresented: isPresented, content: content)
        #endif
    }
}

#Preview("HybridGameScreen") {
    // Local services for preview
    let gameStore = GameStore()
    let adService = DummyAdService()
    let haptics = HapticsService()
    let gameCenter = DefaultGameCenterService()
    let storage = UserDefaultsStorageService()
    let themeRegistry = ThemeRegistry.Default
    // Note: Rely on default EnvironmentKeys for backgroundThemeRegistry and audio if available.
    
    return HybridGameScreen(isPlayingDismiss: {})
        .environment(\.gameStore, gameStore)
        .environment(\.adService, adService)
        .environment(\.hapticsService, haptics)
        .environment(\.gameCenter, gameCenter)
        .environment(\.storage, storage)
        .environment(\.currentTheme, themeRegistry.descriptor(for: "raised-3d-square"))
        .environment(\.tileJourney, gameStore.journey)
        .environment(\.leaderboardClient, .mock)
}

#Preview("HomeView") {
    // Local services for preview
    let gameStore = GameStore()
    let homeState = HomeState()
    let purchaseService = PurchaseService()
    let adService = DummyAdService()
    let haptics = HapticsService()
    let gameCenter = DefaultGameCenterService()
    let storage = UserDefaultsStorageService()
    let themeRegistry = ThemeRegistry.Default
    
    // Simple HomeActions for preview
    let actions = HomeActions(
        play: {},
        openShop: {},
        buyGems: {},
        watchAd: { 50 },
        openDaily: {},
        openFreeSpin: {},
        openMusic: {},
        openChallenge: {},
        openCreate: {},
        openProfile: {},
        openAchievements: {},
        openLeaderboard: {},
        openSettings: {},
        openThemeLeft: {},
        openThemeRight: {},
        openSaleOffer: {}
    )
    
    return HomeView()
        .environment(homeState)
        .environment(\.homeActions, actions)
        .environment(\.gameStore, gameStore)
        .environment(\.purchaseService, purchaseService)
        .environment(\.adService, adService)
        .environment(\.hapticsService, haptics)
        .environment(\.gameCenter, gameCenter)
        .environment(\.storage, storage)
        .environment(\.currentTheme, themeRegistry.descriptor(for: "raised-3d-square"))
        .environment(\.tileJourney, gameStore.journey)
        .environment(\.leaderboardClient, .gameCenter())
}

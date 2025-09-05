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

@main
struct game2244App: App {
    @State private var gameStore = GameStore()
    @State private var homeState = HomeState()
    @State private var purchaseService = PurchaseService()
    @State private var adService = DummyAdService()
    @State private var hapticsService = HapticsService()
    @State private var gameCenterService = DefaultGameCenterService()
    @State private var themeRegistry = ThemeRegistry.Default
    @AppStorage("selectedThemeId") private var selectedThemeId: String = "raised-3d-square"
    @AppStorage("useGlassPreview") private var useGlassPreview: Bool = true
    @State private var isPlaying: Bool = false
    @State private var storageService = UserDefaultsStorageService()
    @State private var achievementStore = AchievementStore()
    @State private var dailyClaimsStore = DailyClaimsStore()
    @State private var shopStore: ShopStore? = nil
    
    private let planner: MilestonePlanner = PowerOfTwoPlanner()
    
    var body: some Scene {
        WindowGroup {
            RootGameView()
                .environment(\.gameStore, gameStore)
                .environment(\.purchaseService, purchaseService)
                .environment(\.adService, adService)
                .environment(\.hapticsService, hapticsService)
                .environment(\.gameCenter, gameCenterService)
                .environment(\.storage, storageService)
                .environment(\.currentTheme, themeRegistry.descriptor(for: selectedThemeId))
                .environment(\.tileJourney, gameStore.journey)
                .environment(\.leaderboardClient, LeaderboardClient.gameCenter())
                .environment(achievementStore)
                .environment(dailyClaimsStore)
                .environment(\.shopStore, shopStore ?? ShopStore(journeyStore: gameStore.journey))
                .task {
                    // Initialize shop store
                    shopStore = ShopStore(journeyStore: gameStore.journey)
                    
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
                    
                    // Setup Game Center
                    GameCenterManager.shared.configureAccessPoint(active: true, location: .topLeading)
                    GameCenterManager.shared.authenticateIfNeeded {
                        UIApplication.shared.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .first?.windows.first?.rootViewController
                    }
                    await achievementStore.syncWithGameCenter()
                    
                    // Setup achievement evaluator with reward handler
                    let evaluator = AchievementEvaluator(achievementStore: achievementStore)
                    evaluator.onReward = { rewards in
                        // Award gems
                        if let gems = rewards.gems, gems > 0 {
                            gameStore.coins += gems
                            homeState.gems += gems
                        }
                        
                        // Award powerups (simplified - you may want to track these separately)
                        if let hammers = rewards.hammers, hammers > 0 {
                            gameStore.addPowerUp("hammer", count: hammers)
                        }
                        if let magnets = rewards.magnets, magnets > 0 {
                            gameStore.addPowerUp("magnet", count: magnets)
                        }
                        // Note: spins would need separate tracking for wheel of fortune feature
                    }
                    gameStore.achievementEvaluator = evaluator
                    
                    // Setup daily claims reward handler
                    dailyClaimsStore.onReward = { rewards in
                        // Award gems
                        if let gems = rewards.gems, gems > 0 {
                            gameStore.coins += gems
                            homeState.gems += gems
                        }
                        
                        // Award powerups
                        if let hammers = rewards.hammers, hammers > 0 {
                            gameStore.addPowerUp("hammer", count: hammers)
                        }
                        if let magnets = rewards.magnets, magnets > 0 {
                            gameStore.addPowerUp("magnet", count: magnets)
                        }
                        // Note: spins would need separate tracking for wheel of fortune feature
                    }
                    
                    // Load daily claims catalogs
                    await dailyClaimsStore.loadCatalogs()
                    
                    // Load initial progress
                    loadInitialProgress()
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
        if highest > 0 {
            let milestones = planner.milestones(for: highest)
            homeState.highestTile = milestones.current
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
        .environment(\.leaderboardClient, .noop)
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
        .environment(\.leaderboardClient, .noop)
}

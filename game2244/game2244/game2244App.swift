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
                .task {
                    // Honor ad-free state persisted
                    if UserDefaults.standard.bool(forKey: "isAdFreePurchased") {
                        adService.setAdFree(true)
                    }
                    _ = await gameCenterService.authenticate()
                    
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

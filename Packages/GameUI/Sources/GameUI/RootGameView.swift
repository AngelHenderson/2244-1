import SwiftUI
import GameApp
import GameCore

/// Root view that manages the flow between Home and Game screens
public struct RootGameView: View {
    @State private var homeState = HomeState()
    @State private var gameStore = GameStore()
    @State private var isPlaying = false
    
    // Progress management
    private let planner: MilestonePlanner = PowerOfTwoPlanner()
    private let progressCoordinator: ProgressSyncCoordinator
    
    public init() {
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
            if isPlaying {
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
                HomeView()
                    .environment(homeState)
                    .environment(\.homeActions, makeHomeActions())
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .task {
                        // Load saved progress when Home appears
                        await loadProgressWithCoordinator()
                    }
            }
        }
    }
    
    @MainActor
    private func makeHomeActions() -> HomeActions {
        HomeActions(
            play: {
                // Start playing
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPlaying = true
                }
            },
            openShop: {
                print("Open Shop")
                // TODO: Implement shop sheet
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
                // TODO: Implement daily rewards
            },
            openFreeSpin: {
                print("Open Free Spin")
                // TODO: Implement spin wheel
            },
            openMusic: {
                print("Toggle Music")
                homeState.isMusicOn.toggle()
                saveProgress()
            },
            openChallenge: {
                print("Open Challenge (locked)")
            },
            openCreate: {
                print("Open Create (locked)")
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
        let bestScore = gameStore.state.score
        let gems = gameStore.coins
        
        Task {
            do {
                // Update progress with game state
                let progress = try await progressCoordinator.apply({ p in
                    p.highestTile = max(p.highestTile, highestTile)
                    p.bestScore = max(p.bestScore, bestScore)
                    p.gems = gems
                    p.gamesPlayed += 1
                    p.lastUpdatedAt = Date()
                }, userIsSignedIn: false)
                
                // Update home state
                await MainActor.run {
                    homeState.apply(progress: progress, planner: planner)
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
            
            // Apply to home state
            await MainActor.run {
                homeState.apply(progress: progress, planner: planner)
                gameStore.coins = progress.gems
            }
        } catch {
            print("Failed to load progress: \(error)")
            // Use defaults if loading fails
            await MainActor.run {
                homeState.gems = 305
                homeState.highestTile = 2048
                homeState.milestoneBelow = 1024
                homeState.lockedMilestones = [4096, 8192]
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

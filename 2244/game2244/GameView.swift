import SwiftUI
import GameUI
import GameApp
import GameServices
import GameCore
#if os(iOS)
import StoreKit
#endif

struct GameView: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.purchaseService) private var purchaseService
    @Environment(\.adService) private var adService
    @Environment(\.storage) private var storage
    @Environment(\.gameCenter) private var gameCenter
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("colorBlindMode") private var colorBlindMode = false
    @AppStorage("selectedThemeId") private var selectedThemeId: String = "raised-3d-square"
    @AppStorage("selectedBackgroundId") private var selectedBackgroundId: String = "city_1"
    @State private var hasSubmittedForCurrentGame = false
    @State private var showGameOverAlert = false
    
        var body: some View {
        HybridGameScreen(isPlayingDismiss: nil)
        .environment(\.colorBlindMode, colorBlindMode)
        .environment(\.backgroundTheme, BackgroundThemeRegistry.Default.theme(for: selectedBackgroundId))
        .environment(\.backgroundThemeRegistry, BackgroundThemeRegistry.Default)
            .task {
                await adService.showBanner()
                // Attempt to restore last autosave on first launch of this scene
                _ = await gameStore.load(from: "autosave", using: storage)
                // Initialize comprehensive session tracking
                gameStore.initializeSessionTracking()
            }
            .onAppear {
                Theme.colorBlindMode = colorBlindMode
            }
            .onChange(of: colorBlindMode) { _, newValue in
                Theme.colorBlindMode = newValue
            }
            // Enhanced auto-save with comprehensive session data
            .onChange(of: gameStore.state.moves) { _, _ in
                // Use comprehensive session tracking auto-save
                gameStore.saveProgressImmediately(newTile: nil)
                // Also save to autosave slot for compatibility
                Task { await gameStore.save(to: "autosave", using: storage, theme: selectedThemeId) }
            }
            // Enhanced auto-save on app going to background/inactive
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    // Use comprehensive session tracking auto-save
                    gameStore.saveProgressImmediately(newTile: nil)
                    // Also save to autosave slot for compatibility
                    Task { await gameStore.save(to: "autosave", using: storage, theme: selectedThemeId) }
                }
            }
            .onChange(of: gameStore.state.isGameOver) { _, isOver in
                if isOver { 
                    showGameOverAlert = true
                    Task {
                        // Submit best score when game over
                        await submitBestScoreIfNeeded()
                    }
                }
            }
            .alert("No moves left", isPresented: $showGameOverAlert) {
                Button("New Game") {
                    hasSubmittedForCurrentGame = false
                    gameStore.resetGame()
                }
                Button("Dismiss", role: .cancel) { }
            } message: {
                Text("Try Shuffle or start a new run.")
            }
    }
}

extension GameView {
    @MainActor
    private func submitBestScoreIfNeeded() async {
        guard !hasSubmittedForCurrentGame else { return }
        let current = gameStore.state.score
        let storedBest = await storage.bestScore()
        let scoreToSubmit = max(current, storedBest)
        do {
            try await gameCenter.submit(score: scoreToSubmit, leaderboard: "main")
            hasSubmittedForCurrentGame = true
        } catch {
            // Ignore for no-op default; future implementations can handle errors
        }
    }
}




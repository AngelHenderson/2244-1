import SwiftUI
import GlassPreview

// MARK: - Integration Example
// This file demonstrates how to integrate the Glass Preview Row feature
// into an existing 2244-style game app.

/// Example integration of Glass Preview into a main game view
struct MainGameWithGlassPreview: View {
    @State private var showGlassPreview = false
    @State private var gameMode: GameMode = .classic
    
    enum GameMode: String, CaseIterable {
        case classic = "Classic"
        case glassPreview = "Glass Preview"
        
        var displayName: String { rawValue }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Game mode selector
                Picker("Game Mode", selection: $gameMode) {
                    ForEach(GameMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Game view based on selected mode
                Group {
                    switch gameMode {
                    case .classic:
                        ClassicGameView()
                    case .glassPreview:
                        GlassPreview.gameView(
                            config: .balanced
                        )
                    }
                }
                
                Spacer()
            }
            .navigationTitle("2244 Game")
            .background(Color(hex: "020617").ignoresSafeArea())
        }
    }
}

/// Placeholder for existing classic game view
struct ClassicGameView: View {
    var body: some View {
        VStack {
            Text("Classic 2244 Game")
                .font(.title)
                .foregroundColor(.white)
            
            Text("Your existing game implementation goes here")
                .foregroundColor(.white.opacity(0.7))
            
            // This would be your existing game grid, HUD, etc.
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 400)
                .overlay(
                    Text("Game Board")
                        .foregroundColor(.white)
                )
        }
        .padding()
    }
}

// MARK: - Advanced Integration Examples

/// Example showing custom configuration
struct CustomGlassPreviewGame: View {
    var body: some View {
        GlassPreview.gameView(
            cols: 6,  // Wider board
            rows: 10, // Taller board
            seed: 42, // Fixed seed for consistent experience
            config: GlassGameStore.Config(
                giftWeights: [
                    .hammer: 40,   // More hammers
                    .swap: 30,     // More swaps
                    .magnet: 20,   // Some magnets
                    .shuffle: 10,  // Fewer shuffles
                    .undo: 0,      // No undo
                    .bomb: 0       // No bombs
                ],
                giftOnAutoDrop: true, // Award gifts even on auto-drop
                requireDirectBelowInChain: false, // More lenient chain rules
                backgroundColorHex: "#001122", // Custom background color
                spawnWeights: [2: 0.6, 4: 0.3, 8: 0.1] // Custom tile spawn rates
            )
        )
    }
}

/// Example showing how to create a custom game store for advanced integration
struct AdvancedGlassPreviewIntegration: View {
    @State private var gameStore = GlassPreview.gameStore(config: .generous)
    @State private var showStats = false
    
    var body: some View {
        VStack {
            // Custom HUD
            HStack {
                VStack(alignment: .leading) {
                    Text("Score: \(gameStore.score)")
                    Text("Moves: \(gameStore.moves)")
                    Text("Power-ups: \(gameStore.powerups.values.reduce(0, +))")
                }
                .foregroundColor(.white)
                
                Spacer()
                
                Button("Stats") {
                    showStats.toggle()
                }
                .foregroundColor(.blue)
            }
            .padding()
            
            // Glass game view with custom store
            GlassGameView(gameStore: gameStore)
            
            // Custom controls
            HStack {
                Button("New Game") {
                    gameStore = GlassPreview.gameStore(
                        seed: UInt64(Date().timeIntervalSince1970),
                        config: .generous
                    )
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Spacer()
                
                if gameStore.isGameOver {
                    Button("Restart") {
                        gameStore = GlassPreview.gameStore(
                            seed: gameStore.sessionSeed + 1,
                            config: gameStore.config
                        )
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .background(Color(hex: "020617").ignoresSafeArea())
        .sheet(isPresented: $showStats) {
            StatsView(gameStore: gameStore)
        }
    }
}

/// Custom stats view showing analytics
struct StatsView: View {
    let gameStore: GlassGameStore
    
    var body: some View {
        NavigationView {
            List {
                Section("Game Stats") {
                    HStack {
                        Text("Score")
                        Spacer()
                        Text("\(gameStore.score)")
                    }
                    
                    HStack {
                        Text("Moves")
                        Spacer()
                        Text("\(gameStore.moves)")
                    }
                    
                    HStack {
                        Text("Session Seed")
                        Spacer()
                        Text("\(gameStore.sessionSeed)")
                            .font(.caption)
                    }
                }
                
                Section("Power-ups") {
                    ForEach(PowerUp.allCases, id: \.self) { powerUp in
                        HStack {
                            Text(powerUp.rawValue.capitalized)
                            Spacer()
                            Text("\(gameStore.powerups[powerUp] ?? 0)")
                        }
                    }
                }
                
                Section("Analytics Events") {
                    ForEach(gameStore.analyticsEvents.suffix(10).indices, id: \.self) { index in
                        let event = gameStore.analyticsEvents[gameStore.analyticsEvents.count - 10 + index]
                        VStack(alignment: .leading) {
                            Text(event.type)
                                .font(.headline)
                            Text(event.parameters.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Game Stats")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Demo and Testing Views

/// Demo view showing all glass preview features
struct GlassPreviewShowcase: View {
    var body: some View {
        TabView {
            // Basic demo
            GlassPreviewDemo()
                .tabItem {
                    Image(systemName: "gamecontroller")
                    Text("Demo")
                }
            
            // Balanced gameplay
            GlassPreview.gameView(config: .balanced)
                .tabItem {
                    Image(systemName: "scale.3d")
                    Text("Balanced")
                }
            
            // Generous gameplay
            GlassPreview.gameView(config: .generous)
                .tabItem {
                    Image(systemName: "gift")
                    Text("Generous")
                }
            
            // Challenging gameplay
            GlassPreview.gameView(config: .challenging)
                .tabItem {
                    Image(systemName: "flame")
                    Text("Challenge")
                }
            
            // Custom integration
            AdvancedGlassPreviewIntegration()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Advanced")
                }
        }
    }
}

// MARK: - Migration Helper

/// Helper for migrating from existing game state to Glass Preview
struct GlassPreviewMigration {
    /// Convert existing game board to Glass Preview format
    static func convertLegacyBoard(_ legacyBoard: [[Int?]]) -> ([[Int?]], GlassGameStore) {
        let (convertedBoard, score, moves) = GlassGameStore().toLegacyGameState()
        let glassStore = GlassGameStore.fromLegacyGameState(
            board: legacyBoard,
            score: 0,
            moves: 0,
            config: .balanced
        )
        return (convertedBoard, glassStore)
    }
    
    /// Create Glass Preview game with similar difficulty to existing game
    static func createSimilarDifficulty(
        existingHighScore: Int,
        existingLevel: Int
    ) -> GlassGameStore.Config {
        // Adjust difficulty based on existing progress
        if existingHighScore > 100000 {
            return .challenging
        } else if existingHighScore > 10000 {
            return .balanced
        } else {
            return .generous
        }
    }
}

// MARK: - Preview Provider

#Preview("Glass Preview Showcase") {
    GlassPreviewShowcase()
}

#Preview("Main Game Integration") {
    MainGameWithGlassPreview()
}

#Preview("Advanced Integration") {
    AdvancedGlassPreviewIntegration()
}

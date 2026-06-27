import SwiftUI

/// Debug HUD for testing glass preview functionality
public struct GlassDebugHUD: View {
    let gameStore: GlassGameStore
    @Binding var isVisible: Bool
    @State private var selectedSeed: String = ""
    @State private var showAnalytics = false
    
    public init(gameStore: GlassGameStore, isVisible: Binding<Bool>) {
        self.gameStore = gameStore
        self._isVisible = isVisible
        self._selectedSeed = State(initialValue: String(gameStore.sessionSeed))
    }
    
    public var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    isVisible = false
                }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    
                    Divider()
                    
                    gameStateSection
                    
                    previewQueuesSection
                    
                    powerupsSection
                    
                    debugActionsSection
                    
                    configurationSection
                    
                    analyticsSection
                    
                    rawDebugInfoSection
                }
                .padding()
            }
            .frame(maxWidth: 400)
            .background(Color.black.opacity(0.9))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Text("Glass Preview Debug")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            Button("Close") {
                isVisible = false
            }
            .foregroundColor(.blue)
        }
    }
    
    @ViewBuilder
    private var gameStateSection: some View {
        DebugSection(title: "Game State") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Session Seed: \(gameStore.sessionSeed)")
                Text("Score: \(gameStore.score)")
                Text("Moves: \(gameStore.moves)")
                Text("Game Over: \(gameStore.isGameOver ? "Yes" : "No")")
                Text("Current Chain: \(gameStore.currentChain.map { "(\($0.col),\($0.row))" }.joined(separator: " → "))")
                if let validation = gameStore.chainValidation {
                    Text("Validation: \(validation)")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    @ViewBuilder
    private var previewQueuesSection: some View {
        DebugSection(title: "Preview Queues") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<gameStore.cols, id: \.self) { col in
                    let queue = gameStore.preview[col]
                    Text("Col \(col): \(queue.map { $0.isGlass ? "G\($0.value)" : "\($0.value)" }.joined(separator: ", "))")
                        .font(.caption)
                }
            }
        }
    }
    
    @ViewBuilder
    private var powerupsSection: some View {
        DebugSection(title: "Power-ups") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(PowerUp.allCases, id: \.self) { powerUp in
                    let count = gameStore.powerups[powerUp] ?? 0
                    Text("\(powerUp.rawValue.capitalized): \(count)")
                }
            }
        }
    }
    
    @ViewBuilder
    private var debugActionsSection: some View {
        DebugSection(title: "Debug Actions") {
            VStack(spacing: 12) {
                Button("Force All Glass") {
                    gameStore.forceAllGlass()
                }
                .debugButtonStyle()
                
                Button("Award Random Power-up") {
                    // gameStore.debugAwardPowerUp()
                }
                .debugButtonStyle()
                
                HStack {
                    TextField("Custom Seed", text: $selectedSeed)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Apply") {
                        // gameStore.restart(with: seed)
                    }
                    .debugButtonStyle()
                }
            }
        }
    }
    
    @ViewBuilder
    private var configurationSection: some View {
        DebugSection(title: "Configuration") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Background: \(gameStore.config.backgroundColorHex)")
                Text("Gift on Auto-drop: \(gameStore.config.giftOnAutoDrop ? "Yes" : "No")")
                Text("Require Direct Below: \(gameStore.config.requireDirectBelowInChain ? "Yes" : "No")")
                
                Text("Gift Weights:")
                    .fontWeight(.semibold)
                ForEach(PowerUp.allCases, id: \.self) { powerUp in
                    let weight = gameStore.config.giftWeights[powerUp] ?? 0
                    Text("  \(powerUp.rawValue): \(weight)%")
                        .font(.caption)
                }
            }
        }
    }
    
    @ViewBuilder
    private var analyticsSection: some View {
        DebugSection(title: "Analytics") {
            VStack(spacing: 8) {
                Button("Show Events (\(gameStore.analyticsEvents.count))") {
                    showAnalytics.toggle()
                }
                .debugButtonStyle()
                
                if showAnalytics {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(gameStore.analyticsEvents.suffix(20).enumerated()), id: \.offset) { offset, event in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.type)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    Text(String(describing: event.parameters))
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                .padding(4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
    }
    
    @ViewBuilder
    private var rawDebugInfoSection: some View {
        DebugSection(title: "Raw Debug Info") {
            Text(gameStore.debugInfo())
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

/// Reusable debug section
struct DebugSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            content
                .foregroundColor(.white.opacity(0.9))
                .font(.caption)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Debug button style
extension View {
    func debugButtonStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(6)
            .font(.caption)
    }
}

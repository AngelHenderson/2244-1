import SwiftUI
import GameApp

struct LeaderboardView: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.storage) private var storage
    @Environment(\.gameCenter) private var gameCenter
    @Environment(\.dismiss) private var dismiss
    @State private var best: Int = 0
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Current Game") {
                    HStack { Text("Score"); Spacer(); Text("\(gameStore.state.score)").monospacedDigit() }
                    HStack { Text("Best Local"); Spacer(); Text("\(best)").monospacedDigit() }
                }
                Section("Actions") {
                    Button(action: submitToGameCenter) {
                        HStack { Image(systemName: "trophy.fill"); Text("Submit to Game Center") }
                    }.disabled(isSubmitting)
                }
            }
            .navigationTitle("Leaderboard")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .task { best = await storage.bestScore() }
    }
    private func submitToGameCenter() {
        Task { @MainActor in
            isSubmitting = true
            _ = await gameCenter.authenticate()
            try? await gameCenter.submit(score: gameStore.state.score, leaderboard: "main")
            isSubmitting = false
        }
    }
}



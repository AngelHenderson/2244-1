import SwiftUI
import GameApp

@MainActor
struct RewardSpinnerView: View {
    @Environment(\.gameStore) private var gameStore
    let baseAmount: Int
    let tileValue: Int
    let onClose: () -> Void
    
    @State private var selectedIndex: Int = 2 // center (4x)
    @State private var direction: Int = 1
    @State private var isFrozen = false
    @State private var timer: Timer? = nil
    
    private let multipliers: [Int] = [2, 3, 4, 5, 4, 3, 2]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New Unlock!")
                .font(.title.bold())
            Text("Tile \(tileValue)")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            spinner
            
            Button(action: claim) {
                VStack(spacing: 4) {
                    Text("Claim \(currentMultiplier)x")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear(perform: startSpinner)
        .onDisappear(perform: stopSpinner)
    }
    
    private func claim() {
        isFrozen = true
        stopSpinner()
        gameStore.claimPendingUnlockReward(multiplier: currentMultiplier)
        onClose()
    }
    
    private var currentMultiplier: Int {
        multipliers[selectedIndex]
    }
    
    private var spinner: some View {
        VStack(spacing: 12) {
            Text("Reward Multiplier")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            ZStack {
                Capsule()
                    .fill(Color.black.opacity(0.15))
                    .frame(height: 70)
                
                HStack(spacing: 8) {
                    ForEach(0..<multipliers.count, id: \.self) { index in
                        Text("\(multipliers[index])x")
                            .font(.headline.weight(.bold))
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(index == selectedIndex ? Color.green : Color.orange)
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(index == selectedIndex ? 0.9 : 0.4), lineWidth: 2)
                                    )
                            )
                            .foregroundStyle(.white)
                            .scaleEffect(index == selectedIndex ? 1.1 : 0.9)
                            .animation(.easeInOut(duration: 0.2), value: selectedIndex)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }
    
    private func startSpinner() {
        timer?.invalidate()
        isFrozen = false
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            Task { @MainActor in
                guard !isFrozen else { return }
                moveIndicator()
            }
        }
    }
    
    private func stopSpinner() {
        timer?.invalidate()
        timer = nil
    }
    
    private func moveIndicator() {
        var nextIndex = selectedIndex + direction
        if nextIndex >= multipliers.count {
            direction = -1
            nextIndex = multipliers.count - 2
        } else if nextIndex < 0 {
            direction = 1
            nextIndex = 1
        }
        selectedIndex = nextIndex
    }
}

import SwiftUI
import GameApp

struct RewardSpinnerView: View {
    @Environment(\.gameStore) private var gameStore
    let baseAmount: Int
    let tileValue: Int
    let onClose: () -> Void
    
    @State private var isSpinning = false
    @State private var selectedMultiplier: Int? = nil
    
    private let multipliers: [Int] = [1, 2, 3, 5]
    private let weights: [Double] = [0.6, 0.3, 0.09, 0.01]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New Unlock!")
                .font(.title.bold())
            Text("Tile \(tileValue)")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("Base Reward")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Image(systemName: "diamond.fill").foregroundStyle(.mint)
                    Text("\(baseAmount)")
                        .font(.title2.weight(.bold))
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.black.opacity(0.2))
                    .frame(height: 140)
                HStack(spacing: 16) {
                    ForEach(multipliers, id: \.self) { m in
                        Text("\(m)x")
                            .font(.title3.weight(.bold))
                            .frame(width: 60, height: 60)
                            .background(selectedMultiplier == m ? Color.green : Color.orange, in: Circle())
                            //.foregroundStyle(.white)
                            .scaleEffect(selectedMultiplier == m ? 1.1 : 1.0)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedMultiplier)
                    }
                }
                .padding(.horizontal)
            }
            
            HStack(spacing: 12) {
                Button(action: spin) {
                    Text(isSpinning ? "Spinning..." : "Spin")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSpinning)
                
                Button(action: claim) {
                    Text("Claim")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(selectedMultiplier == nil)
            }
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private func spin() {
        guard !isSpinning else { return }
        isSpinning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.selectedMultiplier = weightedRandomMultiplier()
            self.isSpinning = false
        }
    }
    
    private func claim() {
        guard let m = selectedMultiplier else { return }
        gameStore.claimPendingUnlockReward(multiplier: m)
        onClose()
    }
    
    private func weightedRandomMultiplier() -> Int {
        let sum = weights.reduce(0, +)
        let rnd = Double.random(in: 0...sum)
        var cumulative: Double = 0
        for (idx, w) in weights.enumerated() {
            cumulative += w
            if rnd <= cumulative { return multipliers[idx] }
        }
        return multipliers.last ?? 1
    }
}



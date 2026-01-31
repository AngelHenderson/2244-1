import SwiftUI
import GameApp

#if canImport(GameCore)
import GameCore
typealias TileValueFormatter = AlphaMag
#else
enum TileValueFormatter {
    static func formatTileValue(_ value: Int) -> String {
        RewardSpinnerView.tileFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
#endif

@MainActor
struct RewardSpinnerView: View {
    @Environment(\.gameStore) private var gameStore
    let baseAmount: Int
    let tileValue: Int
    let onClose: () -> Void
    
    @State private var selectedIndex: Int = 2
    @State private var direction: Int = 1
    @State private var isFrozen = false
    @State private var timer: Timer? = nil
    @State private var didClaim = false
    
    private let multipliers: [Int] = [2, 3, 4, 5, 4, 3, 2]
    private let slotWidth: CGFloat = 48
    
    var body: some View {
        VStack(spacing: 18) {
            Text("New Tile Unlocked")
                .font(.avenirNext(size: GameFonts.title1Size, weight: .bold))
            Text(TileValueFormatter.formatTileValue(tileValue))
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 6) {
                Text("Base Reward")
                    .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .foregroundStyle(.mint)
                    Text("\(baseAmount)")
                        .font(.avenirNext(size: GameFonts.title2Size, weight: .heavy))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassBackground(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            spinner
            
            Button(action: claim) {
                    Text("Claim \(currentMultiplier)x")
                    .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                        .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            didClaim = false
            startSpinner()
        }
        .onDisappear {
            stopSpinner()
            finalizeReward()
        }
    }
    
    private func claim() {
        isFrozen = true
        stopSpinner()
        finalizeReward()
        onClose()
    }
    
    private func finalizeReward() {
        guard !didClaim else { return }
        didClaim = true
        gameStore.claimPendingUnlockReward(multiplier: currentMultiplier)
    }
    
    private var currentMultiplier: Int {
        multipliers[selectedIndex]
    }
    
    private var spinner: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: "7B50A2"))
                    .frame(height: 56)
                
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 70, height: 46)
                        .offset(x: indicatorX(in: geo.size.width))
                          .animation(.easeInOut(duration: 0.25), value: selectedIndex)
                }
                .allowsHitTesting(false)
                
                HStack(spacing: 0) {
                    ForEach(0..<multipliers.count, id: \.self) { index in
                        multiplierCell(for: index)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .frame(height: 56)
        }
    }
    
    private func multiplierCell(for index: Int) -> some View {
        let colors = [
            Color(hex: "E646A0"),
            Color(hex: "F5962A"),
            Color(hex: "F4C229"),
            Color(hex: "61C459"),
            Color(hex: "F4C229"),
            Color(hex: "F5962A"),
            Color(hex: "E646A0")
        ]
        return Text("x\(multipliers[index])")
            .font(.avenirNext(size: GameFonts.headlineSize, weight: .heavy))
            .foregroundColor(.white)
            .frame(width: slotWidth, height: 56)
            .background(colors[index])
    }
    
    private func indicatorX(in width: CGFloat) -> CGFloat {
        let available = width - 70
        let progress = CGFloat(selectedIndex) / CGFloat(max(multipliers.count - 1, 1))
        return progress * max(available, 0)
    }
    
    #if !canImport(GameCore)
    private static let tileFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    #endif
    
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


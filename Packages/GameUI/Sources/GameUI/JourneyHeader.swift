import SwiftUI
import GameApp
import GameServices

/// Journey Header component showing milestone progression
public struct JourneyHeader: View {
    @Environment(\.tileJourney) private var journey
    @Environment(\.hapticsService) private var haptics
    
    @State private var showingRewardAnimation = false
    @State private var lastUnlockedTile: Int? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            // Highest Tile Badge
            VStack(spacing: 4) {
                Text("Highest Tile")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(journey.highestTile)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: journey.highestTile)
            
            // Milestone Path
            HStack(spacing: 8) {
                ForEach(journey.path(), id: \.self) { value in
                    MilestoneCard(
                        value: value,
                        unlocked: value <= journey.currentMilestone(),
                        claimed: journey.claimed.contains(value),
                        isCurrent: value == journey.currentMilestone(),
                        onClaim: {
                            claimMilestone(value)
                        }
                    )
                }
            }
            .padding(.horizontal)
            
            // Progress to Next
            if let next = journey.nextMilestone() {
                VStack(spacing: 4) {
                    Text("Progress to \(next)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ProgressView(value: journey.progress(toNextFrom: journey.currentMilestone()))
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 200)
                        .tint(.green)
                }
            }
        }
        .task {
            await listenForEvents()
        }
    }
    
    private func claimMilestone(_ value: Int) {
        journey.claim(value)
        haptics.mediumImpact()
        showingRewardAnimation = true
        
        // Grant rewards based on milestone value
        let reward = calculateReward(for: value)
        // Here you would integrate with your reward system
        print("Claimed milestone \(value) - Reward: \(reward) gems")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showingRewardAnimation = false
        }
    }
    
    private func calculateReward(for milestone: Int) -> Int {
        // Start at 1024 => 50 gems, then +10 per power of 2
        guard milestone >= 1024 else { return 0 }
        let power = Int(log2(Double(milestone)))
        let basePower = 10 // 2^10 = 1024
        return 50 + max(0, (power - basePower)) * 10
    }
    
    private func listenForEvents() async {
        for await event in journey.events {
            switch event {
            case let .milestoneUnlocked(tile):
                haptics.success()
                lastUnlockedTile = tile
                showingRewardAnimation = true
                print("🎉 Milestone Unlocked: \(tile)")
                
            case let .milestoneClaimed(tile):
                print("✅ Milestone Claimed: \(tile)")
                
            case let .highestUpdated(tile):
                print("📈 Highest Updated: \(tile)")
            }
        }
    }
}

private struct MilestoneCard: View {
    let value: Int
    let unlocked: Bool
    let claimed: Bool
    let isCurrent: Bool
    let onClaim: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 4) {
            // Tile Display
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
                    .frame(width: 72, height: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(borderColor, lineWidth: isCurrent ? 3 : 1)
                    )
                    .shadow(color: shadowColor, radius: isCurrent ? 8 : 2)
                
                if unlocked {
                    Text(formatValue(value))
                        .font(.headline)
                        .fontWeight(isCurrent ? .bold : .semibold)
                        .foregroundColor(textColor)
                } else {
                    Image("lockpic")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            
            // Claim Button or Status
            if unlocked {
                if claimed {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                        Text("Claimed")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isPressed = true
                        }
                        onClaim()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isPressed = false
                        }
                    }) {
                        Text("Claim")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    private var cardBackground: Color {
        if !unlocked {
            return Color.gray.opacity(0.15)
        } else if isCurrent {
            return Color.green.opacity(0.2)
        } else if claimed {
            return Color.blue.opacity(0.1)
        } else {
            return Color.yellow.opacity(0.15)
        }
    }
    
    private var borderColor: Color {
        if !unlocked {
            return Color.gray.opacity(0.3)
        } else if isCurrent {
            return Color.green
        } else if claimed {
            return Color.blue.opacity(0.5)
        } else {
            return Color.yellow
        }
    }
    
    private var shadowColor: Color {
        isCurrent ? Color.green.opacity(0.3) : Color.black.opacity(0.1)
    }
    
    private var textColor: Color {
        if isCurrent {
            return Color.green
        } else if claimed {
            return Color.primary.opacity(0.7)
        } else {
            return Color.primary
        }
    }
    
    private func formatValue(_ value: Int) -> String {
        if value >= 1024 {
            let k = value / 1024
            if k * 1024 == value {
                return "\(k)K"
            }
        }
        return "\(value)"
    }
}

// MARK: - Preview
#Preview {
    VStack {
        JourneyHeader()
            .padding()
        Spacer()
    }
    .environment(\.tileJourney, JourneyKit.Store(
        config: .init(minPower: 10, maxPower: 15)
    ))
    .environment(\.hapticsService, HapticsService())
}

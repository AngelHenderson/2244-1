import SwiftUI
import GameServices

@MainActor
public struct DailyClaimsView: View {
    @Environment(DailyClaimsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showClaimAnimation = false
    @State private var claimedRewards: AchievementDef.Rewards?
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color.purple.opacity(0.3), Color.indigo.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        if store.canClaimToday {
                            claimTodaySection
                        } else {
                            nextClaimSection
                        }
                        
                        claimsGridSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Daily Claims")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .overlay {
            if showClaimAnimation, let rewards = claimedRewards {
                ClaimAnimationOverlay(rewards: rewards)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Streak indicator
            VStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(store.currentStreak > 0 ? .orange : .gray)
                    .symbolEffect(.pulse, isActive: store.currentStreak > 0)
                
                Text("\(store.currentStreak)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("Day Streak")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            
            // Current progress
            HStack {
                Label("Day \(store.currentClaimDay) Completed", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
    }
    
    private var claimTodaySection: some View {
        VStack(spacing: 12) {
            if let nextDay = store.getNextClaimableDay(),
               let claim = store.dailyClaims.first(where: { $0.day == nextDay }) {
                Text("Day \(claim.day) Reward Available!")
                    .font(.headline)
                
                RewardsDisplay(rewards: claim.rewards)
                    .font(.title3)
                
                Button {
                    claimReward(claim.rewards)
                } label: {
                    Label("Claim Now", systemImage: "gift.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var nextClaimSection: some View {
        VStack(spacing: 12) {
            Text("Next Claim Available In")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if let timeRemaining = store.getTimeUntilNextClaim() {
                TimerView(timeRemaining: timeRemaining)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var claimsGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("365 Day Journey")
                .font(.title2.bold())
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 68), spacing: 8)
            ], spacing: 8) {
                ForEach(store.dailyClaims) { claim in
                    ClaimDayTile(claim: claim, currentDay: store.currentClaimDay)
                }
            }
        }
    }
    
    private func claimReward(_ rewards: AchievementDef.Rewards) {
        claimedRewards = rewards
        showClaimAnimation = true
        store.claimDailyReward()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showClaimAnimation = false
                claimedRewards = nil
            }
        }
    }
}

private struct ClaimDayTile: View {
    let claim: DailyClaimsStore.DailyClaim
    let currentDay: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Day")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            
            Text("\(claim.day)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
            
            // Rewards summary (tiny)
            RewardsTiny(rewards: claim.rewards)
                .font(.system(size: 9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Status icon
            if claim.isClaimed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else if claim.isAvailable {
                Image(systemName: "gift.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
                    .symbolEffect(.pulse)
            }
        }
        .frame(width: 68, height: 68)
        .background(backgroundGradient, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: claim.isAvailable ? 2 : 1)
        )
    }
    
    private var backgroundGradient: Gradient {
        if claim.isClaimed {
            return Gradient(colors: [.green.opacity(0.3), .green.opacity(0.1)])
        } else if claim.isAvailable {
            return Gradient(colors: [.yellow.opacity(0.3), .orange.opacity(0.2)])
        } else if claim.day <= currentDay {
            return Gradient(colors: [.gray.opacity(0.3), .gray.opacity(0.1)])
        } else {
            return Gradient(colors: [.clear, .gray.opacity(0.05)])
        }
    }
    
    private var borderColor: Color {
        if claim.isAvailable {
            return .yellow
        } else if claim.isClaimed {
            return .green.opacity(0.5)
        } else {
            return .gray.opacity(0.3)
        }
    }
}

private struct RewardsTiny: View {
    let rewards: AchievementDef.Rewards
    var body: some View {
        HStack(spacing: 6) {
            if let gems = rewards.gems, gems > 0 {
                Label("\(gems)", systemImage: "diamond.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.cyan)
                    .overlay(
                        Text("\(gems)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.cyan)
                            .offset(x: 8)
                    , alignment: .trailing)
            }
            if let spins = rewards.spins, spins > 0 {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.purple)
            }
            if let hammers = rewards.hammers, hammers > 0 {
                Image(systemName: "hammer.fill")
                    .foregroundStyle(.orange)
            }
            if let magnets = rewards.magnets, magnets > 0 {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.blue)
            }
        }
    }
}

private struct TimerView: View {
    let timeRemaining: TimeInterval
    @State private var currentTime = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(timeString)
            .onReceive(timer) { _ in
                currentTime = Date()
            }
    }
    
    private var timeString: String {
        let remaining = max(0, timeRemaining - Date().timeIntervalSince(currentTime))
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

private struct RewardsDisplay: View {
    let rewards: AchievementDef.Rewards
    
    var body: some View {
        HStack(spacing: 16) {
            if let gems = rewards.gems, gems > 0 {
                Label("\(gems)", systemImage: "diamond.fill")
                    .foregroundStyle(.cyan)
            }
            if let spins = rewards.spins, spins > 0 {
                Label("\(spins)", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.purple)
            }
            if let hammers = rewards.hammers, hammers > 0 {
                Label("\(hammers)", systemImage: "hammer.fill")
                    .foregroundStyle(.orange)
            }
            if let magnets = rewards.magnets, magnets > 0 {
                Label("\(magnets)", systemImage: "magnifyingglass")
                    .foregroundStyle(.blue)
            }
        }
    }
}

private struct ClaimAnimationOverlay: View {
    let rewards: AchievementDef.Rewards
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow)
                    .symbolEffect(.bounce)
                
                Text("Reward Claimed!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                
                RewardsDisplay(rewards: rewards)
                    .font(.title)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }
}
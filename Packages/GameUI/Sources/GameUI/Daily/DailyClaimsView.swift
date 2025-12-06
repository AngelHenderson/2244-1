import SwiftUI
import GameApp
import GameServices

@MainActor
public struct DailyClaimsView: View {
    @Environment(DailyClaimsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showClaimAnimation = false
    @State private var claimedRewards: AchievementDef.Rewards?
    @State private var selectedPage = 0
    
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
                        
                        availabilitySection
                        
                        claimsPagerSection
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
        .onAppear(perform: syncSelectedPage)
        .onChange(of: store.currentClaimDay) { _, _ in
            syncSelectedPage()
        }
        .onChange(of: store.dailyClaims.count) { _, _ in
            store.ensureClaimsCovering(pageIndex: selectedPage)
        }
        .onChange(of: selectedPage) { _, newValue in
            store.ensureClaimsCovering(pageIndex: newValue)
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
    
    private var availabilitySection: some View {
        Group {
            if store.canClaimToday {
                claimTodaySection
            } else {
                nextClaimSection
            }
        }
    }
    
    private var claimTodaySection: some View {
        VStack(spacing: 12) {
            if let nextDay = store.getNextClaimableDay(),
               let claim = store.dailyClaims.first(where: { $0.day == nextDay }) {
                let combined = store.combinedRewardForNextClaim() ?? claim.rewards
                
                Text("Day \(claim.day) Reward Available!")
                    .font(.headline)
                
                RewardsDisplay(rewards: combined)
                    .font(.title3)
                
                if combined.entries.count > claim.rewards.entries.count {
                    Text("Includes a streak bonus!")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                
                Text("Claim it from the timeline below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
    
    private var claimsPagerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Rewards")
                    .font(.title2.bold())
                Spacer()
                Text("Week \(selectedPage + 1)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if chunkedClaims.isEmpty {
                Text("Rewards loading...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                TabView(selection: $selectedPage) {
                    let highlightDay = store.getNextClaimableDay() ?? (store.currentClaimDay + 1)
                    ForEach(Array(chunkedClaims.enumerated()), id: \.offset) { index, claims in
                        VStack(spacing: 12) {
                            ForEach(claims) { claim in
                                DailyRewardRow(
                                    claim: claim,
                                    currentClaimDay: store.currentClaimDay,
                                    highlightDay: highlightDay,
                                    onClaim: claim.isAvailable ? { claimReward(claim.rewards) } : nil
                                )
                            }
                            if claims.count < 7 {
                                Spacer(minLength: CGFloat(7 - claims.count) * 72)
                            }
                        }
                        .padding(.vertical, 4)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 7 * 86)
            }
        }
    }
    
    private var chunkedClaims: [[DailyClaimsStore.DailyClaim]] {
        store.dailyClaims.chunked(into: 7)
    }
    
    private func syncSelectedPage() {
        let focusDay = store.getNextClaimableDay() ?? max(store.currentClaimDay, 1)
        let targetPage = max((focusDay - 1) / 7, 0)
        if selectedPage != targetPage {
            selectedPage = targetPage
        }
    }
    
    private func claimReward(_ rewards: AchievementDef.Rewards) {
        claimedRewards = store.combinedRewardForNextClaim() ?? rewards
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

private struct DailyRewardRow: View {
    let claim: DailyClaimsStore.DailyClaim
    let currentClaimDay: Int
    let highlightDay: Int
    let onClaim: (() -> Void)?
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Day \(claim.day)")
                        .font(.headline)
                    if claim.day == highlightDay {
                        Text("Today")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15), in: Capsule())
                    }
                }
                
                RewardsTiny(rewards: claim.rewards)
                    .font(.footnote)
            }
            
            Spacer()
            
            statusControl
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var statusControl: some View {
        if claim.isClaimed {
            Label("Claimed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline.bold())
        } else if let onClaim {
            Button(action: onClaim) {
                Text("Claim")
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.purple.gradient, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .shadow(color: .purple.opacity(0.2), radius: 6, y: 3)
        } else {
            VStack(spacing: 4) {
                Image(systemName: "clock")
                Text(claim.day <= currentClaimDay ? "Locked" : "Upcoming")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
    
    private var backgroundColor: Color {
        if claim.isClaimed {
            return Color.green.opacity(0.12)
        } else if claim.isAvailable {
            return Color.yellow.opacity(0.15)
        } else {
            return Color(.secondarySystemBackground)
        }
    }
    
    private var borderColor: Color {
        if claim.isAvailable {
            return .yellow
        } else if claim.isClaimed {
            return .green.opacity(0.6)
        } else {
            return .gray.opacity(0.2)
        }
    }
}

private struct RewardsTiny: View {
    let rewards: AchievementDef.Rewards
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(rewards.entries, id: \.self) { entry in
                RewardChip(entry: entry, style: .compact)
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
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rewards.entries, id: \.self) { entry in
                RewardChip(entry: entry, style: .detailed)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    .font(.title3)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }
}

private struct RewardChip: View {
    enum Style {
        case compact
        case detailed
    }
    
    let entry: AchievementDef.Rewards.Entry
    let style: Style
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.kind.iconName)
                .foregroundStyle(entry.kind.iconColor)
            switch style {
            case .compact:
                Text(compactText)
                    .font(.caption)
                    .foregroundStyle(entry.kind.iconColor)
            case .detailed:
                VStack(alignment: .leading, spacing: 2) {
                    Text(detailedTitle)
                        .font(.subheadline.bold())
                    Text(entry.kind.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(style == .compact ? 4 : 8)
        .background(entry.kind.iconColor.opacity(0.12), in: Capsule())
    }
    
    private var compactText: String {
        return "\(entry.amount) \(entry.kind.displayName)"
    }
    
    private var detailedTitle: String {
        return "\(entry.amount) \(entry.kind.displayName)"
    }
}

private extension AchievementDef.Rewards.Entry.Kind {
    var iconName: String {
        switch self {
        case .gems: return "diamond.fill"
        case .spins: return "arrow.triangle.2.circlepath"
        case .hammers: return "hammer.fill"
        case .magnets: return "magnet.fill"
        case .swaps: return "arrow.2.squarepath"
        case .boost2x, .boost3x, .boost4x: return "bolt.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .gems: return .cyan
        case .spins: return .purple
        case .hammers: return .orange
        case .magnets: return .blue
        case .swaps: return .green
        case .boost2x: return .yellow
        case .boost3x: return .pink
        case .boost4x: return .red
        }
    }
    
    var displayName: String {
        switch self {
        case .gems: return "Gems"
        case .spins: return "Spins"
        case .hammers: return "Hammers"
        case .magnets: return "MegaMerges"
        case .swaps: return "Swaps"
        case .boost2x: return "2× Boost"
        case .boost3x: return "3× Boost"
        case .boost4x: return "4× Boost"
        }
    }
    
    var subtitle: String {
        switch self {
        case .boost2x, .boost3x, .boost4x:
            return "Bonus multiplier"
        case .spins:
            return "Bonus spin"
        case .swaps:
            return "Swap power"
        case .hammers:
            return "Smash a tile"
        case .magnets:
            return "Pull matches"
        case .gems:
            return "Spend in shop"
        }
    }
    
    var isMultiplier: Bool {
        switch self {
        case .boost2x, .boost3x, .boost4x:
            return true
        default:
            return false
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        var result: [[Element]] = []
        var index = 0
        while index < count {
            let end = Swift.min(index + size, count)
            result.append(Array(self[index..<end]))
            index += size
        }
        return result
    }
}


import SwiftUI
import GameServices

@MainActor
public struct DailyStreaksView: View {
    @Environment(DailyClaimsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStreak: DailyClaimsStore.DailyStreak?
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color.orange.opacity(0.3), Color.red.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        currentStreakSection
                        progressSection
                        milestonesSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Daily Streaks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(item: $selectedStreak) { streak in
            StreakDetailSheet(streak: streak)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
    
    private var currentStreakSection: some View {
        VStack(spacing: 20) {
            // Main streak display
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 180, height: 180)
                    .shadow(color: .orange.opacity(0.5), radius: 20, y: 10)
                
                VStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse)
                    
                    Text("\(store.currentStreak)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("DAYS")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            
            // Streak status
            VStack(spacing: 8) {
                if store.currentStreak == 0 {
                    Text("Start Your Streak!")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text("Claim daily rewards to build your streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Keep it going!")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    
                    if let nextMilestone = store.dailyStreaks.first(where: { !$0.isUnlocked })?.day {
                        Text("\(nextMilestone - store.currentStreak) days until next milestone")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streak Progress")
                .font(.headline)
            
            // Progress bar to next milestone
            if let nextMilestone = store.dailyStreaks.first(where: { !$0.isUnlocked }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Day \(store.currentStreak)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Day \(nextMilestone.day)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(
                                    width: geometry.size.width * CGFloat(store.currentStreak) / CGFloat(nextMilestone.day),
                                    height: 8
                                )
                        }
                    }
                    .frame(height: 8)
                    
                    // Next reward preview
                    HStack {
                        Text("Next Reward:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        RewardsDisplay(rewards: nextMilestone.rewards)
                            .font(.caption)
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("365 Day Milestones")
                .font(.title2.bold())
            
            Text("Tap to view rewards")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.dailyStreaks.prefix(10)) { streak in
                        MilestoneCard(streak: streak, currentStreak: store.currentStreak)
                            .onTapGesture {
                                selectedStreak = streak
                            }
                    }
                    
                    if store.dailyStreaks.count > 10 {
                        VStack {
                            Text("...")
                                .font(.title.bold())
                            Text("\(store.dailyStreaks.count - 10) more")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .frame(width: 100, height: 140)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            
            // All milestones grid
            Text("All Milestones")
                .font(.headline)
                .padding(.top)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80), spacing: 12)
            ], spacing: 12) {
                ForEach(store.dailyStreaks) { streak in
                    MilestoneBadge(streak: streak, currentStreak: store.currentStreak)
                        .onTapGesture {
                            selectedStreak = streak
                        }
                }
            }
        }
    }
}

private struct MilestoneCard: View {
    let streak: DailyClaimsStore.DailyStreak
    let currentStreak: Int
    
    var body: some View {
        VStack(spacing: 12) {
            // Day number
            Text("Day")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("\(streak.day)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(streak.isUnlocked ? .green : .primary)
            
            // Status icon
            if streak.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            } else if currentStreak >= streak.day - 3 {
                Image(systemName: "lock.open.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            } else {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(.gray)
            }
            
            // Rewards preview
            if let gems = streak.rewards.gems, gems > 0 {
                Label {
                    Text(verbatim: String(gems))
                } icon: {
                    Image(systemName: "diamond.fill")
                }
                .font(.caption)
                .foregroundStyle(.cyan)
            }
        }
        .frame(width: 100, height: 140)
        .background(backgroundGradient, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(borderColor, lineWidth: 2)
        )
    }
    
    private var backgroundGradient: Gradient {
        if streak.isUnlocked {
            return Gradient(colors: [.green.opacity(0.3), .green.opacity(0.1)])
        } else if currentStreak >= streak.day - 3 {
            return Gradient(colors: [.orange.opacity(0.2), .yellow.opacity(0.1)])
        } else {
            return Gradient(colors: [.gray.opacity(0.1), .clear])
        }
    }
    
    private var borderColor: Color {
        if streak.isUnlocked {
            return .green
        } else if currentStreak >= streak.day - 3 {
            return .orange.opacity(0.5)
        } else {
            return .gray.opacity(0.3)
        }
    }
}

private struct MilestoneBadge: View {
    let streak: DailyClaimsStore.DailyStreak
    let currentStreak: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(streak.day)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(streak.isUnlocked ? .green : .primary)
            
            if streak.isUnlocked {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            } else {
                Image(systemName: "star")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: 80, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(streak.isUnlocked ? .green.opacity(0.2) : .gray.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(streak.isUnlocked ? .green : .gray.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct StreakDetailSheet: View {
    let streak: DailyClaimsStore.DailyStreak
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "flame.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(streak.isUnlocked ? .green : .orange)
                        .symbolEffect(.pulse)
                    
                    Text("Day \(streak.day) Milestone")
                        .font(.title2.bold())
                    
                    if streak.isUnlocked {
                        Label("Unlocked", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    } else {
                        Text("Keep your streak going!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Rewards
                VStack(alignment: .leading, spacing: 16) {
                    Text("Rewards")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        ForEach(streak.rewards.entries, id: \.self) { entry in
                            HStack {
                                Image(systemName: entry.kind.iconName)
                                    .font(.title2)
                                    .foregroundStyle(entry.kind.iconColor)
                                Text("\(entry.amount) \(entry.kind.displayName)")
                                    .font(.title3)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct RewardsDisplay: View {
    let rewards: AchievementDef.Rewards
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(rewards.entries, id: \.self) { entry in
                Label("\(entry.amount)", systemImage: entry.kind.iconName)
                    .foregroundStyle(entry.kind.iconColor)
            }
        }
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
        case .magnets: return "Magnets"
        case .swaps: return "Swaps"
        case .boost2x: return "2× Boost"
        case .boost3x: return "3× Boost"
        case .boost4x: return "4× Boost"
        }
    }
}
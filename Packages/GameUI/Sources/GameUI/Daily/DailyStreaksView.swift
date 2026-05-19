import SwiftUI
import GameCore
import GameApp

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
            .platformNavigationTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .platformTopBarTrailing) {
                    HStack(spacing: 12) {
                        GemBalancePill()
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        .sheet(item: $selectedStreak) { streak in
            StreakDetailSheet(streak: streak)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .trackScreen(.dailyStreaks)
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
                        .font(.avenirNext(size: 48, weight: .regular))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse)

                    Text("\(store.currentStreak)")
                        .font(.avenirNext(size: 56, weight: .bold))
                        .foregroundStyle(.white)

                    Text("DAYS")
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            // Streak status
            VStack(spacing: 8) {
                if store.currentStreak == 0 {
                    Text("Start Your Streak!")
                        .font(.avenirNext(size: GameFonts.title3Size, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Claim daily rewards to build your streak")
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Keep it going!")
                        .font(.avenirNext(size: GameFonts.title3Size, weight: .bold))
                        .foregroundStyle(.primary)

                    if let nextMilestone = store.dailyStreaks.first(where: { !$0.isUnlocked })?.day {
                        Text("\(nextMilestone - store.currentClaimDay) days until next milestone")
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let timeRemaining = store.getTimeUntilNextClaim() {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                        StreakCountdownText(timeRemaining: timeRemaining)
                    }
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestone Progress")
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))

            // Progress bar to next milestone
            if let nextMilestone = store.dailyStreaks.first(where: { !$0.isUnlocked }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(store.currentClaimDay)")
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(nextMilestone.day)")
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .medium))
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
                                    width: geometry.size.width * min(1, CGFloat(store.currentClaimDay) / CGFloat(nextMilestone.day)),
                                    height: 8
                                )
                        }
                    }
                    .frame(height: 8)

                    // Next reward preview
                    HStack {
                        Text("Next Reward:")
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                            .foregroundStyle(.secondary)
                        RewardsDisplay(rewards: nextMilestone.rewards)
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
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
                .font(.avenirNext(size: GameFonts.title2Size, weight: .bold))

            Text("Tap to view rewards")
                .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.dailyStreaks.prefix(10)) { streak in
                        MilestoneCard(streak: streak, currentDay: store.currentClaimDay)
                            .onTapGesture {
                                selectedStreak = streak
                            }
                    }

                    if store.dailyStreaks.count > 10 {
                        VStack {
                            Text("...")
                                .font(.avenirNext(size: GameFonts.title1Size, weight: .bold))
                            Text("\(store.dailyStreaks.count - 10) more")
                                .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                        }
                        .foregroundStyle(.secondary)
                        .frame(width: 100, height: 140)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }

            // All milestones grid
            Text("All Milestones")
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                .padding(.top)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80), spacing: 12)
            ], spacing: 12) {
                ForEach(store.dailyStreaks) { streak in
                    MilestoneBadge(streak: streak, currentDay: store.currentClaimDay)
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
    let currentDay: Int

    var body: some View {
        VStack(spacing: 12) {
            // Day number
            Text("Day")
                .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                .foregroundStyle(.secondary)

            Text("\(streak.day)")
                .font(.avenirNext(size: 32, weight: .bold))
                .foregroundStyle(streak.isUnlocked ? .green : .primary)

            // Status icon
            if streak.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.avenirNext(size: GameFonts.title2Size, weight: .regular))
                    .foregroundStyle(.green)
            } else if currentDay >= streak.day - 3 {
                Image(systemName: "lock.open.fill")
                    .font(.avenirNext(size: GameFonts.title2Size, weight: .regular))
                    .foregroundStyle(.orange)
            } else {
                Image(systemName: "lock.fill")
                    .font(.avenirNext(size: GameFonts.title2Size, weight: .regular))
                    .foregroundStyle(.gray)
            }

            // Rewards preview
            HStack(spacing: 4) {
                ForEach(streak.rewards.entries.prefix(2), id: \.self) { entry in
                    HStack(spacing: 2) {
                        Image(entry.kind.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text(verbatim: String(entry.amount))
                    }
                }
                if streak.rewards.entries.count > 2 {
                    Text("+\(streak.rewards.entries.count - 2)")
                }
            }
            .font(.avenirNext(size: GameFonts.caption1Size, weight: .medium))
            .foregroundStyle(.secondary)
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
        } else if currentDay >= streak.day - 3 {
            return Gradient(colors: [.orange.opacity(0.2), .yellow.opacity(0.1)])
        } else {
            return Gradient(colors: [.gray.opacity(0.1), .clear])
        }
    }
    
    private var borderColor: Color {
        if streak.isUnlocked {
            return .green
        } else if currentDay >= streak.day - 3 {
            return .orange.opacity(0.5)
        } else {
            return .gray.opacity(0.3)
        }
    }
}

private struct MilestoneBadge: View {
    let streak: DailyClaimsStore.DailyStreak
    let currentDay: Int

    var body: some View {
        VStack(spacing: 4) {
            Text("\(streak.day)")
                .font(.avenirNext(size: 20, weight: .bold))
                .foregroundStyle(streak.isUnlocked ? .green : .primary)

            if streak.isUnlocked {
                Image(systemName: "star.fill")
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                    .foregroundStyle(.yellow)
            } else {
                Image(systemName: "star")
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
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
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "flame.circle.fill")
                            .font(.avenirNext(size: 64, weight: .regular))
                            .foregroundStyle(streak.isUnlocked ? .green : .orange)
                            .symbolEffect(.pulse)

                        Text("Day \(streak.day) Milestone")
                            .font(.avenirNext(size: GameFonts.title2Size, weight: .bold))

                        if streak.isUnlocked {
                            Label("Unlocked", systemImage: "checkmark.circle.fill")
                                .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .regular))
                                .foregroundStyle(.green)
                        } else {
                            Text("Keep your streak going!")
                                .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Rewards
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Rewards")
                            .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))

                        VStack(spacing: 12) {
                            ForEach(streak.rewards.entries, id: \.self) { entry in
                                HStack {
                                    Image(entry.kind.assetName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                    Text("\(entry.amount) \(entry.kind.displayName)")
                                        .font(.avenirNext(size: GameFonts.title3Size, weight: .regular))
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .platformTopBarTrailing) {
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
                HStack(spacing: 4) {
                    Image(entry.kind.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                    Text("\(entry.amount)")
                }
            }
        }
    }
}

private struct StreakCountdownText: View {
    let timeRemaining: TimeInterval
    @State private var deadline: Date?
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(timeString)
            .onAppear {
                deadline = Date().addingTimeInterval(timeRemaining)
            }
            .onReceive(timer) { _ in
                now = Date()
            }
    }

    private var timeString: String {
        guard let deadline else {
            return String(format: "%02d:%02d:%02d", 0, 0, 0)
        }
        let remaining = max(0, deadline.timeIntervalSince(now))
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

#if DEBUG
#Preview("Daily Streaks") {
    GameUIScreenPreviewHost {
        DailyStreaksView()
    }
}
#endif

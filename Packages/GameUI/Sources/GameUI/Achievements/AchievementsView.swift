import SwiftUI
import GameServices
import GameApp

public struct AchievementsView: View {
    @Environment(AchievementStore.self) private var achievements
    @Environment(HomeState.self) private var homeState
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    /// Sorted achievements: claimable first, then locked, then claimed last
    private var sortedAchievements: [AchievementDef] {
        achievements.catalog.sorted { a, b in
            let stateA = achievements.unlocks[a.id]
            let stateB = achievements.unlocks[b.id]
            
            let priorityA = sortPriority(for: stateA)
            let priorityB = sortPriority(for: stateB)
            
            return priorityA < priorityB
        }
    }
    
    /// Sort priority: 0 = claimable (top), 1 = locked (middle), 2 = claimed (bottom)
    private func sortPriority(for state: AchievementStore.UnlockState?) -> Int {
        guard let state else { return 1 } // No state = locked
        if state.isClaimable { return 0 }  // Claimable at top
        if state.claimed { return 2 }       // Claimed at bottom
        return 1                            // Locked in middle
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(sortedAchievements) { def in
                        AchievementRow(
                            definition: def,
                            state: achievements.unlocks[def.id],
                            onClaim: {
                                // Claim the achievement
                                achievements.claim(definition: def)
                                // Immediately sync gems from UserDefaults to HomeState
                                let updatedGems = UserDefaults.standard.integer(forKey: "coins")
                                homeState.gems = updatedGems
                            }
                        )
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.3), value: achievements.unlocks)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct AchievementRow: View {
    let definition: AchievementDef
    let state: AchievementStore.UnlockState?
    let onClaim: () -> Void
    
    private var isUnlocked: Bool { state?.unlocked == true }
    private var isClaimed: Bool { state?.claimed == true }
    private var isClaimable: Bool { state?.isClaimable == true }
    
    var body: some View {
        HStack(spacing: 16) {
            LockupIcon(isUnlocked: isUnlocked)
                .frame(width: 64, height: 64)
            
            VStack(alignment: .leading, spacing: 8) {
                    Text(definition.title)
                        .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(detailText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 8) {
                    Label(definition.category, systemImage: categoryIcon(for: definition.category))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if isClaimed {
                        StatusBadge(text: "Claimed", color: .green)
                    } else if !isUnlocked {
                        StatusBadge(text: "Locked", color: .gray)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 12) {
                ClaimButton(
                    title: isClaimed ? "Claimed" : "Claim",
                    enabled: isClaimable,
                    action: onClaim
                )
                
                RewardSummary(rewards: definition.rewards)
                    }
                }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(UIColor.systemGray6),
                            Color(UIColor.systemGray5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isClaimable ? Color.green : Color(UIColor.separator), lineWidth: 1)
        )
        .opacity(definition.hidden && !isUnlocked ? 0.8 : 1.0)
    }
    
    private var detailText: String {
        if definition.hidden && !isUnlocked {
            return "Complete objectives to reveal this achievement."
        }
        return definition.description
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "onboarding": return "sparkles"
        case "score": return "trophy"
        case "timeattack": return "timer"
        case "daily": return "calendar"
        case "endless": return "infinity"
        case "patterns": return "square.grid.3x3"
        case "powerups": return "bolt"
        case "hidden": return "questionmark"
        default: return "star"
        }
    }
}

private struct RewardSummary: View {
    let rewards: AchievementDef.Rewards?
    
    private var summary: String {
        guard let rewards else { return "Bragging rights" }
        var parts: [String] = []
        if let gems = rewards.gems, gems > 0 { parts.append("\(gems) Gems") }
        if let hammers = rewards.hammers, hammers > 0 { parts.append("\(hammers) Hammers") }
        if let magnets = rewards.magnets, magnets > 0 { parts.append("\(magnets) Magnets") }
        if let spins = rewards.spins, spins > 0 { parts.append("\(spins) Spins") }
        if let boost2x = rewards.boost2x, boost2x > 0 { parts.append("\(boost2x)× 2 Boost") }
        if let boost3x = rewards.boost3x, boost3x > 0 { parts.append("\(boost3x)× 3 Boost") }
        if let boost4x = rewards.boost4x, boost4x > 0 { parts.append("\(boost4x)× 4 Boost") }
        return parts.isEmpty ? "Bragging rights" : parts.joined(separator: ", ")
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "gift.fill")
                .foregroundStyle(.orange)
            Text(summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct LockupIcon: View {
    let isUnlocked: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isUnlocked ? [.green.opacity(0.3), .green.opacity(0.15)] : [.purple.opacity(0.2), .blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                )
            
            Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .foregroundStyle(isUnlocked ? .green : .white)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
}

private struct StatusBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct ClaimButton: View {
    let title: String
    let enabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(minWidth: 96)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(buttonBackground)
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.6)
    }
    
    private var buttonBackground: AnyShapeStyle {
        if enabled {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.green, .green.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        } else {
            return AnyShapeStyle(Color.gray.opacity(0.3))
        }
    }
}
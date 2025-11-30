import SwiftUI
import GameServices
import GameApp

public struct AchievementsView: View {
    @Environment(AchievementStore.self) private var achievements
    @Environment(HomeState.self) private var homeState
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    /// Sorted achievements: claimable first, then locked, then claimed last
    /// Tile progression stays near top since it's always in progress
    private var sortedAchievements: [AchievementDef] {
        achievements.catalog.sorted { a, b in
            let stateA = achievements.unlocks[a.id]
            let stateB = achievements.unlocks[b.id]
            
            let priorityA = sortPriority(for: a.id, state: stateA)
            let priorityB = sortPriority(for: b.id, state: stateB)
            
            return priorityA < priorityB
        }
    }
    
    /// Sort priority: 0 = claimable (top), 1 = tile/moves progression / locked (middle), 2 = claimed (bottom)
    private func sortPriority(for id: String, state: AchievementStore.UnlockState?) -> Int {
        // Progressive achievements stay near top (priority 0.5 - between claimable and locked)
        if id == "tile_progression"
            || id == "moves_progression"
            || id == "combo_6_10"
            || id == "combo_11_15"
            || id == "combo_16_20"
            || id == "combo_21_30"
            || id == "merge_progression"
            || id == "swap_usage_progression"
            || id == "magnet_usage_progression" {
            if state?.isClaimable == true { return 0 }  // Claimable at very top
            return 1  // Otherwise just below claimable items
        }
        
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
                            tileProgressionTier: def.id == "tile_progression" ? achievements.currentTileTier : nil,
                            movesProgressionTier: def.id == "moves_progression" ? achievements.currentMovesTier : nil,
                            tierDisplay: tierDisplay(for: def.id),
                            progress: achievements.progress(for: def),
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
    
private func tierDisplay(for id: String) -> AchievementStore.ProgressTierDisplay? {
        switch id {
        case "combo_6_10":
            return achievements.combo610Display
        case "combo_11_15":
            return achievements.combo1115Display
        case "combo_16_20":
            return achievements.combo1620Display
        case "combo_21_30":
            return achievements.combo2130Display
        case "merge_progression":
            return achievements.mergeDisplay
        case "swap_usage_progression":
            return achievements.swapUsesDisplay
        case "magnet_usage_progression":
            return achievements.magnetUsesDisplay
        default:
            return nil
        }
    }
}

private struct AchievementRow: View {
    let definition: AchievementDef
    let state: AchievementStore.UnlockState?
    let tileProgressionTier: (suffix: String, label: String, value: Double)?
    let movesProgressionTier: (label: String, value: Double)?
    let tierDisplay: AchievementStore.ProgressTierDisplay?
    let progress: AchievementStore.AchievementProgress?
    let onClaim: () -> Void
    
    public init(
        definition: AchievementDef,
        state: AchievementStore.UnlockState?,
        tileProgressionTier: (suffix: String, label: String, value: Double)? = nil,
        movesProgressionTier: (label: String, value: Double)? = nil,
        tierDisplay: AchievementStore.ProgressTierDisplay? = nil,
        progress: AchievementStore.AchievementProgress? = nil,
        onClaim: @escaping () -> Void
    ) {
        self.definition = definition
        self.state = state
        self.tileProgressionTier = tileProgressionTier
        self.movesProgressionTier = movesProgressionTier
        self.tierDisplay = tierDisplay
        self.progress = progress
        self.onClaim = onClaim
    }
    
    private var isUnlocked: Bool { state?.unlocked == true }
    private var isClaimed: Bool { state?.claimed == true }
    private var isClaimable: Bool { state?.isClaimable == true }
    
    /// Dynamic title for progressive achievements
    private var displayTitle: String {
        if let tierDisplay {
            return tierDisplay.title
        }
        if let tier = tileProgressionTier {
            return "Reach the \(tier.label) tile"
        }
        if let tier = movesProgressionTier {
            return "Make \(tier.label) moves"
        }
        return definition.title
    }
    
    /// Dynamic description for progressive achievements
    private var displayDescription: String {
        if definition.hidden && !isUnlocked {
            return "Complete objectives to reveal this achievement."
        }
        if let tierDisplay {
            return tierDisplay.description
        }
        if let tier = tileProgressionTier {
            if tier.label == "∞" {
                return "Create a tile beyond comprehension. You are infinite."
            }
            return "Create a \(tier.label) tile to claim this reward and unlock the next tier."
        }
        if let tier = movesProgressionTier {
            return "Make \(tier.label) total moves to unlock the next tier."
        }
        return definition.description
    }
    
    var body: some View {
        HStack(spacing: 16) {
            LockupIcon(isUnlocked: isUnlocked)
                .frame(width: 64, height: 64)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(categoryLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Text(displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(displayDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let progress = progress {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(progressLabel(for: progress))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(progressValueText(for: progress))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(
                            value: clampedProgressValue(progress).current,
                            total: clampedProgressValue(progress).target
                        )
                        .progressViewStyle(.linear)
                        .tint(.green)
                    }
                    .padding(.top, 2)
                }
                
                HStack(spacing: 8) {
                    if isClaimed {
                        StatusBadge(text: "Completed", color: .green)
                    } else if !isUnlocked {
                        StatusBadge(text: "In Progress", color: .orange)
                    } else if isClaimable {
                        StatusBadge(text: "Ready!", color: .green)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 12) {
                ClaimButton(
                    title: isClaimed ? "Done" : "Claim",
                    enabled: isClaimable,
                    action: onClaim
                )
                
                RewardSummary(rewards: rewardsForDisplay)
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
    
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "onboarding": return "sparkles"
        case "score": return "trophy"
        case "highesttile": return "arrow.up.circle"
        case "timeattack": return "timer"
        case "daily": return "calendar"
        case "endless": return "infinity"
        case "patterns": return "square.grid.3x3"
        case "powerups": return "bolt"
        case "career": return "chart.bar.fill"
        case "hidden": return "questionmark"
        default: return "star"
        }
    }
    
    private var categoryLabel: String {
        tierDisplay?.categoryLabel ?? definition.category
    }
    
    private var rewardsForDisplay: AchievementDef.Rewards? {
        tierDisplay?.rewards ?? definition.rewards
    }
    
    private func clampedProgressValue(_ progress: AchievementStore.AchievementProgress) -> (current: Double, target: Double) {
        let target = max(progress.target, 1)
        let current = min(max(progress.current, 0), target)
        return (current, target)
    }
    
    private func progressValueText(for progress: AchievementStore.AchievementProgress) -> String {
        let values = clampedProgressValue(progress)
        return "\(formattedValue(values.current))/\(formattedValue(progress.target))"
    }
    
    private func progressLabel(for progress: AchievementStore.AchievementProgress) -> String {
        if let tierDisplay {
            return tierDisplay.title
        }
        return definition.title
    }
    
    private func formattedValue(_ value: Double) -> String {
        if value >= 1_000 {
            return value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
        } else {
            return value.formatted(.number.precision(.fractionLength(0)))
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
        if let magnets = rewards.magnets, magnets > 0 { parts.append("\(magnets) MegaMerges") }
        if let swaps = rewards.swaps, swaps > 0 { parts.append("\(swaps) Swaps") }
        if let spins = rewards.spins, spins > 0 { parts.append("\(spins) Spins") }
        if let boost2x = rewards.boost2x, boost2x > 0 { parts.append("\(boost2x)× 2X Boost") }
        if let boost3x = rewards.boost3x, boost3x > 0 { parts.append("\(boost3x)× 3X Boost") }
        if let boost4x = rewards.boost4x, boost4x > 0 { parts.append("\(boost4x)× 4X Boost") }
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
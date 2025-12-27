import SwiftUI
import GameServices
import GameApp

public struct AchievementsView: View {
    @Environment(AchievementStore.self) private var achievements
    @Environment(HomeState.self) private var homeState
    @Environment(\.gameStore) private var gameStore
    @Environment(\.dismiss) private var dismiss

    public init() {}
    
    /// Sorted achievements: highest level first, then by claimable status
    private var sortedAchievements: [AchievementDef] {
        achievements.catalog.sorted { a, b in
            let levelA = achievementLevel(for: a.id)
            let levelB = achievementLevel(for: b.id)

            // Sort by level descending (highest first)
            if levelA != levelB {
                return levelA > levelB
            }

            // If same level, sort by claimable status
            let stateA = achievements.unlocks[a.id]
            let stateB = achievements.unlocks[b.id]
            let priorityA = sortPriority(for: a.id, state: stateA)
            let priorityB = sortPriority(for: b.id, state: stateB)

            return priorityA < priorityB
        }
    }

    /// Get the current level for an achievement
    private func achievementLevel(for id: String) -> Int {
        switch id {
        case "tile_progression":
            return achievements.tileProgressionDisplay.level
        case "moves_progression":
            return achievements.movesProgressionTier + 1
        case "combo_6_10":
            return achievements.combo610Display.level
        case "combo_11_15":
            return achievements.combo1115Display.level
        case "combo_16_20":
            return achievements.combo1620Display.level
        case "combo_21_30":
            return achievements.combo2130Display.level
        case "merge_progression":
            return achievements.mergeDisplay.level
        case "swap_usage_progression":
            return achievements.swapUsesDisplay.level
        case "hammer_usage_progression":
            return achievements.hammerUsesDisplay.level
        case "survive_moves_progression":
            return achievements.surviveMovesDisplay.level
        case "spin_usage_progression":
            return achievements.spinUsesDisplay.level
        case "magnet_usage_progression":
            return achievements.magnetUsesDisplay.level
        case "challenge_creation":
            return achievements.challengeCreationDisplay.level
        case "infinity_progression":
            return achievements.infinityDisplay.level
        case "playtime_progression":
            return achievements.playtimeDisplay.level
        case "boost2x_usage_progression":
            return achievements.boost2xUsesDisplay.level
        case "boost3x_usage_progression":
            return achievements.boost3xUsesDisplay.level
        case "boost4x_usage_progression":
            return achievements.boost4xUsesDisplay.level
        case "spin_purchases_progression":
            return achievements.spinPurchasesDisplay.level
        case "daily_claims_progression":
            return achievements.dailyClaimsDisplay.level
        case "boost5x_usage_progression":
            return achievements.boost5xUsesDisplay.level
        case "boost20x_usage_progression":
            return achievements.boost20xUsesDisplay.level
        case "wheel_collects_progression":
            return achievements.wheelCollectsDisplay.level
        default:
            return 1
        }
    }

    /// Sort priority: 0 = claimable (top), 1 = in progress (middle), 2 = claimed (bottom)
    private func sortPriority(for id: String, state: AchievementStore.UnlockState?) -> Int {
        guard let state else { return 1 } // No state = in progress
        if state.isClaimable { return 0 }  // Claimable at top
        if state.claimed { return 2 }       // Claimed at bottom
        return 1                            // In progress in middle
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
            .onAppear {
                // Trigger playtime update when viewing achievements
                gameStore.achievementEvaluator?.savePlaytimeProgress(state: gameStore.state)
            }
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
        case "tile_progression":
            return achievements.tileProgressionDisplay
        case "playtime_progression":
            return achievements.playtimeDisplay
        case "infinity_progression":
            return achievements.infinityDisplay
        case "swap_usage_progression":
            return achievements.swapUsesDisplay
        case "hammer_usage_progression":
            return achievements.hammerUsesDisplay
        case "survive_moves_progression":
            return achievements.surviveMovesDisplay
        case "spin_usage_progression":
            return achievements.spinUsesDisplay
        case "magnet_usage_progression":
            return achievements.magnetUsesDisplay
        case "challenge_creation":
            return achievements.challengeCreationDisplay
        case "boost2x_usage_progression":
            return achievements.boost2xUsesDisplay
        case "boost3x_usage_progression":
            return achievements.boost3xUsesDisplay
        case "boost4x_usage_progression":
            return achievements.boost4xUsesDisplay
        case "spin_purchases_progression":
            return achievements.spinPurchasesDisplay
        case "daily_claims_progression":
            return achievements.dailyClaimsDisplay
        case "boost5x_usage_progression":
            return achievements.boost5xUsesDisplay
        case "boost20x_usage_progression":
            return achievements.boost20xUsesDisplay
        case "wheel_collects_progression":
            return achievements.wheelCollectsDisplay
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
        if value < 1_000 {
            return value.formatted(.number.precision(.fractionLength(0)))
        } else if value < 1_000_000 {
            let k = value / 1_000
            return k.formatted(.number.precision(.fractionLength(0...1))) + "K"
        } else if value < 1_000_000_000 {
            let m = value / 1_000_000
            return m.formatted(.number.precision(.fractionLength(0...1))) + "M"
        } else if value < 1_000_000_000_000 {
            let b = value / 1_000_000_000
            return b.formatted(.number.precision(.fractionLength(0...1))) + "B"
        } else {
            // Use alphabetic suffixes for trillions+: a, b, c, ..., z, aa, ab, ..., az, ba, ..., bz
            var remaining = value
            var tierIndex = 0
            while remaining >= 1_000 && tierIndex < 100 {
                remaining /= 1_000
                tierIndex += 1
            }
            // tierIndex 4 = trillions = 'a', 5 = quadrillions = 'b', etc.
            let letterIndex = tierIndex - 3 // 4->1 (a), 5->2 (b), etc.
            let suffix = excelStyleLetters(for: letterIndex)
            return remaining.formatted(.number.precision(.fractionLength(0...1))) + suffix
        }
    }

    /// Excel-style letters: 1->"a", 26->"z", 27->"aa", 52->"az", 53->"ba", 78->"bz"
    private func excelStyleLetters(for index: Int) -> String {
        guard index >= 1 else { return "a" }
        var i = index
        var result = ""
        while i > 0 {
            let rem = (i - 1) % 26
            let scalar = UnicodeScalar(97 + rem)! // 'a'..'z'
            result = String(scalar) + result
            i = (i - 1) / 26
        }
        return result
    }
}

private struct RewardSummary: View {
    let rewards: AchievementDef.Rewards?

    private enum RewardIcon {
        case asset(String)
        case system(String, Color)
    }

    private struct RewardItem: Identifiable {
        let id = UUID()
        let icon: RewardIcon
        let text: String
    }

    private var rewardItems: [RewardItem] {
        guard let rewards else { return [] }
        var items: [RewardItem] = []
        if let gems = rewards.gems, gems > 0 {
            items.append(RewardItem(icon: .asset("gem"), text: "\(gems) Gems"))
        }
        if let hammers = rewards.hammers, hammers > 0 {
            items.append(RewardItem(icon: .asset("hammer"), text: "\(hammers) Hammer\(hammers == 1 ? "" : "s")"))
        }
        if let magnets = rewards.magnets, magnets > 0 {
            items.append(RewardItem(icon: .asset("magnet"), text: "\(magnets) MegaMerge\(magnets == 1 ? "" : "s")"))
        }
        if let swaps = rewards.swaps, swaps > 0 {
            items.append(RewardItem(icon: .asset("swap"), text: "\(swaps) Swap\(swaps == 1 ? "" : "s")"))
        }
        if let spins = rewards.spins, spins > 0 {
            items.append(RewardItem(icon: .asset("spinthewheel"), text: "\(spins) Spin\(spins == 1 ? "" : "s")"))
        }
        if let boost2x = rewards.boost2x, boost2x > 0 {
            items.append(RewardItem(icon: .asset("boost2x"), text: "\(boost2x)× 2X Boost"))
        }
        if let boost3x = rewards.boost3x, boost3x > 0 {
            items.append(RewardItem(icon: .asset("boost3x"), text: "\(boost3x)× 3X Boost"))
        }
        if let boost4x = rewards.boost4x, boost4x > 0 {
            items.append(RewardItem(icon: .asset("boost4x"), text: "\(boost4x)× 4X Boost"))
        }
        return items
    }

    @ViewBuilder
    private func iconView(for icon: RewardIcon) -> some View {
        switch icon {
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        case .system(let name, let color):
            Image(systemName: name)
                .foregroundStyle(color)
        }
    }

    var body: some View {
        let items = rewardItems

        if items.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("Bragging rights")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else if items.count == 1 {
            // Single reward - show its specific icon
            let item = items[0]
            HStack(spacing: 6) {
                iconView(for: item.icon)
                Text(item.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            // Multiple rewards - show gift icon
            HStack(spacing: 6) {
                Image("gift")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                Text(items.map { $0.text }.joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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
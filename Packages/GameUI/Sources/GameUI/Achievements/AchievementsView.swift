import SwiftUI
import GameServices
import GameApp

public struct AchievementsView: View {
    @Environment(AchievementStore.self) private var achievements
    @Environment(HomeState.self) private var homeState
    @Environment(\.gameStore) private var gameStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAchievementForTiers: AchievementDef?

    public init() {}
    
    /// Sorted achievements: claimable first, then by level (highest first), then by progress bar (highest first)
    private var sortedAchievements: [AchievementDef] {
        achievements.catalog.sorted { a, b in
            let stateA = achievements.unlocks[a.id]
            let stateB = achievements.unlocks[b.id]
            let claimableA = stateA?.isClaimable == true
            let claimableB = stateB?.isClaimable == true
            let maxedA = isMaxed(for: a.id)
            let maxedB = isMaxed(for: b.id)

            // Claimable achievements go to the top
            if claimableA != claimableB {
                return claimableA
            }

            // Maxed out achievements go to the bottom
            if maxedA != maxedB {
                return maxedB // B is maxed, so A comes first
            }

            let levelA = achievementLevel(for: a.id)
            let levelB = achievementLevel(for: b.id)

            // Sort by level descending (highest first)
            if levelA != levelB {
                return levelA > levelB
            }

            // If same level, sort by progress bar percentage (highest first)
            let progressA = achievements.progress(for: a)?.percentage ?? 0
            let progressB = achievements.progress(for: b)?.percentage ?? 0
            if progressA != progressB {
                return progressA > progressB
            }

            // If same level and progress, sort by category/name
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

    /// Check if an achievement has reached its maximum tier (all tiers completed)
    private func isMaxed(for id: String) -> Bool {
        switch id {
        case "tile_progression":
            return achievements.isTileProgressionMaxed
        case "moves_progression":
            return achievements.isMovesProgressionMaxed
        case "combo_6_10":
            return achievements.isCombo610Maxed
        case "combo_11_15":
            return achievements.isCombo1115Maxed
        case "combo_16_20":
            return achievements.isCombo1620Maxed
        case "combo_21_30":
            return achievements.isCombo2130Maxed
        case "merge_progression":
            return achievements.isMergeProgressionMaxed
        case "swap_usage_progression":
            return achievements.isSwapUsesProgressionMaxed
        case "hammer_usage_progression":
            return achievements.isHammerUsesProgressionMaxed
        case "survive_moves_progression":
            return achievements.isSurviveMovesProgressionMaxed
        case "spin_usage_progression":
            return achievements.isSpinUsesProgressionMaxed
        case "magnet_usage_progression":
            return achievements.isMagnetUsesProgressionMaxed
        case "challenge_creation":
            return achievements.isChallengeCreationMaxed
        case "infinity_progression":
            return achievements.isInfinityProgressionMaxed
        case "playtime_progression":
            return achievements.isPlaytimeProgressionMaxed
        case "boost2x_usage_progression":
            return achievements.isBoost2xUsesProgressionMaxed
        case "boost3x_usage_progression":
            return achievements.isBoost3xUsesProgressionMaxed
        case "boost4x_usage_progression":
            return achievements.isBoost4xUsesProgressionMaxed
        case "spin_purchases_progression":
            return achievements.isSpinPurchasesProgressionMaxed
        case "daily_claims_progression":
            return achievements.isDailyClaimsProgressionMaxed
        case "boost5x_usage_progression":
            return achievements.isBoost5xUsesProgressionMaxed
        case "boost20x_usage_progression":
            return achievements.isBoost20xUsesProgressionMaxed
        case "wheel_collects_progression":
            return achievements.isWheelCollectsProgressionMaxed
        default:
            // For non-progressive achievements, check if claimed
            return achievements.unlocks[id]?.claimed == true
        }
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Show "Claim All" button at top when there are multiple claimable achievements
                if achievements.claimableCount >= 2 {
                    ClaimAllButton(count: achievements.claimableCount) {
                        _ = achievements.claimAll()
                        // Sync gems from UserDefaults to HomeState
                        let updatedGems = UserDefaults.standard.integer(forKey: "coins")
                        homeState.gems = updatedGems
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.systemGroupedBackground))
                }

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
                                isMaxed: isMaxed(for: def.id),
                                hasMultipleTiers: achievements.hasMultipleTiers(for: def.id),
                                onClaim: {
                                    // Claim the achievement
                                    achievements.claim(definition: def)
                                    // Immediately sync gems from UserDefaults to HomeState
                                    let updatedGems = UserDefaults.standard.integer(forKey: "coins")
                                    homeState.gems = updatedGems
                                },
                                onTapTiers: {
                                    selectedAchievementForTiers = def
                                }
                            )
                        }
                    }
                    .padding()
                    .animation(.easeInOut(duration: 0.3), value: achievements.unlocks)
                }
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
            .sheet(item: $selectedAchievementForTiers) { def in
                AllTiersView(
                    achievementTitle: tierDisplay(for: def.id)?.title ?? def.title,
                    tiers: achievements.allTiers(for: def.id)
                )
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
    let isMaxed: Bool
    let hasMultipleTiers: Bool
    let onClaim: () -> Void
    let onTapTiers: () -> Void

    public init(
        definition: AchievementDef,
        state: AchievementStore.UnlockState?,
        tileProgressionTier: (suffix: String, label: String, value: Double)? = nil,
        movesProgressionTier: (label: String, value: Double)? = nil,
        tierDisplay: AchievementStore.ProgressTierDisplay? = nil,
        progress: AchievementStore.AchievementProgress? = nil,
        isMaxed: Bool = false,
        hasMultipleTiers: Bool = false,
        onClaim: @escaping () -> Void,
        onTapTiers: @escaping () -> Void = {}
    ) {
        self.definition = definition
        self.state = state
        self.tileProgressionTier = tileProgressionTier
        self.movesProgressionTier = movesProgressionTier
        self.tierDisplay = tierDisplay
        self.progress = progress
        self.isMaxed = isMaxed
        self.hasMultipleTiers = hasMultipleTiers
        self.onClaim = onClaim
        self.onTapTiers = onTapTiers
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
        VStack(alignment: .leading, spacing: 10) {
            // Top row: Icon, Title/Category, Claim button
            HStack(alignment: .top, spacing: 12) {
                LockupIcon(isUnlocked: isUnlocked, isMaxed: isMaxed)
                    .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(categoryLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 6) {
                    ClaimButton(
                        title: isClaimed ? "Done" : "Claim",
                        enabled: isClaimable,
                        action: onClaim
                    )
                    RewardSummary(rewards: rewardsForDisplay)
                }
            }

            // Description
            Text(displayDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Progress bar (full width)
            if let progress = progress {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(progressValueText(for: progress))
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    ProgressView(
                        value: clampedProgressValue(progress).current,
                        total: clampedProgressValue(progress).target
                    )
                    .progressViewStyle(.linear)
                    .tint(.green)
                }
            }

            // Status badges
            HStack(spacing: 8) {
                if isClaimed {
                    StatusBadge(text: "Completed", color: .green)
                } else if !isUnlocked {
                    StatusBadge(text: "In Progress", color: .orange)
                } else if isClaimable {
                    StatusBadge(text: "Ready!", color: .green)
                }

                Spacer()

                if hasMultipleTiers {
                    Button(action: onTapTiers) {
                        HStack(spacing: 4) {
                            Text("View All Tiers")
                                .font(.caption2.bold())
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15), in: Capsule())
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
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
            return k.formatted(.number.precision(.fractionLength(0...2))) + "K"
        } else if value < 1_000_000_000 {
            let m = value / 1_000_000
            return m.formatted(.number.precision(.fractionLength(0...2))) + "M"
        } else if value < 1_000_000_000_000 {
            let b = value / 1_000_000_000
            return b.formatted(.number.precision(.fractionLength(0...2))) + "B"
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
            return remaining.formatted(.number.precision(.fractionLength(0...2))) + suffix
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
            // Multiple rewards - show mystery box icon
            HStack(spacing: 6) {
                Image("mysterybox")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text(items.map { $0.text }.joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LockupIcon: View {
    let isUnlocked: Bool
    let isMaxed: Bool

    init(isUnlocked: Bool, isMaxed: Bool = false) {
        self.isUnlocked = isUnlocked
        self.isMaxed = isMaxed
    }

    private var iconName: String {
        if isMaxed {
            return "checkmark.circle.fill"
        } else if isUnlocked {
            return "lock.open.fill"
        } else {
            return "lock.fill"
        }
    }

    private var iconColor: Color {
        if isMaxed {
            return .green
        } else if isUnlocked {
            return .green
        } else {
            return .white
        }
    }

    private var backgroundColors: [Color] {
        if isMaxed {
            return [.green.opacity(0.4), .green.opacity(0.2)]
        } else if isUnlocked {
            return [.green.opacity(0.3), .green.opacity(0.15)]
        } else {
            return [.purple.opacity(0.2), .blue.opacity(0.1)]
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: backgroundColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                )

            Image(systemName: iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .foregroundStyle(iconColor)
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

private struct ClaimAllButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "gift.fill")
                    .font(.title3)
                Text("Claim All (\(count))")
                    .font(.headline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
            )
            .foregroundStyle(.white)
            .shadow(color: .green.opacity(0.4), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
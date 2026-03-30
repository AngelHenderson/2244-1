import SwiftUI
import GameApp
import GameCore

public struct AchievementsView: View {
    @Environment(AchievementStore.self) private var achievements
    @Environment(HomeState.self) private var homeState
    @Environment(\.gameStore) private var gameStore
    @Environment(DailyQuestStore.self) private var questStore
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
        case "leaderboard_rank_progression":
            return achievements.leaderboardRankDisplay.level
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
        case "leaderboard_rank_progression":
            return achievements.isLeaderboardRankMaxed
        default:
            // For non-progressive achievements, check if claimed
            return achievements.unlocks[id]?.claimed == true
        }
    }
    
    @State private var selectedTab: Tab = .achievements

    private enum Tab: String, CaseIterable {
        case achievements = "Achievements"
        case dailyQuests = "Daily Quests"
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch selectedTab {
                case .achievements:
                    // Show "Claim All" button at top when there are multiple claimable achievements
                    if achievements.claimableCount >= 2 {
                        ClaimAllButton(count: achievements.claimableCount) {
                            _ = achievements.claimAll()
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
                                        achievements.claim(definition: def)
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

                case .dailyQuests:
                    ScrollView {
                        DailyQuestsSection(questStore: questStore, homeState: homeState)
                            .padding()
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(selectedTab == .achievements ? "ACHIEVEMENTS" : "DAILY QUESTS")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                gameStore.achievementEvaluator?.savePlaytimeProgress(state: gameStore.state)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        GemBalancePill()
                        Button("Done") {
                            dismiss()
                        }
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
        case "moves_progression":
            return achievements.movesDisplay
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
        case "leaderboard_rank_progression":
            return achievements.leaderboardRankDisplay
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
            // Strip "Level X: " prefix from title since it's now shown in categoryLabel
            let title = tierDisplay.title
            if let colonIndex = title.firstIndex(of: ":"),
               title.hasPrefix("Level ") {
                let afterColon = title.index(colonIndex, offsetBy: 2, limitedBy: title.endIndex) ?? colonIndex
                return String(title[afterColon...])
            }
            return title
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
            // Title centered at top
            Text(displayTitle)
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            // Category label centered below title
            HStack(spacing: 4) {
                if tierDisplay != nil {
                    Image("GiftBoxIcon", bundle: .module)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                }
                Text(categoryLabel)
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Row: Icon, Claim button
            HStack(alignment: .top, spacing: 12) {
                LockupIcon(isUnlocked: isUnlocked, isMaxed: isMaxed)
                    .frame(width: 52, height: 52)

                Spacer()

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
                .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .regular))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Progress bar (full width)
            if let progress = progress {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(progressValueText(for: progress))
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                            .monospacedDigit()
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
                                .font(.avenirNext(size: GameFonts.caption2Size, weight: .bold))
                            Image(systemName: "chevron.right")
                                .font(.avenirNext(size: GameFonts.caption2Size, weight: .regular))
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
        if let tierDisplay {
            return "Level \(tierDisplay.level): \(tierDisplay.categoryLabel)"
        }
        return definition.category
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
        // Show actual unclamped values so users can see when they've exceeded the target (e.g., "1.56K/1.5K")
        // The progress bar itself remains clamped to not exceed 100%
        return "\(formattedValue(progress.current))/\(formattedValue(progress.target))"
    }
    
    private func progressLabel(for progress: AchievementStore.AchievementProgress) -> String {
        if let tierDisplay {
            return tierDisplay.title
        }
        return definition.title
    }
    
    private func formattedValue(_ value: Double) -> String {
        // Use Decimal for precision with very large numbers
        // GameCore.AlphaMag.format handles K, M, B, and alphabetic suffixes (a, b, c, ..., aa, ab, ...)
        let decimalValue = Decimal(value)
        do {
            return try GameCore.AlphaMag.format(decimalValue, decimals: 2)
        } catch {
            // Fallback to simple formatting if AlphaMag fails
            return value.formatted(.number.precision(.fractionLength(0)))
        }
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
            items.append(RewardItem(icon: .system("4.circle.fill", .orange), text: "\(boost4x)× 4X Boost"))
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
                    .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        } else if items.count == 1 {
            // Single reward - show its specific icon
            let item = items[0]
            HStack(spacing: 6) {
                iconView(for: item.icon)
                Text(item.text)
                    .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
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
                    .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
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
            .font(.avenirNext(size: GameFonts.caption2Size, weight: .bold))
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
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
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
                    .font(.avenirNext(size: GameFonts.title3Size, weight: .regular))
                Text("Claim All (\(count))")
                    .font(.avenirNext(size: GameFonts.headlineSize, weight: .bold))
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

// MARK: - Daily Quests Section

struct DailyQuestsSection: View {
    let questStore: DailyQuestStore
    let homeState: HomeState

    @State private var countdown: String = ""
    @State private var timer: Timer?
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(spacing: 10) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("DAILY QUESTS")
                        .font(.avenirNext(size: GameFonts.headlineSize, weight: .bold))
                        .foregroundStyle(.primary)

                    if questStore.claimableCount > 0 {
                        Text("\(questStore.claimableCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green, in: Capsule())
                    }

                    Spacer()

                    // Countdown
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text(countdown)
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.secondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(questStore.quests) { quest in
                    DailyQuestRow(
                        quest: quest,
                        highestTileStep: homeState.highestTileStep,
                        tileQuestTargetStep: questStore.tileQuestTargetStep
                    ) {
                        questStore.claim(questId: quest.id)
                        // Sync gems immediately
                        let updatedGems = UserDefaults.standard.integer(forKey: "coins")
                        homeState.gems = updatedGems
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .onAppear {
            updateCountdown()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                Task { @MainActor in updateCountdown() }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func updateCountdown() {
        let remaining = questStore.timeUntilReset()
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        countdown = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Daily Quest Row

private struct DailyQuestRow: View {
    let quest: DailyQuestStore.Quest
    let highestTileStep: Int
    let tileQuestTargetStep: Int
    let onClaim: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title + claim
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(quest.title)
                        .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(quest.description)
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onClaim) {
                    Text(quest.claimed ? "Done" : "Claim")
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(quest.isClaimable ? Color.green : Color(UIColor.systemGray4))
                        )
                        .foregroundStyle(quest.isClaimable ? .white : .secondary)
                }
                .disabled(!quest.isClaimable)
                .buttonStyle(.plain)
            }

            // Progress bar
            if quest.id == "daily_tile_reach" && tileQuestTargetStep > 0 {
                QuestMilestoneBar(
                    startStep: tileQuestTargetStep - 10,
                    targetStep: tileQuestTargetStep,
                    currentStep: highestTileStep
                )
                .padding(.vertical, 4)
            } else {
                HStack(spacing: 8) {
                    ProgressView(value: Double(min(quest.current, quest.target)), total: Double(quest.target))
                        .progressViewStyle(.linear)
                        .tint(quest.isComplete ? .green : .blue)

                    Text("\(min(quest.current, quest.target))/\(quest.target)")
                        .font(.avenirNext(size: GameFonts.caption2Size, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 50, alignment: .trailing)
                }
            }

            // Reward icons row
            DailyQuestRewardRow(rewards: quest.rewards)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(quest.isClaimable ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Daily Quest Reward Row

private struct DailyQuestRewardRow: View {
    let rewards: AchievementDef.Rewards

    private struct Item: Identifiable {
        let id = UUID()
        let text: String
        let assetName: String?
        let systemName: String?
        let color: Color
    }

    private var items: [Item] {
        var list: [Item] = []
        if let g = rewards.gems, g > 0 { list.append(Item(text: "\(g)", assetName: "gem", systemName: nil, color: .clear)) }
        if let h = rewards.hammers, h > 0 { list.append(Item(text: "\(h)", assetName: "hammer", systemName: nil, color: .clear)) }
        if let m = rewards.magnets, m > 0 { list.append(Item(text: "\(m)", assetName: "magnet", systemName: nil, color: .clear)) }
        if let s = rewards.swaps, s > 0 { list.append(Item(text: "\(s)", assetName: "swap", systemName: nil, color: .clear)) }
        if let sp = rewards.spins, sp > 0 { list.append(Item(text: "\(sp)", assetName: "spinthewheel", systemName: nil, color: .clear)) }
        if let b2 = rewards.boost2x, b2 > 0 { list.append(Item(text: "\(b2)×", assetName: "boost-2x", systemName: nil, color: .clear)) }
        if let b3 = rewards.boost3x, b3 > 0 { list.append(Item(text: "\(b3)×", assetName: nil, systemName: "3.circle.fill", color: .pink)) }
        if let b4 = rewards.boost4x, b4 > 0 { list.append(Item(text: "\(b4)×", assetName: nil, systemName: "4.circle.fill", color: .orange)) }
        return list
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items) { item in
                HStack(spacing: 3) {
                    if let asset = item.assetName {
                        Image(asset)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                    } else if let sys = item.systemName {
                        Image(systemName: sys)
                            .foregroundStyle(item.color)
                            .font(.system(size: 12))
                    }
                    Text(item.text)
                        .font(.avenirNext(size: GameFonts.caption2Size, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

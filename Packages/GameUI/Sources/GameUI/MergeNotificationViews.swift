import SwiftUI
import GameApp
import GameCore

struct UnlockedNotificationView: View {
    let value: Int
    let onClose: () -> Void
    @Environment(\.gameStore) private var gameStore
    @State private var showClaimOption = false
    @State private var selectedMultiplier = 1

    private var tileLabel: String {
        // For high-value tiles (Int.max), use step-based formatting from gameStore
        if value >= Int.max / 2 {
            let step = gameStore.state.highestTileStep
            return JourneyTileGenerator.formatTileAtStep(step)
        }
        return TileLabelFormatter.format(value)
    }

    private var journeyReward: (previous: String?, current: String, next: String?) {
        // For high-value tiles, use step-based progression
        if value >= Int.max / 2 {
            let step = gameStore.state.highestTileStep
            let currentLabel = JourneyTileGenerator.formatTileAtStep(step)
            let prevLabel = step > 0 ? JourneyTileGenerator.formatTileAtStep(step - 1) : nil
            let nextLabel = JourneyTileGenerator.formatTileAtStep(step + 1)
            return (prevLabel, currentLabel, nextLabel)
        }

        // Get journey tier labels for the progression
        if let tile = Tile.makeFromValue(value) {
            if let currentTier = JourneyAbbreviationTiers.tier(for: tile) {
                let prevTier = currentTier.order > 0 ?
                    JourneyAbbreviationTiers.tiers[safe: currentTier.order - 1] : nil
                let nextTier = JourneyAbbreviationTiers.tiers[safe: currentTier.order + 1]

                return (prevTier?.label, currentTier.label, nextTier?.label)
            }
        }
        // Default progression - use proper tile label format
        return (nil, tileLabel, nil)
    }

    private var gemReward: Int {
        // For high-value tiles, use step-based reward formula
        if value >= Int.max / 2 {
            let step = gameStore.state.highestTileStep
            // Formula: 50 gems for step 8 (512), then +2 per step
            if step >= 8 {
                return (50 + (step - 8) * 2) * selectedMultiplier
            }
            return 50 * selectedMultiplier
        }

        // Get gem reward from the reward curve based on tier
        if let tile = Tile.makeFromValue(value),
           let tierInfo = JourneyAbbreviationTiers.tier(for: tile) {
            // Base gems scale with tier order
            let base = 75 + tierInfo.order * 25
            let normalized = Double(tierInfo.order) / Double(max(1, JourneyAbbreviationTiers.tiers.count))
            let scale = 1.0 + normalized * 2.0
            return Int(Double(base) * scale) * selectedMultiplier
        }
        // Fallback for non-tier milestones
        return 50 * selectedMultiplier
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("EXCELLENT")
                .font(.title2.weight(.bold))
                .padding(.bottom, 8)

            // Journey progression tiles
            HStack(spacing: 12) {
                // Previous tier (if exists)
                if let prev = journeyReward.previous {
                    JourneyTileCard(label: prev, isPrimary: false, size: 80)
                }

                // Current unlocked tier (highlighted)
                JourneyTileCard(label: journeyReward.current, value: value, isPrimary: true, size: 100)
                    .overlay(alignment: .top) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                            .font(.title3)
                            .offset(y: -15)
                    }

                // Next tier (locked)
                if let next = journeyReward.next {
                    JourneyTileCard(label: next, isPrimary: false, size: 80, isLocked: true)
                }
            }
            .padding(.vertical, 8)

            // Reward section
            VStack(spacing: 12) {
                Text("Your Reward")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Image("gem")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                    Text("+\(gemReward)")
                        .font(.title2.weight(.semibold))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.cyan.opacity(0.15))
                .cornerRadius(12)
            }

            // Multiplier options
            if showClaimOption {
                MultiplierSelectorView(selectedMultiplier: $selectedMultiplier)
                    .padding(.vertical, 8)

                Button(action: {
                    // Claim with multiplier (watch ad if > 1)
                    gameStore.claimJourneyReward(coins: gemReward)
                    onClose()
                }) {
                    HStack {
                        if selectedMultiplier > 1 {
                            Image(systemName: "play.rectangle.fill")
                            Text("Claim ×\(selectedMultiplier)")
                        } else {
                            Text("Continue")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedMultiplier > 1 ? Color.cyan : Color.blue)
                    .cornerRadius(12)
                }
            } else {
                Button("Continue") {
                    showClaimOption = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .presentationDetents([.height(550)])
        .presentationDragIndicator(.visible)
    }
}

struct AddedNotificationView: View {
    let value: Int
    let onClose: () -> Void
    @Environment(\.gameStore) private var gameStore
    @State private var showClaimOption = false
    @State private var selectedMultiplier = 1

    // For high-value tiles, the added step is derived from highest step
    private var displayStep: Int {
        if value >= Int.max / 2 {
            // Added tiles appear at a step relative to the highest
            return max(0, gameStore.state.highestTileStep - 7)
        }
        return TileStepLabelFormatter.stepForValue(value, start: 2) ?? 0
    }

    private var tileLabel: String {
        if value >= Int.max / 2 {
            return JourneyTileGenerator.formatTileAtStep(displayStep)
        }
        return TileLabelFormatter.format(value)
    }

    private var journeyReward: (previous: String?, current: String, next: String?) {
        if value >= Int.max / 2 {
            let step = displayStep
            let currentLabel = JourneyTileGenerator.formatTileAtStep(step)
            let prevLabel = step > 0 ? JourneyTileGenerator.formatTileAtStep(step - 1) : nil
            let nextLabel = JourneyTileGenerator.formatTileAtStep(step + 1)
            return (prevLabel, currentLabel, nextLabel)
        }

        if let tile = Tile.makeFromValue(value) {
            if let currentTier = JourneyAbbreviationTiers.tier(for: tile) {
                let prevTier = currentTier.order > 0 ?
                    JourneyAbbreviationTiers.tiers[safe: currentTier.order - 1] : nil
                let nextTier = JourneyAbbreviationTiers.tiers[safe: currentTier.order + 1]
                return (prevTier?.label, currentTier.label, nextTier?.label)
            }
        }
        return (nil, tileLabel, nil)
    }

    private var gemReward: Int {
        // For high-value tiles, use step-based rewards
        if value >= Int.max / 2 {
            let step = displayStep
            if step >= 8 {
                return (30 + (step - 8)) * selectedMultiplier
            }
            return 30 * selectedMultiplier
        }

        // Spawn pool updates get smaller rewards than unlocks
        if let tile = Tile.makeFromValue(value),
           let tierInfo = JourneyAbbreviationTiers.tier(for: tile) {
            let base = 40 + tierInfo.order * 15
            let normalized = Double(tierInfo.order) / Double(max(1, JourneyAbbreviationTiers.tiers.count))
            let scale = 1.0 + normalized * 1.5
            return Int(Double(base) * scale) * selectedMultiplier
        }
        return 25 * selectedMultiplier
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("SPAWN POOL UPDATED")
                .font(.title2.weight(.bold))
                .padding(.bottom, 8)

            HStack(spacing: 12) {
                if let prev = journeyReward.previous {
                    JourneyTileCard(label: prev, isPrimary: false, size: 80)
                }

                JourneyTileCard(label: journeyReward.current, value: value, isPrimary: true, size: 100)
                    .overlay(alignment: .top) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                            .offset(y: -15)
                    }

                if let next = journeyReward.next {
                    JourneyTileCard(label: next, isPrimary: false, size: 80, isLocked: true)
                }
            }
            .padding(.vertical, 8)

            VStack(spacing: 12) {
                Text("Your Reward")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Image("gem")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                    Text("+\(gemReward)")
                        .font(.title2.weight(.semibold))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.cyan.opacity(0.15))
                .cornerRadius(12)
            }

            if showClaimOption {
                MultiplierSelectorView(selectedMultiplier: $selectedMultiplier)
                    .padding(.vertical, 8)

                Button(action: {
                    gameStore.claimJourneyReward(coins: gemReward)
                    onClose()
                }) {
                    HStack {
                        if selectedMultiplier > 1 {
                            Image(systemName: "play.rectangle.fill")
                            Text("Claim ×\(selectedMultiplier)")
                        } else {
                            Text("Continue")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedMultiplier > 1 ? Color.cyan : Color.blue)
                    .cornerRadius(12)
                }
            } else {
                Button("Continue") {
                    showClaimOption = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .presentationDetents([.height(550)])
        .presentationDragIndicator(.visible)
    }
}

struct ExcludedNotificationView: View {
    let value: Int
    let onClose: () -> Void
    @Environment(\.gameStore) private var gameStore
    @State private var showClaimOption = false
    @State private var selectedMultiplier = 1

    // For high-value tiles, the eliminated step is 14 below highest
    private var displayStep: Int {
        if value >= Int.max / 2 {
            return max(0, gameStore.state.highestTileStep - 14)
        }
        return TileStepLabelFormatter.stepForValue(value, start: 2) ?? 0
    }

    private var tileLabel: String {
        if value >= Int.max / 2 {
            return JourneyTileGenerator.formatTileAtStep(displayStep)
        }
        return TileLabelFormatter.format(value)
    }

    private var journeyReward: (previous: String?, current: String, next: String?) {
        if value >= Int.max / 2 {
            let step = displayStep
            let currentLabel = JourneyTileGenerator.formatTileAtStep(step)
            let prevLabel = step > 0 ? JourneyTileGenerator.formatTileAtStep(step - 1) : nil
            let nextLabel = JourneyTileGenerator.formatTileAtStep(step + 1)
            return (prevLabel, currentLabel, nextLabel)
        }

        if let tile = Tile.makeFromValue(value) {
            if let currentTier = JourneyAbbreviationTiers.tier(for: tile) {
                let prevTier = currentTier.order > 0 ?
                    JourneyAbbreviationTiers.tiers[safe: currentTier.order - 1] : nil
                let nextTier = JourneyAbbreviationTiers.tiers[safe: currentTier.order + 1]
                return (prevTier?.label, currentTier.label, nextTier?.label)
            }
        }
        return (nil, tileLabel, nil)
    }

    private var gemReward: Int {
        // For high-value tiles, use step-based rewards
        if value >= Int.max / 2 {
            let step = displayStep
            if step >= 8 {
                return (20 + (step - 8)) * selectedMultiplier
            }
            return 20 * selectedMultiplier
        }

        // Eliminations get smallest rewards
        if let tile = Tile.makeFromValue(value),
           let tierInfo = JourneyAbbreviationTiers.tier(for: tile) {
            let base = 25 + tierInfo.order * 10
            let normalized = Double(tierInfo.order) / Double(max(1, JourneyAbbreviationTiers.tiers.count))
            let scale = 1.0 + normalized * 1.0
            return Int(Double(base) * scale) * selectedMultiplier
        }
        return 15 * selectedMultiplier
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("TILE ELIMINATED")
                .font(.title2.weight(.bold))
                .padding(.bottom, 8)

            HStack(spacing: 12) {
                if let prev = journeyReward.previous {
                    JourneyTileCard(label: prev, isPrimary: false, size: 80)
                }

                JourneyTileCard(label: journeyReward.current, value: value, isPrimary: true, size: 100)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.title2)
                            .offset(x: 8, y: -8)
                    }

                if let next = journeyReward.next {
                    JourneyTileCard(label: next, isPrimary: false, size: 80, isLocked: true)
                }
            }
            .padding(.vertical, 8)

            VStack(spacing: 12) {
                Text("Your Reward")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Image("gem")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                    Text("+\(gemReward)")
                        .font(.title2.weight(.semibold))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.cyan.opacity(0.15))
                .cornerRadius(12)
            }

            if showClaimOption {
                MultiplierSelectorView(selectedMultiplier: $selectedMultiplier)
                    .padding(.vertical, 8)

                Button(action: {
                    gameStore.claimJourneyReward(coins: gemReward)
                    onClose()
                }) {
                    HStack {
                        if selectedMultiplier > 1 {
                            Image(systemName: "play.rectangle.fill")
                            Text("Claim ×\(selectedMultiplier)")
                        } else {
                            Text("Continue")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedMultiplier > 1 ? Color.cyan : Color.blue)
                    .cornerRadius(12)
                }
            } else {
                Button("Continue") {
                    showClaimOption = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .presentationDetents([.height(550)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Helper Views

struct JourneyTileCard: View {
    let label: String
    var value: Int? = nil  // Optional tile value for Theme.color lookup
    var isPrimary: Bool = false
    var size: CGFloat = 100
    var accentColor: Color = .orange  // Fallback if value not provided
    var isLocked: Bool = false

    private var tileColor: Color {
        if let value = value {
            return Theme.color(for: value)
        }
        return accentColor
    }

    private var textColor: Color {
        if isLocked {
            return .gray
        }
        if isPrimary {
            if let value = value {
                return Theme.textColor(for: value)
            }
            return .white
        }
        return .secondary
    }

    var body: some View {
        Text(label)
            .font(.system(size: isPrimary ? 28 : 20, weight: isPrimary ? .bold : .semibold, design: .rounded))
            .foregroundStyle(textColor)
            .frame(width: size, height: size)
            .background(
                Group {
                    if isPrimary {
                        LinearGradient(
                            colors: [tileColor, tileColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else if isLocked {
                        Color.gray.opacity(0.15)
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: isPrimary ? 16 : 12))
            .shadow(color: isPrimary ? tileColor.opacity(0.5) : .clear, radius: isPrimary ? 8 : 0)
            .overlay(alignment: .topTrailing) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.gray)
                        .font(.caption)
                        .offset(x: 5, y: -5)
                }
            }
    }
}

struct MultiplierSelectorView: View {
    @Binding var selectedMultiplier: Int
    private let multipliers = [2, 3, 4, 5, 4, 3, 2]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(Array(multipliers.enumerated()), id: \.offset) { index, mult in
                    Text("×\(mult)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: colorForMultiplier(mult),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(selectedMultiplier == mult && index == 3 ? Color.white : Color.clear, lineWidth: 2)
                        )
                        .onTapGesture {
                            if index == 3 {  // Center position (×5)
                                selectedMultiplier = mult
                            }
                        }
                }
            }

            // Indicator triangle
            Image(systemName: "arrowtriangle.up.fill")
                .foregroundStyle(.gray)
                .font(.caption)
        }
        .padding(.horizontal)
    }

    private func colorForMultiplier(_ mult: Int) -> [Color] {
        switch mult {
        case 2: return [Color.pink, Color.pink.opacity(0.8)]
        case 3: return [Color.orange, Color.orange.opacity(0.8)]
        case 4: return [Color.yellow, Color.yellow.opacity(0.8)]
        case 5: return [Color.green, Color.green.opacity(0.8)]
        default: return [Color.gray, Color.gray.opacity(0.8)]
        }
    }
}

// MARK: - Collection Extension

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

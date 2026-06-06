import SwiftUI
import GameApp
import GameCore

// Celebration phrases are pre-selected in GameStore.pickUniquePhrases()
// and passed through to each notification view via the celebrationPhrase parameter.


struct UnlockedNotificationView: View {
    let value: Int
    let celebrationPhrase: String
    let onClose: () -> Void
    @Environment(\.gameStore) private var gameStore
    @Environment(\.audio) private var audioService
    @Environment(\.currentTheme) private var currentTheme

    // Bouncing spinner state
    @State private var currentIndex: Int = 0
    @State private var direction: Int = 1  // 1 = forward, -1 = backward
    @State private var isSpinning = false
    @State private var hasStopped = false  // Shows reward after stopping
    @State private var didClaim = false
    @State private var animationTimer: Timer?
    @State private var spinStartTime: Date?
    private let maxSpinDuration: TimeInterval = 10  // Auto-stop after 10 seconds

    // Spinner configuration - 7 cells that slide back and forth
    private let multipliers: [Int] = [2, 3, 4, 5, 4, 3, 2]
    private let cellWidth: CGFloat = 44
    private let tickInterval: TimeInterval = 0.08  // time per cell

    private var isHighValue: Bool {
        value >= Int.max / 2
    }

    private var isInfinity: Bool {
        // Check if the tile label is infinity
        tileLabel == "∞" || displayStep > 817
    }

    private var isOneBeforeInfinity: Bool {
        // 873bz is at step 817, one tile before infinity
        displayStep == 817 || tileLabel == "873bz"
    }

    private var displayStep: Int {
        if isHighValue {
            return gameStore.state.highestTileStep
        }
        return TileStepLabelFormatter.stepForValue(value, start: 2) ?? 0
    }

    private var tileLabel: String {
        if isHighValue {
            return JourneyTileGenerator.formatTileAtStep(displayStep)
        }
        return TileLabelFormatter.format(value)
    }

    private var journeyReward: (previous: (label: String, step: Int)?, current: (label: String, step: Int), next: (label: String, step: Int)?) {
        let step = displayStep
        
        // Always use step-based tile labels for correct doubling sequence
        let currentLabel = JourneyTileGenerator.formatTileAtStep(step)
        let prevLabel = step > 0 ? JourneyTileGenerator.formatTileAtStep(step - 1) : nil
        let nextLabel = JourneyTileGenerator.formatTileAtStep(step + 1)
        
        return (
            prevLabel.map { ($0, step - 1) },
            (currentLabel, step),
            (nextLabel, step + 1)
        )
    }

    private var currentMultiplier: Int {
        multipliers[currentIndex]
    }

    private var baseReward: Int {
        // Use pending unlock reward if available, otherwise calculate from tier
        if let base = gameStore.pendingUnlockRewardBase {
            return base
        }

        // For high-value tiles, use step-based reward formula
        if value >= Int.max / 2 {
            let step = gameStore.state.highestTileStep
            // Formula: 50 gems for step 8 (512), then +2 per step
            if step >= 8 {
                return 50 + (step - 8) * 2
            }
            return 50
        }

        // Get gem reward from the reward curve based on tier
        if let tile = Tile.makeFromValue(value),
           let tierInfo = JourneyAbbreviationTiers.tier(for: tile) {
            // Base gems scale with tier order
            let base = 75 + tierInfo.order * 25
            let normalized = Double(tierInfo.order) / Double(max(1, JourneyAbbreviationTiers.tiers.count))
            let scale = 1.0 + normalized * 2.0
            return Int(Double(base) * scale)
        }
        // Fallback for non-tier milestones
        return 50
    }

    private var totalReward: Int {
        baseReward * currentMultiplier
    }

    var body: some View {
        VStack(spacing: 12) {
            // Celebration header
            Text(displayPhrase)
                .font(.avenirNext(size: GameFonts.title2Size, weight: .bold))
                .foregroundStyle(.orange)

            // Title
            Text("NEW TILE UNLOCKED")
                .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .semibold))
                .foregroundStyle(.secondary)

            // Journey progression tiles
            HStack(spacing: 8) {
                // Previous tier (if exists)
                if let prev = journeyReward.previous {
                    JourneyTileCard(label: prev.label, step: prev.step, isPrimary: false, size: 40, theme: currentTheme)
                }

                // Current unlocked tier (highlighted)
                JourneyTileCard(label: journeyReward.current.label, step: journeyReward.current.step, isPrimary: true, size: 50, theme: currentTheme)
                    .overlay(alignment: .top) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption2)
                            .offset(y: -8)
                    }

                // Next tier (locked)
                if let next = journeyReward.next {
                    JourneyTileCard(label: next.label, step: next.step, isPrimary: false, size: 40, isLocked: true, theme: currentTheme)
                }
            }

            if hasStopped {
                // Show final reward after stopping
                VStack(spacing: 12) {
                    Text("You Won!")
                        .font(.avenirNext(size: GameFonts.title3Size, weight: .bold))
                        .foregroundStyle(.green)

                    HStack(spacing: 8) {
                        Image("gem")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                        Text("+\(totalReward)")
                            .font(.avenirNext(size: GameFonts.title1Size, weight: .heavy))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(12)

                    Text("\(currentMultiplier)x multiplier applied!")
                        .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)

                // Collect button
                Button(action: collectReward) {
                    Text("Collect")
                        .font(.avenirNext(size: GameFonts.headlineSize, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .cornerRadius(12)
                }
            } else {
                // Reward section with spinner
                VStack(spacing: 8) {
                    Text("Your Reward")
                        .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Image("gem")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text("+\(totalReward)")
                            .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.15), value: totalReward)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.cyan.opacity(0.15))
                    .cornerRadius(10)
                }

                // Bouncing multiplier spinner
                spinnerView
                    .padding(.vertical, 4)

                // Stop button
                Button(action: stopAndShowReward) {
                    Text("STOP!")
                        .font(.avenirNext(size: GameFonts.headlineSize, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
        .onAppear {
            didClaim = false
            hasStopped = false
            startSpinner()
        }
        .onDisappear {
            stopSpinner()
            finalizeReward()
        }
    }

    // MARK: - Physics Spinner View

    private var spinnerView: some View {
        VStack(spacing: 0) {
            // Moving peg/indicator pointing down
            GeometryReader { geo in
                let stripWidth = cellWidth * CGFloat(multipliers.count)
                let startX = (geo.size.width - stripWidth) / 2
                let pegX = startX + CGFloat(currentIndex) * cellWidth + cellWidth / 2

                Triangle()
                    .fill(Color.white)
                    .frame(width: 20, height: 12)
                    .position(x: pegX, y: 6)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .animation(.easeInOut(duration: tickInterval * 0.8), value: currentIndex)
            }
            .frame(height: 14)

            // Fixed strip of multipliers
            HStack(spacing: 0) {
                ForEach(0..<multipliers.count, id: \.self) { index in
                    multiplierCell(for: index)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
        }
    }

    private func multiplierCell(for index: Int) -> some View {
        let colors: [Color] = [
            Color(hex: "E646A0"),  // 2x - pink
            Color(hex: "F5962A"),  // 3x - orange
            Color(hex: "F4C229"),  // 4x - yellow
            Color(hex: "61C459"),  // 5x - green
            Color(hex: "F4C229"),  // 4x - yellow
            Color(hex: "F5962A"),  // 3x - orange
            Color(hex: "E646A0")   // 2x - pink
        ]
        return Text("X\(multipliers[index])")
            .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .heavy))
            .foregroundColor(.white)
            .frame(width: cellWidth, height: 48)
            .background(colors[index])
    }

    // MARK: - Animation

    private func startSpinner() {
        isSpinning = true
        currentIndex = 0
        direction = 1
        spinStartTime = Date()

        // Timer to move through multipliers
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [self] _ in
            Task { @MainActor in
                self.moveToNext()
            }
        }
    }

    private func stopSpinner() {
        animationTimer?.invalidate()
        animationTimer = nil
        isSpinning = false
        Task { await audioService.stopTickSound() }
    }

    private func moveToNext() {
        guard isSpinning else { return }

        // Auto-stop after max duration to prevent infinite tick sound
        if let start = spinStartTime, Date().timeIntervalSince(start) >= maxSpinDuration {
            stopAndShowReward()
            return
        }

        // Play tick sound
        Task { await audioService.playSfx(name: "tick") }

        // Move to next position
        let nextIndex = currentIndex + direction

        // Bounce at edges
        if nextIndex >= multipliers.count {
            // Hit the end, reverse direction
            direction = -1
            currentIndex = multipliers.count - 2
        } else if nextIndex < 0 {
            // Hit the start, reverse direction
            direction = 1
            currentIndex = 1
        } else {
            currentIndex = nextIndex
        }
    }

    // MARK: - Reward Claiming

    private func stopAndShowReward() {
        // Stop spinner and show the reward
        stopSpinner()
        withAnimation {
            hasStopped = true
        }
    }

    private func collectReward() {
        // Finalize and close
        finalizeReward()
        onClose()
    }

    private func finalizeReward() {
        guard !didClaim else { return }
        didClaim = true
        gameStore.claimPendingUnlockReward(multiplier: currentMultiplier)
    }

    // MARK: - Celebration Phrases

    /// Returns the special milestone override phrase, or the pre-selected unique phrase.
    private var displayPhrase: String {
        // Check for infinity first
        if isInfinity {
            let infinityCount = countInfinityTilesOnBoard()
            if infinityCount >= 2 {
                return "You made a second infinity tile! Keep going!"
            }
            return "Congrats! You've reached Infinity!"
        }

        // One tile before infinity
        if isOneBeforeInfinity {
            return "One tile away from Infinity! Keep going!"
        }

        // Check for case-sensitive labels (billions "1B" vs quadrillions "1b")
        if tileLabel == "1B" {
            return "You're in the billions! Keep going!"
        }
        if tileLabel == "1b" {
            return "You're in the quadrillions! Keep going!"
        }

        // Check for specific milestone tile labels (case-sensitive to distinguish
        // real tiers like "1K" (thousands) from letter-suffix tiers like "1k" (10^42))
        switch tileLabel {
        case "512":
            return "Good Job! First milestone unlocked!"
        case "1024", "1K":
            return "Magnificent! You're in the thousands!"
        case "524K":
            return "Incredible! Almost in the millions!"
        case "1M":
            return "You're in the millions! Keep going!"
        case "536M":
            return "Almost in the billions! Keep going!"
        case "1a":
            return "You're in the trillions! Keep going!"
        case "288b":
            return "50th milestone unlocked! Keep going!"
        case "324g":
            return "100th Milestone Unlocked! Keep going!"
        case "411q":
            return "200th milestone unlocked! Keep Going!"
        case "2048":
            return "Amazing! You unlocked 2048!"
        default:
            break
        }

        // Use the pre-selected unique phrase from the milestone sequence
        return celebrationPhrase
    }

    private func countInfinityTilesOnBoard() -> Int {
        var count = 0
        for row in 0..<gameStore.state.board.height {
            for col in 0..<gameStore.state.board.width {
                let pos = Position(row: row, col: col)
                if gameStore.state.board[pos]?.isInfinity == true {
                    count += 1
                }
            }
        }
        return count
    }
}

// Triangle shape for the peg indicator
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct AddedNotificationView: View {
    let value: Int
    let celebrationPhrase: String
    let onClose: () -> Void
    @Environment(\.gameStore) private var gameStore
    @Environment(\.currentTheme) private var currentTheme
    @State private var showClaimOption = false
    @State private var selectedMultiplier = 1

    private var isHighValue: Bool {
        value >= Int.max / 2
    }

    // For high-value tiles, the added step is derived from highest step
    private var displayStep: Int {
        if isHighValue {
            let highestStep = gameStore.state.highestTileStep
            // The actual spawn pool max is highestStep - 5
            // (from spawnStepNearHighest: stepsBelow = 5 for step >= 17)
            return max(0, highestStep - 5)
        }
        return TileStepLabelFormatter.stepForValue(value, start: 2) ?? 0
    }

    private var tileLabel: String {
        if isHighValue {
            return JourneyTileGenerator.formatTileAtStep(displayStep)
        }
        return TileLabelFormatter.format(value)
    }

    private var journeyReward: (previous: (label: String, step: Int)?, current: (label: String, step: Int), next: (label: String, step: Int)?) {
        let step = displayStep
        
        // Always use step-based tile labels for correct doubling sequence
        let currentLabel = JourneyTileGenerator.formatTileAtStep(step)
        let prevLabel = step > 0 ? JourneyTileGenerator.formatTileAtStep(step - 1) : nil
        let nextLabel = JourneyTileGenerator.formatTileAtStep(step + 1)
        
        return (
            prevLabel.map { ($0, step - 1) },
            (currentLabel, step),
            (nextLabel, step + 1)
        )
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
            // Celebration header
            Text(displayPhrase)
                .font(.avenirNext(size: GameFonts.title2Size, weight: .bold))
                .foregroundStyle(.green)

            // Title
            Text("SPAWN POOL UPDATED")
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            HStack(spacing: 8) {
                if let prev = journeyReward.previous {
                    JourneyTileCard(label: prev.label, step: prev.step, isPrimary: false, size: 44, theme: currentTheme)
                }

                JourneyTileCard(label: journeyReward.current.label, step: journeyReward.current.step, isPrimary: true, size: 56, theme: currentTheme)
                    .overlay(alignment: .top) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .offset(y: -10)
                    }

                if let next = journeyReward.next {
                    JourneyTileCard(label: next.label, step: next.step, isPrimary: false, size: 44, isLocked: true, theme: currentTheme)
                }
            }

            // No reward for adding tiles - just continue
            Button(action: onClose) {
                Text("Continue")
                    .font(.avenirNext(size: GameFonts.headlineSize, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var displayPhrase: String {
        // Check for 2048 (step 10)
        if tileLabel == "2048" || displayStep == 10 {
            return "Great! First block added!"
        }
        return celebrationPhrase
    }
}

struct ExcludedNotificationView: View {
    let value: Int
    let celebrationPhrase: String
    let onClose: () -> Void
    @Environment(\.gameStore) private var gameStore
    @Environment(\.currentTheme) private var currentTheme
    @State private var showClaimOption = false
    @State private var selectedMultiplier = 1

    private var isHighValue: Bool {
        value >= Int.max / 2
    }

    private var isAtInfinity: Bool {
        // Check if we've reached infinity (highest tile is infinity)
        gameStore.state.highestTileStep > 817
    }

    // For high-value tiles, eliminated step = milestone step - 12
    // Matches applyMilestoneEliminationForStep: thresholdStep = step - 12
    private var displayStep: Int {
        if isHighValue {
            let highestStep = gameStore.state.highestTileStep
            return max(0, highestStep - 12)
        }
        return TileStepLabelFormatter.stepForValue(value, start: 2) ?? 0
    }

    private var tileLabel: String {
        if isHighValue {
            return JourneyTileGenerator.formatTileAtStep(displayStep)
        }
        return TileLabelFormatter.format(value)
    }

    private var journeyReward: (previous: (label: String, step: Int)?, current: (label: String, step: Int), next: (label: String, step: Int)?) {
        let step = displayStep

        if isHighValue {
            let currentLabel = JourneyTileGenerator.formatTileAtStep(step)
            let prevLabel = step > 0 ? JourneyTileGenerator.formatTileAtStep(step - 1) : nil
            let nextLabel = JourneyTileGenerator.formatTileAtStep(step + 1)
            return (
                prevLabel.map { ($0, step - 1) },
                (currentLabel, step),
                (nextLabel, step + 1)
            )
        }

        if let tile = Tile.makeFromValue(value) {
            if let currentTier = JourneyAbbreviationTiers.tier(for: tile) {
                let prevTier = currentTier.order > 0 ?
                    JourneyAbbreviationTiers.tiers[safe: currentTier.order - 1] : nil
                let nextTier = JourneyAbbreviationTiers.tiers[safe: currentTier.order + 1]
                return (
                    prevTier.map { ($0.label, step - 1) },
                    (currentTier.label, step),
                    nextTier.map { ($0.label, step + 1) }
                )
            }
        }
        return (nil, (tileLabel, step), nil)
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
            // Celebration header
            Text(displayPhrase)
                .font(.avenirNext(size: GameFonts.title2Size, weight: .bold))
                .foregroundStyle(.cyan)

            // Title
            Text("TILE ELIMINATED")
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            HStack(spacing: 8) {
                if let prev = journeyReward.previous {
                    JourneyTileCard(label: prev.label, step: prev.step, isPrimary: false, size: 44, theme: currentTheme)
                }

                JourneyTileCard(label: journeyReward.current.label, step: journeyReward.current.step, isPrimary: true, size: 56, theme: currentTheme)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                            .offset(x: 6, y: -6)
                    }

                if let next = journeyReward.next {
                    JourneyTileCard(label: next.label, step: next.step, isPrimary: false, size: 44, isLocked: true, theme: currentTheme)
                }
            }

            // No reward for eliminating tiles - just continue
            Button(action: onClose) {
                Text("Continue")
                    .font(.avenirNext(size: GameFonts.headlineSize, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var displayPhrase: String {
        // Special phrase for infinity
        if isAtInfinity {
            return "Congratulations! Can you make another Infinity?"
        }
        // Check for 2048 (step 10)
        if tileLabel == "2048" || displayStep == 10 {
            return "Awesome! First block eliminated!"
        }
        return celebrationPhrase
    }
}

// MARK: - Helper Views

struct JourneyTileCard: View {
    let label: String
    var value: Int? = nil  // Optional tile value for Theme.color lookup
    var step: Int? = nil   // Optional step for high-value tiles
    var isPrimary: Bool = false
    var size: CGFloat = 100
    var accentColor: Color = .orange  // Fallback if value not provided
    var isLocked: Bool = false
    var theme: ThemeDescriptor? = nil

    private var tileColor: Color {
        // Use step-based color for high-value tiles
        if let step = step {
            if let theme { return theme.colorForStep(step) }
            return Theme.colorForStep(step)
        }
        if let value = value {
            // For high-value tiles (Int.max), try to get step from value
            if value >= Int.max / 2 {
                // Can't determine step from Int.max, use accent color
                return accentColor
            }
            if let theme { return theme.color(for: value) }
            return Theme.color(for: value)
        }
        return accentColor
    }

    private var textColor: Color {
        if isLocked {
            return .gray
        }
        if isPrimary {
            // Use step-based text color for high-value tiles
            if let step = step {
                if let theme { return theme.textColorForStep(step) }
                return Theme.textColorForStep(step)
            }
            if let value = value {
                if value >= Int.max / 2 {
                    return .white
                }
                return Theme.textColor(for: value)
            }
            return .white
        }
        return .secondary
    }

    var body: some View {
        Text(label)
            .font(.avenirNext(size: isPrimary ? size * 0.32 : size * 0.30, weight: isPrimary ? .bold : .semibold))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
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
                        .font(.avenirNext(size: 14, weight: .bold))
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

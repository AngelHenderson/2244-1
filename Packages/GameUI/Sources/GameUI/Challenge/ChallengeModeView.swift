import SwiftUI
import GameCore
import GameApp

public struct ChallengeModeView: View {
    @Environment(\.challengeStore) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var scrollViewProxy: ScrollViewProxy? = nil
    @State private var currentTime = Date()  // For countdown timer updates
    @State private var selectedChallenge: Challenge? = nil
    @State private var showIconLegend = false
    @State private var showLockedAlert = false
    @State private var lockedTileLabel = ""

    public var playerHighestTileStep: Int
    public var onPlay: ((Challenge) -> Void)?

    public init(playerHighestTileStep: Int = 0, onPlay: ((Challenge) -> Void)? = nil) {
        self.playerHighestTileStep = playerHighestTileStep
        self.onPlay = onPlay
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        ZStack(alignment: .leading) {
                            timelineSpine

                            VStack(spacing: 24) {
                                ForEach(Array(store.challenges.enumerated().reversed()), id: \.element.id) { index, challenge in
                                    challengeCardView(for: challenge, index: index)
                                }
                            }
                            .padding(.horizontal, 48)
                            .padding(.vertical, 32)
                        }
                        .padding(.horizontal, 16)
                    }
                    .onAppear {
                        scrollViewProxy = proxy
                        // Default to active challenge if none selected
                        if selectedChallenge == nil {
                            selectedChallenge = store.activeChallenge
                        }
                        if let active = store.activeChallenge {
                            proxy.scrollTo(active.id, anchor: .center)
                        } else if let pending = store.pendingUnlockChallenge {
                            proxy.scrollTo(pending.challenge.id, anchor: .center)
                        }
                    }
                }

                playButton
            }
            .navigationTitle("CHALLENGE MODE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        GemBalancePill()
                        Button {
                            showIconLegend = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        Button("Done") { dismiss() }
                    }
                }
            }
            .sheet(isPresented: $showIconLegend) {
                IconLegendSheet()
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { time in
                currentTime = time
            }
        }
        .alert("Tile Too Low", isPresented: $showLockedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Sorry! You do not have a high enough tile to unlock this. You need a \(lockedTileLabel) tile.")
        }
    }

    @ViewBuilder
    private func challengeCardView(for challenge: Challenge, index: Int) -> some View {
        let status = store.status(for: challenge)
        let isSelected = selectedChallenge?.id == challenge.id
        Button {
            if status.isPlayable {
                selectedChallenge = challenge
            } else {
                if let targetStep = challenge.targetTile {
                    lockedTileLabel = TileStepLabelFormatter.labelForStep(targetStep, start: 2)
                } else {
                    lockedTileLabel = "higher"
                }
                showLockedAlert = true
            }
        } label: {
            GeometryReader { geo in
                let cardWidth = geo.size.width * 0.5
                ChallengeCard(
                    challenge: challenge,
                    challengeNumber: index + 1,
                    status: status,
                    currentTime: currentTime,
                    isSelected: isSelected
                )
                .frame(width: cardWidth)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .buttonStyle(.plain)
        .frame(height: 150)
        .id(challenge.id)
    }

    private var timelineSpine: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 4)
                .frame(height: geo.size.height)
                .padding(.leading, 36)
        }
    }

    private var playButton: some View {
        Group {
            if let selected = selectedChallenge {
                // A playable challenge is selected
                let challengeNumber = (store.challenges.firstIndex(where: { $0.id == selected.id }) ?? 0) + 1
                let isReplay = store.completedIds.contains(selected.id)
                Button {
                    onPlay?(selected)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: isReplay ? "arrow.clockwise" : "play.fill")
                        Text(isReplay ? "Replay Challenge \(challengeNumber)" : "Play Challenge \(challengeNumber)")
                    }
                    .font(.avenirNext(size: GameFonts.title3Size, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if let pending = store.pendingUnlockChallenge {
                // Pending unlock - show countdown
                VStack(spacing: 8) {
                    Text("Next Challenge Unlocks In")
                        .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text(formatTimeRemaining(until: pending.unlockDate))
                        .font(.avenirNext(size: GameFonts.title2Size, weight: .bold))
                        .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.15))
                )
            } else {
                // All completed or no challenges
                Text("All Challenges Completed!")
                    .font(.avenirNext(size: GameFonts.title3Size, weight: .semibold))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func formatTimeRemaining(until date: Date) -> String {
        let remaining = max(0, date.timeIntervalSince(currentTime))
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

private struct ChallengeCard: View {
    let challenge: Challenge
    let challengeNumber: Int
    let status: ChallengeStatus
    let currentTime: Date
    var isSelected: Bool = false

    @State private var showingRewards = false

    // Format tile target for display using TileStepLabelFormatter
    private var targetTileLabel: String {
        guard let targetTile = challenge.targetTile else { return "??" }

        // Special case for Infinity
        if targetTile == Int.max {
            return "∞"
        }

        // Use TileStepLabelFormatter for proper step-to-label conversion
        return TileStepLabelFormatter.labelForStep(targetTile, start: 2)
    }

    // Renders the target tile with proper colors
    @ViewBuilder
    private var targetTileView: some View {
        let tileSize: CGFloat = 55

        if let targetTile = challenge.targetTile {
            if targetTile == Int.max {
                // Infinity tile - special rainbow gradient
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue, .cyan, .green, .yellow, .orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: tileSize, height: tileSize)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                    Text("∞")
                        .font(.avenirNext(size: tileSize * 0.5, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .opacity(isLocked ? 0.5 : 1.0)
            } else {
                // Regular tile with theme colors - targetTile is a step value
                let tileColor = Theme.colorForStep(targetTile)
                let textColor = Theme.textColorForStep(targetTile)

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(tileColor)
                        .frame(width: tileSize, height: tileSize)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                    Text(targetTileLabel)
                        .font(.avenirNext(size: fontSize(for: targetTileLabel, tileSize: tileSize), weight: .heavy))
                        .foregroundStyle(textColor)
                        .minimumScaleFactor(0.5)
                        .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                }
                .opacity(isLocked ? 0.5 : 1.0)
            }
        } else {
            // Fallback for missing target
            Text("??")
                .font(.avenirNext(size: 48, weight: .heavy))
                .foregroundStyle(.secondary)
        }
    }

    private func fontSize(for label: String, tileSize: CGFloat) -> CGFloat {
        let digitCount = label.count
        if digitCount <= 2 { return tileSize * 0.40 }
        if digitCount == 3 { return tileSize * 0.36 }
        if digitCount == 4 { return tileSize * 0.32 }
        return tileSize * 0.26
    }

    private var isPendingUnlock: Bool {
        if case .pendingUnlock = status { return true }
        return false
    }

    private var unlockDate: Date? {
        if case .pendingUnlock(let date) = status { return date }
        return nil
    }

    /// Formats the reward for display, showing gems, power-ups, boosts, or spins
    /// Shows a treasure box for multiple rewards (tap to view details)
    @ViewBuilder
    private var rewardLabel: some View {
        let reward = challenge.reward
        let parts = buildRewardParts(reward)

        if parts.count > 1 {
            // Multiple rewards - show treasure box, tap to view
            HStack(spacing: 4) {
                Image(systemName: "shippingbox.fill")
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                Text("Rewards")
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .semibold))
            }
            .onTapGesture {
                showingRewards = true
            }
            .popover(isPresented: $showingRewards) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rewards")
                        .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                        .padding(.bottom, 4)
                    ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                        HStack(spacing: 6) {
                            Image(systemName: part.icon)
                                .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                                .frame(width: 20)
                            Text(part.text)
                                .font(.avenirNext(size: GameFonts.bodySize, weight: .medium))
                        }
                    }
                }
                .padding()
                .presentationCompactAdaptation(.popover)
            }
        } else if let part = parts.first {
            // Single reward - show specific icon
            HStack(spacing: 4) {
                Image(systemName: part.icon)
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                Text(part.text)
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .semibold))
            }
        }
    }

    private func buildRewardParts(_ reward: ChallengeReward) -> [(icon: String, text: String)] {
        var parts: [(icon: String, text: String)] = []

        // Gems
        if reward.coins > 0 {
            parts.append((icon: "diamond.fill", text: "\(reward.coins)"))
        }

        // Power-ups
        for (powerUp, count) in reward.powerUps.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let name: String
            let icon: String
            switch powerUp {
            case .hammer:
                name = "Hammer"
                icon = "hammer.fill"
            case .swap:
                name = "Swap"
                icon = "arrow.left.arrow.right"
            case .magnet:
                name = "MegaMerge"
                icon = "dot.radiowaves.left.and.right"
            case .shuffle:
                name = "Shuffle"
                icon = "shuffle"
            case .undo:
                name = "Undo"
                icon = "arrow.uturn.backward"
            case .double:
                name = "Double"
                icon = "plus.forwardslash.minus"
            }
            parts.append((icon: icon, text: "\(count) \(name)"))
        }

        // Score boosts
        for (multiplier, count) in reward.scoreBoosts.sorted(by: { $0.key < $1.key }) {
            parts.append((icon: "bolt.fill", text: "\(count)x \(multiplier)X"))
        }

        // Spins
        if reward.spins > 0 {
            parts.append((icon: "arrow.trianglehead.2.clockwise.rotate.90", text: "\(reward.spins) Spin"))
        }

        return parts
    }

    var body: some View {
        VStack(spacing: 6) {
            Text("Challenge \(challengeNumber)")
                .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .semibold))
                .foregroundStyle(.secondary)

            targetTileView

            VStack(spacing: 4) {
                statusText

                if !isCompleted {
                    rewardLabel
                        .foregroundStyle(status == .active ? .orange : .secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 3)
        )
        .overlay(alignment: .topTrailing) {
            statusIcon
                .padding(12)
        }
        .overlay(alignment: .leading) {
            HStack(spacing: 0) {
                // Horizontal line connecting spine to dot
                Rectangle()
                    .fill(nodeFill)
                    .frame(width: 150, height: 3)
                // Dot
                Circle()
                    .fill(nodeFill)
                    .frame(width: 12, height: 12)
            }
            .offset(x: -162)
        }
        .opacity(isLocked ? 0.7 : 1.0)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .locked:
            EmptyView()
        case .pendingUnlock:
            Image(systemName: "clock.fill")
                .foregroundStyle(.orange)
        case .active:
            EmptyView()
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch status {
        case .active:
            VStack(spacing: 4) {
                Text(challenge.name)
                    .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                Text(challenge.description)
                    .font(.avenirNext(size: GameFonts.footnoteSize, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        case .completed:
            Text("Completed")
                .font(.avenirNext(size: GameFonts.footnoteSize, weight: .medium))
                .foregroundStyle(.green)
        case .pendingUnlock(let unlockDate):
            VStack(spacing: 4) {
                Text("Unlocks in")
                    .font(.avenirNext(size: GameFonts.footnoteSize, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(formatTimeRemaining(until: unlockDate))
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                    .foregroundStyle(.orange)
            }
        case .locked:
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                Text("Locked")
            }
            .font(.avenirNext(size: GameFonts.footnoteSize, weight: .medium))
            .foregroundStyle(.secondary)
        }
    }

    private var isLocked: Bool {
        status == .locked
    }

    private var isCompleted: Bool {
        status == .completed
    }

    private var borderColor: Color {
        if isSelected {
            return .blue
        }
        switch status {
        case .active:
            return .green
        case .pendingUnlock:
            return .orange
        default:
            return .clear
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        switch status {
        case .completed:
            Color(UIColor.systemGray6)
        case .active:
            LinearGradient(
                colors: [
                    Color(UIColor.systemGray6),
                    Color(UIColor.systemGray5).opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .pendingUnlock:
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.15),
                    Color(UIColor.systemGray5).opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .locked:
            Color(UIColor.systemGray5).opacity(0.6)
        }
    }

    private var nodeFill: Color {
        switch status {
        case .active:
            return .green
        case .pendingUnlock:
            return .orange
        case .completed:
            return .secondary.opacity(0.6)
        case .locked:
            return .secondary.opacity(0.3)
        }
    }

    private func formatTimeRemaining(until date: Date) -> String {
        let remaining = max(0, date.timeIntervalSince(currentTime))
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Icon Legend View

private struct IconLegendSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let legendItems: [(icon: String, name: String, description: String)] = [
        ("diamond.fill", "Gems", "Currency to spend in shop"),
        ("hammer.fill", "Hammer", "Destroy any tile"),
        ("arrow.left.arrow.right", "Swap", "Swap two tiles"),
        ("dot.radiowaves.left.and.right", "MegaMerge", "Pull matching tiles together"),
        ("arrow.trianglehead.2.clockwise.rotate.90", "Spin", "Bonus spin on reward wheel"),
        ("2.circle.fill", "2× Boost", "Double spin multiplier"),
        ("3.circle.fill", "3× Boost", "Triple spin multiplier"),
        ("4.circle.fill", "4× Boost", "Quadruple spin multiplier"),
        ("shippingbox.fill", "Treasure Box", "Contains multiple rewards")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(legendItems, id: \.icon) { item in
                        HStack(spacing: 16) {
                            Image(systemName: item.icon)
                                .font(.avenirNext(size: GameFonts.title2Size, weight: .regular))
                                .foregroundStyle(iconColor(for: item.icon))
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.avenirNext(size: GameFonts.bodySize, weight: .medium))
                                Text(item.description)
                                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)

                        if item.icon != legendItems.last?.icon {
                            Divider()
                                .padding(.leading, 64)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Reward Icons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func iconColor(for icon: String) -> Color {
        switch icon {
        case "diamond.fill": return .cyan
        case "hammer.fill": return .gray
        case "arrow.left.arrow.right": return .green
        case "dot.radiowaves.left.and.right": return .red
        case "arrow.trianglehead.2.clockwise.rotate.90": return .purple
        case "2.circle.fill": return .yellow
        case "3.circle.fill": return .pink
        case "4.circle.fill": return .red
        case "shippingbox.fill": return .orange
        default: return .primary
        }
    }
}

#Preview("Challenge Mode") {
    let store = ChallengeStore()
    // Mark first two challenges as completed
    if store.challenges.count >= 2 {
        store.markCompleted(store.challenges[0].id)
        store.markCompleted(store.challenges[1].id)
    }

    return ChallengeModeView()
        .environment(\.challengeStore, store)
}

import SwiftUI
import GameCore
import GameApp

public struct ChallengeModeView: View {
    @Environment(\.challengeStore) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var scrollViewProxy: ScrollViewProxy? = nil
    @State private var currentTime = Date()  // For countdown timer updates
    @State private var selectedChallenge: Challenge? = nil

    public var onPlay: ((Challenge) -> Void)?

    public init(onPlay: ((Challenge) -> Void)? = nil) {
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
                    Button("Done") { dismiss() }
                }
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { time in
                currentTime = time
            }
        }
    }

    @ViewBuilder
    private func challengeCardView(for challenge: Challenge, index: Int) -> some View {
        let status = store.status(for: challenge)
        let isSelected = selectedChallenge?.id == challenge.id
        GeometryReader { geo in
            ChallengeCard(
                challenge: challenge,
                challengeNumber: index + 1,
                status: status,
                currentTime: currentTime,
                isSelected: isSelected,
                onTap: status.isPlayable ? { selectedChallenge = challenge } : nil
            )
            .frame(width: geo.size.width * 0.5)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 180)
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
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if let pending = store.pendingUnlockChallenge {
                // Pending unlock - show countdown
                VStack(spacing: 8) {
                    Text("Next Challenge Unlocks In")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatTimeRemaining(until: pending.unlockDate))
                        .font(.system(.title2, design: .monospaced).bold())
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
                    .font(.title3.weight(.semibold))
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
    var onTap: (() -> Void)? = nil

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

    private var isPendingUnlock: Bool {
        if case .pendingUnlock = status { return true }
        return false
    }

    private var unlockDate: Date? {
        if case .pendingUnlock(let date) = status { return date }
        return nil
    }

    /// Formats the reward for display, showing gems, power-ups, boosts, or spins
    /// Shows a treasure box for multiple rewards
    @ViewBuilder
    private var rewardLabel: some View {
        let reward = challenge.reward
        let parts = buildRewardParts(reward)

        if parts.count > 1 {
            // Multiple rewards - show treasure box followed by reward list
            HStack(spacing: 6) {
                Image(systemName: "shippingbox.fill")
                    .font(.caption)
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    HStack(spacing: 3) {
                        Image(systemName: part.icon)
                            .font(.system(size: 9))
                        Text(part.text)
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
            }
        } else if let part = parts.first {
            // Single reward - show specific icon
            HStack(spacing: 4) {
                Image(systemName: part.icon)
                    .font(.caption)
                Text(part.text)
                    .font(.caption.weight(.semibold))
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
                icon = "magnet"
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
        VStack(spacing: 8) {
            Text("Challenge \(challengeNumber)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(targetTileLabel)
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(isLocked ? .secondary : .primary)

            VStack(spacing: 6) {
                statusText

                if !isCompleted {
                    rewardLabel
                        .foregroundStyle(status == .active ? .orange : .secondary)
                }
            }
        }
        .padding(20)
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
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .opacity(onTap != nil ? 1.0 : (isLocked ? 0.7 : 1.0))
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .locked:
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
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
                    .font(.headline)
                Text(challenge.description)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        case .completed:
            Text("Completed")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.green)
        case .pendingUnlock(let unlockDate):
            VStack(spacing: 4) {
                Text("Unlocks in")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(formatTimeRemaining(until: unlockDate))
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(.orange)
            }
        case .locked:
            Text("Locked")
                .font(.footnote.weight(.medium))
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

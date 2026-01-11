import SwiftUI
import GameCore
import GameApp

public struct ChallengeModeView: View {
    @Environment(\.challengeStore) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var scrollViewProxy: ScrollViewProxy? = nil
    @State private var currentTime = Date()  // For countdown timer updates

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
                                    ChallengeCard(
                                        challenge: challenge,
                                        challengeNumber: index + 1,
                                        status: store.status(for: challenge),
                                        currentTime: currentTime
                                    )
                                    .id(challenge.id)
                                }
                            }
                            .padding(.horizontal, 48)
                            .padding(.vertical, 32)
                        }
                        .padding(.horizontal, 16)
                    }
                    .onAppear {
                        scrollViewProxy = proxy
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
            if let active = store.activeChallenge {
                // Active challenge - can play now
                Button {
                    onPlay?(active)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Play Challenge \(store.currentChallengeNumber)")
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

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Challenge \(challengeNumber)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                statusIcon
            }

            Text(targetTileLabel)
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(isLocked ? .secondary : .primary)

            VStack(spacing: 6) {
                statusText

                if !isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "diamond.fill")
                            .font(.caption)
                        Text("\(challenge.reward.coins)")
                            .font(.caption.weight(.semibold))
                    }
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
        .overlay(alignment: .leading) {
            Circle()
                .fill(nodeFill)
                .frame(width: 12, height: 12)
                .offset(x: -44)
        }
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

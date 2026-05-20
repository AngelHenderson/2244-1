import SwiftUI
import GameCore

struct ChallengeDetailView: View {
    let challenge: Challenge
    let challengeNumber: Int
    let status: ChallengeStatus
    let reward: ChallengeReward
    let onStart: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.currentTheme) private var currentTheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    targetTile
                    titleBlock
                    ruleSection
                    rewardSection
                    startButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Challenge \(challengeNumber)")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .platformTopBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var targetTile: some View {
        VStack(spacing: 10) {
            if let step = challenge.targetTile {
                TileView(
                    tile: Tile.make(forStep: step),
                    isSelected: false,
                    isValid: true,
                    size: 96,
                    theme: currentTheme
                )
            } else {
                Image(systemName: "target")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.orange)
            }

            Text(targetText)
                .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    private var titleBlock: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(challenge.difficulty.rawValue.capitalized)
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(difficultyColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(difficultyColor)

                Text(statusText)
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(statusColor)
            }

            Text(challenge.name)
                .font(.avenirNext(size: GameFonts.title2Size, weight: .heavy))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(challenge.description)
                .font(.avenirNext(size: GameFonts.bodySize, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var ruleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rules")
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .bold))

            ChallengeDetailRow(icon: "target", label: "Objective", value: objectiveText)
            ChallengeDetailRow(icon: "timer", label: "Time", value: timeText)
            ChallengeDetailRow(icon: "hand.tap", label: "Moves", value: moveText)
            ChallengeDetailRow(icon: "square.grid.3x3.fill", label: "Spawns", value: spawnText)
            ChallengeDetailRow(icon: "bolt.slash.fill", label: "Power-ups", value: powerUpText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var rewardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reward")
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .bold))

            if rewardParts.isEmpty {
                ChallengeDetailRow(icon: "shippingbox", label: "Prize", value: "Practice run")
            } else {
                ForEach(rewardParts, id: \.text) { part in
                    HStack(spacing: 12) {
                        rewardIcon(part.icon)
                            .frame(width: 26, height: 26)
                        Text(part.text)
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .semibold))
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var startButton: some View {
        Button {
            onStart()
        } label: {
            Label(status == .completed ? "Replay Challenge" : "Start Challenge", systemImage: status == .completed ? "arrow.clockwise" : "play.fill")
                .font(.avenirNext(size: GameFonts.title3Size, weight: .heavy))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!status.isPlayable)
    }

    private var targetText: String {
        if let step = challenge.targetTile {
            return "Reach \(TileStepLabelFormatter.labelForStep(step, start: 2))"
        }
        if let score = challenge.targetScore {
            return "Score \(AlphaNumber(score).formattedWithCommas())"
        }
        return "Beat the target"
    }

    private var objectiveText: String {
        if let step = challenge.targetTile {
            return "Create a \(TileStepLabelFormatter.labelForStep(step, start: 2)) tile"
        }
        if let score = challenge.targetScore {
            return "Reach \(AlphaNumber(score).formattedWithCommas()) points"
        }
        return "Finish the challenge goal"
    }

    private var timeText: String {
        guard let timeLimit = challenge.timeLimit else { return "3:00" }
        let seconds = Int(timeLimit.rounded())
        let minutes = seconds / 60
        let remainder = seconds % 60
        if remainder == 0 {
            return "\(minutes) min"
        }
        return "\(minutes):\(String(format: "%02d", remainder))"
    }

    private var moveText: String {
        guard let moveLimit = challenge.moveLimit else { return "Depends on valid moves" }
        return "\(moveLimit)"
    }

    private var spawnText: String {
        let minimum = challenge.minSpawnTile.map { TileStepLabelFormatter.labelForStep($0, start: 2) } ?? "2"
        guard let maximum = challenge.maxSpawnTile else {
            return "\(minimum)+"
        }
        return "\(minimum)-\(TileStepLabelFormatter.labelForStep(maximum, start: 2))"
    }

    private var powerUpText: String {
        if challenge.bannedPowerUps.isEmpty {
            return "Allowed"
        }
        let names = challenge.bannedPowerUps
            .map(powerUpName)
            .sorted()
            .joined(separator: ", ")
        return "Banned: \(names)"
    }

    private var statusText: String {
        switch status {
        case .active:
            return "Active"
        case .completed:
            return "Completed"
        case .locked:
            return "Locked"
        case .pendingUnlock:
            return "Unlocking"
        }
    }

    private var statusColor: Color {
        switch status {
        case .active:
            return .green
        case .completed:
            return .blue
        case .locked:
            return .secondary
        case .pendingUnlock:
            return .orange
        }
    }

    private var difficultyColor: Color {
        switch challenge.difficulty {
        case .easy:
            return .green
        case .medium:
            return .blue
        case .hard:
            return .orange
        case .expert:
            return .red
        }
    }

    private var rewardParts: [(icon: String, text: String)] {
        var parts: [(icon: String, text: String)] = []

        if reward.coins > 0 {
            parts.append(("gem", "\(reward.coins) Gems"))
        }

        for (type, count) in reward.powerUps.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            parts.append((powerUpIcon(for: type), "\(count) \(powerUpName(for: type))"))
        }

        for (multiplier, count) in reward.scoreBoosts.sorted(by: { $0.key < $1.key }) {
            parts.append(("boost\(multiplier)x", "\(count)x \(multiplier)X Boost"))
        }

        if reward.spins > 0 {
            parts.append(("spinthewheel", reward.spins == 1 ? "1 Spin" : "\(reward.spins) Spins"))
        }

        return parts
    }

    @ViewBuilder
    private func rewardIcon(_ icon: String) -> some View {
        if icon == "gem" || icon == "hammer" || icon == "swap" || icon == "magnet" || icon == "spinthewheel" || icon.hasPrefix("boost") {
            Image(icon)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: icon)
                .font(.avenirNext(size: GameFonts.title3Size, weight: .semibold))
        }
    }

    private func powerUpIcon(for type: PowerUpType) -> String {
        switch type {
        case .hammer:
            return "hammer"
        case .swap:
            return "swap"
        case .magnet:
            return "magnet"
        case .shuffle:
            return "shuffle"
        case .undo:
            return "arrow.uturn.backward"
        case .double:
            return "plus.forwardslash.minus"
        }
    }

    private func powerUpName(for type: PowerUpType) -> String {
        switch type {
        case .hammer:
            return "Hammer"
        case .swap:
            return "Swap"
        case .magnet:
            return "MegaMerge"
        case .shuffle:
            return "Shuffle"
        case .undo:
            return "Undo"
        case .double:
            return "Double"
        }
    }
}

private struct ChallengeDetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            Text(label)
                .font(.avenirNext(size: GameFonts.bodySize, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.avenirNext(size: GameFonts.bodySize, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview("Challenge Detail") {
    ChallengeDetailView(
        challenge: Challenge(
            name: "Tile Sprint",
            description: "Reach the target tile before time runs out.",
            difficulty: .medium,
            targetTile: 19,
            timeLimit: 180,
            maxSpawnTile: 4
        ),
        challengeNumber: 6,
        status: .active,
        reward: ChallengeReward(coins: 100, powerUps: [.hammer: 1], spins: 1),
        onStart: {}
    )
}

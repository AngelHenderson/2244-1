import SwiftUI
import GameCore
import GameApp

public struct DailyQuestsView: View {
    @Environment(DailyQuestStore.self) private var questStore
    @Environment(HomeState.self) private var homeState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.socialFeedPublisher) private var socialFeedPublisher

    @State private var countdown: String = ""
    @State private var timer: Timer?

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Countdown to reset
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.orange)
                        Text("Resets in \(countdown)")
                            .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.12))
                    )

                    // Quest cards
                    ForEach(questStore.quests) { quest in
                        QuestCard(
                            quest: quest,
                            highestTileStep: homeState.highestTileStep,
                            tileQuestTargetStep: questStore.tileQuestTargetStep
                        ) {
                            questStore.claim(questId: quest.id)
                            // Post to social feed when all quests are now complete
                            if questStore.quests.allSatisfy({ $0.claimed }) {
                                socialFeedPublisher.postDailyQuestsComplete()
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("DAILY QUESTS")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .platformTopBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            updateCountdown()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                Task { @MainActor in
                    updateCountdown()
                }
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

// MARK: - Quest Card

private struct QuestCard: View {
    let quest: DailyQuestStore.Quest
    let highestTileStep: Int
    let tileQuestTargetStep: Int
    let onClaim: () -> Void

    private var statusColor: Color {
        if quest.claimed { return .green }
        if quest.isClaimable { return .green }
        return .clear
    }

    private var statusText: String {
        if quest.claimed { return "Completed" }
        if quest.isClaimable { return "Ready!" }
        return "In Progress"
    }

    private var statusBadgeColor: Color {
        if quest.claimed { return .green }
        if quest.isClaimable { return .green }
        return .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title centered
            Text(quest.title)
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            // Description
            Text(quest.description)
                .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            // Progress bar
            if quest.id == "daily_tile_reach" && tileQuestTargetStep > 0 {
                QuestMilestoneBar(
                    startStep: tileQuestTargetStep - 10,
                    targetStep: tileQuestTargetStep,
                    currentStep: highestTileStep
                )
                .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(progressText)
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(quest.progress * 100))%")
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(min(quest.current, quest.target)), total: Double(quest.target))
                        .progressViewStyle(.linear)
                        .tint(quest.isComplete ? .green : .blue)
                }
            }

            // Rewards row
            QuestRewardSummary(rewards: quest.rewards)
                .frame(maxWidth: .infinity, alignment: .center)

            // Bottom row: status badge + claim button
            HStack {
                // Status badge
                Text(statusText)
                    .font(.avenirNext(size: GameFonts.caption2Size, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(statusBadgeColor.opacity(0.15))
                    )
                    .foregroundStyle(statusBadgeColor)

                Spacer()

                // Claim button
                Button(action: onClaim) {
                    Text(quest.claimed ? "Done" : "Claim")
                        .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .bold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(quest.isClaimable ? Color.green : Color(uiColor: .systemGray4))
                        )
                        .foregroundStyle(quest.isClaimable ? .white : .secondary)
                }
                .disabled(!quest.isClaimable)
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(uiColor: .systemGray6),
                            Color(uiColor: .systemGray5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(quest.isClaimable ? Color.green : Color(uiColor: .separator), lineWidth: 1)
        )
    }

    private var progressText: String {
        "\(min(quest.current, quest.target)) / \(quest.target)"
    }
}

// MARK: - Quest Reward Summary

private struct QuestRewardSummary: View {
    let rewards: AchievementDef.Rewards

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
        var items: [RewardItem] = []
        if let gems = rewards.gems, gems > 0 {
            items.append(RewardItem(icon: .asset("gem"), text: "\(gems)"))
        }
        if let hammers = rewards.hammers, hammers > 0 {
            items.append(RewardItem(icon: .asset("hammer"), text: "\(hammers)"))
        }
        if let magnets = rewards.magnets, magnets > 0 {
            items.append(RewardItem(icon: .asset("magnet"), text: "\(magnets)"))
        }
        if let swaps = rewards.swaps, swaps > 0 {
            items.append(RewardItem(icon: .asset("swap"), text: "\(swaps)"))
        }
        if let spins = rewards.spins, spins > 0 {
            items.append(RewardItem(icon: .asset("spinthewheel"), text: "\(spins)"))
        }
        if let boost2x = rewards.boost2x, boost2x > 0 {
            items.append(RewardItem(icon: .asset("boost2x"), text: "\(boost2x)×"))
        }
        if let boost3x = rewards.boost3x, boost3x > 0 {
            items.append(RewardItem(icon: .asset("boost3x"), text: "\(boost3x)×"))
        }
        if let boost4x = rewards.boost4x, boost4x > 0 {
            items.append(RewardItem(icon: .asset("boost4x"), text: "\(boost4x)×"))
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
                .frame(width: 18, height: 18)
        case .system(let name, let color):
            Image(systemName: name)
                .foregroundStyle(color)
                .font(.system(size: 16))
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(rewardItems) { item in
                HStack(spacing: 4) {
                    iconView(for: item.icon)
                    Text(item.text)
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Daily Quests") {
    GameUIScreenPreviewHost {
        DailyQuestsView()
    }
}
#endif

import SwiftUI
import GameServices

struct AllTiersView: View {
    let achievementTitle: String
    let tiers: [AchievementStore.TierEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(tiers) { tier in
                            TierRow(tier: tier)
                                .id(tier.id)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    // Scroll to current tier
                    if let currentTier = tiers.first(where: { $0.isCurrent }) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(currentTier.id, anchor: .center)
                            }
                        }
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(achievementTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct TierRow: View {
    let tier: AchievementStore.TierEntry

    private var statusIcon: String {
        if tier.isCompleted {
            return "checkmark.circle.fill"
        } else if tier.isCurrent {
            return "arrow.right.circle.fill"
        } else {
            return "circle"
        }
    }

    private var statusColor: Color {
        if tier.isCompleted {
            return .green
        } else if tier.isCurrent {
            return .blue
        } else {
            return .gray.opacity(0.5)
        }
    }

    private var backgroundGradient: [Color] {
        if tier.isCompleted {
            return [.green.opacity(0.15), .green.opacity(0.05)]
        } else if tier.isCurrent {
            return [.blue.opacity(0.2), .blue.opacity(0.1)]
        } else {
            return [Color(UIColor.systemGray6), Color(UIColor.systemGray5)]
        }
    }

    private var borderColor: Color {
        if tier.isCurrent {
            return .blue
        } else if tier.isCompleted {
            return .green.opacity(0.5)
        } else {
            return Color(UIColor.separator)
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Level indicator
            VStack {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                Text("Lv \(tier.level)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50)

            // Tier info
            VStack(alignment: .leading, spacing: 6) {
                Text(tier.title)
                    .font(.headline)
                    .foregroundStyle(tier.isCompleted || tier.isCurrent ? .primary : .secondary)

                Text(tier.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Rewards
                TierRewardSummary(rewards: tier.rewards)
            }

            Spacer()

            // Milestone badge
            Text(tier.milestoneLabel)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(tier.isCompleted ? .green.opacity(0.2) : Color(UIColor.systemGray5))
                )
                .foregroundStyle(tier.isCompleted ? .green : .secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: backgroundGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(borderColor, lineWidth: tier.isCurrent ? 2 : 1)
        )
        .opacity(tier.isCompleted || tier.isCurrent ? 1.0 : 0.7)
    }
}

private struct TierRewardSummary: View {
    let rewards: AchievementDef.Rewards

    private enum RewardIcon {
        case asset(String)
        case system(String, Color)
    }

    private struct RewardItem: Identifiable {
        let id = UUID()
        let icon: RewardIcon
        let label: String
        let amount: Int
    }

    private var rewardItems: [RewardItem] {
        var items: [RewardItem] = []
        if let gems = rewards.gems, gems > 0 {
            items.append(RewardItem(icon: .asset("gem"), label: "Gems", amount: gems))
        }
        if let hammers = rewards.hammers, hammers > 0 {
            items.append(RewardItem(icon: .asset("hammer"), label: "Hammer", amount: hammers))
        }
        if let magnets = rewards.magnets, magnets > 0 {
            items.append(RewardItem(icon: .asset("magnet"), label: "MegaMerge", amount: magnets))
        }
        if let swaps = rewards.swaps, swaps > 0 {
            items.append(RewardItem(icon: .asset("swap"), label: "Swap", amount: swaps))
        }
        if let spins = rewards.spins, spins > 0 {
            items.append(RewardItem(icon: .asset("spinthewheel"), label: "Spin", amount: spins))
        }
        if let boost2x = rewards.boost2x, boost2x > 0 {
            items.append(RewardItem(icon: .system("2.circle.fill", .blue), label: "2X", amount: boost2x))
        }
        if let boost3x = rewards.boost3x, boost3x > 0 {
            items.append(RewardItem(icon: .system("3.circle.fill", .purple), label: "3X", amount: boost3x))
        }
        if let boost4x = rewards.boost4x, boost4x > 0 {
            items.append(RewardItem(icon: .system("4.circle.fill", .orange), label: "4X", amount: boost4x))
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
                .frame(width: 14, height: 14)
        case .system(let name, let color):
            Image(systemName: name)
                .font(.caption)
                .foregroundStyle(color)
        }
    }

    var body: some View {
        let items = rewardItems
        if items.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    HStack(spacing: 3) {
                        iconView(for: item.icon)
                        Text("\(item.amount)")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

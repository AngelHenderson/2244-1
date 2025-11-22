import SwiftUI
import GameServices

public struct AchievementsView: View {
    @Environment(AchievementStore.self) private var achievements
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(achievements.catalog) { def in
                        AchievementRow(
                            definition: def,
                            isUnlocked: achievements.unlocks[def.id]?.unlocked == true,
                            unlockedDate: achievements.unlocks[def.id]?.unlockedAt
                        )
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
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

private struct RewardsView: View {
    let rewards: AchievementDef.Rewards
    
    var body: some View {
        HStack(spacing: 4) {
            if let gems = rewards.gems, gems > 0 {
                Label {
                    Text(verbatim: String(gems))
                } icon: {
                    Image(systemName: "diamond.fill")
                }
                .font(.caption)
                .foregroundStyle(.cyan)
            }
            if let spins = rewards.spins, spins > 0 {
                Label("\(spins)", systemImage: "arrow.trianglehead.2.clockwise")
                    .font(.caption)
                    .foregroundStyle(.purple)
            }
            if let hammers = rewards.hammers, hammers > 0 {
                Label("\(hammers)", systemImage: "hammer.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if let magnets = rewards.magnets, magnets > 0 {
                Label("\(magnets)", systemImage: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.mint)
            }
        }
        .labelStyle(.iconOnly)
    }
}

private struct AchievementRow: View {
    let definition: AchievementDef
    let isUnlocked: Bool
    let unlockedDate: Date?
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: isUnlocked ? "checkmark.seal.fill" : "seal")
                .font(.system(size: 32))
                .foregroundStyle(isUnlocked ? .green : .secondary)
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(definition.title)
                        .font(.headline)
                        .foregroundStyle(isUnlocked ? .primary : .secondary)
                    
                    if definition.hidden && !isUnlocked {
                        Text("Hidden")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                
                if !definition.hidden || isUnlocked {
                    Text(definition.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Complete objectives to unlock")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
                
                HStack {
                    Label(definition.category, systemImage: categoryIcon(for: definition.category))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if let rewards = definition.rewards {
                        RewardsView(rewards: rewards)
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .opacity(definition.hidden && !isUnlocked ? 0.7 : 1.0)
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "onboarding": return "sparkles"
        case "score": return "trophy"
        case "timeattack": return "timer"
        case "daily": return "calendar"
        case "endless": return "infinity"
        case "patterns": return "square.grid.3x3"
        case "powerups": return "bolt"
        case "hidden": return "questionmark"
        default: return "star"
        }
    }
}
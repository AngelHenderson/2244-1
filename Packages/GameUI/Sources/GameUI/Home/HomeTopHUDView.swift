import SwiftUI
import GameCore

struct HomeTopHUDView: View {
    let streakDays: Int
    let gems: Int
    let nextReward: AchievementDef.Rewards?
    let canClaim: Bool
    let onStreakTap: () -> Void
    let onShopTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onStreakTap) {
                HStack(spacing: 7) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("Streak")
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .medium))
                    Text("\(streakDays) \(streakDays == 1 ? "Day" : "Days")")
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))

                    // Show next reward preview when claimable
                    if canClaim, let reward = nextReward {
                        Divider()
                            .frame(height: 14)
                            .background(.white.opacity(0.4))

                        nextRewardLabel(reward)
                    }
                }
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(canClaim ? Color.orange.opacity(0.6) : Color.white.opacity(0.16), lineWidth: canClaim ? 1.5 : 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Daily streak \(streakDays) \(streakDays == 1 ? "day" : "days"). Open streaks.")

            Spacer(minLength: 8)

            Button(action: onShopTap) {
                HStack(spacing: 7) {
                    Image("gem")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                    Text(verbatim: String(gems))
                        .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .bold))
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.small)
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Gems \(String(gems)). Open shop.")
        }
        .environment(\.colorScheme, .dark)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func nextRewardLabel(_ reward: AchievementDef.Rewards) -> some View {
        // Show the first reward entry as a compact preview
        if let first = reward.entries.first {
            HStack(spacing: 3) {
                Image(first.kind.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                Text("+\(first.amount)")
                    .font(.avenirNext(size: GameFonts.caption2Size, weight: .bold))
            }
            .foregroundStyle(.yellow)
        }
    }
}

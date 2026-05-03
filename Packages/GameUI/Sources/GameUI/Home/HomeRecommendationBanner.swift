import SwiftUI
import GameApp

struct HomeRecommendationBanner: View {
    let action: NextBestAction
    let onAct: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(action.title.uppercased())
                    .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(action.subtitle)
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 6)

            Button(action: onAct) {
                Text(ctaText)
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss recommendation")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .environment(\.colorScheme, .dark)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(0.95), .purple.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Recommended next action"))
    }

    private var ctaText: String {
        switch action {
        case .tutorial:
            "EXPLORE"
        case .play, .nextMilestone:
            "PLAY"
        case .claimDaily:
            "CLAIM"
        case .freeSpin:
            "SPIN"
        case .unlockCreate, .unlockChallenge, .settingsPrivacy:
            "OPEN"
        case .lowInventoryShop:
            "SHOP"
        }
    }
}

import SwiftUI
import GameApp

struct TopHUD: View {
    @Environment(\.gameStore) private var gameStore
    let rank: Int
    let milestones: [Milestone]
    let onLeaderboard: () -> Void
    let onBuy: () -> Void
    let onPause: () -> Void
    
    struct Milestone: Identifiable, Equatable {
        let id = UUID()
        let label: String
        let isCurrent: Bool
    }
    
    var body: some View {
        HStack(alignment: .center) {
            rankBadge
            Spacer(minLength: Tokens.Spacing.lg)
            VStack(spacing: 4) {
                progressTrack
                scoreBadge
            }
            Spacer(minLength: Tokens.Spacing.lg)
            gemWallet
            pauseButton
        }
        .padding(.horizontal)
    }
    
    private var rankBadge: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            Text("Rank:")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Text(verbatim: String(rank))
                .font(.system(size: 18, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous))
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .onTapGesture { onLeaderboard() }
    }
    
    private var progressTrack: some View {
        GeometryReader { geo in
            let barWidth = min(geo.size.width, 320)
            ZStack(alignment: .center) {
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(width: barWidth, height: 6)
                HStack(spacing: 22) {
                    ForEach(milestones) { ms in
                        milestoneChip(ms)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 44)
        .contentShape(Rectangle())
        .onTapGesture { onLeaderboard() }
    }
    
    private func milestoneChip(_ ms: Milestone) -> some View {
        ZStack {
            let size: CGFloat = ms.isCurrent ? Tokens.Size.chipCurrent : Tokens.Size.chip
            RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous)
                .fill(ms.isCurrent ? Color.green : Color.orange)
                .shadow(radius: ms.isCurrent ? 4 : 2, y: 2)
                .frame(width: size, height: size)
            Text(ms.label)
                .font(.system(size: ms.isCurrent ? 16 : 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            if ms.isCurrent {
                Image(systemName: "crown.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.yellow)
                    .offset(y: -size * 0.85)
            }
        }
    }
    
    private var gemWallet: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            gemImage
            Text(verbatim: String(gameStore.coins))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Button(action: onBuy) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .background(Color.green, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous))
        .foregroundStyle(.white)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var gemImage: Image {
        return Image("gem")
    }

    private var pauseButton: some View {
        Button(action: onPause) {
            Image(systemName: "pause.fill")
                .font(.system(size: 14, weight: .bold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .foregroundStyle(.white)
        .accessibilityLabel("Pause")
    }

    private var scoreBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.grid.cross")
            Text("Score: \(gameStore.state.scoreValue.formattedWithCommas())")
                .monospacedDigit()
        }
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.black.opacity(0.5), in: Capsule())
        .foregroundStyle(.white)
    }
}



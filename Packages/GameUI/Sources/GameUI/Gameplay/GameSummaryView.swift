import SwiftUI
import GameCore

struct GameSummaryView: View {
    let summary: GameRunSummary
    let isFirstRun: Bool
    let isPersonalBest: Bool
    let onPlayAgain: () -> Void
    let onReplayFromMilestone: () -> Void
    let onHome: () -> Void

    @Environment(\.currentTheme) private var currentTheme

    var body: some View {
        ZStack {
            Color.black.opacity(0.82)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    highestTile
                    statsGrid
                    insight
                    actions
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 28)
            }
        }
        .transition(.opacity)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.avenirNext(size: isPersonalBest ? 33 : 30, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
        }
    }

    private var highestTile: some View {
        VStack(spacing: 10) {
            TileView(
                tile: Tile.make(forStep: summary.highestTileStep),
                isSelected: false,
                isValid: true,
                size: 92,
                theme: currentTheme
            )
            .shadow(color: .yellow.opacity(isPersonalBest ? 0.45 : 0.2), radius: 16, x: 0, y: 8)

            Text("Highest tile")
                .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                .foregroundStyle(.white.opacity(0.62))
                .textCase(.uppercase)
        }
        .padding(.vertical, 4)
    }

    private var statsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ],
            spacing: 10
        ) {
            SummaryStatTile(label: "Score", value: summary.scoreAlpha.formattedWithCommas(), icon: "chart.line.uptrend.xyaxis")
            SummaryStatTile(label: "Moves", value: "\(summary.moves)", icon: "hand.tap.fill")
            SummaryStatTile(label: "Tile", value: tileLabel, icon: "square.grid.2x2.fill")
            SummaryStatTile(label: "Time", value: formattedDuration, icon: "timer")
        }
    }

    private var insight: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text(isFirstRun ? "What mattered" : "Next run focus")
                    .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(insightText)
                .font(.avenirNext(size: GameFonts.bodySize, weight: .medium))
                .foregroundStyle(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: onPlayAgain) {
                Label("Play Again", systemImage: "arrow.clockwise")
                    .font(.avenirNext(size: GameFonts.title3Size, weight: .heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button(action: onReplayFromMilestone) {
                Label("Replay From Tile", systemImage: "flag.checkered")
                    .font(.avenirNext(size: GameFonts.bodySize, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.white)

            Button("Home", action: onHome)
                .font(.avenirNext(size: GameFonts.bodySize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.top, 2)
        }
    }

    private var title: String {
        if isFirstRun { return "First Run Complete" }
        if isPersonalBest { return "New Personal Best" }
        return "Great Run"
    }

    private var subtitle: String {
        if isFirstRun {
            return "Score, highest tile, and moves are the numbers to beat next."
        }
        if isPersonalBest {
            return "That run pushed your best score higher."
        }
        return "Review the result, then choose your next start."
    }

    private var tileLabel: String {
        TileStepLabelFormatter.labelForStep(summary.highestTileStep, start: 2)
    }

    private var formattedDuration: String {
        let totalSeconds = max(0, Int(summary.duration.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes == 0 {
            return "\(seconds)s"
        }
        return "\(minutes)m \(seconds)s"
    }

    private var insightText: String {
        if isFirstRun {
            return "Try to keep open space around your largest tile. Longer chains are easier when the board has room to breathe."
        }
        if summary.infinityMergeCount > 0 {
            return "You reached infinity territory. Replay from a strong milestone and protect your largest tile early."
        }
        if summary.moves < 20 {
            return "This board ended quickly. Use the next run to build space before chasing the biggest merge."
        }
        if summary.highestTileStep >= 19 {
            return "You reached a high-value tile. Start the next run from a milestone if you want to practice late-board decisions."
        }
        return "Your next jump will come from longer chains. Leave two directions open before committing to a merge path."
    }
}

private struct SummaryStatTile: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.68))

            Text(value)
                .font(.avenirNext(size: GameFonts.title3Size, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.58)

            Text(label)
                .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview("Game Summary") {
    GameSummaryView(
        summary: GameRunSummary(
            score: 248_240,
            scoreAlpha: AlphaNumber(248_240),
            highestTile: 8192,
            highestTileStep: 12,
            moves: 46,
            duration: 311,
            seed: 44,
            infinityMergeCount: 0,
            endedAt: Date()
        ),
        isFirstRun: false,
        isPersonalBest: true,
        onPlayAgain: {},
        onReplayFromMilestone: {},
        onHome: {}
    )
}

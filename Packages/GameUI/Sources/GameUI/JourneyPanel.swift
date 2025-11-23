import SwiftUI
import GameApp
import GameCore

struct JourneyPanel: View {
    @Environment(\.gameStore) private var gameStore
    let showAll: Bool
    
    init(showAll: Bool = false) {
        self.showAll = showAll
    }
    
    private func journeyValues() -> [Tile] {
        if showAll {
            // Show full journey up to 873bz
            return JourneyTileGenerator.generateFullJourney()
        } else {
            // Show journey relative to current highest
            let highest = max(2, gameStore.state.highestTile)
            return JourneyTileGenerator.generateJourney(highest: highest, stepsAhead: 20)
        }
    }
    
    var body: some View {
        let tiles = journeyTileItems
        let highest = max(2, gameStore.state.highestTile)
        
        return ScrollView(.vertical, showsIndicators: false) {
            journeyList(tiles: tiles, highest: highest)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
        }
    }
}

private extension JourneyPanel {
    struct JourneyTileItem: Identifiable {
        let id: Int
        let tile: Tile
    }
    
    var journeyTileItems: [JourneyTileItem] {
        journeyValues()
            .reversed()
            .enumerated()
            .map { JourneyTileItem(id: $0.offset, tile: $0.element) }
    }
    
    @ViewBuilder
    func journeyList(tiles: [JourneyTileItem], highest: Int) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(tiles, id: \.id) { item in
                let index = item.id
                let tile = item.tile
                let tier = JourneyAbbreviationTiers.tier(for: tile)
                let rewardStatus = tier.flatMap { rewardStatus(for: $0) }
                
                HStack(alignment: .center, spacing: 16) {
                    if let tier, let rewardStatus {
                        JourneyTierRewardBubble(status: rewardStatus) {
                            gameStore.presentJourneyReward(for: tier)
                        }
                        .accessibilityLabel("\(tier.label) reward")
                    } else {
                        Spacer()
                            .frame(width: 0)
                    }
                    
                    VStack(spacing: 4) {
                        TileView(
                            tile: tile,
                            isSelected: false,
                            isValid: true,
                            size: 120
                        )
                        if tile.value == highest {
                            Text("Highest Tile")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
                
                if index < tiles.count - 1 {
                    JourneyDotTrail(height: 64, dotCount: 4, dotSize: 6)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                        .padding(.vertical, 8)
                }
            }
        }
    }
    
    func rewardStatus(for tier: JourneyAbbreviationTier) -> JourneyTierRewardBubble.Status? {
        guard gameStore.isAbbreviationTierUnlocked(tier) else { return nil }
        return gameStore.hasClaimedAbbreviationTier(tier) ? .claimed : .available
    }
}

private struct JourneyTierRewardBubble: View {
    enum Status {
        case available, claimed
    }
    
    let status: Status
    let onTap: () -> Void
    
    var body: some View {
        Group {
            if status == .available {
                Button(action: onTap) {
                    bubbleContent
                }
                .buttonStyle(.plain)
            } else {
                bubbleContent
            }
        }
        .frame(width: 76)
    }
    
    private var bubbleContent: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(background)
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(status == .available ? "Tap" : "Claimed")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 8)
                )
            
            if status == .claimed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
                    .background(
                        Circle()
                            .fill(Color.white)
                    )
                    .offset(x: 8, y: -8)
            }
        }
    }
    
    private var background: LinearGradient {
        if status == .available {
            return LinearGradient(
                colors: [
                    Color(red: 0.54, green: 0.12, blue: 0.82),
                    Color(red: 0.98, green: 0.35, blue: 0.31)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(colors: [Color.gray.opacity(0.35)], startPoint: .top, endPoint: .bottom)
    }
}

private struct JourneyDotTrail: View {
    let height: CGFloat
    let dotCount: Int
    let dotSize: CGFloat

    var body: some View {
        let clampedCount = max(1, min(dotCount, 4))
        let totalDotsHeight = CGFloat(clampedCount) * dotSize
        let spacing = max(4, (height - totalDotsHeight) / CGFloat(clampedCount + 1))

        VStack(spacing: spacing) {
            ForEach(0..<clampedCount, id: \.self) { _ in
                Circle()
                    .frame(width: dotSize, height: dotSize)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: height, alignment: .center)
    }
}




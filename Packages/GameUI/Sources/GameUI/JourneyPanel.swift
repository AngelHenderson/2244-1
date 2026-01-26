import SwiftUI
import GameApp
import GameCore

public struct JourneyPanel: View {
    @Environment(\.gameStore) private var gameStore

    private let topInset: CGFloat
    private let bottomInset: CGFloat

    public init(topInset: CGFloat = 0, bottomInset: CGFloat = 0) {
        self.topInset = topInset
        self.bottomInset = bottomInset
    }

    public var body: some View {
        let milestones = roadMilestones
        let segmentHeight: CGFloat = 180
        let tilesPerSegment = 2
        let segments = (milestones.count + tilesPerSegment - 1) / tilesPerSegment
        let totalHeight = CGFloat(segments) * segmentHeight + 200

        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .top) {
                    // Background
                    SerpentineBackground()
                        .frame(height: totalHeight)

                    // Road and milestones
                    SerpentineRoadView(
                        milestones: milestones,
                        rowHeight: segmentHeight,
                        onClaimReward: { tier in
                            gameStore.presentJourneyReward(for: tier)
                        }
                    )
                }
                .frame(maxWidth: .infinity)
                .frame(height: totalHeight)
            }
            .safeAreaPadding(.top, topInset)
            .safeAreaPadding(.bottom, bottomInset)
            .onAppear {
                if let currentIndex = milestones.firstIndex(where: { $0.status == .current }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            proxy.scrollTo(currentIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(SerpentineBackground())
    }
}

// MARK: - Derived Data

private extension JourneyPanel {
    var highestTile: Int {
        max(2, gameStore.state.highestTile)
    }

    var highestStep: Int {
        Tile(value: highestTile).stepIndex ?? 0
    }

    var roadMilestones: [SerpentineMilestone] {
        // Always show the full journey from 2 to 873bz then infinity
        let tiles = GameCore.JourneyTileGenerator.generateFullJourney()
        return tiles.enumerated().map { index, tile in
            let tierInfo = JourneyAbbreviationTiers.tier(for: tile)
            let isUnlocked: Bool
            let isClaimed: Bool
            if let tierInfo {
                isUnlocked = gameStore.isAbbreviationTierUnlocked(tierInfo.tier)
                isClaimed = gameStore.hasClaimedAbbreviationTier(tierInfo.tier)
            } else if tile.isInfinity {
                isUnlocked = true
                isClaimed = false
            } else if let step = tile.stepIndex {
                isUnlocked = step <= highestStep
                isClaimed = false
            } else {
                isUnlocked = tile.value <= highestTile
                isClaimed = false
            }

            let status: SerpentineMilestone.Status
            if tile.isInfinity {
                status = .infinity
            } else if let step = tile.stepIndex {
                if step < highestStep {
                    status = .completed
                } else if step == highestStep {
                    status = .current
                } else {
                    status = .locked
                }
            } else if tile.value == highestTile {
                status = .current
            } else if tile.value < highestTile {
                status = .completed
            } else {
                status = .locked
            }

            let rewardAvailable = tierInfo != nil ? (isUnlocked && !isClaimed) : false
            let rewardClaimed = tierInfo != nil ? (isUnlocked && isClaimed) : false

            return SerpentineMilestone(
                id: index,
                tile: tile,
                label: formatLabel(for: tile),
                tier: tierInfo?.tier,
                status: status,
                isUnlocked: isUnlocked,
                isRewardAvailable: rewardAvailable,
                isRewardClaimed: rewardClaimed
            )
        }
    }

    func formatLabel(for tile: Tile) -> String {
        if tile.isInfinity {
            return "∞"
        }
        if let step = tile.stepIndex {
            return GameCore.JourneyTileGenerator.formatTileAtStep(step)
        }
        return GameCore.AlphaMag.formatTileValue(tile.value)
    }
}

// MARK: - Serpentine Milestone Model

@MainActor
struct SerpentineMilestone: Identifiable {
    enum Status {
        case completed
        case current
        case locked
        case infinity
    }

    let id: Int
    let tile: Tile
    let label: String
    let tier: JourneyAbbreviationTier?
    let status: Status
    let isUnlocked: Bool
    let isRewardAvailable: Bool
    let isRewardClaimed: Bool

    var tileColor: Color {
        if tile.isInfinity {
            return Color.purple
        }
        return Theme.color(for: tile.value)
    }

    var tileTextColor: Color {
        if tile.isInfinity {
            return .white
        }
        return Theme.textColor(for: tile.value)
    }
}

// MARK: - Serpentine Background

private struct SerpentineBackground: View {
    var body: some View {
        ZStack {
            // Dark purple gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.14, blue: 0.28),
                    Color(red: 0.12, green: 0.10, blue: 0.20),
                    Color(red: 0.08, green: 0.06, blue: 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle hills/waves in background
            GeometryReader { geo in
                Canvas { context, size in
                    // Draw subtle wave patterns
                    for i in 0..<Int(size.height / 300) {
                        let y = CGFloat(i) * 300 + 150
                        let opacity = 0.03 + Double(i % 3) * 0.02

                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addQuadCurve(
                            to: CGPoint(x: size.width, y: y + 50),
                            control: CGPoint(x: size.width * 0.5, y: y - 80)
                        )
                        path.addLine(to: CGPoint(x: size.width, y: y + 150))
                        path.addLine(to: CGPoint(x: 0, y: y + 100))
                        path.closeSubpath()

                        context.fill(path, with: .color(.purple.opacity(opacity)))
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Serpentine Road View

private struct SerpentineRoadView: View {
    let milestones: [SerpentineMilestone]
    let rowHeight: CGFloat
    let onClaimReward: (JourneyAbbreviationTier) -> Void

    private let roadWidth: CGFloat = 45
    private let tileSize: CGFloat = 65

    // Group tiles: 2 tiles per horizontal segment, alternating left/right
    private let tilesPerSegment = 2

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let leftX = width * 0.22
            let rightX = width * 0.78
            let segmentHeight: CGFloat = 180 // Height for each S-curve segment

            ZStack {
                // Draw the serpentine road
                SerpentineRoadPath(
                    milestoneCount: milestones.count,
                    tilesPerSegment: tilesPerSegment,
                    segmentHeight: segmentHeight,
                    leftX: leftX,
                    rightX: rightX,
                    roadWidth: roadWidth,
                    width: width
                )

                // Place milestones along the road
                ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                    let pos = tilePosition(index: index, width: width, leftX: leftX, rightX: rightX, segmentHeight: segmentHeight)

                    MilestoneTileView(
                        milestone: milestone,
                        size: tileSize,
                        onClaimReward: {
                            if let tier = milestone.tier {
                                onClaimReward(tier)
                            }
                        }
                    )
                    .position(x: pos.x, y: pos.y)
                    .id(index)
                }
            }
            .frame(height: totalHeight(segmentHeight: segmentHeight))
        }
    }

    private func totalHeight(segmentHeight: CGFloat) -> CGFloat {
        let segments = (milestones.count + tilesPerSegment - 1) / tilesPerSegment
        return CGFloat(segments) * segmentHeight + 100
    }

    private func tilePosition(index: Int, width: CGFloat, leftX: CGFloat, rightX: CGFloat, segmentHeight: CGFloat) -> CGPoint {
        let segmentIndex = index / tilesPerSegment
        let positionInSegment = index % tilesPerSegment
        let isRightSegment = segmentIndex % 2 == 0

        let totalSegments = (milestones.count + tilesPerSegment - 1) / tilesPerSegment
        let baseY = CGFloat(totalSegments - segmentIndex) * segmentHeight

        // Calculate Y position within segment
        let y: CGFloat
        if positionInSegment == 0 {
            y = baseY - segmentHeight * 0.25
        } else {
            y = baseY - segmentHeight * 0.75
        }

        // Calculate X position - tiles spread across the horizontal section
        let x: CGFloat
        if isRightSegment {
            // Right segment: first tile on right, second tile toward center
            if positionInSegment == 0 {
                x = rightX
            } else {
                x = rightX - (rightX - width * 0.5) * 0.6
            }
        } else {
            // Left segment: first tile on left, second tile toward center
            if positionInSegment == 0 {
                x = leftX
            } else {
                x = leftX + (width * 0.5 - leftX) * 0.6
            }
        }

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Serpentine Road Path

private struct SerpentineRoadPath: View {
    let milestoneCount: Int
    let tilesPerSegment: Int
    let segmentHeight: CGFloat
    let leftX: CGFloat
    let rightX: CGFloat
    let roadWidth: CGFloat
    let width: CGFloat

    var body: some View {
        Canvas { context, size in
            guard milestoneCount > 0 else { return }

            let totalSegments = (milestoneCount + tilesPerSegment - 1) / tilesPerSegment
            let totalHeight = CGFloat(totalSegments) * segmentHeight + 100

            var roadPath = Path()

            // Start from bottom right
            let startY = totalHeight - 50
            let startX = rightX
            roadPath.move(to: CGPoint(x: startX, y: startY))

            for segment in 0..<totalSegments {
                let isRightSegment = segment % 2 == 0
                let segmentTopY = totalHeight - CGFloat(segment + 1) * segmentHeight

                if isRightSegment {
                    // Right side segment - draw horizontal then curve to left
                    let currentX = rightX
                    let centerX = width * 0.5

                    // Horizontal section on right
                    roadPath.addLine(to: CGPoint(x: currentX, y: segmentTopY + segmentHeight * 0.75))

                    // Curve toward center
                    roadPath.addQuadCurve(
                        to: CGPoint(x: centerX, y: segmentTopY + segmentHeight * 0.5),
                        control: CGPoint(x: currentX, y: segmentTopY + segmentHeight * 0.5)
                    )

                    // Continue curve to left side
                    if segment < totalSegments - 1 {
                        roadPath.addQuadCurve(
                            to: CGPoint(x: leftX, y: segmentTopY + segmentHeight * 0.25),
                            control: CGPoint(x: leftX, y: segmentTopY + segmentHeight * 0.5)
                        )
                    } else {
                        // Last segment - end at center top
                        roadPath.addLine(to: CGPoint(x: centerX, y: segmentTopY))
                    }
                } else {
                    // Left side segment - draw horizontal then curve to right
                    let currentX = leftX
                    let centerX = width * 0.5

                    // Horizontal section on left
                    roadPath.addLine(to: CGPoint(x: currentX, y: segmentTopY + segmentHeight * 0.75))

                    // Curve toward center
                    roadPath.addQuadCurve(
                        to: CGPoint(x: centerX, y: segmentTopY + segmentHeight * 0.5),
                        control: CGPoint(x: currentX, y: segmentTopY + segmentHeight * 0.5)
                    )

                    // Continue curve to right side
                    if segment < totalSegments - 1 {
                        roadPath.addQuadCurve(
                            to: CGPoint(x: rightX, y: segmentTopY + segmentHeight * 0.25),
                            control: CGPoint(x: rightX, y: segmentTopY + segmentHeight * 0.5)
                        )
                    } else {
                        // Last segment - end at center top
                        roadPath.addLine(to: CGPoint(x: centerX, y: segmentTopY))
                    }
                }
            }

            // Draw road edge first (darker, wider)
            context.stroke(
                roadPath,
                with: .color(Color(red: 0.20, green: 0.20, blue: 0.25)),
                style: StrokeStyle(lineWidth: roadWidth + 6, lineCap: .round, lineJoin: .round)
            )

            // Draw the main road
            context.stroke(
                roadPath,
                with: .color(Color(red: 0.40, green: 0.40, blue: 0.45)),
                style: StrokeStyle(lineWidth: roadWidth, lineCap: .round, lineJoin: .round)
            )

            // Draw the dashed center line
            context.stroke(
                roadPath,
                with: .color(.white.opacity(0.6)),
                style: StrokeStyle(
                    lineWidth: 2.5,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [10, 8]
                )
            )
        }
    }
}

// MARK: - Milestone Tile View

private struct MilestoneTileView: View {
    let milestone: SerpentineMilestone
    let size: CGFloat
    let onClaimReward: () -> Void

    @State private var glowAnimation = false

    var body: some View {
        VStack(spacing: 8) {
            // Crown for current milestone
            if milestone.status == .current {
                Image(systemName: "crown.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .orange.opacity(0.5), radius: 4)
            }

            // Reward badge
            if milestone.isRewardAvailable {
                Button(action: onClaimReward) {
                    HStack(spacing: 4) {
                        Image(systemName: "gift.fill")
                            .font(.caption2.bold())
                        Text("Claim")
                            .font(.caption2.bold())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.red))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            } else if milestone.isRewardClaimed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                    Text("Claimed")
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.gray.opacity(0.5)))
                .foregroundStyle(.white.opacity(0.7))
            }

            // The tile itself
            ZStack {
                // Glow effect for current milestone
                if milestone.status == .current {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(milestone.tileColor.opacity(0.4))
                        .frame(width: size + 20, height: size + 20)
                        .blur(radius: 15)
                        .scaleEffect(glowAnimation ? 1.1 : 1.0)
                }

                // Tile background
                RoundedRectangle(cornerRadius: 12)
                    .fill(tileBackground)
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(tileBorder, lineWidth: milestone.status == .current ? 3 : 2)
                    )
                    .shadow(color: tileShadow, radius: milestone.status == .current ? 12 : 4)

                // Tile label
                if milestone.status == .infinity {
                    Image(systemName: "infinity")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                } else {
                    Text(milestone.label)
                        .font(.system(size: labelFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(labelColor)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
        }
        .onAppear {
            if milestone.status == .current {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowAnimation = true
                }
            }
        }
    }

    private var tileBackground: some ShapeStyle {
        switch milestone.status {
        case .completed, .current:
            return AnyShapeStyle(milestone.tileColor)
        case .locked:
            return AnyShapeStyle(Color(red: 0.25, green: 0.25, blue: 0.30))
        case .infinity:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.purple.opacity(0.8), Color.cyan.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var tileBorder: Color {
        switch milestone.status {
        case .completed:
            return .white.opacity(0.3)
        case .current:
            return .yellow
        case .locked:
            return .white.opacity(0.1)
        case .infinity:
            return .cyan.opacity(0.8)
        }
    }

    private var tileShadow: Color {
        switch milestone.status {
        case .current:
            return milestone.tileColor.opacity(0.6)
        case .infinity:
            return .purple.opacity(0.5)
        default:
            return .black.opacity(0.3)
        }
    }

    private var labelColor: Color {
        switch milestone.status {
        case .completed, .current:
            return milestone.tileTextColor
        case .locked:
            return .white.opacity(0.5)
        case .infinity:
            return .white
        }
    }

    private var labelFontSize: CGFloat {
        if milestone.label.count > 5 {
            return 14
        } else if milestone.label.count > 3 {
            return 18
        }
        return 22
    }
}

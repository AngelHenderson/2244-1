import SwiftUI
import GameApp
import GameCore

// MARK: - Journey Scroll Actions

public struct JourneyScrollActions: Sendable {
    public var scrollToTop: @Sendable () -> Void
    public var scrollToBottom: @Sendable () -> Void

    public init(scrollToTop: @escaping @Sendable () -> Void = {}, scrollToBottom: @escaping @Sendable () -> Void = {}) {
        self.scrollToTop = scrollToTop
        self.scrollToBottom = scrollToBottom
    }
}

public struct JourneyScrollActionsKey: EnvironmentKey {
    public static let defaultValue = JourneyScrollActions()
}

public extension EnvironmentValues {
    var journeyScrollActions: JourneyScrollActions {
        get { self[JourneyScrollActionsKey.self] }
        set { self[JourneyScrollActionsKey.self] = newValue }
    }
}

public struct JourneyPanel: View {
    @Environment(\.gameStore) private var gameStore

    private let topInset: CGFloat
    private let bottomInset: CGFloat

    // Scroll position as string ID for reliability
    @State private var scrollPosition: String?

    public init(topInset: CGFloat = 0, bottomInset: CGFloat = 0) {
        self.topInset = topInset
        self.bottomInset = bottomInset
    }

    public var body: some View {
        let milestones = roadMilestones
        let milestoneCount = milestones.count
        let verticalSpacing: CGFloat = 100
        let totalHeight = CGFloat(milestoneCount) * verticalSpacing + 200

        // Find current milestone index for initial position
        let currentIndex = milestones.firstIndex(where: { $0.status == .current }) ?? 0

        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .top) {
                    // The visual road and milestones
                    SerpentineRoadView(
                        milestones: milestones,
                        rowHeight: verticalSpacing,
                        onClaimReward: { tier in
                            gameStore.presentJourneyReward(for: tier)
                        }
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: totalHeight)

                    // Invisible scroll anchor points at each milestone Y position
                    VStack(spacing: 0) {
                        ForEach(0..<milestoneCount, id: \.self) { index in
                            // Reversed order: top of VStack = highest index (infinity)
                            let reversedIndex = milestoneCount - 1 - index
                            Color.clear
                                .frame(height: verticalSpacing)
                                .id("milestone-\(reversedIndex)")
                        }
                        // Extra space at bottom
                        Color.clear.frame(height: 100)
                            .id("milestone-bottom")
                    }
                }
                .frame(height: totalHeight)
            }
            .scrollPosition(id: $scrollPosition, anchor: .center)
            .scrollClipDisabled()
            .contentMargins(.top, topInset, for: .scrollContent)
            .contentMargins(.bottom, bottomInset, for: .scrollContent)
            .onAppear {
                // Set initial scroll position to current milestone
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        scrollPosition = "milestone-\(currentIndex)"
                    }
                }
            }

            // Navigation arrows
            VStack {
                // Up arrow - scrolls to infinity (highest index)
                Button {
                    withAnimation(.snappy(duration: 0.5)) {
                        scrollPosition = "milestone-\(milestoneCount - 1)"
                    }
                } label: {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                        }
                }
                .padding(.top, topInset + 8)

                Spacer()

                // Down arrow - scrolls to tile 2 (index 0)
                Button {
                    withAnimation(.snappy(duration: 0.5)) {
                        scrollPosition = "milestone-0"
                    }
                } label: {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                        }
                }
                .padding(.bottom, bottomInset + 8)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Derived Data

private extension JourneyPanel {
    var highestTile: Int {
        max(2, gameStore.state.highestTile)
    }

    var highestStep: Int {
        // Use the step directly from gameStore to handle values beyond Int.max
        max(0, gameStore.state.highestTileStep)
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
        // Use step-based color to handle values beyond Int.max
        if let step = tile.stepIndex {
            return Theme.colorForStep(step)
        }
        return Theme.color(for: tile.value)
    }

    var tileTextColor: Color {
        if tile.isInfinity {
            return .white
        }
        // Use step-based color to handle values beyond Int.max
        if let step = tile.stepIndex {
            return Theme.textColorForStep(step)
        }
        return Theme.textColor(for: tile.value)
    }
}

// MARK: - Serpentine Road View

private struct SerpentineRoadView: View {
    let milestones: [SerpentineMilestone]
    let rowHeight: CGFloat
    let onClaimReward: (JourneyAbbreviationTier) -> Void

    private let roadWidth: CGFloat = 50
    private let tileSize: CGFloat = 60

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let positions = calculateAllPositions(count: milestones.count, width: width)
            let totalHeight = CGFloat(milestones.count) * 100 + 200

            ZStack {
                // Draw the serpentine road through all tile positions
                SerpentineRoadPath(
                    positions: positions,
                    roadWidth: roadWidth
                )
                .frame(width: width, height: totalHeight)

                // Place milestones at calculated positions
                ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                    if index < positions.count {
                        MilestoneTileView(
                            milestone: milestone,
                            size: tileSize,
                            onClaimReward: {
                                if let tier = milestone.tier {
                                    onClaimReward(tier)
                                }
                            }
                        )
                        .position(positions[index])
                        .id(index)
                    }
                }
            }
            .frame(width: width, height: totalHeight)
        }
    }

    /// Calculate positions for all tiles along the serpentine path
    /// Index 0 = lowest value (2) at bottom, higher indices = higher values going up
    private func calculateAllPositions(count: Int, width: CGFloat) -> [CGPoint] {
        guard count > 0 else { return [] }

        var positions: [CGPoint] = []
        let leftX = width * 0.25
        let rightX = width * 0.75
        let verticalSpacing: CGFloat = 100
        let tilesPerSection = 2

        // Calculate total height first
        let totalHeight = CGFloat(count) * verticalSpacing + 100

        // Build positions from bottom (index 0 = tile "2") to top (highest values)
        for i in 0..<count {
            let sectionIndex = i / tilesPerSection
            let posInSection = i % tilesPerSection
            let sectionOnRight = (sectionIndex % 2 == 0)

            // Y position: index 0 at bottom, increasing index goes up
            let y = totalHeight - CGFloat(i) * verticalSpacing - 50

            // X position: alternating left/right sections
            let x: CGFloat
            if sectionOnRight {
                // Right section
                if posInSection == 0 {
                    x = rightX
                } else {
                    x = rightX - (rightX - width * 0.5) * 0.4
                }
            } else {
                // Left section
                if posInSection == 0 {
                    x = leftX
                } else {
                    x = leftX + (width * 0.5 - leftX) * 0.4
                }
            }

            positions.append(CGPoint(x: x, y: y))
        }

        return positions
    }
}

// MARK: - Serpentine Road Path

private struct SerpentineRoadPath: View {
    let positions: [CGPoint]
    let roadWidth: CGFloat

    var body: some View {
        ZStack {
            // Road edge (darker, wider)
            RoadShape(positions: positions)
                .stroke(
                    Color(red: 0.20, green: 0.20, blue: 0.25),
                    style: StrokeStyle(lineWidth: roadWidth + 8, lineCap: .round, lineJoin: .round)
                )

            // Main road
            RoadShape(positions: positions)
                .stroke(
                    Color(red: 0.45, green: 0.45, blue: 0.50),
                    style: StrokeStyle(lineWidth: roadWidth, lineCap: .round, lineJoin: .round)
                )

            // Dashed center line
            RoadShape(positions: positions)
                .stroke(
                    Color.white.opacity(0.7),
                    style: StrokeStyle(
                        lineWidth: 3,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: [12, 10]
                    )
                )
        }
    }
}

private struct RoadShape: Shape {
    let positions: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var roadPath = Path()
        guard positions.count > 1 else { return roadPath }

        // Start below the first position (bottom of screen, lowest tile value)
        let first = positions[0]
        roadPath.move(to: CGPoint(x: first.x, y: first.y + 80))
        roadPath.addLine(to: first)

        // Draw smooth S-curves through all positions
        for i in 1..<positions.count {
            let current = positions[i]
            let prev = positions[i - 1]

            // Calculate midpoint Y
            let midY = (prev.y + current.y) / 2

            // Create S-curve
            roadPath.addCurve(
                to: current,
                control1: CGPoint(x: prev.x, y: midY),
                control2: CGPoint(x: current.x, y: midY)
            )
        }

        // Extend past the last position (top of screen, highest tile value)
        if let last = positions.last {
            roadPath.addLine(to: CGPoint(x: last.x, y: last.y - 80))
        }

        return roadPath
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

import SwiftUI
import GameApp
import GameCore

public struct JourneyPanel: View {
    @Environment(\.gameStore) private var gameStore
    let showAll: Bool

    @State private var stepsAhead: Int = InfiniteRoadMetrics.initialDynamicSteps

    public init(showAll: Bool = false) {
        self.showAll = showAll
    }

    public var body: some View {
        let milestones = roadMilestones
        let totalHeight = CGFloat(milestones.count) * InfiniteRoadMetrics.milestoneSpacing + InfiniteRoadMetrics.horizonHeight

        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .top) {
                    // Road background
                    InfiniteRoadCanvas(totalHeight: totalHeight)
                        .frame(height: totalHeight)

                    // Milestones
                    VStack(spacing: 0) {
                        ForEach(milestones) { milestone in
                            RoadMilestoneSection(
                                milestone: milestone,
                                isFirst: milestone.id == 0,
                                isLast: milestone.id == milestones.count - 1
                            ) {
                                if let tier = milestone.tier {
                                    gameStore.presentJourneyReward(for: tier)
                                }
                            }
                            .id(milestone.id)
                            .onAppear { handleMilestoneAppear(milestone) }
                        }

                        InfinityHorizon()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: totalHeight)
            }
            .onAppear {
                if let currentMilestone = milestones.first(where: { $0.status == .current }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            proxy.scrollTo(currentMilestone.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(InfiniteRoadSky())
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: stepsAhead)
        .onAppear {
            if showAll {
                stepsAhead = InfiniteRoadMetrics.maxDynamicSteps
            }
        }
        .onChange(of: showAll) { _, _ in
            if showAll {
                stepsAhead = InfiniteRoadMetrics.maxDynamicSteps
            }
        }
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

    var roadMilestones: [RoadMilestone] {
        let tiles: [Tile]
        if showAll {
            tiles = JourneyTileGenerator.generateFullJourney()
        } else {
            tiles = JourneyTileGenerator.generateJourney(highest: highestTile, stepsAhead: stepsAhead)
        }
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

            let status: RoadMilestone.Status
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

            return RoadMilestone(
                id: index,
                tile: tile,
                label: JourneyPanel.formatLabel(for: tile),
                tier: tierInfo?.tier,
                status: status,
                isUnlocked: isUnlocked,
                isRewardAvailable: rewardAvailable,
                isRewardClaimed: rewardClaimed
            )
        }
    }

    static func formatLabel(for tile: Tile) -> String {
        if tile.isInfinity {
            return "∞"
        }
        if let step = tile.stepIndex {
            return JourneyTileGenerator.formatTileAtStep(step)
        }
        return AlphaMag.formatTileValue(tile.value)
    }

    func handleMilestoneAppear(_ milestone: RoadMilestone) {
        guard !showAll else { return }
        let thresholdIndex = max(0, roadMilestones.count - InfiniteRoadMetrics.prefetchThreshold)
        if milestone.id >= thresholdIndex && stepsAhead < InfiniteRoadMetrics.maxDynamicSteps {
            stepsAhead += InfiniteRoadMetrics.dynamicStepIncrement
        }
    }
}

// MARK: - Infinite Road Background

private struct InfiniteRoadSky: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.08, blue: 0.18),
                Color(red: 0.02, green: 0.03, blue: 0.08),
                Color(red: 0.0, green: 0.0, blue: 0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            StarsOverlay()
        )
        .ignoresSafeArea()
    }
}

private struct StarsOverlay: View {
    var body: some View {
        Canvas { context, size in
            let starCount = 80
            var rng = SeededRNG(seed: 2244)

            for _ in 0..<starCount {
                let x = CGFloat.random(in: 0...size.width, using: &rng)
                let y = CGFloat.random(in: 0...size.height * 0.6, using: &rng)
                let brightness = CGFloat.random(in: 0.3...0.9, using: &rng)
                let starSize = CGFloat.random(in: 1...2.5, using: &rng)

                context.fill(
                    Circle().path(in: CGRect(x: x, y: y, width: starSize, height: starSize)),
                    with: .color(.white.opacity(brightness))
                )
            }
        }
    }
}

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

private struct InfiniteRoadCanvas: View {
    let totalHeight: CGFloat

    var body: some View {
        Canvas { context, size in
            let roadWidth: CGFloat = InfiniteRoadMetrics.roadWidth
            let centerX = size.width / 2

            // Calculate perspective effect - road narrows towards horizon
            let perspectiveFactor = 0.3  // Road narrows to 30% at horizon

            // Road base with perspective
            let roadPath = Path { path in
                let topWidth = roadWidth * perspectiveFactor
                let bottomWidth = roadWidth

                path.move(to: CGPoint(x: centerX - bottomWidth / 2, y: totalHeight))
                path.addLine(to: CGPoint(x: centerX - topWidth / 2, y: 0))
                path.addLine(to: CGPoint(x: centerX + topWidth / 2, y: 0))
                path.addLine(to: CGPoint(x: centerX + bottomWidth / 2, y: totalHeight))
                path.closeSubpath()
            }

            // Draw shadow manually by offsetting and using darker color
            var shadowPath = roadPath
            shadowPath = shadowPath.offsetBy(dx: 0, dy: 4)
            context.fill(
                shadowPath,
                with: .color(.black.opacity(0.3))
            )

            // Main road with gradient
            context.fill(
                roadPath,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.26, green: 0.28, blue: 0.32),
                        Color(red: 0.20, green: 0.22, blue: 0.26),
                        Color(red: 0.18, green: 0.20, blue: 0.24)
                    ]),
                    startPoint: CGPoint(x: centerX, y: 0),
                    endPoint: CGPoint(x: centerX, y: totalHeight)
                )
            )

            // Road edges (yellow lines) with perspective
            let edgeWidth: CGFloat = 4

            // Left edge
            let leftEdgePath = Path { path in
                let topWidth = roadWidth * perspectiveFactor
                let bottomWidth = roadWidth

                path.move(to: CGPoint(x: centerX - bottomWidth / 2, y: totalHeight))
                path.addLine(to: CGPoint(x: centerX - topWidth / 2, y: 0))
                path.addLine(to: CGPoint(x: centerX - topWidth / 2 + edgeWidth * perspectiveFactor, y: 0))
                path.addLine(to: CGPoint(x: centerX - bottomWidth / 2 + edgeWidth, y: totalHeight))
                path.closeSubpath()
            }

            // Right edge
            let rightEdgePath = Path { path in
                let topWidth = roadWidth * perspectiveFactor
                let bottomWidth = roadWidth

                path.move(to: CGPoint(x: centerX + bottomWidth / 2 - edgeWidth, y: totalHeight))
                path.addLine(to: CGPoint(x: centerX + topWidth / 2 - edgeWidth * perspectiveFactor, y: 0))
                path.addLine(to: CGPoint(x: centerX + topWidth / 2, y: 0))
                path.addLine(to: CGPoint(x: centerX + bottomWidth / 2, y: totalHeight))
                path.closeSubpath()
            }

            context.fill(leftEdgePath, with: .color(Color(red: 0.95, green: 0.8, blue: 0.25)))
            context.fill(rightEdgePath, with: .color(Color(red: 0.95, green: 0.8, blue: 0.25)))

            // Center dashed line with perspective
            let dashSegments = 30
            for i in 0..<dashSegments {
                let progress = CGFloat(i) / CGFloat(dashSegments)
                let nextProgress = CGFloat(i + 1) / CGFloat(dashSegments)

                // Skip every other segment for dashed effect
                if i % 2 == 1 { continue }

                let yStart = totalHeight * (1 - progress)
                let yEnd = totalHeight * (1 - nextProgress)

                // Calculate width at each y position
                let widthAtStart = 8 * (1 - progress * 0.7)  // Narrows with perspective
                let widthAtEnd = 8 * (1 - nextProgress * 0.7)

                let dashPath = Path { path in
                    path.move(to: CGPoint(x: centerX - widthAtStart / 2, y: yStart))
                    path.addLine(to: CGPoint(x: centerX - widthAtEnd / 2, y: yEnd))
                    path.addLine(to: CGPoint(x: centerX + widthAtEnd / 2, y: yEnd))
                    path.addLine(to: CGPoint(x: centerX + widthAtStart / 2, y: yStart))
                    path.closeSubpath()
                }

                let fadeOpacity = 0.85 * (1.0 - Double(progress) * 0.5)
                context.fill(
                    dashPath,
                    with: .color(.white.opacity(fadeOpacity))  // Fades with distance
                )
            }
        }
    }
}

// MARK: - Road Milestone Section

private struct RoadMilestoneSection: View {
    let milestone: RoadMilestone
    let isFirst: Bool
    let isLast: Bool
    let rewardAction: () -> Void

    var body: some View {
        ZStack {
            // Distance marker posts on sides
            HStack {
                if milestone.id % 2 == 0 {
                    DistanceMarkerPost(milestone: milestone)
                    Spacer()
                } else {
                    Spacer()
                    DistanceMarkerPost(milestone: milestone)
                }
            }
            .padding(.horizontal, 20)

            // Milestone sign on road
            VStack(spacing: 16) {
                if let status = milestone.rewardStatus {
                    RewardBadge(status: status, action: rewardAction)
                }

                MilestoneRoadSign(milestone: milestone)

                if milestone.status == .current {
                    PlayerVehicle()
                        .offset(y: 20)
                }
            }
        }
        .frame(height: InfiniteRoadMetrics.milestoneSpacing)
        .frame(maxWidth: .infinity)
    }
}

private struct DistanceMarkerPost: View {
    let milestone: RoadMilestone

    var body: some View {
        VStack(spacing: 4) {
            // Sign plate
            VStack(spacing: 2) {
                Text(milestone.label)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(milestone.status == .locked ? .white.opacity(0.5) : .white)

                Text("MILE \(milestone.id + 1)")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(milestone.signBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
            )

            // Post
            Rectangle()
                .fill(Color(red: 0.4, green: 0.4, blue: 0.4))
                .frame(width: 4, height: 30)
        }
    }
}

private struct MilestoneRoadSign: View {
    let milestone: RoadMilestone

    var body: some View {
        ZStack {
            // Sign background
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(milestone.background)
                .frame(width: 100, height: 100)
                .shadow(color: milestone.shadowColor, radius: 16, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(milestone.borderColor, lineWidth: 3)
                )

            VStack(spacing: 4) {
                if milestone.status == .infinity {
                    Image(systemName: "infinity")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                } else {
                    Text(milestone.label)
                        .font(.system(size: milestone.isCompactLabel ? 18 : 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                }

                if milestone.status != .infinity {
                    Text("Level \(milestone.id + 1)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(milestone.accessibilityLabel)
    }
}

private struct PlayerVehicle: View {
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 0) {
            // Glowing indicator
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.yellow, .orange, .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)
                .blur(radius: 8)

            // Vehicle/marker
            ZStack {
                // Shadow
                Ellipse()
                    .fill(.black.opacity(0.4))
                    .frame(width: 50, height: 16)
                    .offset(y: 20)
                    .blur(radius: 4)

                // Car body
                VStack(spacing: 0) {
                    // Top
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.25, blue: 0.25),
                                    Color(red: 0.75, green: 0.15, blue: 0.15)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 36, height: 20)

                    // Body
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.3, blue: 0.3),
                                    Color(red: 0.8, green: 0.2, blue: 0.2)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 44, height: 30)
                }
                .overlay(
                    VStack(spacing: 12) {
                        // Windshield
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.cyan.opacity(0.6))
                            .frame(width: 28, height: 10)

                        // Headlights
                        HStack(spacing: 20) {
                            Circle()
                                .fill(.yellow)
                                .frame(width: 6, height: 6)
                            Circle()
                                .fill(.yellow)
                                .frame(width: 6, height: 6)
                        }
                    }
                )
            }
            .scaleEffect(bounce ? 1.05 : 1.0)
            .offset(y: bounce ? -3 : 0)

            // "YOU ARE HERE" label
            Text("YOU ARE HERE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.black.opacity(0.6))
                )
                .offset(y: 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                bounce = true
            }
        }
    }
}

private struct InfinityHorizon: View {
    @State private var shimmer = false

    var body: some View {
        VStack(spacing: 0) {
            // Road fading into horizon
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.22, blue: 0.26),
                            Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.5),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: InfiniteRoadMetrics.roadWidth, height: 100)

            // Horizon glow
            ZStack {
                // Outer glow
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.4),
                                Color.cyan.opacity(0.2),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 150)
                    .blur(radius: 20)

                // Infinity symbol
                VStack(spacing: 8) {
                    Image(systemName: "infinity")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .purple, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(shimmer ? 0.7 : 1.0)

                    Text("THE ROAD NEVER ENDS")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .tracking(2)
                }
            }
            .padding(.top, 20)
        }
        .frame(height: InfiniteRoadMetrics.horizonHeight)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

// MARK: - Reward Badge

private struct RewardBadge: View {
    enum Status {
        case available
        case claimed
    }

    let status: Status
    let action: () -> Void

    var body: some View {
        Group {
            if status == .available {
                Button(action: action) {
                    badgeContent
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Claim journey reward")
            } else {
                badgeContent
                    .accessibilityLabel("Reward already claimed")
            }
        }
    }

    private var badgeContent: some View {
        HStack(spacing: 6) {
            Image(systemName: "gift.fill")
                .font(.footnote.weight(.bold))
            Text(status == .available ? "Claim" : "Claimed")
                .font(.caption.weight(.bold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(status == .available ? InfiniteRoadColors.rewardAvailable : InfiniteRoadColors.rewardClaimed)
        )
        .foregroundStyle(.white)
    }
}

// MARK: - Models & Constants

private struct RoadMilestone: Identifiable {
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

    var rewardStatus: RewardBadge.Status? {
        if isRewardAvailable { return .available }
        if isRewardClaimed { return .claimed }
        return nil
    }

    var isCompactLabel: Bool {
        label.count > 4
    }

    var signBackgroundColor: Color {
        switch status {
        case .completed:
            return Color(red: 0.15, green: 0.4, blue: 0.25)
        case .current:
            return Color(red: 0.8, green: 0.5, blue: 0.1)
        case .locked:
            return Color(red: 0.25, green: 0.25, blue: 0.3)
        case .infinity:
            return Color(red: 0.3, green: 0.2, blue: 0.5)
        }
    }

    var background: LinearGradient {
        switch status {
        case .completed:
            return InfiniteRoadColors.completedGradient
        case .current:
            return InfiniteRoadColors.currentGradient
        case .locked:
            return InfiniteRoadColors.lockedGradient
        case .infinity:
            return InfiniteRoadColors.infinityGradient
        }
    }

    var borderColor: Color {
        switch status {
        case .completed:
            return Color.white.opacity(0.25)
        case .current:
            return Color.yellow.opacity(0.85)
        case .locked:
            return Color.white.opacity(0.1)
        case .infinity:
            return .cyan
        }
    }

    var shadowColor: Color {
        status == .current ? Color.yellow.opacity(0.45) : Color.black.opacity(0.35)
    }

    var accessibilityLabel: String {
        var base = "Mile \(id + 1), \(label)"
        switch status {
        case .completed:
            base += ", completed"
        case .current:
            base += ", current position"
        case .locked:
            base += ", ahead on the road"
        case .infinity:
            base += ", infinity - the road never ends"
        }

        if isRewardAvailable {
            base += ", reward ready to claim"
        } else if isRewardClaimed {
            base += ", reward claimed"
        }

        return base
    }
}

private enum InfiniteRoadMetrics {
    static let milestoneSpacing: CGFloat = 420  // Much farther apart
    static let roadWidth: CGFloat = 100  // Slightly wider road
    static let horizonHeight: CGFloat = 300  // Taller horizon
    static let initialDynamicSteps: Int = 120  // See more ahead initially
    static let dynamicStepIncrement: Int = 60  // Load more steps at a time
    static let maxDynamicSteps: Int = 1000  // Much further view distance
    static let prefetchThreshold: Int = 5  // Load new content earlier
}

private enum InfiniteRoadColors {
    static let completedGradient = LinearGradient(
        colors: [
            Color(red: 0.2, green: 0.5, blue: 0.35),
            Color(red: 0.12, green: 0.35, blue: 0.25)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let currentGradient = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.4, blue: 0.2),
            Color(red: 0.9, green: 0.25, blue: 0.15)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let lockedGradient = LinearGradient(
        colors: [
            Color(red: 0.22, green: 0.22, blue: 0.28),
            Color(red: 0.14, green: 0.14, blue: 0.18)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let infinityGradient = LinearGradient(
        colors: [
            Color(red: 0.4, green: 0.2, blue: 0.6),
            Color(red: 0.2, green: 0.3, blue: 0.7)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let rewardAvailable = Color(red: 0.97, green: 0.37, blue: 0.36)
    static let rewardClaimed = Color.gray.opacity(0.5)
}

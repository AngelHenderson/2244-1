import SwiftUI
import GameApp
import GameCore

struct JourneyPanel: View {
    @Environment(\.gameStore) private var gameStore
    let showAll: Bool
    
    @State private var stepsAhead: Int = JourneyPanelMetrics.initialDynamicSteps
    
    init(showAll: Bool = false) {
        self.showAll = showAll
    }
    
    var body: some View {
        let milestones = roadMilestones
        
        ScrollView(.vertical, showsIndicators: false) {
            GeometryReader { geometry in
                let effectiveWidth = max(geometry.size.width, JourneyPanelMetrics.minContentWidth)
                let effectiveSize = CGSize(
                    width: effectiveWidth,
                    height: max(geometry.size.height, RoadLayout.contentHeight(for: milestones.count))
                )
                
                let layout = RoadLayout(size: effectiveSize, milestones: milestones)
                
                ZStack(alignment: .top) {
                    RoadBackgroundView(layout: layout)
                    ForEach(layout.entries) { entry in
                        RoadMilestoneView(entry: entry) {
                            if let tier = entry.milestone.tier {
                                gameStore.presentJourneyReward(for: tier)
                            }
                        }
                        .position(entry.position)
                        .onAppear { handleMilestoneAppear(entry.milestone) }
                    }
                }
                .frame(width: effectiveWidth, height: layout.contentHeight, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(height: RoadLayout.contentHeight(for: milestones.count))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 24)
        .background(JourneyPanelBackground())
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: stepsAhead)
        .onAppear {
            if showAll {
                stepsAhead = JourneyPanelMetrics.maxDynamicSteps
            }
        }
        .onChange(of: showAll) { _, _ in
            if showAll {
                stepsAhead = JourneyPanelMetrics.maxDynamicSteps
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
            let tier = JourneyAbbreviationTiers.tier(for: tile)
            let isUnlocked: Bool
            let isClaimed: Bool
            if let tier {
                isUnlocked = gameStore.isAbbreviationTierUnlocked(tier)
                isClaimed = gameStore.hasClaimedAbbreviationTier(tier)
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
            
            let rewardAvailable = tier != nil ? (isUnlocked && !isClaimed) : false
            let rewardClaimed = tier != nil ? (isUnlocked && isClaimed) : false
            
            return RoadMilestone(
                id: index,
                tile: tile,
                label: JourneyPanel.formatLabel(for: tile),
                tier: tier,
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
        let thresholdIndex = max(0, roadMilestones.count - JourneyPanelMetrics.prefetchThreshold)
        if milestone.id >= thresholdIndex && stepsAhead < JourneyPanelMetrics.maxDynamicSteps {
            stepsAhead += JourneyPanelMetrics.dynamicStepIncrement
        }
    }
}

// MARK: - Layout & Rendering

private struct RoadLayout {
    struct Entry: Identifiable {
        let milestone: RoadMilestone
        let position: CGPoint
        
        var id: Int { milestone.id }
    }
    
    let entries: [Entry]
    let contentHeight: CGFloat
    
    init(size: CGSize, milestones: [RoadMilestone]) {
        contentHeight = RoadLayout.contentHeight(for: milestones.count)
        let centerX = size.width / 2
        let amplitude = min(JourneyPanelMetrics.roadAmplitude, (size.width / 2) - 36)
        let offsets = JourneyPanelMetrics.horizontalOffsets
        let baseY = JourneyPanelMetrics.verticalPadding
        let spacing = JourneyPanelMetrics.verticalSpacing
        
        entries = milestones.map { milestone in
            let lane = offsets[milestone.id % offsets.count]
            let position = CGPoint(
                x: centerX + amplitude * lane,
                y: baseY + CGFloat(milestone.id) * spacing
            )
            return Entry(milestone: milestone, position: position)
        }
    }
    
    static func contentHeight(for count: Int) -> CGFloat {
        let rows = max(count - 1, 0)
        return JourneyPanelMetrics.verticalPadding * 2 + CGFloat(rows) * JourneyPanelMetrics.verticalSpacing
    }
}

private struct JourneyPanelBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.02, blue: 0.05),
                Color(red: 0.09, green: 0.09, blue: 0.17)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            RadialGradient(
                colors: [Color.white.opacity(0.12), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 380
            )
        )
    }
}

private struct RoadBackgroundView: View {
    let layout: RoadLayout
    
    var body: some View {
        Canvas { context, size in
            let points = layout.entries.map(\.position)
            guard points.count > 1 else { return }
            var path = Path()
            path.move(to: points[0])
            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                let control = CGPoint(
                    x: (previous.x + current.x) / 2,
                    y: (previous.y + current.y) / 2
                )
                path.addQuadCurve(to: current, control: control)
            }
            
            context.stroke(
                path,
                with: .color(JourneyPanelColors.roadBorder),
                style: StrokeStyle(lineWidth: JourneyPanelMetrics.roadWidth + 18, lineCap: .round)
            )
            
            context.stroke(
                path,
                with: .color(JourneyPanelColors.roadFill),
                style: StrokeStyle(lineWidth: JourneyPanelMetrics.roadWidth, lineCap: .round)
            )
            
            context.stroke(
                path,
                with: .color(.white.opacity(0.45)),
                style: StrokeStyle(
                    lineWidth: 4,
                    lineCap: .round,
                    dash: [28, 20]
                )
            )
        }
        // Placeholder Canvas strokes above mimic road assets. Replace with custom art when ready.
    }
}

private struct RoadMilestoneView: View {
    let entry: RoadLayout.Entry
    let rewardAction: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            if let status = entry.milestone.rewardStatus {
                RewardBadge(status: status, action: rewardAction)
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(entry.milestone.background)
                    .frame(width: 84, height: 84)
                    .shadow(color: entry.milestone.shadowColor, radius: 12, x: 0, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(entry.milestone.borderColor, lineWidth: 3)
                    )
                
                VStack(spacing: 2) {
                    Text(entry.milestone.label)
                        .font(.system(size: entry.milestone.isCompactLabel ? 16 : 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                        .minimumScaleFactor(0.6)
                    Text("Level \(entry.milestone.id + 1)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(6)
                
                if entry.milestone.status == .current {
                    PlayerMarker()
                        .offset(y: -70)
                } else if entry.milestone.status == .infinity {
                    Image(systemName: "infinity")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(entry.milestone.accessibilityLabel)
            
            if entry.milestone.status == .current {
                Text("Current")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                    )
            }
        }
    }
}

private struct PlayerMarker: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.yellow)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.9))
                .frame(width: 3, height: 16)
        }
        .accessibilityHidden(true)
    }
}

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
                .fill(status == .available ? JourneyPanelColors.rewardAvailable : JourneyPanelColors.rewardClaimed)
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
    
    var background: LinearGradient {
        switch status {
        case .completed:
            return JourneyPanelColors.completedGradient
        case .current:
            return JourneyPanelColors.currentGradient
        case .locked:
            return JourneyPanelColors.lockedGradient
        case .infinity:
            return JourneyPanelColors.infinityGradient
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
        var base = "Level \(id + 1), \(label)"
        switch status {
        case .completed:
            base += ", completed"
        case .current:
            base += ", current level"
        case .locked:
            base += ", locked"
        case .infinity:
            base += ", infinity"
        }
        
        if isRewardAvailable {
            base += ", reward ready to claim"
        } else if isRewardClaimed {
            base += ", reward claimed"
        }
        
        return base
    }
}

private enum JourneyPanelMetrics {
    static let minContentWidth: CGFloat = 360
    static let verticalSpacing: CGFloat = 190
    static let verticalPadding: CGFloat = 150
    static let roadWidth: CGFloat = 44
    static let roadAmplitude: CGFloat = 140
    static let horizontalOffsets: [CGFloat] = [-1.0, -0.35, 0.35, 1.0]
    static let initialDynamicSteps: Int = 80
    static let dynamicStepIncrement: Int = 40
    static let maxDynamicSteps: Int = 640
    static let prefetchThreshold: Int = 8
}

private enum JourneyPanelColors {
    static let roadFill = Color(red: 0.17, green: 0.19, blue: 0.28)
    static let roadBorder = Color.black.opacity(0.75)
    
    static let completedGradient = LinearGradient(
        colors: [
            Color(red: 0.26, green: 0.36, blue: 0.61),
            Color(red: 0.13, green: 0.22, blue: 0.44)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let currentGradient = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.31, blue: 0.33),
            Color(red: 0.99, green: 0.64, blue: 0.18)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let lockedGradient = LinearGradient(
        colors: [
            Color(red: 0.18, green: 0.18, blue: 0.26),
            Color(red: 0.11, green: 0.11, blue: 0.15)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let infinityGradient = LinearGradient(
        colors: [Color.purple, Color.blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let rewardAvailable = Color(red: 0.97, green: 0.37, blue: 0.36)
    static let rewardClaimed = Color.gray.opacity(0.5)
}

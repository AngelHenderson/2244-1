import SwiftUI
import GameApp
import GameCore
import GameServices

public struct HomeScreen: View {
    public let onPlay: () -> Void
    @State private var isShowingAllBlocks: Bool = false
    @State private var isShowingCreate: Bool = false
    @State private var isShowingChallenge: Bool = false
    @Environment(\.gameStore) private var gameStore
    @Environment(\.storage) private var storage
    @Environment(\.tileJourney) private var journey
    @State private var didLoadAutosave: Bool = false
    
    public init(onPlay: @escaping () -> Void) {
        self.onPlay = onPlay
    }
    
    private var hasUnclaimedRewards: Bool {
        // Check if there are any unlocked but unclaimed milestones
        journey.milestones().contains { milestone in
            milestone <= journey.highestTile && !journey.claimed.contains(milestone)
        }
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: Tokens.Spacing.lg) {
                // Highest tile block and caption (centered)
                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        let highest = max(2, journey.highestTile)
                        ZStack {
                            TileView(tile: Tile(value: highest), isSelected: false, isValid: true, size: 72)
                            
                            // Unclaimed rewards indicator
                            if hasUnclaimedRewards {
                                VStack {
                                    HStack {
                                        Spacer()
                                        Circle()
                                            .fill(Color.yellow)
                                            .frame(width: 12, height: 12)
                                            .overlay(
                                                Text("!")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                    Spacer()
                                }
                                .padding(4)
                            }
                        }
                        .frame(width: 72, height: 72)
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        Text("Highest Tile")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if hasUnclaimedRewards {
                            Image(systemName: "gift.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                        Spacer()
                    }
                }
                
                // Journey 5-block preview
                JourneyPreview()

                // View all blocks button
                Button(action: { isShowingAllBlocks = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                        Text("View All Blocks")
                            .font(.headline.weight(.semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)

                // Play CTA
                HStack {
                    Spacer()
                    PlayButton(onTap: onPlay)
                    Spacer()
                }
                
                // Create custom challenge
                HStack {
                    Spacer()
                    Button(action: { isShowingCreate = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars")
                            Text("Create")
                                .font(.headline.weight(.semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding()
        }
        .navigationTitle("Home")
        .sheet(isPresented: $isShowingAllBlocks) {
            AllBlocksView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $isShowingCreate) {
            CreateChallengeSheet(onStart: { settings in
                // Map settings to a seed; later we can extend GameStore to use full config
                let seed = settings.seed ?? GameStore.seed(from: "target:\(settings.target) time:\(settings.time) min:\(settings.minTile) lvl:\(settings.levels)")
                gameStore.startCustomGame(seed: seed)
                isShowingCreate = false
                isShowingChallenge = true
            }, onCancel: { isShowingCreate = false })
            .presentationDetents([.large])
        }
        .sheet(isPresented: $isShowingChallenge) {
            HybridGameScreen(isPlayingDismiss: {
                gameStore.registerChallengeCreationCompleted()
                isShowingChallenge = false
            })
        }
        .simultaneousGesture(DragGesture(minimumDistance: .infinity))
        .task {
            if !didLoadAutosave {
                _ = await gameStore.load(from: "autosave", using: storage)
                didLoadAutosave = true
                // Sync journey with loaded highest tile
                journey.didReach(tile: gameStore.state.highestTile)
            }
        }
        .onAppear {
            // Ensure journey is synced with current highest tile
            journey.didReach(tile: gameStore.state.highestTile)
        }
    }
}

// MARK: - All Blocks
private struct AllBlocksView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            JourneyPanel(showAll: true)
                .navigationTitle("Journey")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - Create Challenge
private struct CreateChallengeSheet: View {
    struct Settings {
        var target: String = "1M"
        var time: Int = 60
        var minTile: Int = 10
        var levels: Int = 5
        var leftTiles: [Int] = [64, 128, 256, 512]
        var middleTiles: [Int] = [1024]
        var rightTiles: [Int] = []
        var reward: Int = 209
        var seed: UInt64? = nil
    }
    
    @State private var settings = Settings()
    let onStart: (Settings) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header
                targetRow
                .onChange(of: settings.target) { _, _ in
                    updateTilesForTarget()
                }
                controlsRow
                tilesGrid
                rewardRow
                playButton
            }
            .padding(.horizontal)
            .padding(.bottom)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("DESIGN YOUR OWN\nCHALLENGE")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                    }
                }
            }
            .onAppear { updateTilesForTarget() }
        }
    }
    
    private var header: some View {
        HStack { Spacer(); Text("TARGET").font(.headline.weight(.bold)); Spacer() }
            .padding(.top, 6)
            .padding(.bottom, 4)
    }
    
    private var targetRow: some View {
        HStack(spacing: 16) {
            Button { cycleTarget(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .buttonStyle(.bordered)
            Text(settings.target)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .frame(width: 120, height: 56)
                .background(Color.pink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                //.foregroundStyle(.white)
            Button { cycleTarget(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .buttonStyle(.bordered)
        }
    }
    
    private var controlsRow: some View {
        HStack(spacing: 14) {
            stepperCard(title: "Time", value: $settings.time, step: 10, minValue: 10, maxValue: 1500)
            stepperCard(title: "Min Tile", value: $settings.minTile, step: 1, minValue: 1, maxValue: 10)
            stepperCard(title: "Levels", value: $settings.levels, step: 1, minValue: 1, maxValue: 10)
        }
    }
    
    private var tilesGrid: some View {
        VStack(spacing: 10) {
            HStack { Text("Tiles").font(.headline.weight(.bold)); Spacer(); Text("Tiles").font(.headline.weight(.bold)); Spacer(); Text("Tiles").font(.headline.weight(.bold)) }
            HStack(alignment: .top, spacing: 18) {
                tileColumn(settings.leftTiles)
                tileColumn(settings.middleTiles)
                tileColumn(settings.rightTiles)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    private var rewardRow: some View {
        VStack(spacing: 6) {
            Text("REWARD").font(.headline.weight(.bold))
            HStack(spacing: 8) {
                Image(systemName: "diamond.fill").foregroundStyle(.mint)
                Text("+\(settings.reward)")
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(white: 0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            //.foregroundStyle(.white)
        }
        .onChange(of: settings.time) { _, _ in updateReward() }
        .onChange(of: settings.minTile) { _, _ in updateReward(); updateTilesForTarget() }
        .onChange(of: settings.levels) { _, _ in updateReward(); updateTilesForTarget() }
        .onChange(of: settings.leftTiles) { _, _ in updateReward() }
        .onChange(of: settings.middleTiles) { _, _ in updateReward() }
        .onChange(of: settings.rightTiles) { _, _ in updateReward() }
        // Intentionally NOT listening to target; reward shouldn't change with target per spec
    }
    
    private var playButton: some View {
        Button(action: { onStart(settings) }) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Text("PLAY")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [.green, .green.opacity(0.85)], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            //.foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
    
    private func stepperCard(title: String, value: Binding<Int>, step: Int, minValue: Int, maxValue: Int) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                Button {
                    value.wrappedValue = Swift.max(minValue, value.wrappedValue - step)
                    updateReward()
                } label: { Image(systemName: "minus").frame(width: 28, height: 28) }
                    .buttonStyle(.bordered)
                Text("\(value.wrappedValue)")
                    .frame(width: 44)
                    .font(.headline.monospacedDigit())
                Button {
                    value.wrappedValue = Swift.min(maxValue, value.wrappedValue + step)
                    updateReward()
                } label: { Image(systemName: "plus").frame(width: 28, height: 28) }
                    .buttonStyle(.bordered)
            }
            .padding(10)
            .background(Color(white: 0.2).opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }
    
    private func tileColumn(_ tiles: [Int]) -> some View {
        VStack(spacing: 14) {
            ForEach(tiles, id: \.self) { v in
                TileView(tile: Tile(value: v), isSelected: false, isValid: true, size: 56)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func cycleTarget(_ dir: Int) {
        let options = [
            "1M", "1B",
            "1a", "1b", "1c", "1d", "1e", "1f", "1g", "1h", "1i", "1j",
            "1k", "1l", "1m", "1n", "1o", "1p", "1q", "1r", "1s", "1t",
            "1u", "1v", "1w", "1x", "1y", "1z"
        ]
        guard let idx = options.firstIndex(of: settings.target) else { settings.target = "1M"; return }
        let next = (idx + options.count + dir) % options.count
        settings.target = options[next]
    }

    // MARK: Reward Calculation
    private func updateReward() {
        withAnimation(.easeInOut(duration: 0.2)) {
            settings.reward = computeReward(from: settings)
        }
    }

    private func computeReward(from s: Settings) -> Int {
        // Base reward derived from difficulty knobs excluding target
        // Higher time reduces reward slightly; higher min tile and levels increase reward.
        let timeFactor = max(10, min(600, s.time))
        let minTileFactor = max(1, s.minTile)
        let levelsFactor = max(1, s.levels)

        let tilesAll = s.leftTiles + s.middleTiles + s.rightTiles
        let distinctTiles = Set(tilesAll).count
        let maxTileValue = tilesAll.max() ?? 0

        // Normalize components
        let timeScore = max(5, 70 - timeFactor / 10)                 // less time => higher score
        let minTileScore = minTileFactor * 4                          // tougher base => higher score
        let levelScore = levelsFactor * 6                             // more levels => higher score
        let varietyScore = distinctTiles * 3                          // more tile types => slightly higher
        let maxTileScore = Int(log2(Double(max(2, maxTileValue)))) * 5

        let raw = timeScore + minTileScore + levelScore + varietyScore + maxTileScore

        // Map to gems; clamp and ensure at least 1
        let reward = max(1, min(9999, raw * 3))
        return reward
    }

    // MARK: - Target-driven Tiles Preset
    private func updateTilesForTarget() {
        // Derive a base shift from target, then adjust based on minTile and levels
        // Rules:
        // - 1M target: cap around 1024 as max when minTile is default
        // - 1B target: include 65K, 131K, 262K, 524K, 1M in visible presets
        // - Lower minTile increases overall window upward (max goes up when min goes down)
        // - Levels controls how many distinct tiles are shown across columns
        let targetShift = shiftForTarget(settings.target)
        // Compute a dynamic boost inversely proportional to minTile (1..10)
        // Smaller minTile -> larger boost (up to +4 doublings)
        let minTileBoost = max(0, 11 - max(1, min(10, settings.minTile))) / 3
        let shift = max(0, targetShift + minTileBoost)

        // Base outlines
        let baseLeft = [64, 128, 256, 512]
        let baseMiddle = [1024]

        // Determine how many extra levels to display beyond left/middle
        let totalSlots = max(1, min(10, settings.levels))
        // Start from a seed list and extend if needed
        var seeds: [Int] = baseLeft + baseMiddle
        while seeds.count < totalSlots {
            let last = seeds.last ?? 1024
            if last > (Int.max >> 1) { seeds.append(Int.max) } else { seeds.append(last << 1) }
        }

        // Apply shift
        let shifted = shiftTiles(seeds, by: shift)

        // Split across columns roughly like before
        settings.leftTiles = Array(shifted.prefix(min(4, shifted.count)))
        settings.middleTiles = shifted.count > 4 ? [shifted[4]] : []
        settings.rightTiles = shifted.count > 5 ? Array(shifted.suffix(from: 5).prefix(4)) : []
    }

    private func shiftForTarget(_ target: String) -> Int {
        if target == "1M" { return 0 } // around 1024 cap with default minTile
        if target == "1B" { return 6 } // 64->4096, 1024->65536 baseline
        if target.hasPrefix("1"), let suffix = target.last, suffix.isLowercase {
            let letters = Array("abcdefghijklmnopqrstuvwxyz")
            if let idx = letters.firstIndex(of: suffix) {
                return 6 + (idx + 1) * 2
            }
        }
        return 0
    }

    private func shiftTiles(_ tiles: [Int], by power: Int) -> [Int] {
        guard power > 0 else { return tiles }
        return tiles.map { v in
            if v <= 0 { return v }
            if power >= 62 { return Int.max }
            let limit = Int.max >> power
            if v > limit { return Int.max }
            return v << power
        }
    }
}





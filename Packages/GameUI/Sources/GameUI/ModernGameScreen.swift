import SwiftUI
import GameApp
import GameCore
import GameServices

/// Modern three-zone game screen: HUD + Board + Dock
/// Adapted from reference implementation to work with existing GameStore architecture
public struct ModernGameScreen: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.adService) private var adService
    @Environment(\.hapticsService) private var haptics
    @Environment(\.gameCenter) private var gameCenter
    
    @State private var isShowingTopMergeTile: Bool = false
    @State private var topMergeTileValue: Int? = nil
    @State private var isShowingDoublePrompt: Bool = false
    
    // Sheet states
    @State private var isShowingPause = false
    @State private var isShowingStore = false
    @State private var isShowingLeaderboard = false
    
    // Closure injected by parent to dismiss gameplay (return to Home)
    public var isPlayingDismiss: (() -> Void)? = nil
    
    public init(isPlayingDismiss: (() -> Void)? = nil) {
        self.isPlayingDismiss = isPlayingDismiss
    }
    
    public var body: some View {
        ZStack {
            // Modern solid background - no glass effects
            ModernTheme.bg.ignoresSafeArea()

            GeometryReader { geo in
                let availableW = geo.size.width - ModernTheme.gutter * 2
                let availableH = geo.size.height - (ModernTheme.hudHeight + ModernTheme.dockHeight) - ModernTheme.gutter * 2
                let boardSide = min(availableW, availableH)

                VStack {
                    Spacer(minLength: ModernTheme.hudHeight)
                    
                    ModernBoardPlate(side: boardSide)
                        .accessibilityIdentifier("BoardPlate")

                    Spacer(minLength: ModernTheme.dockHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, ModernTheme.gutter)
            }
        }
        .safeAreaInset(edge: .top) { 
            ModernHUDBar(
                rank: 536,
                onLeaderboard: { isShowingLeaderboard = true },
                onBuy: { isShowingStore = true },
                onPause: { isShowingPause = true }
            )
        }
        .safeAreaInset(edge: .bottom) { 
            ModernPowerupDock(
                onHammer: handleHammer,
                onShuffle: handleShuffle,
                onTarget: handleTarget,
                onAdGift: { gameStore.addCoins(50) },
                onHome: { isPlayingDismiss?() }
            )
        }
        // Top merge tile animation overlay
        .overlay(alignment: .top) {
            if isShowingTopMergeTile, let v = topMergeTileValue {
                let currentLabel = CompactNumberFormatter.format(v)
                let nextVal = v > 0 && v <= (Int.max >> 1) ? v * 2 : v
                let nextLabel = CompactNumberFormatter.format(nextVal)
                HStack {
                    Spacer(minLength: 0)
                    Text("\(currentLabel) >> \(nextLabel)")
                        .font(.title3.weight(.black))
                        //.foregroundStyle(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.top, 8)
                        .shadow(radius: 6)
                    Spacer(minLength: 0)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        // Sheets
        .sheet(isPresented: $isShowingPause) { 
            PauseSheet(onResume: { isShowingPause = false }, onRestart: { gameStore.resetGame(); isShowingPause = false }) 
        }
        .sheet(isPresented: $isShowingStore) { 
            StoreView() 
        }
        .sheet(isPresented: $isShowingLeaderboard) { 
            LeaderboardView() 
        }
        .sheet(isPresented: Binding(
            get: { gameStore.pendingUnlockRewardBase != nil },
            set: { newValue in if !newValue { gameStore.clearPendingUnlockReward() } }
        )) {
            RewardSpinnerView(
                baseAmount: gameStore.pendingUnlockRewardBase ?? 0,
                tileValue: gameStore.pendingUnlockTile ?? 0,
                onClose: { gameStore.clearPendingUnlockReward() }
            )
        }
        .sheet(isPresented: Binding(
            get: { gameStore.lastMergeInfo != nil },
            set: { newValue in if !newValue { gameStore.clearLastMergeInfo() } }
        )) {
            if let info = gameStore.lastMergeInfo {
                MergeInfoBoard(info: info, onClose: { gameStore.clearLastMergeInfo() })
            }
        }
        .alert("Double your tile?", isPresented: $isShowingDoublePrompt) {
            Button("No", role: .cancel) { gameStore.clearPendingDoubleOffer() }
            Button("Yes") { /* Dismiss and wait for user to tap a tile */ }
        } message: {
            if let base = gameStore.pendingDoubleBase {
                Text("Tap a target tile to set it to \(base * 2).")
            } else {
                Text("Tap a target tile.")
            }
        }
        .onChange(of: gameStore.lastAddedTileValue) { _, newValue in
            guard let v = newValue else { return }
            let highest = max(0, gameStore.state.highestTile)
            let oneBeforeHighest = highest >= 4 ? highest / 2 : 0
            guard oneBeforeHighest > 0, v == oneBeforeHighest else { return }
            topMergeTileValue = v
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isShowingTopMergeTile = true
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    isShowingTopMergeTile = false
                }
            }
        }
        .onChange(of: gameStore.pendingDoubleBase) { _, newValue in
            isShowingDoublePrompt = (newValue != nil)
        }
    }
    
    // MARK: - Power-up Handlers
    
    private func handleHammer() {
        haptics.lightImpact()
        // TODO: Implement hammer selection mode
    }
    
    private func handleShuffle() {
        if gameStore.coins >= GameStore.PowerUpCost.shuffle { 
            _ = gameStore.useShuffle()
            haptics.success() 
        } else { 
            haptics.error() 
        }
    }
    
    private func handleTarget() {
        haptics.lightImpact()
        // TODO: Implement target/scope power-up
    }
}

// MARK: - Modern Theme Tokens

enum ModernTheme {
    static let bg = Color(red: 0.05, green: 0.06, blue: 0.09)            // #0C0E16
    static let boardPlate = Color(red: 0.06, green: 0.08, blue: 0.13)     // #0F1422
    static let gutter: CGFloat = 8
    static let hudHeight: CGFloat = 56
    static let dockHeight: CGFloat = 76
    static let boardInset: CGFloat = 12
    static let gridGap: CGFloat = 6
    static let tileRadius: CGFloat = 12
    static let boardRadius: CGFloat = 20
}

// MARK: - Modern HUD Bar

struct ModernHUDBar: View {
    @Environment(\.gameStore) private var gameStore
    let rank: Int
    let onLeaderboard: () -> Void
    let onBuy: () -> Void
    let onPause: () -> Void
    
    var body: some View {
        HStack {
            // Left: Rank badge
            Text("Rank: \(rank.formatted(.number.grouping(.automatic)))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .contentShape(.rect)
                .onTapGesture { onLeaderboard() }

            Spacer()

            // Center: Score (hero metric)
            Text(gameStore.state.score.formatted(.number.grouping(.automatic)))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                //.foregroundStyle(.white)

            Spacer()

            // Right: Gems + Plus + Pause
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .foregroundStyle(.mint)
                    Text("\(gameStore.coins)")
                        .monospacedDigit()
                    Button {
                        onBuy()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 15, weight: .semibold))
                
                Button {
                    onPause()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(.regularMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: ModernTheme.hudHeight)
        .background(.clear) // Clean, no material blur
        .overlay(Divider().opacity(0.3), alignment: .bottom)
        .accessibilityIdentifier("ModernHUDBar")
    }
}

// MARK: - Modern Board Plate

struct ModernBoardPlate: View {
    @Environment(\.gameStore) private var gameStore
    let side: CGFloat
    
    var body: some View {
        let board = gameStore.state.board
        let cols = board.width
        let rows = board.height
        let gap = ModernTheme.gridGap
        let inner = side - ModernTheme.boardInset * 2
        let tileW = (inner - CGFloat(cols - 1) * gap) / CGFloat(cols)
        let tileH = (inner - CGFloat(rows - 1) * gap) / CGFloat(rows)

        return ZStack {
            // Solid board background (no glass effects)
            RoundedRectangle(cornerRadius: ModernTheme.boardRadius, style: .continuous)
                .fill(ModernTheme.boardPlate)
                .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 3)

            // Grid
            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: gap) {
                        ForEach(0..<cols, id: \.self) { c in
                            let position = Position(row: r, col: c)
                            let tile = board[position]
                            let value = tile?.value ?? 0
                            
                            ModernTile(value: value)
                                .frame(width: tileW, height: tileH)
                                .clipShape(RoundedRectangle(cornerRadius: ModernTheme.tileRadius, style: .continuous))
                                .contentShape(.rect)
                                .onTapGesture {
                                    if gameStore.pendingDoubleBase != nil {
                                        _ = gameStore.applyDouble(to: position)
                                    }
                                }
                        }
                    }
                }
            }
            .padding(ModernTheme.boardInset)
        }
        .frame(width: side, height: side)
    }
}

// MARK: - Modern Tile

struct ModernTile: View {
    let value: Int

    var body: some View {
        let text = value == 0 ? "" : TileLabelFormatter.format(value)
        let bg = Theme.color(for: value)
        let textColor = Theme.textColor(for: value)

        ZStack {
            bg
            Text(text)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(textColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Modern Power-up Dock

struct PowerUpItem: Identifiable, Hashable {
    let id: String
    let label: String
    let systemImage: String
    let cost: Int
    var count: Int = 0  // For owned items
    
    static let hammer = PowerUpItem(id: "hammer", label: "Hammer", systemImage: "hammer.fill", cost: GameStore.PowerUpCost.hammer)
    static let shuffle = PowerUpItem(id: "shuffle", label: "Shuffle", systemImage: "arrow.triangle.2.circlepath", cost: GameStore.PowerUpCost.shuffle)
    static let target = PowerUpItem(id: "target", label: "Target", systemImage: "scope", cost: 75)
}

struct ModernPowerupDock: View {
    @Environment(\.gameStore) private var gameStore
    let onHammer: () -> Void
    let onShuffle: () -> Void
    let onTarget: () -> Void
    let onAdGift: () -> Void
    let onHome: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                // Power-ups
                powerUpButton(.hammer, action: onHammer)
                powerUpButton(.shuffle, action: onShuffle)
                powerUpButton(.target, action: onTarget)
                
                Spacer()
                
                // Utility buttons
                Button {
                    onAdGift()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "gift.fill")
                            .imageScale(.medium)
                        Text("FREE")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .frame(width: 48, height: 48)
                    //.foregroundStyle(.white)
                    .background(.green, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button {
                    onHome()
                } label: {
                    Image(systemName: "house.fill")
                        .imageScale(.medium)
                        .frame(width: 48, height: 48)
                        //.foregroundStyle(.white)
                        .background(ModernTheme.boardPlate, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Text("HAMMER  •  Break any tile on the board")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(height: ModernTheme.dockHeight)
        .background(
            LinearGradient(
                colors: [ModernTheme.bg.opacity(0.6), ModernTheme.bg], 
                startPoint: .top, 
                endPoint: .bottom
            )
        )
        .overlay(Divider().opacity(0.3), alignment: .top)
        .accessibilityIdentifier("ModernPowerupDock")
    }
    
    @ViewBuilder
    private func powerUpButton(_ powerUp: PowerUpItem, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(ModernTheme.boardPlate)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: powerUp.systemImage)
                            .imageScale(.medium)
                            //.foregroundStyle(.white)
                    }

                // Cost badge (always show cost for power-ups)
                HStack(spacing: 3) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 8))
                    Text("\(powerUp.cost)")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.black.opacity(0.8), in: Capsule())
                //.foregroundStyle(.white)
                .offset(x: 6, y: -6)
            }
        }
        .buttonStyle(ModernPowerUpButtonStyle())
        .disabled(gameStore.coins < powerUp.cost)
        .opacity(gameStore.coins < powerUp.cost ? 0.5 : 1.0)
        .accessibilityLabel("\(powerUp.label), costs \(powerUp.cost) gems")
    }
}

// MARK: - Button Style

struct ModernPowerUpButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

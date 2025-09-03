import SwiftUI
import GameApp
import GameCore
import GameServices

public struct GameScreen: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.adService) private var adService
    @Environment(\.hapticsService) private var haptics
    @Environment(\.gameCenter) private var gameCenter
    
    @State private var scope: LeaderboardScope = .week
    @State private var isShowingTopMergeTile: Bool = false
    @State private var topMergeTileValue: Int? = nil
    @State private var isShowingDoublePrompt: Bool = false
    // Closure injected by parent to dismiss gameplay (return to Home)
    public var isPlayingDismiss: (() -> Void)? = nil
    
    public init(isPlayingDismiss: (() -> Void)? = nil) {
        self.isPlayingDismiss = isPlayingDismiss
    }
    
    public var body: some View {
        ZStack {
            BackgroundView()
                .allowsHitTesting(false)
            
            VStack(spacing: 8) {
                // Top HUD (rank, milestones track, gems)
                TopHUD(
                    rank: 536,
                    milestones: dynamicMilestones(),
                    onLeaderboard: { isShowingLeaderboard = true },
                    onBuy: { isShowingStore = true },
                    onPause: { isShowingPause = true }
                )
                .allowsHitTesting(true)
                .padding(.top, 8)
                
                // Main game area with glass preview
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        // Calculate the board container size safely
                        let availableWidth = max(0, proxy.size.width - 32)
                        let availableHeight = max(0, proxy.size.height - 100)
                        let maxBoardSize = max(0, min(availableWidth, availableHeight))
                        
                        // Board container with glass preview
                        ZStack {
                            RoundedRectangle(cornerRadius: Tokens.Radius.frame, style: .continuous)
                                .fill(.black.opacity(0.35))
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Tokens.Radius.frame, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Tokens.Radius.frame, style: .continuous)
                                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                                )
                                .shadow(color: Tokens.Shadow.board, radius: Tokens.Shadow.boardRadius, y: Tokens.Shadow.boardOffsetY)
                                .accessibilityHidden(true)
                                .allowsHitTesting(false)
                            
                            SimplifiedGlassBoardView(onTileTap: { position in
                                if gameStore.pendingDoubleBase != nil {
                                    _ = gameStore.applyDouble(to: position)
                                    isShowingDoublePrompt = false
                                }
                            })
                            .padding(Tokens.Spacing.sm)
                            .accessibilityLabel("Game board with glass preview")
                        }
                        .frame(width: maxBoardSize, height: maxBoardSize)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Bottom reserve rail (crown tile)
                        BottomRail(reserveLabel: "1w")
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        // Side toolbars over entire screen, above all other content
        .overlay(alignment: .leading) {
            LeftToolbar(
                onPause: { isShowingPause = true },
                onShop: { isShowingStore = true },
                onAdGift: { gameStore.addCoins(50) },
                onHome: { isPlayingDismiss?() }
            )
            .padding(.horizontal)
            .zIndex(20)
            .allowsHitTesting(true)
        }
        .overlay(alignment: .trailing) {
            RightToolbar(
                onHammer: { haptics.lightImpact() },
                onShuffle: {
                    if gameStore.coins >= GameStore.PowerUpCost.shuffle { _ = gameStore.useShuffle(); haptics.success() } else { haptics.error() }
                },
                onMagnet: { /* reserved booster */ }
            )
            .padding(.horizontal)
            .zIndex(20)
            .allowsHitTesting(true)
        }
        .overlay(alignment: .top) {
            if isShowingTopMergeTile, let v = topMergeTileValue {
                let currentLabel = CompactNumberFormatter.format(v)
                let nextVal = v > 0 && v <= (Int.max >> 1) ? v * 2 : v
                let nextLabel = CompactNumberFormatter.format(nextVal)
                HStack {
                    Spacer(minLength: 0)
                    Text("\(currentLabel) >> \(nextLabel)")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
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
        // Bottom powerup bar is represented by right toolbar + reserve rail in this layout
        .sheet(isPresented: $isShowingPause) { PauseSheet(onResume: { isShowingPause = false }, onRestart: { gameStore.resetGame(); isShowingPause = false }) }
        .sheet(isPresented: $isShowingStore) { StoreView() }
        .sheet(isPresented: $isShowingLeaderboard) { LeaderboardView() }
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
            // Show prompt whenever a double offer is available
            isShowingDoublePrompt = (newValue != nil)
        }
    }
    
    private func dynamicMilestones() -> [TopHUD.Milestone] {
        let highest = max(2, gameStore.state.highestTile)
        let minAllowed = max(2, gameStore.currentMinAllowedTile())
        let current = highest
        let next = current > 0 && current < (Int.max >> 1) ? current * 2 : current
        func label(_ v: Int) -> String { TileLabelFormatter.format(v) }
        return [
            .init(label: label(minAllowed), isCurrent: false),
            .init(label: label(current), isCurrent: true),
            .init(label: label(next), isCurrent: false)
        ]
    }
    @State private var isShowingPause = false
    @State private var isShowingStore = false
    @State private var isShowingLeaderboard = false
}

// LeaderboardScope moved to HybridGameScreen to avoid duplicate declarations

// MARK: - HUD Bar
private struct HUDBar: View {
    @Environment(\.gameStore) private var gameStore
    @Binding var scope: LeaderboardScope
    let onPause: () -> Void
    let onBuy: () -> Void
    
    var body: some View {
        HStack(spacing: Tokens.Spacing.md) {
            Button(action: onPause) {
                Image(systemName: "pause.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel("Pause")
            
            Spacer(minLength: Tokens.Spacing.lg)
            
            Picker("Leaderboard", selection: $scope) {
                ForEach(LeaderboardScope.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            .accessibilityLabel("Leaderboard scope")
            
            Spacer(minLength: Tokens.Spacing.lg)
            
            HStack(spacing: Tokens.Spacing.sm) {
                HStack(spacing: Tokens.Spacing.xs) {
                    Image(systemName: "trophy.fill")
                    Text("536").monospacedDigit()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                
                HStack(spacing: Tokens.Spacing.xs) {
                    Image(systemName: "diamond.fill")
                    Text("\(gameStore.coins)").monospacedDigit()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                
                Button(action: onBuy) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Buy Gems")
            }
        }
    }
}

// MARK: - Bottom Power-up Toolbar
private struct PowerupToolbar: View {
    @Environment(\.gameStore) private var gameStore
    let onHammer: () -> Void
    let onShuffle: () -> Void
    let onUndo: () -> Void
    
    var body: some View {
        HStack(spacing: Tokens.Spacing.md) {
            powerupButton(symbol: "hammer.fill", label: "Hammer", cost: GameStore.PowerUpCost.hammer, disabled: gameStore.coins < GameStore.PowerUpCost.hammer, action: onHammer)
            powerupButton(symbol: "arrow.triangle.2.circlepath.circle.fill", label: "Shuffle", cost: GameStore.PowerUpCost.shuffle, disabled: gameStore.coins < GameStore.PowerUpCost.shuffle, action: onShuffle)
            powerupButton(symbol: "arrow.uturn.backward.circle.fill", label: "Undo", cost: 0, disabled: !gameStore.state.undoAvailable, action: onUndo)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
    
    @ViewBuilder
    private func powerupButton(symbol: String, label: String, cost: Int, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.sm) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                Text(label)
                    .font(.body.weight(.semibold))
                if cost > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill")
                        Text("\(cost)").monospacedDigit()
                    }
                    .font(.callout.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.thinMaterial, in: Capsule())
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(disabled)
        .opacity(disabled ? 0.6 : 1)
        .accessibilityLabel("\(label) \(cost > 0 ? "cost \(cost)" : "")")
    }
}

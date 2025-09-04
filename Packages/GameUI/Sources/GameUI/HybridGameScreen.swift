import SwiftUI
import GameApp
import GameCore
import GameServices
#if os(macOS)
import AppKit
#endif

/// Hybrid screen combining original GameScreen mechanics with modern styling
public struct HybridGameScreen: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.adService) private var adService
    @Environment(\.hapticsService) private var haptics
    @Environment(\.gameCenter) private var gameCenter
    @Environment(\.backgroundThemeRegistry) private var backgroundThemeRegistry
    
    @State private var scope: LeaderboardScope = .week
    @State private var isShowingTopMergeTile: Bool = false
    @State private var topMergeTileValue: Int? = nil
    @State private var isShowingDoublePrompt: Bool = false
    @State private var isShowingPause = false
    @State private var isShowingStore = false
    @State private var isShowingLeaderboard = false
    
    // Power-up selection modes
    @State private var isHammerMode = false
    @State private var isSwapMode = false
    @State private var isMagnetMode = false
    @State private var firstSwapPosition: Position? = nil
    @State private var magnetTargetValue: Int? = nil
    
    // Background theme selection stored in AppStorage  
    @AppStorage("selectedBackgroundId") private var selectedBackgroundId: String = "city_1"
    
    private var currentBackgroundTheme: BackgroundTheme {
        backgroundThemeRegistry.theme(for: selectedBackgroundId)
    }
    
    // Closure injected by parent to dismiss gameplay (return to Home)
    public var isPlayingDismiss: (() -> Void)? = nil
    
    public init(isPlayingDismiss: (() -> Void)? = nil) {
        self.isPlayingDismiss = isPlayingDismiss
    }
    
    public var body: some View {
        ZStack {
            // Theme background using new BackgroundTheme system
            ThemedBackground(theme: currentBackgroundTheme)

            GeometryReader { geo in
                // Clamp available dimensions to non-negative to avoid invalid frames
                let availableW = max(0, geo.size.width - ModernTheme.gutter * 2)
                let hudAndDockHeight = ModernTheme.hudHeight + ModernTheme.dockHeight
                let availableH = max(0, geo.size.height - hudAndDockHeight - ModernTheme.gutter * 2)
                let boardSide = max(0, min(availableW, availableH))

                VStack(spacing: 12) {
                    Spacer(minLength: ModernTheme.hudHeight)
                    
                    // Board container with glass preview (clear background)
                    ZStack {
                        // CRITICAL: Use SimplifiedGlassBoardView for merge logic and glass preview
                        SimplifiedGlassBoardView(onTileTap: { position in
                            handleTileTap(at: position)
                        })
                        .padding(ModernTheme.boardInset)
                        .accessibilityLabel("Game board with glass preview")
                        
                        // Mode overlay indicators
                        if isHammerMode || isSwapMode || isMagnetMode {
                            ModeOverlay(
                                isHammerMode: isHammerMode,
                                isSwapMode: isSwapMode,
                                isMagnetMode: isMagnetMode,
                                firstSwapPosition: firstSwapPosition,
                                onCancel: cancelAllModes
                            )
                        }
                    }
                    .frame(width: boardSide, height: boardSide)

                    Spacer(minLength: ModernTheme.dockHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, ModernTheme.gutter)
            }
        }
        .safeAreaInset(edge: .top) { 
            // Enhanced HUD with milestone progression
            EnhancedHUDBar(
                scope: $scope,
                rank: calculateRank(),
                milestones: dynamicMilestones(),
                onLeaderboard: { isShowingLeaderboard = true },
                onBuy: { isShowingStore = true },
                onPause: { isShowingPause = true },
                onThemeChange: { 
                    // Cycle through background themes
                    let allThemes = backgroundThemeRegistry.allThemes()
                    if let currentIndex = allThemes.firstIndex(where: { $0.id == selectedBackgroundId }) {
                        let nextIndex = (currentIndex + 1) % allThemes.count
                        selectedBackgroundId = allThemes[nextIndex].id
                    }
                }
            )
        }
        .safeAreaInset(edge: .bottom) { 
            // Enhanced power-up dock with better layout
            EnhancedPowerupDock(
                onHammer: handleHammer,
                onShuffle: handleShuffle,
                onSwap: handleSwap,
                onMagnet: handleMagnet,
                onUndo: handleUndo,
                onPause: { isShowingPause = true },
                onShop: { isShowingStore = true },
                onAdGift: { 
                    Task { @MainActor in
                        _ = await adService.showRewarded {
                            gameStore.addCoins(50)
                        }
                    }
                },
                onHome: { isPlayingDismiss?() }
            )
        }
        
        // Top merge tile animation
        .overlay(alignment: .top) {
            if isShowingTopMergeTile, let v = topMergeTileValue {
                TopMergeTileView(value: v)
            }
        }
        
        // Sheets
        .sheet(isPresented: $isShowingPause) { 
            PauseSheet(
                onResume: { isShowingPause = false },
                onRestart: { 
                    gameStore.resetGame()
                    isShowingPause = false
                }
            )
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
        
        // Double offer alert
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
        
        // OnChange handlers
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
    
    // MARK: - Helper Methods
    
    private func calculateRank() -> Int {
        // Calculate rank based on score
        return max(1, 100000 - gameStore.state.score)
    }
    
    private func dynamicMilestones() -> [Milestone] {
        let highest = max(2, gameStore.state.highestTile)
        let minAllowed = max(2, gameStore.currentMinAllowedTile())
        let current = highest
        let next = current > 0 && current < (Int.max >> 1) ? current * 2 : current
        return [
            Milestone(value: minAllowed, label: TileLabelFormatter.format(minAllowed), isCurrent: false, isLocked: false),
            Milestone(value: current, label: TileLabelFormatter.format(current), isCurrent: true, isLocked: false),
            Milestone(value: next, label: TileLabelFormatter.format(next), isCurrent: false, isLocked: true)
        ]
    }

    
    // MARK: - Power-up Handlers
    
    private func handleHammer() {
        if gameStore.isPowerUpAvailable("hammer") {
            cancelAllModes()
            isHammerMode = true
            haptics.lightImpact()
        } else {
            haptics.error()
        }
    }
    
    private func handleShuffle() {
        if gameStore.isPowerUpAvailable("shuffle") {
            _ = gameStore.useShuffle()
            haptics.success()
        } else {
            haptics.error()
        }
    }
    
    private func handleSwap() {
        if gameStore.isPowerUpAvailable("swap") {
            cancelAllModes()
            isSwapMode = true
            firstSwapPosition = nil
            haptics.lightImpact()
        } else {
            haptics.error()
        }
    }
    
    private func handleUndo() {
        if gameStore.state.undoAvailable {
            _ = gameStore.useUndo()
            haptics.lightImpact()
        } else {
            haptics.error()
        }
    }
    
    private func handleMagnet() {
        cancelAllModes()
        isMagnetMode = true
        haptics.lightImpact()
    }
    
    private func handleTileTap(at position: Position) {
        // Handle double tile power-up first
        if gameStore.pendingDoubleBase != nil {
            _ = gameStore.applyDouble(to: position)
            isShowingDoublePrompt = false
            return
        }
        
        // Handle hammer mode
        if isHammerMode {
            if gameStore.state.board[position] != nil {
                _ = gameStore.useHammer(at: position)
                haptics.success()
                isHammerMode = false
            } else {
                haptics.error()
            }
            return
        }
        
        // Handle swap mode
        if isSwapMode {
            if gameStore.state.board[position] != nil {
                if let first = firstSwapPosition {
                    // Second selection - perform swap if adjacent
                    if first.isAdjacent(to: position) {
                        _ = gameStore.useSwap(first, position)
                        haptics.success()
                        isSwapMode = false
                        firstSwapPosition = nil
                    } else {
                        // Not adjacent, reset selection
                        firstSwapPosition = position
                        haptics.lightImpact()
                    }
                } else {
                    // First selection
                    firstSwapPosition = position
                    haptics.lightImpact()
                }
            } else {
                haptics.error()
            }
            return
        }
        
        // Handle magnet mode
        if isMagnetMode {
            if let tile = gameStore.state.board[position] {
                let success = gameStore.useMagnet(value: tile.value, to: position)
                if success {
                    haptics.success()
                } else {
                    haptics.warning() // No matching tiles found
                }
                isMagnetMode = false
                magnetTargetValue = nil
            } else {
                haptics.error()
            }
            return
        }
    }
    
    private func cancelAllModes() {
        isHammerMode = false
        isSwapMode = false
        isMagnetMode = false
        firstSwapPosition = nil
        magnetTargetValue = nil
    }
}

// MARK: - Leaderboard Scope
public enum LeaderboardScope: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    public var id: Self { self }
}

// MARK: - Enhanced HUD Bar

struct EnhancedHUDBar: View {
    @Environment(\.gameStore) private var gameStore
    @Binding var scope: LeaderboardScope
    let rank: Int
    let milestones: [Milestone]
    let onLeaderboard: () -> Void
    let onBuy: () -> Void
    let onPause: () -> Void
    let onThemeChange: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Top row
            HStack {
                // Rank badge
                Button(action: onLeaderboard) {
                    Label("Rank: \(rank)", systemImage: "trophy.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Leaderboard Scope Picker
                Picker("Scope", selection: $scope) {
                    ForEach(LeaderboardScope.allCases) { scopeCase in
                        Text(scopeCase.rawValue).tag(scopeCase)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                
                Spacer()
                
                // Score (hero metric)
                Text(gameStore.state.score.formatted(.number.grouping(.automatic)))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    //.foregroundStyle(.white)
                
                Spacer()
                
                // Right controls
                HStack(spacing: 12) {
                    // Gems
                    HStack(spacing: 4) {
                        Image(systemName: "diamond.fill")
                            .foregroundStyle(.mint)
                        Text("\(gameStore.coins)")
                            .monospacedDigit()
                        Button(action: onBuy) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    
                    // Theme button
                    Button(action: onThemeChange) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    
                    // Pause button
                    Button(action: onPause) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Milestone progression bar
            if !milestones.isEmpty {
                HStack(spacing: 4) {
                    ForEach(milestones) { milestone in
                        MilestoneChip(milestone: milestone)
                    }
                }
                .frame(height: 24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.clear)
    }
}

// MARK: - Enhanced Power-up Dock

struct EnhancedPowerupDock: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.audio) private var audio
    @AppStorage("sfxEnabled") private var sfxEnabled: Bool = true
    let onHammer: () -> Void
    let onShuffle: () -> Void
    let onSwap: () -> Void
    let onMagnet: () -> Void
    let onUndo: () -> Void
    let onPause: () -> Void
    let onShop: () -> Void
    let onAdGift: () -> Void
    let onHome: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Single row, ordered like the reference image
            HStack(spacing: 0) {
                // Speaker toggle
                ExpandedPlainIconButton(icon: sfxEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill") {
                    sfxEnabled.toggle()
                    audio.setSfxEnabled(sfxEnabled)
                }

                // Power-ups
                ExpandedPowerUpButton(
                    icon: "hammer.fill",
                    powerUpKey: "hammer",
                    cost: GameStore.PowerUpCost.hammer,
                    isEnabled: gameStore.isPowerUpAvailable("hammer"),
                    action: onHammer
                )
                ExpandedPowerUpButton(
                    icon: "arrow.triangle.2.circlepath",
                    powerUpKey: "shuffle",
                    cost: GameStore.PowerUpCost.shuffle,
                    isEnabled: gameStore.isPowerUpAvailable("shuffle"),
                    action: onShuffle
                )
                ExpandedPowerUpButton(
                    icon: "scope",
                    powerUpKey: "swap",
                    cost: GameStore.PowerUpCost.swap,
                    isEnabled: gameStore.isPowerUpAvailable("swap"),
                    action: onSwap
                )
                ExpandedPowerUpButton(
                    icon: "magnet.fill",
                    powerUpKey: "magnet",
                    cost: 0,
                    isEnabled: true,
                    showCost: false,
                    action: onMagnet
                )

                // Free reward
                ExpandedUtilityButton(icon: "gift.fill", title: "FREE", action: onAdGift)

                // Utility
                ExpandedPlainIconButton(icon: "pause.fill", action: onPause)
                ExpandedPlainIconButton(icon: "shippingbox.fill", action: onShop)
                ExpandedPlainIconButton(icon: "house.fill", action: onHome)
            }
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
    }
}

// MARK: - Supporting Views

struct Milestone: Identifiable {
    let id = UUID()
    let value: Int
    let label: String
    let isCurrent: Bool
    let isLocked: Bool
}

struct MilestoneChip: View {
    let milestone: Milestone
    
    var body: some View {
        Text(milestone.label)
            .font(.system(size: milestone.isCurrent ? 14 : 12, weight: .bold, design: .rounded))
            .foregroundStyle(milestone.isLocked ? .gray : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(milestone.isCurrent ? Color.green : (milestone.isLocked ? Color.gray.opacity(0.3) : Color.orange))
            )
            .overlay(
                milestone.isCurrent ?
                Image(systemName: "crown.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.yellow)
                    .offset(y: -10) : nil
            )
    }
}

struct ExpandedPowerUpButton: View {
    @Environment(\.gameStore) private var gameStore
    let icon: String
    let powerUpKey: String
    let cost: Int
    let isEnabled: Bool
    var showCost: Bool = true
    let action: () -> Void
    
    var inventoryCount: Int {
        gameStore.powerUpInventory[powerUpKey, default: 0]
    }
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(isEnabled ? .white : .gray)
                
                // Show inventory count badge if > 0
                if inventoryCount > 0 {
                    Text("\(inventoryCount)")
                        .font(.system(size: 11, weight: .bold))
                        //.foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .offset(x: -8, y: 8)
                }
                
                // Show cost if no inventory
                if showCost && cost > 0 && inventoryCount == 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 8))
                        Text("\(cost)")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .foregroundStyle(isEnabled ? .white : .gray)
                    .offset(x: -8, y: 28)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

struct TopMergeTileView: View {
    let value: Int
    
    var body: some View {
        let currentLabel = CompactNumberFormatter.format(value)
        let nextVal = value > 0 && value <= (Int.max >> 1) ? value * 2 : value
        let nextLabel = CompactNumberFormatter.format(nextVal)
        
        HStack {
            Spacer()
            Text("\(currentLabel) >> \(nextLabel)")
                .font(.title3.weight(.black))
                //.foregroundStyle(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                )
                .shadow(radius: 6)
                .padding(.top, 8)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ExpandedUtilityButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            //.foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

struct ExpandedPlainIconButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                //.foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mode Overlay

struct ModeOverlay: View {
    let isHammerMode: Bool
    let isSwapMode: Bool
    let isMagnetMode: Bool
    let firstSwapPosition: Position?
    let onCancel: () -> Void
    
    var modeText: String {
        if isHammerMode { return "Tap a tile to destroy" }
        if isSwapMode { 
            if firstSwapPosition != nil {
                return "Tap an adjacent tile to swap"
            } else {
                return "Select first tile to swap"
            }
        }
        if isMagnetMode { return "Select a number to magnetize" }
        return ""
    }
    
    var modeColor: Color {
        if isHammerMode { return .red }
        if isSwapMode { return .blue }
        if isMagnetMode { return .purple }
        return .clear
    }
    
    var body: some View {
        VStack {
            // Mode banner at top
            HStack {
                Text(modeText)
                    .font(.headline)
                    //.foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(modeColor)
                    .cornerRadius(20)
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .font(.headline)
                //.foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray)
                .cornerRadius(20)
            }
            .padding()
            
            Spacer()
        }
        
        // Subtle overlay dimming
        .background(
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
        .animation(.easeInOut(duration: 0.2), value: isHammerMode || isSwapMode || isMagnetMode)
    }
}




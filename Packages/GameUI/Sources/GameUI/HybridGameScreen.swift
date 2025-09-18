import SwiftUI
import GameApp
import GameCore
import GameServices
#if os(macOS)
import AppKit
#endif

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

/// Hybrid screen combining original GameScreen mechanics with modern styling
public struct HybridGameScreen: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.adService) private var adService
    @Environment(\.hapticsService) private var haptics
    @Environment(\.gameCenter) private var gameCenter
    @Environment(\.backgroundThemeRegistry) private var backgroundThemeRegistry
    
    @State private var isShowingTopMergeTile: Bool = false
    @State private var topMergeTileValue: Int? = nil
    @State private var isShowingDoublePrompt: Bool = false
    @State private var isShowingPause = false
    @State private var isShowingStore = false
    @State private var isShowingLeaderboard = false
    
    // Temporary HomeState for HUDTopBar (initialized with game values)
    @State private var tempHomeState = HomeState()
    
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
        let topHUD = HUDTopBar(score: gameStore.state.score)
            .environment(tempHomeState)
            .environment(\.homeActions, makeGameActions())

        let bottomDock = SimplePowerupDock(
            onHammer: handleHammer,
            onSwap: handleSwap,
            onMagnet: handleMagnet,
            onUndo: handleUndo,
            onHome: { isPlayingDismiss?() }
        )

        let giftRewardBinding = Binding(
            get: { gameStore.pendingGiftReward != nil },
            set: { newValue in if !newValue { gameStore.dismissGiftReward() } }
        )

        let unlockRewardBinding = Binding(
            get: { gameStore.pendingUnlockRewardBase != nil },
            set: { newValue in if !newValue { gameStore.clearPendingUnlockReward() } }
        )

        let mergeInfoBinding = Binding(
            get: { gameStore.lastMergeInfo != nil },
            set: { newValue in if !newValue { gameStore.clearLastMergeInfo() } }
        )

        return mainGameView
            .safeAreaInset(edge: .top) { topHUD }
            .safeAreaInset(edge: .bottom) { bottomDock }
            .overlay(alignment: .top) {
                if isShowingTopMergeTile, let v = topMergeTileValue {
                    TopMergeTileView(value: v)
                }
            }
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
            .sheet(isPresented: giftRewardBinding) {
                if let giftReward = gameStore.pendingGiftReward {
                    GiftRewardView(giftReward: giftReward) {
                        gameStore.claimGiftReward()
                    }
                }
            }
            .sheet(isPresented: unlockRewardBinding) {
                RewardSpinnerView(
                    baseAmount: gameStore.pendingUnlockRewardBase ?? 0,
                    tileValue: gameStore.pendingUnlockTile ?? 0,
                    onClose: { gameStore.clearPendingUnlockReward() }
                )
            }
            .sheet(isPresented: mergeInfoBinding) {
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
                handleLastAddedTileChange(newValue)
            }
            .onChange(of: gameStore.pendingDoubleBase) { _, newValue in
                isShowingDoublePrompt = (newValue != nil)
            }
            .onChange(of: gameStore.coins) { _, newValue in
                tempHomeState.gems = newValue
            }
            .onChange(of: gameStore.state.score) { _, newValue in
                tempHomeState.rank = max(1, 100000 - newValue)
            }
            .onAppear {
                // Initialize tempHomeState with current values
                tempHomeState.gems = gameStore.coins
                tempHomeState.rank = max(1, 100000 - gameStore.state.score)
            }
    }
    
    private func makeGameActions() -> HomeActions {
        HomeActions(
            play: { },
            openShop: { isShowingStore = true },
            buyGems: { },
            watchAd: { 50 },
            openDaily: { },
            openFreeSpin: { },
            openMusic: { },
            openChallenge: { },
            openCreate: { },
            openProfile: { },
            openAchievements: { },
            openLeaderboard: { isShowingLeaderboard = true },
            openSettings: { },
            openThemeLeft: { },
            openThemeRight: { },
            openSaleOffer: { }
        )
    }
    
    @ViewBuilder
    private var mainGameView: some View {
        ZStack {
            // Theme background using new BackgroundTheme system
//            ThemedBackground(theme: currentBackgroundTheme)

            GeometryReader { geo in

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    
                    // Board container with glass preview (clear background)
                    ZStack {
                        // CRITICAL: Use SimplifiedGlassBoardView for merge logic and glass preview
                        SimplifiedGlassBoardView(onTileTap: { position in
                            handleTileTap(at: position)
                        })
                        .padding()
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, ModernTheme.gutter)
            }
        }
    }
    
    private func handleLastAddedTileChange(_ newValue: Int?) {
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


// MARK: - Simple Power-up Dock

struct SimplePowerupDock: View {
    @Environment(\.gameStore) private var gameStore
    let onHammer: () -> Void
    let onSwap: () -> Void
    let onMagnet: () -> Void
    let onUndo: () -> Void
    let onHome: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            // Home button
            powerupDockItem(
                icon: "house.fill",
                action: onHome
            )
            
            // Break Any Tile On The Board (Hammer)
            powerupDockItem(
                assetName: "hammer",
                badge: gameStore.powerUpInventory["hammer", default: 0],
                isEnabled: gameStore.isPowerUpAvailable("hammer"),
                action: onHammer
            )
            
            // Swap Any 2 Tiles With Each Other (Restart/Swap)
            powerupDockItem(
                assetName: "restart",
                badge: gameStore.powerUpInventory["swap", default: 0],
                isEnabled: gameStore.isPowerUpAvailable("swap"),
                action: onSwap
            )
            
            // Merge Same Tiles On The Board (Magnet)
            powerupDockItem(
                assetName: "magnet",
                badge: gameStore.powerUpInventory["magnet", default: 0],
                isEnabled: gameStore.isPowerUpAvailable("magnet"),
                action: onMagnet
            )
            
            // Undo button
            powerupDockItem(
                icon: "arrow.uturn.backward",
                isEnabled: gameStore.state.undoAvailable,
                action: onUndo
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func powerupDockItem(
        icon: String,
        badge: Int = 0,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .frame(width: 48, height: 48)
                    .foregroundStyle(isEnabled ? .primary : .tertiary)
                
                // Badge for inventory count
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .offset(x: 6, y: -6)
                }
            }
            .padding(4)
        }
        .buttonStyle(.plain)
        .glassEffectCompat(cornerRadius: 12)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
    
    private func powerupDockItem(
        assetName: String,
        badge: Int = 0,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .frame(width: 48, height: 48)
                    .opacity(isEnabled ? 1.0 : 0.4)
                
                // Badge for inventory count
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .offset(x: 6, y: -6)
                }
            }
            .padding(4)
        }
        .buttonStyle(.plain)
        .glassEffectCompat(cornerRadius: 12)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Supporting Views

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




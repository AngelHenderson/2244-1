import SwiftUI
import GameApp
import GameServices

public struct HomeView: View {
    private let managesBackground: Bool
    @Environment(HomeState.self) private var state
    @Environment(\.homeActions) private var actions
    @Environment(\.tileJourney) private var journey
    @Environment(\.toastManager) private var toastManager
    @State private var isShowingJourney: Bool = false
    @State private var isShowingLeaderboard: Bool = false
    @State private var isShowingAchievements: Bool = false
    @State private var isShowingMusic: Bool = false
    @State private var isShowingShop: Bool = false
    @State private var isShowingProfile: Bool = false
    @State private var isShowingSettings: Bool = false
    @State private var isShowingThemePicker: Bool = false
    @State private var centeredMilestone: Int? = nil
    // Measured overlay heights for proper centering of the journey scroller
    @State private var headerHeight: CGFloat = 0
    @State private var playButtonHeight: CGFloat = 0
    @State private var bottomDockHeight: CGFloat = 0
    
    // Background theme selection stored in AppStorage  
    @AppStorage("selectedBackgroundId") private var selectedBackgroundId: String = "city_1"
    @Environment(\.backgroundThemeRegistry) private var backgroundThemeRegistry
    
    private var currentBackgroundTheme: BackgroundTheme {
        backgroundThemeRegistry.theme(for: selectedBackgroundId)
    }
    
    private var bottomOverlayHeight: CGFloat { playButtonHeight + bottomDockHeight + 8 }

    public init(managesBackground: Bool = true) {
        self.managesBackground = managesBackground
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            if managesBackground {
                HomeBackgroundLayer(theme: currentBackgroundTheme)
                    .ignoresSafeArea()
                    .zIndex(0)
            }

            
            // Background layer: Tile scroller. We pass measured header/footer insets so
            // the current tile appears visually centered upon first appear.
            TileScrollerView(topInset: headerHeight + 8, bottomInset: bottomOverlayHeight)
            
            // Foreground layer: Main UI
            VStack(spacing: 0) {
                // Top HUD
                HUDTopBar()
                    .padding(.top, 8)
                    // Add background material to prevent scrolling content overlap visibility
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .top)
                    .overlay(alignment: .top) {
                        // Measure header height so scroller can center correctly
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { headerHeight = geo.size.height }
                                .onChange(of: geo.size.height) { _, new in headerHeight = new }
                        }
                    }

                // Main content with side rails and center progression
                GeometryReader { geo in
                    HStack(alignment: .center, spacing: 16) {
                        // Left rail
                        VStack(spacing: 20) {
                            SideRailButton(
                                systemImage: nil,
                                customImage: "dailypic",
                                title: "DAILY",
                                badge: state.hasDailyBadge,
                                action: { actions.openDaily() }
                            )

                            SideRailButton(
                                systemImage: nil,
                                customImage: "spinthewheel",
                                title: "FREE SPIN",
                                badge: state.hasFreeSpinBadge,
                                action: { actions.openFreeSpin() }
                            )

                            SideRailButton(
                                systemImage: nil,
                                customImage: "mysterybox",
                                title: "SHOP",
                                badge: state.hasShopBadge,
                                action: { isShowingShop = true }
                            )

                            SideRailButton(
                                systemImage: nil,
                                customImage: "soundeffect",
                                title: "MUSIC",
                                action: { isShowingMusic = true }
                            )

                            SideRailButton(
                                systemImage: nil,
                                customImage: "salesoffer",
                                title: "SALE OFFER",
                                badge: true,
                                action: { actions.openSaleOffer() }
                            )
                            
                            Spacer(minLength: 0)
                        }
                        .frame(width: 80)
                        .padding(.top, 20)

                        // Center column: Spacer for tile visibility
                        Spacer()
                            .frame(maxWidth: .infinity)

                        // Right rail
                        VStack(spacing: 20) {
                            SideRailButton(
                                systemImage: nil,
                                customImage: "createagame",
                                title: "CREATE",
                                locked: false,
                                action: { actions.openCreate() }
                            )
                            
                            SideRailButton(
                                systemImage: nil,
                                customImage: "ads",
                                title: "",
                                badge: true,
                                specialLabel: "+\(state.adReward)",
                                action: {
                                    Task {
                                        let reward = await actions.watchAd()
                                        await MainActor.run { state.addGems(reward) }
                                    }
                                }
                            )
                            
                            SideRailButton(
                                systemImage: nil,
                                customImage: "challenge",
                                title: "CHALLENGE",
                                locked: false,
                                action: { actions.openChallenge() }
                            )

                            // Best Offer with countdown
                            if let deadline = state.bestOfferDeadline {
                                VStack(spacing: 6) {
                                    SideRailButton(
                                        systemImage: nil,
                                        customImage: "gift",
                                        title: "BEST OFFER",
                                        action: { actions.openShop() }
                                    )
                                    CountdownView(deadline: deadline)
                                }
                            } else {
                                SideRailButton(
                                    systemImage: nil,
                                    customImage: "gift",
                                    title: "BEST OFFER",
                                    action: { actions.openShop() }
                                )
                            }

                            SideRailButton(
                                systemImage: nil,
                                customImage: "themedefault",
                                title: "THEME",
                                action: { isShowingThemePicker = true }
                            )

                            Spacer(minLength: 0)
                        }
                        .frame(width: 80)
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 12)
                }

                // Play button
                PillButton(title: "Play", icon: "play.fill") { 
                    actions.play() 
                }
                .padding(.horizontal)
                .padding(.vertical)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { playButtonHeight = geo.size.height }
                            .onChange(of: geo.size.height) { _, new in playButtonHeight = new }
                    }
                )

                // Bottom dock
                HStack(spacing: 22) {
                    dockItem(
                        system: "person.circle.fill",
                        title: "Profile",
                        badge: state.hasProfileBadge,
                        action: { isShowingProfile = true }
                    )
                    dockItem(
                        system: "star.circle.fill",
                        title: "Achievements",
                        badge: state.hasAchievementsBadge,
                        action: { isShowingAchievements = true }
                    )
                    dockItem(
                        system: "trophy.circle.fill",
                        title: "Leaderboard",
                        action: { isShowingLeaderboard = true }
                    )
                    dockItem(
                        system: "gearshape.fill",
                        title: "Settings",
                        action: { isShowingSettings = true }
                    )
                }
                .padding(.bottom, 16)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { bottomDockHeight = geo.size.height }
                            .onChange(of: geo.size.height) { _, new in bottomDockHeight = new }
                    }
                )
            }
            .zIndex(1)
            .zIndex(2)
        }
        // Leaderboard (full screen on iPad)
        .adaptiveSheet(isPresented: $isShowingLeaderboard) {
            LeaderboardView()
        }
        // Achievements (full screen on iPad)
        .adaptiveSheet(isPresented: $isShowingAchievements) {
            AchievementsView()
        }
        // Music Themes (full screen on iPad)
        .adaptiveSheet(isPresented: $isShowingMusic) {
            MusicThemesView(
                onTry: { instrument in
                    // Placeholder: ad presentation to be implemented by host later
                    print("Try instrument: \(instrument.id)")
                },
                onPurchase: { instrument in
                    print("Purchase tapped for: \(instrument.id)")
                }
            )
        }
        // Shop (full screen on iPad)
        .adaptiveSheet(isPresented: $isShowingShop) {
            ShopView()
        }
        // Profile (full screen on iPad)
        .adaptiveSheet(isPresented: $isShowingProfile) {
            PlayerProfileView()
        }
        // Settings (full screen on iPad)
        .adaptiveSheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        // Theme Picker (full screen on iPad)
        .adaptiveSheet(isPresented: $isShowingThemePicker) {
            ThemePickerView()
        }
        // Floating toast notification overlay
        .toastOverlay(manager: toastManager)
    }

    private func dockItem(system: String, title: String, badge: Bool = false, action: @escaping () -> Void) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            return AnyView(
                Button(action: action) {
                    VStack(spacing: 4) {
                        // Prefer asset with same semantic name if available
                        let asset = assetName(for: title)
                        if !asset.isEmpty {
                            Image(asset)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                        } else {
                            Image(systemName: system)
                                .font(.system(size: 24))
                        }
                    }
                    .padding(4)
                }
                .buttonStyle(.glass)
            )
        } else {
            return AnyView(
                Button(action: action) {
                    VStack(spacing: 4) {
                        let asset = assetName(for: title)
                        if !asset.isEmpty {
                            Image(asset)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                        } else {
                            Image(systemName: system)
                                .font(.system(size: 24))
                        }
                    }
                    .padding(4)
                }
            )
        }
    }


    private func assetName(for title: String) -> String {
        switch title.lowercased() {
        case "profile": return "profile"
        case "achievements": return "achievement"
        case "leaderboard": return "leaderboard"
        case "settings": return "settings"
        case "theme": return "themedefault"
        default: return ""
        }
    }
}

// (Removed inline daily rewards card; daily rewards are accessed via the Daily button.)

private struct ThemeButton: View {
    let name: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(themeGradient)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: themeIcon)
                            .font(.title2)
                    }
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
    
    private var themeGradient: LinearGradient {
        switch name.lowercased() {
        case "beach":
            return LinearGradient(
                colors: [Color.orange, Color.yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "aqua":
            return LinearGradient(
                colors: [Color.init(hex: "EBEBEB")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color.purple, Color.pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var themeIcon: String {
        switch name.lowercased() {
        case "beach": return "sun.max.fill"
        case "aqua": return "drop.fill"
        default: return "sparkle"
        }
    }
}

// MARK: - Compatibility glass effect
public extension View {
    @ViewBuilder
    func glassEffectCompat(cornerRadius: CGFloat = 8) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

#Preview("Home - Default") {
    // Local services and state for preview
    let gameStore = GameStore()
    let homeState = HomeState()
    let purchaseService = PurchaseService()
    let adService = DummyAdService()
    let haptics = HapticsService()
    let gameCenter = DefaultGameCenterService()
    let storage = UserDefaultsStorageService()
    let themeRegistry = ThemeRegistry.Default
    let toastManager = ToastManager()

    // Seed some demo state for a nicer preview
    homeState.gems = 305
    homeState.highestTile = 1024
    homeState.milestoneBelow = 512
    homeState.lockedMilestones = [2048, 4096]
    // Sync journey to highest tile
    gameStore.journey.didReach(tile: homeState.highestTile)

    // Minimal actions for preview
    let actions = HomeActions(
        play: {},
        openShop: {},
        buyGems: {},
        watchAd: { 50 },
        openDaily: {},
        openFreeSpin: {},
        openMusic: {},
        openChallenge: {},
        openCreate: {},
        openProfile: {},
        openAchievements: {},
        openLeaderboard: {},
        openSettings: {},
        openThemeLeft: {},
        openThemeRight: {},
        openSaleOffer: {}
    )

    return HomeView()
        .environment(homeState)
        .environment(\.homeActions, actions)
        .environment(\.gameStore, gameStore)
        .environment(\.purchaseService, purchaseService)
        .environment(\.adService, adService)
        .environment(\.hapticsService, haptics)
        .environment(\.gameCenter, gameCenter)
        .environment(\.storage, storage)
        .environment(\.currentTheme, themeRegistry.descriptor(for: "raised-3d-square"))
        .environment(\.tileJourney, gameStore.journey)
        .environment(\.leaderboardClient, .noop)
        .environment(\.toastManager, toastManager)
}

#Preview("Home - Best Offer") {
    // Local services and state for preview
    let gameStore = GameStore()
    let homeState = HomeState()
    let purchaseService = PurchaseService()
    let adService = DummyAdService()
    let haptics = HapticsService()
    let gameCenter = DefaultGameCenterService()
    let storage = UserDefaultsStorageService()
    let themeRegistry = ThemeRegistry.Default
    let toastManager = ToastManager()

    // Seed demo state with an active best offer
    homeState.gems = 520
    homeState.highestTile = 2048
    homeState.milestoneBelow = 1024
    homeState.lockedMilestones = [4096, 8192]
    homeState.bestOfferDeadline = Date().addingTimeInterval(60 * 30) // 30 minutes remaining
    gameStore.journey.didReach(tile: homeState.highestTile)

    let actions = HomeActions(
        play: {},
        openShop: {},
        buyGems: {},
        watchAd: { 50 },
        openDaily: {},
        openFreeSpin: {},
        openMusic: {},
        openChallenge: {},
        openCreate: {},
        openProfile: {},
        openAchievements: {},
        openLeaderboard: {},
        openSettings: {},
        openThemeLeft: {},
        openThemeRight: {},
        openSaleOffer: {}
    )

    return HomeView()
        .environment(homeState)
        .environment(\.homeActions, actions)
        .environment(\.gameStore, gameStore)
        .environment(\.purchaseService, purchaseService)
        .environment(\.adService, adService)
        .environment(\.hapticsService, haptics)
        .environment(\.gameCenter, gameCenter)
        .environment(\.storage, storage)
        .environment(\.currentTheme, themeRegistry.descriptor(for: "raised-3d-square"))
        .environment(\.tileJourney, gameStore.journey)
        .environment(\.leaderboardClient, .noop)
        .environment(\.toastManager, toastManager)
}

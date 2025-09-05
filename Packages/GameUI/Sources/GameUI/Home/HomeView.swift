import SwiftUI
import GameApp
import GameServices

public struct HomeView: View {
    @Environment(HomeState.self) private var state
    @Environment(\.homeActions) private var actions
    @Environment(\.tileJourney) private var journey
    @State private var isShowingJourney: Bool = false
    @State private var isShowingLeaderboard: Bool = false
    @State private var isShowingAchievements: Bool = false
    @State private var isShowingMusic: Bool = false
    @State private var isShowingShop: Bool = false
    @State private var centeredMilestone: Int? = nil

    public init() {}
    
    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top HUD
                HUDTopBar()
                    .padding(.top, 8)

                // Main content with side rails and center progression
                GeometryReader { geo in
                    HStack(alignment: .center, spacing: 16) {
                        // Left rail
                        VStack(spacing: 20) {
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
                            
                            // Daily below Sale Offer
                            SideRailButton(
                                systemImage: nil,
                                customImage: "dailypic",
                                title: "DAILY",
                                badge: state.hasDailyBadge,
                                action: { actions.openDaily() }
                            )
                            
                            Spacer(minLength: 0)
                        }
                        .frame(width: 80)
                        .padding(.top, 20)

                        // Center column: Inline Journey view (header + full scroll)
                        VStack(spacing: 16) {
                            JourneyPanel(showAll: true)
                                .padding(.horizontal)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)

                        // Right rail
                        VStack(spacing: 20) {
                            SideRailButton(
                                systemImage: nil,
                                customImage: "createagame",
                                title: "CREATE",
                                locked: state.isCreateLocked,
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
                                locked: state.isChallengeLocked,
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
                                action: { actions.openShop() }
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

                // Bottom dock
                HStack(spacing: 22) {
                    dockItem(
                        system: "person.circle.fill",
                        title: "Profile",
                        badge: state.hasProfileBadge,
                        action: { actions.openProfile() }
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
                        action: { actions.openSettings() }
                    )
                }
                .padding(.bottom, 16)
            }

        }
        // Leaderboard sheet
        .sheet(isPresented: $isShowingLeaderboard) {
            LeaderboardView()
        }
        // Achievements sheet
        .sheet(isPresented: $isShowingAchievements) {
            AchievementsView()
        }
        // Music Themes sheet
        .sheet(isPresented: $isShowingMusic) {
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
        // Shop sheet
        .sheet(isPresented: $isShowingShop) {
            ShopView()
        }
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
}

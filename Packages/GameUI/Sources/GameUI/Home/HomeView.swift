import SwiftUI
import GameApp
import GameCore
import GameServices

public struct HomeView: View {
    private let managesBackground: Bool
    @Environment(HomeState.self) private var state
    @Environment(DailyClaimsStore.self) private var dailyClaimsStore
    @Environment(AchievementStore.self) private var achievementStore
    @Environment(\.homeActions) private var actions
    @Environment(\.tileJourney) private var journey
    @Environment(\.toastManager) private var toastManager
    @Environment(\.spinWheelState) private var spinState
    @Environment(\.leaderboardClient) private var leaderboardClient
    @State private var isShowingJourney: Bool = false
    @State private var isShowingLeaderboard: Bool = false
    @State private var isShowingAchievements: Bool = false
    @State private var isShowingMusic: Bool = false
    @State private var isShowingShop: Bool = false
    @State private var isShowingProfile: Bool = false
    @State private var isShowingSettings: Bool = false
    @State private var isShowingThemePicker: Bool = false
    @State private var isShowingBoosts: Bool = false
    @State private var isShowingWeeklyOffer: Bool = false
    @State private var showLockedChallengeAlert: Bool = false
    @State private var centeredMilestone: Int? = nil
    // Measured overlay heights for proper centering of the journey scroller
    @State private var headerHeight: CGFloat = 0
    @State private var playButtonHeight: CGFloat = 0
    @State private var bottomDockHeight: CGFloat = 0
    
    // Background theme selection stored in AppStorage  
    @AppStorage("selectedBackgroundThemeId") private var selectedBackgroundId: String = "city_1"
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
            JourneyPanel(topInset: headerHeight + 8, bottomInset: bottomOverlayHeight)

            // Foreground layer: Main UI
            VStack(spacing: 0) {
                // Top HUD
                HUDTopBar(onLeaderboardTap: { isShowingLeaderboard = true })

                // Main content with side rails and center progression
                GeometryReader { geo in
                    HStack(alignment: .center, spacing: 16) {
                        // Left rail
                        VStack(spacing: 20) {
                            SideRailButton(
                                systemImage: nil,
                                customImage: "dailypic",
                                title: "DAILY",
                                badge: dailyClaimsStore.canClaimToday,
                                banned: state.isBanned,
                                onBannedTap: { state.showBanAlert = true },
                                action: { actions.openDaily() }
                            )

                            SideRailButton(
                                systemImage: nil,
                                customImage: "spinthewheel",
                                title: "FREE SPIN",
                                badgeCount: spinState.bonusSpins,
                                banned: state.isBanned,
                                onBannedTap: { state.showBanAlert = true },
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
                                // Until a dedicated sale-offer flow exists (Batch C), reuse the
                                // weekly offer sheet rather than dead-ending the tap.
                                action: { isShowingWeeklyOffer = true }
                            )

                            SideRailButton(
                                systemImage: "bolt.fill",
                                customImage: nil,
                                title: "BOOSTS",
                                banned: state.isBanned,
                                onBannedTap: { state.showBanAlert = true },
                                action: { isShowingBoosts = true }
                            )

                            Spacer(minLength: 0)
                        }
                        .frame(width: 80)
                        .padding(.top, 20)

                        // Center column: empty space, touches pass through to JourneyPanel
                        Spacer()
                            .frame(maxWidth: .infinity)

                        // Right rail
                        VStack(spacing: 20) {
                            SideRailButton(
                                systemImage: nil,
                                customImage: "createagame",
                                title: "CREATE",
                                locked: state.isCreateLocked,
                                banned: state.isBanned,
                                onBannedTap: { state.showBanAlert = true },
                                action: { actions.openCreate() }
                            )
                            
                            SideRailButton(
                                systemImage: nil,
                                customImage: "ads",
                                title: "",
                                badge: true,
                                banned: state.isBanned,
                                specialLabel: "+\(state.adReward)",
                                specialLabelInside: true,
                                onBannedTap: { state.showBanAlert = true },
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
                                banned: state.isBanned,
                                onLockedTap: {
                                    showLockedChallengeAlert = true
                                },
                                onBannedTap: { state.showBanAlert = true },
                                action: { actions.openChallenge() }
                            )

                            // Best Offer with countdown
                            if let deadline = state.bestOfferDeadline {
                                VStack(spacing: 6) {
                                    SideRailButton(
                                        systemImage: nil,
                                        customImage: "gift",
                                        title: "BEST OFFER",
                                        action: { isShowingWeeklyOffer = true }
                                    )
                                    CountdownView(deadline: deadline)
                                }
                            } else {
                                SideRailButton(
                                    systemImage: nil,
                                    customImage: "gift",
                                    title: "BEST OFFER",
                                    action: { isShowingWeeklyOffer = true }
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
                    if state.isBanned {
                        state.showBanAlert = true
                    } else {
                        actions.play()
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if state.isBanned {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(red: 0.85, green: 0.15, blue: 0.15))
                            .offset(x: -8, y: -4)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical)

                // Bottom dock
                HStack(spacing: 22) {
                    dockItem(
                        system: "person.circle.fill",
                        title: "Profile",
                        badge: state.hasProfileBadge,
                        action: {
                            isShowingProfile = true
                        }
                    )
                    dockItem(
                        system: "star.circle.fill",
                        title: "Achievements",
                        badgeCount: state.achievementsBadgeCount,
                        banned: state.isBanned,
                        action: {
                            if state.isBanned { state.showBanAlert = true }
                            else { isShowingAchievements = true }
                        }
                    )
                    dockItem(
                        system: "trophy.circle.fill",
                        title: "Leaderboard",
                        action: {
                            isShowingLeaderboard = true
                        }
                    )
                    dockItem(
                        system: "gearshape.fill",
                        title: "Settings",
                        action: {
                            isShowingSettings = true
                        }
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
        }
        // Leaderboard (full screen on iPad)
        .adaptiveSheet(isPresented: $isShowingLeaderboard) {
            LeaderboardView(client: leaderboardClient)
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
                .environment(state)
        }
        // Theme Picker (full screen on iPad)
        .adaptiveSheet(isPresented: $isShowingThemePicker) {
            ThemePickerView()
        }
        // Boosts Sheet
        .sheet(isPresented: $isShowingBoosts) {
            BoostsSheet()
        }
        // Weekly Offer Sheet
        .sheet(isPresented: $isShowingWeeklyOffer) {
            WeeklyOfferSheet()
        }
        // Floating toast notification overlay
        .toastOverlay(manager: toastManager)
        // Update achievements badge count
        .onAppear {
            state.achievementsBadgeCount = achievementStore.claimableCount
        }
        .onChange(of: achievementStore.claimableCount) { _, newCount in
            state.achievementsBadgeCount = newCount
        }
        .alert("Tile Too Low", isPresented: $showLockedChallengeAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Sorry! You do not have a high enough tile to unlock this. You need a 1B tile.")
        }
        .alert("You Are Still Banned!", isPresented: Bindable(state).showBanAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You are still banned. Your ban is over in \(state.banTimeRemainingText ?? "never (permanent)").")
        }
        .alert("\(state.warningsRemaining) Chances Left!", isPresented: Bindable(state).showWarningAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You have \(state.warningsRemaining) chances left! After that, you are banned!")
        }
        .alert(state.evaluationTitle, isPresented: Bindable(state).showEvaluationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(state.evaluationMessage)
        }
    }

    private func dockItem(system: String, title: String, badge: Bool = false, badgeCount: Int = 0, banned: Bool = false, action: @escaping () -> Void) -> some View {
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
                    .frame(width: 56, height: 56)
                    .padding(4)
                    .overlay(alignment: .topTrailing) {
                        if banned {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(red: 0.85, green: 0.15, blue: 0.15))
                                .offset(x: 6, y: -4)
                        } else if badgeCount > 0 {
                            Text("\(badgeCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                                .offset(x: 6, y: -4)
                        }
                    }
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
                    .frame(width: 56, height: 56)
                    .padding(4)
                    .overlay(alignment: .topTrailing) {
                        if banned {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(red: 0.85, green: 0.15, blue: 0.15))
                                .offset(x: 6, y: -4)
                        } else if badgeCount > 0 {
                            Text("\(badgeCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                                .offset(x: 6, y: -4)
                        }
                    }
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
    let _ = (homeState.gems = 305)
    let _ = (homeState.highestTile = 1024)
    let _ = (homeState.milestoneBelow = 512)
    let _ = (homeState.lockedMilestones = [2048, 4096])
    // Sync journey to highest tile
    let _ = gameStore.journey.didReach(tile: homeState.highestTile)

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

    HomeView()
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
        .environment(\.leaderboardClient, .mock)
        .environment(\.toastManager, toastManager)
        .environment(DailyQuestStore())
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
    let _ = (homeState.gems = 520)
    let _ = (homeState.highestTile = 2048)
    let _ = (homeState.milestoneBelow = 1024)
    let _ = (homeState.lockedMilestones = [4096, 8192])
    // bestOfferDeadline is now auto-calculated from WeeklyOfferManager
    let _ = gameStore.journey.didReach(tile: homeState.highestTile)

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

    HomeView()
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
        .environment(\.leaderboardClient, .mock)
        .environment(\.toastManager, toastManager)
        .environment(DailyQuestStore())
}

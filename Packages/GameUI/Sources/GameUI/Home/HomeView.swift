import SwiftUI
import GameApp
import GameCore
import GameServices

public struct HomeView: View {
    private let managesBackground: Bool
    @Environment(HomeState.self) private var state
    @Environment(DailyClaimsStore.self) private var dailyClaimsStore
    @Environment(AchievementStore.self) private var achievementStore
    @Environment(PlayerReadinessStore.self) private var playerReadiness
    @Environment(\.homeActions) private var actions
    @Environment(\.tileJourney) private var journey
    @Environment(\.toastManager) private var toastManager
    @Environment(\.spinWheelState) private var spinState
    @Environment(\.leaderboardClient) private var leaderboardClient
    @Environment(\.purchaseService) private var purchaseService
    @Environment(\.gameStore) private var gameStore
    @Environment(\.adService) private var adService
    @Environment(\.deepLinkRouter) private var deepLinkRouter
    @State private var presentedSheet: HomeSheetDestination?
    @State private var isShowingBoosts: Bool = false
    @State private var isShowingWeeklyOffer: Bool = false
    @State private var isShowingAdBonusIntro: Bool = false
    @State private var showLockedChallengeAlert: Bool = false
    @State private var centeredMilestone: Int? = nil
    @State private var isPrivacyOptionsRequired: Bool = false
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
                HUDTopBar(onLeaderboardTap: { presentedSheet = .leaderboard })

                // Single contextual recommendation
                if let action = currentRecommendation {
                    NextBestActionCard(action: action) {
                        applyRecommendation(action)
                    } onDismiss: {
                        playerReadiness.dismissRecommendation(action)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Main content with side rails and center progression
                GeometryReader { geo in
                    HStack(alignment: .center, spacing: 16) {
                        // Left rail (Daily / Free Spin / Shop / Music / Boosts)
                        VStack(spacing: 20) {
                            if playerReadiness.isVisible(.daily) {
                                SideRailButton(
                                    systemImage: nil,
                                    customImage: "dailypic",
                                    title: "DAILY",
                                    badge: dailyClaimsStore.canClaimToday,
                                    banned: state.isBanned,
                                    onBannedTap: { state.showBanAlert = true },
                                    action: { actions.openDaily() }
                                )
                            }

                            if playerReadiness.isVisible(.freeSpin) {
                                SideRailButton(
                                    systemImage: nil,
                                    customImage: "spinthewheel",
                                    title: "FREE SPIN",
                                    badgeCount: spinState.bonusSpins,
                                    banned: state.isBanned,
                                    onBannedTap: { state.showBanAlert = true },
                                    action: { actions.openFreeSpin() }
                                )
                            }

                            if playerReadiness.isVisible(.shop) {
                                SideRailButton(
                                    systemImage: nil,
                                    customImage: "mysterybox",
                                    title: "SHOP",
                                    badge: state.hasShopBadge,
                                    action: { presentedSheet = .shop }
                                )
                            }

                            if playerReadiness.isVisible(.music) {
                                SideRailButton(
                                    systemImage: nil,
                                    customImage: "soundeffect",
                                    title: "MUSIC",
                                    action: { presentedSheet = .music }
                                )
                            }

                            if playerReadiness.isVisible(.boosts) {
                                SideRailButton(
                                    systemImage: "bolt.fill",
                                    customImage: nil,
                                    title: "BOOSTS",
                                    banned: state.isBanned,
                                    onBannedTap: { state.showBanAlert = true },
                                    action: { isShowingBoosts = true }
                                )
                            }

                            if playerReadiness.isVisible(.practice) {
                                SideRailButton(
                                    systemImage: "target",
                                    customImage: nil,
                                    title: "PRACTICE",
                                    action: { presentedSheet = .practice }
                                )
                            }

                            Spacer(minLength: 0)
                        }
                        .frame(width: 80)
                        .padding(.top, 20)

                        // Center column: empty space, touches pass through to JourneyPanel
                        Spacer()
                            .frame(maxWidth: .infinity)

                        // Right rail (Create / Bonus Ad / Challenge / Best Offer / Theme)
                        VStack(spacing: 20) {
                            if playerReadiness.isVisible(.create) || isCreateNearUnlock {
                                SideRailButton(
                                    systemImage: nil,
                                    customImage: "createagame",
                                    title: "CREATE",
                                    locked: state.isCreateLocked,
                                    banned: state.isBanned,
                                    onLockedTap: { /* surfaced via NextBestAction */ },
                                    onBannedTap: { state.showBanAlert = true },
                                    action: { actions.openCreate() }
                                )
                            }

                            if !purchaseService.isAdFreePurchased && playerReadiness.isVisible(.adBonus) {
                                SideRailButton(
                                    systemImage: nil,
                                    customImage: "ads",
                                    title: "BONUS",
                                    badge: true,
                                    banned: state.isBanned,
                                    specialLabel: "+\(state.adReward)",
                                    specialLabelInside: true,
                                    onBannedTap: { state.showBanAlert = true },
                                    action: {
                                        isShowingAdBonusIntro = true
                                    }
                                )
                            }

                            if playerReadiness.isVisible(.challenge) || isChallengeNearUnlock {
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
                            }

                            if playerReadiness.isVisible(.bestOffer) {
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
                            }

                            if playerReadiness.isVisible(.theme) {
                                SideRailButton(
                                    systemImage: nil,
                                    customImage: "themedefault",
                                    title: "THEME",
                                    action: { presentedSheet = .themePicker }
                                )
                            }

                            if playerReadiness.isVisible(.modes) {
                                SideRailButton(
                                    systemImage: "square.grid.2x2.fill",
                                    customImage: nil,
                                    title: "MODES",
                                    action: { presentedSheet = .modes }
                                )
                            }

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
                    if playerReadiness.isVisible(.profile) {
                        dockItem(
                            system: "person.circle.fill",
                            title: "Profile",
                            badge: state.hasProfileBadge,
                            action: {
                                presentedSheet = .profile
                            }
                        )
                    }
                    if playerReadiness.isVisible(.achievements) {
                        dockItem(
                            system: "star.circle.fill",
                            title: "Achievements",
                            badgeCount: state.achievementsBadgeCount,
                            banned: state.isBanned,
                            action: {
                                if state.isBanned { state.showBanAlert = true }
                                else { presentedSheet = .achievements }
                            }
                        )
                    }
                    if playerReadiness.isVisible(.leaderboard) {
                        dockItem(
                            system: "trophy.circle.fill",
                            title: "Leaderboard",
                            action: {
                                presentedSheet = .leaderboard
                            }
                        )
                    }
                    if playerReadiness.isVisible(.feed) {
                        dockItem(
                            system: "bubble.left.and.bubble.right.fill",
                            title: "Feed",
                            action: {
                                presentedSheet = .feed
                            }
                        )
                    }
                    if playerReadiness.isVisible(.friends) {
                        dockItem(
                            system: "person.2.circle.fill",
                            title: "Friends",
                            action: {
                                presentedSheet = .friends
                            }
                        )
                    }
                    dockItem(
                        system: "gearshape.fill",
                        title: "Settings",
                        action: {
                            presentedSheet = .settings
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
        // Unified destination sheet (full screen on iPad)
        .adaptiveSheet(item: $presentedSheet) { destination in
            switch destination {
            case .leaderboard:
                LeaderboardView(client: leaderboardClient)
            case .achievements:
                AchievementsView()
            case .music:
                MusicThemesView(
                    onTry: { instrument in
                        print("Try instrument: \(instrument.id)")
                    },
                    onPurchase: { instrument in
                        print("Purchase tapped for: \(instrument.id)")
                    }
                )
            case .shop:
                ShopView()
            case .profile:
                PlayerProfileView()
            case .settings:
                SettingsView()
                    .environment(state)
            case .themePicker:
                ThemePickerView()
            case .dailyQuests:
                DailyQuestsView()
            case .dailyStreaks:
                DailyStreaksView()
            case .practice:
                PracticeHubView(
                    onOpenDailyChallenge: { closeSheetAndRun { actions.openChallenge() } },
                    onOpenCreate: { closeSheetAndRun { actions.openCreate() } },
                    onOpenProCoach: { presentedSheet = .proCoach }
                )
            case .modes:
                ModeLibraryView(
                    onPlay: { closeSheetAndRun { actions.play() } },
                    onDaily: { closeSheetAndRun { actions.openDaily() } },
                    onChallenge: { closeSheetAndRun { actions.openChallenge() } },
                    onCreate: { closeSheetAndRun { actions.openCreate() } },
                    onPractice: { presentedSheet = .practice }
                )
            case .feed:
                SocialFeedView()
            case .friends:
                FriendsView()
            case .account:
                AccountCenterView()
            case .subscription:
                SubscriptionCenterView()
            case .reminders:
                ReminderSettingsView()
            case .widgetPromo:
                WidgetPromoView()
            case .yearReview:
                YearReviewView()
            case .proCoach:
                ProCoachView()
            }
        }
        // Boosts Sheet
        .sheet(isPresented: $isShowingBoosts) {
            BoostsSheet()
        }
        // Weekly Offer Sheet
        .sheet(isPresented: $isShowingWeeklyOffer) {
            WeeklyOfferSheet()
        }
        .sheet(isPresented: $isShowingAdBonusIntro) {
            RewardedInterstitialIntroSheet(
                rewardGems: state.adReward,
                onClaim: {
                    await actions.watchAd()
                }
            )
        }
        // Floating toast notification overlay
        .toastOverlay(manager: toastManager)
        .onChange(of: deepLinkRouter.pendingRoute) { _, route in
            consumeHomeOwnedRoute(route)
        }
        // Update achievements badge count + auto-present weekly offer once per ISO week
        .onAppear {
            state.achievementsBadgeCount = achievementStore.claimableCount
            if WeeklyOfferManager.shouldAutoPresent() {
                WeeklyOfferManager.markAutoPresented()
                isShowingWeeklyOffer = true
            }
            // Consume any pending route that arrived before HomeView was on
            // screen (e.g., cold launch via deep link).
            consumeHomeOwnedRoute(deepLinkRouter.pendingRoute)
        }
        .task {
            // Refresh consent state once per home appearance so the
            // privacy recommendation surfaces in EU regions where UMP
            // requires it.
            isPrivacyOptionsRequired = await adService.isPrivacyOptionsRequired()
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
        .trackScreen(.home)
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
        case "feed": return ""
        case "friends": return ""
        case "settings": return "settings"
        case "theme": return "themedefault"
        default: return ""
        }
    }

    private func closeSheetAndRun(_ action: @escaping @MainActor () -> Void) {
        presentedSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            action()
        }
    }

    // MARK: - Recommendation / readiness helpers

    /// Build the single recommendation to highlight, gated by readiness state.
    private var currentRecommendation: NextBestAction? {
        let action = playerReadiness.nextBestAction(
            highestTile: gameStore.state.highestTile,
            highestTileStep: gameStore.state.highestTileStep,
            gems: state.gems,
            canClaimDaily: dailyClaimsStore.canClaimToday,
            bonusSpins: spinState.bonusSpins,
            isPrivacyOptionsRequired: isPrivacyOptionsRequired
        )
        // .play and .nextMilestone are surfaced via the main Play button rather than a banner.
        if action == .play || action == .nextMilestone { return nil }
        return action
    }

    private var isCreateNearUnlock: Bool {
        gameStore.state.highestTileStep >= 15 || gameStore.state.highestTile >= 65_536
    }

    private var isChallengeNearUnlock: Bool {
        gameStore.state.highestTileStep >= 25 || gameStore.state.highestTile >= 67_108_864
    }

    private func applyRecommendation(_ action: NextBestAction) {
        switch action {
        case .tutorial, .play, .nextMilestone:
            actions.play()
        case .claimDaily:
            actions.openDaily()
        case .freeSpin:
            actions.openFreeSpin()
        case .unlockCreate:
            if !state.isCreateLocked { actions.openCreate() }
        case .unlockChallenge:
            if !state.isChallengeLocked { actions.openChallenge() }
        case .lowInventoryShop:
            presentedSheet = .shop
        case .settingsPrivacy:
            // Surface the UMP privacy form directly when available; otherwise
            // open Settings so the player can find the privacy controls.
            Task {
                let didPresent = await adService.showPrivacyOptions()
                if !didPresent {
                    await MainActor.run { presentedSheet = .settings }
                }
                isPrivacyOptionsRequired = await adService.isPrivacyOptionsRequired()
            }
        }
    }

    /// Routes that HomeView's `presentedSheet` owns. RootGameView handles
    /// the rest (shop, daily, spin, challenge, gameplay, tutorial).
    @MainActor
    private func consumeHomeOwnedRoute(_ route: AppRoute?) {
        guard let route else { return }
        switch route {
        case .settings:
            presentedSheet = .settings
        case .profile:
            presentedSheet = .profile
        case .achievements:
            presentedSheet = .achievements
        case .leaderboard:
            presentedSheet = .leaderboard
        case .theme:
            presentedSheet = .themePicker
        case .music:
            presentedSheet = .music
        case .dailyQuests:
            presentedSheet = .dailyQuests
        case .dailyStreaks:
            presentedSheet = .dailyStreaks
        case .practice:
            presentedSheet = .practice
        case .modes:
            presentedSheet = .modes
        case .feed:
            presentedSheet = .feed
        case .friends:
            presentedSheet = .friends
        case .account:
            presentedSheet = .account
        case .subscription:
            presentedSheet = .subscription
        case .reminders:
            presentedSheet = .reminders
        case .widgetPromo:
            presentedSheet = .widgetPromo
        case .yearReview:
            presentedSheet = .yearReview
        case .proCoach:
            presentedSheet = .proCoach
        case .shop, .daily, .spin, .challenge, .tutorial, .gameplay:
            return
        }
        deepLinkRouter.consume()
    }
}

// MARK: - Recommendation Card

private struct NextBestActionCard: View {
    let action: NextBestAction
    let onAct: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.18), in: Circle())
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.avenirNext(size: GameFonts.bodySize, weight: .bold))
                    .lineLimit(1)
                Text(action.subtitle)
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button(action: onAct) {
                Text(ctaText)
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss recommendation")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassEffectCompat(cornerRadius: 14)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Recommended next action"))
    }

    private var iconName: String {
        switch action {
        case .tutorial: return "graduationcap.fill"
        case .play: return "play.fill"
        case .claimDaily: return "calendar.badge.checkmark"
        case .freeSpin: return "arrow.triangle.2.circlepath"
        case .nextMilestone: return "crown.fill"
        case .unlockCreate: return "lock.open.fill"
        case .unlockChallenge: return "flag.checkered"
        case .lowInventoryShop: return "cart.fill"
        case .settingsPrivacy: return "lock.shield.fill"
        }
    }

    private var ctaText: String {
        switch action {
        case .tutorial: return "Learn"
        case .play, .nextMilestone: return "Play"
        case .claimDaily: return "Claim"
        case .freeSpin: return "Spin"
        case .unlockCreate, .unlockChallenge: return "Open"
        case .lowInventoryShop: return "Shop"
        case .settingsPrivacy: return "Open"
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

private struct RewardedInterstitialIntroSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isClaiming = false
    @State private var message: String?

    let rewardGems: Int
    let onClaim: @MainActor @Sendable () async -> Int

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gift.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.yellow)

            Text("Bonus Chest")
                .font(.avenirNext(size: GameFonts.title2Size, weight: .bold))

            Text("Watch a short ad to claim +\(rewardGems) gems, or skip and keep playing without the bonus.")
                .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let message {
                Text(message)
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { @MainActor in
                    isClaiming = true
                    let granted = await onClaim()
                    isClaiming = false
                    if granted > 0 {
                        dismiss()
                    } else {
                        message = "The reward is not available yet. Please try again in a moment."
                    }
                }
            } label: {
                Text(isClaiming ? "Preparing Reward..." : "Claim +\(rewardGems) Gems")
                    .font(.avenirNext(size: GameFonts.bodySize, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isClaiming)

            Button(role: .cancel) {
                dismiss()
            } label: {
                Text("Skip")
                    .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .presentationDetents([.medium])
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
        .environment(PlayerReadinessStore())
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
        .environment(PlayerReadinessStore())
}

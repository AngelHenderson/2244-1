import SwiftUI
import GameApp
import GameCore
import GameServices

public struct HomeView: View {
    private let managesBackground: Bool
    @Environment(HomeState.self) private var state
    @Environment(DailyClaimsStore.self) private var dailyClaimsStore
    @Environment(DailyQuestStore.self) private var dailyQuestStore
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
    @State private var showLockedCreateAlert: Bool = false
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

    public init(managesBackground: Bool = true) {
        self.managesBackground = managesBackground
    }
    
    public var body: some View {
        GeometryReader { rootGeo in
            let recommendation = currentRecommendation
            let leftItems = leftRailItems
            let rightItems = rightRailItems
            let visibleDockItems = dockItems
            let metrics = HomeLayoutMetrics(
                availableSize: rootGeo.size,
                safeAreaInsets: rootGeo.safeAreaInsets,
                leftRailItemCount: leftItems.count,
                rightRailItemCount: rightItems.count,
                dockItemCount: visibleDockItems.count,
                hasRecommendation: recommendation != nil
            )

            ZStack(alignment: .top) {
                if managesBackground {
                    HomeBackgroundLayer(theme: currentBackgroundTheme)
                        .ignoresSafeArea()
                        .zIndex(0)
                }

                JourneyPanel(
                    topInset: metrics.journeyTopInset(measuredHeaderHeight: headerHeight),
                    bottomInset: metrics.journeyBottomInset(
                        measuredPlayHeight: playButtonHeight,
                        measuredDockHeight: bottomDockHeight
                    )
                )

                VStack(spacing: 0) {
                    header(recommendation: recommendation, horizontalPadding: metrics.contentHorizontalPadding)
                        .background(HeightReader(height: $headerHeight))

                    GeometryReader { middleGeo in
                        let leftMetrics = metrics.railMetrics(for: leftItems.count, availableHeight: middleGeo.size.height)
                        let rightMetrics = metrics.railMetrics(for: rightItems.count, availableHeight: middleGeo.size.height)

                        HStack(alignment: .top, spacing: metrics.middleHorizontalSpacing) {
                            sideRail(items: leftItems, metrics: leftMetrics)

                            Spacer(minLength: 0)

                            sideRail(items: rightItems, metrics: rightMetrics)
                        }
                        .padding(.horizontal, metrics.contentHorizontalPadding)
                        .frame(width: middleGeo.size.width, height: middleGeo.size.height, alignment: .top)
                    }

                    playButton(metrics: metrics.play)
                        .background(HeightReader(height: $playButtonHeight))

                    bottomDock(items: visibleDockItems, metrics: metrics.dock)
                        .background(HeightReader(height: $bottomDockHeight))
                }
                .zIndex(1)
            }
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
                    onPlayPractice: { config in
                        closeSheetAndRun {
                            actions.playCustomChallenge(config)
                        }
                    },
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
            state.updateNpcRepliesBadgeCount()
            state.achievementsBadgeCount = achievementStore.claimableCount + dailyQuestStore.claimableCount
            if WeeklyOfferManager.shouldAutoPresent() {
                WeeklyOfferManager.markAutoPresented()
                isShowingWeeklyOffer = true
            }
            // Consume any pending route that arrived before HomeView was on
            // screen (e.g., cold launch via deep link).
            consumeHomeOwnedRoute(deepLinkRouter.pendingRoute)

            // Recompute visible features based on current progress so
            // dock items unlocked during the last play session appear
            // immediately when returning to the home screen.
            playerReadiness.recomputeVisibleFeatures(
                highestTile: gameStore.state.highestTile,
                highestTileStep: gameStore.state.highestTileStep
            )
        }
        .task {
            // Refresh consent state once per home appearance so the
            // privacy recommendation surfaces in EU regions where UMP
            // requires it.
            isPrivacyOptionsRequired = await adService.isPrivacyOptionsRequired()
        }
        .onChange(of: achievementStore.claimableCount) { _, newCount in
            state.achievementsBadgeCount = newCount + dailyQuestStore.claimableCount
        }
        .onChange(of: dailyQuestStore.claimableCount) { _, newCount in
            state.achievementsBadgeCount = achievementStore.claimableCount + newCount
        }
        .alert("Tile Too Low", isPresented: $showLockedChallengeAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Sorry! You do not have a high enough tile to unlock this. You need a 1B tile.")
        }
        .alert("Tile Too Low", isPresented: $showLockedCreateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Sorry! You do not have a high enough tile to unlock this. You need a 1M tile.")
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
        .onChange(of: presentedSheet) { _, newValue in
            if newValue == nil {
                state.updateNpcRepliesBadgeCount()
            }
        }
        .trackScreen(.home)
    }

    @ViewBuilder
    private func header(recommendation: NextBestAction?, horizontalPadding: CGFloat) -> some View {
        VStack(spacing: 0) {
            HomeTopHUDView(
                streakDays: dailyClaimsStore.currentStreak,
                gems: state.gems,
                nextReward: dailyClaimsStore.getNextClaimableDay().flatMap { day in dailyClaimsStore.dailyClaims.first(where: { $0.day == day })?.rewards },
                canClaim: dailyClaimsStore.canClaimToday,
                onStreakTap: { presentedSheet = .dailyStreaks },
                onShopTap: { actions.openShop() }
            )

            if let recommendation {
                HomeRecommendationBanner(action: recommendation) {
                    applyRecommendation(recommendation)
                } onDismiss: {
                    playerReadiness.dismissRecommendation(recommendation)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func sideRail(items: [HomeRailItem], metrics: HomeLayoutMetrics.RailMetrics) -> some View {
        if metrics.columnCount == 1 {
            VStack(spacing: metrics.rowSpacing) {
                ForEach(items) { item in
                    railButton(item, metrics: metrics)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, metrics.topPadding)
            .frame(width: metrics.totalWidth)
        } else {
            VStack(spacing: 0) {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.fixed(metrics.itemWidth), spacing: metrics.columnSpacing),
                        count: metrics.columnCount
                    ),
                    spacing: metrics.rowSpacing
                ) {
                    ForEach(items) { item in
                        railButton(item, metrics: metrics)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.top, metrics.topPadding)
            .frame(width: metrics.totalWidth)
        }
    }

    private func railButton(_ item: HomeRailItem, metrics: HomeLayoutMetrics.RailMetrics) -> some View {
        SideRailButton(
            systemImage: item.systemImage,
            customImage: item.customImage,
            title: item.title,
            metrics: metrics,
            badge: item.badge,
            badgeCount: item.badgeCount,
            locked: item.locked,
            banned: item.banned,
            specialLabel: item.specialLabel,
            specialLabelInside: item.specialLabelInside,
            countdownDeadline: item.countdownDeadline,
            onLockedTap: item.onLockedTap,
            onBannedTap: item.onBannedTap,
            action: item.action
        )
    }

    private func playButton(metrics: HomeLayoutMetrics.PlayButtonMetrics) -> some View {
        PillButton(title: "Play", icon: "play.fill", metrics: metrics) {
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
                    .offset(x: -8, y: 2)
            }
        }
    }

    private func bottomDock(items: [HomeDockItem], metrics: HomeLayoutMetrics.DockMetrics) -> some View {
        HomeCustomTabBar(items: items, metrics: metrics)
    }

    private var leftRailItems: [HomeRailItem] {
        var items: [HomeRailItem] = []

        if playerReadiness.isVisible(.daily) {
            items.append(
                HomeRailItem(
                    id: "daily",
                    systemImage: nil,
                    customImage: "dailypic",
                    title: "DAILY",
                    badge: dailyClaimsStore.canClaimToday,
                    banned: state.isBanned,
                    onBannedTap: { state.showBanAlert = true },
                    action: { actions.openDaily() }
                )
            )
        }

        items.append(
            HomeRailItem(
                id: "free-spin",
                systemImage: nil,
                customImage: "spinthewheel",
                title: "SPIN",
                badgeCount: spinState.bonusSpins > 0 ? spinState.bonusSpins : nil,
                banned: state.isBanned,
                onBannedTap: { state.showBanAlert = true },
                action: { actions.openFreeSpin() }
            )
        )

        if playerReadiness.isVisible(.shop) {
            items.append(
                HomeRailItem(
                    id: "shop",
                    systemImage: nil,
                    customImage: "mysterybox",
                    title: "SHOP",
                    action: { presentedSheet = .shop }
                )
            )
        }

        if playerReadiness.isVisible(.music) {
            items.append(
                HomeRailItem(
                    id: "music",
                    systemImage: nil,
                    customImage: "soundeffect",
                    title: "MUSIC",
                    action: { presentedSheet = .music }
                )
            )
        }

        if playerReadiness.isVisible(.boosts) {
            items.append(
                HomeRailItem(
                    id: "boosts",
                    systemImage: "bolt.fill",
                    customImage: nil,
                    title: "BOOSTS",
                    banned: state.isBanned,
                    onBannedTap: { state.showBanAlert = true },
                    action: { isShowingBoosts = true }
                )
            )
        }

        if playerReadiness.isVisible(.practice) {
            items.append(
                HomeRailItem(
                    id: "practice",
                    systemImage: "target",
                    customImage: nil,
                    title: "PRACTICE",
                    action: { presentedSheet = .practice }
                )
            )
        }

        return items
    }

    private var rightRailItems: [HomeRailItem] {
        var items: [HomeRailItem] = []

        if playerReadiness.isVisible(.create) || isCreateNearUnlock {
            items.append(
                HomeRailItem(
                    id: "create",
                    systemImage: nil,
                    customImage: "createagame",
                    title: "CREATE",
                    locked: state.isCreateLocked,
                    banned: state.isBanned,
                    onLockedTap: { showLockedCreateAlert = true },
                    onBannedTap: { state.showBanAlert = true },
                    action: { actions.openCreate() }
                )
            )
        }

        if !purchaseService.isAdFreePurchased && playerReadiness.isVisible(.adBonus) {
            items.append(
                HomeRailItem(
                    id: "ad-bonus",
                    systemImage: nil,
                    customImage: "ads",
                    title: "BONUS",
                    banned: state.isBanned,
                    specialLabel: "+\(state.adReward)",
                    specialLabelInside: true,
                    onBannedTap: { state.showBanAlert = true },
                    action: { isShowingAdBonusIntro = true }
                )
            )
        }

        if playerReadiness.isVisible(.challenge) || isChallengeNearUnlock {
            items.append(
                HomeRailItem(
                    id: "challenge",
                    systemImage: nil,
                    customImage: "challenge",
                    title: "CHALLENGE",
                    locked: state.isChallengeLocked,
                    banned: state.isBanned,
                    onLockedTap: { showLockedChallengeAlert = true },
                    onBannedTap: { state.showBanAlert = true },
                    action: { actions.openChallenge() }
                )
            )
        }

        if playerReadiness.isVisible(.bestOffer) {
            items.append(
                HomeRailItem(
                    id: "best-offer",
                    systemImage: nil,
                    customImage: "gift",
                    title: "BEST OFFER",
                    countdownDeadline: state.bestOfferDeadline,
                    action: { isShowingWeeklyOffer = true }
                )
            )
        }

        if playerReadiness.isVisible(.theme) {
            items.append(
                HomeRailItem(
                    id: "theme",
                    systemImage: nil,
                    customImage: "themedefault",
                    title: "THEME",
                    action: { presentedSheet = .themePicker }
                )
            )
        }

        if playerReadiness.isVisible(.modes) {
            items.append(
                HomeRailItem(
                    id: "modes",
                    systemImage: "square.grid.2x2.fill",
                    customImage: nil,
                    title: "MODES",
                    action: { presentedSheet = .modes }
                )
            )
        }

        return items
    }

    private var dockItems: [HomeDockItem] {
        var items: [HomeDockItem] = []

        if playerReadiness.isVisible(.feed) {
            items.append(
                HomeDockItem(
                    id: "feed",
                    system: "bubble.left.and.bubble.right.fill",
                    title: "Feed",
                    badgeCount: state.npcRepliesBadgeCount,
                    banned: state.isBanned,
                    action: {
                        if state.isBanned { state.showBanAlert = true }
                        else { presentedSheet = .feed }
                    }
                )
            )
        }

        items.append(
            HomeDockItem(
                id: "profile",
                system: "person.circle.fill",
                title: "Profile",
                banned: state.isBanned,
                action: {
                    if state.isBanned { state.showBanAlert = true }
                    else { presentedSheet = .profile }
                }
            )
        )

        if playerReadiness.isVisible(.achievements) {
            items.append(
                HomeDockItem(
                    id: "achievements",
                    system: "star.circle.fill",
                    title: "Achievements",
                    badgeCount: state.achievementsBadgeCount,
                    banned: state.isBanned,
                    action: {
                        if state.isBanned { state.showBanAlert = true }
                        else { presentedSheet = .achievements }
                    }
                )
            )
        }

        if playerReadiness.isVisible(.leaderboard) {
            items.append(
                HomeDockItem(
                    id: "leaderboard",
                    system: "trophy.circle.fill",
                    title: "Leaderboard",
                    action: { presentedSheet = .leaderboard }
                )
            )
        }

        items.append(
            HomeDockItem(
                id: "settings",
                system: "gearshape.fill",
                title: "Settings",
                action: { presentedSheet = .settings }
            )
        )

        if playerReadiness.isVisible(.friends) {
            items.append(
                HomeDockItem(
                    id: "friends",
                    system: "person.2.circle.fill",
                    title: "Friends",
                    banned: state.isBanned,
                    action: {
                        if state.isBanned { state.showBanAlert = true }
                        else { presentedSheet = .friends }
                    }
                )
            )
        }

        return items
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
            if state.isBanned { state.showBanAlert = true }
            else { presentedSheet = .profile }
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
            if state.isBanned { state.showBanAlert = true }
            else { presentedSheet = .feed }
        case .friends:
            if state.isBanned { state.showBanAlert = true }
            else { presentedSheet = .friends }
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

private struct HomeRailItem: Identifiable {
    let id: String
    let systemImage: String?
    let customImage: String?
    let title: String
    var badge: Bool = false
    var badgeCount: Int? = nil
    var locked: Bool = false
    var banned: Bool = false
    var specialLabel: String? = nil
    var specialLabelInside: Bool = false
    var countdownDeadline: Date? = nil
    var onLockedTap: (() -> Void)? = nil
    var onBannedTap: (() -> Void)? = nil
    let action: () -> Void
}

private struct HeightReader: View {
    @Binding var height: CGFloat

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    height = geo.size.height
                }
                .onChange(of: geo.size.height) { _, newHeight in
                    height = newHeight
                }
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

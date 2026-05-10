//
//  game2244App.swift
//  game2244
//
//  Created by Angel Henderson on 8/11/25.
//

import SwiftUI
import GameApp
import GameServices
import GameUI
import GameCore
import GameKit
import FirebaseCore

@main
struct game2244App: App {
    // Register AppDelegate for SwiftUI
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        configureNavigationBarAppearance()
    }

    private func configureNavigationBarAppearance() {
        // Configure Avenir Next for navigation bar titles
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()

        // Large title (used when .navigationBarTitleDisplayMode(.large))
        if let largeTitleFont = UIFont(name: "AvenirNext-Bold", size: 34) {
            appearance.largeTitleTextAttributes = [.font: largeTitleFont]
        }

        // Inline title (used when .navigationBarTitleDisplayMode(.inline))
        if let titleFont = UIFont(name: "AvenirNext-DemiBold", size: 17) {
            appearance.titleTextAttributes = [.font: titleFont]
        }

        // Apply to all navigation bars
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    @State private var gameStore = GameStore()
    @State private var homeState = HomeState()
    @State private var purchaseService = PurchaseService()
    @State private var adService = LiveAdService()
    @State private var hapticsService = HapticsService()
    @State private var audioService = LiveAudioService()
    @State private var gameCenterService = DefaultGameCenterService()
    @State private var themeRegistry = ThemeRegistry.Default
    @State private var backgroundThemeRegistry = BackgroundThemeRegistry.Default
    @AppStorage("selectedThemeId") private var selectedThemeId: String = "raised-3d-square"
    @AppStorage("selectedBackgroundThemeId") private var selectedBackgroundThemeId: String = "city_1"
    @State private var isPlaying: Bool = false
    @State private var storageService = UserDefaultsStorageService()
    @State private var achievementStore = AchievementStore()
    @State private var dailyClaimsStore = DailyClaimsStore()
    @State private var gemWallet = GemWallet()
    @State private var playerReadiness = PlayerReadinessStore()
    @State private var rewardLedger = RewardLedgerStore()
    @State private var shopStore: ShopStore? = nil
    @State private var challengeStore = ChallengeStore()
    @State private var challengeDesignerStore = ChallengeDesignerStore()
    @State private var spinWheelState = SpinWheelState()
    @State private var dailyQuestStore = DailyQuestStore()
    @State private var seasonHistoryStore = SeasonHistoryStore()
    @State private var leaderboardClient: LeaderboardClient = .empty
    @State private var reportService: any ReportServiceProtocol = NoopReportService()
    @State private var socialService: any SocialService = FirestoreSocialService()
    @State private var deepLinkRouter = DeepLinkRouter()

    private let planner: MilestonePlanner = PowerOfTwoPlanner()
    private let reminderNotificationScheduler = LocalReminderNotificationScheduler()
    private let analyticsService = FirebaseAnalyticsService()
    private static let lastLaunchAtKey = "analytics.lastLaunchAt"
    
    
    private var currentBackgroundTheme: BackgroundTheme {
        backgroundThemeRegistry.theme(for: selectedBackgroundThemeId)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                HomeBackgroundLayer(theme: currentBackgroundTheme)
                    .ignoresSafeArea()
                    .zIndex(0)

                RootGameView(managesBackground: false)
            }
            .onOpenURL { url in
                deepLinkRouter.handle(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GemsDidChange"))) { notification in
                if let newBalance = notification.userInfo?["newBalance"] as? Int {
                    homeState.gems = newBalance
                    gameStore.coins = newBalance
                }
            }
                .environment(\.gameStore, gameStore)
                .environment(\.purchaseService, purchaseService)
                .environment(\.adService, adService)
                .environment(\.hapticsService, hapticsService)
                .environment(\.audio, audioService)
                .environment(\.gameCenter, gameCenterService)
                .environment(\.storage, storageService)
                .environment(\.currentTheme, themeRegistry.descriptor(for: selectedThemeId))
                .environment(\.backgroundThemeRegistry, backgroundThemeRegistry)
                .environment(\.currentBackgroundTheme, backgroundThemeRegistry.theme(for: selectedBackgroundThemeId))
                .environment(\.tileJourney, gameStore.journey)
                // Starts empty so release builds never show synthetic leaderboard rows
                // before the real backend selection completes.
                .environment(\.leaderboardClient, leaderboardClient)
                .environment(\.reportService, reportService)
                .environment(\.socialService, socialService)
                .environment(\.analytics, analyticsService)
                .environment(\.reminderNotificationScheduler, reminderNotificationScheduler)
                .environment(homeState)
                .environment(playerReadiness)
                .environment(rewardLedger)
                .environment(\.rewardLedgerOptional, rewardLedger)
                .environment(achievementStore)
                .environment(dailyClaimsStore)
                .environment(dailyQuestStore)
                .environment(\.seasonHistoryStore, seasonHistoryStore)
                .environment(
                    \.shopStore,
                    shopStore ?? ShopStore(
                        journeyStore: gameStore.journey,
                        purchaseService: purchaseService,
                        gemWallet: gemWallet,
                        gameStore: gameStore,
                        rewardLedger: rewardLedger,
                        analytics: analyticsService
                    )
                )
                .environment(\.challengeStore, challengeStore)
                .environment(\.challengeDesignerStore, challengeDesignerStore)
                .environment(\.spinWheelState, spinWheelState)
                .environment(\.deepLinkRouter, deepLinkRouter)
                .onChange(of: purchaseService.isAdFreePurchased) { _, isAdFree in
                    adService.setAdFree(isAdFree)
                }
                .task {
                    // --- Synchronous Setup First ---
                    gemWallet.attach(gameStore: gameStore, homeState: homeState)
                    gemWallet.bootstrapFromLocal()
                    gameStore.spinWheelState = spinWheelState
                    gameStore.rewardLedger = rewardLedger

                    // Initialize shop store
                    shopStore = ShopStore(
                        journeyStore: gameStore.journey,
                        purchaseService: purchaseService,
                        gemWallet: gemWallet,
                        gameStore: gameStore,
                        rewardLedger: rewardLedger,
                        analytics: analyticsService
                    )

                    await recordLaunchAnalytics()

                    // Load achievements synchronously
                    try? achievementStore.loadCatalogFromBundle(named: "2244_achievements")
                    
                    let applyRewards: @MainActor @Sendable (AchievementDef.Rewards) -> Void = { rewards in
                        let markFirstReward: @MainActor () -> Void = {
                            playerReadiness.recordRewardEarned(
                                highestTile: gameStore.state.highestTile,
                                highestTileStep: gameStore.state.highestTileStep
                            )
                        }

                        // Prefer the achievement-claim context (stable across launches via
                        // a persisted claim sequence). When this closure is invoked from
                        // daily claims / quests / streak unlocks, fall back to a process-
                        // unique UUID so the ledger still rejects accidental same-call
                        // duplicates while not interfering with replay protection.
                        let contextKey = achievementStore.lastClaimedRewardContext
                            ?? "applyRewards:\(UUID().uuidString)"

                        let key: @Sendable (RewardLedgerEntry.ItemType, Int) -> String = { item, amount in
                            "\(contextKey):\(item.rawValue):\(amount)"
                        }

                        // Gems (also granted directly via AchievementStore, but keep for wallet sync)
                        if let gems = rewards.gems, gems > 0 {
                            rewardLedger.grant(
                                source: .achievement,
                                itemType: .gems,
                                amount: gems,
                                idempotencyKey: key(.gems, gems)
                            ) {
                                gemWallet.deposit(gems, source: .achievement)
                            }
                            markFirstReward()
                        }
                        
                        // Power-ups
                        if let hammers = rewards.hammers, hammers > 0 {
                            rewardLedger.grant(
                                source: .achievement,
                                itemType: .hammer,
                                amount: hammers,
                                idempotencyKey: key(.hammer, hammers)
                            ) {
                                gameStore.addPowerUp("hammer", count: hammers)
                            }
                            markFirstReward()
                        }
                        if let magnets = rewards.magnets, magnets > 0 {
                            rewardLedger.grant(
                                source: .achievement,
                                itemType: .magnet,
                                amount: magnets,
                                idempotencyKey: key(.magnet, magnets)
                            ) {
                                gameStore.addPowerUp("magnet", count: magnets)
                            }
                            markFirstReward()
                        }
                        if let swaps = rewards.swaps, swaps > 0 {
                            rewardLedger.grant(
                                source: .achievement,
                                itemType: .swap,
                                amount: swaps,
                                idempotencyKey: key(.swap, swaps)
                            ) {
                                gameStore.addPowerUp("swap", count: swaps)
                            }
                            markFirstReward()
                        }
                        
                        // Spins & multipliers
                        if let spins = rewards.spins, spins > 0 {
                            rewardLedger.grant(
                                source: .achievement,
                                itemType: .spin,
                                amount: spins,
                                idempotencyKey: key(.spin, spins)
                            ) {
                                spinWheelState.addBonusSpins(spins)
                            }
                            markFirstReward()
                        }
                        if let boost2x = rewards.boost2x, boost2x > 0 {
                            rewardLedger.grant(
                                source: .achievement,
                                itemType: .multiplier2x,
                                amount: boost2x,
                                idempotencyKey: key(.multiplier2x, boost2x)
                            ) {
                                spinWheelState.addMultiplier(.twoX, count: boost2x)
                            }
                            markFirstReward()
                        }
                        if let boost3x = rewards.boost3x, boost3x > 0 {
                            rewardLedger.grant(
                                source: .achievement,
                                itemType: .multiplier3x,
                                amount: boost3x,
                                idempotencyKey: key(.multiplier3x, boost3x)
                            ) {
                                spinWheelState.addMultiplier(.threeX, count: boost3x)
                            }
                            markFirstReward()
                        }
                        if let boost4x = rewards.boost4x, boost4x > 0 {
                            rewardLedger.grant(
                                source: .achievement,
                                itemType: .multiplier4x,
                                amount: boost4x,
                                idempotencyKey: key(.multiplier4x, boost4x)
                            ) {
                                spinWheelState.addMultiplier(.fourX, count: boost4x)
                            }
                            markFirstReward()
                        }
                    }
                    
                    // Setup achievement evaluator with reward handler
                    achievementStore.onReward = applyRewards

                    let evaluator = AchievementEvaluator(achievementStore: achievementStore)
                    gameStore.achievementEvaluator = evaluator

                    // Wire daily quest store into evaluator (same task = guaranteed order)
                    evaluator.dailyQuestStore = dailyQuestStore
                    dailyQuestStore.setHighestTileStep(gameStore.state.highestTileStep)
                    dailyQuestStore.onReward = { rewards in
                        applyRewards(rewards)
                        homeState.addGems(0) // trigger UI refresh
                    }

                    // Start tracking playtime for the initial session
                    evaluator.onGameStart(state: gameStore.state)

                    // Setup daily claims reward handler
                    dailyClaimsStore.onReward = applyRewards
                    
                    // One-time fix for corrupted score data from sandboxed challenges
                    if !UserDefaults.standard.bool(forKey: "hasResetCorruptedScore_v1") {
                        gameStore.resetCorruptedScoreData()
                        UserDefaults.standard.set(true, forKey: "hasResetCorruptedScore_v1")
                    }

                    // Load initial progress
                    loadInitialProgress()

                    // --- Asynchronous Network/Auth Setup ---

                    FirebaseService.shared.initialize()
                    let gameCenterClient = LeaderboardClient.gameCenter()
                    if FirebaseApp.app() != nil {
                        try? await FirebaseService.shared.signInAnonymously()
                        if let snapshot = FirebaseService.shared.currentAuthUser {
                            try? await FirebaseService.shared.upsertPublicUserProfile(
                                uid: snapshot.uid,
                                displayName: snapshot.displayName ?? "Player",
                                username: snapshot.email?.split(separator: "@").first.map(String.init) ?? "player",
                                avatarID: UserDefaults.standard.string(forKey: "profileAvatarId") ?? "avatar_buddy_bot",
                                friendCode: String(snapshot.uid.prefix(6)).uppercased(),
                                countryCode: UserDefaults.standard.string(forKey: "profileCountryCode")
                            )
                        }
                        await gemWallet.startCloudSync()
                        await homeState.startBlockedPlayersCloudSync()
                        let firebaseClient = LeaderboardClient.firebase(LeaderboardService())
                        leaderboardClient = .mirroring(
                            primary: firebaseClient,
                            secondary: gameCenterClient
                        )
                        reportService = FirestoreReportService()
                    } else {
                        #if DEBUG
                        print("⚠️ Firebase not configured; leaderboard uses Mock data + Game Center and gem cloud sync skipped.")
                        socialService = MockSocialService()
                        leaderboardClient = .mirroring(primary: .mock, secondary: gameCenterClient)
                        #else
                        leaderboardClient = gameCenterClient
                        #endif
                    }

                    gameStore.onGameEnded = { summary in
                        playerReadiness.recordRunCompleted(summary)
                        Task { @MainActor in
                            await recordCoreRunCompleted(summary: summary)
                            await submitGameEndProgress(summary: summary)
                        }
                    }

                    // Suppress simulator-specific warnings in console
                    if ProcessInfo.processInfo.environment.keys.contains("SIMULATOR_DEVICE_NAME") {
                        // Running in simulator - some warnings are expected
                        print("🧪 Running in iOS Simulator - some system warnings are expected")
                    }

                    // Honor persisted ad-free state before any ad request or SDK startup.
                    let isAdFree = purchaseService.isAdFreePurchased
                        || UserDefaults.standard.bool(forKey: "isAdFreePurchased")
                    adService.setAdFree(isAdFree)
                    if !isAdFree {
                        _ = await adService.prepareForAdRequests()
                    }

                    _ = await gameCenterService.authenticate()
                    
                    // Setup Game Center (place access point away from Rank button)
                    GameCenterManager.shared.configureAccessPoint(active: true, location: .topTrailing)
                    #if canImport(UIKit)
                    GameCenterManager.shared.authenticateIfNeeded {
                        UIApplication.shared.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .first?.windows.first?.rootViewController
                    }
                    #endif
                    await achievementStore.syncWithGameCenter()
                    
                    // Enable audio by default if not set
                    if UserDefaults.standard.object(forKey: "musicEnabled") == nil {
                        await audioService.setMusicEnabled(true)
                    }
                    if UserDefaults.standard.object(forKey: "sfxEnabled") == nil {
                        await audioService.setSfxEnabled(true)
                    }
                    
                    // Load daily claims catalogs
                    await dailyClaimsStore.loadCatalogs()

                    playerReadiness.recordSessionStarted()
                }
        }
    }
    
    private func loadInitialProgress() {
        let defaults = UserDefaults.standard
        
        // Load gems
        if defaults.object(forKey: "coins") != nil {
            let gems = defaults.integer(forKey: "coins")
            homeState.gems = gems
            gameStore.coins = gems
        }
        
        // Load highest tile and calculate milestones
        let highest = gameStore.state.highestTile
        let highestStep = gameStore.state.highestTileStep
        if highest > 0 {
            let milestones = planner.milestones(for: highest)
            homeState.highestTile = milestones.current
            homeState.highestTileStep = highestStep
            homeState.milestoneBelow = milestones.below ?? 1024
            homeState.lockedMilestones = milestones.above
        }
    }

    @MainActor
    private func submitGameEndProgress(summary: GameRunSummary) async {
        do {
            try await leaderboardClient.submitRun(summary)
        } catch {
            await fireMajorFlowError(flow: "leaderboard_submit", category: "submit_failed")
        }

        let storedInfinityCount = UserDefaults.standard.integer(forKey: "infinityMergeCount")
        let sessionInfinityCount = summary.infinityMergeCount
        let infinityCount = max(storedInfinityCount, sessionInfinityCount)
        if infinityCount > 0 {
            do {
                try await leaderboardClient.submitInfinityCount(infinityCount)
            } catch {
                await fireMajorFlowError(flow: "leaderboard_submit", category: "infinity_submit_failed")
            }
        }
    }

    @MainActor
    private func recordLaunchAnalytics() async {
        let defaults = UserDefaults.standard
        let now = Date()

        var launchParams: [String: any Sendable] = ["platform": "ios"]
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            launchParams["app_version"] = version
        }
        if let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            launchParams["build_number"] = build
        }

        await analyticsService.fire(
            event: LaunchAnalyticsEvent.appLaunch.rawValue,
            params: launchParams
        )

        if let lastLaunchAt = defaults.object(forKey: Self.lastLaunchAtKey) as? Date {
            let daysSinceLastLaunch = max(0, now.timeIntervalSince(lastLaunchAt) / 86_400)
            await analyticsService.fire(
                event: LaunchAnalyticsEvent.returnSession.rawValue,
                params: ["return_interval": returnIntervalBucket(daysSinceLastLaunch)]
            )
        }

        defaults.set(now, forKey: Self.lastLaunchAtKey)
    }

    @MainActor
    private func recordCoreRunCompleted(summary: GameRunSummary) async {
        await analyticsService.fire(
            event: LaunchAnalyticsEvent.coreRunCompleted.rawValue,
            params: [
                "score_tier": scoreTierBucket(score: summary.score, reachedInfinity: summary.infinityMergeCount > 0),
                "highest_tile_step_bucket": highestTileStepBucket(summary.highestTileStep),
                "moves_bucket": movesBucket(summary.moves),
                "duration_bucket": durationBucket(summary.duration),
                "reached_infinity": summary.infinityMergeCount > 0,
            ]
        )
    }

    @MainActor
    private func fireMajorFlowError(flow: String, category: String) async {
        await analyticsService.fire(
            event: LaunchAnalyticsEvent.majorFlowError.rawValue,
            params: [
                "flow": flow,
                "error_category": category,
            ]
        )
    }

    private func returnIntervalBucket(_ days: TimeInterval) -> String {
        switch days {
        case ..<1: return "same_day"
        case ..<4: return "days_1_3"
        case ..<8: return "days_4_7"
        case ..<31: return "days_8_30"
        default: return "days_31_plus"
        }
    }

    private func scoreTierBucket(score: Int, reachedInfinity: Bool) -> String {
        guard !reachedInfinity else { return "infinity" }
        switch score {
        case ..<10_000: return "under_10k"
        case ..<1_000_000: return "10k_to_1m"
        case ..<1_000_000_000: return "1m_to_1b"
        default: return "1b_plus"
        }
    }

    private func highestTileStepBucket(_ step: Int) -> String {
        switch step {
        case ..<10: return "starter"
        case ..<20: return "thousands"
        case ..<30: return "millions"
        case ..<40: return "billions"
        case ..<65: return "alpha_low"
        default: return "alpha_high"
        }
    }

    private func movesBucket(_ moves: Int) -> String {
        switch moves {
        case ..<25: return "under_25"
        case ..<100: return "25_to_99"
        case ..<250: return "100_to_249"
        default: return "250_plus"
        }
    }

    private func durationBucket(_ duration: TimeInterval) -> String {
        switch duration {
        case ..<60: return "under_1m"
        case ..<300: return "1m_to_5m"
        case ..<900: return "5m_to_15m"
        default: return "15m_plus"
        }
    }
}

// Extension to handle platform-specific presentation
extension View {
    @ViewBuilder
    func gamePresentation<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        self.fullScreenCover(isPresented: isPresented, content: content)
        #else
        self.sheet(isPresented: isPresented, content: content)
        #endif
    }
}

#Preview("HybridGameScreen") {
    // Local services for preview
    let gameStore = GameStore()
    let adService = DummyAdService()
    let haptics = HapticsService()
    let gameCenter = DefaultGameCenterService()
    let storage = UserDefaultsStorageService()
    let themeRegistry = ThemeRegistry.Default
    // Note: Rely on default EnvironmentKeys for backgroundThemeRegistry and audio if available.
    
    return HybridGameScreen(isPlayingDismiss: {})
        .environment(\.gameStore, gameStore)
        .environment(\.adService, adService)
        .environment(\.hapticsService, haptics)
        .environment(\.gameCenter, gameCenter)
        .environment(\.storage, storage)
        .environment(\.currentTheme, themeRegistry.descriptor(for: "raised-3d-square"))
        .environment(\.tileJourney, gameStore.journey)
        .environment(\.leaderboardClient, .mock)
}

#Preview("HomeView") {
    // Local services for preview
    let gameStore = GameStore()
    let homeState = HomeState()
    let purchaseService = PurchaseService()
    let adService = DummyAdService()
    let haptics = HapticsService()
    let gameCenter = DefaultGameCenterService()
    let storage = UserDefaultsStorageService()
    let themeRegistry = ThemeRegistry.Default
    
    // Simple HomeActions for preview
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
        .environment(\.leaderboardClient, .gameCenter())
}

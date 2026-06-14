import SwiftUI
import GameApp
import GameCore

#if DEBUG
@MainActor
struct GameUIScreenPreviewHost<Content: View>: View {
    @State private var homeState: HomeState
    @State private var gameStore: GameStore
    @State private var dailyClaimsStore: DailyClaimsStore
    @State private var dailyQuestStore: DailyQuestStore
    @State private var achievementStore: AchievementStore
    @State private var playerReadiness: PlayerReadinessStore
    @State private var shopStore: ShopStore
    @State private var challengeStore: ChallengeStore
    @State private var challengeDesignerStore: ChallengeDesignerStore
    @State private var spinWheelState: SpinWheelState
    @State private var wheelEngine: WheelEngine
    @State private var seasonHistoryStore: SeasonHistoryStore
    @State private var toastManager: ToastManager

    private let defaults: UserDefaults
    private let profileClient: PreviewProfileClient
    private let accountService: LocalAccountService
    private let audioService: GameUIPreviewAudioService
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        MockSocialService.gamertagProvider = {
            MockLeaderboardData.globalNames + MockLeaderboardData.hallOfFameNames
        }
        let defaults = Self.makeDefaults()
        let homeState = Self.makeHomeState()
        let gameStore = Self.makeGameStore()
        let dailyQuestStore = Self.makeDailyQuestStore(defaults: defaults)
        let dailyClaimsStore = DailyClaimsStore(storage: defaults)
        let achievementStore = AchievementStore(defaults: defaults)
        let shopStore = Self.makeShopStore(journeyStore: gameStore.journey)
        let playerReadiness = PlayerReadinessStore(storage: PreviewPlayerReadinessStorage())

        self.defaults = defaults
        self.profileClient = PreviewProfileClient()
        self.accountService = LocalAccountService(defaults: defaults)
        self.audioService = GameUIPreviewAudioService()
        self.content = content

        _homeState = State(initialValue: homeState)
        _gameStore = State(initialValue: gameStore)
        _dailyClaimsStore = State(initialValue: dailyClaimsStore)
        _dailyQuestStore = State(initialValue: dailyQuestStore)
        _achievementStore = State(initialValue: achievementStore)
        _playerReadiness = State(initialValue: playerReadiness)
        _shopStore = State(initialValue: shopStore)
        _challengeStore = State(initialValue: ChallengeStore())
        _challengeDesignerStore = State(initialValue: ChallengeDesignerStore())
        _spinWheelState = State(initialValue: SpinWheelState())
        _wheelEngine = State(initialValue: WheelEngine())
        _seasonHistoryStore = State(initialValue: SeasonHistoryStore())
        _toastManager = State(initialValue: ToastManager())
    }

    var body: some View {
        content()
            .environment(homeState)
            .environment(dailyClaimsStore)
            .environment(dailyQuestStore)
            .environment(achievementStore)
            .environment(playerReadiness)
            .environment(\.gameStore, gameStore)
            .environment(\.shopStore, shopStore)
            .environment(\.tileJourney, gameStore.journey)
            .environment(\.challengeStore, challengeStore)
            .environment(\.challengeDesignerStore, challengeDesignerStore)
            .environment(\.spinWheelState, spinWheelState)
            .environment(\.wheelEngine, wheelEngine)
            .environment(\.seasonHistoryStore, seasonHistoryStore)
            .environment(\.homeActions, .preview)
            .environment(\.profileClient, profileClient)
            .environment(\.accountService, accountService)
            .environment(\.socialService, MockSocialService())
            .environment(\.purchaseService, PurchaseService())
            .environment(\.adService, DummyAdService())
            .environment(\.hapticsService, HapticsService())
            .environment(\.audio, audioService)
            .environment(\.storage, UserDefaultsStorageService())
            .environment(\.leaderboardClient, .mock)
            .environment(\.gameCenter, DefaultGameCenterService())
            .environment(\.toastManager, toastManager)
            .environment(\.currentTheme, ThemeRegistry.Default.descriptor(for: "raised-3d-square"))
    }

    private static func makeDefaults() -> UserDefaults {
        let suiteName = "gameui.screen.preview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("Angel Junior711", forKey: "profilePlayerName")
        defaults.set("AJ711-534", forKey: "profileFriendCode")
        defaults.set("US", forKey: "profileCountryCode")
        defaults.set(9, forKey: "dailyStreak")
        defaults.set(5, forKey: "dailyClaimDay")
        return defaults
    }

    private static func makeHomeState() -> HomeState {
        let state = HomeState()
        state.rank = 534
        state.gems = 1_240
        state.highestTile = 1_048_576
        state.highestTileStep = 19
        state.milestoneBelow = 524_288
        state.lockedMilestones = [2_097_152, 4_194_304]
        state.achievementsBadgeCount = 3
        return state
    }

    private static func makeGameStore() -> GameStore {
        let store = GameStore.sandboxed(initialGems: 1_240, playerHighestTile: 1_048_576, playerHighestTileStep: 19)
        store.coins = 1_240
        store.journey.didReach(tile: 1_048_576)
        return store
    }

    private static func makeDailyQuestStore(defaults: UserDefaults) -> DailyQuestStore {
        let store = DailyQuestStore(defaults: defaults)
        store.setHighestTileStep(19)
        store.recordMerges(1_450)
        store.recordPowerUpUse(count: 3)
        store.recordChallengeCompleted()
        return store
    }

    private static func makeShopStore(journeyStore: JourneyKit.Store) -> ShopStore {
        let store = ShopStore(journeyStore: journeyStore)
        store.catalog = ShopCatalog.preview
        store.isLoading = false
        return store
    }
}

extension HomeActions {
    static let preview = HomeActions(
        play: {},
        openShop: {},
        buyGems: {},
        watchAd: { 50 },
        openDaily: {},
        openDailyStreaks: {},
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
        openSaleOffer: {},
        openDailyQuests: {},
        openPractice: {},
        openModes: {},
        openFeed: {},
        openFriends: {},
        openAccount: {},
        openSubscription: {},
        openReminders: {},
        openWidgetPromo: {},
        openYearReview: {},
        openProCoach: {}
    )
}

struct PreviewProfileClient: ProfileClient, Sendable {
    func fetchProfile() async throws -> ProfilePayload {
        ProfilePayload(
            playerName: "Angel Junior711",
            bestScoreText: "1,048,576",
            globalRank: 534,
            tiers: [
                TierStat(key: "K", value: 12, color: .green, label: "K-Tier"),
                TierStat(key: "M", value: 4, color: .blue, label: "M-Tier"),
                TierStat(key: "B", value: 1, color: .purple, label: "B-Tier"),
            ],
            friendCode: "AJ711-534",
            season: SeasonInfo(name: "Season 7", division: "Diamond"),
            avatarSystemName: AvatarCatalog.default.id,
            countryCode: "US",
            highestTile: "1M"
        )
    }

    func updatePlayerName(_ name: String) async throws {}
    func updateCountry(_ countryCode: String?) async throws {}

    func shareDeepLink(for payload: ProfilePayload) -> URL {
        URL(string: "game2244://profile?id=\(payload.friendCode)")!
    }
}

struct PreviewPlayerReadinessStorage: PlayerReadinessStorage {
    func load() -> PlayerReadinessSnapshot {
        PlayerReadinessSnapshot(
            hasCompletedTutorial: true,
            sessionsStarted: 8,
            completedRuns: 5,
            totalMerges: 1_450,
            hasEarnedFirstReward: true,
            visibleFeatures: Set(HomeFeature.allCases),
            onboardingPreferences: OnboardingPreferences(completedAt: Date()),
            reminderPreferences: ReminderPreferences(
                practiceReminderEnabled: true,
                streakReminderEnabled: true,
                questReminderEnabled: true,
                smartSchedulingEnabled: true,
                reminderHour: 19,
                reminderMinute: 30
            )
        )
    }

    func save(_ snapshot: PlayerReadinessSnapshot) {}
}

struct GameUIPreviewAudioService: AudioServiceProtocol {
    func setMusicEnabled(_ enabled: Bool) async {}
    func setSfxEnabled(_ enabled: Bool) async {}
    func playMusic(loop: Bool) async {}
    func playMusic(named fileName: String, loop: Bool) async {}
    func stopMusic() async {}
    func playSfx(name: String) async {}
    func playMergeSfx(tileCount: Int) async {}
    func stopTickSound() async {}
    func setCurrentMusicTheme(_ theme: String) async {}
}

enum ScreenPreviewFixtures {
    static let challengeConfig = CustomChallengeConfig(
        target: .tileStep(19),
        timeLimitSeconds: 180,
        minTileLevel: 2,
        levels: 7,
        tileAssignments: [
            0: .low,
            1: .mid,
            2: .high,
        ],
        predictedRewardGems: 150,
        minSpawnStep: 1,
        maxSpawnStep: 8
    )

    @MainActor
    static func achievementTiers() -> [AchievementStore.TierEntry] {
        AchievementStore(defaults: UserDefaults(suiteName: "gameui.preview.tiers") ?? .standard)
            .allTiers(for: "moves_progression")
    }

    static let leaderboardEntries: [LeaderboardEntry] = [
        LeaderboardEntry(id: "1", rank: 1, name: "OldCentipede46123", score: 208_000, countryCode: "US", platform: .ios, highestTile: "208bx"),
        LeaderboardEntry(id: "2", rank: 2, name: "lalajalay", score: 94_000, countryCode: "US", platform: .ios, highestTile: "94bt"),
        LeaderboardEntry(id: "me", rank: 46, name: "Angel Junior711", score: 1_000, countryCode: "US", platform: .ios, isMe: true, highestTile: "1an"),
    ]
}
#endif

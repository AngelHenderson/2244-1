import SwiftUI

public struct HomeActions: Sendable {
    public var play: @Sendable @MainActor () -> Void = {}
    public var openShop: @Sendable @MainActor () -> Void = {}
    public var buyGems: @Sendable @MainActor () -> Void = {}
    public var watchAd: @Sendable @MainActor () async -> Int = { 0 }
    public var openDaily: @Sendable @MainActor () -> Void = {}
    public var openDailyStreaks: @Sendable @MainActor () -> Void = {}
    public var openFreeSpin: @Sendable @MainActor () -> Void = {}
    public var openMusic: @Sendable @MainActor () -> Void = {}
    public var openChallenge: @Sendable @MainActor () -> Void = {}
    public var openCreate: @Sendable @MainActor () -> Void = {}
    public var openProfile: @Sendable @MainActor () -> Void = {}
    public var openAchievements: @Sendable @MainActor () -> Void = {}
    public var openLeaderboard: @Sendable @MainActor () -> Void = {}
    public var openSettings: @Sendable @MainActor () -> Void = {}
    public var openThemeLeft: @Sendable @MainActor () -> Void = {}
    public var openThemeRight: @Sendable @MainActor () -> Void = {}
    public var openSaleOffer: @Sendable @MainActor () -> Void = {}
    public var openDailyQuests: @Sendable @MainActor () -> Void = {}
    public var openPractice: @Sendable @MainActor () -> Void = {}
    public var openModes: @Sendable @MainActor () -> Void = {}
    public var openFeed: @Sendable @MainActor () -> Void = {}
    public var openFriends: @Sendable @MainActor () -> Void = {}
    public var openAccount: @Sendable @MainActor () -> Void = {}
    public var openSubscription: @Sendable @MainActor () -> Void = {}
    public var openReminders: @Sendable @MainActor () -> Void = {}
    public var openWidgetPromo: @Sendable @MainActor () -> Void = {}
    public var openYearReview: @Sendable @MainActor () -> Void = {}
    public var openProCoach: @Sendable @MainActor () -> Void = {}
    
    public init(
        play: @escaping @Sendable @MainActor () -> Void = {},
        openShop: @escaping @Sendable @MainActor () -> Void = {},
        buyGems: @escaping @Sendable @MainActor () -> Void = {},
        watchAd: @escaping @Sendable @MainActor () async -> Int = { 0 },
        openDaily: @escaping @Sendable @MainActor () -> Void = {},
        openDailyStreaks: @escaping @Sendable @MainActor () -> Void = {},
        openFreeSpin: @escaping @Sendable @MainActor () -> Void = {},
        openMusic: @escaping @Sendable @MainActor () -> Void = {},
        openChallenge: @escaping @Sendable @MainActor () -> Void = {},
        openCreate: @escaping @Sendable @MainActor () -> Void = {},
        openProfile: @escaping @Sendable @MainActor () -> Void = {},
        openAchievements: @escaping @Sendable @MainActor () -> Void = {},
        openLeaderboard: @escaping @Sendable @MainActor () -> Void = {},
        openSettings: @escaping @Sendable @MainActor () -> Void = {},
        openThemeLeft: @escaping @Sendable @MainActor () -> Void = {},
        openThemeRight: @escaping @Sendable @MainActor () -> Void = {},
        openSaleOffer: @escaping @Sendable @MainActor () -> Void = {},
        openDailyQuests: @escaping @Sendable @MainActor () -> Void = {},
        openPractice: @escaping @Sendable @MainActor () -> Void = {},
        openModes: @escaping @Sendable @MainActor () -> Void = {},
        openFeed: @escaping @Sendable @MainActor () -> Void = {},
        openFriends: @escaping @Sendable @MainActor () -> Void = {},
        openAccount: @escaping @Sendable @MainActor () -> Void = {},
        openSubscription: @escaping @Sendable @MainActor () -> Void = {},
        openReminders: @escaping @Sendable @MainActor () -> Void = {},
        openWidgetPromo: @escaping @Sendable @MainActor () -> Void = {},
        openYearReview: @escaping @Sendable @MainActor () -> Void = {},
        openProCoach: @escaping @Sendable @MainActor () -> Void = {}
    ) {
        self.play = play
        self.openShop = openShop
        self.buyGems = buyGems
        self.watchAd = watchAd
        self.openDaily = openDaily
        self.openDailyStreaks = openDailyStreaks
        self.openFreeSpin = openFreeSpin
        self.openMusic = openMusic
        self.openChallenge = openChallenge
        self.openCreate = openCreate
        self.openProfile = openProfile
        self.openAchievements = openAchievements
        self.openLeaderboard = openLeaderboard
        self.openSettings = openSettings
        self.openThemeLeft = openThemeLeft
        self.openThemeRight = openThemeRight
        self.openSaleOffer = openSaleOffer
        self.openDailyQuests = openDailyQuests
        self.openPractice = openPractice
        self.openModes = openModes
        self.openFeed = openFeed
        self.openFriends = openFriends
        self.openAccount = openAccount
        self.openSubscription = openSubscription
        self.openReminders = openReminders
        self.openWidgetPromo = openWidgetPromo
        self.openYearReview = openYearReview
        self.openProCoach = openProCoach
    }
}

private struct HomeActionsKey: EnvironmentKey {
    static let defaultValue = HomeActions()
}

public extension EnvironmentValues {
    var homeActions: HomeActions {
        get { self[HomeActionsKey.self] }
        set { self[HomeActionsKey.self] = newValue }
    }
}

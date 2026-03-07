import SwiftUI

public struct HomeActions: Sendable {
    public var play: @Sendable @MainActor () -> Void = {}
    public var openShop: @Sendable @MainActor () -> Void = {}
    public var buyGems: @Sendable @MainActor () -> Void = {}
    public var watchAd: @Sendable @MainActor () async -> Int = { 0 }
    public var openDaily: @Sendable @MainActor () -> Void = {}
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
    
    public init(
        play: @escaping @Sendable @MainActor () -> Void = {},
        openShop: @escaping @Sendable @MainActor () -> Void = {},
        buyGems: @escaping @Sendable @MainActor () -> Void = {},
        watchAd: @escaping @Sendable @MainActor () async -> Int = { 0 },
        openDaily: @escaping @Sendable @MainActor () -> Void = {},
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
        openDailyQuests: @escaping @Sendable @MainActor () -> Void = {}
    ) {
        self.play = play
        self.openShop = openShop
        self.buyGems = buyGems
        self.watchAd = watchAd
        self.openDaily = openDaily
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

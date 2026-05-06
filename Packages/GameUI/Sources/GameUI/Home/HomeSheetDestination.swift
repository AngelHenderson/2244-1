import Foundation

/// Identifies which adaptive sheet HomeView should present.
///
/// Replaces a cluster of separate `@State` booleans so only one of these
/// destinations can be on screen at a time. Sheets/alerts that legitimately
/// layer (boosts, weekly offer, ad bonus intro) keep their own state.
public enum HomeSheetDestination: Hashable, Identifiable, Sendable {
    case leaderboard
    case achievements
    case music
    case shop
    case profile
    case settings
    case themePicker
    case dailyQuests
    case dailyStreaks
    case practice
    case modes
    case feed
    case history
    case friends
    case account
    case subscription
    case reminders
    case widgetPromo
    case yearReview
    case proCoach

    public var id: HomeSheetDestination { self }
}

import SwiftUI
import GameCore

/// Typed inventory of every user-facing surface that should emit a
/// `screen_view` event. Adding a screen here is the single source of truth
/// for analytics names — string drift in views is no longer allowed.
public enum AnalyticsScreen: String, CaseIterable, Sendable {
    // Root surfaces
    case home
    case gameplay
    case customChallengeGameplay = "custom_challenge_gameplay"

    // Onboarding / tutorial
    case howToPlay = "how_to_play"

    // Hub sheets reachable from Home
    case shop
    case dailyClaims = "daily_claims"
    case dailyStreaks = "daily_streaks"
    case dailyQuests = "daily_quests"
    case freeSpin = "free_spin"
    case challengeMode = "challenge_mode"
    case challengeDesigner = "challenge_designer"
    case profile
    case achievements
    case leaderboard
    case settings
    case themePicker = "theme_picker"
    case music = "music_themes"

    // Modal child surfaces
    case pause
    case boosts
    case weeklyOffer = "weekly_offer"
    case rewardedInterstitialIntro = "rewarded_interstitial_intro"
    case reportPlayer = "report_player"
    case slotPicker = "slot_picker"
    case replayExport = "replay_export"
    case replayImport = "replay_import"
    case tilesInfo = "tiles_info"
    case perksInfo = "perks_info"
    case validMovesInfo = "valid_moves_info"
    case playerHistory = "player_history"

    public var eventName: String { "screen_view" }
}

@MainActor
public extension View {
    /// Fires a `screen_view` analytics event with `screen_name` set to
    /// `screen.rawValue` when the view appears. Wires through the
    /// `\.analytics` environment service so production builds use the
    /// configured analytics backend without each screen owning its own
    /// firing logic.
    func trackScreen(_ screen: AnalyticsScreen) -> some View {
        modifier(AnalyticsScreenModifier(screen: screen))
    }
}

@MainActor
private struct AnalyticsScreenModifier: ViewModifier {
    let screen: AnalyticsScreen
    @Environment(\.analytics) private var analytics

    func body(content: Content) -> some View {
        content.onAppear {
            let name = screen.rawValue
            let event = screen.eventName
            Task {
                await analytics.fire(event: event, params: ["screen_name": name])
            }
        }
    }
}

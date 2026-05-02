import Foundation

/// Identifies which user-triggered sheet HybridGameScreen should present.
///
/// Mirrors `HomeSheetDestination`. The auto-triggered surfaces (gift
/// reward, unlock reward, in-game notifications) keep their own
/// `gameStore`-driven bindings because they can fire mid-gameplay even
/// while a user-triggered sheet is open and need their own coordination.
public enum GameplaySheetDestination: Hashable, Identifiable, Sendable {
    case pause
    case shop
    case leaderboard

    public var id: GameplaySheetDestination { self }
}

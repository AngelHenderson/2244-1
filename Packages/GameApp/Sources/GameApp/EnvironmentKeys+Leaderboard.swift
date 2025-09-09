import SwiftUI
import GameServices

public struct LeaderboardServiceKey: EnvironmentKey {
    nonisolated public static var defaultValue: LeaderboardService {
        MainActor.assumeIsolated {
            LeaderboardService()
        }
    }
}

public extension EnvironmentValues {
    var leaderboardService: LeaderboardService {
        get { self[LeaderboardServiceKey.self] }
        set { self[LeaderboardServiceKey.self] = newValue }
    }
}
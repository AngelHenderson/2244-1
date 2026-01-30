import Foundation

public protocol LeaderboardServiceProtocol: Sendable {
    func submit(score: Int64, for leaderboardId: String) async throws
    func loadEntries(for leaderboardId: String, timeScope: LeaderboardTimeScope, limit: Int) async throws -> [LeaderboardServiceEntry]
    func loadLocalPlayerEntry(for leaderboardId: String, timeScope: LeaderboardTimeScope) async throws -> LeaderboardServiceEntry?
}

public enum LeaderboardTimeScope: Int, Sendable {
    case today = 0
    case week = 1
    case allTime = 2
}

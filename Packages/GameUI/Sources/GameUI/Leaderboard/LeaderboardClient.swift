import SwiftUI
import Foundation

public struct LeaderboardClient: Sendable {
    public var authenticate: @Sendable () async throws -> Bool
    public var submitScore: @Sendable (_ score: Int) async throws -> Void
    public var fetchPage: @Sendable (
        _ period: LeaderboardPeriod,
        _ filter: LeaderboardFilter,
        _ cursor: String?,            // backend-defined paging token
        _ pageSize: Int               // suggested 50
    ) async throws -> LeaderboardPage
    public var fetchMyRank: @Sendable (
        _ period: LeaderboardPeriod,
        _ filter: LeaderboardFilter
    ) async throws -> LeaderboardEntry?
    
    public init(
        authenticate: @escaping @Sendable () async throws -> Bool,
        submitScore: @escaping @Sendable (Int) async throws -> Void,
        fetchPage: @escaping @Sendable (LeaderboardPeriod, LeaderboardFilter, String?, Int) async throws -> LeaderboardPage,
        fetchMyRank: @escaping @Sendable (LeaderboardPeriod, LeaderboardFilter) async throws -> LeaderboardEntry?
    ) {
        self.authenticate = authenticate
        self.submitScore = submitScore
        self.fetchPage = fetchPage
        self.fetchMyRank = fetchMyRank
    }
}

public extension LeaderboardClient {
    static let noop = LeaderboardClient(
        authenticate: { true },
        submitScore: { _ in },
        fetchPage: { _, _, _, _ in 
            .init(entries: mockEntries(), myEntry: nil, nextCursor: nil) 
        },
        fetchMyRank: { _, _ in nil }
    )
    
    // Mock data for preview/testing
    private static func mockEntries() -> [LeaderboardEntry] {
        [
            LeaderboardEntry(id: "1", rank: 1, name: "DefenselessMetal49", score: 158432, countryCode: "BD", platform: .ios, highestTile: "873bz"),
            LeaderboardEntry(id: "2", rank: 2, name: "LopingLemming57", score: 145200, countryCode: nil, platform: .ios, highestTile: "873bz"),
            LeaderboardEntry(id: "3", rank: 3, name: "DensePage91", score: 132100, countryCode: "PK", platform: .android, highestTile: "873bz"),
            LeaderboardEntry(id: "4", rank: 4, name: "BrittleBelly111", score: 128900, countryCode: "DE", platform: .ios, highestTile: "218bz"),
            LeaderboardEntry(id: "5", rank: 5, name: "PerfectPirate2198", score: 115600, countryCode: "IN", platform: .ios, highestTile: "27bz"),
            LeaderboardEntry(id: "6", rank: 6, name: "CaramelStamp47", score: 98200, countryCode: "PK", platform: .ios, highestTile: "27bz"),
            LeaderboardEntry(id: "7", rank: 7, name: "Player6362", score: 87650, countryCode: "UZ", platform: .android, highestTile: "13bz"),
            LeaderboardEntry(id: "8", rank: 8, name: "CulturalDerision48", score: 76543, countryCode: "GB", platform: .ios, highestTile: "6bz"),
            LeaderboardEntry(id: "9", rank: 9, name: "KnownOwner26", score: 65432, countryCode: "LB", platform: .android, highestTile: "1bz"),
            LeaderboardEntry(id: "me", rank: 536, name: "Angel Junior711", score: 45200, countryCode: "US", platform: .ios, isMe: true, highestTile: "1an"),
        ]
    }
}

private struct LeaderboardClientKey: EnvironmentKey {
    static let defaultValue: LeaderboardClient = .noop
}

public extension EnvironmentValues {
    var leaderboardClient: LeaderboardClient {
        get { self[LeaderboardClientKey.self] }
        set { self[LeaderboardClientKey.self] = newValue }
    }
}

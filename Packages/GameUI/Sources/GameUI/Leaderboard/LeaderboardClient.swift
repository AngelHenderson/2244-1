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
            let entries = mockEntries()
            return .init(entries: entries, myEntry: entries.last, nextCursor: nil, totalPlayers: 12847)
        },
        fetchMyRank: { _, _ in mockEntries().last }
    )

    // Mock data for preview/testing - uses valid journey milestones in descending order
    private static func mockEntries() -> [LeaderboardEntry] {
        [
            LeaderboardEntry(id: "1", rank: 1, name: "DefenselessMetal49", score: 873000, countryCode: "JP", platform: .ios, highestTile: "873bz"),
            LeaderboardEntry(id: "2", rank: 2, name: "LopingLemming57", score: 654000, countryCode: "BR", platform: .android, highestTile: "506bz"),
            LeaderboardEntry(id: "3", rank: 3, name: "DensePage91", score: 512000, countryCode: "PK", platform: .ios, highestTile: "128by"),
            LeaderboardEntry(id: "4", rank: 4, name: "BrittleBelly111", score: 218000, countryCode: "DE", platform: .android, highestTile: "64bm"),
            LeaderboardEntry(id: "5", rank: 5, name: "PerfectPirate2198", score: 156000, countryCode: "UZ", platform: .ios, highestTile: "8ba"),
            LeaderboardEntry(id: "6", rank: 6, name: "CaramelStamp47", score: 98000, countryCode: "IN", platform: .android, highestTile: "512az"),
            LeaderboardEntry(id: "7", rank: 7, name: "Player6362", score: 75000, countryCode: "FR", platform: .ios, highestTile: "64am"),
            LeaderboardEntry(id: "8", rank: 8, name: "CulturalDerision48", score: 42000, countryCode: "GB", platform: .android, highestTile: "2aa"),
            LeaderboardEntry(id: "9", rank: 9, name: "KnownOwner26", score: 27000, countryCode: "LB", platform: .ios, highestTile: "256z"),
            LeaderboardEntry(id: "10", rank: 10, name: "SwiftCoder99", score: 18000, countryCode: "CA", platform: .android, highestTile: "32m"),
            LeaderboardEntry(id: "11", rank: 11, name: "PixelMaster42", score: 12000, countryCode: "AU", platform: .ios, highestTile: "8g"),
            LeaderboardEntry(id: "12", rank: 12, name: "NeonRacer77", score: 8500, countryCode: "KR", platform: .android, highestTile: "2a"),
            LeaderboardEntry(id: "13", rank: 13, name: "CloudJumper88", score: 6200, countryCode: "MX", platform: .ios, highestTile: "512B"),
            LeaderboardEntry(id: "14", rank: 14, name: "StarGazer2024", score: 4100, countryCode: "IT", platform: .android, highestTile: "64M"),
            LeaderboardEntry(id: "15", rank: 15, name: "ThunderBolt55", score: 2800, countryCode: "ES", platform: .ios, highestTile: "8M"),
            LeaderboardEntry(id: "me", rank: 536, name: "Angel Junior711", score: 1000, countryCode: "US", platform: .ios, isMe: true, highestTile: "2M"),
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

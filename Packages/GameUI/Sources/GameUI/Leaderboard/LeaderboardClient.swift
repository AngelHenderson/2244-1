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
            LeaderboardEntry(id: "1", rank: 1, name: "Alex", score: 158432, countryCode: "US", platform: .ios),
            LeaderboardEntry(id: "2", rank: 2, name: "Sarah", score: 145200, countryCode: "CA", platform: .ios),
            LeaderboardEntry(id: "3", rank: 3, name: "Mike", score: 132100, countryCode: "GB", platform: .android),
            LeaderboardEntry(id: "4", rank: 4, name: "Emma", score: 128900, countryCode: "AU", platform: .ios),
            LeaderboardEntry(id: "5", rank: 5, name: "John", score: 115600, countryCode: "US", platform: .ios),
            LeaderboardEntry(id: "me", rank: 42, name: "You", score: 45200, countryCode: "US", platform: .ios, isMe: true),
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

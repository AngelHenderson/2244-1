import XCTest
@testable import GameUI

final class LeaderboardPerfTests: XCTestCase {
    func testPerfFetchGlobal() async throws {
        let client = LeaderboardClient.mock
        let start = Date()
        _ = try await client.fetchPage(.allTime, .global, nil, 50)
        let end = Date()
        print("PERF_RESULT global: \(end.timeIntervalSince(start))")
    }

    func testPerfFetchCountry() async throws {
        let client = LeaderboardClient.mock
        let start = Date()
        _ = try await client.fetchPage(.allTime, .country, "US", 50)
        let end = Date()
        print("PERF_RESULT country: \(end.timeIntervalSince(start))")
    }
}

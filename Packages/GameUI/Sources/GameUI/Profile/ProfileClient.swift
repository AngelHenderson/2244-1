import SwiftUI

// MARK: - Service Protocol

public struct ProfilePayload {
    public var playerName: String
    public var bestScoreText: String
    public var globalRank: Int
    public var tiers: [TierStat]
    public var friendCode: String
    public var season: SeasonInfo
    public var avatarSystemName: String
    
    public init(
        playerName: String,
        bestScoreText: String,
        globalRank: Int,
        tiers: [TierStat],
        friendCode: String,
        season: SeasonInfo,
        avatarSystemName: String
    ) {
        self.playerName = playerName
        self.bestScoreText = bestScoreText
        self.globalRank = globalRank
        self.tiers = tiers
        self.friendCode = friendCode
        self.season = season
        self.avatarSystemName = avatarSystemName
    }
}

public protocol ProfileClient: Sendable {
    func fetchProfile() async throws -> ProfilePayload
    func updatePlayerName(_ name: String) async throws
    func shareDeepLink(for payload: ProfilePayload) -> URL
}

// MARK: - Environment Key

private struct ProfileClientKey: EnvironmentKey {
    static let defaultValue: any ProfileClient = MockProfileClient()
}

public extension EnvironmentValues {
    var profileClient: ProfileClient {
        get { self[ProfileClientKey.self] }
        set { self[ProfileClientKey.self] = newValue }
    }
}

// MARK: - Mock Implementation

struct MockProfileClient: ProfileClient, Sendable {
    func fetchProfile() async throws -> ProfilePayload {
        // Mirror the screenshot's data
        let left: [TierStat] = [
            .init(key: "K", value: 244, color: .purple, label: "K-Tier Best"),
            .init(key: "B", value: 323, color: .red, label: "B-Tier Best"),
            .init(key: "b", value: 323, color: .yellow, label: "b-Tier Best"),
            .init(key: "d", value: 261, color: .pink, label: "d-Tier Best"),
            .init(key: "f", value: 299, color: .teal, label: "f-Tier Best")
        ]
        let right: [TierStat] = [
            .init(key: "M", value: 395, color: .pink, label: "M-Tier Best"),
            .init(key: "a", value: 287, color: .teal, label: "a-Tier Best"),
            .init(key: "c", value: 275, color: .green, label: "c-Tier Best"),
            .init(key: "e", value: 265, color: .red, label: "e-Tier Best"),
            .init(key: "g", value: 328, color: .yellow, label: "g-Tier Best")
        ]
        return .init(
            playerName: "Angel Junior711",
            bestScoreText: "3,513,812",
            globalRank: 534,
            tiers: left + right,
            friendCode: "AJ711-534",
            season: .init(name: "Season 7", division: "Diamond"),
            avatarSystemName: "pawprint.circle.fill"
        )
    }

    func updatePlayerName(_ name: String) async throws { /* no-op */ }

    func shareDeepLink(for payload: ProfilePayload) -> URL {
        // Replace with your real deep link scheme
        return URL(string: "game2244://profile?id=\(payload.friendCode)")!
    }
}
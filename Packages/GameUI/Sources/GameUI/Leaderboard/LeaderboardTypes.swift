import Foundation

public enum LeaderboardPeriod: String, Codable, CaseIterable, Sendable {
    case today = "Today"
    case week = "This Week"
    case allTime = "All Time"
}

public enum LeaderboardFilter: String, Codable, CaseIterable, Sendable, Identifiable {
    case global = "Global"
    case hallOfFame = "Hall of Fame"
    case country = "US"

    public var id: Self { self }

    public var icon: String {
        switch self {
        case .global: return "globe.americas.fill"
        case .hallOfFame: return "crown.fill"
        case .country: return "flag.fill"
        }
    }
}

public enum Platform: String, Codable, Sendable {
    case ios, android, unknown
}

public struct LeaderboardEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: String            // player id
    public var rank: Int
    public var name: String
    public var score: Int
    public var countryCode: String?  // "US", "BD", etc.
    public var platform: Platform
    public var isMe: Bool
    public var avatarURL: String?    // Optional avatar URL
    public var highestTile: String?  // "1an", "873bz", etc.
    
    public init(
        id: String,
        rank: Int,
        name: String,
        score: Int,
        countryCode: String? = nil,
        platform: Platform = .ios,
        isMe: Bool = false,
        avatarURL: String? = nil,
        highestTile: String? = nil
    ) {
        self.id = id
        self.rank = rank
        self.name = name
        self.score = score
        self.countryCode = countryCode
        self.platform = platform
        self.isMe = isMe
        self.avatarURL = avatarURL
        self.highestTile = highestTile
    }
}

public struct LeaderboardPage: Codable, Sendable {
    public var entries: [LeaderboardEntry]
    public var myEntry: LeaderboardEntry?
    public var nextCursor: String?
    public var totalPlayers: Int?
    
    public init(
        entries: [LeaderboardEntry],
        myEntry: LeaderboardEntry? = nil,
        nextCursor: String? = nil,
        totalPlayers: Int? = nil
    ) {
        self.entries = entries
        self.myEntry = myEntry
        self.nextCursor = nextCursor
        self.totalPlayers = totalPlayers
    }
}

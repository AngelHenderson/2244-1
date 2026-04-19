import Foundation

public enum LeaderboardPeriod: String, Codable, CaseIterable, Sendable {
    case today = "Today"
    case week = "This Week"
    case allTime = "All Time"
}

public enum LeaderboardFilter: String, Codable, CaseIterable, Sendable, Identifiable {
    case global = "Global"
    case hallOfFame = "Hall of Fame"
    case country = "Country"

    public var id: Self { self }

    public var icon: String {
        switch self {
        case .global: return "globe"
        case .hallOfFame: return "infinity"
        case .country: return "flag.fill"
        }
    }

    public var title: String {
        switch self {
        case .global: return "Global"
        case .hallOfFame: return "Hall of Fame"
        case .country:
            let code = UserLeaderboardData.currentCountry
            if code.uppercased() == "US" { return "US" }
            if code.uppercased() == "GB" { return "UK" }
            // Try localized name in current locale, then English, then fall back to code
            return Locale.current.localizedString(forRegionCode: code) 
                ?? Locale(identifier: "en_US").localizedString(forRegionCode: code)
                ?? code
        }
    }

    public var countryCode: String? {
        switch self {
        case .country: return UserLeaderboardData.currentCountry
        default: return nil
        }
    }

    /// Returns available filters based on user's country
    public static func availableFilters(for countryCode: String) -> [LeaderboardFilter] {
        return [.global, .hallOfFame, .country]
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

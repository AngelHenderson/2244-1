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
    case countryUK = "UK"
    case countryCA = "Canada"
    case countryAU = "Australia"
    case countryDE = "Germany"
    case countryFR = "France"
    case countryJP = "Japan"
    case countryIN = "India"
    case countryBR = "Brazil"
    case countryMX = "Mexico"

    public var id: Self { self }

    public var icon: String {
        switch self {
        case .global: return "globe.americas.fill"
        case .hallOfFame: return "crown.fill"
        case .country: return "flag.fill"
        case .countryUK: return "flag.fill"
        case .countryCA: return "flag.fill"
        case .countryAU: return "flag.fill"
        case .countryDE: return "flag.fill"
        case .countryFR: return "flag.fill"
        case .countryJP: return "flag.fill"
        case .countryIN: return "flag.fill"
        case .countryBR: return "flag.fill"
        case .countryMX: return "flag.fill"
        }
    }

    public var countryCode: String? {
        switch self {
        case .country: return "US"
        case .countryUK: return "GB"
        case .countryCA: return "CA"
        case .countryAU: return "AU"
        case .countryDE: return "DE"
        case .countryFR: return "FR"
        case .countryJP: return "JP"
        case .countryIN: return "IN"
        case .countryBR: return "BR"
        case .countryMX: return "MX"
        default: return nil
        }
    }

    /// Returns available filters based on user's country
    public static func availableFilters(for countryCode: String) -> [LeaderboardFilter] {
        switch countryCode {
        case "US":
            return [.global, .hallOfFame, .country]
        case "GB":
            return [.global, .hallOfFame, .countryUK]
        case "CA":
            return [.global, .hallOfFame, .countryCA]
        case "AU":
            return [.global, .hallOfFame, .countryAU]
        case "DE":
            return [.global, .hallOfFame, .countryDE]
        case "FR":
            return [.global, .hallOfFame, .countryFR]
        case "JP":
            return [.global, .hallOfFame, .countryJP]
        case "IN":
            return [.global, .hallOfFame, .countryIN]
        case "BR":
            return [.global, .hallOfFame, .countryBR]
        case "MX":
            return [.global, .hallOfFame, .countryMX]
        default:
            return [.global, .hallOfFame]
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

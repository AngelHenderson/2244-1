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
    case countryAF = "Afghanistan"
    case countryAL = "Albania"
    case countryDZ = "Algeria"
    case countryCN = "China"
    case countryKR = "South Korea"
    case countryIT = "Italy"
    case countryES = "Spain"
    case countryNL = "Netherlands"
    case countryCH = "Switzerland"
    case countryNO = "Norway"
    case countryDK = "Denmark"
    case countryFI = "Finland"
    case countryPL = "Poland"
    case countryBE = "Belgium"
    case countrySE = "Sweden"
    case countryAT = "Austria"
    case countryIE = "Ireland"
    case countryPT = "Portugal"
    case countryGR = "Greece"
    case countryCZ = "Czechia"
    case countryRO = "Romania"
    case countryMY = "Malaysia"
    case countryNZ = "New Zealand"
    case countryHU = "Hungary"
    case countryTH = "Thailand"
    case countryAE = "UAE"
    case countryPH = "Philippines"
    case countryAD = "Andorra"
    case countryID = "Indonesia"
    case countryZA = "South Africa"
    case countryKE = "Kenya"
    case countryFJ = "Fiji"
    case countryVN = "Vietnam"
    case countryCW = "Curacao"
    case countryVE = "Venezuela"
    case countryAZ = "Azerbaijan"
    case countryKZ = "Kazakhstan"
    case countryTJ = "Tajikistan"
    case countryNU = "Niue"
    case countryKG = "Kyrgyzstan"
    case countryIS = "Iceland"
    case countrySK = "Slovakia"
    case countryUZ = "Uzbekistan"
    case countryPK = "Pakistan"
    case countryUA = "Ukraine"
    case countryMG = "Madagascar"
    case countryIQ = "Iraq"

    public var id: Self { self }

    public var icon: String {
        switch self {
        case .global: return "globe"
        case .hallOfFame: return "infinity"
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
        case .countryAF: return "flag.fill"
        case .countryAL: return "flag.fill"
        case .countryDZ: return "flag.fill"
        case .countryCN: return "flag.fill"
        case .countryKR: return "flag.fill"
        case .countryIT: return "flag.fill"
        case .countryES: return "flag.fill"
        case .countryNL: return "flag.fill"
        case .countryCH: return "flag.fill"
        case .countryNO: return "flag.fill"
        case .countryDK: return "flag.fill"
        case .countryFI: return "flag.fill"
        case .countryPL: return "flag.fill"
        case .countryBE: return "flag.fill"
        case .countrySE: return "flag.fill"
        case .countryAT: return "flag.fill"
        case .countryIE: return "flag.fill"
        case .countryPT: return "flag.fill"
        case .countryGR: return "flag.fill"
        case .countryCZ: return "flag.fill"
        case .countryRO: return "flag.fill"
        case .countryMY: return "flag.fill"
        case .countryNZ: return "flag.fill"
        case .countryHU: return "flag.fill"
        case .countryTH: return "flag.fill"
        case .countryAE: return "flag.fill"
        case .countryPH: return "flag.fill"
        case .countryAD: return "flag.fill"
        case .countryID: return "flag.fill"
        case .countryZA: return "flag.fill"
        case .countryKE: return "flag.fill"
        case .countryFJ: return "flag.fill"
        case .countryVN: return "flag.fill"
        case .countryCW: return "flag.fill"
        case .countryVE: return "flag.fill"
        case .countryAZ: return "flag.fill"
        case .countryKZ: return "flag.fill"
        case .countryTJ: return "flag.fill"
        case .countryNU: return "flag.fill"
        case .countryKG: return "flag.fill"
        case .countryIS: return "flag.fill"
        case .countrySK: return "flag.fill"
        case .countryUZ: return "flag.fill"
        case .countryPK: return "flag.fill"
        case .countryUA: return "flag.fill"
        case .countryMG: return "flag.fill"
        case .countryIQ: return "flag.fill"
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
        case .countryAF: return "AF"
        case .countryAL: return "AL"
        case .countryDZ: return "DZ"
        case .countryCN: return "CN"
        case .countryKR: return "KR"
        case .countryIT: return "IT"
        case .countryES: return "ES"
        case .countryNL: return "NL"
        case .countryCH: return "CH"
        case .countryNO: return "NO"
        case .countryDK: return "DK"
        case .countryFI: return "FI"
        case .countryPL: return "PL"
        case .countryBE: return "BE"
        case .countrySE: return "SE"
        case .countryAT: return "AT"
        case .countryIE: return "IE"
        case .countryPT: return "PT"
        case .countryGR: return "GR"
        case .countryCZ: return "CZ"
        case .countryRO: return "RO"
        case .countryMY: return "MY"
        case .countryNZ: return "NZ"
        case .countryHU: return "HU"
        case .countryTH: return "TH"
        case .countryAE: return "AE"
        case .countryPH: return "PH"
        case .countryAD: return "AD"
        case .countryID: return "ID"
        case .countryZA: return "ZA"
        case .countryKE: return "KE"
        case .countryFJ: return "FJ"
        case .countryVN: return "VN"
        case .countryCW: return "CW"
        case .countryVE: return "VE"
        case .countryAZ: return "AZ"
        case .countryKZ: return "KZ"
        case .countryTJ: return "TJ"
        case .countryNU: return "NU"
        case .countryKG: return "KG"
        case .countryIS: return "IS"
        case .countrySK: return "SK"
        case .countryUZ: return "UZ"
        case .countryPK: return "PK"
        case .countryUA: return "UA"
        case .countryMG: return "MG"
        case .countryIQ: return "IQ"
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
        case "AF":
            return [.global, .hallOfFame, .countryAF]
        case "AL":
            return [.global, .hallOfFame, .countryAL]
        case "DZ":
            return [.global, .hallOfFame, .countryDZ]
        case "CN":
            return [.global, .hallOfFame, .countryCN]
        case "KR":
            return [.global, .hallOfFame, .countryKR]
        case "IT":
            return [.global, .hallOfFame, .countryIT]
        case "ES":
            return [.global, .hallOfFame, .countryES]
        case "NL":
            return [.global, .hallOfFame, .countryNL]
        case "CH":
            return [.global, .hallOfFame, .countryCH]
        case "NO":
            return [.global, .hallOfFame, .countryNO]
        case "DK":
            return [.global, .hallOfFame, .countryDK]
        case "FI":
            return [.global, .hallOfFame, .countryFI]
        case "PL":
            return [.global, .hallOfFame, .countryPL]
        case "BE":
            return [.global, .hallOfFame, .countryBE]
        case "SE":
            return [.global, .hallOfFame, .countrySE]
        case "AT":
            return [.global, .hallOfFame, .countryAT]
        case "IE":
            return [.global, .hallOfFame, .countryIE]
        case "PT":
            return [.global, .hallOfFame, .countryPT]
        case "GR":
            return [.global, .hallOfFame, .countryGR]
        case "CZ":
            return [.global, .hallOfFame, .countryCZ]
        case "RO":
            return [.global, .hallOfFame, .countryRO]
        case "MY":
            return [.global, .hallOfFame, .countryMY]
        case "NZ":
            return [.global, .hallOfFame, .countryNZ]
        case "HU":
            return [.global, .hallOfFame, .countryHU]
        case "TH":
            return [.global, .hallOfFame, .countryTH]
        case "AE":
            return [.global, .hallOfFame, .countryAE]
        case "PH":
            return [.global, .hallOfFame, .countryPH]
        case "AD":
            return [.global, .hallOfFame, .countryAD]
        case "ID":
            return [.global, .hallOfFame, .countryID]
        case "ZA":
            return [.global, .hallOfFame, .countryZA]
        case "KE":
            return [.global, .hallOfFame, .countryKE]
        case "FJ":
            return [.global, .hallOfFame, .countryFJ]
        case "VN":
            return [.global, .hallOfFame, .countryVN]
        case "CW":
            return [.global, .hallOfFame, .countryCW]
        case "VE":
            return [.global, .hallOfFame, .countryVE]
        case "AZ":
            return [.global, .hallOfFame, .countryAZ]
        case "KZ":
            return [.global, .hallOfFame, .countryKZ]
        case "TJ":
            return [.global, .hallOfFame, .countryTJ]
        case "NU":
            return [.global, .hallOfFame, .countryNU]
        case "KG":
            return [.global, .hallOfFame, .countryKG]
        case "IS":
            return [.global, .hallOfFame, .countryIS]
        case "SK":
            return [.global, .hallOfFame, .countrySK]
        case "UZ":
            return [.global, .hallOfFame, .countryUZ]
        case "PK":
            return [.global, .hallOfFame, .countryPK]
        case "UA":
            return [.global, .hallOfFame, .countryUA]
        case "MG":
            return [.global, .hallOfFame, .countryMG]
        case "IQ":
            return [.global, .hallOfFame, .countryIQ]
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

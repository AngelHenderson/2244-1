import SwiftUI
import Foundation

// MARK: - User Milestone Storage (for mock leaderboard)
public enum UserLeaderboardData {
    /// The user's current highest milestone (e.g., "16M", "33M", "1B")
    /// Reads from UserDefaults "leaderboard.milestone" (set by GameStore)
    public static var currentMilestone: String {
        UserDefaults.standard.string(forKey: "leaderboard.milestone") ?? "2"
    }

    /// Calculate global rank for a specific milestone (for immediate updates)
    public static func globalRank(for milestone: String) -> Int {
        return calculateGlobalRank(for: milestone)
    }

    /// The user's display name
    /// Reads from UserDefaults "playerName" (set by profile)
    public static var playerName: String {
        UserDefaults.standard.string(forKey: "playerName") ?? "Player"
    }

    /// The user's avatar ID
    /// Reads from UserDefaults "avatarSystemName" (set by profile)
    public static var avatarID: String {
        UserDefaults.standard.string(forKey: "avatarSystemName") ?? "avatar-shiba-dog"
    }

    /// The user's country code (e.g., "US", "GB")
    /// Reads from UserDefaults "profileCountryCode" (set by profile), falls back to device locale
    public static var currentCountry: String {
        UserDefaults.standard.string(forKey: "profileCountryCode") ?? Locale.current.region?.identifier ?? "US"
    }

    /// The user's global rank based on their current milestone
    /// Uses the same bracket-based calculation as ProfileClient for consistency
    public static var globalRank: Int {
        return calculateGlobalRank(for: currentMilestone)
    }

    /// Calculate global rank for any milestone string
    private static func calculateGlobalRank(for userMilestone: String) -> Int {
        // Dynamic global rank calculation based on actual country data aggregation
        // This counts how many players across all countries have a better milestone than the user
        let betterPlayers = MockLeaderboardData.countAllPlayersBetterThan(userMilestone: userMilestone)

        // User's rank = number of players better than them + 1
        return betterPlayers + 1
    }
}

public struct LeaderboardClient: Sendable {
    public var authenticate: @Sendable () async throws -> Bool
    /// Submit high score to global leaderboard
    public var submitScore: @Sendable (_ score: Int) async throws -> Void
    /// Submit infinity count to Hall of Fame leaderboard
    public var submitInfinityCount: @Sendable (_ infinityCount: Int) async throws -> Void
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
        submitInfinityCount: @escaping @Sendable (Int) async throws -> Void = { _ in },
        fetchPage: @escaping @Sendable (LeaderboardPeriod, LeaderboardFilter, String?, Int) async throws -> LeaderboardPage,
        fetchMyRank: @escaping @Sendable (LeaderboardPeriod, LeaderboardFilter) async throws -> LeaderboardEntry?
    ) {
        self.authenticate = authenticate
        self.submitScore = submitScore
        self.submitInfinityCount = submitInfinityCount
        self.fetchPage = fetchPage
        self.fetchMyRank = fetchMyRank
    }
}

// MARK: - Daily Progression System
// Players progress through milestones daily. The leaderboard updates at midnight.

public enum MockLeaderboardData {
    // Reference date for calculating day offset (progression "just started" on Jan 20, 2026)
    static let referenceDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 20
        return Calendar.current.date(from: components) ?? Date()
    }()

    // Calculate days since reference date for progression
    // Leaderboard only updates at midnight - uses start of today, not current time
    static var daysSinceReference: Int {
        let calendar = Calendar.current
        // Get start of today (midnight) to ensure leaderboard only changes at midnight
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfReference = calendar.startOfDay(for: referenceDate)
        let days = calendar.dateComponents([.day], from: startOfReference, to: startOfToday).day ?? 0
        return max(0, days)
    }

    // Current hour of day (0-23) for intraday score 0 attrition
    static var currentHourOfDay: Int {
        Calendar.current.component(.hour, from: Date())
    }

    // Calculate score 0 player count with compounding daily attrition
    // Each day, 75% of score 0 players progress, leaving 25% at end of day
    // This compounds: Day 1 end = 25%, Day 2 end = 6.25%, Day 3 end = 1.5625%, etc.
    // Within each day, attrition happens linearly from start to end
    //
    // Example with 50,000 base score 0 players:
    // - Day 1, 12:00 AM: 50,000
    // - Day 1, 11:59 PM: 12,500 (25%)
    // - Day 2, 11:59 PM: 3,125 (6.25%)
    // - Day 3, 11:59 PM: 781 (1.5625%)
    static func scoreZeroPlayersAtCurrentTime(baseCount: Int) -> Int {
        let days = daysSinceReference
        let hour = Double(currentHourOfDay)

        // Calculate score 0 players at start and end of current day
        let dailyRetention = 0.25  // 25% remain at end of each day
        let startOfDayMultiplier = pow(dailyRetention, Double(days))
        let endOfDayMultiplier = pow(dailyRetention, Double(days + 1))

        // Linear interpolation within the day based on current hour
        let hourProgress = hour / 24.0
        let currentMultiplier = startOfDayMultiplier - (startOfDayMultiplier - endOfDayMultiplier) * hourProgress

        return max(1, Int(Double(baseCount) * currentMultiplier))
    }

    // All milestone tiers in order (lowest to highest) - generated from doubling sequence
    static let allMilestones: [String] = [
        // Score 0 and lowest milestones (2-512)
        "0", "2", "4", "8", "16", "32", "64", "128", "256", "512",
        // Raw numbers and K-tier (thousands)
        "1024", "2048", "4096", "8192", "16K", "32K", "65K", "131K", "262K", "524K",
        // M-tier (millions)
        "1M", "2M", "4M", "8M", "16M", "33M", "67M", "134M", "268M", "536M",
        "1B", "2B", "4B", "8B", "17B", "34B", "68B", "137B", "274B", "549B",
        "1a", "2a", "4a", "8a", "17a", "35a", "70a", "140a", "281a", "562a",
        "1b", "2b", "4b", "9b", "18b", "36b", "72b", "144b", "288b", "576b",
        "1c", "2c", "4c", "9c", "18c", "36c", "73c", "147c", "295c", "590c",
        "1d", "2d", "4d", "9d", "18d", "37d", "75d", "151d", "302d", "604d",
        "1e", "2e", "4e", "9e", "19e", "38e", "77e", "154e", "309e", "618e",
        "1f", "2f", "4f", "9f", "19f", "39f", "79f", "158f", "316f", "633f",
        "1g", "2g", "5g", "10g", "20g", "40g", "81g", "162g", "324g", "649g",
        "1h", "2h", "5h", "10h", "20h", "41h", "83h", "166h", "332h", "664h",
        "1i", "2i", "5i", "10i", "21i", "42i", "85i", "170i", "340i", "680i",
        "1j", "2j", "5j", "10j", "21j", "43j", "87j", "174j", "348j", "696j",
        "1k", "2k", "5k", "11k", "22k", "44k", "89k", "178k", "356k", "713k",
        "1l", "2l", "5l", "11l", "22l", "45l", "91l", "182l", "365l", "730l",
        "1m", "2m", "5m", "11m", "23m", "46m", "93m", "187m", "374m", "748m",
        "1n", "2n", "5n", "11n", "23n", "47n", "95n", "191n", "383n", "766n",
        "1o", "3o", "6o", "12o", "24o", "49o", "98o", "196o", "392o", "784o",
        "1p", "3p", "6p", "12p", "25p", "50p", "100p", "200p", "401p", "803p",
        "1q", "3q", "6q", "12q", "25q", "51q", "102q", "205q", "411q", "822q",
        "1r", "3r", "6r", "13r", "26r", "52r", "105r", "210r", "421r", "842r",
        "1s", "3s", "6s", "13s", "26s", "53s", "107s", "215s", "431s", "862s",
        "1t", "3t", "6t", "13t", "27t", "55t", "110t", "220t", "441t", "883t",
        "1u", "3u", "7u", "14u", "28u", "56u", "113u", "226u", "452u", "904u",
        "1v", "3v", "7v", "14v", "28v", "57v", "115v", "231v", "463v", "926v",
        "1w", "3w", "7w", "14w", "29w", "59w", "118w", "237w", "474w", "948w",
        "1x", "3x", "7x", "15x", "30x", "60x", "121x", "242x", "485x", "971x",
        "1y", "3y", "7y", "15y", "31y", "62y", "124y", "248y", "497y", "994y",
        "1z", "3z", "7z", "15z", "31z", "63z", "127z", "254z", "509z", "1aa",
        "2aa", "4aa", "8aa", "16aa", "32aa", "65aa", "130aa", "260aa", "521aa", "1ab",
        "2ab", "4ab", "8ab", "16ab", "33ab", "66ab", "133ab", "266ab", "533ab", "1ac",
        "2ac", "4ac", "8ac", "17ac", "34ac", "68ac", "136ac", "273ac", "546ac", "1ad",
        "2ad", "4ad", "8ad", "17ad", "34ad", "69ad", "139ad", "279ad", "559ad", "1ae",
        "2ae", "4ae", "8ae", "17ae", "35ae", "71ae", "143ae", "286ae", "573ae", "1af",
        "2af", "4af", "9af", "18af", "36af", "73af", "146af", "293af", "587af", "1ag",
        "2ag", "4ag", "9ag", "18ag", "37ag", "75ag", "150ag", "300ag", "601ag", "1ah",
        "2ah", "4ah", "9ah", "19ah", "38ah", "76ah", "153ah", "307ah", "615ah", "1ai",
        "2ai", "4ai", "9ai", "19ai", "39ai", "78ai", "157ai", "315ai", "630ai", "1aj",
        "2aj", "5aj", "10aj", "20aj", "40aj", "80aj", "161aj", "322aj", "645aj", "1ak",
        "2ak", "5ak", "10ak", "20ak", "41ak", "82ak", "165ak", "330ak", "661ak", "1al",
        "2al", "5al", "10al", "21al", "42al", "84al", "169al", "338al", "676al", "1am",
        "2am", "5am", "10am", "21am", "43am", "86am", "173am", "346am", "693am", "1an",
        "2an", "5an", "11an", "22an", "44an", "88an", "177an", "354an", "709an", "1ao",
        "2ao", "5ao", "11ao", "22ao", "45ao", "90ao", "181ao", "363ao", "726ao", "1ap",
        "2ap", "5ap", "11ap", "23ap", "46ap", "93ap", "186ap", "372ap", "744ap", "1aq",
        "2aq", "5aq", "11aq", "23aq", "47aq", "95aq", "190aq", "381aq", "762aq", "1ar",
        "3ar", "6ar", "12ar", "24ar", "48ar", "97ar", "195ar", "390ar", "780ar", "1as",
        "3as", "6as", "12as", "24as", "49as", "99as", "199as", "399as", "799as", "1at",
        "3at", "6at", "12at", "25at", "51at", "102at", "204at", "409at", "818at", "1au",
        "3au", "6au", "13au", "26au", "52au", "105au", "209au", "419au", "837au", "1av",
        "3av", "6av", "13av", "27av", "54av", "107av", "214av", "429av", "858av", "1aw",
        "3aw", "6aw", "13aw", "27aw", "55aw", "110aw", "220aw", "439aw", "878aw", "1ax",
        "3ax", "7ax", "14ax", "28ax", "56ax", "112ax", "224ax", "449ax", "899ax", "1ay",
        "3ay", "7ay", "14ay", "28ay", "57ay", "115ay", "230ay", "460ay", "921ay", "1az",
        "3az", "7az", "14az", "29az", "58az", "117az", "235az", "471az", "943az", "1ba",
        "3ba", "7ba", "15ba", "30ba", "60ba", "120ba", "241ba", "483ba", "966ba", "1bb",
        "3bb", "7bb", "15bb", "30bb", "61bb", "123bb", "247bb", "494bb", "989bb", "1bc",
        "3bc", "7bc", "15bc", "31bc", "63bc", "126bc", "253bc", "506bc", "1bd",
        "2bd", "4bd", "8bd", "16bd", "32bd", "64bd", "129bd", "259bd", "518bd", "1be",
        "2be", "4be", "8be", "16be", "33be", "66be", "132be", "265be", "531be", "1bf",
        "2bf", "4bf", "8bf", "16bf", "33bf", "67bf", "135bf", "271bf", "543bf", "1bg",
        "2bg", "4bg", "8bg", "17bg", "34bg", "69bg", "139bg", "278bg", "556bg", "1bh",
        "2bh", "4bh", "8bh", "17bh", "35bh", "71bh", "142bh", "285bh", "570bh", "1bi",
        "2bi", "4bi", "9bi", "18bi", "36bi", "72bi", "145bi", "291bi", "583bi", "1bj",
        "2bj", "4bj", "9bj", "18bj", "37bj", "74bj", "149bj", "299bj", "598bj", "1bk",
        "2bk", "4bk", "9bk", "19bk", "38bk", "76bk", "153bk", "306bk", "612bk", "1bl",
        "2bl", "4bl", "9bl", "19bl", "39bl", "78bl", "156bl", "313bl", "627bl", "1bm",
        "2bm", "5bm", "10bm", "20bm", "40bm", "80bm", "160bm", "321bm", "642bm", "1bn",
        "2bn", "5bn", "10bn", "20bn", "41bn", "82bn", "164bn", "328bn", "657bn", "1bo",
        "2bo", "5bo", "10bo", "21bo", "42bo", "84bo", "168bo", "336bo", "673bo", "1bp",
        "2bp", "5bp", "10bp", "21bp", "43bp", "86bp", "172bp", "344bp", "689bp", "1bq",
        "2bq", "5bq", "11bq", "22bq", "44bq", "88bq", "176bq", "353bq", "706bq", "1br",
        "2br", "5br", "11br", "22br", "45br", "90br", "180br", "361br", "722br", "1bs",
        "2bs", "5bs", "11bs", "23bs", "46bs", "92bs", "185bs", "370bs", "740bs", "1bt",
        "2bt", "5bt", "11bt", "23bt", "47bt", "94bt", "189bt", "379bt", "758bt", "1bu",
        "3bu", "6bu", "12bu", "24bu", "48bu", "97bu", "194bu", "388bu", "776bu", "1bv",
        "3bv", "6bv", "12bv", "24bv", "49bv", "99bv", "198bv", "397bv", "794bv", "1bw",
        "3bw", "6bw", "12bw", "25bw", "50bw", "101bw", "203bw", "406bw", "813bw", "1bx",
        "3bx", "6bx", "13bx", "26bx", "52bx", "104bx", "208bx", "416bx", "833bx", "1by",
        "3by", "6by", "13by", "26by", "53by", "106by", "213by", "426by", "853by", "1bz",
        "3bz", "6bz", "13bz", "27bz", "54bz", "109bz", "218bz", "436bz", "873bz"
    ]

    /// Searchable player data for compare view - generated from actual leaderboard data
    public struct SearchablePlayer: Identifiable {
        public let id: String
        public let name: String
        public let code: String
        public let countryCode: String
        public let milestone: String
    }

    /// Generate all searchable players from leaderboard data with codes
    public static func allSearchablePlayers() -> [SearchablePlayer] {
        let day = daysSinceReference
        var players: [SearchablePlayer] = []
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let digits = Array("0123456789")

        // Helper to generate alphanumeric code from seed
        func generateCode(seed: Int) -> String {
            func char(at pos: Int) -> Character {
                let charSeed = seed * (pos + 1) * 11
                let useDigit = (charSeed % 3) == 0
                if useDigit {
                    return digits[(charSeed / 3) % 10]
                } else {
                    return letters[(charSeed / 2) % 26]
                }
            }
            return "\(char(at: 0))\(char(at: 1))\(char(at: 2))-\(char(at: 3))\(char(at: 4))\(char(at: 5))"
        }

        // Country configurations: (milestones, names, countrySeed, countryCode)
        let countryConfigs: [(milestones: [String], names: [String], seed: Int, code: String)] = [
            (LeaderboardClient.usPlayerMilestones, usNames, 0, "US"),
            (LeaderboardClient.ukPlayerMilestones, ukNames, 5000, "GB"),
            (LeaderboardClient.canadaPlayerMilestones, canadaNames, 10000, "CA"),
            (LeaderboardClient.australiaPlayerMilestones, australiaNames, 15000, "AU"),
            (LeaderboardClient.germanyPlayerMilestones, germanyNames, 20000, "DE"),
            (LeaderboardClient.francePlayerMilestones, franceNames, 25000, "FR"),
            (LeaderboardClient.japanPlayerMilestones, japanNames, 30000, "JP"),
            (LeaderboardClient.indiaPlayerMilestones, indiaNames, 35000, "IN"),
            (LeaderboardClient.brazilPlayerMilestones, brazilNames, 40000, "BR"),
            (LeaderboardClient.mexicoPlayerMilestones, mexicoNames, 45000, "MX"),
            (LeaderboardClient.afghanistanPlayerMilestones, afghanistanNames, 50000, "AF"),
            (LeaderboardClient.albaniaPlayerMilestones, albaniaNames, 55000, "AL"),
            (LeaderboardClient.algeriaPlayerMilestones, algeriaNames, 60000, "DZ"),
            (LeaderboardClient.chinaPlayerMilestones, chinaNames, 65000, "CN"),
            (LeaderboardClient.southKoreaPlayerMilestones, southKoreaNames, 70000, "KR"),
            (LeaderboardClient.italyPlayerMilestones, italyNames, 75000, "IT"),
            (LeaderboardClient.spainPlayerMilestones, spainNames, 80000, "ES"),
            (LeaderboardClient.netherlandsPlayerMilestones, netherlandsNames, 85000, "NL"),
            (LeaderboardClient.switzerlandPlayerMilestones, switzerlandNames, 90000, "CH"),
            (LeaderboardClient.norwayPlayerMilestones, norwayNames, 95000, "NO"),
            (LeaderboardClient.denmarkPlayerMilestones, denmarkNames, 100000, "DK"),
            (LeaderboardClient.finlandPlayerMilestones, finlandNames, 105000, "FI"),
            (LeaderboardClient.polandPlayerMilestones, polandNames, 110000, "PL"),
            (LeaderboardClient.belgiumPlayerMilestones, belgiumNames, 115000, "BE"),
            (LeaderboardClient.swedenPlayerMilestones, swedenNames, 120000, "SE"),
            (LeaderboardClient.austriaPlayerMilestones, austriaNames, 125000, "AT"),
            (LeaderboardClient.irelandPlayerMilestones, irelandNames, 130000, "IE"),
            (LeaderboardClient.portugalPlayerMilestones, portugalNames, 135000, "PT"),
            (LeaderboardClient.greecePlayerMilestones, greeceNames, 140000, "GR"),
            (LeaderboardClient.czechiaPlayerMilestones, czechiaNames, 145000, "CZ"),
            (LeaderboardClient.romaniaPlayerMilestones, romaniaNames, 150000, "RO"),
            (LeaderboardClient.malaysiaPlayerMilestones, malaysiaNames, 155000, "MY"),
            (LeaderboardClient.newZealandPlayerMilestones, newZealandNames, 160000, "NZ"),
            (LeaderboardClient.hungaryPlayerMilestones, hungaryNames, 165000, "HU"),
            (LeaderboardClient.thailandPlayerMilestones, thailandNames, 170000, "TH"),
            (LeaderboardClient.uaePlayerMilestones, uaeNames, 175000, "AE"),
            (LeaderboardClient.philippinesPlayerMilestones, philippinesNames, 180000, "PH"),
            (LeaderboardClient.andorraPlayerMilestones, MockLeaderboardData.andorraNames, 185000, "AD"),
            (LeaderboardClient.indonesiaPlayerMilestones, MockLeaderboardData.indonesiaNames, 190000, "ID"),
            (LeaderboardClient.southAfricaPlayerMilestones, MockLeaderboardData.southAfricaNames, 195000, "ZA"),
            (LeaderboardClient.kenyaPlayerMilestones, MockLeaderboardData.kenyaNames, 200000, "KE"),
            (LeaderboardClient.fijiPlayerMilestones, MockLeaderboardData.fijiNames, 205000, "FJ")
        ]

        for config in countryConfigs {
            for i in 0..<min(150, config.milestones.count) {
                let baseMilestone = config.milestones[i]
                let name = nameForPlayer(index: i, names: config.names, countrySeed: config.seed, day: day)
                let progressedMilestone = milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + config.seed, day: day)
                let codeSeed = (i + 1) * 7 + config.seed + 13

                players.append(SearchablePlayer(
                    id: "\(config.code.lowercased())_\(i)",
                    name: name,
                    code: generateCode(seed: codeSeed),
                    countryCode: config.code,
                    milestone: progressedMilestone
                ))
            }
        }

        return players.sorted { $0.code < $1.code }
    }

    // Normalize invalid milestone entries to valid ones
    static func normalizeMilestone(_ milestone: String) -> String {
        let invalidToValid: [String: String] = [
            // Raw numbers (thousands tier)
            "4k": "4096",
            "8k": "8192",
            // Uppercase K (thousands tier)
            "6k": "16K",
            "16k": "16K",
            "32k": "32K",
            "64k": "65K",
            "65k": "65K",
            "128k": "131K",
            "131k": "131K",
            "256k": "262K",
            "262k": "262K",
            "512k": "524K",
            "524k": "524K",
            // Letter tier k corrections
            "3k": "356k",
            "368k": "356k",
            "12k": "22k",
            "184k": "178k",
            "380k": "713k",
            // Other letter tier mappings
            "10k": "10ak",
            "13k": "13t",
            "21k": "21al",
            "23k": "23m",
            "24k": "24o",
            "25k": "25p",
            "26k": "26s",
            "43k": "43j",
            "46k": "46m",
            "47k": "47n",
            "49k": "49o",
            "52k": "52r",
            "86k": "86am",
            "92k": "92bs",
            "95k": "95n",
            "98k": "98o",
            "101k": "101bw",
            "104k": "104au",
            "172k": "172bp",
            "190k": "190aq",
            "196k": "196o",
            "202k": "200p",
            "208k": "208bx",
            "332k": "332h",
            "344k": "345bp",
            "392k": "392o",
            "404k": "407bw",
            "416k": "416bx",
            "440k": "441t",
            // M-tier (millions) corrections
            "3M": "3o",
            "5M": "5g",
            "6M": "67M",
            "7M": "7x",
            "9M": "9c",
            "10M": "10g",
            "12M": "12o",
            "15M": "15x",
            "17M": "16M",
            "32M": "33M",
            "64M": "67M",
            "65M": "67M",
            "128M": "134M",
            "131M": "134M",
            "256M": "268M",
            "262M": "268M",
            "512M": "536M",
            "524M": "536M"
        ]
        return invalidToValid[milestone] ?? milestone
    }

    public static let globalNames = [
        "DefenselessMetal113090", "LopingLemming366775", "DensePage606454", "BrittleBelly378166", "PerfectPirate002198",
        "CaramelStamp540035", "Player006362", "CulturalDerision125825", "KnownOwner816617", "SwiftCoder159607",
        "PixelMaster748740", "NeonRacer607539", "CloudJumper689506", "StarGazer002024", "ThunderBolt507614",
        "CryptoKing712740", "MidnightOwl188137", "SolarFlare036196", "OceanWave878869", "MountainPeak660972",
        "DesertStorm875175", "JungleCat510460", "ArcticFox939275", "TropicalBird570541", "CosmicDust555331",
        "QuantumLeap035256", "NebulaStar541366", "GalaxyRider213281", "AsteroidHunter307929", "CometChaser943999",
        "MeteorShower490180", "SaturnRing106251", "JupiterMoon945882", "MarsRover652511", "VenusFlyer746976",
        "MercuryDash434165", "PlutoExplorer378313", "NeptuneWave575300", "UranusOrbit060276", "EarthGuard724482",
        "SunBlaze762087", "MoonWalker401411", "StarDancer746126", "SpacePilot446429", "RocketMan803508",
        "LaserBeam193628", "PhotonBlast369925", "NeutronStar967846", "ProtonPower572084", "ElectronFlow288169",
        "AtomSmasher302943", "MoleculeMix835494", "CellDivider926550", "DNAHelix431818", "RNAStrand123317",
        "ProteinFold990603", "EnzymeCat244951", "VitaminBoost636173", "MineralRock121189", "CrystalClear873097",
        "DiamondEdge628696", "RubyGlow895754", "SapphireShine479114", "EmeraldDream535535", "AmethystMist642606",
        "TopazSun210254", "OpalMoon281552", "PearlOcean894781", "JadeForest723448", "OnyxShadow478670",
        "GarnetFire754374", "TurquoiseSky641687", "CoralReef948207", "IvoryTower682707", "BronzeAge633030",
        "SilverLining743365", "GoldRush682418", "PlatinumPro917381", "TitaniumStrong231738", "CopperGlow256951",
        "IronWill317193", "SteelNerve121543", "AluminumLight184188", "ZincShield809081", "NickelSpin810647",
        "CobaltBlue134447", "ChromeFinish771732", "TungstenTough258394", "MolybdenumMax376493", "VanadiumVibe172034",
        "ManganeseMight774509", "PalladiumPure453084", "RhodiumRare101269", "IridiumIntense672277", "OsmiumOdd233561",
        "RheniumRich695253", "TantalumTwist258498", "HafniumHigh509980", "ZirconiumZest230030", "NiobiumNova237940",
        "TokyoTiger778294", "LondonLion245602", "ParisPanther498589", "BerlinBear008218", "SydneySerpent634772",
        "TorontoTornado515976", "MadridMaverick983643", "RomeRaider184724", "SaoPauloStar483164", "MumbaiMaster482711",
        "ShanghaiShark890139", "MoscowMight810148", "DubaiDragon354547", "SingaporeSurge500873", "HongKongHero351162",
        "SeoulSniper578452", "BangkokBolt182848", "JakartaJet643384", "CairoChamp081350", "LagoosLegend866099",
        "NairobiNinja892405", "CapeTownCrush621130", "BuenosAiresBoss725008", "MexicoCityMaster392481", "LimaaLion485983",
        "SantiagoStorm444097", "BogotaBeast471443", "CaracasChamp147285", "HavannaHawk401550", "KingstonKing737312",
        "MontrealMaverick378582", "VancouverVictor981419", "MelbourneMight815557", "AucklandAce491276", "WellingtonWolf315877",
        "OsakaOracle255633", "KyotoKnight377863", "NagoyaNinja611040", "FukuokaaFury815070", "SapporoStrike777002",
        "MunichMaster942913", "HamburgHero964803", "FrankfurtFlash676648", "CologneCrusher742603", "DusseldorfDragon908503",
        "AmsterdamAce262368", "BrussellsBoss822873", "ViennaViking160358", "ZurichZealot419278", "GenevaGhost254315"
    ]

    // Real-life names for extended brackets (70% of players rank 151+ use these)
    public static let realNames = [
        // Common English names
        "James", "Michael", "Robert", "David", "William", "John", "Richard", "Thomas", "Chris", "Daniel",
        "Matthew", "Anthony", "Mark", "Steven", "Paul", "Andrew", "Joshua", "Kevin", "Brian", "George",
        "Emma", "Olivia", "Sophia", "Isabella", "Mia", "Charlotte", "Amelia", "Harper", "Evelyn", "Abigail",
        "Emily", "Elizabeth", "Sofia", "Avery", "Ella", "Scarlett", "Grace", "Chloe", "Victoria", "Riley",
        // Hispanic names
        "Carlos", "Miguel", "Luis", "Jose", "Juan", "Diego", "Alejandro", "Javier", "Fernando", "Rafael",
        "Maria", "Carmen", "Rosa", "Ana", "Lucia", "Elena", "Isabel", "Sofia", "Valentina", "Camila",
        // German names
        "Hans", "Klaus", "Wolfgang", "Heinrich", "Friedrich", "Dieter", "Helmut", "Werner", "Gerhard", "Manfred",
        "Ingrid", "Helga", "Ursula", "Gisela", "Renate", "Monika", "Petra", "Sabine", "Karin", "Brigitte",
        // French names
        "Pierre", "Jean", "Jacques", "François", "Michel", "Philippe", "Alain", "Bernard", "Christophe", "Thierry",
        "Marie", "Jeanne", "Françoise", "Monique", "Catherine", "Nathalie", "Isabelle", "Sylvie", "Martine", "Christine",
        // Italian names
        "Marco", "Giuseppe", "Giovanni", "Francesco", "Antonio", "Alessandro", "Andrea", "Luca", "Matteo", "Lorenzo",
        "Giulia", "Francesca", "Chiara", "Sara", "Anna", "Alessia", "Valentina", "Elisa", "Martina", "Giorgia",
        // Japanese names (romanized)
        "Hiroshi", "Takeshi", "Kenji", "Yuki", "Haruto", "Sota", "Ren", "Kaito", "Asahi", "Minato",
        "Yui", "Hana", "Aoi", "Sakura", "Himari", "Mei", "Rin", "Mio", "Ichika", "Akari",
        // Korean names (romanized)
        "Minho", "Jiwon", "Seojun", "Dohyun", "Hajun", "Junwoo", "Siwoo", "Yejun", "Jiho", "Junseo",
        "Jiyeon", "Soyeon", "Yuna", "Minji", "Subin", "Hayeon", "Chaewon", "Seoyeon", "Yerin", "Dahyun",
        // Chinese names (romanized)
        "Wei", "Fang", "Lei", "Jun", "Ming", "Tao", "Hao", "Chen", "Lin", "Jian",
        "Mei", "Ling", "Xiu", "Hong", "Yan", "Hui", "Juan", "Ping", "Li", "Na",
        // Indian names
        "Raj", "Amit", "Vikram", "Rahul", "Arjun", "Aditya", "Rohan", "Karan", "Nikhil", "Sanjay",
        "Priya", "Ananya", "Kavya", "Ishita", "Riya", "Neha", "Pooja", "Shreya", "Anika", "Diya",
        // Brazilian/Portuguese names
        "Pedro", "Lucas", "Gabriel", "Matheus", "Guilherme", "Rafael", "Bruno", "Felipe", "Gustavo", "Leonardo",
        "Julia", "Beatriz", "Larissa", "Leticia", "Amanda", "Mariana", "Carolina", "Fernanda", "Bruna", "Gabriela",
        // Russian names (romanized)
        "Ivan", "Dmitri", "Alexei", "Sergei", "Nikolai", "Viktor", "Andrei", "Pavel", "Mikhail", "Oleg",
        "Natasha", "Olga", "Anastasia", "Tatiana", "Ekaterina", "Irina", "Svetlana", "Marina", "Yelena", "Larisa",
        // Arabic names (romanized)
        "Ahmed", "Mohamed", "Ali", "Omar", "Hassan", "Yusuf", "Ibrahim", "Khalid", "Tariq", "Nasser",
        "Fatima", "Aisha", "Layla", "Mariam", "Noor", "Hana", "Sara", "Zara", "Amira", "Dalia",
        // Scandinavian names
        "Erik", "Lars", "Anders", "Magnus", "Olaf", "Bjorn", "Sven", "Gunnar", "Harald", "Leif",
        "Astrid", "Ingrid", "Freya", "Sigrid", "Helga", "Liv", "Solveig", "Greta", "Karin", "Maja"
    ]
    
    // Last names organized by region (same structure as realNames for matching)
    public static let lastNames = [
        // Common English last names (indices 0-39)
        "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Wilson", "Anderson",
        "Taylor", "Thomas", "Moore", "Jackson", "Martin", "Lee", "Thompson", "White", "Harris", "Clark",
        "Lewis", "Robinson", "Walker", "Hall", "Young", "King", "Wright", "Hill", "Scott", "Green",
        "Adams", "Baker", "Nelson", "Carter", "Mitchell", "Roberts", "Turner", "Phillips", "Campbell", "Parker",
        // Hispanic last names (indices 40-59)
        "Garcia", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Perez", "Sanchez", "Ramirez", "Torres",
        "Flores", "Rivera", "Gomez", "Diaz", "Reyes", "Morales", "Cruz", "Ortiz", "Gutierrez", "Chavez",
        // German last names (indices 60-79)
        "Mueller", "Schmidt", "Schneider", "Fischer", "Weber", "Meyer", "Wagner", "Becker", "Schulz", "Hoffmann",
        "Koch", "Bauer", "Richter", "Klein", "Wolf", "Schroeder", "Neumann", "Schwarz", "Braun", "Zimmermann",
        // French last names (indices 80-99)
        "Martin", "Bernard", "Dubois", "Thomas", "Robert", "Richard", "Petit", "Durand", "Leroy", "Moreau",
        "Simon", "Laurent", "Lefebvre", "Michel", "Garcia", "David", "Bertrand", "Roux", "Vincent", "Fournier",
        // Italian last names (indices 100-119)
        "Rossi", "Russo", "Ferrari", "Esposito", "Bianchi", "Romano", "Colombo", "Ricci", "Marino", "Greco",
        "Bruno", "Gallo", "Conti", "DeLuca", "Mancini", "Costa", "Giordano", "Rizzo", "Lombardi", "Moretti",
        // Japanese last names (indices 120-139)
        "Sato", "Suzuki", "Takahashi", "Tanaka", "Watanabe", "Ito", "Yamamoto", "Nakamura", "Kobayashi", "Kato",
        "Yoshida", "Yamada", "Sasaki", "Yamaguchi", "Matsumoto", "Inoue", "Kimura", "Hayashi", "Shimizu", "Yamazaki",
        // Korean last names (indices 140-159)
        "Kim", "Lee", "Park", "Choi", "Jung", "Kang", "Cho", "Yoon", "Jang", "Lim",
        "Han", "Shin", "Seo", "Kwon", "Hwang", "Ahn", "Song", "Yoo", "Hong", "Moon",
        // Chinese last names (indices 160-179)
        "Wang", "Li", "Zhang", "Liu", "Chen", "Yang", "Huang", "Zhao", "Wu", "Zhou",
        "Xu", "Sun", "Ma", "Zhu", "Hu", "Guo", "He", "Lin", "Luo", "Gao",
        // Indian last names (indices 180-199)
        "Sharma", "Patel", "Singh", "Kumar", "Gupta", "Verma", "Reddy", "Joshi", "Rao", "Mehta",
        "Shah", "Iyer", "Nair", "Chopra", "Kapoor", "Malhotra", "Menon", "Pillai", "Das", "Bhat",
        // Brazilian/Portuguese last names (indices 200-219)
        "Silva", "Santos", "Oliveira", "Souza", "Rodrigues", "Ferreira", "Alves", "Pereira", "Lima", "Gomes",
        "Costa", "Ribeiro", "Martins", "Carvalho", "Almeida", "Lopes", "Soares", "Fernandes", "Vieira", "Barbosa",
        // Russian last names (indices 220-239)
        "Ivanov", "Smirnov", "Kuznetsov", "Popov", "Vasiliev", "Petrov", "Sokolov", "Mikhailov", "Fedorov", "Morozov",
        "Volkov", "Alexeev", "Lebedev", "Semenov", "Egorov", "Pavlov", "Kozlov", "Stepanov", "Nikolaev", "Orlov",
        // Arabic last names (indices 240-259)
        "Al-Rashid", "Al-Farsi", "Al-Hassan", "Al-Mansour", "Al-Nasser", "Al-Hamad", "Al-Salem", "Al-Khalid", "Al-Zahra", "Al-Fahad",
        "El-Amin", "El-Said", "El-Masri", "El-Sharif", "El-Hadi", "El-Bakri", "El-Rahman", "El-Karim", "El-Aziz", "El-Hakim",
        // Scandinavian last names (indices 260-279)
        "Andersen", "Hansen", "Johansen", "Larsen", "Olsen", "Pedersen", "Nilsen", "Kristiansen", "Jensen", "Karlsen",
        "Eriksen", "Haugen", "Bakken", "Berg", "Dahl", "Holm", "Lund", "Strand", "Moen", "Haug"
    ]

    static let hallOfFameNames = [
        // Ranks 1-30
        "InfinityMaster462572", "EndlessVoyager", "BeyondLimits422678", "EternalChamp", "UltimatePlayer",
        "LegendaryGamer", "InfiniteWinner", "CosmicConqueror", "SupremeVictor", "DivinePlayer",
        "MythicalHero", "TranscendentOne", "OmnipotentGamer", "CelestialKing", "ImmortalPlayer",
        "UnstoppableForce", "PerfectScore571450", "FlawlessVictory", "AbsoluteChamp", "MaxLevelPro",
        "GodTierPlayer", "EliteInfinity", "MasterOfAll", "ChampOfChamps", "NumberOneForever",
        "SkillMaxed367578", "TopDogForever", "KingOfKings", "QueenSupreme", "UltimateVictory",
        // Ranks 31-60
        "BeyondPerfect", "EndgameBoss", "FinalFormPro", "MaxPowerUser", "InfiniteGlory",
        "EternalVictory", "LimitBreaker661070", "BoundlessSkill", "NeverEndingWin", "ForeverFirst",
        "AlphaOmega531681", "ZenithReached", "ApexPredator099366", "PinnaclePlayer", "SummitSeeker",
        "VanguardVictor", "ParagonPrime", "SupremeSeeker", "TitanTamer", "OlympianOne",
        "PhoenixRisen", "DragonSlayer864745", "ThunderGod795666", "StormBringer", "LightningLord",
        "ShadowMaster", "VoidWalker214877", "CosmicRuler", "GalacticKing", "UniversalChamp",
        // Ranks 61-90
        "StarForger112263", "NebulaNinja", "QuantumKing911350", "DimensionLord", "RealityBender",
        "TimeTraveler", "SpaceConqueror", "MatterMaster", "EnergyElite", "ForceField835186",
        "GravityGuru", "MagneticMight", "AtomicAce", "NuclearNinja", "FusionFighter",
        "PlasmaPlayer", "PhotonPhenom", "NeutronNinja", "ProtonPro", "ElectronElite",
        "QuarkQueen", "LeptonLord", "BosonBoss", "HiggsHero", "StringSeeker",
        "TheoryTitan", "ParticlePro", "WaveMaster", "FieldForce", "QuantumQuest",
        // Ranks 91-120
        "InfiniteImpact", "BoundlessBeam", "LimitlessLaser", "EndlessEnergy", "EternalEcho",
        "TimelessTitan", "AgelessAce", "ForeverFlame", "PerpetualPower", "ConstantChamp",
        "SteadyStrike", "UnwaveringOne", "RelentlessRuler", "PersistentPro", "EnduringElite",
        "LastingLegend", "DurableDynamo", "ResilientRacer", "TenaciousTitan", "StubbornStar",
        "UnyieldingUnit", "UnbreakableBoss", "InvincibleIcon", "ImmortalImpact", "EternalEdge",
        "InfiniteInsight", "BoundlessBrain", "LimitlessMind", "EndlessEgo", "ForeverFocus",
        // Ranks 121-150
        "MindMaster694210", "BrainBoss156227", "ThoughtTitan", "IdeaIcon", "ConceptChamp",
        "VisionVictor", "DreamDynamo", "HopeHero", "FaithFighter", "BelieveBoss",
        "TrustTitan", "LoyalLegend", "HonorHero", "GloryGamer", "FameFlame",
        "ReputationRuler", "PrestigePro", "StatusStar", "RankRoyal", "TierTitan",
        "LevelLord", "GradientGuru", "ScaleSeeker", "MeasureMaster", "MetricMight",
        "UnitUltimate", "ValueVictor", "WorthWinner", "PricePlayer", "CostChamp",
        // Ranks 151-180
        "AceOfSpades770953", "CardShark418215", "DeckMaster", "JokerWild", "RoyalFlush",
        "FullHouse398511", "StraightEdge", "FlushKing", "PairPerfect", "HighRoller",
        "JackpotJoe", "LuckyLuke", "FortuneHunter", "ChanceTaker", "OddsBeater",
        "BetBuster", "WagerWinner", "StakesKing", "PotMaster", "ChipChamp",
        "BluffBoss", "TellTracker", "ReadRuler", "FoldFighter", "RaiseMaster",
        "CallKing", "CheckChamp", "AllInAce", "BigBlind957849", "SmallStacks",
        // Ranks 181-210
        "NightOwl091844", "DawnPatrol", "DuskRider", "TwilightTitan", "MidnightMage",
        "SunriseSeeker", "SunsetStar", "MoonWalker199527", "StarGazer", "SkyWatcher",
        "CloudSurfer", "RainMaker", "SnowStorm", "HailHero", "FrostFighter",
        "BlizzardBoss", "IceKing570078", "ColdChamp", "FreezeFrame", "ChillMaster",
        "HeatWave139063", "FireStarter", "BurnBoss", "FlameKing", "EmberElite",
        "AshMaster", "SmokeScreen", "SparkPlug", "IgniteIcon", "InfernoImp",
        // Ranks 211-240
        "OceanMaster177166", "SeaSerpent", "WaveRider246180", "TideTracker", "CurrentKing",
        "DeepDiver", "SurfStar", "BeachBoss", "CoastCruiser", "ShoreShark",
        "RiverRunner", "StreamStar", "CreekCruiser", "PondPro", "LakeLord",
        "WaterfallWin", "RapidsRuler", "DeltaDuke", "EstuaryElite", "BayBoss",
        "HarborHero", "PortPro", "DockDynamo", "MarinaMaster", "AnchorAce",
        "SailStar", "BoatBoss", "ShipShape", "CaptainCool", "AdmiralAce",
        // Ranks 241-270
        "JungleMaster213010", "ForestFury", "WoodlandWin", "GroveGuard", "TreeTop537361",
        "CanopyKing", "LeafLord", "BranchBoss", "RootRuler", "BarkBaron",
        "VineMaster", "FernFighter", "MossMage", "ShrubStar", "BushBoss",
        "GrassMaster", "MeadowMight", "FieldFury", "PasturePro", "PrairiePrime",
        "SavannaStar", "PlainsPro", "SteppeStar", "TundraTitan", "ArcticAce",
        "PolarPro", "GlacierGod", "IcecapIcon", "PermafrostPro", "FrozenFury",
        // Ranks 271-300
        "DesertDuke140431", "SandStorm880529", "DuneDynamo", "OasisOracle", "MirageMaster",
        "CamelKing", "ScorpionStar", "ViperVictor", "LizardLord", "CactusCool",
        "MesaMaster", "CanyonKing", "CliffChamp", "RockRuler", "BoulderBoss",
        "PebblePro", "StoneStar", "GravelGuru", "SlateStar", "MarbleMaster",
        "GranitePro", "QuartzQueen", "CrystalKing", "GemGuru", "DiamondDuke",
        "RubyRuler", "EmeraldElite", "SapphireStar", "TopazTitan", "OpalOracle",
        // Ranks 301-330
        "CaveMaster986778", "CavernKing", "GrottoGuru", "TunnelTitan", "MineMaster456421",
        "ShaftStar", "VeinVictor", "OreMaster", "CoalKing", "IronIcon",
        "CopperChamp", "BronzeBoss", "SilverStar", "GoldGuru", "PlatinumPro",
        "TitaniumTitan", "SteelStar", "AlloyStar", "MetalMaster", "ForgeFury",
        "AnvilAce", "HammerHero", "SmithStar", "BladeBoss", "SwordStar",
        "AxeAce", "SpearStar", "ShieldStar", "ArmorAce", "HelmHero",
        // Ranks 331-360
        "WizardKing362282", "MageMonarch", "SorcererStar", "WarlockWin", "WitchWonder669752",
        "SpellStar", "RuneRuler", "GlyphGuru", "SigilStar", "CharmChamp",
        "HexHero", "CurseCaster", "BlessingBoss", "AuraAce", "ManaMaster",
        "MysticMight", "ArcaneAce", "OccultOracle", "EsotericElite", "EnigmaEra",
        "PuzzlePro", "RiddleRuler", "MysteryMaster", "SecretStar", "HiddenHero",
        "VeiledVictor", "MaskedMaster", "CloakedChamp", "ShadowedStar", "DarkDynamo",
        // Ranks 361-390
        "LightLord440455", "BrightBoss361311", "RadiantRuler", "GlowGuru", "ShineShark",
        "BeamBoss", "RayRuler", "FlashFury", "SparkStar", "GleamGuru",
        "ShimmerStar", "TwinkleTitan", "GlitterGod", "DazzleDuke", "BlazeBoss",
        "LuminousLord", "BrilliantBoss", "VividVictor", "VibrantViper", "IntensityIcon",
        "PowerPulse", "EnergyEmperor", "ForcePhenom", "StrengthStar", "MightMonarch",
        "MuscleMaster", "PowerPeak", "StrengthSurge", "ForceFusion", "EnergyEagle",
        // Ranks 391-420
        "SpeedStar545327", "FastFury575123", "QuickQueen", "RapidRuler", "SwiftStar",
        "FleetFoot", "DashDynamo", "SprintStar", "RacerRoyal", "RunnerRuler",
        "JoggerJoe", "MarathonMaster", "SpurterStar", "BoltBoss", "ZoomZephyr",
        "VelocityVictor", "MomentumMaster", "AccelAce", "TurboTitan", "NitroNinja",
        "RocketRuler", "JetJockey", "PropelPro", "ThrustTitan", "BoostBoss",
        "SurgeStar", "LeapLord", "BoundBoss", "JumpJet", "VaultVictor",
        // Ranks 421-450
        "ClimbKing182560", "SummitStar784800", "PeakPro", "MountainMaster", "HillHero",
        "RidgeRuler", "CrestChamp", "SlopeStar", "TrailTitan", "PathPro",
        "RouteMaster", "JourneyJoe", "TrekTitan", "HikeMaster", "WalkWonder",
        "StrollStar", "WanderWin", "RoamRuler", "DriftDuke", "FloatFury",
        "GlideMaster", "SoarStar", "FlyFury", "WingWonder", "FeatherFury",
        "BirdBoss", "EagleEye", "HawkHero", "FalconFury", "OwlOracle",
        // Ranks 451-480
        "WolfWarrior218074", "FoxFury352370", "BearBoss", "TigerTitan", "LionLord",
        "PantherPro", "JaguarJet", "CheetahChamp", "LeopardLord", "CougarCool",
        "LynxLord", "BobcatBoss", "WildcatWin", "CatKing", "KittenKing",
        "PuppyPro", "DogDynamo", "HoundHero", "TerrierTitan", "BullBoss",
        "PitPro", "MastiffMaster", "ShepherdStar", "RetrieveRuler", "LabLord",
        "PoodlePro", "SpanielStar", "SetterStar", "PointerPro", "BeagleBoss",
        // Ranks 481-510
        "HorseMaster764909", "PonyPro120575", "StallionStar", "MareMaster", "ColtChamp",
        "FoalFury", "MustangMight", "BroncoStar", "RacehorsePro", "ThoroughbredTitan",
        "ZebraBoss", "DonkeyDuke", "MuleMaster", "CamelCool", "LlamaLord",
        "AlpacaAce", "GoatGuru", "SheepStar", "RamRuler", "LambLord",
        "CowChamp", "BullBaron", "OxOracle", "BisonBoss", "BuffaloBolt",
        "ElkElite", "MooseMaster", "DeerDuke", "AntelopeAce", "GazellePro",
        // Ranks 511-540
        "ElephantElite264788", "RhinoRuler542166", "HippoHero", "GiraffePro", "ZebraStar",
        "LionKing", "TigerStar", "CheetahKing", "GorillaPro", "ChimpChamp",
        "OrangutanOracle", "BaboonBoss", "MonkeyMaster", "LemurLord", "TarsierTitan",
        "AyeAyeAce", "SlothStar", "ArmadilloAce", "AnteaterAce", "AardvarkAce",
        "PlatypusPro", "EchidnaElite", "KoalaCool", "WombatWin", "KangarooKing",
        "WallabyWin", "TasmanianTitan", "DingoStar", "KiwiKing", "EmuElite",
        // Ranks 541-570
        "OstrichOracle777811", "FlamingoFury406704", "PelicanPro", "StorkStar", "HeronHero",
        "CraneCool", "EgretElite", "IbisIcon", "SpoonbillStar", "ToucanTitan",
        "ParrotPro", "MacawMaster", "CockatooChamp", "LovebirdLord", "BudgieBoss",
        "FinchFury", "CanaryChamp", "SparrowStar", "RobinRuler", "CardinalChamp",
        "BluejayBoss", "CrowChamp", "RavenRuler", "MagpieMaster", "JayStar",
        "WoodpeckerWin", "NuthatchNinja", "ChickadeeCool", "TitTitan", "WrenWonder",
        // Ranks 571-600
        "HummingHero783355", "SwiftStar812095", "SwallowStar", "MartinMaster", "NightjarNinja",
        "OwlOracle501659", "HawkHero844054", "EagleStar", "FalconPro", "KestrelKing",
        "OspreyOracle", "VultureVictor", "CondorChamp", "BuzzardBoss", "KiteStar",
        "HarrierHero", "GoshawkGuru", "AccipiterAce", "MerlinMaster", "PeregrinePro",
        "SakerStar", "LannerLord", "GyrfalconGod", "PrairieHero", "ApplomadoAce",
        "CaracaraCool", "SecretaryBird", "SeriemaStar", "KakapoKing", "TakaheHero"
    ]

    // Convert milestone string to a score value
    // Higher milestones = exponentially higher scores
    // Returns a scaled score that fits in Int while preserving relative ordering
    static func scoreForMilestone(_ milestone: String) -> Int {
        // For infinity milestones (e.g., "15552∞"), parse the count
        // Score is based on infinity count - higher count = higher score
        if milestone.hasSuffix("∞") {
            let countStr = milestone.dropLast()
            if let count = Int(countStr) {
                // Base score for infinity players starts very high
                // Each infinity adds to the score, scaled to fit in Int
                let baseScore = 999_000_000_000  // 999 billion base
                let perInfinityScore = 1_000_000  // 1 million per infinity
                return baseScore + (count * perInfinityScore)
            }
        }

        // Normalize the milestone first
        let normalized = normalizeMilestone(milestone)

        // Find milestone index in allMilestones array
        if let index = allMilestones.firstIndex(of: normalized) {
            // Score grows with milestone tier
            // Use a logarithmic scale to prevent overflow
            let baseScore = 1_000_000  // 1 million base
            let tierBonus = index * 10_000_000  // 10 million per tier
            return baseScore + tierBonus
        }

        // Fallback: try to estimate based on suffix
        let suffixes = ["M", "B", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
        let doubleSuffixes = ["aa", "ab", "ac", "ad", "ae", "af", "ag", "ah", "ai", "aj", "ak", "al", "am", "an", "ao", "ap", "aq", "ar", "as", "at", "au", "av", "aw", "ax", "ay", "az", "ba", "bb", "bc", "bd", "be", "bf", "bg", "bh", "bi", "bj", "bk", "bl", "bm", "bn", "bo", "bp", "bq", "br", "bs", "bt", "bu", "bv", "bw", "bx", "by", "bz"]

        // Extract mantissa and suffix from normalized milestone
        var mantissa = 1
        var suffix = ""
        for (i, char) in normalized.enumerated() {
            if char.isLetter {
                suffix = String(normalized.dropFirst(i))
                mantissa = Int(normalized.prefix(i)) ?? 1
                break
            }
        }

        // Calculate tier index
        var tierIndex = 0
        if let idx = doubleSuffixes.firstIndex(of: suffix.lowercased()) {
            tierIndex = 28 + idx  // After single letters (28 = M, B, a-z)
        } else if let idx = suffixes.firstIndex(of: suffix.uppercased()) {
            tierIndex = idx
        } else if let idx = suffixes.firstIndex(of: suffix.lowercased()) {
            tierIndex = idx + 2  // a-z after M, B
        }

        // Score based on tier and mantissa
        // Use multiplication that won't overflow
        let tierScore = tierIndex * 10_000_000  // 10 million per tier
        let mantissaBonus = mantissa * 10_000   // 10k per mantissa unit
        return 1_000_000 + tierScore + mantissaBonus
    }

    // Base player counts (starting values)
    static let baseUSPlayers = 84_721
    static let baseGlobalPlayers = 885_676

    // Calculate new players joining on a given day (0.5-4 per day per country)
    static func newPlayersJoining(on day: Int, isUS: Bool) -> Double {
        let seed = isUS ? 12345 : 67890
        let random = seededRandom(seed: seed, index: day)
        return 0.5 + random * 3.5  // 0.5 to 4 new players per day
    }

    // Calculate country-specific new players joining per day (0.5-4 per day)
    static func countryNewPlayersJoining(on day: Int, countrySeed: Int) -> Double {
        let random = seededRandom(seed: countrySeed, index: day)
        return 0.5 + random * 3.5  // 0.5 to 4 new players per day
    }

    // Reasons why a player might leave the leaderboard
    enum PlayerLeavingReason: String, CaseIterable {
        case gameOver = "Game Over"      // 25% - ran out of moves
        case banned = "Banned"           // 25% - violated terms
        case deleted = "Deleted"         // 25% - deleted the game
        case restart = "Restart"         // 25% - chose to restart progress
    }

    // Determine why a specific player left (equal 25% for each reason)
    static func leavingReason(for playerIndex: Int, on day: Int, seed: Int) -> PlayerLeavingReason {
        let random = seededRandom(seed: seed + playerIndex * 7, index: day)
        let reasonIndex = Int(random * 4.0) // 0, 1, 2, or 3
        return PlayerLeavingReason.allCases[min(reasonIndex, 3)]
    }

    // Calculate players leaving per day (0.1-0.5 per day)
    // Reasons distributed equally (25% each): game over, banned, deleted, restart
    // 95% of leaving players are from ranks 151+, only 5% from top 150
    static func playersLeaving(on day: Int, isUS: Bool) -> Double {
        let seed = isUS ? 11111 : 22222
        let random = seededRandom(seed: seed, index: day)
        return 0.1 + random * 0.4  // 0.1 to 0.5 players per day
    }

    // Calculate players leaving for a specific reason (25% of total leaving)
    static func playersLeavingFor(reason: PlayerLeavingReason, on day: Int, isUS: Bool) -> Double {
        return playersLeaving(on: day, isUS: isUS) * 0.25
    }

    // Calculate players leaving from outside top 150 (95% of total leaving)
    static func playersLeavingOutsideTop150(on day: Int, isUS: Bool) -> Double {
        return playersLeaving(on: day, isUS: isUS) * 0.95
    }

    // Calculate players leaving from top 150 (5% of total leaving)
    static func playersLeavingFromTop150(on day: Int, isUS: Bool) -> Double {
        return playersLeaving(on: day, isUS: isUS) * 0.05
    }

    // Calculate country-specific players leaving per day (0.1-0.5 per day)
    // Each country has a unique seed for varied attrition patterns
    // Reasons distributed equally (25% each): game over, banned, deleted, restart
    // 95% are from outside top 150, only 5% from top 150
    static func countryPlayersLeaving(on day: Int, countrySeed: Int) -> Double {
        let random = seededRandom(seed: countrySeed, index: day)
        return 0.1 + random * 0.4  // 0.1 to 0.5 players per day
    }

    // Country-specific players leaving for a specific reason (25% of total leaving)
    static func countryPlayersLeavingFor(reason: PlayerLeavingReason, on day: Int, countrySeed: Int) -> Double {
        return countryPlayersLeaving(on: day, countrySeed: countrySeed) * 0.25
    }

    // Country-specific players leaving from outside top 150 (95%)
    static func countryPlayersLeavingOutsideTop150(on day: Int, countrySeed: Int) -> Double {
        return countryPlayersLeaving(on: day, countrySeed: countrySeed) * 0.95
    }

    // Country-specific players leaving from top 150 (5%)
    static func countryPlayersLeavingFromTop150(on day: Int, countrySeed: Int) -> Double {
        return countryPlayersLeaving(on: day, countrySeed: countrySeed) * 0.05
    }

    // Calculate players changing name or avatar per day (0.05-0.4 per country)
    static func playersChangingNameOrAvatar(on day: Int, isUS: Bool) -> Double {
        let seed = isUS ? 33333 : 44444
        let random = seededRandom(seed: seed, index: day)
        return 0.05 + random * 0.35  // 0.05 to 0.4 players per day
    }

    // Country-specific players changing name or avatar per day (0.05-0.4 per country)
    static func countryPlayersChangingNameOrAvatar(on day: Int, countrySeed: Int) -> Double {
        let random = seededRandom(seed: countrySeed + 5000, index: day)
        return 0.05 + random * 0.35  // 0.05 to 0.4 players per day
    }

    // Calculate total players for a specific country with new joins and attrition
    // New players: 0.5-4 per day, Attrition: 0.1-0.5 per day (95% outside top 150)
    static func totalCountryPlayers(basePlayers: Int, on day: Int, countrySeed: Int) -> Int {
        var totalNew: Double = 0
        var totalLeft: Double = 0
        for d in 0...day {
            totalNew += countryNewPlayersJoining(on: d, countrySeed: countrySeed)
            totalLeft += countryPlayersLeaving(on: d, countrySeed: countrySeed)
        }
        // Net players = base + new - left (ensure at least 151 to maintain top 150 leaderboard)
        return max(151, basePlayers + Int(totalNew) - Int(totalLeft))
    }

    // Starting milestones for active new players (players who start making progress immediately)
    // These are lower-tier milestones that new players might achieve on day 1
    static let newPlayerStartingMilestones = [
        "2", "4", "8", "16", "32", "64", "128", "256", "512", "1024", "2048", "4096", "8192",
        "16K", "32K", "65K", "131K", "262K", "524K"
    ]

    // Determine if a new player is "active" (starts with a milestone) vs "inactive" (starts at 0)
    // 75% of new players are active and start making milestones immediately
    static func isActiveNewPlayer(playerIndex: Int, joinDay: Int) -> Bool {
        let random = seededRandom(seed: playerIndex * 999 + joinDay * 13, index: joinDay)
        return random < 0.75  // 75% chance to be active
    }

    // Get starting milestone for an active new player
    static func startingMilestoneForNewPlayer(playerIndex: Int, joinDay: Int) -> String {
        let random = seededRandom(seed: playerIndex * 555 + joinDay * 7, index: playerIndex)
        let index = Int(random * Double(newPlayerStartingMilestones.count))
        return newPlayerStartingMilestones[min(index, newPlayerStartingMilestones.count - 1)]
    }

    // Calculate total players including all who joined up to this day, minus those who left
    // Players leave due to: bans, running out of moves, deleting game, or choosing to restart
    static func totalPlayers(on day: Int, isUS: Bool) -> Int {
        let basePlayers = isUS ? baseUSPlayers : baseGlobalPlayers
        var totalNew: Double = 0
        var totalLeft: Double = 0
        for d in 0...day {
            totalNew += newPlayersJoining(on: d, isUS: isUS)
            totalLeft += playersLeaving(on: d, isUS: isUS)
        }
        // Net players = base + new - left (ensure non-negative)
        return max(0, basePlayers + Int(totalNew) - Int(totalLeft))
    }

    // Calculate score with daily progression for a player
    // - 75% of new players are "active" and start with a milestone immediately
    // - 25% of new players start at score 0, gain 2 points the next day, then multiplier starts
    // - Existing players: multiply by 1.01x-1.5x per day
    static func scoreWithDailyProgression(baseScore: Int, playerIndex: Int, day: Int, isNewPlayer: Bool = false, joinDay: Int = 0) -> Int {
        if isNewPlayer {
            // New player - check if they're active (75%) or inactive (25%)
            if isActiveNewPlayer(playerIndex: playerIndex, joinDay: joinDay) {
                // Active new player - starts with a milestone immediately
                let startingMilestone = startingMilestoneForNewPlayer(playerIndex: playerIndex, joinDay: joinDay)
                let startingScore = scoreForMilestone(startingMilestone)
                let daysSinceJoin = day - joinDay
                if daysSinceJoin <= 0 {
                    return startingScore
                }
                // Apply multiplier for days since joining
                let dailyMultiplier = 1.01 + seededRandom(seed: playerIndex * 777, index: day) * 0.49
                let effectiveDays = min(daysSinceJoin, 365)
                let totalMultiplier = pow(dailyMultiplier, Double(effectiveDays) * 0.01)
                let newScore = Double(startingScore) * totalMultiplier
                return min(Int(newScore), Int.max / 2)
            } else {
                // Inactive new player - starts at score 0
                let daysSinceJoin = day - joinDay
                if daysSinceJoin == 0 {
                    return 0  // Still score 0 on day they joined
                } else {
                    // Day 1 after join: score becomes 2, then multiplier applies
                    let startingScore = 2
                    let daysWithMultiplier = daysSinceJoin - 1
                    if daysWithMultiplier <= 0 {
                        return startingScore
                    }
                    let dailyMultiplier = 1.01 + seededRandom(seed: playerIndex * 777, index: day) * 0.49
                    let effectiveDays = min(daysWithMultiplier, 365)
                    let totalMultiplier = pow(dailyMultiplier, Double(effectiveDays) * 0.01)
                    let newScore = Double(startingScore) * totalMultiplier
                    return min(Int(newScore), Int.max / 2)
                }
            }
        } else if baseScore == 0 {
            // Existing player at score 0 (from base data) - gain 2 points next day, then multiplier
            if day == 0 {
                return 0
            } else {
                let startingScore = 2
                let daysWithMultiplier = day - 1
                if daysWithMultiplier <= 0 {
                    return startingScore
                }
                let dailyMultiplier = 1.01 + seededRandom(seed: playerIndex * 777, index: day) * 0.49
                let effectiveDays = min(daysWithMultiplier, 365)
                let totalMultiplier = pow(dailyMultiplier, Double(effectiveDays) * 0.01)
                let newScore = Double(startingScore) * totalMultiplier
                return min(Int(newScore), Int.max / 2)
            }
        } else {
            // Existing player with score - multiply by 1.01x-1.5x per day
            let dailyMultiplier = 1.01 + seededRandom(seed: playerIndex * 777, index: day) * 0.49
            let effectiveDays = min(day, 365)
            let totalMultiplier = pow(dailyMultiplier, Double(effectiveDays) * 0.01)
            let newScore = Double(baseScore) * totalMultiplier
            return min(Int(newScore), Int.max / 2)
        }
    }

    // Avatar IDs from AvatarCatalog (12 options)
    static let avatarIDs = [
        // Original avatars
        "avatar-shiba-dog", "avatar-astronaut-cat", "avatar-robot-green", "avatar-phoenix-fire",
        "avatar-shark-teeth", "avatar-paper-plane", "avatar-baseball-cap", "avatar-warrior-samurai",
        "avatar-burger-food", "avatar-chicken-bird", "avatar-anchor-nautical", "avatar-bear-grizzly",
        // New avatars
        "avatar-ancient-scroll", "avatar-bubble-narwhal", "avatar-buddy-bot", "avatar-cosmic-sloth",
        "avatar-crimson-wyrm", "avatar-dapper-ape", "avatar-ember-drake", "avatar-emerald-android",
        "avatar-frosty-cupcake", "avatar-moonlight-wizard", "avatar-nordic-warrior", "avatar-professor-bee",
        "avatar-sea-captain", "avatar-skull-crossbones", "avatar-sly-fox", "avatar-soccer-star",
        "avatar-specimen-jar", "avatar-spooky-ghost", "avatar-starfighter", "avatar-storm-sword",
        "avatar-sunny-sunflower", "avatar-toxic-tonic", "avatar-treasure-chest", "avatar-winter-doll"
    ]

    // Get a varied avatar for a player using seeded randomness
    // This ensures each player has a consistent but varied avatar
    static func avatarForPlayer(index: Int, countrySeed: Int = 0) -> String {
        // ~15% of players haven't set an avatar yet (show letter-in-circle placeholder)
        let noAvatarRandom = seededRandom(seed: index * 251 + countrySeed * 43, index: index + countrySeed)
        if noAvatarRandom < 0.15 {
            return ""  // No avatar - will show letter placeholder in UI
        }

        let seed = index * 131 + countrySeed * 17
        let random = seededRandom(seed: seed, index: index)
        let avatarIndex = Int(random * Double(avatarIDs.count))
        return avatarIDs[avatarIndex % avatarIDs.count]
    }

    // Get avatar for a player with daily variation (some players change avatars over time)
    // 85% of changes happen outside top 150, only 15% in top 150
    static func avatarForPlayer(index: Int, countrySeed: Int, day: Int) -> String {
        // ~15% of players haven't set an avatar yet (show letter-in-circle placeholder)
        // New players add avatars between 3 hours and 2 days after joining
        let noAvatarRandom = seededRandom(seed: index * 251 + countrySeed * 43, index: index + countrySeed)
        if noAvatarRandom < 0.15 {
            // This player hasn't set an avatar - they'll add one after a seeded delay
            // Delay ranges from ~3 hours (0.125 days) to ~2 days
            let delayDays = 0.125 + noAvatarRandom / 0.15 * 1.875  // Maps 0-0.15 to 0.125-2.0 days
            let playerJoinDay = Int(seededRandom(seed: index * 373 + countrySeed * 67, index: index) * Double(max(1, day)))
            let daysSinceJoin = day - playerJoinDay
            if Double(daysSinceJoin) < delayDays {
                return ""  // Still hasn't set avatar
            }
            // Player has now set their avatar - fall through to normal avatar logic
        }

        // Calculate cumulative name/avatar changes up to this day
        var totalChanges: Double = 0
        for d in 0...day {
            totalChanges += countryPlayersChangingNameOrAvatar(on: d, countrySeed: countrySeed)
        }

        // Determine which players have changed based on seeded randomness
        let changeThreshold = seededRandom(seed: index * 199 + countrySeed * 31, index: index)
        let playerChangeDay = Int(changeThreshold * 200)  // Spread changes over ~200 days

        // Top 150 players are much less likely to change (only 15% of changes)
        // Multiply their change day by ~5.67x to reduce probability
        if index < 150 {
            let top150Eligible = seededRandom(seed: index * 317 + countrySeed * 59, index: index)
            if top150Eligible > 0.15 {
                // This top-150 player is not in the 15% that changes
                return avatarForPlayer(index: index, countrySeed: countrySeed)
            }
        }

        if day >= playerChangeDay && totalChanges > Double(index % 50) * 0.1 {
            // This player has changed - use a different avatar
            let newSeed = index * 131 + countrySeed * 17 + day * 7
            let random = seededRandom(seed: newSeed, index: day)
            let avatarIndex = Int(random * Double(avatarIDs.count))
            return avatarIDs[avatarIndex % avatarIDs.count]
        }

        // No change - use base avatar
        return avatarForPlayer(index: index, countrySeed: countrySeed)
    }

    // Get name for a player with daily variation (some players change names over time)
    // Real name percentages: 15% for top 150, 30% for extended brackets (rank 151+)
    // (Top 150: 85% gamertag, 15% realistic. Extended: 70% gamertag, 30% realistic)
    // 85% of name changes happen outside top 150, only 15% in top 150
    // 1/3 of players can switch between realistic and gamertag when they change
    static func nameForPlayer(index: Int, names: [String], countrySeed: Int, day: Int) -> String {
        // Determine initial name type (real vs gamertag) based on rank tier
        let realNameThreshold: Double = index < 150 ? 0.15 : 0.30
        let baseTypeRandom = seededRandom(seed: index * 401 + countrySeed * 83, index: index)
        var useRealName = baseTypeRandom < realNameThreshold

        // Calculate cumulative name/avatar changes up to this day
        var totalChanges: Double = 0
        for d in 0...day {
            totalChanges += countryPlayersChangingNameOrAvatar(on: d, countrySeed: countrySeed)
        }

        // Check if this player's name has changed
        let changeThreshold = seededRandom(seed: index * 211 + countrySeed * 43, index: index)
        let playerChangeDay = Int(changeThreshold * 200)

        // 85% of changes happen outside top 150
        var canChange = true
        if index < 150 {
            let top150Eligible = seededRandom(seed: index * 331 + countrySeed * 67, index: index)
            canChange = top150Eligible <= 0.15
        }

        let hasChanged = canChange && day >= playerChangeDay && totalChanges > Double(index % 50) * 0.1

        if hasChanged {
            // 1/3 of players can switch name types when they change
            let canSwitchType = seededRandom(seed: index * 503 + countrySeed * 97 + day, index: index)
            if canSwitchType < 0.333 {
                // Switch name type (real <-> gamertag)
                useRealName = !useRealName
            }
        }

        if useRealName {
            // Distribution: 40% English, 14.5% Hispanic, 5% German, 3.5% French, 10% Italian, 1.5% Japanese, 0.75% Chinese, 15% Portuguese, 1.25% Indian, 1% Russian, 5% Arabic, 0.5% Korean, 2% Scandinavian
            let nameTypeRandom = seededRandom(seed: index * 601 + countrySeed * 127, index: index)
            let commonEnglishStart = 0
            let commonEnglishCount = 40  // Indices 0-39: common English names
            let hispanicStart = 40
            let hispanicCount = 20  // Indices 40-59: Hispanic names
            let germanStart = 60
            let germanCount = 20  // Indices 60-79: German names
            let frenchStart = 80
            let frenchCount = 20  // Indices 80-99: French names
            let italianStart = 100
            let italianCount = 20  // Indices 100-119: Italian names
            let japaneseStart = 120
            let japaneseCount = 20  // Indices 120-139: Japanese names
            let chineseStart = 160  // Indices 160-179: Chinese names
            let chineseCount = 20
            let portugueseStart = 200  // Indices 200-219: Brazilian/Portuguese names
            let portugueseCount = 20
            let indianStart = 180  // Indices 180-199: Indian names
            let indianCount = 20
            let russianStart = 220  // Indices 220-239: Russian names
            let russianCount = 20
            let arabicStart = 240  // Indices 240-259: Arabic names
            let arabicCount = 20
            let koreanStart = 140  // Indices 140-159: Korean names
            let koreanCount = 20
            let scandinavianStart = 260  // Indices 260-279: Scandinavian names
            let scandinavianCount = 20
            
            let realNameIndex: Int
            if nameTypeRandom < 0.40 {
                // 40% common English
                if hasChanged {
                    realNameIndex = commonEnglishStart + ((index + countrySeed + day * 3) % commonEnglishCount)
                } else {
                    realNameIndex = commonEnglishStart + ((index + countrySeed) % commonEnglishCount)
                }
            } else if nameTypeRandom < 0.545 {
                // 14.5% Hispanic (0.40 + 0.145 = 0.545)
                if hasChanged {
                    realNameIndex = hispanicStart + ((index + countrySeed + day * 3) % hispanicCount)
                } else {
                    realNameIndex = hispanicStart + ((index + countrySeed) % hispanicCount)
                }
            } else if nameTypeRandom < 0.595 {
                // 5% German (0.545 + 0.05 = 0.595)
                if hasChanged {
                    realNameIndex = germanStart + ((index + countrySeed + day * 3) % germanCount)
                } else {
                    realNameIndex = germanStart + ((index + countrySeed) % germanCount)
                }
            } else if nameTypeRandom < 0.63 {
                // 3.5% French (0.595 + 0.035 = 0.63)
                if hasChanged {
                    realNameIndex = frenchStart + ((index + countrySeed + day * 3) % frenchCount)
                } else {
                    realNameIndex = frenchStart + ((index + countrySeed) % frenchCount)
                }
            } else if nameTypeRandom < 0.73 {
                // 10% Italian (0.63 + 0.10 = 0.73)
                if hasChanged {
                    realNameIndex = italianStart + ((index + countrySeed + day * 3) % italianCount)
                } else {
                    realNameIndex = italianStart + ((index + countrySeed) % italianCount)
                }
            } else if nameTypeRandom < 0.745 {
                // 1.5% Japanese (0.73 + 0.015 = 0.745)
                if hasChanged {
                    realNameIndex = japaneseStart + ((index + countrySeed + day * 3) % japaneseCount)
                } else {
                    realNameIndex = japaneseStart + ((index + countrySeed) % japaneseCount)
                }
            } else if nameTypeRandom < 0.7525 {
                // 0.75% Chinese (0.745 + 0.0075 = 0.7525)
                if hasChanged {
                    realNameIndex = chineseStart + ((index + countrySeed + day * 3) % chineseCount)
                } else {
                    realNameIndex = chineseStart + ((index + countrySeed) % chineseCount)
                }
            } else if nameTypeRandom < 0.9025 {
                // 15% Portuguese (0.7525 + 0.15 = 0.9025)
                if hasChanged {
                    realNameIndex = portugueseStart + ((index + countrySeed + day * 3) % portugueseCount)
                } else {
                    realNameIndex = portugueseStart + ((index + countrySeed) % portugueseCount)
                }
            } else if nameTypeRandom < 0.915 {
                // 1.25% Indian (0.9025 + 0.0125 = 0.915)
                if hasChanged {
                    realNameIndex = indianStart + ((index + countrySeed + day * 3) % indianCount)
                } else {
                    realNameIndex = indianStart + ((index + countrySeed) % indianCount)
                }
            } else if nameTypeRandom < 0.925 {
                // 1% Russian (0.915 + 0.01 = 0.925)
                if hasChanged {
                    realNameIndex = russianStart + ((index + countrySeed + day * 3) % russianCount)
                } else {
                    realNameIndex = russianStart + ((index + countrySeed) % russianCount)
                }
            } else if nameTypeRandom < 0.975 {
                // 5% Arabic (0.925 + 0.05 = 0.975)
                if hasChanged {
                    realNameIndex = arabicStart + ((index + countrySeed + day * 3) % arabicCount)
                } else {
                    realNameIndex = arabicStart + ((index + countrySeed) % arabicCount)
                }
            } else if nameTypeRandom < 0.98 {
                // 0.5% Korean (0.975 + 0.005 = 0.98)
                if hasChanged {
                    realNameIndex = koreanStart + ((index + countrySeed + day * 3) % koreanCount)
                } else {
                    realNameIndex = koreanStart + ((index + countrySeed) % koreanCount)
                }
            } else {
                // 2% Scandinavian (0.98 + 0.02 = 1.0)
                if hasChanged {
                    realNameIndex = scandinavianStart + ((index + countrySeed + day * 3) % scandinavianCount)
                } else {
                    realNameIndex = scandinavianStart + ((index + countrySeed) % scandinavianCount)
                }
            }
            
            // Return just the first name - last names are added by resolveRealisticNameDuplicates
            return realNames[realNameIndex]
        } else {
            var baseName: String
            if hasChanged {
                // Name has changed - use a different gamertag
                let newIndex = (index + day * 3) % names.count
                baseName = names[newIndex]
            } else {
                // Base gamertag name
                baseName = names[index % names.count]
            }
            
            // Strip any existing trailing digits from the base name
            while let last = baseName.last, last.isNumber {
                baseName.removeLast()
            }
            
            // 55% of gamertag names have numbers at the end
            let numberRandom = seededRandom(seed: index * 709 + countrySeed * 151, index: index)
            if numberRandom < 0.55 {
                // Generate a 6-digit number suffix (100000-999999), zero-padded
                let numberSeed = seededRandom(seed: index * 823 + countrySeed * 179, index: index)
                let number = 100000 + Int(numberSeed * 900000)
                return baseName + String(format: "%06d", number)
            }
            return baseName
        }
    }
    
    // Check if a name is a realistic first name (not a gamertag)
    static func isRealisticName(_ name: String) -> Bool {
        return realNames.contains(name)
    }
    
    // Get the region start index for a given first name
    static func regionStartForFirstName(_ firstName: String) -> Int {
        guard let index = realNames.firstIndex(of: firstName) else { return 0 }
        if index < 40 { return 0 }        // English
        if index < 60 { return 40 }       // Hispanic
        if index < 80 { return 60 }       // German
        if index < 100 { return 80 }      // French
        if index < 120 { return 100 }     // Italian
        if index < 140 { return 120 }     // Japanese
        if index < 160 { return 140 }     // Korean
        if index < 180 { return 160 }     // Chinese
        if index < 200 { return 180 }     // Indian
        if index < 220 { return 200 }     // Portuguese
        if index < 240 { return 220 }     // Russian
        if index < 260 { return 240 }     // Arabic
        return 260                         // Scandinavian
    }
    
    // Resolve duplicate first names by adding last names where needed
    // Takes a list of (index, name) tuples and returns resolved names
    static func resolveRealisticNameDuplicates(entries: [(index: Int, name: String)], countrySeed: Int) -> [Int: String] {
        var result: [Int: String] = [:]
        
        // Group entries by first name (only for realistic names)
        var firstNameGroups: [String: [(index: Int, name: String)]] = [:]
        
        for entry in entries {
            // Check if this is a realistic name (first name only, no spaces)
            if !entry.name.contains(" ") && isRealisticName(entry.name) {
                firstNameGroups[entry.name, default: []].append(entry)
            } else {
                // Gamertag or already has last name - keep as is
                result[entry.index] = entry.name
            }
        }
        
        // Process each group of first names
        for (firstName, group) in firstNameGroups {
            if group.count == 1 {
                // No duplicate - keep just the first name
                result[group[0].index] = firstName
            } else {
                // Duplicates found - add last names to all entries with this first name
                let regionStart = regionStartForFirstName(firstName)
                
                for entry in group {
                    // Generate a unique last name based on the player's index
                    let lastNameOffset = Int(seededRandom(seed: entry.index * 1103 + countrySeed * 229, index: entry.index) * 20)
                    let lastNameIndex = regionStart + lastNameOffset
                    let lastName = lastNames[lastNameIndex % lastNames.count]
                    result[entry.index] = firstName + " " + lastName
                }
            }
        }
        
        return result
    }
    
    // Generate names for a batch of players, automatically resolving duplicates
    // Returns a dictionary mapping player index to their final name
    static func namesForPlayers(indices: [Int], gamertagNames: [String], countrySeed: Int, day: Int) -> [Int: String] {
        // First pass: generate all names without duplicate resolution
        var rawNames: [(index: Int, name: String)] = []
        for index in indices {
            let name = nameForPlayer(index: index, names: gamertagNames, countrySeed: countrySeed, day: day)
            rawNames.append((index, name))
        }
        
        // Second pass: resolve any duplicate realistic first names
        return resolveRealisticNameDuplicates(entries: rawNames, countrySeed: countrySeed)
    }
    
    // Resolve duplicate first names in a list of LeaderboardEntry objects
    // Returns a new array with last names added to duplicate first names
    static func resolveEntryDuplicates(_ entries: [LeaderboardEntry], countrySeed: Int = 0) -> [LeaderboardEntry] {
        // Group entries by name (only for realistic first names)
        var firstNameGroups: [String: [Int]] = [:]  // firstName -> indices in entries array
        
        for (idx, entry) in entries.enumerated() {
            // Skip user entries and entries that already have last names or are gamertags
            if entry.isMe { continue }
            
            let name = entry.name
            // Check if this is a realistic first name (no spaces, exists in realNames)
            if !name.contains(" ") && isRealisticName(name) {
                firstNameGroups[name, default: []].append(idx)
            }
        }
        
        // Build result, adding last names where needed
        var result = entries
        for (firstName, indices) in firstNameGroups {
            if indices.count > 1 {
                // Duplicates found - add last names to all entries with this first name
                let regionStart = regionStartForFirstName(firstName)
                
                for idx in indices {
                    let entry = entries[idx]
                    
                    // 5% chance of cross-cultural last name, 95% same culture
                    let crossCultureRandom = seededRandom(seed: entry.rank * 1301 + countrySeed * 257, index: entry.rank)
                    
                    let lastNameIndex: Int
                    if crossCultureRandom < 0.05 {
                        // 5% - pick a last name from a different culture (random from all last names)
                        let randomLastNameOffset = Int(seededRandom(seed: entry.rank * 1103 + countrySeed * 229, index: entry.rank) * Double(lastNames.count))
                        lastNameIndex = randomLastNameOffset
                    } else {
                        // 95% - pick a last name from the same culture as the first name
                        let lastNameOffset = Int(seededRandom(seed: entry.rank * 1103 + countrySeed * 229, index: entry.rank) * 20)
                        lastNameIndex = regionStart + lastNameOffset
                    }
                    
                    let lastName = lastNames[lastNameIndex % lastNames.count]
                    
                    // Create a new entry with the full name
                    result[idx] = LeaderboardEntry(
                        id: entry.id,
                        rank: entry.rank,
                        name: firstName + " " + lastName,
                        score: entry.score,
                        countryCode: entry.countryCode,
                        platform: entry.platform,
                        isMe: entry.isMe,
                        avatarURL: entry.avatarURL,
                        highestTile: entry.highestTile
                    )
                }
            }
        }
        
        return result
    }

    // Generate extended bracket player entries around a given rank
    // Used when user is outside top 150 to show surrounding players with names
    static func extendedBracketEntries(
        aroundRank userRank: Int,
        userMilestone: String,
        countryCode: String,
        countrySeed: Int,
        names: [String],
        day: Int,
        totalPlayers: Int,
        extendedBrackets: [(milestone: String, startRank: Int)]
    ) -> [LeaderboardEntry] {
        var entries: [LeaderboardEntry] = []

        // Generate 5 players above and 5 players below the user
        let ranksToShow = 5

        // Players above user (better ranks)
        for offset in (1...ranksToShow).reversed() {
            let rank = userRank - offset
            guard rank > 150 else { continue }  // Don't generate if in top 150

            let playerIndex = rank + countrySeed  // Unique index for this player
            let name = nameForPlayer(index: playerIndex, names: names, countrySeed: countrySeed, day: day)
            let avatar = avatarForPlayer(index: playerIndex, countrySeed: countrySeed, day: day)
            let platform: Platform = playerIndex % 2 == 0 ? .ios : .android

            // Use milestoneForExtendedRank for slow, capped progression
            var milestone = milestoneForExtendedRank(rank: rank, countryCode: countryCode) ?? userMilestone
            // Ensure above-user entries have milestones >= user's milestone
            let aboveMilestoneIdx = milestoneIndex(for: milestone)
            let userMilestoneIdx = milestoneIndex(for: userMilestone)
            if aboveMilestoneIdx < userMilestoneIdx {
                milestone = userMilestone
            }

            let score = scoreForMilestone(milestone)

            entries.append(LeaderboardEntry(
                id: "ext_\(countryCode.lowercased())_\(rank)",
                rank: rank,
                name: name,
                score: score,
                countryCode: countryCode,
                platform: platform,
                isMe: false,
                avatarURL: avatar,
                highestTile: milestone
            ))
        }

        // Add user entry
        let userScore = scoreForMilestone(userMilestone)
        entries.append(LeaderboardEntry(
            id: "me",
            rank: userRank,
            name: UserLeaderboardData.playerName,
            score: userScore,
            countryCode: countryCode,
            platform: .ios,
            isMe: true,
            avatarURL: UserLeaderboardData.avatarID,
            highestTile: userMilestone
        ))

        // Players below user (worse ranks)
        for offset in 1...ranksToShow {
            let rank = userRank + offset
            guard rank <= totalPlayers else { continue }  // Don't exceed total players

            let playerIndex = rank + countrySeed  // Unique index for this player
            let name = nameForPlayer(index: playerIndex, names: names, countrySeed: countrySeed, day: day)
            let avatar = avatarForPlayer(index: playerIndex, countrySeed: countrySeed, day: day)
            let platform: Platform = playerIndex % 2 == 0 ? .ios : .android

            // Use milestoneForExtendedRank for slow, capped progression
            var milestone = milestoneForExtendedRank(rank: rank, countryCode: countryCode) ?? userMilestone
            // Ensure below-user entries have milestones <= user's milestone
            let belowMilestoneIdx = milestoneIndex(for: milestone)
            let userMilestoneIdx = milestoneIndex(for: userMilestone)
            if belowMilestoneIdx > userMilestoneIdx {
                milestone = userMilestone
            }

            let score = scoreForMilestone(milestone)

            entries.append(LeaderboardEntry(
                id: "ext_\(countryCode.lowercased())_\(rank)",
                rank: rank,
                name: name,
                score: score,
                countryCode: countryCode,
                platform: platform,
                isMe: false,
                avatarURL: avatar,
                highestTile: milestone
            ))
        }

        return entries
    }

    // Calculate infinity count with daily progression for Hall of Fame players
    // Progression rate is tiered based on current infinity count:
    // 1-99: 0.2-0.55/day, 100-999: 1-4/day, 1000-9999: 3-7/day, 10000-99999: 6-15/day, 100000+: 10-30/day
    static func infinityCountWithProgression(baseCount: Int, playerIndex: Int, day: Int) -> Int {
        // Each player has a consistent "skill factor" between 0 and 1 that determines
        // where they fall within each tier's rate range
        let skillFactor = seededRandom(seed: playerIndex * 888, index: playerIndex)

        // Simulate day-by-day progression with tiered rates
        var currentCount = Double(baseCount)
        for _ in 0..<day {
            let dailyRate: Double
            if currentCount < 100 {
                // 1-99: 0.2-0.55 infinities/day
                dailyRate = 0.2 + skillFactor * 0.35
            } else if currentCount < 1000 {
                // 100-999: 1-4 infinities/day
                dailyRate = 1.0 + skillFactor * 3.0
            } else if currentCount < 10000 {
                // 1000-9999: 3-7 infinities/day
                dailyRate = 3.0 + skillFactor * 4.0
            } else if currentCount < 100000 {
                // 10000-99999: 6-15 infinities/day
                dailyRate = 6.0 + skillFactor * 9.0
            } else {
                // 100000+: 10-30 infinities/day
                dailyRate = 10.0 + skillFactor * 20.0
            }
            currentCount += dailyRate
        }
        return Int(currentCount)
    }

    // Calculate global rank using country data aggregation (same as HUD)
    static func calculateGlobalRank(milestone: String, totalPlayers: Int) -> Int {
        // Use the same aggregation logic as UserLeaderboardData.globalRank
        return countAllPlayersBetterThan(userMilestone: milestone) + 1
    }

    /// Calculate Hall of Fame rank for a given milestone
    /// Hall of Fame has ~2,500 total entries, with top players having infinity tiles
    static func calculateHallOfFameRank(milestone: String) -> Int {
        let userMilestoneIdx = milestoneIndex(for: milestone)
        let day = daysSinceReference

        // Hall of Fame total players (grows slowly - elite players only)
        let baseHofPlayers = 2_500
        let hofGrowth = day / 7  // ~1 new elite player per week
        let totalHofPlayers = baseHofPlayers + hofGrowth

        // Hall of Fame brackets - much more compressed since only top players
        let hofExtendedBrackets: [(milestone: String, startRank: Int)] = [
            // Top tier (infinity and beyond)
            ("1an", 1), ("693am", 3), ("346am", 5), ("173am", 8),
            ("86am", 12), ("43am", 18), ("21am", 25), ("10am", 35),
            // High alphabetic tiers
            ("1am", 50), ("676al", 70), ("338al", 95), ("169al", 125),
            ("1al", 160), ("661ak", 200), ("330ak", 250), ("165ak", 310),
            ("1ak", 380), ("645aj", 460), ("322aj", 550), ("161aj", 650),
            ("1aj", 760), ("630ai", 880), ("315ai", 1010), ("157ai", 1150),
            ("1ai", 1300), ("615ah", 1460), ("307ah", 1630), ("153ah", 1810),
            ("1ah", 2000), ("1B", 2200), ("536M", 2400)
        ]

        // Find matching bracket
        for bracket in hofExtendedBrackets {
            let bracketIdx = milestoneIndex(for: bracket.milestone)
            if userMilestoneIdx >= bracketIdx {
                return bracket.startRank
            }
        }

        // Below all brackets
        return totalHofPlayers
    }

    /// Calculate country-specific rank for a given milestone
    static func calculateCountryRank(milestone: String, countryCode: String) -> Int {
        let userMilestoneIdx = milestoneIndex(for: milestone)
        let day = daysSinceReference

        // Get country-specific data and seed
        let (milestones, extendedBrackets, totalPlayers) = countryData(for: countryCode, day: day)
        let countrySeed = countryPlayerSeeds[countryCode] ?? 0

        return countBetterInCountry(
            userMilestoneIdx: userMilestoneIdx,
            milestones: milestones,
            extendedBrackets: extendedBrackets,
            totalPlayers: totalPlayers,
            countrySeed: countrySeed,
            day: day
        ) + 1
    }

    // Country player seeds for milestone progression (must match the seeds used in entry generation)
    private static let countryPlayerSeeds: [String: Int] = [
        "US": 0, "GB": 5000, "CA": 10000, "AU": 15000, "DE": 20000,
        "FR": 25000, "JP": 30000, "IN": 35000, "BR": 40000, "MX": 45000,
        "AF": 50000, "AL": 55000, "DZ": 60000, "CN": 65000, "KR": 70000,
        "IT": 75000, "ES": 80000, "NL": 85000, "CH": 90000, "NO": 95000,
        "DK": 100000, "FI": 105000, "PL": 110000, "BE": 115000, "SE": 120000,
        "AT": 125000, "IE": 130000, "PT": 135000, "GR": 140000, "CZ": 145000,
        "RO": 150000, "MY": 155000, "NZ": 160000, "HU": 165000, "TH": 170000, "AE": 175000, "PH": 180000, "AD": 185000, "ID": 190000,
        "ZA": 195000, "KE": 200000, "FJ": 205000, "VN": 210000, "CW": 215000
    ]

    /// Get the milestone at a specific rank for a country's top 150 players
    /// Returns nil if rank is out of bounds
    static func milestoneAtCountryRank(rank: Int, countryCode: String) -> String? {
        let day = daysSinceReference
        let (milestones, _, _) = countryData(for: countryCode, day: day)
        let countrySeed = countryPlayerSeeds[countryCode] ?? 0

        // Rank is 1-indexed, array is 0-indexed
        let index = rank - 1
        guard index >= 0 && index < min(150, milestones.count) else {
            return nil
        }

        // Build list of all progressed milestones with their indices
        var progressedData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int)] = []
        for i in 0..<min(150, milestones.count) {
            let baseMilestone = milestones[i]
            let progressedMilestone = milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + countrySeed, day: day)

            // Skip infinity players (they're filtered from country leaderboards)
            if progressedMilestone.hasSuffix("∞") { continue }

            let milestoneIdx = milestoneIndex(for: progressedMilestone)
            progressedData.append((i, progressedMilestone, milestoneIdx))
        }

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker: lower originalIndex = reached milestone first = better rank
        progressedData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            return $0.originalIndex < $1.originalIndex
        }

        // Return the milestone at the requested rank position
        guard index < progressedData.count else {
            return nil
        }
        return progressedData[index].progressedMilestone
    }

    /// Get the milestone for a rank in the extended brackets (ranks 151+)
    /// Returns the milestone tier that contains this rank
    static func milestoneForExtendedRank(rank: Int, countryCode: String) -> String? {
        let day = daysSinceReference
        let (_, extendedBrackets, _) = countryData(for: countryCode, day: day)
        let countrySeed = countryPlayerSeeds[countryCode] ?? 0

        guard rank > 150 else {
            return nil
        }

        // Find the bracket that contains this rank and the next higher bracket
        var baseMilestone: String? = nil
        var nextHigherBracketMilestone: String? = nil
        for (i, bracket) in extendedBrackets.enumerated() {
            if bracket.startRank <= rank {
                baseMilestone = bracket.milestone
                // The bracket before this one (lower startRank = higher milestone tier)
                if i > 0 {
                    nextHigherBracketMilestone = extendedBrackets[i - 1].milestone
                }
            } else {
                break
            }
        }

        guard let base = baseMilestone,
              let baseIndex = allMilestones.firstIndex(of: base) else {
            return baseMilestone
        }

        // Progression for extended bracket players: 0.75-5 milestones/day
        let playerIndex = rank + countrySeed
        let randomFactor = seededRandom(seed: playerIndex * 888, index: playerIndex)
        let dailyRate = 0.75 + randomFactor * 4.25
        let tiersGained = Int(dailyRate * Double(day))
        var newIndex = baseIndex + tiersGained

        // Cap: don't exceed the next higher bracket's milestone
        // This prevents rank 151 from showing a higher milestone than rank 150
        // For the first bracket (no higher bracket), cap at the base milestone itself
        // since these players are at the highest extended tier already
        if let capMilestone = nextHigherBracketMilestone,
           let capIndex = allMilestones.firstIndex(of: capMilestone) {
            newIndex = min(newIndex, capIndex)
        } else {
            // First bracket: don't progress beyond the base milestone
            newIndex = min(newIndex, baseIndex)
        }

        // Also cap at the max milestone index
        newIndex = min(newIndex, allMilestones.count - 1)

        return allMilestones[newIndex]
    }

    /// Returns country-specific milestone data
    private static func countryData(for countryCode: String, day: Int) -> (milestones: [String], extendedBrackets: [(milestone: String, startRank: Int)], totalPlayers: Int) {
        switch countryCode {
        case "US":
            return (LeaderboardClient.usPlayerMilestones, LeaderboardClient.usExtendedRankBrackets, totalPlayers(on: day, isUS: true))
        case "GB":
            return (LeaderboardClient.ukPlayerMilestones, LeaderboardClient.ukExtendedRankBrackets, 17_676)
        case "CA":
            return (LeaderboardClient.canadaPlayerMilestones, LeaderboardClient.canadaExtendedRankBrackets, 12_847)
        case "AU":
            return (LeaderboardClient.australiaPlayerMilestones, LeaderboardClient.australiaExtendedRankBrackets, 63_213)
        case "DE":
            return (LeaderboardClient.germanyPlayerMilestones, LeaderboardClient.germanyExtendedRankBrackets, 76_767)
        case "FR":
            return (LeaderboardClient.francePlayerMilestones, LeaderboardClient.franceExtendedRankBrackets, 127_676)
        case "JP":
            return (LeaderboardClient.japanPlayerMilestones, LeaderboardClient.japanExtendedRankBrackets, 894)
        case "IN":
            return (LeaderboardClient.indiaPlayerMilestones, LeaderboardClient.indiaExtendedRankBrackets, 1_488)
        case "BR":
            return (LeaderboardClient.brazilPlayerMilestones, LeaderboardClient.brazilExtendedRankBrackets, 10_000)
        case "MX":
            return (LeaderboardClient.mexicoPlayerMilestones, LeaderboardClient.mexicoExtendedRankBrackets, 7_229)
        case "AF":
            return (LeaderboardClient.afghanistanPlayerMilestones, LeaderboardClient.afghanistanExtendedRankBrackets, 11_111)
        case "AL":
            return (LeaderboardClient.albaniaPlayerMilestones, LeaderboardClient.albaniaExtendedRankBrackets, 11_222)
        case "DZ":
            return (LeaderboardClient.algeriaPlayerMilestones, LeaderboardClient.algeriaExtendedRankBrackets, 3_333)
        case "CN":
            return (LeaderboardClient.chinaPlayerMilestones, LeaderboardClient.chinaExtendedRankBrackets, 8_192)
        case "KR":
            return (LeaderboardClient.southKoreaPlayerMilestones, LeaderboardClient.southKoreaExtendedRankBrackets, 3_123)
        case "IT":
            return (LeaderboardClient.italyPlayerMilestones, LeaderboardClient.italyExtendedRankBrackets, 13_856)
        case "ES":
            return (LeaderboardClient.spainPlayerMilestones, LeaderboardClient.spainExtendedRankBrackets, 14_399)
        case "NL":
            return (LeaderboardClient.netherlandsPlayerMilestones, LeaderboardClient.netherlandsExtendedRankBrackets, 46_767)
        case "CH":
            return (LeaderboardClient.switzerlandPlayerMilestones, LeaderboardClient.switzerlandExtendedRankBrackets, 20_000)
        case "NO":
            return (LeaderboardClient.norwayPlayerMilestones, LeaderboardClient.norwayExtendedRankBrackets, 34_924)
        case "DK":
            return (LeaderboardClient.denmarkPlayerMilestones, LeaderboardClient.denmarkExtendedRankBrackets, 90_123)
        case "FI":
            return (LeaderboardClient.finlandPlayerMilestones, LeaderboardClient.finlandExtendedRankBrackets, 87_654)
        case "PL":
            return (LeaderboardClient.polandPlayerMilestones, LeaderboardClient.polandExtendedRankBrackets, 67_108)
        case "BE":
            return (LeaderboardClient.belgiumPlayerMilestones, LeaderboardClient.belgiumExtendedRankBrackets, 8_989)
        case "SE":
            return (LeaderboardClient.swedenPlayerMilestones, LeaderboardClient.swedenExtendedRankBrackets, 6_288)
        case "AT":
            return (LeaderboardClient.austriaPlayerMilestones, LeaderboardClient.austriaExtendedRankBrackets, 7_543)
        case "IE":
            return (LeaderboardClient.irelandPlayerMilestones, LeaderboardClient.irelandExtendedRankBrackets, 34_567)
        case "PT":
            return (LeaderboardClient.portugalPlayerMilestones, LeaderboardClient.portugalExtendedRankBrackets, 98_989)
        case "GR":
            return (LeaderboardClient.greecePlayerMilestones, LeaderboardClient.greeceExtendedRankBrackets, 41_414)
        case "CZ":
            return (LeaderboardClient.czechiaPlayerMilestones, LeaderboardClient.czechiaExtendedRankBrackets, 61_616)
        case "RO":
            return (LeaderboardClient.romaniaPlayerMilestones, LeaderboardClient.romaniaExtendedRankBrackets, 5_966)
        case "MY":
            return (LeaderboardClient.malaysiaPlayerMilestones, LeaderboardClient.malaysiaExtendedRankBrackets, 52_111)
        case "NZ":
            return (LeaderboardClient.newZealandPlayerMilestones, LeaderboardClient.newZealandExtendedRankBrackets, 2_623)
        case "HU":
            return (LeaderboardClient.hungaryPlayerMilestones, LeaderboardClient.hungaryExtendedRankBrackets, 111_111)
        case "TH":
            return (LeaderboardClient.thailandPlayerMilestones, LeaderboardClient.thailandExtendedRankBrackets, 5_444)
        case "AE":
            return (LeaderboardClient.uaePlayerMilestones, LeaderboardClient.uaeExtendedRankBrackets, 19_889)
        case "PH":
            return (LeaderboardClient.philippinesPlayerMilestones, LeaderboardClient.philippinesExtendedRankBrackets, 43_210)
        case "AD":
            return (LeaderboardClient.andorraPlayerMilestones, LeaderboardClient.andorraExtendedRankBrackets, 1_977)
        case "ID":
            return (LeaderboardClient.indonesiaPlayerMilestones, LeaderboardClient.indonesiaExtendedRankBrackets, 98_982)
        case "KE":
            return (LeaderboardClient.kenyaPlayerMilestones, LeaderboardClient.kenyaExtendedRankBrackets, 15_111)
        case "FJ":
            return (LeaderboardClient.fijiPlayerMilestones, LeaderboardClient.fijiExtendedRankBrackets, 1_214)
        case "VN":
            return (LeaderboardClient.vietnamPlayerMilestones, LeaderboardClient.vietnamExtendedRankBrackets, 167_676)
        case "CW":
            return (LeaderboardClient.curacaoPlayerMilestones, LeaderboardClient.curacaoExtendedRankBrackets, 39_999)
        default:
            // Default to US data for unknown countries
            return (LeaderboardClient.usPlayerMilestones, LeaderboardClient.usExtendedRankBrackets, totalPlayers(on: day, isUS: true))
        }
    }

    /// Returns all countries that have leaderboard data, sorted by player count (popularity) descending,
    /// followed by additional popular countries without leaderboard data yet
    public static func countriesWithLeaderboardsSortedByPopularity() -> [String] {
        let day = daysSinceReference

        // Countries with leaderboard data and their base player counts
        let countryPlayerCounts: [(code: String, players: Int)] = [
            ("FR", 127_676),
            ("DK", 90_123),
            ("FI", 87_654),
            ("US", totalPlayers(on: day, isUS: true)),
            ("DE", 76_767),
            ("PL", 67_108),
            ("AU", 63_213),
            ("NL", 46_767),
            ("NO", 34_924),
            ("IE", 34_567),
            ("CH", 20_000),
            ("GB", 17_676),
            ("ES", 14_399),
            ("IT", 13_856),
            ("CA", 12_847),
            ("AL", 11_222),
            ("AF", 11_111),
            ("BR", 10_000),
            ("BE", 8_989),
            ("CN", 8_192),
            ("AT", 7_543),
            ("MX", 7_229),
            ("SE", 6_288),
            ("DZ", 3_333),
            ("KR", 3_123),
            ("RO", 5_966),
            ("MY", 52_111),
            ("NZ", 2_623),
            ("HU", 111_111),
            ("IN", 1_488),
            ("JP", 894),
            ("TH", 5_444),
            ("AE", 19_889),
            ("PH", 43_210),
            ("AD", 1_977),
            ("ID", 98_982),
            ("KE", 15_111),
            ("FJ", 1_214),
            ("CZ", 61_616),
            ("PT", 98_989),
            ("GR", 41_414),
            ("ZA", 2_974),
            ("VN", 167_676),
            ("CW", 39_999)
        ]

        let countriesWithLeaderboards = countryPlayerCounts
            .sorted { $0.players > $1.players }
            .map { $0.code }

        // Additional popular countries (no leaderboard data yet)
        let additionalCountries = [
            "SA", "IL", "TR",
            "NG", "EG", "AR", "CL", "CO", "PE", "VE"
        ]

        return countriesWithLeaderboards + additionalCountries
    }

    /// Helper to count better players in a single country
    /// When countrySeed and day are provided, applies milestone progression for accurate comparison
    private static func countBetterInCountry(
        userMilestoneIdx: Int,
        milestones: [String],
        extendedBrackets: [(milestone: String, startRank: Int)],
        totalPlayers: Int,
        countrySeed: Int? = nil,
        day: Int? = nil
    ) -> Int {
        // Check if user would be in top 150 (better than first extended bracket)
        if let firstBracket = extendedBrackets.first {
            let firstBracketIdx = milestoneIndex(for: firstBracket.milestone)
            if userMilestoneIdx > firstBracketIdx {
                // User is better than top bracket, count from milestones array
                // Apply progression if countrySeed and day are provided
                var count = 0
                for (i, baseMilestone) in milestones.prefix(min(150, milestones.count)).enumerated() {
                    let m: String
                    if let seed = countrySeed, let d = day {
                        // Apply progression to get actual milestone
                        m = milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + seed, day: d)
                    } else {
                        m = baseMilestone
                    }
                    let mIdx = milestoneIndex(for: m)
                    if mIdx > userMilestoneIdx {
                        count += 1
                    }
                }
                return count
            }
        }

        // User is in extended brackets range, find matching bracket
        for bracket in extendedBrackets {
            let bracketIdx = milestoneIndex(for: bracket.milestone)
            if userMilestoneIdx >= bracketIdx {
                // startRank - 1 = number of players better than this bracket
                return bracket.startRank - 1
            }
        }

        // User is below all brackets (at score 0), apply time-of-day attrition
        // Find the score 0 bracket start rank (last bracket with milestone "0")
        let scoreZeroBracket = extendedBrackets.last { $0.milestone == "0" }
        let scoreZeroStartRank = scoreZeroBracket?.startRank ?? totalPlayers

        // Calculate score 0 players and apply retention multiplier
        let baseScoreZeroPlayers = totalPlayers - scoreZeroStartRank + 1
        let currentScoreZeroPlayers = scoreZeroPlayersAtCurrentTime(baseCount: baseScoreZeroPlayers)
        let adjustedTotalPlayers = scoreZeroStartRank - 1 + currentScoreZeroPlayers

        return max(0, adjustedTotalPlayers - 1)
    }

    /// Count players better than user's milestone across all countries
    /// Used by UserLeaderboardData.calculateGlobalRank for accurate global ranking
    static func countAllPlayersBetterThan(userMilestone: String) -> Int {
        let userMilestoneIdx = milestoneIndex(for: userMilestone)
        let day = daysSinceReference
        var total = 0

        // Add each country's count
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.usPlayerMilestones, extendedBrackets: LeaderboardClient.usExtendedRankBrackets, totalPlayers: Self.totalPlayers(on: day, isUS: true))
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.ukPlayerMilestones, extendedBrackets: LeaderboardClient.ukExtendedRankBrackets, totalPlayers: 17_676)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.canadaPlayerMilestones, extendedBrackets: LeaderboardClient.canadaExtendedRankBrackets, totalPlayers: 12_847)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.australiaPlayerMilestones, extendedBrackets: LeaderboardClient.australiaExtendedRankBrackets, totalPlayers: 63_213)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.germanyPlayerMilestones, extendedBrackets: LeaderboardClient.germanyExtendedRankBrackets, totalPlayers: 76_767)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.francePlayerMilestones, extendedBrackets: LeaderboardClient.franceExtendedRankBrackets, totalPlayers: 127_676)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.japanPlayerMilestones, extendedBrackets: LeaderboardClient.japanExtendedRankBrackets, totalPlayers: 894)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.indiaPlayerMilestones, extendedBrackets: LeaderboardClient.indiaExtendedRankBrackets, totalPlayers: 1_488)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.brazilPlayerMilestones, extendedBrackets: LeaderboardClient.brazilExtendedRankBrackets, totalPlayers: 10_000)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.mexicoPlayerMilestones, extendedBrackets: LeaderboardClient.mexicoExtendedRankBrackets, totalPlayers: 7_229)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.afghanistanPlayerMilestones, extendedBrackets: LeaderboardClient.afghanistanExtendedRankBrackets, totalPlayers: 11_111)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.albaniaPlayerMilestones, extendedBrackets: LeaderboardClient.albaniaExtendedRankBrackets, totalPlayers: 11_222)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.algeriaPlayerMilestones, extendedBrackets: LeaderboardClient.algeriaExtendedRankBrackets, totalPlayers: 3_333)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.chinaPlayerMilestones, extendedBrackets: LeaderboardClient.chinaExtendedRankBrackets, totalPlayers: 8_192)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.southKoreaPlayerMilestones, extendedBrackets: LeaderboardClient.southKoreaExtendedRankBrackets, totalPlayers: 3_123)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.italyPlayerMilestones, extendedBrackets: LeaderboardClient.italyExtendedRankBrackets, totalPlayers: 13_856)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.spainPlayerMilestones, extendedBrackets: LeaderboardClient.spainExtendedRankBrackets, totalPlayers: 14_399)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.netherlandsPlayerMilestones, extendedBrackets: LeaderboardClient.netherlandsExtendedRankBrackets, totalPlayers: 46_767)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.switzerlandPlayerMilestones, extendedBrackets: LeaderboardClient.switzerlandExtendedRankBrackets, totalPlayers: 20_000)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.norwayPlayerMilestones, extendedBrackets: LeaderboardClient.norwayExtendedRankBrackets, totalPlayers: 34_924)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.denmarkPlayerMilestones, extendedBrackets: LeaderboardClient.denmarkExtendedRankBrackets, totalPlayers: 90_123)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.finlandPlayerMilestones, extendedBrackets: LeaderboardClient.finlandExtendedRankBrackets, totalPlayers: 87_654)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.polandPlayerMilestones, extendedBrackets: LeaderboardClient.polandExtendedRankBrackets, totalPlayers: 67_108)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.belgiumPlayerMilestones, extendedBrackets: LeaderboardClient.belgiumExtendedRankBrackets, totalPlayers: 8_989)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.swedenPlayerMilestones, extendedBrackets: LeaderboardClient.swedenExtendedRankBrackets, totalPlayers: 6_288)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.austriaPlayerMilestones, extendedBrackets: LeaderboardClient.austriaExtendedRankBrackets, totalPlayers: 7_543)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.irelandPlayerMilestones, extendedBrackets: LeaderboardClient.irelandExtendedRankBrackets, totalPlayers: 34_567)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.portugalPlayerMilestones, extendedBrackets: LeaderboardClient.portugalExtendedRankBrackets, totalPlayers: 98_989)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.greecePlayerMilestones, extendedBrackets: LeaderboardClient.greeceExtendedRankBrackets, totalPlayers: 41_414)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.czechiaPlayerMilestones, extendedBrackets: LeaderboardClient.czechiaExtendedRankBrackets, totalPlayers: 61_616)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.romaniaPlayerMilestones, extendedBrackets: LeaderboardClient.romaniaExtendedRankBrackets, totalPlayers: 5_966)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.malaysiaPlayerMilestones, extendedBrackets: LeaderboardClient.malaysiaExtendedRankBrackets, totalPlayers: 52_111)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.newZealandPlayerMilestones, extendedBrackets: LeaderboardClient.newZealandExtendedRankBrackets, totalPlayers: 2_623)
        total += Self.countBetterInCountry(userMilestoneIdx: userMilestoneIdx, milestones: LeaderboardClient.hungaryPlayerMilestones, extendedBrackets: LeaderboardClient.hungaryExtendedRankBrackets, totalPlayers: 111_111)

        return total
    }

    // Calculate milestone progression for regular leaderboard players
    // Players at/above 16K milestone: progress at 0.25-1 milestones per day
    // Players below 16K milestone: progress at 1.5-4 milestones per day (faster to catch up)
    static func milestoneWithProgression(baseMilestone: String, playerIndex: Int, day: Int) -> String {
        guard let baseIndex = allMilestones.firstIndex(of: baseMilestone) else {
            return baseMilestone
        }

        // Index of "16K" in allMilestones array
        let milestone16KIndex = 14

        // Each player gets a consistent daily milestone progression rate
        // Rate depends on milestone: players below 16K progress faster to catch up
        let dailyRate: Double
        let randomFactor = seededRandom(seed: playerIndex * 888, index: playerIndex)

        if baseIndex < milestone16KIndex {
            // Players below 16K milestone: 1.5-4 milestones per day (faster progression)
            dailyRate = 1.5 + randomFactor * 2.5
        } else {
            // Players at/above 16K milestone: 0.25-1 milestones per day
            dailyRate = 0.25 + randomFactor * 0.75
        }

        // Calculate total tiers gained
        let tiersGained = Int(dailyRate * Double(day))
        let newIndex = baseIndex + tiersGained

        // If progression goes beyond the highest milestone, player reaches infinity
        // Calculate infinity count based on how far past the max they've progressed
        if newIndex >= allMilestones.count {
            let tiersPastMax = newIndex - allMilestones.count + 1
            // Each tier past max represents making and merging infinity tiles
            // Sequential: 1∞, 2∞, 3∞, 4∞, 5∞, ...
            return "\(tiersPastMax)∞"
        }

        return allMilestones[newIndex]
    }

    // Get milestone index for sorting (higher index = better milestone)
    static func milestoneIndex(for milestone: String) -> Int {
        // Normalize the milestone first
        let normalized = normalizeMilestone(milestone)

        // Try exact match first
        if let index = allMilestones.firstIndex(of: normalized) {
            return index
        }
        // Try case-insensitive match
        let lowercased = normalized.lowercased()
        if let index = allMilestones.firstIndex(where: { $0.lowercased() == lowercased }) {
            return index
        }

        // For unfound milestones, estimate index based on tier and mantissa
        // This ensures invalid milestones still sort correctly relative to valid ones
        return estimateMilestoneIndex(normalized)
    }

    // Estimate milestone index for milestones not in allMilestones array
    // Uses tier hierarchy and mantissa to calculate approximate position
    private static func estimateMilestoneIndex(_ milestone: String) -> Int {
        let lowered = milestone.lowercased()
        var numStr = ""
        var suffix = ""

        for char in lowered {
            if char.isNumber {
                numStr.append(char)
            } else {
                suffix.append(char)
            }
        }

        let mantissa = Int(numStr) ?? 1

        // Calculate tier based on suffix
        // Raw numbers: tier 0, K: tier 1, M: tier 2, B: tier 3
        // Single letters a-z: tiers 4-29
        // Double letters aa-bz: tiers 30-81
        let tier: Int
        switch suffix.uppercased() {
        case "K": tier = 1
        case "M": tier = 2
        case "B": tier = 3
        default:
            if suffix.isEmpty {
                tier = 0  // Raw number
            } else if suffix.count == 1, let c = suffix.first, c >= "a" && c <= "z" {
                // Single letter tier: a=4, b=5, ..., z=29
                tier = 4 + Int(c.asciiValue! - Character("a").asciiValue!)
            } else if suffix.count == 2 {
                // Double letter tier: aa=30, ab=31, ..., az=55, ba=56, ..., bz=81
                let chars = Array(suffix)
                let first = Int(chars[0].asciiValue! - Character("a").asciiValue!)
                let second = Int(chars[1].asciiValue! - Character("a").asciiValue!)
                tier = 30 + first * 26 + second
            } else {
                tier = 0  // Unknown, treat as raw number
            }
        }

        // Each tier spans ~10 entries in allMilestones
        // Base index is tier * 10, plus mantissa contribution (scaled logarithmically)
        let tierBase = tier * 10

        // Mantissa within tier: higher mantissa = higher index within tier
        // Most tiers go from 1 to ~900, so use log scale
        let mantissaContribution: Int
        if mantissa <= 1 {
            mantissaContribution = 0
        } else if mantissa <= 10 {
            mantissaContribution = 1 + (mantissa - 1) / 2  // 1-4
        } else if mantissa <= 100 {
            mantissaContribution = 5 + (mantissa - 10) / 20  // 5-9
        } else {
            mantissaContribution = min(9, 9 + (mantissa - 100) / 200)  // 9+
        }

        return tierBase + mantissaContribution
    }

    // Compare two milestone strings: returns >0 if m1 > m2, <0 if m1 < m2, 0 if equal
    static func compareMilestones(_ m1: String, _ m2: String) -> Int {
        let idx1 = milestoneIndex(for: m1)
        let idx2 = milestoneIndex(for: m2)

        // If both found, compare indices
        if idx1 > 0 || idx2 > 0 {
            return idx1 - idx2
        }

        // Parse milestones manually for comparison
        // Format: <number><suffix> where suffix is K, M, B, or lowercase letters (a-z, aa-zz, etc.)
        func parseMilestone(_ m: String) -> (mantissa: Int, tier: Int)? {
            let lowered = m.lowercased()
            var numStr = ""
            var suffix = ""
            for char in lowered {
                if char.isNumber {
                    numStr.append(char)
                } else {
                    suffix.append(char)
                }
            }
            guard let mantissa = Int(numStr) else { return nil }

            // Determine tier from suffix
            let tier: Int
            switch suffix {
            case "k": tier = 1
            case "m": tier = 2
            case "b": tier = 3
            default:
                // Letter suffixes: a=4, b=5, ..., z=29, aa=30, ab=31, ...
                if suffix.isEmpty {
                    tier = 0
                } else if suffix.count == 1, let c = suffix.first, c >= "a" && c <= "z" {
                    tier = 4 + Int(c.asciiValue! - Character("a").asciiValue!)
                } else if suffix.count == 2 {
                    let chars = Array(suffix)
                    let first = Int(chars[0].asciiValue! - Character("a").asciiValue!)
                    let second = Int(chars[1].asciiValue! - Character("a").asciiValue!)
                    tier = 30 + first * 26 + second
                } else {
                    tier = 100 // Unknown suffix, assume high
                }
            }
            return (mantissa, tier)
        }

        guard let p1 = parseMilestone(m1), let p2 = parseMilestone(m2) else {
            return 0
        }

        // Higher tier = better
        if p1.tier != p2.tier {
            return p1.tier - p2.tier
        }
        // Same tier, higher mantissa = better
        return p1.mantissa - p2.mantissa
    }

    // Hall of Fame infinity counts - original values
    static let hallOfFameInfinityCounts: [Int] = [
        // US Hall of Fame (43 players)
        12222, 7644, 2888, 2233, 1898, 1895, 1288, 977, 775, 676, 674, 674, 588, 411, 299,
        214, 159, 100, 77, 44, 43, 41, 38, 34, 31, 28, 25, 22, 19, 17,
        13, 11, 9, 8, 6, 4, 3, 3, 2, 2, 1, 1, 1
    ]

    static let ukHallOfFameInfinityCounts: [Int] = [
        // UK Hall of Fame (43 players)
        10578, 3336, 876, 299, 233, 167, 162, 122, 89, 78, 67, 56, 45, 43, 36,
        36, 34, 34, 34, 32, 21, 16, 12, 10, 10, 8, 7, 6, 5, 5,
        4, 4, 4, 3, 3, 3, 3, 2, 2, 2, 1, 1, 1
    ]

    static let canadaHallOfFameInfinityCounts: [Int] = [
        // Canada Hall of Fame (38 players)
        544, 449, 388, 333, 299, 208, 207, 206, 188, 149, 133, 119, 107, 97, 89,
        83, 79, 77, 76, 67, 53, 39, 22, 21, 20, 19, 19, 13, 11, 10,
        8, 4, 3, 2, 2, 1, 1, 1
    ]

    static let australiaHallOfFameInfinityCounts: [Int] = [
        // Australia Hall of Fame (38 players)
        998, 555, 333, 331, 239, 207, 157, 119, 83, 44, 44, 43, 42, 22, 21,
        18, 16, 14, 12, 11, 11, 10, 8, 7, 7, 6, 6, 6, 4, 3,
        3, 3, 2, 2, 2, 1, 1, 1
    ]

    static let germanyHallOfFameInfinityCounts: [Int] = [
        // Germany Hall of Fame (41 players)
        2111, 1666, 1222, 1000, 888, 788, 774, 674, 534, 199, 185, 125, 85, 32, 30,
        28, 26, 24, 22, 22, 22, 21, 19, 13, 12, 12, 10, 7, 6, 5,
        5, 5, 4, 4, 3, 3, 2, 2, 2, 1, 1
    ]

    static let franceHallOfFameInfinityCounts: [Int] = [
        // France Hall of Fame (36 players)
        444, 211, 209, 208, 111, 97, 95, 33, 32, 22, 21, 21, 20, 15, 13,
        11, 10, 10, 9, 9, 9, 9, 8, 8, 8, 8, 7, 7, 7, 7,
        4, 3, 3, 2, 1, 1
    ]

    static let japanHallOfFameInfinityCounts: [Int] = [
        // Japan Hall of Fame (37 players)
        677, 676, 670, 633, 560, 414, 411, 212, 211, 88, 39, 48, 44, 44, 34,
        25, 17, 13, 11, 10, 9, 9, 6, 5, 5, 5, 4, 4, 3, 3,
        3, 3, 2, 2, 1, 1, 1
    ]

    static let indiaHallOfFameInfinityCounts: [Int] = [
        // India Hall of Fame (37 players)
        6776, 6767, 6702, 6333, 5666, 4141, 4114, 2121, 2112, 888, 399, 48, 44, 44, 34,
        25, 17, 13, 11, 10, 9, 9, 6, 5, 5, 5, 4, 4, 3, 3,
        3, 3, 2, 2, 1, 1, 1
    ]

    static let brazilHallOfFameInfinityCounts: [Int] = [
        // Brazil Hall of Fame (44 players)
        1111, 943, 587, 384, 321, 267, 232, 222, 222, 221, 167, 143, 121, 119, 99,
        86, 69, 56, 25, 24, 23, 21, 17, 14, 12, 11, 11, 9, 8, 8,
        7, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1, 1, 1
    ]

    static let mexicoHallOfFameInfinityCounts: [Int] = [
        // Mexico Hall of Fame (35 players)
        11111, 8755, 5912, 4413, 4410, 3544, 1185, 966, 784, 711, 635, 559, 318, 98, 77,
        69, 67, 66, 34, 17, 8, 7, 6, 5, 5, 4, 3, 3, 2, 2,
        2, 1, 1, 1, 1
    ]

    static let afghanistanHallOfFameInfinityCounts: [Int] = [
        // Afghanistan Hall of Fame (22 players)
        1933, 689, 663, 639, 348, 311, 220, 129, 97, 69, 44, 23, 19, 14, 10,
        7, 5, 4, 4, 3, 1, 1
    ]

    static let albaniaHallOfFameInfinityCounts: [Int] = [
        // Albania Hall of Fame (26 players)
        870, 492, 484, 239, 114, 110, 53, 24, 19, 16, 14, 12, 11, 11, 10,
        9, 9, 7, 5, 3, 3, 2, 2, 1, 1, 1
    ]

    static let algeriaHallOfFameInfinityCounts: [Int] = [
        // Algeria Hall of Fame (28 players)
        322, 299, 221, 211, 156, 122, 89, 77, 65, 39, 33, 28, 24, 21, 19,
        18, 16, 13, 9, 4, 3, 3, 2, 2, 1, 1, 1, 1
    ]

    static let chinaHallOfFameInfinityCounts: [Int] = [
        // China Hall of Fame (52 players)
        988, 676, 543, 277, 222, 167, 112, 98, 78, 66, 54, 43, 32, 25, 18,
        17, 15, 14, 13, 13, 12, 12, 12, 11, 11, 9, 8, 8, 6, 6,
        5, 5, 5, 4, 4, 4, 4, 3, 3, 3, 3, 2, 2, 2, 2,
        2, 1, 1, 1, 1, 1, 1
    ]

    static let southKoreaHallOfFameInfinityCounts: [Int] = [
        // South Korea Hall of Fame (51 players)
        28822, 22222, 18766, 11149, 3995, 2996, 2055, 1288, 866, 386, 344, 221, 116, 108, 100,
        95, 29, 28, 28, 27, 22, 21, 21, 20, 20, 19, 19, 19, 18, 18,
        18, 18, 17, 12, 12, 11, 8, 8, 6, 6, 4, 3, 3, 2, 2,
        2, 1, 1, 1, 1, 1
    ]

    static let italyHallOfFameInfinityCounts: [Int] = [
        // Italy Hall of Fame (54 players)
        4552, 3888, 3222, 2555, 2193, 1183, 877, 398, 303, 233, 188, 165, 154, 153, 151,
        111, 96, 84, 75, 67, 58, 52, 47, 43, 33, 32, 31, 30, 28, 26,
        25, 22, 18, 13, 12, 10, 10, 7, 5, 5, 4, 4, 3, 3, 3,
        2, 2, 2, 2, 1, 1, 1, 1, 1
    ]

    static let spainHallOfFameInfinityCounts: [Int] = [
        // Spain Hall of Fame (49 players)
        12345, 4321, 3443, 2998, 2222, 1676, 1234, 1111, 1098, 932,
        767, 676, 494, 432, 345, 321, 234, 210, 197, 185,
        173, 161, 159, 147, 135, 123, 111, 109, 100, 67,
        55, 49, 43, 34, 23, 22, 20, 17, 13, 8,
        5, 3, 3, 2, 2, 1, 1, 1, 1
    ]

    static let netherlandsHallOfFameInfinityCounts: [Int] = [
        // Netherlands Hall of Fame (33 players)
        32123, 19922, 6769, 4167, 2524, 676, 111, 89, 77, 77,
        76, 75, 48, 27, 11, 7, 5, 5, 4, 3,
        3, 3, 2, 2, 2, 2, 1, 1, 1, 1,
        1, 1, 1
    ]

    static let usNames = [
        "AmericanEagle486408", "StarsAndStripes", "USAChamp879384", "LibertyGamer", "PatriotPlayer",
        "FreedomFighter", "StateStar221473", "CapitalCity096548", "RedWhiteBlue", "UncleSamPro",
        "NYCGamer791952", "LAPlayer385153", "ChicagoChamp", "TexasHero", "FloridaFan",
        "CaliforniaDream", "NewYorkNinja", "BostonBoss", "SeattleStar", "DenverDude",
        "PhoenixPro", "HoustonHawk", "AtlantaAce", "MiamiMaster", "DetroitDynamo",
        "PhillyPhenom", "DCDefender", "VegasVictor", "PortlandPower", "AustinAce",
        "SanDiegoSurfer", "DallasDestroyer", "SanJoseSamurai", "JacksonvilleJet", "IndianapolisIcon",
        "ColumbusChamp", "CharlotteCrush", "SanFranciscoFox", "FortWorthForce", "MemphisMaverick",
        "BaltimoreBlitz", "MilwaukeeMaster", "AlbuquerqueAce", "TucsonTitan", "FresnoFlash",
        "SacramentoStar", "KansasCityKing", "MesaMaster", "OmahOracle", "ColoradoComet",
        "RaleighRaider", "LongBeachLegend", "VirginiaViking", "OaklandOutlaw", "MinneapolisMight",
        "TulsaTornado", "ArlingtonArrow", "NewOrleansNinja", "WichitaWarrior", "ClevelandCrusher",
        "TampaTitan", "BakersfieldBoss", "AuroraAce", "AnaheimAssassin", "HonoluluHero",
        "SantaAnaSniper", "CorpusChristiChamp", "RiversideRuler", "LexingtonLion", "StocktonStorm",
        "StLouisStriker", "PittsburghPro", "AnchorageAlpha", "CincinnatiCyber", "GreensboroGhost",
        "PlanoPlayer", "IrvineInferno", "NewarkNinja", "ToledoTerror", "OrlandoOmega",
        "ChulaChulaChamp", "DurhamDragon", "JerseyJuggernaut", "StPaulPhenomm", "LaRedoLegend",
        "BuffaloBeast", "GilbertGladiator", "MadisonMarvel", "RennoRocket", "NorthLasVegasNova",
        "LubbockLancer", "GlendaleeGuru", "WinstonWarrior", "ScottsdaleSnake", "NorfolkNomad",
        "SpokaneSprint", "RichmondRacer", "BoiseBlaster", "FresnFighter", "DesMoinesDynamo",
        "TacomaTornado", "RochesterRuler", "SaltLakeStar", "BirminghamBoss", "HartfordHawk",
        "ProvidencePro", "NashvilleNinja", "JerseyShoreJet", "OklahomaOmega", "LouisvilleLion",
        "MilwaukeeMight", "TucsonTwister", "MobileMarvel", "KnoxvilleKing", "ChattanoogaChamp",
        "AkronAce", "SyracuseSniper", "SavannahStar", "AllenAlpha", "DaytonDynamo",
        "SpringfieldSprint", "PasadenaPro", "PompanoPlayer", "CoralGablesCrush", "TallahasseTitan",
        "GainesvilleGuru", "PensacolaPhenom", "ClearwaterChamp", "BocaRatonBoss", "NapleNinja"
    ]

    static let ukNames = [
        "LondonLegend734037", "ManchesterMaverick", "BirminghamBoss", "LiverpoolLion", "LeedsLightning",
        "SheffieldShark", "BristolBrawler", "NewcastleNinja", "NottinghamNinja", "SouthamptonStar",
        "LeicesterLancer", "CoventriCrusher", "BradfordBeast", "CardiffChamp", "BelfastBolt",
        "EdinburghElite", "GlasgowGladiator", "ManchesterMaster", "LondonLancer", "OxfordOracle",
        "CambridgeCrush", "BrightonBlaze", "PlymouthPower", "DerbyDynamo", "SwanseaStorm",
        "AberdeenAce", "DundeeDestroyer", "InvernessIcon", "YorkYeti", "BathBlaster",
        "ExeterEagle", "NorwichNova", "IpswichImpact", "ReadingRaider", "LutonLurker",
        "PrestonProwler", "BlackpoolBlitz", "BoltonBomber", "WiganWarrior", "StokeSmasher",
        "HullHammer", "MiddlesbroughMight", "SunderlandSlayer", "DurhamDragon", "CheltenhamChaser",
        "WorcesterWolf", "GloucesterGhost", "PeterboroughPhoenix", "MiltonKeynesMaster", "NorthamptonNinja",
        "LincolnLion", "ChesterChamp", "WarringtonWizard", "CarlisleCrusher", "LancasterLegend",
        "HarrogatHero", "ScarboroughStar", "WhitbyWonder", "DoncasterDemon", "RotherhamRogue",
        "BarnsleyBeast", "WakefieldWarrior", "HuddersfieldHawk", "HalifaxHunter", "OldhamOracle",
        "RochdaleRacer", "BuryBrawler", "StockportStriker", "SalfordShadow", "TraffordTitan",
        "PortsmouthPirate", "BournemouthBoss", "PooleProwler", "TorquayTornado", "TauntonThunder",
        "WestonWolf", "SwindonSerpent", "BasingstokeBlaze", "GuildfordGladiator", "CrawleyCrusher",
        "MaidstoneMaverick", "AshfordAssassin", "CanterburyKnight", "DoverDynamo", "FolkestoneFlash",
        "MargateMarauder", "RamsgateRuler", "TunbridgeWellsTitan", "SevenoaksSlayer", "DartfordDestroyer",
        "GravesendGhost", "RochesterRogue", "ChathamChamp", "GillinghamGladiator", "SittingbourneStar",
        "FavershamFury", "WhitstableWizard", "HerneBayHero", "BirchingtonBolt", "BroadstairsBoss"
    ]

    static let canadaNames = [
        "TorontoTitan", "VancouverViking", "MontrealMaverick", "CalgaryChamp", "OttawaOracle",
        "EdmontonElite", "WinnipegWarrior", "QuebecQuake", "HamiltonHawk", "KitchenerKnight",
        "LondonLancer", "VictoriaVictor", "HalifaxHero", "OshawaOmen", "WindsorWolf",
        "SaskatoonStar", "ReginaRaider", "StJohnsStorm", "BarrieBeast", "KelownaKing",
        "AbbotsfordAce", "KingstonKrusher", "SudburySlayer", "ThunderBayTitan", "GuelphGladiator",
        "CambridgeCrusher", "BrantfordBrawler", "MississaugaMaster", "BramptonBoss", "MarkhamMaverick",
        "RichmondRogue", "BurnabyBlaze", "SurreySniper", "LavalLegend", "LongueuilLion",
        "GatineauGhost", "NiagaraNinja", "PeterboroughProwler", "KamloopsKiller", "NanaimoNova",
        "CharlottetownChamp", "FrederictonFury", "MonctonMarauder", "YellowknifeYeti", "WhitehorseWolf",
        "IqaluitIce", "RedDeerRanger", "MooseJawMaster", "BrandonBolt", "PrinceGeorgePro",
        "DrummondvilleDragon", "SherbrookeShadow", "TroisRivieresThunder", "SaguenaySnake", "ChicoutimiChaser",
        "RimouskiRuler", "VictoriavilleViper", "GranbyGhost", "SaintJeanStar", "BeloeilBeast",
        "MagogMaverick", "AlmaMaster", "JolietteJuggernaut", "LachuteLancer", "MontLaurierLegend",
        "RouynNorandaRogue", "ValDOrVictor", "AmosMachine", "SeptIlesSerpent", "BaieComeuBrawler",
        "GaspeGladiator", "MataneMaster", "RiviereDuLoupRaider", "EdmundstonEagle", "BathurstBolt",
        "CampbelltonCrusher", "MiramichiMaverick", "SackvilleStar", "TruroTornado", "SydneyShadow",
        "GlaceBayGhost", "NewGlasgowNinja", "YarmouthYak", "KentvileKnight", "BridgewaterBoss",
        "CornerBrookCrush", "GanderGladiator", "GrandFallsGhost", "StephenvilleStar", "LabradorLegend",
        "CharlottetownChaser", "SummersideStar", "StratfordStriker", "MontagueMaster", "SourisSerpent"
    ]

    static let australiaNames = [
        "SydneyStar", "MelbourneMaverick", "BrisbaneBoss", "PerthProwler", "AdelaideAce",
        "GoldCoastGladiator", "NewcastleNinja", "CanberraCrusher", "WollongongWarrior", "HobartHero",
        "GeelongGhost", "TownsvilleTitan", "CairnsChamp", "ToowoombaThunder", "DarwinDestroyer",
        "LauncestonLegend", "AlburyAssassin", "BallaratBrawler", "BendigoBeast", "MackayMaster",
        "RockhamptonRaider", "BundabergBolt", "HerveyBayHawk", "WaggaWaggaWolf", "MilduraMaverick",
        "SheppartonShadow", "GladstoneGladiator", "TamworthTornado", "OrangeOracle", "DubboDestroyer",
        "BathurstBoss", "GeraldtonGhost", "KalgoorlieKnight", "BunburyBrawler", "AliceSpringsAce",
        "BroomeBlaze", "KarrathaKiller", "PortHedlandProwler", "MountIsaMaster", "SunshineCoastStar",
        "FremantleFlash", "MandurahMaverick", "RockinghamRogue", "PalmerstonProdigy", "LismoreeLion",
        "GraftonGladiator", "CoffsHarbourChamp", "PortMacquariePro", "ArmidaleeAce", "TareeeTitan",
        "NowraaNinja", "QueanbeyanQuake", "GoulburnGhost", "MurrayBridgeMaster", "MountGambierGladiator",
        "WhyallaWarrior", "PortAugustaaProwler", "PortLincolnLegend", "CedunaChamp", "PortPiriePro",
        "DevonportDestroyer", "BurnieBoss", "UlverstoneeUltra", "KingstonKnight", "QueenstownQuake",
        "ZeehanZealot", "SmithtonStar", "WynyardWarrior", "PengguinProwler", "GeorgetownGhost",
        "KatherineKnight", "TennantCreekTitan", "NhulunbuyNinja", "JabbiruuJuggernaut", "YulendumuYeti",
        "ArnhemAce", "BarklyBrawler", "VictoriaRiverVictor", "WadeeyeWarrior", "GrooteeGladiator",
        "NarrabriiNinja", "MooreeMaster", "InverellImpact", "GlenInnesGhost", "TenterfieldTitan",
        "MuswellbrookMaverick", "SingletonStar", "MaitlandMaster", "CessnockChamp", "KuriKuriKnight"
    ]

    static let germanyNames = [
        "BerlinBoss", "MunichMaverick", "HamburgHero", "CologneCrusher", "FrankfurtFlash",
        "StuttgartStar", "DusseldorfDestroyer", "LeipzigLegend", "DortmundDemon", "EssenElite",
        "BremenBrawler", "DresdenDragon", "HannoverHawk", "NurembergNinja", "DuisburgDynamo",
        "BochumBeast", "WuppertalWarrior", "BielefeldBlitz", "BonnBolt", "MunsterMaster",
        "AugsburgAce", "KarlsruheKnight", "MannheimMaverick", "WiesbadenWolf", "GelsenkirchenGhost",
        "AachenAssassin", "MoenchengladbachMaster", "ChemnitzChamp", "BraunschweigBrawler", "KielKiller",
        "KrefeldKrusher", "MagdeburgMaverick", "FreiburgFlash", "OberhausenOracle", "LubeckLegend",
        "HagenHero", "ErfurtElite", "RostockRaider", "KasselKnight", "MainzMaster",
        "HammHawk", "SaarbruckenStar", "HerneHero", "MulheimMaverick", "OsnabruckOracle",
        "LudwigshafenLion", "LeverkusenLegend", "OldenburgOgre", "NeusNinja", "PotsdamProwler",
        "HeidelbergHawk", "PaderbornPhantom", "DarmstadtDestroyer", "RegensburgRogue", "WurzburgWarrior",
        "WolfsburgWolf", "HeilbronnHunter", "IngelstadtImpact", "UlmUltra", "OffenbachOracle",
        "GottingenGhost", "BottropBrawler", "RecklinghausenRaider", "PforzheimPhoenix", "RemscheidRogue",
        "ReutlingenRaptor", "MoersMaverick", "SiegenShadow", "SalzgitterStorm", "HildesheimHero",
        "KaiserslauternKnight", "CottbusCrusher", "WittenWarrior", "GuetersloehGladiator", "SchwerinStar",
        "IserlohnImpact", "ZwickauZealot", "DessauDestroyer", "TuebingenTitan", "FlensburgFlash",
        "HanauHawk", "RatingenRogue", "LunenLegend", "VillingenViper", "MarburgMaster",
        "KonstanzKnight", "GiessenGhost", "NorderstedtNinja", "DelmenhorstDemon", "BambergBoss"
    ]

    static let franceNames = [
        // 1-10: Mix (3 Paris)
        "ParisPro", "MarseilleMaster", "EiffelElite", "ToulouseTitan", "NiceNinja",
        "MontmartreMaster", "StrasbourgStar", "MontpellierMaverick", "BordeauxBoss", "LouvreeLegend",
        // 11-20: Mix (2 Paris)
        "LyonLegend", "RennesRaider", "ParisienProwler", "SaintEtienneSlayer", "ToulonTornado",
        "GrenobleGhost", "DijonDestroyer", "ChampsElyseesChamp", "NimesNinja", "LilleLion",
        // 21-30: Mix (3 Paris)
        "NantesNomad", "SacreCoeurStar", "AixEnProvenceAce", "BrestBrawler", "ToursThunder",
        "ArcDeTriompheAce", "LimogesLion", "MetzMaster", "MontparnasseMaverick", "PerpignanProwler",
        // 31-40: Mix (2 Paris)
        "OrleansOracle", "MulhouseMaverick", "RouenRaider", "CaenCrusher", "MaraisMaster",
        "ReimsRogue", "LeHavreHawk", "AngersAce", "StGermainStar", "VilleurbannneVictor",
        // 41-50: Mix (3 Paris)
        "ClermontCrusher", "LeMansLegend", "BastilleBoss", "AmiensAssassin", "BesanconBolt",
        "TrocaderoTitan", "AvignonAvenger", "DunkerqueDestroyer", "PalaisRoyalPro", "ColombesChamp",
        // 51-60: Mix (2 Paris)
        "PoitiersPhantom", "CalaisCrusher", "AntibesAce", "LaRochelleLegend", "IleDeLaCiteIcon",
        "StMaloMaster", "ChamberyChamp", "NiortNinja", "OperaOracle", "ColmarChamp",
        // 61-70: Mix (3 Paris)
        "ValenceVictor", "QuimperQuake", "PigalleProwler", "LorientLegend", "ChartresChamp",
        "LavalLion", "RiveDroiteRaider", "DraguignanDragon", "SarcellesShadow", "BellevilleBlaster",
        // 71-80: Mix (2 Paris)
        "BagneuxBoss", "BoulogneBolt", "PantinProwler", "MontreuillMaster", "ChateletChamp",
        "NanterreNinja", "IvryImpact", "FontenayFlash", "DefenseDynamo", "AulnayAce",
        // 81-90: Mix (3 Paris)
        "SevranStar", "LivryLion", "StOuenOracle", "RepubliquRaider", "RosnyRogue",
        "SartrouvilleStar", "NationNinja", "GennevilliersGhost", "CergyChamp", "PlaceDItaliePro",
        // 91-100: Mix (2 Paris)
        "CannesChamp", "HyeresHero", "SaintDenisStar", "RoubaixRogue", "GareDuNordGhost",
        "TourcoingTitan", "AsnieresAce", "VersaillesVictor", "SaintPaulStar", "AubervilliersAce",
        // 101-110: Mix (3 Paris)
        "ChampignyShadow", "CourbevoieChamp", "LeMaraisLegend", "EvryEagle", "MaisonsAce",
        "SaintOuenStar", "TuileriesThunder", "BondyBolt", "VitryVictor", "PantheonProwler",
        // 111-120: Mix (2 Paris)
        "ClichyChamp", "EpinalEagle", "SoissonsStar", "PereLachaisePro", "GagnyGhost",
        "LuxembourgLion", "DreuxDestroyer", "ArlesBrawler", "BatignolessBoss", "NarbonneNinja",
        // 121-130: Mix (3 Paris)
        "BeziersBolt", "CarcassonneCrusher", "PontNeufPro", "SeteSlayer", "AgdAce",
        "MontorgueilMaster", "AlbiAce", "CastresChamp", "OberkampfOracle", "RodezRaider",
        // 131-140: Mix (2 Paris)
        "MillauMaster", "FigeacFlash", "CahorsCrusher", "AuchAce", "LaBuetteBlaster",
        "TarbesTitan", "PauProwler", "BayonneBoss", "BertinPoireeBoss", "BiarritzBrawler",
        // 141-150: Mix (3 Paris)
        "DaxDestroyer", "MontDeMarsanMaster", "SentierStar", "AgenAce", "VilleneuveStar",
        "MenilmontantMaverick", "PerigueuxPhantom", "BergeracBolt", "PorteDeClignancourt", "LiberteLegend"
    ]

    static let japanNames = [
        // 1-10: Mix (3 Tokyo)
        "TokyoTitan", "OsakaOracle", "ShibuyaShadow", "KyotoKnight", "NagoyaNinja",
        "ShinjukuShogun", "SapporoSamurai", "KobeKenshi", "AkihabarAce", "FukuokaFighter",
        // 11-20: Mix (3 Tokyo)
        "YokohamYusha", "HiroshimaHero", "RoppongiRonin", "SendaiSenshi", "KawasakiKaze",
        "HarajukuHunter", "SaitamaShogun", "ChibaChampion", "IkebukuroIron", "KitakyushuKage",
        // 21-30: Mix (3 Tokyo)
        "SakaiShinobi", "NiigataNinja", "GinzaGhost", "HamamatsuHawk", "KumamotoKing",
        "AsakusaAssassin", "SagamiharaStar", "OkayamaOni", "OdaibaDragon", "ShizuokaShadow",
        // 31-40: Mix (3 Tokyo)
        "KagoshimaKami", "FunabashiFury", "UenoUltra", "HimejiHero", "MatsuyamaMaster",
        "ShiodomeSlayer", "NagasakiNinja", "KanazawaKenshi", "TokyoTowerTitan", "UtsunomiyaUltra",
        // 41-50: Mix (3 Tokyo)
        "MatsudoMage", "NishinomiyaNinja", "NakameguroNinja", "AmagasakiAce", "KashiwaKaze",
        "ShimokitaStar", "ToyamaThunder", "NahaNoble", "YanakaYusha", "NagareyamaLegend",
        // 51-60: Mix (3 Tokyo)
        "FujisawaFist", "ToyohashiTiger", "KichijojKnight", "HachiojiHunter", "MachidarMaster",
        "DaikanyamaDemon", "TamaThunder", "HinoHero", "EbisuElite", "KodairaKing",
        // 61-70: Mix (3 Tokyo)
        "NishitokyStar", "FuchuFighter", "AzabuAce", "AkishimaAce", "MusashinoMaster",
        "MeguroMaster", "KoganeiKaze", "TachikawaThunder", "NihonbashiNinja", "KokubujiKnight",
        // 71-80: Mix (3 Tokyo)
        "HigashikurHero", "TsukubaThunder", "ShinagawaShogun", "KasukabeStar", "SokaShogun",
        "SkytreeSlayer", "TokorozawaTitan", "KawagoeChampi", "NerimaNoble", "KoshigayaKing",
        // 81-90: Mix (3 Tokyo)
        "IchinomiyaIron", "OtsuOracle", "SetagayaStar", "AomoriAce", "MoriokaMarvel",
        "KotokuKenshi", "AkitaAssassin", "YamagataYusha", "TaitoTiger", "FukushimaFury",
        // 91-100: Mix (3 Tokyo)
        "MitoMaster", "TsuchiuraTiger", "SumidaSamurai", "OitaOracle", "MiyazakiMaster",
        "ChiyodaChamp", "NaraNinja", "OtaruOracle", "MinatoMaster", "AsahikawAce",
        // 101-110: Mix (3 Tokyo)
        "KushiroKnight", "ObihiroOracle", "SuginamiSensei", "TokamachTitan", "NagaokaLegend",
        "BunkyoBlade", "JoetsuJinx", "SadoSamurai", "KatsushikaKing", "MurakamiMaster",
        // 111-120: Mix (3 Tokyo)
        "TsurugaTiger", "FukuiFighter", "AdachiAce", "KomatsuKaze", "KagaGhost",
        "NakanoNinja", "TakaokaThunder", "ImizuImpact", "ItabashiIron", "ToyamaTornado",
        // 121-130: Mix (3 Tokyo)
        "GifuGladiator", "OgakiOracle", "EdogawaEagle", "TajimThunder", "SekiShadow",
        "ArakawAce", "ShizuokaSlayer", "HamamatsuHero", "ToshimaTitan", "NumazuNinja",
        // 131-140: Mix (3 Tokyo)
        "FujiFlash", "MishimaMaster", "OtaOracle", "ItoImpact", "ShimonosekiStar",
        "RyogokuRonin", "UbeUltra", "HagiHero", "YoyogiYusha", "IwakuniIron",
        // 141-150: Mix (3 Tokyo)
        "TokuyamaThunder", "KudamatsKnight", "TsukijiTitan", "YanaiYusha", "ShunanShogun",
        "JimboChoJinx", "KaratsKaze", "SagaSamurai", "OchanomizuOracle", "ImariImpact"
    ]

    static let indiaNames = [
        "MumbaiMaster", "DelhiDestroyer", "BangaloreBlitz", "HyderabadHero", "ChennaiChamp",
        "KolkataKing", "PuneProdigy", "AhmedabadAce", "JaipurJuggler", "LucknowLegend",
        "KanpurKnight", "NagpurNinja", "IndoreInvader", "ThaneThunder", "BhopalBoss",
        "VisakhapatnamVictor", "PimpriProwler", "PatnaPhantom", "VadodaraViper", "GhaziabadGhost",
        "LudhianaLion", "AggraAvenger", "NashikNomad", "FaridabadFury", "MeerutMarvel",
        "RajkotRaider", "KalyanKaze", "VasaiViking", "VaranasiVanguard", "SrinagarStar",
        "AurangabadAssassin", "DhanbadDragon", "AmritsarArcher", "NaviNinja", "AllahabadAce",
        "RanchRogue", "HowrahHawk", "CoimbatoreChampion", "JabalpurJuggernaut", "GwaliorGladiator",
        "VijayawadaVortex", "JodhpurJester", "MaduraiMaster", "RaipurRanger", "KotaKrusher",
        "ChandigarhCrusader", "GuwahatiGuru", "SolapurSlayer", "HubliHero", "MysoreMystic",
        "TirupurTitan", "BareilliBrawler", "AligarhAvenger", "MoradabadMage", "GorakhpurGiant",
        "BhiwandiBlaster", "JamshedpurJinx", "BhilaiBlaze", "AmravatiAssault", "CuttackCyclone",
        "BikanerBolt", "BhavnagarBeast", "DehradunDemon", "DurgapurDestiny", "AsansolAce",
        "NandedNinja", "KolhapurKing", "AjmerArrow", "GulbargaGuard", "JamnagarJolt",
        "UjjainUltra", "LoniLancer", "SiligurShadow", "JhansiJudge", "UlhasnagarUltra",
        "JammuJaguar", "SangliStorm", "MangoMaster", "BelgaumBlade", "MangaloreMaverick",
        "AmbatturAce", "TirunelveliTiger", "MalegaonMarauder", "GayaGhost", "JalgaonJet",
        "UdaipurUnicorn", "MaheshtalaMinotaur", "DavangereDynamo", "BellaryBoss", "PaliBolt"
    ]

    static let brazilNames = [
        "SaoPauloStar", "RioRaider", "BrasiliaBlitz", "SalvadorSlayer", "FortalezaFury",
        "BeloHorizBoss", "ManausMaster", "CuritibaCrusher", "RecifeRogue", "PortoAlegreAce",
        "GoianiGhost", "BelemBolt", "GuarulhosGuard", "CampinasChampi", "SaoLuisLegend",
        "SaoGoncaloStar", "MaceioMaverick", "DuqueCaxiasDestroyer", "NatalNinja", "TeresinhaTitan",
        "CampoGrandeGladiator", "NovaIguacuNomad", "SaoBeDoSulShadow", "JoaoPessoJuggernaut", "SantoAndreAce",
        "OsascoOracle", "RibeiraoPretoRaider", "JaboataoBrawler", "UberlandiaUltra", "SorocabaSlayer",
        "ContagemChamp", "AracajuAssassin", "FeiraSantanaFury", "CuiabaKing", "JoinvillleJolt",
        "JuizForaJinx", "LondrinaLion", "AparecidaAce", "NiteroiNinja", "AnanindeauAvenger",
        "BelfordRoxoBolt", "CamposBrawler", "SaoJoseCamposStar", "SerraSlayer", "CaxiasSulChamp",
        "VilaVelhaVictor", "FlorianopolisFighter", "MacaeMaster", "SantaMariaStorm", "MogiCruzesMage",
        "BetimBlade", "DiademaDragon", "CaruaruCrusher", "PetrolinaProwler", "CanoasChampion",
        "VitoriaVortex", "CaucaiaCyclone", "SantaCruzStar", "PelotasProwler", "SuzanoShadow",
        "TaubateTitan", "LimeirLegend", "BarueriBlitz", "GravataiBoss", "ImperatrizIron",
        "CamacarKnight", "VoltaRedondaViper", "IpatIngaInvader", "JundaiJolt", "CabeFrioChamp",
        "SobralSlayer", "MaringaMaster", "MontesClarosMaverick", "RioGrandeRogue", "PiracicabaProwler",
        "CariacicaChamp", "OlindaOracle", "PontaGrossaProwler", "ItaquaquecBrawler", "BlumenauBolt",
        "JacareJinx", "GovernadorValadares", "FrancoRochaFury", "SantarEmStar", "PraiGrandeProwler",
        "PaulistaPhantom", "ItaboraiImpact", "RioBrancoRaider", "SaoVicenteVictor", "FozIguacuFighter"
    ]

    static let mexicoNames = [
        "CiudadMexicoMaster", "GuadalajaraGhost", "MonterreyMaverick", "PueblaProwler", "TijuanaTitan",
        "LeonLegend", "JuarezJuggernaut", "ZapopanZealot", "MeridaaMaster", "SanLuisPotosiStar",
        "AguascalientesAce", "HermosilloHero", "SaltilloSlayer", "MexicaliMage", "CuliacanCrusher",
        "AcapulcoAvenger", "TlalnepantlaTornado", "CancunChamp", "ChihuahuaChampion", "NaucalpanNinja",
        "QueretaroQuake", "MoreliaMaverick", "TolucaTempest", "TorreonTitan", "CuernavacaCyclone",
        "ReynosaRaider", "TuxtlaGutierrezTornado", "DurangoDestroyer", "OaxacaOracle", "VillahermosaVictor",
        "VeracruzViper", "CiudadLopezMateosLegend", "XalapaaXtreme", "TabascoThunder", "MazatlanMaster",
        "ImurisiInvader", "CelayaaCyclone", "TepicTornado", "EnsenadaEagle", "ColimaCrusher",
        "PachucaProwler", "TlaxcalaTitan", "CampecheCaptain", "ZacatecasZealot", "ChetumalChamp",
        "LaaPazProwler", "GuaymasGladiator", "LosLocosMochisMaster", "NuevoLaredoNinja", "MatamorosMaverick",
        "PiedrasNegrasPhantom", "MonclovaMonster", "SabinasStar", "CiudadVictoriaVictor", "TampiicoTitan",
        "PozaRicaProwler", "CoatzacoalcosChamp", "MinatitlanMaster", "CordobaCyclone", "OrizabaOracle",
        "IrapuatoInvader", "SalamancaSlayer", "SanJuanDelRioRaider", "TehuacanTornado", "AtlixcoAce",
        "TulaaTitan", "PlaayaDelCarmenChamp", "CoziCozumelCrusader", "IslaaMujeresMaster", "ProgresoProwler",
        "CampeecheCityChamp", "CiudadDelCarmenCrusher", "FronteraaFighter", "ParaisoPhantom", "MacuspanaaMaverick",
        "ComalcalcoCyclone", "CardenasChamp", "HuimanguilloHero", "EmilianoZapataZealot", "TenosiqueeTitan",
        "SanCristobalSlayer", "ComitanCrusader", "TapachulaTornado", "TonalaTitan", "ArriagaAce",
        "ChiapaDeCorzoChamp", "OcosinguloOracle", "PalenqueProwler", "CatazajaCyclone", "TeapaaTitan"
    ]

    static let afghanistanNames = [
        "KabulKing", "HeratHero", "MazariSharifMaster", "KandaharKnight", "JalalabadJuggernaut",
        "KunduzKrusader", "BalkhhBrawler", "BaghlanBolt", "GhazniGladiator", "KhostKhampion",
        "NangarharNinja", "TakharTitan", "BadakhshanBoss", "FaryabFury", "HelmandHunter",
        "LogarLegend", "PaktiaPhantom", "SamangaanSlayer", "WardakWarrior", "ZabulZealot",
        "BamyanBlade", "DaykundiDestroyer", "GhorGhost", "NimrozNomad", "FarahFighter",
        "BadghisBrawler", "SariPulStar", "JowzjanJolt", "PanjshirProwler", "KapisaKing",
        "LaghmanLion", "NuristanNinja", "KunarKrusader", "ParwanPhantom", "PaktikaProwler",
        "UrozganUltra", "SamanganShadow", "TakharThunder", "BaghlanBoss", "KhostKiller",
        "NangarharNova", "KandaharKrusader", "HeratHawk", "MazarMaverick", "KabulKrusader",
        "JalalabadJinx", "KunduzKing", "BalkhBolt", "GhazniGhost", "PaktiaaProwler",
        "LogarLightning", "WardakWolf", "ZabulZephyr", "BamyanBeast", "GhorGuardian",
        "FarahFlash", "NimrozNightmare", "BadghisBlade", "SariPulSlayer", "JowzjanJuggernaut",
        "PanjshirPower", "KapisaKnight", "LaghmanLegend", "NuristanNomad", "KunarKing",
        "ParwanProwler", "PaktikaPhantom", "UrozganUltimate", "SamanganStorm", "BadakhshanBolt",
        "FaryabFighter", "HelmandHero", "DaykundiDragon", "TakharTornado", "BaghlanBlitz",
        "KhostKhan", "NangarharNuke", "KandaharCrusher", "HeratHammer", "MazarMaster",
        "KabulCommander", "JalalabadJudge", "KunduzKhaleesi", "BalkhBaron", "GhazniGeneral"
    ]

    static let albaniaNames = [
        "TiranaaTitan", "DurresDestroyer", "VloraVictor", "ElbasanEagle", "ShkodraSlayer",
        "FierFury", "KorceKrusader", "BeratBrawler", "LushnjeLegend", "KavajaaKnight",
        "GjirokasterGhost", "SarandaStar", "KukesProwler", "LezheLion", "PogradeckPhantom",
        "KucoveKing", "BurrelBolt", "PeshkopiProwler", "LaciLightning", "KrujaKrusader",
        "CerrikChamp", "LiberLiber", "GramshGladiator", "PermetPhantom", "TepelenaTornado",
        "HimaraHero", "PukaProwler", "MirditaMaster", "MatMaverick", "DibraDestroyer",
        "TropojaTitan", "KelmendKing", "ShkrelSlayer", "HasHawk", "BajramCurriiBoss",
        "FushKrujeeFighter", "MamurrasMaster", "KapsliceKnight", "DevolliDestroyer", "KolonjaaKrusader",
        "MallakastraaMaverick", "MalesiMadheeMaster", "PolcanPhantom", "PrespaaProwler", "PukePhantom",
        "SeliceSlayer", "ShijakkStar", "SkaparSlayer", "TeplovaaTitan", "VaauDejesVictor",
        "BallshBrawler", "BilistBolt", "CermeChamp", "DivjakaaDestroyer", "FrakullaFury",
        "GoskovaGladiator", "HoraNinja", "JalKnight", "KelcyraaKrusader", "KllosoKing",
        "KrutjeKrusader", "LekasBoss", "LibofshaLegend", "MbreshotMaster", "NovoselaNinja",
        "OrikumOracle", "PatosiPhantom", "QendraQuake", "RoskoveciRaider", "SeleniceSlayer",
        "ShushicaaSlayer", "TerboufTitan", "VllahinaaVictor", "VreshttasVictor", "ZharrezaZealot",
        "ArmenAce", "BabiceBlitz", "CakaranChamp", "DorrezDestroyer", "ErsekeEagle",
        "FrakovaFury", "GerdecGhost", "HolltaasHero", "IbaaInvader", "JubanaaJudge"
    ]

    static let algeriaNames = [
        "AlgierssAce", "OranOracle", "ConstantineChamp", "AnnabaaAnnihilator", "BlidaBrawler",
        "BatnaBolt", "DjelfaDestroyer", "SetifSlayer", "SidiBelAbbesStar", "BiskraBoss",
        "TebessaTitan", "ElOuedEagle", "SkikdaaSlayer", "TiaretTornado", "BejaiaaBeast",
        "TlemcenThunder", "OuarglaOracle", "BelAbbesBrawler", "MostaganemMaster", "BordjBouArreridj",
        "ChelfChamp", "SoukAhrasStar", "MedeaMaverick", "ElBayadhEagle", "JijelJuggernaut",
        "MsilaaMaster", "SaidaStar", "GhardaiaGhost", "RelizaneRaider", "MascaaraMaverick",
        "OumElBouaghiBoss", "KhencheelaKnight", "AinDeflaDestroyer", "NaamaNinja", "AinTemouchentAce",
        "GhilizaneGladiator", "TissemssiltTitan", "ElTarfEagle", "TindoufThunder", "AdrarAce",
        "IlliziInvader", "TamanrassetTitan", "BordjBadjiMokhtarBoss", "InGueezzamInvader", "DjanetDragon",
        "OutlaTitan", "BouSaadaBoss", "LaghouatLegend", "ElGoléeGhost", "TimimounTornado",
        "BeniiAbbèsBrawler", "AdraarAce", "BecharrBolt", "ZaaldasZealot", "HassiMessaoudHero",
        "InAmenasInvader", "TouggurtTitan", "ElMeghaierMaster", "ElOuedEagle", "GueemaarGladiator",
        "DebilaaDestroyer", "RegganeeRaider", "AouléefAce", "InSalahInvader", "AbalassaaAce",
        "BordjiOmarDrisBoss", "TimiaaounTitan", "IdelessInvader", "TamanrasssetTitan", "HirafokHero",
        "SiletStar", "TinZaaouatenTornado", "ArakArcher", "InEkkerInvader", "AinGuezzamAce",
        "BordjiElHoouasssBoss", "BordjiMokhtaarMaster", "TinZaouaténTornado", "IdelesssInvader", "TiimiaounTitan",
        "BordjiiBadjiMokhtaarBoss", "InGuezzzamInvader", "TamanrasseetTitan", "AouulefAce", "ReggganeRaider"
    ]

    static let chinaNames = [
        "BeijingBoss", "ShanghaiStar", "GuangzhouGhost", "ShenzhenSlayer", "ChengduChamp",
        "HangzhouHero", "WuhanWarrior", "XianXpert", "NanjingNinja", "ChongqingCrusher",
        "TianjinTitan", "SuzhouStar", "DongguanDestroyer", "ShenyangSlayer", "QingdaoQuake",
        "ZhengzhouZealot", "DalianDragon", "JinanJuggernaut", "ChangshaChamp", "HarbinHawk",
        "FuzhouFlash", "KunmingKnight", "WuxiWonder", "HefeiiHero", "ChangchunChamp",
        "NanchangNinja", "ShijiazhuangStar", "TaiyuanTornado", "NanningNinja", "GuiyangGhost",
        "UrumqiUltimate", "LanzhouLegend", "HaikouHawk", "YantaiYakuza", "JiaxingJuggernaut",
        "WenzhouWarrior", "QuanzhouQuake", "XuzhouXpert", "TangshannTitan", "BaotouBolt",
        "ZhongshanZealot", "HuizhouHero", "YinchuanYeti", "LuoyangLegend", "LinyiLightning",
        "ZiboZephyr", "HuaianHawk", "ZhuhaiiZealot", "JiangmenJuggernaut", "WeifangWarrior",
        "LanzhouuLegend", "YangzhouYakuza", "DaqingDragon", "NantongNinja", "TaizhouTitan",
        "XianningXpert", "ZhenjiangZealot", "CangzhouChamp", "MaanshanMaster", "YichannYeti",
        "LiuzhouLightning", "DatongDragon", "AnshannAce", "ChangzhouChamp", "FushuunFlash",
        "JilinJuggernaut", "YueyangYakuza", "YanchengYeti", "ChifengChamp", "AnqingAce",
        "QinhuangdaoQuake", "BengbuBolt", "XinyangXpert", "ShaoxingSlayer", "ZhanjiangZealot",
        "HuanggangHero", "JiningJuggernaut", "QujingQuake", "JiaozuoJuggernaut", "PingdingshanPro",
        "XiangyangXpert", "WuhuWarrior", "NanchongNinja", "JiujiangJuggernaut", "XingtaiXpert"
    ]

    static let southKoreaNames = [
        "SeoulStar", "BusanBoss", "IncheonInvader", "DaeguDestroyer", "DaejeonDragon",
        "GwangjuGhost", "UlsanUltimate", "SuwonSlayer", "ChangwonChamp", "SeongnamStar",
        "GoyangGladiator", "YonginYakuza", "BucheonBolt", "AnsanAce", "AnYangArcher",
        "NamyangjuNinja", "HwaseongHero", "CheongJuChamp", "JeonjuJuggernaut", "CheonanChamp",
        "GimhaeGhost", "PohangPro", "JejuJuggernaut", "KimcheonKnight", "GangneungGladiator",
        "ChunCheonChamp", "YeosuYeti", "GeojGladiator", "YangSanYakuza", "AnsAce",
        "GwangmyeongGhost", "JinJuJuggernaut", "GunpoGladiator", "UiJeongBuUltimate", "GumiGhost",
        "WonjuWarrior", "IksanInvader", "AsanAce", "PyeongtaekPro", "GwangJuGladiator",
        "JeCheonJuggernaut", "YangJuYakuza", "GyeongjuGhost", "GwacheonGladiator", "HanamHero",
        "OsanOracle", "SiheungSlayer", "GunSanGladiator", "UiWangUltimate", "YangCheonYeti",
        "TongYeongTitan", "SacheonSlayer", "GimPoGhost", "SeosanStar", "GangDongGladiator",
        "ChungJuChamp", "NonSanNinja", "GyeryongGladiator", "DongDuCheonDragon", "SongTanStar",
        "PaJuPro", "ICheonInvader", "GimCheonGhost", "NaJuNinja", "MokPoMaster",
        "YeongCheonYeti", "SangJuSlayer", "AnDongAce", "MunGyeongMaster", "YeongJuYakuza",
        "JeongEupJuggernaut", "NamWonNinja", "GimJeGhost", "BuAnBolt", "GoChangGladiator",
        "HongSeongHero", "BoRyeongBoss", "SeoCheongStar", "TaeAnTitan", "DangJinDragon",
        "YeSanYeti", "CheongYangChamp", "HongSanHero", "GongJuGladiator", "GyeRyongKnight"
    ]

    static let italyNames = [
        "RomaStar", "MilanoMaster", "NapoliNinja", "TorinoTitan", "FirenzeFighter",
        "VeneziaVictor", "BolognaBlitz", "GenovaGladiator", "PalermoPhoenix", "BariBlaster",
        "CataniaChamp", "VeronaViking", "MessinaMaster", "PadovaPhenom", "TriesteTracker",
        "BresciaBolt", "ParmaProdigy", "TarantoTitan", "PratoPhoenix", "ModenaMaestro",
        "ReggioRuler", "PescariaPro", "LivornoLegend", "RavennaRaider", "CagliariCrusader",
        "FoggiaFighter", "RiminiRanger", "SalernoSlayer", "FerraraFury", "SassariStorm",
        "MonzaMaster", "SiracusaStar", "BergamoBolt", "PerugiaPro", "TrentoTitan",
        "SpeziaStar", "VicenzaVictor", "TerniTornado", "NovaraNavigator", "UdineUltimate",
        "PiacenzaPhoenix", "AnconaAce", "ArezzoArcher", "LuccaLegend", "ComoCrusader",
        "PistoiaPro", "PesaroPowerhouse", "AlbengaAce", "AlessandriaArcher", "AostaAce",
        "BiellaBlitz", "CarraraChamp", "CesenaChallenger", "CosenzaCrusader", "CremonaChamp",
        "FanoFighter", "FermoFury", "ForliForce", "GrossetoGladiator", "ImolaMaster",
        "IserniaTitan", "LaTeziaLegend", "LatinaStar", "LecceLegend", "MantovaMarauder",
        "MassaMaster", "MateraMaster", "OlbiaStar", "OristanoOracle", "PaviaPro",
        "PordenonePhoenix", "RagusaRuler", "RovigoRanger", "SanremoStar", "SavonaStar",
        "SienaStar", "TrapaniTitan", "TrevisoTracker", "VareseStar", "ViterboVictor",
        "AscoliAce", "AvellinoArcher", "BenevntoBlitz", "CaltanissettaChamp", "CampobassoChamp"
    ]

    static let spainNames = [
        "MadridMaster", "BarcelonaBolt", "ValenciaVictor", "SevillaStar", "ZaragozaZapper",
        "MalagaMaestro", "MurciaMaster", "PalmaPhoenix", "BilbaoBlitz", "AlicanteAce",
        "CordobaCrusader", "ValladolidViking", "GijonGladiator", "HospitaletHero", "VitoriaVictor",
        "CorunaChamp", "GranadaGladiator", "ElcheElite", "OviedoOracle", "BadalonaBolt",
        "CartagenaCrusader", "TerrassaTitan", "JerezJuggler", "SabadellStar", "MostolesMaster",
        "SantaCruzStar", "PamplonaPro", "AlmeriaAce", "LeganesLegend", "SanSebastianStar",
        "BurgosBlaster", "SalamancaStar", "AlbaceteAce", "GetafeGladiator", "LogronoLegend",
        "HuelvaHero", "TarragonaTitan", "LeridaLegend", "CadizChamp", "LeonLegend",
        "MarbellaMaster", "DonostiaDragon", "MataroMaster", "TorrejonTitan", "ParlaPhoenix",
        "AlgecirasAce", "AlcobendasAce", "ReusRanger", "ToledoTitan", "CaceresChamp",
        "JaenJuggler", "OurenseOracle", "LugoLegend", "SantiagoStar", "PontevedraPro",
        "FerrolFighter", "PonferradaPhoenix", "AvilesAce", "LinaresLegend", "TorremoleTitan",
        "BenidormBlitz", "FuengirolaFury", "TorreviejaTitan", "ManresaMaster", "VigoVictor",
        "RubiRanger", "ManacorMaster", "IbizaInferno", "MelillaMaster", "CeutaChamp",
        "RondaRanger", "EcijaElite", "UtreraUltimate", "PuertoProdigy", "AntequeraAce",
        "EsteponaStar", "LaSedaLuz", "TalaveraTitan", "PlasenciaPro", "SegoviaStar"
    ]

    static let netherlandsNames = [
        "AmsterdamAce", "RotterdamRuler", "HagueHero", "UtrechtUltimate", "EindhovenElite",
        "TilburgTitan", "GroningenGladiator", "AlmereMaster", "BredaBolt", "NijmegenNinja",
        "EnschedeStar", "HaarlemHero", "ArnhemAce", "ZaandamZapper", "AmersfoortAce",
        "ApeldoornApex", "HertogenboschHero", "ZaanstadZealot", "HaarlemmermeerHero", "ZoetermeerZapper",
        "LeeuwardenLegend", "LeidenLegend", "MaastrichtMaster", "DordrechtDragon", "EdeElite",
        "AlphenaandenRijnAce", "DelftDragon", "DeventerDestroyer", "WestervoortWarrior", "HelmondHero",
        "VenloPro", "SittardStar", "OssMaster", "GoesGladiator", "RoosendaalRanger",
        "VlaardingenVictor", "HoornHero", "PurmerendPhoenix", "HeerhugowoardHero", "SchinnenStar",
        "ZwolleZapper", "ZeistZealot", "WeertWarrior", "HilversumHero", "BoxmeerBolt",
        "MeppelMaster", "EmmenElite", "AssenAce", "HeerlenHero", "KerkradeKnight",
        "CulemborgChamp", "NieuwegeinNinja", "KampKnight", "VeendamVictor", "VelsenVictor",
        "HoofddorpHero", "DrachtenDragon", "SneekStar", "FranekerFury", "HarenHero",
        "DoetinchemDestroyer", "HarderwijkHero", "WageningenWarrior", "BarneveldBolt", "RhenenRanger",
        "TielTitan", "GeldermaStar", "WinterswijkWarrior", "BorculoBolt", "GraafschapGladiator",
        "SchiedamStar", "RijswijkRanger", "VoorschotenVictor", "OegstgeestOracle", "LeidschendamLegend",
        "WassenaarWarrior", "KatwijkKnight", "NoorwijkNinja", "RijnsaterwoudeRanger", "HillegomHero"
    ]

    static let switzerlandNames = [
        "ZurichZapper", "GenevaGladiator", "BaselBolt", "BernBeast", "LausanneLegend",
        "WinterthurWarrior", "LucerneLion", "StGallenStar", "LuganoLord", "BielBolt",
        "ThunThunder", "KoenigsfeldKnight", "ChurChamp", "NeuchatelNinja", "VerbierVictor",
        "ZermattZealot", "DavosDestroyer", "InterlakeIce", "MontreuMaster", "FribourgFury",
        "SolothurnStar", "SchaffhausenShark", "SionStar", "BellinzonaBolt", "LocarnoLegend",
        "AarauAce", "OltenOracle", "BadenBeast", "WilWolf", "UsterUltimate",
        "EmmenElite", "KreuzlingenKnight", "UssterUltimate", "DubendorfDragon", "DietikonDestroyer",
        "NyonNinja", "RenensRanger", "VeveyVictor", "MorgesMarauder", "YverdonYeti",
        "ZugZapper", "RapperswilRanger", "HerisuaHero", "AppenzellAce", "GlarusGladiator",
        "AltdorfAlpha", "SarnenStar", "StansSlayer", "SchwyzSword", "FrauenfeldFury"
    ]

    static let norwayNames = [
        "OsloOracle", "BergenBolt", "TrondheimTitan", "StavangerStar", "DrammenDestroyer",
        "FredrikstadFury", "KristiansandKnight", "TromsøThunder", "SandnesSlayer", "SarpsborgSage",
        "SkienShark", "ÅlesundAce", "SandefjordStar", "HaugesundHero", "TønsbergTitan",
        "MossMarauder", "PortsgrunnPhantom", "BodøBeast", "HamarHawk", "LarvikLegend",
        "ArendalAvenger", "KongsvingKnight", "MoldeMonarch", "HaldenHunter", "SteinkjerSword",
        "GjesdalGladiator", "AskøyAce", "LillestrømLion", "NarvikNinja", "HortenHero",
        "FlekkefjordFury", "RånumRanger", "FarsundFalcon", "ElverumElite", "StordStar",
        "EgeroundEagle", "BrekstadBolt", "MandolMaster", "VossViking", "RørosRuler",
        "KirkeneKnight", "HammerfestHero", "VardøVictor", "LongyearbyenLegend", "SvalbardStar",
        "LørenSkogLion", "BærumBolt", "AskerAce", "NittedalNinja", "OppegårdOracle"
    ]

    static let denmarkNames = [
        "CopenhagenCrusher", "AarhuusAce", "OdenseOracle", "AalborgAssassin", "EsbjergElite",
        "RandersRuler", "KoldingKnight", "HorsensHero", "VejlieViking", "RoskildRaider",
        "HerningHawk", "SilkeborgStar", "NæstvedNinja", "FredeciaBolt", "ViborgVictor",
        "KøgeKing", "HolstebroHunter", "TaastrupTitan", "SlagelseSword", "HillerødHero",
        "SønderbergSage", "HjørringHammer", "HolbækBolt", "SkiveStar", "SvendbergSlayer",
        "RingstedRanger", "HaderslevHawk", "BillundBeast", "GrenåGladiator", "ThistedThunder",
        "NykøbingNinja", "StruerStar", "BrøndbyBolt", "GlostrupGhost", "AlbertslundAce",
        "BallerupBeast", "FrederikssundFury", "HelsingørHero", "GentoftGladiator", "LyngbyLion",
        "RødovreRuler", "HvidovreHawk", "IshøjIcon", "GrevGhost", "SolrødStar",
        "FaxeFalcon", "StevnsStorm", "LejreLion", "OdsherredOracle", "KalundborgKnight"
    ]

    static let finlandNames = [
        "HelsinkiHero", "EspooElite", "TampereThunder", "VantaaVictor", "OuluOracle",
        "TurkuTitan", "JyväskyläJet", "LahtiLion", "KuopioKnight", "PoriPhantom",
        "JoensuuJuggernaut", "LappeenrantaLegend", "VaasaViking", "RovaniemiRaider", "SeinäjokiStar",
        "MikkeliMaster", "KotkaKrusher", "SaloSword", "PorvooPhoenix", "KouvoluKing",
        "HyvinääHawk", "KeravaKnight", "JärenpääJester", "NurmijärviNinja", "RaisiRuler",
        "KokkolaChampion", "TuusulaThunder", "KajaaniKnight", "SipoStar", "LohjuLegend",
        "RaumaRanger", "KangasalaKnight", "YlöjärviYeti", "ImtraIntense", "RiihimäkiRuler",
        "NokiaNinja", "VihtiVictor", "SavonlinnaStar", "KauniainenKing", "PirkkalaPhantom",
        "HeinoluHero", "MäntsäläMaster", "HolloluHawk", "ValkeakoskiVictor", "IisalmiIcon",
        "VarkausiViking", "KemiKnight", "TornioThunder", "UlviluUltimate", "AkaaAce"
    ]

    static let polandNames = [
        "WarsawWarrior", "KrakowKnight", "LodzLegend", "WroclawWolf", "PoznanPhantom",
        "GdanskGladiator", "SzczecinStorm", "BydgoszczBeast", "LublinLion", "BialystokBlade",
        "KatowiceKing", "GdyniaGuardian", "CzestochowaChamp", "RadomRaider", "SosnowiecStar",
        "TorunTitan", "KielceKrusher", "GliwiceGhost", "ZabrzaZealot", "BytomBaron",
        "OlsztynOracle", "BielskoBialaBlitz", "RzeszowRanger", "RudaSlaskaRuler", "RybnikRebel",
        "TychyThunder", "DabrowaDemon", "PlocPlague", "ElblagElite", "OpoleOmega",
        "GorzowGiant", "WalbrzychWarden", "ZielnaGoraZephyr", "WloclawekVictor", "TarnowTerror",
        "ChorzowChampion", "KoszalinKnight", "LegnicaLord", "KaliszKommander", "GrunwaldGladiator",
        "PilaProwler", "OstrowiecOracle", "OstrowOrion", "GnieznoGhost", "StargardStar",
        "InowroclawIcon", "PruszkówProwler", "LucznickiLegend", "SlupskSlayer", "SieradzkiSword"
    ]

    static let belgiumNames = [
        "BrusselsBlitz", "AntwerpAce", "GhentGladiator", "BrugesBeacon", "LiegeLion",
        "LeuvenLegend", "NamurNinja", "MonsMarauder", "AalstAvenger", "MechelenMaster",
        "HasseltHawk", "SintNiklaasNova", "KortrijkKnight", "OostendeOracle", "GenkGuardian",
        "RoeselareRaider", "MouscronMystic", "BeverenBeast", "DendermondeDevil", "TurnhoutTitan",
        "LokerenLord", "VilvoordeVictor", "HerentalsHero", "WavreStar", "ArdennesAlpha",
        "SpaStriker", "DinantDynamo", "YpresYeti", "ZeeBruggeZealot", "CharleroiChamp",
        "WaterlooWarrior", "AtomiumAce", "MannekenMaster", "WaffleStar", "ChocolateChamp",
        "DiamondDuke", "FlandersFlash", "WalloniaWolf", "AzureDragon", "BelgianBeast",
        "TinTinTitan", "SmurfsSlayer", "BeerBaron", "FritesFury", "PralinaProdigy",
        "MoulesMaster", "TruffleTerror", "BelgianBolt", "EuropaEagle", "AtomiumOracle"
    ]

    static let swedenNames = [
        "StockholmStar", "GothenburgGladiator", "MalmoMaster", "UppsalaUltra", "VasterasViking",
        "OrebroOracle", "LinkopingLegend", "HelsingborgHawk", "JonkopingJuggernaut", "NorrkopingNinja",
        "LundLion", "UmeaUltimate", "GavleGhost", "BorasBlitz", "SodertaljeSword",
        "EskilstunaEagle", "HalmstadHero", "VaxjoVanguard", "KarlstadKnight", "SundsvallStriker",
        "LuleaLord", "TrollhattanTitan", "OstersundOrion", "SkellefteaStar", "KalmarKrusher",
        "FalunFlash", "KristianstadChamp", "ViktoriaViking", "NordicNinja", "AuroraAce",
        "MidnightSunMaster", "FjordFury", "VikingVanguard", "NorseNova", "SwedishStorm",
        "ArcticAlpha", "BorealisBeast", "RuneRaider", "ThorThunder", "OdinOracle",
        "FreyjaFury", "LokiLegend", "ValhallVictor", "RagnarRuler", "BjornBlade",
        "SigurdStar", "IvarIcon", "LeifLord", "ErikElite", "GustavGuardian"
    ]

    static let austriaNames = [
        "ViennaVictor", "SalzburgStar", "InnsbruckIcon", "GrazGladiator", "LinzLegend",
        "KlagenfurtKnight", "VillachVanguard", "WelsWarrior", "SteyrStriker", "DornbirnDragon",
        "WienerNeustadtNinja", "FeldkirchFlash", "BregenzBeast", "LeobenLord", "KremsKrusher",
        "BadenBaron", "TraunTitan", "AmstettanAce", "KapfenbergKing", "ModlingMaster",
        "LustenauLion", "HalleinHawk", "KufsteinKommander", "BraunauBlitz", "SpittalSword",
        "TelfsThunder", "PerchtoldsdorfPhantom", "WolfsburgWolf", "AlpineAce", "MozartMaster",
        "StraussStar", "KlimtKing", "FreudFury", "SchnitzelSlayer", "StrudelStar",
        "SacherSword", "TirolerTitan", "EdelweissElite", "HabsburgHero", "DanubeDevil",
        "RingRaider", "PraterProwler", "SchonbrunnStar", "BelvedereBlitz", "HofburgHawk",
        "StephansdomStar", "OperaOracle", "WaltzWarrior", "YodelYeti", "ZitherZealot"
    ]

    static let irelandNames = [
        "DublinDragon", "CorkCrusader", "GalwayGladiator", "LimerickLegend", "WaterfordWarrior",
        "KilkennyKnight", "SligoStar", "WexfordWolf", "DroghedaDemon", "DundalkDevil",
        "BrayBeast", "NaasNinja", "SwordsStriker", "AthyAce", "TraleeThunder",
        "KillarneyKing", "EnnisennyElite", "LetterkennyLion", "CarrigalineCrusher", "CelticChampion",
        "ShamrockSlayer", "CloverCommander", "LeprechaunLord", "EmeraldEmperor", "GaelicGiant",
        "TaraThunder", "NewgrangeNinja", "CliffsCrusader", "RingOfKerryRaider", "BlarneybBoss",
        "GuinnessGladiator", "HarpHero", "BodhranBeast", "FiddleFury", "JigJuggernaut",
        "ReelRuler", "CeiliChampion", "OghamOracle", "DruidDragon", "BansheeBlitz",
        "PookaProwler", "SelkieSword", "FomorianFlash", "TuathaTitan", "DanannDestroyer",
        "FiannaFighter", "OisínObliterator", "CúChulainnCrusher", "FionnFury", "BrianBoruBoss"
    ]

    static let portugalNames = [
        "LisbonLegend", "PortoPhoenix", "BragaBeast", "CoimbraChampion", "FunchalFury",
        "SetúbalStar", "AlmadaAce", "AmadoraArcher", "AveirroAvalanche", "LeiriuLion",
        "FaroFlash", "GuimarãesGladiator", "ÉvoraElite", "ViseusVictor", "SantarémSword",
        "VilaNovadeGaiaVanguard", "MatosinhosMaster", "GondomarGhost", "OdivelusOracle", "SintraShadow",
        "CascaisCrusader", "LouresLord", "SeixalStorm", "VillaFrancaViking", "MaiaMonarch",
        "BarreiroBlitz", "OeirasOmega", "RioTintoRaider", "CoroucheConqueror", "PóvoadeVarzimPhantom",
        "PenicheProdigy", "TaviraThunder", "NazaréNinja", "ChelasChampion", "BenficaBoss",
        "SportingSlayer", "BoavistaBrawler", "BelémBlade", "AlfamaAvenger", "BairroAltoBarron",
        "RossioRuler", "ChiadoChief", "EstorilElite", "PrincipeProdigy", "AzoresAce",
        "MadeiraMonarch", "AlgarveAssassin", "AlentejoAvenger", "DouroDevil", "MinhoMaster"
    ]

    static let greeceNames = [
        "AthensAce", "SpartanSlayer", "ThessalonikiThunder", "CreteConqueror", "OlympusOracle",
        "SantoriniStar", "MykonosMonarch", "RhodesRuler", "DelphiDevil", "MeteoraMaster",
        "PatrasPhoenix", "HeraklionHero", "CorinthCrusader", "ArgosAvenger", "NaxosNinja",
        "ZakynthosZealot", "KosKing", "SamosStorm", "LesbosLegend", "ChiosChamion",
        "PeloponnesePhantom", "MacedonianMight", "AegeanAssassin", "IonianInvader", "CycladesChief",
        "PiraeusProdigy", "KalamataKnight", "LarisaLord", "VolosVictor", "KavalaKiller",
        "IoanninaInferno", "XanthiXenith", "DramaDestroyer", "SerreSerpent", "KomotiniKraken",
        "AlexandroupoliArcher", "TrikalaTriton", "LamiaLancer", "ChalkidaChampion", "AgrinionAce",
        "KateriniKing", "VeriaVanguard", "KozaniKnight", "FlorinaPhalanx", "KastelliKrusader",
        "NafplioNemesis", "TripoliTitan", "SpartaShield", "KalavrytaKing", "OlympiaOmega"
    ]

    static let czechiaNames = [
        "PraguePhoenix", "BrnoBlitz", "OstravaOracle", "PlzenProdigy", "LiberecLegend",
        "OlomoucOmega", "BudejoviceBoss", "HradecHero", "ParadiseKnight", "ZlinZealot",
        "KarlovyKing", "HavírovHammer", "KladnoKrusader", "MostMaster", "OpavaOracle",
        "FrydekFury", "KarvinaKiller", "JihlavJudge", "TepliceThunder", "DěčínDevil",
        "ChomutovChampion", "JablonecJuggernaut", "ProstějovPhantom", "PřerovProwler", "CeskéCrusader",
        "TruncovTitan", "OrlovaObliterator", "VsetinVictor", "KromerizKnight", "ValašskéVanguard",
        "BerounBrawler", "KolinKonqueror", "PísekPhoenix", "TáborTerror", "ChebChief",
        "TreboňThrasher", "LitomericeLion", "ÚstíUltimate", "SokolovSword", "RakovnikRuler",
        "BenešovBeast", "PribramProwler", "MladáMaverick", "NymburkNinja", "KutnaKnight",
        "ChrudimChampion", "SvitavyStar", "ŽďárZenith", "TřebíčTitan", "VyškovViking"
    ]

    static let romaniaNames = [
        "BucharestBoss", "ClujCrusader", "TimișoaraThunder", "IașiImpact", "ConstanțaCrush",
        "BrașovBrawler", "CraiovaCyclone", "GalațiGladiator", "PloieștiPhoenix", "OradeaOracle",
        "BrăilaBlitz", "AradAce", "PiteștiProwler", "SibiuSword", "BacăuBeast",
        "TârguMureșMaverick", "BuzăuBolt", "BotoșaniBlade", "SatuMareStar", "RâmnicuVâlceaViking",
        "SuceavaStrike", "PiatraNeamțNinja", "DrobetaTitan", "TârguJiuJudge", "TârgovișteTerror",
        "FocșaniFury", "MediașMaster", "LugojLegend", "DevaDynamo", "HunedoaraHammer",
        "AlbaIuliaAssault", "BistrițaBandit", "ReșițaRuler", "ZalăuZealot", "SfântuGheorgheGhost",
        "MiercureaCiucMystic", "VatraDorneiVanguard", "CâmpulungChampion", "SighișoaraSniper", "AiudAvenger",
        "SebeșStorm", "BlajBlaze", "PetroșaniPower", "VulcanVengeance", "LupeniLancer",
        "CaransebeșCobra", "OravițaOverlord", "MoldovaNouăNova", "OțeluRoșuOmega", "BăileHerculaneHero"
    ]

    static let malaysiaNames = [
        "KLKingpin", "PenangPhoenix", "JohorJuggernaut", "SarawakStrike", "SabahSword",
        "MalaccaMaverick", "IpohImpact", "KuchingCrusader", "KotaKinabaluKnight", "SelangorStar",
        "PutrajayaProwler", "CyberjayaCyclone", "PetalingJayaPhoenix", "SubangSurge", "ShahAlamShield",
        "KlangKrusader", "AmpangAce", "CherasChampion", "BukitBintangBoss", "BangsarBlade",
        "DamansaraDynamo", "SerdangStorm", "RawangRuler", "KajangKiller", "SemenyihSniper",
        "SerembanSentry", "MuarMaster", "SegamatSaber", "KluangKobra", "BatuPahatBolt",
        "KuantanKnight", "TemerlohThunder", "BentongBrawler", "KualaTerengganuTitan", "DungunDevil",
        "KotaBharuBlitz", "PasiMasPhantom", "AlorSetarAssault", "SungaiPetaniStar", "KangarKnight",
        "GeorgeTownGladiator", "ButterWorthBeast", "TaipingTerror", "LumutLancer", "SitiawanShadow",
        "MiriMystic", "SibuSorcerer", "BintuluBandit", "SandakanSentry", "TawauTornado"
    ]

    static let newZealandNames = [
        "AucklandAce", "WellingtonWarrior", "ChristchurchCrusader", "HamiltonHammer", "TaurangaTitan",
        "DunedinDynamo", "PalmerstonNorthPhoenix", "NapierNinja", "NelsonNova", "RotoruaRuler",
        "NewPlymouthNemesis", "WhangāreiWarden", "InvercargillImpact", "WhanganūiWolf", "GisborneGladiator",
        "BlenheimBlade", "TimaruThunder", "TaupōTerror", "MastertonMaverick", "LevinLancer",
        "GreymouthGhost", "WaitakerēWarden", "ManawatuMystic", "KāpitīKnight", "PōrīruaProwler",
        "UpperHuttUltimate", "LowerHuttLegend", "QueenstownQuake", "WanakaWolf", "OamaruOracle",
        "AshburtonAssault", "RangiōrāRanger", "KaikōuraKing", "HokitīkaHero", "TeAwamutuTornado",
        "CambridgeCyclone", "MatamataMarauder", "ThamesTorrent", "WaiūkūWarden", "PapakuraPhantom",
        "MangereMonarch", "TakāpunaTiger", "DevonportDevil", "BirkenheadBoss", "HendersonHawk",
        "AvondaleAce", "MtAlbertMaster", "PonsonbyProwler", "RemueraStar", "EpsomElite"
    ]

    static let hungaryNames = [
        // 1-30: Major cities
        "BudapestBoss", "DebrecenDynamo", "SzegedStriker", "MiskolcMaster", "PecsPhoenix",
        "GyorGladiator", "NyiregyhazaNinja", "KecskeметKnight", "SzekesfehervarStar", "SzombathelyStorm",
        "EgerEagle", "TatabanyaTitan", "KaposvarKing", "ZalaegerszegZealot", "VeszpremViking",
        "BekescsabaBlaze", "SzolnokSurge", "DunaujvarosDagger", "HodmezovasarhelyHawk", "SopronSentinel",
        "EsztergomElite", "SiofokSniper", "GodolloGuardian", "CegledCrusader", "OroshazaOracle",
        "HajduszoboszloHero", "KiskunfelegyházaKnight", "MosonmagyarovarMaven", "BalmazujvarosBlade", "MezokovesDiamond",
        // 31-60: More cities and regions
        "DunakesziDragon", "BudaorsBlitz", "SzentendreShield", "VacVanguard", "PapaProtector",
        "AjkaAssassin", "KomloKestrel", "OzdOutlaw", "SalgotarjanSavage", "GyongyosGriffin",
        "BalatonBrawler", "TokajTitan", "HevizHero", "SzarvasSniper", "KeszthelyKrusher",
        "MohacsMarauder", "PaksPunisher", "TiszaujvarosTornado", "KazincbarcikaKing", "HatvanHawk",
        "GyulaGladiator", "MakoMaster", "OrosházaOmen", "BajaBoss", "KalocsaKestrel",
        "SzekszardSurge", "DombóvárDemon", "TamásiThunder", "BonyhádBlade", "PaksiPro",
        // 61-90: Hungarian landmarks and culture
        "DanubeDefender", "TiszaTornado", "BalatonBlitz", "MatraMarauder", "BükkBrawler",
        "TokajTerror", "HortobagyHero", "AggtelekAce", "TihanyTitan", "GöödöGuard",
        "ViseградVictor", "SzépasszonyValleyViper", "HősökSquareHero", "FishermansBastion", "ChainBridgeChampion",
        "ParliamentProwler", "MatthiasKingdom", "BudaCastleBoss", "HeroesSquareHawk", "ThermalTitan",
        "PusztaPhoenix", "GulashGladiator", "PaprikaPhenom", "TokajiTerror", "PalinkaPro",
        "CsardasChampion", "MajarMaster", "HusarHero", "SzentIstvanStar", "ArpadAvenger",
        // 91-120: Hungarian names
        "AttilaAce", "BelaBoss", "CsabaChampion", "DenesDestroyer", "EmilElite",
        "FerencFlash", "GaborGladiator", "HunorHero", "IstvanIcon", "JanosJuggernaut",
        "KárolyKnight", "LászlóLegend", "MátyásMaster", "NándorNinja", "OttóOutlaw",
        "PéterProwler", "RichardRaider", "SándorSurge", "TamásTitan", "VilmosViking",
        "ZoltánZealot", "ÁkosAssassin", "BarnabásBlade", "DánielDragon", "EndreEagle",
        "FlórianFury", "GergelyGriffin", "HenrikHawk", "ImreIronman", "KristófKestrel",
        // 121-150: More unique names
        "LeventeLeader", "MarcellMaverick", "NorbertNova", "OlivérOracle", "PatrikPaladin",
        "RóbertRuler", "SzabolcsSentinel", "TiborThunder", "VinceVanguard", "AdámAvalanche",
        "BenceBlaze", "CsanádCrusader", "DávidDefender", "ErikEclipse", "FülöpFalcon",
        "GusztávGuardian", "HubertHurricane", "IvánImpact", "KonrádKing", "LorándLion",
        "MiklósMenace", "NikolaszNinja", "OszkarOmen", "PálPhoenix", "RudolfRaptor",
        "SebestyénStrike", "TivadarTornado", "UrbánUltimate", "VendélViper", "ZénóZephyr"
    ]

    static let thailandNames = [
        "BangkokBoss", "ChiangMaiChamp", "PhuketPhoenix", "PattayaProwler", "KrabiKnight",
        "SuratThaniStar", "KhonKaenKing", "HatYaiHero", "NakhonRatchasimaNinja", "UdonThaniUltimate",
        "ChiangRaiRaider", "SamutPrakanStriker", "AyutthayaAce", "LopburiLegend", "SukhothaiSentinel",
        "KanchanaburiKestrel", "RayongRuler", "SongkhlaSniper", "TrangTitan", "PhangNgaPhantom",
        "NonthaburiNinja", "PathumThaniProtector", "NakhonPathomNovice", "SamutSakhonSurge", "RatchaburiRanger",
        "PrachuapKhiriKhanPro", "ChumphonCrusader", "RanongRaider", "TakTornado", "MaeHongSonMaster",
        "LampangLion", "LamphunLancer", "PhitsanulokPhoenix", "PhichitPioneer", "PhetchabunProwler",
        "NakhonSawanNinja", "KamphaengPhetKnight", "UthaithaniUltimate", "ChaiNatChampion", "SingBuriStar"
    ]

    static let uaeNames = [
        "DubaiDynamo", "AbuDhabiAce", "SharjahSultan", "AjmanAvenger", "FujairahFalcon",
        "RasAlKhaimahRaider", "UmmAlQuwainUltimate", "AlAinAssassin", "JebelAliBoss", "PalmJumeirahPro",
        "BurjKhalifaKing", "MarinaMarauder", "JumeirahJuggernaut", "DeiraDominator", "BarshaBeast",
        "KhorFakkanKnight", "DibbaDemon", "HattaHero", "MadinatZayedMaster", "LiwaLegend",
        "RuwaisRuler", "GhayathiGladiator", "MirfaMarvel", "SilaSentinel", "DalmaDefender",
        "MasfoutMaestro", "MunayMaverick", "FiliPhenom", "SwehanStriker", "RemahRanger",
        "AlWathbaWarrior", "AlShamkhaShark", "AlReemRaider", "AlMaryahMaster", "YasIslandYeti",
        "SaadiyatSurge", "AlRahaRaptor", "MusaffahMenace", "KhalidiyaKestrel", "AlBateenBoss"
    ]

    static let philippinesNames = [
        "ManilaMaster", "CebuChampion", "DavaoDestroyer", "QuezonQuester", "MakatiMaverick",
        "BoracayBoss", "PalawanPhoenix", "BaguioBlitz", "IloiloIcon", "BacolodBeast",
        "TaguigTitan", "PasigProwler", "CaviteConqueror", "LagunaLegend", "BatangasBrawler",
        "PampangaPro", "BulacanBlade", "RizalRaider", "ZamboangaZealot", "GeneralSantosGladiator",
        "AngelesAce", "OlongapoOutlaw", "LucenaLion", "NagaNinja", "LegazpiLancer",
        "TaclobanThunder", "IligianIronman", "ButuanBomber", "CotabatoCommander", "DipologDragon",
        "DumagueteDynamo", "RoxasRanger", "SanFernandoStorm", "CalambaChampion", "TarlacTornado",
        "VigianViking", "LaogLightning", "SanPabloSurge", "MalolosMenace", "MeycauayanMarauder"
    ]

    static let andorraNames = [
        "AndorraAce", "PyreneesPro", "EscaldesElite", "LaVellaVictor", "EnampChamp",
        "CanilloConqueror", "OrdoOutlaw", "PasHousePhenix", "SantJuliaStar", "MassanaMaster",
        "AndorranAlpha", "VallnordViper", "GrandvaliraGod", "SoldeuStriker", "ArinsiArtist",
        "CaldeaCrusher", "NaturlandNinja", "PalPeakPro", "ArcalisAvenger", "EngolastrElite",
        "MeritxellMaven", "SisconySurge", "FontaneraForce", "RansotRaider", "InclesStar",
        "AnyvialAce", "LlortLegend", "CortalsChamp", "GrauRoigGamer", "BordesDestrier",
        "PeafonPower", "TosaPhenix", "ErmitaEagle", "RocDelQueRuler", "ComaMaster",
        "SolanaSpirit", "AubinuAccess", "CampClaror", "LlumenRexLord", "VallDeMadriu"
    ]

    static let indonesiaNames = [
        // 1-30: Major cities
        "JakartaJuggernaut", "BaliBlaster", "SurabayaStar", "BandungBoss", "MedanMaster",
        "SemarangSurge", "MakassarMaverick", "PalembangPro", "TangerangTitan", "DepokDestroyer",
        "BekasiBlitz", "YogyakartaYeti", "SoloStriker", "MalangMenace", "PadangPhenix",
        "DenpasarDemon", "BogorBeast", "BatamBomber", "PekanbaruPower", "BanjarmasinBrawler",
        "PontianakProwler", "CirebonChamp", "SamarindaSlayer", "SerangSerpent", "TasikmalayaTiger",
        "KediriKnight", "SukabumiShadow", "PurwakartaPro", "TegalTornado", "KlatenKing",
        // 31-60: More cities and regions
        "KarawangKrusher", "JambiJumper", "KupangKiller", "MataramMaestro", "LampungLegend",
        "AmbonAce", "ManadoMachine", "JayapuraJuggernaut", "PaluPunisher", "KendariKrusher",
        "GorontaloGladiator", "TernateThunder", "BauBauBerserker", "BitungBlaster", "TomohonTerror",
        "RajaAmpatRaider", "KomodoKing", "BromoBlitzer", "PrambananPro", "BorobudurBoss",
        "NusaDuaNinja", "UbudUltimate", "SanurStar", "KutaKrusher", "SeminyakSlayer",
        "GiliGod", "LombokLegend", "FloresFlash", "SumbaStriker", "WakatobiWarrior",
        // 61-90: Landmarks and culture
        "BunakenBeast", "TorajaThunder", "TanaToraja", "DiengDemon", "KarimunKrusher",
        "BelitungBlaster", "BangkaBoomer", "RiauRaider", "AcehAvenger", "NiasNinja",
        "MentawaiMaster", "PadangProdigy", "BukittingiBoss", "PayakumbuhPower", "SolokStar",
        "JavaJaguar", "SumatraStorm", "KalimantanKing", "SulawesiStar", "PapuaProwler",
        "MoluccasMaster", "NusaTenggaraNinja", "IndonesiaIcon", "GarudaGamer", "BatikBaron",
        "WayanWarrior", "KetutKing", "NyomanNinja", "PutuPro", "KadekKrusher",
        // 91-120: Indonesian names
        "RizkyRaider", "BudiBlaster", "AgusAce", "DwiDestroyer", "EkoPro",
        "FahriFlash", "GunturGod", "HendraHero", "IwanImpact", "JokoJuggernaut",
        "KrisnaKnight", "LukmanLegend", "MadesMaverick", "NurdinNinja", "OscarOutlaw",
        "PrasetyaPro", "QuinnQuake", "RahmatRuler", "SantosoStar", "TeguhTitan",
        "UmarUltimate", "VincentVictor", "WahyuWarrior", "XavierXtreme", "YusufYeti",
        "ZainalZenith", "ArdiAce", "BambangBoss", "CahyaChamp", "DediDemon",
        // 121-150: More unique names
        "EndangElite", "FerdiFlame", "GalihGladiator", "HariHawk", "IndraIcon",
        "JayaJolt", "KurniawanKrusher", "LintangLightning", "MulyaMaster", "NugrahaNoble",
        "OmegaOrang", "PutraPhenix", "RakaRaptor", "SuryaSerpent", "TriTornado",
        "UtamaUltimate", "ViraViper", "WidodoWolf", "YudhiYakuza", "ZakiZephyr",
        "AnggaAssassin", "BarunaBlaze", "CakraChampion", "DarmaDynamo", "ErlangaEagle",
        "FajarFury", "GatotGiant", "HanomanHero", "IskandarIce", "JatayuJumper"
    ]
    
    static let southAfricaNames = [
        // 1-30: Major cities
        "JohannesburgJuggernaut", "CapeTownChamp", "DurbanDestroyer", "PretoriaPro", "PortElizabethPhenix",
        "BloemfonteinBoss", "EastLondonElite", "NelspruitNinja", "PietermaritzburgPower", "PolokwaneProwler",
        "KimberleyKing", "RustenburgRaider", "WitbankWarrior", "VereenigingVictor", "WelkomWolf",
        "MidrandMaster", "SandtonStar", "SowetoSurge", "TembisaTitan", "UmlaziBeast",
        "ChatsworthChamp", "MitchellsPlainMaverick", "KhayelitshaKrusher", "MamelodiBrawler", "TownsshipTerror",
        "BoksburgBlaster", "BenoniBoomer", "KemptomParkKnight", "RandburgRuler", "RoodepoortReaper",
        // 31-60: More cities and regions
        "CenturionCrusader", "MidvaalMenace", "UpingtonUltimate", "MusinaMaster", "TzaneenTornado",
        "GeorgeGladiator", "MosselBayMachine", "KnysnaNinja", "HermanusHero", "StellenboschStar",
        "PaarlPunisher", "FranschhoekFlash", "WorcesterWarrior", "BredasdorpBoss", "SwellendamSlayer",
        "GrahamstownGod", "UitenhageUltimate", "GraaffReinetGamer", "BeaufortWestBeast", "OudtshoornOutlaw",
        "SpringbokStar", "AlexanderBayAce", "SaldanhaSerpent", "VelddrielVictor", "LadybrandLegend",
        "HarrissmithHawk", "BethlehemBlitzer", "QwaqwaQuake", "MafekingMaster", "VryburgViking",
        // 61-90: Landmarks and culture
        "KrugerKing", "TableMountainTitan", "RobbenIslandRaider", "DrakensbergDemon", "GardenRouteGod",
        "WildCoastWarrior", "BigHoleBoss", "CradleOfHumankind", "BlydeCanyonBeast", "AugrabesFallsAce",
        "NelsonMandelaBay", "ShakaStar", "ZuluZephyr", "XhosaXtreme", "SothoStriker",
        "TswanaTornado", "VendaVictor", "NdebeleeNinja", "PediPhenix", "SwaziBrawler",
        "ProteasPro", "SpringbokSlayer", "BafanaBoss", "AmaBokBeast", "StormersStrike",
        "BullsBlaster", "LionsLegend", "SharksShredder", "ChelseaCrusher", "KaizerChiefKing",
        // 91-120: South African names
        "ThaboThunder", "SiphoStar", "MandlasMaverick", "BonganiBoss", "LethaboraLegend",
        "NomvulaNinja", "ZaneleZenith", "ThandiweTitan", "SiyandaSurge", "AneleBrawler",
        "BlessingsBlaster", "ChipoChamp", "DumisaniDestroyer", "EnoEagle", "FikileFury",
        "GiftGladiator", "HlobiHawk", "InnocentImpact", "JabulaniJuggernaut", "KabeloKnight",
        "LeboLightning", "MphoMaster", "NhlanhlaNinja", "OratoOutlaw", "PreciousPhenix",
        "QuincyQuake", "ReyaanRaptor", "SamkelSerpent", "TumeloTornado", "UnamiUltimate",
        // 121-150: More unique names
        "VusiViking", "WandileWolf", "XolaXtreme", "YolandaYeti", "ZikhonZephyr",
        "AgripaAce", "BudaBoomer", "ChristoCrusader", "DuduDestroyer", "EskomElite",
        "FaniFire", "GabiGamer", "HennieHero", "IviImpact", "JanJumper",
        "KoketsoKing", "LindiweLegend", "MashuduMaster", "NeoNinja", "OdwaProwler",
        "PetyaPhenix", "RethabilRaider", "SizweStar", "ThamiTitan", "UbuntuUltimate",
        "VuyaniVictor", "WilliamWolf", "XabisaXtreme", "YokoYakuza", "ZamaniZenith"
    ]

    static let kenyaNames = [
        // 1-30: Major cities and towns
        "NairobiNinja", "MombasaMaster", "KisumuKing", "NakuruNova", "ElDoretElite",
        "ThikaTitan", "MalindiMaverick", "KitaleProwler", "GarissaGladiator", "NyeriNinja",
        "MeruMaster", "LamuLegend", "NaivashaNinja", "KerichoKnight", "NanyukiNova",
        "EmbuElite", "IsioloImpact", "VoiVictor", "WajirWarrior", "ManderaMarvel",
        "MachakosMonarch", "KajiardoKrusher", "NavishaNavigator", "RuiruRaider", "JujaJuggernaut",
        "AthrRiverAce", "SyokimauStar", "KongowaKnight", "MtwapaMaverick", "DianiBoss",
        // 31-60: Landmarks and geography
        "MountKenyaMaster", "RiftValleyRaider", "MaasaiMaraMenace", "AmboseliBoss", "TsavoTornado",
        "LakeNakuruLegend", "LakeVictoriaViking", "NairobiParkNinja", "HellsGateHero", "GreatRiftGod",
        "KilimanjaroKing", "MauForestFury", "AberdareBeast", "TurkanaTracker", "SamburuStar",
        "NgoroNgoroPro", "OlPejetaOutlaw", "MeruParkMaster", "ShimbaHillsHero", "WatamuWolf",
        "MalindiMarineMaster", "KisiteStar", "TanaRiverTitan", "GalanaGamer", "MtElgonElite",
        "ChalbiDesertChamp", "MarsabitMaster", "LoiyangalaniLegend", "CentralIslandCrusader", "SouthIslandStar",
        // 61-90: Wildlife and culture
        "SimbaStrike", "CheetahChaser", "ElephantElite", "RhinoRaider", "BuffaloBoss",
        "LeopardLegend", "GiraffaGamer", "ZebraZenith", "HippoBrawler", "CrocodileCrusher",
        "MaasaiWarrior", "KikuyuKing", "LuoLegend", "KalenjinKnight", "KambaMaster",
        "SwahiliStar", "MauMauMenace", "SafariSurge", "HakunaMatata", "JamboJuggernaut",
        "PolepoleProdigy", "AsanteAce", "HarambeeHero", "UhuruUltimate", "TuskerTitan",
        "NyamaNinja", "ChapatiChamp", "UgaliUltimate", "MandaziMaster", "SukumaWikiStar",
        // 91-120: Kenyan names
        "WanjiruWarrior", "KipchogeLegend", "OmondiOmega", "KamauKrusher", "NjorgeNinja",
        "AkinyiBoss", "CheruiyotChamp", "WaweruWolf", "MuthuriMaverick", "NyamburiNova",
        "OtienoOutlaw", "WekesaBeast", "KibakiKnight", "KiplagratKing", "TanuiTornado",
        "ChebetChaser", "RotichRaider", "KosgeiGladiator", "JepkosgeiJumper", "SumgongStar",
        "WanjikuWunder", "MwangiMaster", "KimaniKnight", "GathuniaGamer", "NyokobiBoss",
        "MbugaaMaverick", "MuthoniMonarch", "KaranjaKrusher", "NjuganaNinja", "WaithakiWarrior",
        // 121-150: More cultural references
        "BombololuBoss", "KariobangiKing", "KiberaKnight", "MathareMarvel", "UmojaUltimate",
        "EasternExplosion", "KamukunjiKrusher", "WestlandsWolf", "KarenKnight", "LangataMaster",
        "KilimaniKing", "LavingtonLegend", "SpringValleyStar", "ParklandsProdigy", "MuthaigaMaster",
        "AthiRiverAce", "MlolongoMaverick", "KitengalaKnight", "NguniNinja", "MaaiMahiuMaster",
        "NarokNinja", "BogariaBlaster", "BaringoBoss", "NaivashaNova", "GilgilGladiator",
        "ThomsonFallsTitan", "NyahururuNinja", "RumurutiRaider", "MaralalMaster", "LodwarLegend"
    ]

    static let fijiNames = [
        // 1-30: Cities and towns
        "SuvaStar", "NadiNinja", "LautokeLegend", "BaMaster", "LabasaBoss",
        "SavusavuSurge", "SigatokaSlayer", "NausoriNova", "PacificHarbourPro", "NavuaNinja",
        "RakirakiRaider", "TavuaTitan", "KorovoWarrior", "NasoroMaverick", "DeubaMaster",
        "VailekaBoss", "NamakaNinja", "MartinarKnight", "WailoaloanWarrior", "SuvaPointPro",
        "DominionBoss", "KingsRoadKing", "QueensRoadQuake", "NabouaElite", "LamiFury",
        "CunningStarFiji", "SamoaBayStar", "VunidawaTitan", "KoroleveKnight", "NamosiBoss",
        // 31-60: Islands and geography
        "VitiLevuViking", "VanuaLevuVictor", "TaveuniTornado", "KadavuKrusher", "YasawaYakuza",
        "ManamucaMaster", "BeqaBlaster", "OvalauOutlaw", "RotumaRaider", "GauGladiator",
        "KoroKnight", "MoalaMaster", "LakenbaLegend", "VanuaBalavuVictor", "NaveeniNavy",
        "CoralCoastCrusher", "SuncoastStar", "CloudBreakChamp", "NamukaIslander", "TobereDrifter",
        "WayaWarrior", "NavitiNinja", "DravuniDemon", "ManaMarvel", "TreasureIslandTitan",
        "BlueLogoonBoss", "SabetoBrawler", "NausalaCaptain", "NausoriFlatsFury", "ColomiBrawler",
        // 61-90: Culture and nature
        "BulaBrawler", "KavaKing", "MekeMaster", "LovoLegend", "TapaTracker",
        "TabuaPower", "KerekereKnight", "SuluStar", "VinakaNinja", "SevensStar",
        "RugbyRaider", "ScummyCrusher", "DrauniviNinja", "MasiMaster", "YaqonaYield",
        "TanooaTitan", "WarriorFiji", "IslandBreezeElite", "PalmTreePro", "CoconutCrusher",
        "ReefRider", "LagoonLegend", "TropicTitan", "SunriseSlayer", "TidalTornado",
        "MangroveMarvel", "RainforestRuler", "WaterfallWarrior", "VolcanoVictor", "CoralReefKing",
        // 91-120: Fijian names and rugby players
        "TuisovaStar", "SeruSerpent", "NakarawaNinja", "VolavolaVictor", "RaukuruRaider",
        "MatawaquMaster", "BotiaBlaster", "RadradraRocket", "NaiqamaKnight", "VunipopaBoss",
        "KunataniBrawler", "VoceViking", "GonevaOmega", "TuisamoaStar", "NaivilawaseNinja",
        "SawaStar", "RatuRuler", "AdiAce", "TuiTornado", "QolikoBoss",
        "SailasiSlayer", "KiniKnight", "VilimoniVictor", "TevitaTitan", "IsakeImpact",
        "MesakeMarvel", "EpeliBrawler", "JoelJuggernaut", "WaisaleWarrior", "ManasaMaster",
        "LagiLegend", "DrekiDemon", "NatoaNinja", "MakareKnight", "WainiMaster",
        "SigatokaStar", "NausoriBoss", "VitiViking", "VanuaVictor", "PacificProwler",
        "FijianFirewalker", "IslandInfinite", "AlohaAce", "MoanaMarvel", "OceanOrbit",
        "TidelineTitan", "SeastormStar", "AquariusAce", "PoseidonPro", "NeptuneBoss",
        "LagoonLord", "BarrierBoss", "CurrentCrusher", "SurfSerpent", "WaveMaster",
        "PearlProwler", "ShellShock", "TurtleTitan", "DolphinDynamo", "WhaleWarrior"
    ]

    // Vietnam names for leaderboard
    static let vietnamNames = [
        // 1-30: Major cities
        "HanoiHero", "SaigonStriker", "DaNangDynamo", "HueHawk", "HaiPhongPhoenix",
        "CanThoCommander", "NhaTrangNinja", "DaLatDagger", "VungTauViking", "QuiNhonQuake",
        "BienHoaBlaze", "MyThoMaster", "LongXuyenLion", "RachGiaRaptor", "PhanThietPro",
        "HoiAnAce", "SaPaSentinel", "BacNinhBlade", "ThaiNguyenThunder", "TuyHoaTitan",
        "PhuQuocPhantom", "VinhVanguard", "TamKyKnight", "NamDinhNova", "HaLongHunter",
        "DongHoiDragon", "QuangNgaiGuardian", "KonTumKestrel", "BuonMaThuotBoss", "SocTrangSniper",
        // 31-60: More cities and regions
        "CaMauCrusader", "TraVinhTornado", "ThaiBinhTactician", "HungYenHorizon", "HaDongDestroyer",
        "ThuDucThrasher", "GoVapGladiator", "BinhDuongBrawler", "DongNaiNemesis", "BaRiaBarrage",
        "PhuYenProwler", "LamDongLancer", "GiaLaiGriffin", "DakLakElite", "BinhThuanBlast",
        "NinhThuanNova", "KhanhHoaKing", "QuangNamQuest", "ThuaThienTiger", "QuangBinhBolt",
        "HaTinhHammer", "NgheAnOracle", "ThanhHoaThrone", "HoaBinhHunter", "SonLaSurge",
        "LaoCaiLegend", "YenBaiYeti", "PhuThoPhenom", "VinhPhucVictor", "BacGiangBullet",
        // 61-90: Vietnamese culture and landmarks
        "MekongMaverick", "RedRiverRogue", "DragonBayDefender", "LotusLancer", "PhoenixPagoda",
        "JadeMountain", "SilkRoadSniper", "LanternLegion", "BambooBlitz", "TurtleTower",
        "GoldenBridge", "MarbleMountain", "PerfumeRiverPro", "ImperialKnight", "CuChiChampion",
        "SapaStorm", "HaGiangGhost", "FansipanFury", "CatBaCaptain", "TrangAnTitan",
        "PhongNhaPhantom", "BaiDinhBlade", "TamCocCrusader", "NinhBinhNinja", "HoChiMinhHero",
        "DienBienDagger", "SonDoongSurge", "CaoDaiKnight", "MuiNeMaster", "DalAtDragon"
    ]

    // Curaçao names for leaderboard
    static let curacaoNames = [
        // 1-30: Major areas and landmarks
        "WillemstadWarrior", "PundaPro", "OtrobandaOracle", "PietermaaiPhantom", "HandelskadHero",
        "MamboBeachMaster", "KnipBayKnight", "CasAbaoCrusader", "PortoMariProwler", "SheteBokaStorm",
        "ChristoffelChamp", "HatoCavesHunter", "RifFortRogue", "FloatingBridgeFury", "PlayaFoitiKing",
        "BarberBlitz", "JanThielJaguar", "BlueBayBlade", "SpanseWaterSniper", "TulembaTop",
        "WestpuntWolf", "LagunLancer", "BandaBowBoss", "SantaMartaBite", "ZuurzakZone",
        "BullenbaaiBlast", "DaaibooiBrawler", "KleinCuracaoCrush", "GroteKnipGuard", "PlayaKenepaKick",
        // 31-60: Culture and nature
        "DushiDagger", "PapiamentuPower", "CarnivalCaptain", "TumbaThunder", "KasdiPalPalm",
        "LandhouseLeader", "IgnuanaIsland", "FlamingoFrenzy", "CoralCastleCrew", "TurtleNestNinja",
        "BocaTableBoss", "MikveIsraelMastr", "QueenEmmaBridge", "FortAmsterdam", "NationalParkPro",
        "SeaquariumStar", "FloraFaunaFury", "DolphinAcademy", "CuracaoLiqueur", "PlasaByeuPunch",
        "ScharloStrike", "SundialShogun", "RondeFortRider", "MontagnaSentry", "SavaneSlayer",
        "AscensionTower", "BriefjesBrigade", "TafelbergTitan", "AquaElixir", "ChoboloBeast",
        // 61-90: More local flavor
        "BocaSamiBlitz", "PlayaPortoMari", "SantaCruzSnipe", "WilheminaWarden", "BreezeParadise",
        "BientuBayBolt", "CuracaoKing", "DiviDiveDevil", "TropicTsunami", "SunsetSurfer",
        "ArawakAce", "CaquetioChief", "WatamulaMaster", "NorthSeaNinja", "CaribCoastCrew",
        "LeewardLegend", "WindwardWolf", "ReefRanger", "MangroveMaestro", "PelicanPoint",
        "ParrotProwler", "IguanaImperial", "ConchConqueror", "StarfishStrike", "CoralKnight",
        "TradewindTitan", "PassaatPuncher", "HarborHawkeye", "GulfstreamGhost", "IslandInferno"
    ]

    static let countries = ["JP", "BR", "PK", "DE", "UZ", "IN", "FR", "GB", "LB", "CA", "AU", "KR", "MX", "IT", "ES", "NL", "CH", "NO", "DK", "FI", "PL", "BE", "SE", "AT", "IE", "PT", "GR", "CZ", "RO", "MY", "NZ", "HU", "TH", "AE", "PH", "ID", "ZA", "US", "CN", "RU", "NG", "EG", "AR", "CL", "CO", "PE"]

    // Seeded random for consistent daily results
    static func seededRandom(seed: Int, index: Int) -> Double {
        var state = UInt64(seed &+ index &* 2654435761)
        state = state &* 6364136223846793005 &+ 1442695040888963407
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state & 0x7FFFFFFF) / Double(0x7FFFFFFF)
    }

    // Get milestone index for a player on a given day
    static func milestoneIndex(for playerIndex: Int, baseIndex: Int, day: Int) -> Int {
        // Each player progresses at different rates based on their "skill"
        // Use modulo to cycle days so progression doesn't go to infinity
        let cycleDays = day % 100  // Reset every 100 days
        let progressRate = seededRandom(seed: playerIndex * 1000, index: 0)
        let dailyProgress = progressRate * 0.3 + 0.1 // 0.1-0.4 milestones per day
        let totalProgress = Int(Double(cycleDays) * dailyProgress)

        let newIndex = baseIndex + totalProgress
        return min(newIndex, allMilestones.count - 1)
    }

    // Check if player reached infinity
    static func hasReachedInfinity(playerIndex: Int, day: Int) -> Bool {
        let baseIndex = allMilestones.count - 100 + playerIndex // Top players start near end
        let currentIndex = milestoneIndex(for: playerIndex, baseIndex: baseIndex, day: day)
        return currentIndex >= allMilestones.count - 1 // Reached 873bz or beyond
    }

    // Get infinity tile count for Hall of Fame players
    static func infinityCount(for playerIndex: Int, day: Int) -> Int {
        // Base count + daily progression
        let baseCount = max(1, 50 - playerIndex)
        let dailyGain = seededRandom(seed: playerIndex * 500, index: day)
        let extraTiles = Int(Double(day) * dailyGain * 0.5)
        return baseCount + extraTiles
    }

    // MARK: - Extended Brackets Access for Rank Preview

    /// Global extended brackets (uses US as representative for global leaderboard)
    static var globalExtendedBrackets: [(milestone: String, startRank: Int)] {
        LeaderboardClient.usExtendedRankBrackets
    }

    /// Hall of Fame extended brackets
    static let hallOfFameExtendedBrackets: [(milestone: String, startRank: Int)] = [
        // Top tier (infinity and beyond)
        ("1an", 1), ("693am", 3), ("346am", 5), ("173am", 8),
        ("86am", 12), ("43am", 18), ("21am", 25), ("10am", 35),
        // High alphabetic tiers
        ("1am", 50), ("676al", 70), ("338al", 95), ("169al", 125),
        ("1al", 160), ("661ak", 200), ("330ak", 250), ("165ak", 310),
        ("1ak", 380), ("645aj", 460), ("322aj", 550), ("161aj", 650),
        ("1aj", 760), ("630ai", 880), ("315ai", 1010), ("157ai", 1150),
        ("1ai", 1300), ("615ah", 1460), ("307ah", 1630), ("153ah", 1810),
        ("1ah", 2000), ("1B", 2200), ("536M", 2400)
    ]

    /// Get extended brackets for a specific country code
    static func extendedBrackets(for countryCode: String) -> [(milestone: String, startRank: Int)] {
        switch countryCode {
        case "US": return LeaderboardClient.usExtendedRankBrackets
        case "GB": return LeaderboardClient.ukExtendedRankBrackets
        case "CA": return LeaderboardClient.canadaExtendedRankBrackets
        case "AU": return LeaderboardClient.australiaExtendedRankBrackets
        case "DE": return LeaderboardClient.germanyExtendedRankBrackets
        case "FR": return LeaderboardClient.franceExtendedRankBrackets
        case "JP": return LeaderboardClient.japanExtendedRankBrackets
        case "IN": return LeaderboardClient.indiaExtendedRankBrackets
        case "BR": return LeaderboardClient.brazilExtendedRankBrackets
        case "MX": return LeaderboardClient.mexicoExtendedRankBrackets
        case "AF": return LeaderboardClient.afghanistanExtendedRankBrackets
        case "AL": return LeaderboardClient.albaniaExtendedRankBrackets
        case "DZ": return LeaderboardClient.algeriaExtendedRankBrackets
        case "CN": return LeaderboardClient.chinaExtendedRankBrackets
        case "KR": return LeaderboardClient.southKoreaExtendedRankBrackets
        case "IT": return LeaderboardClient.italyExtendedRankBrackets
        case "ES": return LeaderboardClient.spainExtendedRankBrackets
        case "NL": return LeaderboardClient.netherlandsExtendedRankBrackets
        case "CH": return LeaderboardClient.switzerlandExtendedRankBrackets
        case "NO": return LeaderboardClient.norwayExtendedRankBrackets
        case "DK": return LeaderboardClient.denmarkExtendedRankBrackets
        case "FI": return LeaderboardClient.finlandExtendedRankBrackets
        case "PL": return LeaderboardClient.polandExtendedRankBrackets
        default: return LeaderboardClient.usExtendedRankBrackets
        }
    }

    // MARK: - Top 150 Milestones Access for Rank Preview

    /// Global top 150 milestones (uses US as representative)
    static var globalTop150Milestones: [String] {
        LeaderboardClient.usPlayerMilestones
    }

    /// Hall of Fame top 150 milestones (all are infinity+ players)
    static var hallOfFameTop150Milestones: [String] {
        // Hall of Fame players all have infinity tiles, milestones from hallOfFameExtendedBrackets
        var milestones: [String] = []
        for bracket in hallOfFameExtendedBrackets {
            // Fill from this bracket's start to just before next bracket
            let nextIndex = hallOfFameExtendedBrackets.firstIndex(where: { $0.startRank > bracket.startRank })
            let endRank = nextIndex.map { hallOfFameExtendedBrackets[$0].startRank } ?? 151
            for _ in bracket.startRank..<min(endRank, 151) {
                milestones.append(bracket.milestone)
            }
        }
        return Array(milestones.prefix(150))
    }

    /// Get top 150 milestones for a specific country code
    static func top150Milestones(for countryCode: String) -> [String] {
        switch countryCode {
        case "US": return LeaderboardClient.usPlayerMilestones
        case "GB": return LeaderboardClient.ukPlayerMilestones
        case "CA": return LeaderboardClient.canadaPlayerMilestones
        case "AU": return LeaderboardClient.australiaPlayerMilestones
        case "DE": return LeaderboardClient.germanyPlayerMilestones
        case "FR": return LeaderboardClient.francePlayerMilestones
        case "JP": return LeaderboardClient.japanPlayerMilestones
        case "IN": return LeaderboardClient.indiaPlayerMilestones
        case "BR": return LeaderboardClient.brazilPlayerMilestones
        case "MX": return LeaderboardClient.mexicoPlayerMilestones
        case "AF": return LeaderboardClient.afghanistanPlayerMilestones
        case "AL": return LeaderboardClient.albaniaPlayerMilestones
        case "DZ": return LeaderboardClient.algeriaPlayerMilestones
        case "CN": return LeaderboardClient.chinaPlayerMilestones
        case "KR": return LeaderboardClient.southKoreaPlayerMilestones
        case "IT": return LeaderboardClient.italyPlayerMilestones
        case "ES": return LeaderboardClient.spainPlayerMilestones
        case "NL": return LeaderboardClient.netherlandsPlayerMilestones
        case "CH": return LeaderboardClient.switzerlandPlayerMilestones
        case "NO": return LeaderboardClient.norwayPlayerMilestones
        case "DK": return LeaderboardClient.denmarkPlayerMilestones
        case "FI": return LeaderboardClient.finlandPlayerMilestones
        case "PL": return LeaderboardClient.polandPlayerMilestones
        case "BE": return LeaderboardClient.belgiumPlayerMilestones
        case "SE": return LeaderboardClient.swedenPlayerMilestones
        case "AT": return LeaderboardClient.austriaPlayerMilestones
        case "IE": return LeaderboardClient.irelandPlayerMilestones
        case "PT": return LeaderboardClient.portugalPlayerMilestones
        case "GR": return LeaderboardClient.greecePlayerMilestones
        case "CZ": return LeaderboardClient.czechiaPlayerMilestones
        case "RO": return LeaderboardClient.romaniaPlayerMilestones
        case "MY": return LeaderboardClient.malaysiaPlayerMilestones
        case "NZ": return LeaderboardClient.newZealandPlayerMilestones
        case "HU": return LeaderboardClient.hungaryPlayerMilestones
        case "VN": return LeaderboardClient.vietnamPlayerMilestones
        case "CW": return LeaderboardClient.curacaoPlayerMilestones
        default: return LeaderboardClient.usPlayerMilestones
        }
    }
}

public extension LeaderboardClient {
    static let noop = LeaderboardClient(
        authenticate: { true },
        submitScore: { _ in },
        fetchPage: { _, filter, _, _ in
            let entries: [LeaderboardEntry]
            switch filter {
            case .hallOfFame:
                // Show only top 150 Hall of Fame entries
                let allHofEntries = hallOfFameEntries()
                entries = Array(allHofEntries.prefix(150))
            case .country:
                entries = countryEntries()
            case .countryUK:
                entries = ukEntries()
            case .countryCA:
                entries = canadaEntries()
            case .countryAU:
                entries = australiaEntries()
            case .countryDE:
                entries = germanyEntries()
            case .countryFR:
                entries = franceEntries()
            case .countryJP:
                entries = japanEntries()
            case .countryIN:
                entries = indiaEntries()
            case .countryBR:
                entries = brazilEntries()
            case .countryMX:
                entries = mexicoEntries()
            case .countryAF:
                entries = afghanistanEntries()
            case .countryAL:
                entries = albaniaEntries()
            case .countryDZ:
                entries = algeriaEntries()
            case .countryCN:
                entries = chinaEntries()
            case .countryKR:
                entries = southKoreaEntries()
            case .countryIT:
                entries = italyEntries()
            case .countryES:
                entries = spainEntries()
            case .countryNL:
                entries = netherlandsEntries()
            case .countryCH:
                entries = switzerlandEntries()
            case .countryNO:
                entries = norwayEntries()
            case .countryDK:
                entries = denmarkEntries()
            case .countryFI:
                entries = finlandEntries()
            case .countryPL:
                entries = polandEntries()
            case .countryBE:
                entries = belgiumEntries()
            case .countrySE:
                entries = swedenEntries()
            case .countryAT:
                entries = austriaEntries()
            case .countryIE:
                entries = irelandEntries()
            case .countryPT:
                entries = portugalEntries()
            case .countryGR:
                entries = greeceEntries()
            case .countryCZ:
                entries = czechiaEntries()
            case .countryRO:
                entries = romaniaEntries()
            case .countryMY:
                entries = malaysiaEntries()
            case .countryNZ:
                entries = newZealandEntries()
            case .countryHU:
                entries = hungaryEntries()
            case .countryTH:
                entries = thailandEntries()
            case .countryAE:
                entries = uaeEntries()
            case .countryPH:
                entries = philippinesEntries()
            case .countryAD:
                entries = andorraEntries()
            case .countryID:
                entries = indonesiaEntries()
            case .countryZA:
                entries = southAfricaEntries()
            case .countryKE:
                entries = kenyaEntries()
            case .countryFJ:
                entries = fijiEntries()
            case .countryVN:
                entries = vietnamEntries()
            case .countryCW:
                entries = curacaoEntries()
            case .global:
                entries = globalEntries()
            }
            let day = MockLeaderboardData.daysSinceReference
            // Dynamic player counts with joining rate and attrition
            let totalPlayers: Int
            switch filter {
            case .hallOfFame:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 604, on: day, countrySeed: 999)
            case .country:
                totalPlayers = MockLeaderboardData.totalPlayers(on: day, isUS: true)
            case .countryUK:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 17_676, on: day, countrySeed: 100)
            case .countryCA:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 12_847, on: day, countrySeed: 101)
            case .countryAU:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 63_213, on: day, countrySeed: 102)
            case .countryDE:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 76_767, on: day, countrySeed: 103)
            case .countryFR:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 127_676, on: day, countrySeed: 104)
            case .countryJP:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 894, on: day, countrySeed: 105)
            case .countryIN:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 1_488, on: day, countrySeed: 106)
            case .countryBR:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 10_000, on: day, countrySeed: 107)
            case .countryMX:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 7_229, on: day, countrySeed: 108)
            case .countryAF:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 11_111, on: day, countrySeed: 109)
            case .countryAL:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 11_222, on: day, countrySeed: 110)
            case .countryDZ:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 3_333, on: day, countrySeed: 111)
            case .countryCN:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 8_192, on: day, countrySeed: 112)
            case .countryKR:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 3_123, on: day, countrySeed: 113)
            case .countryIT:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 13_856, on: day, countrySeed: 114)
            case .countryES:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 14_399, on: day, countrySeed: 115)
            case .countryNL:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 46_767, on: day, countrySeed: 116)
            case .countryCH:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 20_000, on: day, countrySeed: 117)
            case .countryNO:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 34_924, on: day, countrySeed: 118)
            case .countryDK:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 90_123, on: day, countrySeed: 119)
            case .countryFI:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 87_654, on: day, countrySeed: 120)
            case .countryPL:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 67_108, on: day, countrySeed: 121)
            case .countryBE:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 8_989, on: day, countrySeed: 122)
            case .countrySE:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 6_288, on: day, countrySeed: 123)
            case .countryAT:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 7_543, on: day, countrySeed: 124)
            case .countryIE:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 34_567, on: day, countrySeed: 125)
            case .countryPT:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 98_989, on: day, countrySeed: 126)
            case .countryGR:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 41_414, on: day, countrySeed: 127)
            case .countryCZ:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 61_616, on: day, countrySeed: 128)
            case .countryRO:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 5_966, on: day, countrySeed: 129)
            case .countryMY:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 52_111, on: day, countrySeed: 130)
            case .countryNZ:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 2_623, on: day, countrySeed: 131)
            case .countryHU:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 111_111, on: day, countrySeed: 132)
            case .countryTH:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 5_444, on: day, countrySeed: 133)
            case .countryAE:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 19_889, on: day, countrySeed: 134)
            case .countryPH:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 43_210, on: day, countrySeed: 135)
            case .countryAD:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 1_977, on: day, countrySeed: 136)
            case .countryID:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 98_982, on: day, countrySeed: 137)
            case .countryZA:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 2_974, on: day, countrySeed: 138)
            case .countryKE:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 15_111, on: day, countrySeed: 139)
            case .countryFJ:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 1_214, on: day, countrySeed: 140)
            case .countryVN:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 167_676, on: day, countrySeed: 141)
            case .countryCW:
                totalPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 39_999, on: day, countrySeed: 142)
            case .global:
                // Global = sum of all country players (dynamic)
                let usPlayers = MockLeaderboardData.totalPlayers(on: day, isUS: true)
                let ukPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 17_676, on: day, countrySeed: 100)
                let caPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 12_847, on: day, countrySeed: 101)
                let auPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 63_213, on: day, countrySeed: 102)
                let dePlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 76_767, on: day, countrySeed: 103)
                let frPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 127_676, on: day, countrySeed: 104)
                let jpPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 894, on: day, countrySeed: 105)
                let inPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 1_488, on: day, countrySeed: 106)
                let brPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 10_000, on: day, countrySeed: 107)
                let mxPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 7_229, on: day, countrySeed: 108)
                let afPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 11_111, on: day, countrySeed: 109)
                let alPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 11_222, on: day, countrySeed: 110)
                let dzPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 3_333, on: day, countrySeed: 111)
                let cnPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 8_192, on: day, countrySeed: 112)
                let krPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 3_123, on: day, countrySeed: 113)
                let itPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 13_856, on: day, countrySeed: 114)
                let esPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 14_399, on: day, countrySeed: 115)
                let nlPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 46_767, on: day, countrySeed: 116)
                let chPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 20_000, on: day, countrySeed: 117)
                let noPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 34_924, on: day, countrySeed: 118)
                let dkPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 90_123, on: day, countrySeed: 119)
                let fiPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 87_654, on: day, countrySeed: 120)
                let plPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 67_108, on: day, countrySeed: 121)
                let bePlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 8_989, on: day, countrySeed: 122)
                let sePlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 6_288, on: day, countrySeed: 123)
                let atPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 7_543, on: day, countrySeed: 124)
                let iePlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 34_567, on: day, countrySeed: 125)
                let ptPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 98_989, on: day, countrySeed: 126)
                let grPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 41_414, on: day, countrySeed: 127)
                let czPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 61_616, on: day, countrySeed: 128)
                let roPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 5_966, on: day, countrySeed: 129)
                let myPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 52_111, on: day, countrySeed: 130)
                let nzPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 2_623, on: day, countrySeed: 131)
                let huPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 111_111, on: day, countrySeed: 132)
                let thPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 5_444, on: day, countrySeed: 133)
                let aePlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 19_889, on: day, countrySeed: 134)
                let phPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 43_210, on: day, countrySeed: 135)
                let adPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 1_977, on: day, countrySeed: 136)
                let idPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 98_982, on: day, countrySeed: 137)
                let zaPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 2_974, on: day, countrySeed: 138)
                let kePlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 15_111, on: day, countrySeed: 139)
                let fjPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 1_214, on: day, countrySeed: 140)
                let vnPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 167_676, on: day, countrySeed: 141)
                let cwPlayers = MockLeaderboardData.totalCountryPlayers(basePlayers: 39_999, on: day, countrySeed: 142)
                totalPlayers = usPlayers + ukPlayers + caPlayers + auPlayers + dePlayers + frPlayers + jpPlayers + inPlayers + brPlayers + mxPlayers + afPlayers + alPlayers + dzPlayers + cnPlayers + krPlayers + itPlayers + esPlayers + nlPlayers + chPlayers + noPlayers + dkPlayers + fiPlayers + plPlayers + bePlayers + sePlayers + atPlayers + iePlayers + ptPlayers + grPlayers + czPlayers + roPlayers + myPlayers + nzPlayers + huPlayers + thPlayers + aePlayers + phPlayers + adPlayers + idPlayers + zaPlayers + kePlayers + fjPlayers + vnPlayers + cwPlayers
            }
            // Resolve duplicate realistic first names by adding last names
            let resolvedEntries = MockLeaderboardData.resolveEntryDuplicates(entries)
            let myEntry = resolvedEntries.first(where: { $0.isMe }) ?? resolvedEntries.last
            return .init(entries: resolvedEntries, myEntry: myEntry, nextCursor: nil, totalPlayers: totalPlayers)
        },
        fetchMyRank: { _, _ in globalEntries().first(where: { $0.isMe }) ?? globalEntries().last }
    )

    // Hall of Fame player sources: which leaderboard they came from (US index, Global index, or Hall of Fame only)
    // Format: (isUS: Bool, sourceIndex: Int?) - if nil, use Hall of Fame names
    static let hallOfFamePlayerSources: [(isUS: Bool, sourceIndex: Int?)] = [
        // Ranks 1-15: Mix of US (top performers) and Global players
        (true, 0), (false, 0), (true, 1), (false, 1), (true, 2),
        (false, 2), (true, 3), (false, 3), (true, 4), (false, 4),
        (true, 5), (false, 5), (true, 6), (false, 6), (true, 7),
        // Ranks 16-30
        (false, 7), (true, 8), (false, 8), (true, 9), (false, 9),
        (true, 10), (false, 10), (true, 11), (false, 11), (true, 12),
        (false, 12), (true, 13), (false, 13), (true, 14), (false, 14),
        // Ranks 31-45
        (true, 15), (false, 15), (true, 16), (false, 16), (true, 17),
        (false, 17), (true, 18), (false, 18), (true, 19), (false, 19),
        (true, 20), (false, 20), (true, 21), (false, 21), (true, 22),
        // Ranks 46-60
        (false, 22), (true, 23), (false, 23), (true, 24), (false, 24),
        (true, 25), (false, 25), (true, 26), (false, 26), (true, 27),
        (false, 27), (true, 28), (false, 28), (true, 29), (false, 29),
        // Ranks 61-75
        (true, 30), (false, 30), (true, 31), (false, 31), (true, 32),
        (false, 32), (true, 33), (false, 33), (true, 34), (false, 34),
        (true, 35), (false, 35), (true, 36), (false, 36), (true, 37),
        // Ranks 76-90
        (false, 37), (true, 38), (false, 38), (true, 39), (false, 39),
        (true, 40), (false, 40), (true, 41), (false, 41), (true, 42),
        (false, 42), (true, 43), (false, 43), (true, 44), (false, 44),
        // Ranks 91-105
        (true, 45), (false, 45), (true, 46), (false, 46), (true, 47),
        (false, 47), (true, 48), (false, 48), (true, 49), (false, 49),
        (true, 50), (false, 50), (true, 51), (false, 51), (true, 52),
        // Ranks 106-120
        (false, 52), (true, 53), (false, 53), (true, 54), (false, 54),
        (true, 55), (false, 55), (true, 56), (false, 56), (true, 57),
        (false, 57), (true, 58), (false, 58), (true, 59), (false, 59),
        // Ranks 121-135
        (true, 60), (false, 60), (true, 61), (false, 61), (true, 62),
        (false, 62), (true, 63), (false, 63), (true, 64), (false, 64),
        (true, 65), (false, 65), (true, 66), (false, 66), (true, 67),
        // Ranks 136-150
        (false, 67), (true, 68), (false, 68), (true, 69), (false, 69),
        (true, 70), (false, 70), (true, 71), (false, 71), (true, 72),
        (false, 72), (true, 73), (false, 73), (true, 74), (false, 74)
    ]

    // Hall of Fame - players who reached ∞ from ALL countries
    // Ranks are based on infinity count - higher infinity = better rank
    // Includes daily progression and player churn
    private static func hallOfFameEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Combine all country Hall of Fame data
        var playerData: [(id: String, baseCount: Int, country: String, nameIndex: Int, playerIndex: Int)] = []
        var globalIndex = 0

        // Calculate how many players have left Hall of Fame (churn)
        // Use a Hall of Fame specific seed
        var totalLeftHoF: Double = 0
        for d in 0...day {
            totalLeftHoF += MockLeaderboardData.countryPlayersLeaving(on: d, countrySeed: 88888)
        }
        let playersToSkip = Int(totalLeftHoF)

        // Add US players (skip some due to churn)
        for (i, count) in MockLeaderboardData.hallOfFameInfinityCounts.enumerated() {
            if globalIndex >= playersToSkip {
                playerData.append(("hof_us_\(i)", count, "US", globalIndex, i))
            }
            globalIndex += 1
        }
        // Add UK players
        for (i, count) in MockLeaderboardData.ukHallOfFameInfinityCounts.enumerated() {
            playerData.append(("hof_uk_\(i)", count, "GB", globalIndex, i + 1000))
            globalIndex += 1
        }
        // Add Canada players
        for (i, count) in MockLeaderboardData.canadaHallOfFameInfinityCounts.enumerated() {
            playerData.append(("hof_ca_\(i)", count, "CA", globalIndex, i + 2000))
            globalIndex += 1
        }
        // Add Australia players
        for (i, count) in MockLeaderboardData.australiaHallOfFameInfinityCounts.enumerated() {
            playerData.append(("hof_au_\(i)", count, "AU", globalIndex, i + 3000))
            globalIndex += 1
        }
        // Add Germany players
        for (i, count) in MockLeaderboardData.germanyHallOfFameInfinityCounts.enumerated() {
            playerData.append(("hof_de_\(i)", count, "DE", globalIndex, i + 4000))
            globalIndex += 1
        }
        // Add France players
        for (i, count) in MockLeaderboardData.franceHallOfFameInfinityCounts.enumerated() {
            playerData.append(("hof_fr_\(i)", count, "FR", globalIndex, i + 5000))
            globalIndex += 1
        }
        // Add Japan players
        for (i, count) in MockLeaderboardData.japanHallOfFameInfinityCounts.enumerated() {
            playerData.append(("hof_jp_\(i)", count, "JP", globalIndex, i + 6000))
            globalIndex += 1
        }
        // Add India players
        for (i, count) in MockLeaderboardData.indiaHallOfFameInfinityCounts.enumerated() {
            playerData.append(("hof_in_\(i)", count, "IN", globalIndex, i + 7000))
            globalIndex += 1
        }
        // Add Brazil players
        for (i, count) in MockLeaderboardData.brazilHallOfFameInfinityCounts.enumerated() {
            playerData.append(("hof_br_\(i)", count, "BR", globalIndex, i + 8000))
            globalIndex += 1
        }
        // Add Mexico players
        for (i, count) in MockLeaderboardData.mexicoHallOfFameInfinityCounts.enumerated() {
            playerData.append(("hof_mx_\(i)", count, "MX", globalIndex, i + 9000))
            globalIndex += 1
        }
        // Add Afghanistan players
        for (i, count) in MockLeaderboardData.afghanistanHallOfFameInfinityCounts.enumerated() {
            playerData.append(("hof_af_\(i)", count, "AF", globalIndex, i + 10000))
            globalIndex += 1
        }
        // Add Albania players
        for (i, count) in MockLeaderboardData.albaniaHallOfFameInfinityCounts.enumerated() {
            playerData.append(("hof_al_\(i)", count, "AL", globalIndex, i + 11000))
            globalIndex += 1
        }
        // Add Algeria players
        for (i, count) in MockLeaderboardData.algeriaHallOfFameInfinityCounts.enumerated() {
            playerData.append(("hof_dz_\(i)", count, "DZ", globalIndex, i + 12000))
            globalIndex += 1
        }
        // Add China players
        for (i, count) in MockLeaderboardData.chinaHallOfFameInfinityCounts.enumerated() {
            playerData.append(("hof_cn_\(i)", count, "CN", globalIndex, i + 13000))
            globalIndex += 1
        }
        // Add South Korea players
        for (i, count) in MockLeaderboardData.southKoreaHallOfFameInfinityCounts.enumerated() {
            playerData.append(("hof_kr_\(i)", count, "KR", globalIndex, i + 14000))
            globalIndex += 1
        }
        // Add Italy players
        for (i, count) in MockLeaderboardData.italyHallOfFameInfinityCounts.enumerated() {
            playerData.append(("hof_it_\(i)", count, "IT", globalIndex, i + 15000))
            globalIndex += 1
        }
        // Add Spain players
        for (i, count) in MockLeaderboardData.spainHallOfFameInfinityCounts.enumerated() {
            playerData.append(("hof_es_\(i)", count, "ES", globalIndex, i + 16000))
            globalIndex += 1
        }
        // Add Netherlands players
        for (i, count) in MockLeaderboardData.netherlandsHallOfFameInfinityCounts.enumerated() {
            playerData.append(("hof_nl_\(i)", count, "NL", globalIndex, i + 17000))
            globalIndex += 1
        }

        // Apply daily progression to infinity counts using tiered rates:
        // 1-99: 0.2-0.55/day, 100-999: 1-4/day, 1000-9999: 3-7/day, 10000-99999: 6-15/day, 100000+: 10-30/day
        var progressedData: [(id: String, progressedCount: Int, country: String, nameIndex: Int, playerIndex: Int)] = []
        for player in playerData {
            let progressedCount = MockLeaderboardData.infinityCountWithProgression(
                baseCount: player.baseCount,
                playerIndex: player.playerIndex,
                day: day
            )
            progressedData.append((player.id, progressedCount, player.country, player.nameIndex, player.playerIndex))
        }

        // Sort by progressed count (highest first)
        progressedData.sort { $0.progressedCount > $1.progressedCount }

        // Build entries with ranks based on sorted order
        var entries: [LeaderboardEntry] = []
        for (rank, player) in progressedData.enumerated() {
            // Use unique name from hallOfFameNames with daily variation (HoF seed: 999999)
            let name = MockLeaderboardData.nameForPlayer(index: rank, names: MockLeaderboardData.hallOfFameNames, countrySeed: 999999, day: day)

            let platform: Platform = rank % 2 == 0 ? .ios : .android
            // Use seeded avatar selection with daily variation (HoF seed: 999999)
            let avatar = MockLeaderboardData.avatarForPlayer(index: rank, countrySeed: 999999, day: day)
            let score = MockLeaderboardData.scoreForMilestone("\(player.progressedCount)∞")

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: name,
                score: score,
                countryCode: player.country,
                platform: platform,
                avatarURL: avatar,
                highestTile: "\(player.progressedCount)∞"
            ))
        }

        return entries
    }

    // Exact US player milestones from screenshots (ranks 1-256+)
    static let usPlayerMilestones: [String] = [
        // Ranks 1-15
        "106by", "3bw", "1br", "1bo", "20bm", "76bk", "74bj", "1bj", "9bi", "35bh", "278bg", "543bf", "16bf", "506bc", "30bb",
        // Ranks 16-30
        "943az", "28ay", "28ax", "1aw", "818at", "24as", "48ar", "2aq", "22ao", "709an", "177an", "1an", "676al", "42al", "661ak",
        // Ranks 31-45
        "2ak", "20aj", "315ai", "19ai", "9ai", "601ag", "2ag", "4af", "2af", "1af", "1af", "71ae", "17ac", "133ab", "2ab",
        // Ranks 46-60
        "32aa", "2aa", "509z", "63z", "15z", "497y", "3y", "7x", "474w", "7w", "463v", "28v", "3v", "226u", "28u",
        // Ranks 61-75
        "7u", "1u", "883t", "3t", "26s", "842r", "6r", "102q", "3q", "401p", "401p", "100p", "12p", "784o", "3o",
        // Ranks 76-90
        "374m", "11m", "1m", "182l", "45l", "11l", "5l", "5l", "2l", "356k", "44k", "11k", "5k", "348j", "680i",
        // Ranks 91-105
        "340i", "170i", "42i", "83h", "41h", "41h", "41h", "10h", "324g", "324g", "40g", "5g", "1g", "316f", "158f",
        // Ranks 106-120
        "79f", "79f", "19f", "9f", "4f", "1f", "154e", "77e", "19e", "9e", "4e", "604d", "302d", "151d", "75d",
        // Ranks 121-135
        "75d", "37d", "37d", "37d", "18d", "9d", "2d", "1d", "1d", "590c", "295c", "73c", "18c", "18c", "9c",
        // Ranks 136-150
        "9c", "4c", "4c", "2c", "1c", "576b", "288b", "144b", "144b", "36b", "18b", "9b", "9b", "9b", "9b",
        // Ranks 151-165 (extended from screenshot)
        "4b", "4b", "2b", "1b", "562a", "562a", "562a", "281a", "281a", "281a", "281a", "281a", "281a", "140a", "140a",
        // Ranks 166-180
        "140a", "140a", "70a", "70a", "70a", "35a", "35a", "35a", "35a", "35a", "35a", "35a", "35a", "35a", "35a",
        // Ranks 181-195
        "35a", "17a", "17a", "17a", "17a", "17a", "17a", "17a", "17a", "17a", "17a", "17a", "17a", "17a", "17a",
        // Ranks 196-210
        "8a", "8a", "8a", "8a", "8a", "8a", "8a", "8a", "8a", "8a", "8a", "8a", "8a", "8a", "8a",
        // Ranks 211-225
        "4a", "4a", "4a", "4a", "4a", "4a", "4a", "4a", "4a", "4a", "4a", "4a", "4a", "4a", "4a",
        // Ranks 226-240
        "4a", "4a", "4a", "4a", "4a", "4a", "2a", "2a", "2a", "2a", "2a", "2a", "2a", "2a", "2a",
        // Ranks 241-255
        "2a", "2a", "2a", "2a", "2a", "2a", "2a", "2a", "2a", "2a", "2a", "2a", "2a", "2a", "2a",
        // Ranks 256-270
        "1a", "1a", "1a", "1a", "1a", "1a", "1a", "1a", "1a", "1a", "1a", "1a", "1a", "1a", "1a"
    ]

    // UK player milestones from screenshots (ranks 1-150)
    static let ukPlayerMilestones: [String] = [
        // Ranks 1-30 (from screenshot)
        "54bz", "833bx", "1bx", "758bt", "22br", "172bp", "2bo", "612bk", "17bh", "33be",
        "30bb", "921ay", "3av", "799as", "399as", "49as", "762aq", "2ap", "354an", "2am",
        "615ah", "2ah", "9ag", "73af", "35ae", "139ad", "2ab", "994y", "30x", "926v",
        // Ranks 31-60 (from screenshot)
        "28u", "862s", "26s", "842r", "421r", "52r", "822q", "51q", "803p", "200p",
        "25p", "784o", "98o", "12o", "766n", "95n", "2n", "374m", "93m", "730l",
        "91l", "11l", "1l", "356k", "89k", "22k", "696j", "174j", "5j", "680i",
        // Ranks 61-90 (from screenshot)
        "340i", "85i", "664h", "166h", "41h", "10h", "5h", "1h", "162g", "20g",
        "2g", "633f", "158f", "39f", "2f", "618e", "154e", "77e", "38e", "38e",
        "19e", "19e", "9e", "9e", "9e", "4e", "2e", "1e", "604d", "302d",
        // Ranks 91-120 (from screenshot)
        "151d", "75d", "18d", "9d", "4d", "4d", "2d", "1d", "590c", "295c",
        "147c", "36c", "576b", "576b", "144b", "72b", "36b", "18b", "18b", "9b",
        "9b", "4b", "2b", "2b", "1b", "562a", "281a", "281a", "140a", "17a",
        // Ranks 121-151 (extra entry for infinity filtering)
        "8a", "4a", "4a", "2a", "2a", "1a", "549B", "274B", "137B", "68B",
        "68B", "34B", "17B", "8B", "2B", "1B", "1B", "536M", "536M", "268M",
        "268M", "268M", "134M", "134M", "134M", "134M", "134M", "67M", "67M", "67M",
        "33M"
    ]

    // Canada player milestones from screenshots (ranks 1-150)
    static let canadaPlayerMilestones: [String] = [
        // Ranks 1-30 (from screenshot)
        "873bz", "3bz", "853by", "106by", "6bv", "2bt", "361br", "22bq", "1bp", "642bm",
        "2bh", "30bb", "899ax", "3au", "48ar", "48ar", "1ar", "726ao", "2ao", "661ak",
        "2aj", "1ai", "1ah", "293af", "4ae", "1ad", "533ab", "4aa", "31y", "948w",
        // Ranks 31-60 (from screenshot)
        "3w", "28v", "904u", "7u", "55t", "1t", "1t", "862s", "431s", "215s",
        "53s", "3s", "842r", "3q", "3p", "392o", "98o", "24o", "3o", "766n",
        "383n", "95n", "23n", "2n", "374m", "2m", "365l", "11l", "5l", "5l",
        // Ranks 61-90 (from screenshot)
        "2l", "713k", "178k", "22k", "11k", "11k", "2k", "1k", "696j", "696j",
        "87j", "5j", "1j", "85i", "42i", "10i", "5i", "5i", "664h", "166h",
        "41h", "20h", "20h", "20h", "20h", "10h", "649g", "649g", "162g", "40g",
        // Ranks 91-120 (from screenshot)
        "20g", "10g", "5g", "5g", "1g", "316f", "316f", "158f", "79f", "9f",
        "9f", "77e", "38e", "38e", "19e", "19e", "4e", "2e", "2e", "1e",
        "1e", "604d", "604d", "302d", "151d", "75d", "37d", "18d", "18d", "2d",
        // Ranks 121-152 (c-tier then b-tier, extra entries for infinity filtering)
        "1d", "590c", "295c", "147c", "73c", "36c", "18c", "9c", "4c", "2c",
        "1c", "576b", "288b", "144b", "72b", "36b", "18b", "9b", "4b", "2b",
        "1b", "1b", "1b", "1b", "1b", "1b", "1b", "1b", "1b", "1b",
        "562a", "281a"
    ]

    // Extended Canada milestone brackets for rank calculation (ranks 151+)
    // Total Canada players: ~12,847
    static let canadaExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // a-tier brackets (ranks 151-179)
        ("1b", 151), ("562a", 152), ("281a", 153), ("140a", 155), ("70a", 158), ("35a", 160),
        ("17a", 165), ("8a", 167), ("4a", 169), ("2a", 170), ("1a", 175),
        // B-tier brackets (ranks 180-248)
        ("549B", 180), ("274B", 184), ("137B", 189), ("68B", 192), ("34B", 197),
        ("17B", 208), ("8B", 216), ("4B", 223), ("2B", 232), ("1B", 246),
        // M-tier brackets (ranks 249-675)
        ("536M", 249), ("268M", 250), ("134M", 264), ("67M", 315), ("33M", 355),
        ("16M", 396), ("8M", 448), ("4M", 551), ("2M", 600), ("1M", 666),
        // K-tier brackets (ranks 676-1885)
        ("524K", 676), ("262K", 767), ("131K", 837), ("65K", 955), ("32K", 1167), ("16K", 1443),
        // Raw number brackets (ranks 1886-12847)
        ("8192", 1886), ("4096", 2234), ("2048", 2877), ("1024", 3581),
        ("512", 4456), ("256", 5676), ("128", 6767), ("64", 8067), ("32", 8745),
        ("16", 9341), ("8", 9867), ("4", 10211), ("2", 10657), ("0", 10899)
    ]

    // Australia player milestones from screenshots (ranks 1-150)
    static let australiaPlayerMilestones: [String] = [
        // Ranks 1-30 (from screenshot)
        "13bz", "794bv", "2br", "657bn", "1bm", "9bk", "556bg", "278bg", "69bg", "989bb",
        "463v", "4a", "409at", "48ar", "46ap", "88an", "676al", "1al", "10aj", "2ah",
        "2af", "69ad", "4ac", "1ab", "127z", "1z", "971x", "30x", "1x", "452u",
        // Ranks 31-60 (from screenshot)
        "113u", "14u", "883t", "27t", "431s", "3s", "210r", "52r", "3r", "411q",
        "51q", "401p", "3o", "383n", "95n", "23n", "11n", "2n", "748m", "187m",
        "46m", "23m", "11m", "730l", "5l", "356k", "22k", "11k", "696j", "87j",
        // Ranks 61-90 (from screenshot)
        "10j", "2j", "680i", "85i", "21i", "2i", "332h", "41h", "5h", "649g",
        "81g", "20g", "2g", "316f", "79f", "39f", "9f", "2f", "309e", "77e",
        "19e", "4e", "604d", "75d", "18d", "18d", "9d", "4d", "4d", "1d",
        // Ranks 91-120 (from screenshot)
        "1d", "590c", "295c", "147c", "36c", "18c", "4c", "2c", "2c", "576b",
        "576b", "288b", "144b", "72b", "72b", "9b", "4b", "2b", "2b", "1b",
        "562a", "281a", "140a", "35a", "17a", "8a", "8a", "4a", "4a", "2a",
        // Ranks 121-151 (extra entry for infinity filtering)
        "1a", "274B", "137B", "137B", "68B", "34B", "34B", "34B", "17B", "17B",
        "8B", "8B", "8B", "8B", "4B", "4B", "4B", "2B", "2B", "1B",
        "1B", "1B", "1B", "1B", "1B", "1B", "1B", "1B", "1B", "1B",
        "536M"
    ]

    // Extended Australia milestone brackets for rank calculation (ranks 151+)
    // Total Australia players: ~63,213
    static let australiaExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // B-tier brackets
        ("1B", 140), ("536M", 175), ("268M", 183), ("134M", 198), ("67M", 199),
        ("33M", 202), ("16M", 223), ("8M", 240), ("4M", 287), ("2M", 333), ("1M", 388),
        // K-tier brackets
        ("524K", 447), ("262K", 669), ("131K", 922), ("65K", 1234), ("32K", 1955), ("16K", 2533),
        // Raw number brackets
        ("8192", 3513), ("4096", 4225), ("2048", 5533), ("1024", 6767), ("512", 8499),
        ("256", 11988), ("128", 14676), ("64", 16767), ("32", 21116), ("16", 26002),
        ("8", 31288), ("4", 35526), ("2", 40000), ("0", 59333)
    ]

    // Germany player milestones (ranks 1-150)
    static let germanyPlayerMilestones: [String] = [
        // Ranks 1-30
        "218bz", "853by", "3by", "90br", "2bq", "42bo", "321bm", "2bl", "4bj", "8bh",
        "16bf", "32bd", "61bb", "117az", "224ax", "429av", "818at", "1as", "12ar", "762aq",
        "190aq", "21am", "1aj", "1af", "4ad", "254z", "971x", "3w", "883t", "107s",
        // Ranks 31-60
        "52r", "51q", "803p", "25p", "784o", "196o", "24o", "3o", "191n", "11n",
        "748m", "93m", "23m", "2m", "365l", "91l", "22k", "43j", "42i", "21i",
        "10i", "10i", "2i", "1i", "664h", "664h", "166h", "10h", "2h", "1h",
        // Ranks 61-90
        "324g", "324g", "162g", "40g", "5g", "1g", "158f", "39f", "9f", "4f",
        "1f", "618e", "309e", "309e", "154e", "154e", "77e", "38e", "38e", "19e",
        "19e", "19e", "19e", "9e", "2e", "604d", "302d", "302d", "151d", "151d",
        // Ranks 91-120
        "151d", "75d", "75d", "75d", "75d", "37d", "37d", "37d", "37d", "18d",
        "18d", "18d", "18d", "9d", "9d", "9d", "9d", "9d", "4d", "4d",
        "4d", "4d", "4d", "2d", "2d", "2d", "2d", "2d", "1d", "1d",
        // Ranks 121-152 (extra entries for infinity filtering)
        "1d", "1d", "1d", "1d", "590c", "590c", "590c", "590c", "590c", "590c",
        "295c", "295c", "295c", "295c", "295c", "295c", "147c", "147c", "147c", "147c",
        "147c", "147c", "73c", "73c", "73c", "73c", "73c", "73c", "73c", "36c",
        "18c", "9c"
    ]

    // Extended Germany milestone brackets for rank calculation (ranks 151+)
    // Total Germany players: ~76,767
    static let germanyExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // c-tier brackets
        ("36c", 150), ("18c", 157), ("9c", 163), ("4c", 169), ("2c", 174), ("1c", 178),
        // b-tier brackets
        ("576b", 187), ("288b", 194), ("144b", 200), ("72b", 206), ("36b", 214),
        ("18b", 224), ("9b", 233), ("4b", 242), ("2b", 251), ("1b", 260),
        // a-tier brackets
        ("562a", 269), ("281a", 279), ("140a", 290), ("70a", 300), ("35a", 311),
        ("17a", 325), ("8a", 339), ("4a", 353), ("2a", 367), ("1a", 382),
        // B-tier brackets
        ("549B", 400), ("274B", 421), ("137B", 446), ("68B", 476), ("34B", 512),
        ("17B", 565), ("8B", 622), ("4B", 677), ("2B", 733), ("1B", 786),
        // M-tier brackets
        ("536M", 827), ("268M", 862), ("134M", 902), ("67M", 998), ("33M", 1055),
        ("16M", 1119), ("8M", 1267), ("4M", 1477), ("2M", 1666), ("1M", 1888),
        // K-tier brackets
        ("524K", 2119), ("262K", 2333), ("131K", 2567), ("65K", 2676), ("32K", 3113), ("16K", 4167),
        // Raw number brackets
        ("8192", 6767), ("4096", 9366), ("2048", 12577), ("1024", 16735), ("512", 20676),
        ("256", 25416), ("128", 30674), ("64", 36234), ("32", 42333), ("16", 46655),
        ("8", 53566), ("4", 60676), ("2", 67676), ("0", 73666)
    ]

    // France player milestones (ranks 1-150)
    static let francePlayerMilestones: [String] = [
        // Ranks 1-30
        "198bv", "776bu", "379bt", "2bs", "11br", "706bq", "2bq", "299bj", "2bi", "4bg",
        "66be", "64bd", "253bc", "989bb", "241ba", "3ay", "6at", "1at", "363ao", "1ao",
        "336al", "2ak", "1aj", "615ah", "4ag", "8ae", "68ac", "521aa", "254z", "3y",
        // Ranks 31-60
        "7w", "463v", "14v", "226u", "7u", "1u", "110t", "55t", "13t", "53s",
        "3s", "105r", "411q", "205q", "205q", "25q", "3q", "200p", "50p", "12p",
        "6p", "49o", "24o", "6o", "1o", "191n", "47n", "11n", "5n", "2n",
        // Ranks 61-90
        "2n", "187m", "23m", "2m", "91l", "45l", "11l", "1l", "356k", "89k",
        "22k", "2k", "348j", "174j", "87j", "87j", "43j", "43j", "21j", "10j",
        "5j", "5j", "2j", "680i", "680i", "340i", "340i", "170i", "170i", "170i",
        // Ranks 91-120
        "85i", "85i", "85i", "85i", "42i", "42i", "42i", "42i", "42i", "21i",
        "21i", "21i", "21i", "21i", "21i", "21i", "10i", "10i", "10i", "10i",
        "10i", "10i", "10i", "10i", "5i", "5i", "5i", "5i", "5i", "2i",
        // Ranks 121-151 (extra entry for infinity filtering)
        "2i", "2i", "2i", "2i", "2i", "2i", "2i", "1i", "1i", "1i",
        "1i", "1i", "1i", "1i", "1i", "1i", "1i", "1i", "1i", "1i",
        "1i", "664h", "664h", "664h", "664h", "664h", "664h", "664h", "664h", "664h",
        "332h"
    ]

    // Extended France milestone brackets for rank calculation (ranks 151+)
    // Total France players: ~127,676
    static let franceExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // h-tier brackets
        ("664h", 142), ("332h", 157), ("166h", 175), ("83h", 211), ("20h", 212),
        ("10h", 219), ("5h", 233), ("2h", 248), ("1h", 291),
        // g-tier brackets
        ("649g", 331), ("324g", 411), ("162g", 444), ("81g", 467), ("40g", 497),
        ("20g", 521), ("10g", 541), ("5g", 567), ("2g", 611), ("1g", 641),
        // f-tier brackets
        ("633f", 667), ("316f", 722), ("158f", 787), ("79f", 833), ("39f", 912),
        ("19f", 955), ("9f", 997), ("4f", 1044), ("2f", 1104), ("1f", 1174),
        // e-tier brackets
        ("618e", 1300), ("309e", 1341), ("154e", 1411), ("77e", 1449), ("38e", 1486),
        ("19e", 1534), ("9e", 1612), ("4e", 1667), ("2e", 1784), ("1e", 1855),
        // d-tier brackets
        ("604d", 2066), ("302d", 2222), ("151d", 2453), ("75d", 2644), ("37d", 2789),
        ("18d", 2933), ("9d", 3067), ("4d", 3322), ("2d", 3633), ("1d", 4161),
        // c-tier brackets
        ("590c", 4567), ("295c", 5012), ("147c", 5678), ("73c", 6161), ("36c", 6767),
        ("18c", 7061), ("9c", 7335), ("4c", 7676), ("2c", 8080), ("1c", 8255),
        // b-tier brackets
        ("576b", 8567), ("288b", 8777), ("144b", 9089), ("72b", 9553), ("36b", 10211),
        ("18b", 10798), ("9b", 11111), ("4b", 11345), ("2b", 11767), ("1b", 12121),
        // Higher b-tier (second pass after 1c)
        ("576b", 12345), ("288b", 12684), ("144b", 13223), ("72b", 13989), ("36b", 14444),
        ("18b", 15556), ("9b", 16543), ("4b", 17234), ("2b", 18532), ("1b", 20000),
        // a-tier brackets
        ("562a", 21111), ("281a", 22222), ("140a", 23333), ("70a", 24444), ("35a", 25555),
        ("17a", 26985), ("8a", 28446), ("4a", 30000), ("2a", 32580), ("1a", 36111),
        // B-tier brackets
        ("549B", 41414), ("274B", 47533), ("137B", 53346), ("68B", 56609), ("34B", 58986),
        ("17B", 61234), ("8B", 66666), ("4B", 67676), ("2B", 68966), ("1B", 70000),
        // M-tier brackets
        ("536M", 71234), ("268M", 74321), ("134M", 77777), ("67M", 80000), ("33M", 82345),
        ("16M", 85123), ("8M", 86767), ("4M", 90000), ("2M", 95344), ("1M", 95899),
        // K-tier brackets
        ("524K", 96666), ("262K", 96767), ("131K", 97012), ("65K", 97343), ("32K", 97676), ("16K", 98111),
        // Raw number brackets
        ("8192", 98877), ("4096", 99244), ("2048", 100000), ("1024", 100959), ("512", 101234),
        ("256", 101470), ("128", 102345), ("64", 106767), ("32", 109876), ("16", 111111),
        ("8", 114114), ("4", 117117), ("2", 121121), ("0", 125521)
    ]

    // Japan player milestones (ranks 1-150)
    static let japanPlayerMilestones: [String] = [
        // Ranks 1-30 (from screenshot)
        "873bz", "436bz", "109bz", "1bz", "24bv", "1br", "642bm", "583bi", "1bf", "15bb",
        "449ax", "1au", "1ar", "5ao", "84al", "1aj", "2af", "8ab", "2aa", "7z",
        "15x", "7v", "3v", "1t", "1r", "6p", "91l", "2l", "44k", "696j",
        // Ranks 31-60 (from screenshot)
        "1j", "2i", "1i", "332h", "41h", "5h", "649g", "81g", "10g", "10g",
        "5g", "2g", "2g", "1g", "633f", "316f", "79f", "19f", "1f", "154e",
        "9e", "77e", "4e", "1e", "604d", "151d", "2d", "1d", "295c", "147c",
        // Ranks 61-90 (from screenshot)
        "2b", "1b", "281a", "140a", "140a", "70a", "17a", "1a", "1a", "1a",
        "549B", "549B", "274B", "137B", "68B", "68B", "17B", "4B", "2B", "2B",
        "1B", "1B", "1B", "1B", "536M", "536M", "536M", "268M", "268M", "268M",
        // Ranks 91-120 (from screenshot)
        "268M", "268M", "134M", "134M", "134M", "134M", "67M", "67M", "67M", "67M",
        "67M", "67M", "33M", "33M", "33M", "33M", "33M", "33M", "16M", "16M",
        "16M", "16M", "16M", "16M", "8M", "8M", "8M", "8M", "8M", "8M",
        // Ranks 121-154 (extra entries for infinity filtering)
        "4M", "2ai", "1ad", "63z", "3v", "13r", "3q", "2m", "19f", "2c",
        "9b", "562a", "140a", "70a", "35a", "17a", "8a", "4a", "2a", "1a",
        "549B", "274B", "137B", "68B", "34B", "17B", "8B", "4B", "2B", "1B",
        "536M", "268M", "134M", "67M"
    ]

    // Extended Japan milestone brackets for rank calculation (ranks 151+)
    // Total Japan players: ~894
    static let japanExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // M-tier brackets (ranks 152-210)
        ("536M", 152), ("268M", 157), ("134M", 161), ("67M", 164), ("33M", 177),
        ("16M", 184), ("8M", 191), ("4M", 198), ("2M", 204), ("1M", 211),
        // K-tier brackets (ranks 218-300)
        ("524K", 218), ("262K", 226), ("131K", 234), ("65K", 243), ("32K", 266), ("16K", 300),
        // Raw number brackets (ranks 333-811)
        ("8192", 333), ("4096", 362), ("2048", 411), ("1024", 448), ("512", 487),
        ("256", 522), ("128", 566), ("64", 611), ("32", 666), ("16", 719),
        ("8", 767), ("4", 811), ("2", 852),
        // Score 0 bracket (ranks 852-894)
        ("0", 852)
    ]

    // India player milestones (ranks 1-150)
    static let indiaPlayerMilestones: [String] = [
        // Ranks 1-30
        "47bt", "1bo", "4bl", "583bi", "1bh", "2bf", "4be", "32bd", "230ay", "25at",
        "1as", "11an", "330ak", "20aj", "307ah", "587af", "35ae", "546ac", "16aa", "7z",
        "883t", "3t", "210r", "12q", "784o", "1o", "5n", "23m", "11l", "89k",
        // Ranks 31-60
        "2k", "174j", "10j", "340i", "21i", "2i", "166h", "20h", "2h", "324g",
        "162g", "40g", "1g", "2f", "309e", "154e", "38e", "19e", "4e", "1e",
        "302d", "75d", "37d", "9d", "2d", "1d", "295c", "73c", "18c", "9c",
        // Ranks 61-90
        "2c", "576b", "288b", "72b", "36b", "18b", "9b", "9b", "4b", "2b",
        "2b", "1b", "281a", "35a", "17a", "8a", "4a", "4a", "1a", "549B",
        "274B", "137B", "137B", "68B", "34B", "34B", "17B", "8B", "8B", "4B",
        // Ranks 91-120
        "4B", "2B", "2B", "2B", "1B", "1B", "1B", "536M", "536M", "536M",
        "268M", "268M", "268M", "134M", "67M", "67M", "33M", "33M", "33M", "16M",
        "16M", "16M", "16M", "8M", "8M", "8M", "8M", "4M", "1M", "1M",
        // Ranks 121-150
        "524K", "524K", "524K", "524K", "262K", "262K", "262K", "131K", "131K", "131K",
        "131K", "65K", "65K", "65K", "65K", "65K", "32K", "32K", "32K", "32K",
        "32K", "16K", "16K", "16K", "16K", "16K", "16K", "8192", "8192", "8192"
    ]

    // Extended India milestone brackets for rank calculation (ranks 151+)
    // Total India players: ~1,488
    static let indiaExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // Raw number brackets (ranks 151-1210)
        ("8192", 151), ("4096", 162), ("2048", 171), ("1024", 180), ("512", 196),
        ("256", 222), ("128", 258), ("64", 300), ("32", 377), ("16", 512),
        ("8", 666), ("4", 835), ("2", 1033),
        // Score 0 bracket (ranks 1211-1488)
        ("0", 1211)
    ]

    // Brazil player milestones (ranks 1-150)
    static let brazilPlayerMilestones: [String] = [
        // Ranks 1-30
        "24bv", "1bu", "2bs", "76bk", "1bh", "259bd", "2bb", "7ba", "14az", "899ax",
        "54aw", "837au", "3au", "3ar", "5ao", "10al", "19ai", "36af", "68ac", "127z",
        "3x", "3v", "6t", "26r", "803p", "3o", "5m", "2k", "340i", "664h",
        // Ranks 31-60
        "10h", "324g", "5g", "316f", "4f", "38e", "2e", "302d", "75d", "37d",
        "2d", "590c", "147c", "73c", "36c", "18c", "18c", "9c", "9c", "4c",
        "4c", "2c", "2c", "1c", "288b", "72b", "72b", "36b", "18b", "4b",
        // Ranks 61-90
        "2b", "2b", "1b", "562a", "562a", "281a", "281a", "281a", "140a", "140a",
        "140a", "70a", "70a", "70a", "35a", "35a", "35a", "17a", "17a", "17a",
        "17a", "8a", "4a", "4a", "2a", "2a", "2a", "2a", "1a", "1a",
        // Ranks 91-120
        "1a", "1a", "1a", "1a", "1a", "549B", "549B", "549B", "549B", "274B",
        "274B", "274B", "274B", "274B", "137B", "137B", "137B", "137B", "137B", "68B",
        "68B", "68B", "68B", "68B", "68B", "34B", "34B", "34B", "34B", "34B",
        // Ranks 121-150
        "17B", "17B", "17B", "17B", "17B", "8B", "8B", "8B", "8B", "8B",
        "4B", "4B", "4B", "4B", "4B", "4B", "4B", "2B", "2B", "2B",
        "2B", "2B", "1B", "1B", "1B", "1B", "1B", "1B", "536M", "536M"
    ]

    // Extended Brazil milestone brackets for rank calculation (ranks 151+)
    // Total Brazil players: ~10,000
    static let brazilExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // M-tier brackets
        ("536M", 149), ("268M", 157), ("134M", 173), ("67M", 196), ("33M", 229),
        ("16M", 267), ("8M", 312), ("4M", 388), ("2M", 453), ("1M", 522),
        // K-tier brackets
        ("524K", 555), ("262K", 588), ("131K", 638), ("65K", 700), ("32K", 833), ("16K", 966),
        // Raw number brackets
        ("8192", 1111), ("4096", 1301), ("2048", 1549), ("1024", 1822), ("512", 2271),
        ("256", 2811), ("128", 3414), ("64", 4000), ("32", 4736), ("16", 5467),
        ("8", 6088), ("4", 6767), ("2", 8297),
        // Score 0 bracket (ranks 9297-10000)
        ("0", 9297)
    ]

    // Mexico player milestones - exact values from positions 1-150
    static let mexicoPlayerMilestones: [String] = [
        // Ranks 1-30
        "97bu", "1bu", "2bs", "5bn", "10bm", "615ah", "285bh", "1bf", "64bd", "235az",
        "28ax", "3av", "6at", "12ar", "11ap", "338al", "82ak", "20aj", "587af", "2ae",
        "4ab", "63y", "3w", "883t", "13r", "205q", "3o", "730l", "1k", "170i",
        // Ranks 31-60
        "664h", "5h", "162g", "2g", "39f", "1f", "38e", "1e", "75d", "4d",
        "295c", "36c", "4c", "1c", "288b", "72b", "36b", "9b", "4b", "2b",
        "1b", "562a", "281a", "140a", "140a", "70a", "8a", "4a", "4a", "2a",
        // Ranks 61-90
        "1a", "549B", "549B", "274B", "274B", "137B", "137B", "68B", "68B", "68B",
        "34B", "34B", "34B", "17B", "17B", "8B", "8B", "8B", "4B", "2B",
        "2B", "2B", "1B", "1B", "1B", "1B", "536M", "536M", "536M", "268M",
        // Ranks 91-120
        "268M", "268M", "268M", "134M", "134M", "134M", "134M", "67M", "67M", "67M",
        "67M", "67M", "33M", "33M", "33M", "33M", "33M", "16M", "16M", "16M",
        "16M", "16M", "16M", "16M", "8M", "8M", "8M", "8M", "8M", "8M",
        // Ranks 121-150
        "8M", "4M", "4M", "4M", "4M", "4M", "4M", "4M", "4M", "4M",
        "2M", "2M", "2M", "2M", "2M", "2M", "2M", "2M", "2M", "1M",
        "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M", "524K"
    ]

    // Extended Mexico milestone brackets for rank calculation (ranks 151+)
    // Total Mexico players: 7,229
    static let mexicoExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // K-tier brackets
        ("524K", 151), ("262K", 161), ("131K", 173), ("65K", 186), ("32K", 203), ("16K", 226),
        // Raw number brackets
        ("8192", 264), ("4096", 322), ("2048", 402), ("1024", 488), ("512", 574),
        ("256", 688), ("128", 822), ("64", 1000), ("32", 1175), ("16", 1558),
        ("8", 2222), ("4", 3377), ("2", 4444),
        // Score 0 bracket (ranks 5783-7229)
        ("0", 5783)
    ]

    // Afghanistan player milestones - exact values from positions 1-150
    static let afghanistanPlayerMilestones: [String] = [
        // Ranks 1-30
        "1bz", "2br", "4bl", "583bi", "1bh", "32bd", "30ba", "449ax", "53av", "1as",
        "726ao", "42al", "9ai", "4af", "8ac", "31z", "3x", "7v", "210r", "3p",
        "2n", "2l", "5j", "20h", "158f", "1f", "9e", "151d", "2d", "73c",
        // Ranks 31-60
        "2c", "72b", "4b", "281a", "35a", "8a", "8a", "4a", "1a", "549B",
        "549B", "274B", "274B", "137B", "137B", "137B", "34B", "17B", "17B", "8B",
        "8B", "8B", "4B", "4B", "4B", "4B", "2B", "2B", "2B", "2B",
        // Ranks 61-90
        "2B", "2B", "1B", "1B", "1B", "1B", "1B", "1B", "536M", "536M",
        "536M", "536M", "536M", "536M", "536M", "268M", "268M", "268M", "268M", "268M",
        "268M", "268M", "268M", "268M", "268M", "134M", "134M", "134M", "134M", "134M",
        // Ranks 91-120
        "134M", "134M", "134M", "134M", "134M", "134M", "134M", "67M", "67M", "67M",
        "67M", "67M", "67M", "67M", "67M", "67M", "67M", "67M", "67M", "67M",
        "67M", "33M", "33M", "33M", "33M", "33M", "33M", "33M", "33M", "33M",
        // Ranks 121-150
        "33M", "33M", "33M", "33M", "33M", "33M", "16M", "16M", "16M", "16M",
        "16M", "16M", "16M", "16M", "16M", "16M", "16M", "16M", "16M", "16M",
        "16M", "16M", "8M", "8M", "8M", "8M", "8M", "8M", "8M", "8M"
    ]

    // Extended Afghanistan milestone brackets for rank calculation (ranks 151+)
    // Total Afghanistan players: 11,111
    static let afghanistanExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // M-tier brackets
        ("8M", 143), ("4M", 162), ("2M", 186), ("1M", 218),
        // K-tier brackets
        ("524K", 253), ("262K", 292), ("131K", 333), ("65K", 379), ("32K", 423), ("16K", 477),
        // Raw number brackets
        ("8192", 540), ("4096", 622), ("2048", 718), ("1024", 827), ("512", 944),
        ("256", 1097), ("128", 1300), ("64", 1677), ("32", 2111), ("16", 2798),
        ("8", 3766), ("4", 5000), ("2", 6767),
        // Score 0 bracket (ranks 8987-11111)
        ("0", 8987)
    ]

    // Albania player milestones - exact values from positions 1-150
    static let albaniaPlayerMilestones: [String] = [
        // Ranks 1-30
        "873bz", "109bz", "6bz", "1by", "3bu", "2bq", "39bl", "2bh", "7ba", "3ax",
        "418au", "3at", "47aq", "2an", "5al", "19ai", "546ac", "65aa", "497y", "7x",
        "57v", "883t", "13s", "411q", "3q", "392o", "1n", "1m", "2l", "5k",
        // Ranks 31-60
        "2k", "2k", "1k", "174j", "43j", "10i", "5i", "1i", "5h", "5g",
        "2g", "2g", "633f", "633f", "316f", "158f", "158f", "39f", "19f", "9f",
        "9f", "9f", "4f", "4f", "2f", "2f", "2f", "1f", "618e", "309e",
        // Ranks 61-90
        "154e", "77e", "38e", "38e", "38e", "38e", "38e", "38e", "38e", "19e",
        "19e", "19e", "19e", "19e", "9e", "9e", "9e", "9e", "4e", "4e",
        "2e", "2e", "1e", "604d", "302d", "302d", "75d", "9d", "147c", "18c",
        // Ranks 91-120
        "18c", "4c", "2c", "576b", "144b", "72b", "18b", "9b", "4b", "2b",
        "1b", "1b", "562a", "281a", "140a", "70a", "35a", "35a", "17a", "17a",
        "8a", "8a", "8a", "4a", "2a", "2a", "1a", "1a", "549B", "549B",
        // Ranks 121-153 (extra entries for infinity filtering)
        "274B", "274B", "137B", "68B", "34B", "17B", "8B", "8B", "8B", "4B",
        "4B", "4B", "2B", "2B", "2B", "2B", "2B", "1B", "1B", "1B",
        "536M", "134M", "134M", "67M", "67M", "67M", "33M", "33M", "33M", "33M",
        "16M", "8M", "4M"
    ]

    // Extended Albania milestone brackets for rank calculation (ranks 151+)
    // Total Albania players: 11,222
    static let albaniaExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // M-tier brackets
        ("33M", 147), ("16M", 152), ("8M", 158), ("4M", 165), ("2M", 173), ("1M", 182),
        // K-tier brackets
        ("524K", 195), ("262K", 222), ("131K", 298), ("65K", 358), ("32K", 455), ("16K", 522),
        // Raw number brackets
        ("8192", 611), ("4096", 700), ("2048", 800), ("1024", 918), ("512", 1102),
        ("256", 1377), ("128", 1722), ("64", 2222), ("32", 2877), ("16", 4000),
        ("8", 5555), ("4", 6767), ("2", 8222),
        // Score 0 bracket (ranks 9777-11222)
        ("0", 9777)
    ]

    // Algeria player milestones - exact values from positions 1-150
    static let algeriaPlayerMilestones: [String] = [
        // Ranks 1-30
        "706bq", "2bm", "145bi", "2bf", "1bc", "1az", "858av", "1av", "837au", "5ao",
        "19ai", "2af", "68ac", "1ab", "30x", "57v", "110t", "6r", "784o", "748m",
        "1l", "2j", "10h", "79f", "1e", "36c", "144b", "2b", "140a", "140a",
        // Ranks 31-60
        "35a", "8a", "4a", "2a", "2a", "549B", "274B", "137B", "68B", "68B",
        "34B", "34B", "17B", "17B", "8B", "4B", "4B", "2B", "2B", "1B",
        "1B", "536M", "536M", "134M", "134M", "67M", "33M", "33M", "16M", "16M",
        // Ranks 61-90
        "16M", "8M", "8M", "8M", "4M", "4M", "4M", "2M", "2M", "2M",
        "2M", "1M", "1M", "1M", "1M", "1M", "524K", "524K", "524K", "524K",
        "524K", "524K", "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K",
        // Ranks 91-120
        "262K", "262K", "131K", "131K", "131K", "131K", "131K", "131K", "131K", "131K",
        "131K", "131K", "131K", "131K", "131K", "65K", "65K", "65K", "65K", "65K",
        "65K", "65K", "65K", "65K", "65K", "65K", "65K", "65K", "65K", "65K",
        // Ranks 121-150
        "65K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K",
        "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K",
        "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K"
    ]

    // Extended Algeria milestone brackets for rank calculation (ranks 151+)
    // Total Algeria players: 3,333
    static let algeriaExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // K-tier brackets
        ("16K", 141), ("8192", 164), ("4096", 188), ("2048", 222), ("1024", 264), ("512", 311),
        // Raw number brackets
        ("256", 388), ("128", 488), ("64", 611), ("32", 763), ("16", 955),
        ("8", 1234), ("4", 1676), ("2", 2222),
        // Score 0 bracket (ranks 2777-3333)
        ("0", 2777)
    ]

    static let chinaPlayerMilestones: [String] = [
        // Ranks 1-30
        "99bv", "1br", "5bo", "4bl", "598bj", "8bf", "8be", "518bc", "129ba", "16bd",
        "943az", "235az", "14ax", "6av", "3au", "190ao", "1ao", "2al", "4ai", "9af",
        "17ac", "31z", "30x", "15x", "431s", "1s", "3q", "12o", "187m", "45l",
        // Ranks 31-60
        "2l", "696j", "5j", "1j", "680i", "170i", "42i", "2i", "2h", "5g",
        "19f", "309e", "4e", "1e", "151d", "37d", "18d", "4d", "2d", "590c",
        "295c", "147c", "147c", "9c", "2c", "576b", "288b", "72b", "18b", "18b",
        // Ranks 61-90
        "4b", "8a", "4a", "4a", "2a", "2a", "1a", "549B", "274B", "274B",
        "137B", "137B", "68B", "68B", "34B", "34B", "34B", "17B", "17B", "17B",
        "17B", "8B", "8B", "8B", "8B", "4B", "4B", "4B", "4B", "4B",
        // Ranks 91-120
        "2B", "2B", "2B", "2B", "1B", "1B", "1B", "1B", "536M", "536M",
        "536M", "536M", "536M", "268M", "268M", "268M", "268M", "268M", "134M", "134M",
        "134M", "134M", "134M", "67M", "67M", "67M", "67M", "67M", "67M", "33M",
        // Ranks 121-150
        "33M", "33M", "33M", "33M", "33M", "33M", "16M", "16M", "16M", "16M",
        "16M", "16M", "16M", "16M", "8M", "8M", "8M", "8M", "8M", "8M",
        "4M", "4M", "4M", "4M", "4M", "4M", "4M", "4M", "4M", "4M"
    ]

    // Extended China milestone brackets for rank calculation (ranks 151+)
    // Total China players: 8,192
    static let chinaExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // M-tier brackets (updated from leaderboard data)
        ("2M", 151), ("1M", 165), ("524K", 187), ("262K", 211), ("131K", 243),
        ("65K", 288), ("32K", 333), ("16K", 388), ("8192", 455), ("4096", 505),
        ("2048", 555), ("1024", 600), ("512", 733), ("256", 777), ("128", 888),
        ("64", 1022), ("32", 1234), ("16", 1600),
        // Raw number brackets
        ("8", 2222), ("4", 3111), ("2", 4666),
        // Score 0 bracket
        ("0", 6767)
    ]

    static let southKoreaPlayerMilestones: [String] = [
        // Ranks 1-30
        "1bt", "1bo", "2bj", "8be", "32bd", "235az", "429av", "48ar", "2ao", "615ah",
        "1ag", "559ad", "1ac", "63z", "3y", "3x", "1w", "452u", "55t", "26s",
        "13r", "12q", "12p", "24o", "23n", "46m", "93l", "178k", "348j", "680i",
        // Ranks 31-60
        "2i", "10h", "81g", "633f", "9f", "154e", "2e", "37d", "590c", "9c",
        "144b", "4b", "281a", "35a", "4a", "1a", "549B", "274B", "137B", "68B",
        "68B", "34B", "17B", "8B", "4B", "4B", "2B", "2B", "1B", "536M",
        // Ranks 61-90
        "268M", "268M", "134M", "134M", "134M", "67M", "33M", "33M", "33M", "16M",
        "16M", "16M", "8M", "8M", "8M", "8M", "4M", "4M", "4M", "4M",
        "2M", "2M", "2M", "2M", "1M", "1M", "1M", "1M", "1M", "524K",
        // Ranks 91-120
        "524K", "524K", "524K", "524K", "524K", "262K", "262K", "262K", "262K", "262K",
        "262K", "262K", "131K", "131K", "131K", "131K", "131K", "131K", "131K", "131K",
        "131K", "131K", "65K", "65K", "65K", "65K", "65K", "65K", "65K", "65K",
        // Ranks 121-150
        "65K", "65K", "65K", "65K", "32K", "32K", "32K", "32K", "32K", "32K",
        "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "16K",
        "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K"
    ]

    // Extended South Korea milestone brackets for rank calculation (ranks 151+)
    // Total South Korea players: 3,123
    static let southKoreaExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // K-tier brackets
        ("16K", 140), ("8192", 157), ("4096", 180), ("2048", 221), ("1024", 277),
        ("512", 333), ("256", 400), ("128", 485), ("64", 581), ("32", 676),
        ("16", 833), ("8", 1111), ("4", 1676), ("2", 2161),
        // Score 0 bracket (ranks 2676-3123)
        ("0", 2676)
    ]

    static let italyPlayerMilestones: [String] = [
        // Ranks 1-30
        "19bl", "2be", "1bd", "494bb", "1az", "1ax", "837au", "799as", "1ar", "2ap",
        "5an", "10al", "20aj", "38ah", "146af", "559ad", "2ac", "8aa", "63z", "485x",
        "3w", "28u", "215s", "1r", "12p", "95n", "730l", "11k", "340i", "20h",
        // Ranks 31-60
        "2g", "618e", "1e", "4d", "9c", "72b", "2b", "70a", "4a", "4a",
        "2d", "549B", "68B", "34B", "34B", "4B", "4B", "2B", "2B", "2B",
        "1B", "1B", "1B", "1B", "536M", "536M", "536M", "536M", "268M", "268M",
        // Ranks 61-90
        "268M", "268M", "268M", "134M", "134M", "134M", "134M", "67M", "67M", "67M",
        "67M", "67M", "67M", "67M", "33M", "33M", "33M", "33M", "33M", "33M",
        "33M", "16M", "16M", "16M", "16M", "16M", "16M", "16M", "8M", "8M",
        // Ranks 91-120
        "8M", "8M", "8M", "8M", "8M", "8M", "8M", "8M", "4M", "4M",
        "4M", "4M", "4M", "4M", "4M", "4M", "4M", "4M", "4M", "4M",
        "4M", "4M", "4M", "4M", "4M", "2M", "2M", "2M", "2M", "2M",
        // Ranks 121-150
        "2M", "2M", "2M", "2M", "2M", "2M", "2M", "2M", "2M", "2M",
        "2M", "2M", "2M", "2M", "2M", "2M", "2M", "2M", "2M", "2M",
        "2M", "2M", "2M", "2M", "2M", "2M", "2M", "2M", "2M", "2M"
    ]

    // Extended Italy milestone brackets for rank calculation (ranks 151+)
    // Total Italy players: ~13,856
    static let italyExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // M-tier brackets (ranks 151-208)
        ("2M", 151), ("1M", 175),
        // K-tier brackets (ranks 209-943)
        ("524k", 209), ("262k", 288), ("131k", 368), ("65k", 444), ("32k", 676), ("16k", 944),
        // Raw number brackets (ranks 1222-13856)
        ("8192", 1222), ("4096", 1676), ("2048", 2222), ("1024", 2777), ("512", 3333),
        ("256", 4000), ("128", 4666), ("64", 5333), ("32", 6000), ("16", 6767),
        ("8", 7777), ("4", 8888), ("2", 10284), ("0", 12000)  // Score 0 = ranks 12000-13856
    ]

    static let spainPlayerMilestones: [String] = [
        // Ranks 1-30 (from screenshot data)
        "2bh", "1bf", "4bd", "7bc", "483ba", "1ax", "818at", "190aq", "1am", "601ag",
        "2ae", "4ac", "8aa", "242x", "1v", "1t", "3r", "6p", "23n", "182l",
        "1k", "21i", "20h", "40g", "158f", "1f", "19e", "604d", "37d", "4d",
        // Ranks 31-60
        "1d", "590c", "147c", "18c", "4c", "9b", "4b", "70a", "17a", "17a",
        "8a", "8a", "2a", "1a", "549B", "274B", "274B", "68B", "4B", "4B",
        "2B", "2B", "1B", "536M", "536M", "536M", "268M", "134M", "67M", "67M",
        // Ranks 61-90
        "16M", "16M", "8M", "8M", "8M", "4M", "4M", "4M", "2M", "2M",
        "2M", "2M", "1M", "1M", "1M", "1M", "1M", "524K", "524K", "524K",
        "524K", "524K", "524K", "524K", "524K", "262K", "262K", "262K", "262K", "262K",
        // Ranks 91-120
        "262K", "262K", "262K", "262K", "131K", "131K", "131K", "131K", "131K", "131K",
        "131K", "131K", "131K", "131K", "131K", "131K", "131K", "65K", "65K", "65K",
        "65K", "65K", "65K", "65K", "65K", "65K", "65K", "65K", "65K", "65K",
        // Ranks 121-150
        "65K", "65K", "65K", "65K", "65K", "65K", "65K", "65K", "32K", "32K",
        "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K",
        "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K"
    ]

    // Extended Spain milestone brackets for rank calculation (ranks 151+)
    // Total Spain players: ~14,399
    static let spainExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // K-tier brackets (ranks 151-228)
        ("32K", 151), ("16K", 177),
        // Raw number brackets (ranks 229-14399)
        ("8192", 229), ("4096", 287), ("2048", 400), ("1024", 539), ("512", 711),
        ("256", 950), ("128", 1234), ("64", 1711), ("32", 2444), ("16", 3333),
        ("8", 4444), ("4", 6221), ("2", 8456), ("0", 11147)  // Score 0 = ranks 11147-14399
    ]

    static let netherlandsPlayerMilestones: [String] = [
        // Ranks 1-30
        "218bz", "1bu", "689bp", "1bn", "4bk", "1bj", "2bi", "1bi", "2bh", "4be",
        "1bd", "1bb", "3az", "1av", "199as", "1ar", "11ap", "2ao", "5aj", "300ag",
        "146af", "573ae", "1ad", "8ab", "2aa", "254z", "3v", "6r", "1r", "3q",
        // Ranks 31-60
        "401p", "12p", "11n", "23m", "5m", "91l", "5l", "11k", "43j", "340i",
        "2i", "83h", "5h", "649g", "162g", "81g", "20g", "2g", "158f", "19f",
        "4f", "2f", "2f", "309e", "77e", "2e", "4d", "2d", "2d", "1d",
        // Ranks 61-90
        "147c", "36c", "9c", "4c", "4c", "2c", "576b", "18b", "1b", "562a",
        "140a", "17a", "4a", "2a", "2a", "549B", "549B", "274B", "137B", "137B",
        "68B", "68B", "68B", "34B", "34B", "34B", "17B", "17B", "17B", "17B",
        // Ranks 91-120
        "8B", "8B", "8B", "8B", "8B", "8B", "4B", "4B", "4B", "4B",
        "4B", "2B", "2B", "2B", "2B", "2B", "2B", "1B", "1B", "1B",
        "1B", "1B", "1B", "536M", "536M", "536M", "536M", "536M", "536M", "536M",
        // Ranks 121-151 (extra entry for infinity filtering)
        "536M", "536M", "536M", "268M", "268M", "268M", "268M", "268M", "268M", "268M",
        "268M", "268M", "268M", "268M", "268M", "268M", "134M", "134M", "134M", "134M",
        "134M", "134M", "134M", "134M", "134M", "134M", "134M", "134M", "134M", "134M",
        "67M"
    ]

    // Switzerland player milestones (ranks 1-150)
    static let switzerlandPlayerMilestones: [String] = [
        // Ranks 1-39 (from screenshot)
        "104bx", "1bq", "2bn", "38bk", "1bi", "2bh", "4bg", "4bg", "1bg", "483ba",
        "1az", "1ay", "214av", "107av", "1au", "1as", "390ar", "2aq", "181ao", "1ao",
        "2ap", "10al", "1al", "5ak", "10aj", "19ai", "4ai", "1af", "4ad", "133ab",
        "1aa", "118w", "1v", "3u", "6t", "13s", "6s", "3s", "421r",
        // Ranks 40-79 (from screenshot)
        "105r", "13r", "1r", "3q", "1q", "200p", "3p", "6o", "11n", "1n",
        "2m", "5l", "11k", "2k", "174j", "1j", "5i", "2i", "332h", "10h",
        "162g", "5g", "1f", "2e", "18d", "590c", "36c", "1c", "2b", "1b",
        "281a", "70a", "35a", "17a", "17a", "8a", "8a", "8a", "4a", "4a",
        // Ranks 80-110 (from screenshot)
        "1a", "549B", "549B", "274B", "274B", "274B", "137B", "137B", "137B", "137B",
        "68B", "34B", "17B", "17B", "8B", "8B", "8B", "4B", "2B", "2B",
        "1B", "1B", "536M", "536M", "536M", "536M", "536M", "268M", "268M", "268M",
        // Ranks 111-151 (extra entry for infinity filtering)
        "268M", "134M", "134M", "134M", "134M", "134M", "67M", "67M", "67M", "67M",
        "67M", "67M", "33M", "33M", "33M", "33M", "33M", "33M", "33M", "16M",
        "16M", "16M", "16M", "16M", "16M", "16M", "16M", "16M", "8M", "8M",
        "8M", "8M", "8M", "8M", "8M", "8M", "8M", "4M", "4M", "4M",
        "2M"
    ]

    // Extended Switzerland milestone brackets for rank calculation (ranks 151+)
    // Total Switzerland players: ~20,000
    static let switzerlandExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // M-tier brackets (ranks 151-180) from screenshot
        ("4M", 151), ("2M", 163), ("1M", 176),
        // K-tier brackets (ranks 181-676) from screenshot
        ("524K", 181), ("262K", 211), ("131K", 257), ("65K", 311), ("32K", 421), ("16K", 676),
        // Raw number brackets (ranks 1000-20000) from screenshot
        ("8192", 1000), ("4096", 1532), ("2048", 1975), ("1024", 2659), ("512", 3872),
        ("256", 5444), ("128", 6767), ("64", 8000), ("32", 9277), ("16", 11111),
        ("8", 12345), ("4", 14321), ("2", 16000), ("0", 18000)  // Score 0 = ranks 18000-20000
    ]

    // Norway player milestones (ranks 1-150)
    static let norwayPlayerMilestones: [String] = [
        // Ranks 1-40 (from screenshot)
        "27bz", "853by", "1br", "4bl", "1bj", "2bg", "4bd", "7ba", "117az", "1ay",
        "1aw", "399as", "1ar", "46ap", "1ao", "1am", "1ak", "2ai", "1ai", "615ah",
        "615ah", "307ah", "9ah", "1ag", "1ae", "1ac", "1aa", "1aa", "509z", "1v",
        "1s", "3q", "1q", "200p", "2n", "5l", "1l", "87j", "10j", "2j",
        // Ranks 41-80 (from screenshot)
        "1j", "170i", "664h", "1h", "10g", "39f", "154e", "19e", "604d", "4d",
        "1c", "9b", "2b", "562a", "281a", "70a", "17a", "1a", "274B", "137B",
        "137B", "34B", "34B", "17B", "17B", "8B", "8B", "8B", "2B", "2B",
        "2B", "1B", "1B", "1B", "536M", "536M", "268M", "268M", "268M", "134M",
        // Ranks 81-90 (134M then 67M)
        "134M", "134M", "134M", "67M", "67M", "67M", "67M", "67M", "67M", "33M",
        // Ranks 91-110 (33M then 16M)
        "33M", "33M", "33M", "33M", "33M", "33M", "33M", "16M", "16M", "16M",
        "16M", "16M", "16M", "16M", "16M", "16M", "16M", "16M", "16M", "16M",
        // Ranks 111-130 (16M then 8M)
        "16M", "8M", "8M", "8M", "8M", "8M", "8M", "8M", "8M", "8M",
        "8M", "8M", "8M", "8M", "8M", "8M", "8M", "8M", "8M", "8M",
        // Ranks 131-152 (8M then 4M, extra entries for infinity filtering)
        "8M", "8M", "8M", "8M", "8M", "4M", "4M", "4M", "4M", "4M",
        "4M", "4M", "4M", "4M", "4M", "4M", "4M", "4M", "4M", "4M",
        "2M", "1M"
    ]

    // Extended Norway milestone brackets for rank calculation (ranks 151+)
    // Total Norway players: ~34,924
    static let norwayExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // M-tier brackets (ranks 151-226)
        ("4M", 151), ("2M", 170), ("1M", 226),
        // K-tier brackets (ranks 344-1199)
        ("524K", 344), ("262K", 511), ("131K", 676), ("65K", 838), ("32K", 1000), ("16K", 1199),
        // Raw number brackets (ranks 1465-34924)
        ("8192", 1465), ("4096", 1888), ("2048", 2222), ("1024", 2777), ("512", 3444),
        ("256", 4313), ("128", 5555), ("64", 6767), ("32", 8355), ("16", 10000),
        ("8", 12934), ("4", 16666), ("2", 21111), ("0", 27131)  // Score 0 = ranks 27131-34924
    ]

    // Denmark player milestones (ranks 1-150)
    static let denmarkPlayerMilestones: [String] = [
        // Ranks 1-30
        "873bz", "13bz", "26by", "1bx", "3bw", "379bt", "1bt", "11br", "86bp", "2bl",
        "1bl", "76bk", "19bk", "2bk", "74bj", "1bj", "1bi", "2bh", "4bg", "32bd",
        "471az", "230ay", "449ax", "429av", "102at", "24ar", "90ao", "1ao", "2an", "1ak",
        // Ranks 31-60
        "601ag", "1ag", "71ae", "17ae", "2ae", "1ac", "2aa", "994y", "1x", "226u",
        "113u", "14u", "3u", "1u", "441t", "110t", "13t", "3t", "1s", "3r",
        "205q", "51q", "12q", "3q", "1q", "200p", "50p", "3p", "1p", "1p",
        // Ranks 61-90
        "1o", "11n", "2n", "1n", "93m", "2m", "5l", "22k", "174j", "10j",
        "680i", "170i", "85i", "42i", "42i", "21i", "21i", "2i", "5h", "79f",
        "4e", "302d", "18d", "2d", "2d", "1d", "295c", "73c", "18c", "4c",
        // Ranks 91-120
        "2c", "2c", "1c", "72b", "18b", "9b", "2b", "1b", "281a", "140a",
        "140a", "70a", "70a", "35a", "8a", "2a", "1a", "1a", "549B", "549B",
        "549B", "274B", "68B", "68B", "34B", "34B", "34B", "17B", "17B", "17B",
        // Ranks 121-152 (extra entries for infinity filtering)
        "17B", "17B", "17B", "8B", "8B", "8B", "8B", "8B", "8B", "8B",
        "8B", "4B", "4B", "4B", "4B", "4B", "4B", "4B", "4B", "4B",
        "4B", "4B", "4B", "4B", "2B", "2B", "2B", "2B", "2B", "2B",
        "1B", "536M"
    ]

    // Extended Denmark milestone brackets for rank calculation (ranks 151+)
    // Total Denmark players: ~90,123
    static let denmarkExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // B-tier brackets (ranks 151-220)
        ("2B", 151), ("1B", 166),
        // M-tier brackets (ranks 221-2965)
        ("536M", 221), ("268M", 297), ("134M", 400), ("67M", 531), ("33M", 662),
        ("16M", 928), ("8M", 1234), ("4M", 1711), ("2M", 2287), ("1M", 2966),
        // K-tier brackets (ranks 3532-9999)
        ("524K", 3532), ("262K", 4633), ("131K", 5555), ("65K", 6767), ("32K", 7676), ("16K", 10000),
        // Raw number brackets (ranks 12345-90123)
        ("8192", 12345), ("4096", 16767), ("2048", 20000), ("1024", 24315), ("512", 26767),
        ("256", 31234), ("128", 36767), ("64", 43322), ("32", 48765), ("16", 54321),
        ("8", 60000), ("4", 67676), ("2", 76767), ("0", 82898)  // Score 0 = ranks 82898-90123
    ]

    // Finland player milestones (ranks 1-150)
    static let finlandPlayerMilestones: [String] = [
        // Ranks 1-30
        "436bz", "94bt", "1br", "2bq", "1bm", "1bi", "570bh", "142bh", "71bh", "17bh",
        "1bh", "556bg", "1be", "1bd", "15bb", "7ba", "3ba", "471az", "117az", "14az",
        "1az", "3ay", "1ax", "6av", "12at", "1at", "1as", "2ar", "5aq", "11ap",
        // Ranks 31-60
        "2ap", "1ap", "1al", "2ak", "645aj", "322aj", "80aj", "20aj", "10aj", "2aj",
        "630ai", "315ai", "78ai", "19ai", "2ai", "1ah", "9ag", "146af", "36af", "4af",
        "2af", "1ad", "8ab", "32aa", "16aa", "4aa", "1aa", "509z", "127z", "63z",
        // Ranks 61-90
        "31z", "31z", "15z", "7z", "1z", "7y", "463v", "3u", "1u", "110t",
        "13t", "3t", "1t", "3s", "6r", "1r", "6q", "6q", "3q", "24o",
        "3o", "1o", "11n", "5n", "5n", "2n", "748m", "23m", "91l", "11l",
        // Ranks 91-120
        "1l", "89k", "11k", "2k", "696j", "10j", "2j", "85i", "10i", "664h",
        "41h", "633f", "316f", "158f", "39f", "4f", "1f", "2e", "151d", "4d",
        "4c", "2c", "2c", "1c", "576b", "144b", "144b", "72b", "72b", "72b",
        // Ranks 121-150
        "36b", "18b", "9b", "4b", "4b", "1b", "562a", "562a", "281a", "281a",
        "70a", "70a", "70a", "70a", "17a", "8a", "8a", "4a", "4a", "4a",
        "4a", "4a", "2a", "2a", "2a", "2a", "2a", "1a", "1a", "1a", "1a", "1a", "1a"
    ]

    static let polandPlayerMilestones: [String] = [
        // Ranks 1-30
        "672bo", "1bo", "4bl", "4bi", "570bh", "3bc", "30bb", "3ay", "1aw", "1aw",
        "1aw", "429av", "53av", "3av", "1at", "3as", "48ar", "3ar", "1ar", "2aq",
        "11ap", "22ao", "2ao", "709an", "1aj", "300ag", "1af", "69ad", "34ac", "1ac",
        // Ranks 31-60
        "1ab", "4aa", "2aa", "497y", "3y", "115v", "7u", "1u", "3s", "26r",
        "3r", "51q", "3q", "1q", "1q", "1q", "401p", "200p", "50p", "12p",
        "12p", "1o", "1n", "93m", "11m", "5m", "5m", "2m", "2m", "1m",
        // Ranks 61-90
        "1m", "1m", "365l", "182l", "45l", "45l", "22l", "11l", "5l", "2l",
        "2l", "1l", "1l", "713k", "713k", "356k", "178k", "89k", "22k", "22k",
        "2k", "1k", "1k", "348j", "174j", "174j", "87j", "43j", "43j", "43j",
        // Ranks 91-120
        "21j", "21j", "10j", "5j", "5j", "2j", "1j", "340i", "42i", "10i",
        "10i", "5i", "5i", "2i", "1i", "1i", "664h", "166h", "41h", "20h",
        "20h", "10h", "2h", "324g", "20g", "10g", "2g", "2g", "1g", "158f",
        // Ranks 121-150
        "39f", "4f", "9e", "9e", "4e", "2e", "2e", "1e", "604d", "604d",
        "604d", "302d", "302d", "151d", "75d", "37d", "18d", "18d", "9d", "9d",
        "2d", "73c", "18c", "18c", "4c", "2c", "2c", "1c", "288b", "288b"
    ]

    // Extended Finland milestone brackets for rank calculation (ranks 151+)
    // Total Finland players: ~87,654
    static let finlandExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // a-tier and B-tier brackets (ranks 151-392)
        ("1a", 151), ("549B", 153), ("274B", 162), ("137B", 183), ("68B", 198), ("34B", 233),
        ("17B", 257), ("8B", 292), ("4B", 322), ("2B", 355), ("1B", 392),
        // M-tier brackets (ranks 428-999)
        ("536M", 428), ("268M", 467), ("134M", 511), ("67M", 571), ("33M", 642),
        ("16M", 725), ("8M", 785), ("4M", 843), ("2M", 908), ("1M", 999),
        // K-tier brackets (ranks 1111-3888)
        ("524K", 1111), ("262K", 1279), ("131K", 1667), ("65K", 2222), ("32K", 2999), ("16K", 3888),
        // Raw number brackets (ranks 5111-87654)
        ("8192", 5111), ("4096", 6767), ("2048", 8956), ("1024", 12345), ("512", 17890),
        ("256", 24321), ("128", 29876), ("64", 34543), ("32", 41111), ("16", 50000),
        ("8", 58888), ("4", 67676), ("2", 76767), ("0", 87654)  // Score 0 = end rank
    ]

    // Extended Poland milestone brackets for rank calculation (ranks 151+)
    // Total Poland players: ~67,108
    static let polandExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // b-tier brackets (ranks 151-160)
        ("72b", 151), ("36b", 152), ("18b", 153), ("9b", 154), ("4b", 155),
        ("2b", 157), ("1b", 159),
        // a-tier brackets (ranks 161-201)
        ("562a", 161), ("281a", 162), ("140a", 164), ("70a", 167), ("35a", 171),
        ("17a", 176), ("8a", 182), ("4a", 189), ("2a", 194), ("1a", 198),
        // B-tier brackets (ranks 202-244)
        ("549B", 202), ("274B", 203), ("137B", 205), ("68B", 207), ("34B", 211),
        ("17B", 216), ("8B", 222), ("4B", 229), ("2B", 236), ("1B", 244),
        // M-tier brackets (ranks 254-639)
        ("536M", 254), ("268M", 266), ("134M", 281), ("67M", 300), ("33M", 328),
        ("16M", 366), ("8M", 419), ("4M", 475), ("2M", 551), ("1M", 639),
        // K-tier brackets (ranks 737-2222)
        ("524K", 737), ("262K", 853), ("131K", 991), ("65K", 1200), ("32K", 1667), ("16K", 2222),
        // Raw number brackets (ranks 3333-67108)
        ("8192", 3333), ("4096", 4567), ("2048", 6767), ("1024", 8765), ("512", 12345),
        ("256", 16789), ("128", 22222), ("64", 29876), ("32", 36925), ("16", 41414),
        ("8", 50000), ("4", 54321), ("2", 56789), ("0", 60000)  // Score 0 = ranks 60000-67108
    ]

    // Belgium player milestones (ranks 1-150)
    // Total Belgium players: ~8,989
    static let belgiumPlayerMilestones: [String] = [
        // Ranks 1-30
        "2bt", "1br", "38bk", "2bi", "1bg", "16be", "1bd", "115ay", "3av", "799as",
        "86am", "1aj", "1af", "4ad", "16ab", "971x", "1v", "3t", "1t", "3s",
        "6r", "411q", "1m", "5l", "178k", "44k", "22k", "5k", "696j", "174j",
        // Ranks 31-60
        "87j", "10j", "2j", "10i", "348j", "10j", "1j", "1j", "680i", "340i",
        "170i", "85i", "20g", "10g", "2g", "19f", "154e", "1e", "9d", "147c",
        "4c", "288b", "36b", "9b", "4b", "1b", "140a", "35a", "4a", "1a",
        // Ranks 61-90
        "274B", "34B", "17B", "8B", "8B", "4B", "4B", "2B", "2B", "2B",
        "2B", "1B", "1B", "1B", "1B", "1B", "1B", "1B", "536M", "536M",
        "536M", "536M", "536M", "536M", "536M", "536M", "536M", "536M", "268M", "268M",
        // Ranks 91-120
        "268M", "268M", "268M", "268M", "268M", "268M", "268M", "268M", "268M", "268M",
        "268M", "268M", "268M", "268M", "134M", "134M", "134M", "134M", "134M", "134M",
        "134M", "134M", "134M", "134M", "134M", "134M", "134M", "134M", "134M", "134M",
        // Ranks 121-150
        "134M", "134M", "134M", "134M", "134M", "67M", "67M", "67M", "67M", "67M",
        "67M", "67M", "67M", "67M", "67M", "67M", "67M", "67M", "67M", "67M",
        "67M", "67M", "67M", "67M", "67M", "67M", "67M", "67M", "67M", "67M"
    ]

    // Extended Belgium milestone brackets for rank calculation (ranks 151+)
    // Total Belgium players: ~8,989
    static let belgiumExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // M-tier brackets (ranks 151-666)
        ("67M", 151), ("33M", 168), ("16M", 222), ("8M", 300), ("4M", 399),
        ("2M", 533), ("1M", 611),
        // K-tier brackets (ranks 667-1233)
        ("524K", 667), ("262K", 767), ("131K", 833), ("65K", 911), ("32K", 1000), ("16K", 1111),
        // Raw number brackets (ranks 1234-8989)
        ("8192", 1234), ("4096", 1360), ("2048", 1555), ("1024", 1676), ("512", 2000),
        ("256", 2578), ("128", 2840), ("64", 3333), ("32", 3888), ("16", 4444),
        ("8", 5000), ("4", 5666), ("2", 6767), ("0", 7676)  // Score 0 = ranks 7676-8989
    ]

    // Sweden player milestones (ranks 1-150)
    // Total Sweden players: ~6,288
    static let swedenPlayerMilestones: [String] = [
        // Ranks 1-30
        "109bz", "46bs", "706bd", "313bl", "1bi", "32bd", "943az", "3az", "1ax", "49as",
        "1am", "5ak", "38ah", "2ae", "4ac", "497y", "121x", "1w", "842r", "1q",
        "1p", "1o", "2n", "5m", "5l", "5k", "21j", "170i", "2i", "83h",
        // Ranks 31-60
        "5h", "649g", "2g", "9e", "75d", "2d", "147c", "2c", "1c", "288b",
        "36b", "9b", "9b", "4b", "2b", "2b", "1b", "281a", "35a", "2a",
        "1a", "1a", "549B", "137B", "34B", "17B", "17B", "1B", "536M", "536M",
        // Ranks 61-90
        "268M", "268M", "268M", "134M", "134M", "134M", "67M", "67M", "67M", "67M",
        "33M", "33M", "33M", "33M", "16M", "16M", "16M", "16M", "16M", "8M",
        "8M", "8M", "8M", "8M", "8M", "4M", "4M", "4M", "4M", "4M",
        // Ranks 91-120
        "4M", "4M", "2M", "2M", "2M", "2M", "2M", "2M", "2M", "2M",
        "2M", "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M",
        "1M", "1M", "1M", "524K", "524K", "524K", "524K", "524K", "524K", "524K",
        // Ranks 121-151 (extra entry for infinity filtering)
        "524K", "524K", "524K", "524K", "524K", "524K", "524K", "262K", "262K", "262K",
        "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K",
        "262K", "262K", "131K", "131K", "131K", "131K", "131K", "131K", "131K", "131K",
        "65K"
    ]

    // Extended Sweden milestone brackets for rank calculation (ranks 151+)
    // Total Sweden players: ~6,288
    static let swedenExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // K-tier brackets (ranks 151-295)
        ("131K", 151), ("65K", 168), ("32K", 200), ("16K", 244),
        // Raw number brackets (ranks 296-6288)
        ("8192", 296), ("4096", 366), ("2048", 452), ("1024", 555), ("512", 666),
        ("256", 833), ("128", 1123), ("64", 1578), ("32", 2000), ("16", 2667),
        ("8", 3333), ("4", 4000), ("2", 4676), ("0", 5412)  // Score 0 = ranks 5412-6288
    ]

    // Austria player milestones (ranks 1-150)
    // Total Austria players: ~7,543
    static let austriaPlayerMilestones: [String] = [
        // Ranks 1-30
        "2bq", "1bl", "33bf", "3ba", "1ax", "399as", "1ar", "5aq", "19ai", "1ag",
        "1ae", "2ac", "497y", "3w", "441t", "110t", "13t", "862s", "1s", "3r",
        "6q", "3q", "3q", "1q", "6o", "5m", "1m", "11l", "1l", "2k",
        // Ranks 31-60
        "10j", "1j", "10i", "166h", "1h", "649g", "40g", "2g", "79f", "4f",
        "618e", "77e", "9e", "1e", "151d", "1d", "18b", "4b", "2b", "562a",
        "140a", "35a", "17a", "8a", "8a", "2a", "68B", "34B", "17B", "8B",
        // Ranks 61-90
        "8B", "4B", "4B", "2B", "2B", "2B", "1B", "1B", "1B", "536M",
        "268M", "134M", "134M", "134M", "67M", "67M", "67M", "67M", "33M", "33M",
        "33M", "16M", "16M", "16M", "16M", "8M", "8M", "8M", "4M", "4M",
        // Ranks 91-120
        "4M", "2M", "2M", "2M", "2M", "1M", "1M", "1M", "1M", "1M",
        "524K", "524K", "524K", "524K", "524K", "262K", "262K", "262K", "262K", "262K",
        "262K", "131K", "131K", "131K", "131K", "131K", "131K", "65K", "65K", "65K",
        // Ranks 121-150
        "65K", "65K", "65K", "65K", "32K", "32K", "32K", "32K", "32K", "32K",
        "32K", "32K", "32K", "32K", "16K", "16K", "16K", "16K", "16K", "16K",
        "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "8192"
    ]

    // Extended Austria milestone brackets for rank calculation (ranks 151+)
    // Total Austria players: ~7,543
    static let austriaExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // Raw number brackets (ranks 151-7543)
        ("8192", 151), ("4096", 169), ("2048", 194), ("1024", 231), ("512", 283),
        ("256", 347), ("128", 422), ("64", 511), ("32", 782), ("16", 1296),
        ("8", 1922), ("4", 2837), ("2", 4111), ("0", 5784)  // Score 0 = ranks 5784-7543
    ]

    // Ireland leaderboard data - top 150 player milestones
    // Total Ireland players: ~34,567
    static let irelandPlayerMilestones: [String] = [
        // Ranks 1-30
        "436bz", "109bz", "2bt", "353bq", "1bo", "4bl", "38bk", "149bj", "1bi", "543bf",
        "66be", "2be", "1bc", "15ba", "3ba", "1ba", "471az", "117az", "14ax", "1ax",
        "1av", "1au", "3at", "195ar", "97ar", "24ar", "1ar", "190aq", "11aq", "1aq",
        // Ranks 31-60
        "726ao", "363ao", "363ao", "181ao", "90ao", "45ao", "45ao", "346am", "173am", "43am",
        "676al", "169al", "84al", "21al", "2al", "1al", "1al", "1ak", "645aj", "322aj",
        "161aj", "80aj", "40aj", "20aj", "20aj", "307ah", "153ah", "76ah", "1ah", "1ag",
        // Ranks 61-90
        "146af", "18af", "1af", "71ae", "8ae", "1ae", "34ad", "8ad", "2ad", "1ad",
        "136ac", "17ac", "1ac", "2ab", "509z", "254z", "63z", "31z", "15z", "7z",
        "1z", "15y", "7w", "3w", "926v", "463v", "57v", "3v", "14u", "431s",
        // Ranks 91-120
        "215s", "53s", "13s", "3s", "6r", "822q", "51q", "1q", "25p", "784o",
        "6o", "23n", "1n", "187m", "187m", "46m", "23m", "5m", "2m", "1m",
        "730l", "182l", "91l", "91l", "45l", "45l", "45l", "22l", "11l", "5l",
        // Ranks 121-152 (extra entries for infinity filtering)
        "2l", "713k", "89k", "44k", "44k", "11k", "5k", "1k", "5j", "1j",
        "2i", "332h", "41h", "10h", "5h", "5h", "2h", "1h", "1h", "81g",
        "5g", "2g", "633f", "19f", "38e", "2e", "1e", "75d", "2d", "9c",
        "4c", "1c"
    ]

    // Extended Ireland milestone brackets for rank calculation (ranks 151+)
    // Total Ireland players: ~34,567
    static let irelandExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // Low tier brackets (ranks 151-220)
        ("144b", 153), ("4M", 193), ("2M", 203), ("1M", 221),
        // K-tier brackets (ranks 247-547)
        ("524K", 247), ("262K", 284), ("131K", 341), ("65K", 425), ("32K", 486), ("16K", 547),
        // Raw number brackets (ranks 611-34567)
        ("8192", 611), ("4096", 676), ("2048", 745), ("1024", 867), ("512", 1111),
        ("256", 1593), ("128", 2222), ("64", 3000), ("32", 4312), ("16", 6767),
        ("8", 9234), ("4", 12345), ("2", 18989), ("0", 26048)  // Score 0 = ranks 26048-34567
    ]

    // Portugal leaderboard data - top 150 player milestones
    // Total Portugal players: ~98,989
    static let portugalPlayerMilestones: [String] = [
        // Ranks 1-30
        "873bz", "198bv", "3bv", "344bp", "1bn", "1bj", "4bh", "543bf", "271bf", "483ba",
        "241ba", "241ba", "120ba", "120ba", "15ba", "1ay", "439aw", "858av", "1av", "1as",
        "744ap", "2ao", "2al", "1ak", "5aj", "19ai", "1ai", "2ah", "1ah", "2ag",
        // Ranks 31-60
        "1ag", "2ae", "4ad", "1ad", "17ac", "248y", "7v", "1v", "14u", "3u",
        "1u", "3s", "6r", "1q", "12p", "392o", "3o", "2m", "5l", "2l",
        "2l", "1l", "178k", "44k", "2k", "83h", "2h", "10g", "79f", "2f",
        // Ranks 61-90
        "4e", "9d", "2d", "1d", "590c", "295c", "147c", "147c", "36c", "2c",
        "8a", "8a", "4a", "2a", "1a", "1a", "549B", "274B", "137B", "137B",
        "68B", "68B", "68B", "34B", "34B", "34B", "34B", "17B", "17B", "17B",
        // Ranks 91-120
        "17B", "17B", "8B", "8B", "8B", "8B", "8B", "8B", "4B", "4B",
        "4B", "4B", "4B", "4B", "4B", "2B", "2B", "2B", "2B", "2B",
        "2B", "2B", "2B", "2B", "1B", "1B", "1B", "1B", "1B", "1B",
        // Ranks 121-151 (extra entry for infinity filtering)
        "1B", "1B", "1B", "536M", "536M", "536M", "536M", "536M", "536M", "536M",
        "536M", "536M", "536M", "536M", "536M", "536M", "268M", "268M", "268M", "268M",
        "268M", "268M", "268M", "268M", "268M", "268M", "268M", "268M", "268M", "268M",
        "134M"
    ]

    // Greece leaderboard data - top 150 player milestones
    // Total Greece players: ~41,414
    static let greecePlayerMilestones: [String] = [
        // Ranks 1-30
        "5bq", "627bl", "1bi", "2bf", "7bc", "1bb", "214av", "1as", "1ap", "1an",
        "19ai", "2ag", "8ae", "1ac", "1aa", "121x", "1t", "1s", "3r", "6q",
        "196o", "1o", "2n", "5m", "22l", "1j", "10i", "324g", "9f", "2f",
        // Ranks 31-60
        "1e", "9d", "576b", "18b", "1b", "140a", "17a", "4a", "2a", "2a",
        "1a", "137B", "34B", "17B", "8B", "8B", "4B", "2B", "2B", "1B",
        "268M", "268M", "134M", "134M", "67M", "67M", "67M", "33M", "33M", "33M",
        // Ranks 61-90
        "33M", "33M", "16M", "16M", "16M", "8M", "8M", "8M", "8M", "8M",
        "8M", "8M", "4M", "4M", "4M", "4M", "4M", "4M", "4M", "4M",
        "4M", "4M", "2M", "2M", "2M", "2M", "2M", "2M", "2M", "2M",
        // Ranks 91-120
        "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M",
        "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M", "524K", "524K",
        "524K", "524K", "524K", "524K", "524K", "524K", "524K", "524K", "524K", "524K",
        // Ranks 121-150
        "524K", "524K", "524K", "524K", "262K", "262K", "262K", "262K", "262K", "262K",
        "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K",
        "131K", "131K", "131K", "131K", "131K", "131K", "131K", "131K", "131K", "131K"
    ]

    // Czechia leaderboard data - top 150 player milestones
    // Total Czechia players: ~61,616
    static let czechiaPlayerMilestones: [String] = [
        // Ranks 1-30
        "873bz", "873bz", "218bz", "13bz", "3bz", "1bz", "1by", "1bv", "361br", "1bp",
        "321bm", "1bl", "1bj", "1bi", "16bf", "8bf", "8bf", "2bf", "1bf", "132be",
        "8be", "2be", "1bd", "7bc", "1bc", "61bb", "3bb", "1bb", "483ba", "241ba",
        // Ranks 31-60
        "60ba", "30ba", "15ba", "15ba", "7ba", "7ba", "7ba", "3ba", "1ba", "1ay",
        "28ax", "858av", "13au", "399as", "1ar", "190aq", "1ap", "2an", "5al", "10aj",
        "2aj", "1aj", "157ai", "2ai", "4ag", "8ae", "4ad", "2ac", "1ab", "509z",
        // Ranks 61-90
        "3z", "15y", "3y", "7w", "3w", "3w", "1w", "1w", "926v", "463v",
        "231v", "115v", "57v", "28v", "28v", "3v", "3u", "1u", "441t", "110t",
        "55t", "27t", "27t", "3t", "26s", "6s", "3s", "421r", "26r", "6r",
        // Ranks 91-120
        "3r", "3r", "822q", "411q", "205q", "205q", "102q", "51q", "25q", "25q",
        "12q", "12q", "6q", "6q", "6q", "3q", "3q", "3q", "1q", "401p",
        "200p", "50p", "25p", "12p", "6p", "6p", "3p", "1p", "6o", "1o",
        // Ranks 121-150
        "2n", "5m", "365l", "2l", "5k", "2k", "2k", "1k", "348j", "174j",
        "43j", "43j", "10j", "2j", "1j", "680i", "340i", "340i", "170i", "85i",
        "85i", "42i", "21i", "10i", "5i", "1i", "332h", "649g", "20g", "633f"
    ]

    // Extended Portugal milestone brackets for rank calculation (ranks 151+)
    // Total Portugal players: ~98,989
    static let portugalExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // M-tier brackets (ranks 151-1615)
        ("134M", 153), ("67M", 182), ("33M", 293), ("16M", 433), ("8M", 600),
        ("4M", 845), ("2M", 1234), ("1M", 1616),
        // K-tier brackets (ranks 2425-7676)
        ("524K", 2425), ("262K", 3333), ("131K", 4444), ("65K", 5656), ("32K", 6767), ("16K", 7676),
        // Raw number brackets (ranks 9000-98989)
        ("8192", 9000), ("4096", 10646), ("2048", 12345), ("1024", 15000), ("512", 18888),
        ("256", 22222), ("128", 27777), ("64", 33333), ("32", 40000), ("16", 46767),
        ("8", 55555), ("4", 67676), ("2", 76767), ("0", 89898)  // Score 0 = ranks 89898-98989
    ]

    // Extended Greece milestone brackets for rank calculation (ranks 151+)
    // Total Greece players: ~41,414
    static let greeceExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // K-tier brackets (ranks 151-310)
        ("131K", 151), ("65K", 183), ("32K", 224), ("16K", 311),
        // Raw number brackets (ranks 456-41414)
        ("8192", 456), ("4096", 723), ("2048", 1234), ("1024", 1938), ("512", 2847),
        ("256", 4000), ("128", 5555), ("64", 7345), ("32", 12345), ("16", 16767),
        ("8", 22222), ("4", 26918), ("2", 31676), ("0", 35252)  // Score 0 = ranks 35252-41414
    ]

    // Extended Czechia milestone brackets for rank calculation (ranks 151+)
    // Total Czechia players: ~61,616
    static let czechiaExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // High-tier brackets (ranks 151-204)
        ("19f", 151), ("154e", 152), ("9e", 153), ("302d", 154), ("1d", 158),
        ("295c", 159), ("1c", 171), ("576b", 174), ("288b", 178), ("144b", 180),
        ("36b", 181), ("9b", 182), ("4b", 183), ("2b", 184), ("562a", 186),
        ("281a", 187), ("140a", 188), ("70a", 189), ("35a", 190), ("8a", 192),
        ("4a", 194), ("2a", 197), ("1a", 201),
        // B-tier brackets (ranks 205-247)
        ("549B", 205), ("274B", 206), ("137B", 208), ("68B", 209), ("34B", 212),
        ("17B", 216), ("8B", 221), ("4B", 227), ("2B", 236), ("1B", 247),
        // M-tier brackets (ranks 260-1802)
        ("536M", 260), ("268M", 281), ("134M", 322), ("67M", 377), ("33M", 444),
        ("16M", 522), ("8M", 676), ("4M", 898), ("2M", 1234), ("1M", 1802),
        // K-tier brackets (ranks 2425-6767)
        ("524K", 2425), ("262K", 3000), ("131K", 3666), ("65K", 4449), ("32K", 5356), ("16K", 6767),
        // Raw number brackets (ranks 7676-61616)
        ("8192", 7676), ("4096", 8989), ("2048", 9898), ("1024", 11111), ("512", 12345),
        ("256", 14000), ("128", 15676), ("64", 17922), ("32", 20000), ("16", 23456),
        ("8", 28989), ("4", 34567), ("2", 41414), ("0", 50000)  // Score 0 = ranks 50000-61616
    ]

    // Romania leaderboard data - top 85 player milestones
    // Total Romania players: ~5,966
    static let romaniaPlayerMilestones: [String] = [
        // Ranks 1-30
        "657bn", "2bm", "299bj", "17bh", "265be", "506bc", "3bb", "471az", "1ay", "1aw",
        "1av", "744ap", "1an", "10aj", "1ag", "4ad", "1ac", "2ab", "8aa", "1aa",
        "509z", "127z", "7z", "463v", "3u", "6s", "421r", "13r", "205q", "6q",
        // Ranks 31-60
        "3p", "6o", "5n", "2n", "2n", "748m", "93m", "11m", "365l", "5j",
        "10h", "79f", "1e", "73c", "36b", "562a", "17a", "2a", "1a", "137B",
        "34B", "17B", "17B", "8B", "4B", "2B", "2B", "1B", "1B", "1B",
        // Ranks 61-85
        "536M", "268M", "67M", "67M", "33M", "33M", "33M", "16M", "8M", "8M",
        "4M", "4M", "4M", "4M", "4M", "2M", "2M", "2M", "2M", "2M",
        "2M", "2M", "2M", "2M", "1M",
        // Ranks 86-97 (1M bracket)
        "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M",
        "1M", "1M",
        // Ranks 98-123 (524K bracket)
        "524K", "524K", "524K", "524K", "524K", "524K", "524K", "524K", "524K", "524K",
        "524K", "524K", "524K", "524K", "524K", "524K", "524K", "524K", "524K", "524K",
        "524K", "524K", "524K", "524K", "524K", "524K",
        // Ranks 124-150 (262K bracket)
        "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K",
        "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K",
        "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K"
    ]

    // Extended Romania milestone brackets for rank calculation (ranks 86+)
    // Total Romania players: ~5,966
    static let romaniaExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // K-tier brackets (ranks 98-377)
        ("524K", 98), ("262K", 124), ("131K", 167), ("65K", 233), ("32K", 300), ("16K", 377),
        // Raw number brackets (ranks 466-5966)
        ("8192", 466), ("4096", 557), ("2048", 655), ("1024", 801), ("512", 979),
        ("256", 1134), ("128", 1400), ("64", 1746), ("32", 2111), ("16", 2683),
        ("8", 3333), ("4", 4096), ("2", 4667), ("0", 5333)  // Score 0 = ranks 5333-5966
    ]

    // Malaysia leaderboard data - top 82 player milestones
    // Total Malaysia players: ~52,111
    static let malaysiaPlayerMilestones: [String] = [
        // Ranks 1-30
        "672bo", "4bl", "8bf", "1bc", "471az", "1av", "1ar", "1ap", "346am", "41ak",
        "20aj", "39ai", "1ag", "1af", "8ae", "1ac", "248y", "1w", "822q", "1p",
        "1n", "2m", "1l", "2k", "5j", "21i", "174j", "1j", "316f", "2f",
        // Ranks 31-60
        "38e", "302d", "4b", "1b", "140a", "35a", "8a", "2a", "1a", "274B",
        "137B", "68B", "68B", "17B", "8B", "4B", "4B", "2B", "2B", "2B",
        "2B", "1B", "1B", "1B", "1B", "536M", "268M", "268M", "134M", "134M",
        // Ranks 61-82
        "134M", "67M", "67M", "67M", "33M", "33M", "33M", "33M", "16M", "16M",
        "16M", "16M", "16M", "8M", "8M", "8M", "8M", "8M", "8M", "8M",
        "8M", "4M",
        // Ranks 83-95
        "4M", "4M", "4M", "4M", "4M", "4M", "4M", "4M", "4M", "4M",
        "4M", "4M", "2M",
        // Ranks 96-110
        "2M", "2M", "2M", "2M", "2M", "2M", "2M", "2M", "2M", "2M",
        "2M", "2M", "2M", "2M", "2M",
        // Ranks 111-130
        "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M",
        "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M",
        // Ranks 131-150
        "1M", "1M", "524K", "524K", "524K", "524K", "524K", "524K", "524K", "524K",
        "524K", "524K", "524K", "524K", "524K", "524K", "524K", "524K", "524K", "524K"
    ]

    // Extended Malaysia milestone brackets for rank calculation (ranks 151+)
    // Total Malaysia players: ~52,111
    static let malaysiaExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // K-tier brackets (ranks 151-888)
        ("262K", 151), ("131K", 200), ("65K", 275), ("32K", 676), ("16K", 836),
        // Raw number brackets (ranks 1000-52111)
        ("8192", 1000), ("4096", 1111), ("2048", 1234), ("1024", 1372), ("512", 1533),
        ("256", 2222), ("128", 3062), ("64", 4321), ("32", 5678), ("16", 8127),
        ("8", 11111), ("4", 18266), ("2", 26767), ("0", 36666)  // Score 0 = ranks 36666-52111
    ]

    // New Zealand leaderboard data - top 83 player milestones
    // Total New Zealand players: ~2,623
    static let newZealandPlayerMilestones: [String] = [
        // Ranks 1-30
        "3bz", "722br", "1bp", "1bl", "1bj", "16bf", "4bd", "117az", "1ax", "1av",
        "1as", "1aq", "1an", "661ak", "1ah", "1ae", "1aa", "485x", "1w", "3u",
        "6s", "12q", "12o", "5m", "11l", "22k", "1g", "2f", "9e", "75d",
        // Ranks 31-60
        "1d", "18c", "576b", "18b", "1b", "35a", "4a", "1a", "549B", "137B",
        "17B", "4B", "4B", "2B", "536M", "268M", "67M", "67M", "33M", "33M",
        "33M", "33M", "16M", "8M", "8M", "8M", "8M", "8M", "8M", "4M",
        // Ranks 61-83
        "4M", "4M", "4M", "4M", "4M", "4M", "4M", "4M", "2M", "2M",
        "2M", "2M", "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M",
        "1M", "1M", "1M"
    ]

    // Extended New Zealand milestone brackets for rank calculation (ranks 84+)
    // Total New Zealand players: ~2,623
    static let newZealandExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // K-tier brackets (ranks 84-159)
        ("524K", 84), ("262K", 95), ("131K", 108), ("65K", 123), ("32K", 140), ("16K", 159),
        // Raw number brackets (ranks 183-2623)
        ("8192", 183), ("4096", 219), ("2048", 262), ("1024", 307), ("512", 362),
        ("256", 433), ("128", 500), ("64", 585), ("32", 676), ("16", 833),
        ("8", 1076), ("4", 1400), ("2", 1739), ("0", 2111)  // Score 0 = ranks 2111-2623
    ]

    // Hungary leaderboard data - top 117 player milestones
    // Total Hungary players: ~111,111
    static let hungaryPlayerMilestones: [String] = [
        // Ranks 1-10
        "6bv", "1br", "627bl", "9bj", "64bd", "471az", "1ay", "1aw", "1au", "12as",
        // Ranks 11-20
        "1aq", "1ao", "1am", "5al", "1ak", "78ai", "2ah", "4ae", "1ad", "2ac",
        // Ranks 21-30
        "2ab", "260aa", "4aa", "127z", "15z", "3z", "7y", "3w", "115v", "14v",
        // Ranks 31-40
        "883t", "220t", "3t", "431s", "107s", "53s", "26s", "6s", "3r", "1r",
        // Ranks 41-50
        "51q", "803p", "12p", "3920o", "24o", "3o", "95n", "1n", "11m", "730l",
        // Ranks 51-60
        "182l", "22l", "5l", "356k", "22k", "1k", "174j", "10j", "2j", "1j",
        // Ranks 61-70
        "340i", "85i", "21i", "10i", "2i", "332h", "41h", "41h", "81g", "20g",
        // Ranks 71-80
        "5g", "5g", "2g", "316f", "79f", "39f", "9f", "2f", "1f", "309e",
        // Ranks 81-85 (interpolated)
        "77e", "19e", "5e", "1e", "5d",
        // Ranks 86-95
        "1c", "288b", "72b", "36b", "9b", "4b", "2b", "70a", "4a", "1a",
        // Ranks 96-109
        "549B", "274B", "274B", "137B", "137B", "137B", "68B", "34B", "17B", "8B",
        "4B", "2B", "1B", "1B",
        // Ranks 108-120
        "536M", "536M", "536M", "268M", "268M", "268M", "268M", "134M",
        "134M", "134M", "134M", "134M", "134M",
        // Ranks 121-130
        "67M", "67M", "67M", "67M", "67M", "33M", "33M", "33M", "33M", "33M",
        // Ranks 131-140
        "16M", "16M", "16M", "16M", "16M", "16M", "8M", "8M", "8M", "8M",
        // Ranks 141-150
        "4M", "4M", "4M", "4M", "2M", "2M", "2M", "2M", "2M", "2M"
    ]

    // Extended Hungary milestone brackets for rank calculation (ranks 151+)
    // Total Hungary players: ~111,111
    static let hungaryExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // M-tier brackets (ranks 151-180)
        ("1M", 151),
        // K-tier brackets (ranks 164-533)
        ("524K", 164), ("262K", 178), ("131K", 209), ("65K", 288), ("32K", 398), ("16K", 533),
        // Raw number brackets (ranks 856-111111)
        ("8192", 856), ("4096", 1234), ("2048", 1831), ("1024", 2500), ("512", 3199),
        ("256", 4445), ("128", 8332), ("64", 13312), ("32", 19327), ("16", 26338),
        ("8", 37332), ("4", 50000), ("2", 67676), ("0", 89898)  // Score 0 = ranks 89898-111111
    ]

    // Thailand leaderboard data - top 150 player milestones
    // Total Thailand players: ~5,444
    static let thailandPlayerMilestones: [String] = [
        // Ranks 1-10
        "54bz", "13bz", "1bz", "3by", "6bx", "198bv", "758bt", "1bs", "1bq", "657bn",
        // Ranks 11-20
        "74bj", "1bg", "1be", "1bc", "1ba", "3ax", "6au", "190aq", "1an", "1al",
        // Ranks 21-30
        "1aj", "2ah", "4ae", "124y", "31y", "1y", "55t", "766n", "2n", "1m",
        // Ranks 31-40
        "2l", "5k", "10j", "664h", "324g", "2g", "39f", "2f", "309e", "38e",
        // Ranks 41-50
        "9e", "1e", "75d", "2d", "35a", "274B", "68B", "34B", "8B", "2B",
        // Ranks 51-60
        "536M", "268M", "67M", "67M", "33M", "33M", "16M", "16M", "8M", "8M",
        // Ranks 61-70
        "8M", "4M", "4M", "4M", "2M", "2M", "2M", "2M", "1M", "1M",
        // Ranks 71-80
        "1M", "1M", "1M", "524K", "262K", "262K", "262K", "262K", "262K", "262K",
        // Ranks 81-95 (interpolated)
        "131K", "131K", "131K", "65K", "65K", "65K", "65K", "65K", "65K", "65K",
        "65K", "65K", "65K", "65K", "65K",
        // Ranks 96-122 (interpolated)
        "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K",
        "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K",
        "32K", "32K", "32K", "32K", "32K", "32K", "32K",
        // Ranks 123-150 (interpolated from 16K)
        "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K",
        "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K",
        "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K"
    ]

    // Extended Thailand milestone brackets for rank calculation (ranks 151+)
    // Total Thailand players: ~5,444
    static let thailandExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // Raw number brackets (ranks 177-5444)
        ("8192", 211), ("4096", 297), ("2048", 400), ("1024", 566), ("512", 811),
        ("256", 1086), ("128", 1297), ("64", 1552), ("32", 2111), ("16", 2792),
        ("8", 3333), ("4", 4000), ("2", 4567), ("0", 4933)  // Score 0 = ranks 4933-5444
    ]

    // UAE player milestones for top 150 players
    // Total UAE players: 19,889
    static let uaePlayerMilestones: [String] = [
        // Ranks 1-10
        "1bp", "4bl", "67bf", "1bd", "1ay", "426av", "204at", "780ar", "1aq", "21al",
        // Ranks 11-20
        "630ai", "2ah", "9af", "2ae", "4ad", "1ac", "8ab", "127z", "15z", "3z",
        // Ranks 21-30
        "1z", "497y", "248y", "124y", "62y", "1y", "7x", "118w", "7w", "115v",
        // Ranks 31-40
        "1v", "56u", "1u", "27t", "3t", "6q", "12o", "766n", "1n", "22l",
        // Ranks 41-50
        "5l", "1l", "178k", "5k", "2k", "1k", "696j", "696j", "174j", "87j",
        // Ranks 51-60
        "43j", "21j", "10j", "1j", "85i", "2i", "1i", "332h", "166h", "41h",
        // Ranks 61-70
        "2h", "5g", "316f", "39f", "2f", "4e", "9d", "9c", "4b", "1b",
        // Ranks 71-80
        "140a", "17a", "1a", "68B", "34B", "8B", "4B", "1B", "268M", "134M",
        // Ranks 81-90
        "67M", "67M", "33M", "33M", "16M", "16M", "8M", "8M", "8M", "4M",
        // Ranks 91-100
        "4M", "4M", "2M", "2M", "2M", "2M", "1M", "1M", "1M", "1M",
        // Ranks 101-110
        "1M", "524K", "524K", "524K", "524K", "524K", "524K", "524K", "262K", "262K",
        // Ranks 111-120
        "262K", "262K", "262K", "262K", "262K", "131K", "131K", "131K", "131K", "131K",
        // Ranks 121-130
        "131K", "131K", "131K", "131K", "131K", "65K", "65K", "65K", "65K", "65K",
        // Ranks 131-140
        "65K", "65K", "65K", "65K", "65K", "65K", "65K", "65K", "65K", "65K",
        // Ranks 141-150
        "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K"
    ]

    // Extended UAE milestone brackets for rank calculation (ranks 151+)
    // Total UAE players: 19,889
    static let uaeExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // K-tier brackets (ranks 164-199)
        ("16K", 164),
        // Raw number brackets (ranks 199-19889)
        ("8192", 199), ("4096", 251), ("2048", 322), ("1024", 676), ("512", 1067),
        ("256", 1666), ("128", 2500), ("64", 3333), ("32", 4444), ("16", 6767),
        ("8", 8998), ("4", 12345), ("2", 15432), ("0", 16767)  // Score 0 = ranks 16767-19889
    ]

    // Philippines leaderboard data - top 150 player milestones
    // Total Philippines players: 43,210
    static let philippinesPlayerMilestones: [String] = [
        // Ranks 1-10
        "1bz", "853by", "106by", "3by", "104bx", "6bx", "406bw", "6bw", "12bv", "1bv",
        // Ranks 11-20
        "2bt", "5br", "2bp", "657bn", "321bm", "4bl", "598bj", "37bj", "9bj", "2bj",
        // Ranks 21-30
        "570bh", "556bg", "1bg", "265be", "64bd", "506bc", "126bc", "15bc", "989bb", "3bb",
        // Ranks 31-40
        "943az", "3ay", "26av", "13av", "1as", "1aq", "5ap", "11ao", "11an", "1an",
        // Ranks 41-50
        "2am", "80aj", "78ai", "153ah", "601ag", "293af", "4ae", "8aa", "509z", "127z",
        // Ranks 51-60
        "15z", "3z", "1z", "3y", "7v", "3v", "3v", "1v", "3s", "50p",
        // Ranks 61-70
        "5n", "22l", "1l", "2k", "5j", "21i", "166h", "1h", "1g", "4e",
        // Ranks 71-80
        "9d", "1d", "147c", "36c", "18c", "4c", "576b", "144b", "18b", "9b",
        // Ranks 81-90
        "4b", "4b", "1b", "140a", "17a", "8a", "2a", "1a", "274B", "274B",
        // Ranks 91-100
        "137B", "68B", "68B", "34B", "34B", "17B", "17B", "17B", "8B", "4B",
        // Ranks 101-110
        "4B", "4B", "4B", "2B", "2B", "2B", "2B", "2B", "2B", "2B",
        // Ranks 111-120
        "2B", "2B", "2B", "2B", "2B", "2B", "2B", "2B", "1B", "1B",
        // Ranks 121-130
        "1B", "1B", "1B", "1B", "1B", "1B", "1B", "1B", "1B", "1B",
        // Ranks 131-140
        "1B", "1B", "1B", "536M", "536M", "536M", "536M", "536M", "536M", "536M",
        // Ranks 141-150
        "536M", "536M", "536M", "536M", "536M", "536M", "536M", "268M", "268M", "268M"
    ]

    // Extended Philippines milestone brackets for rank calculation (ranks 151+)
    // Total Philippines players: 43,210
    static let philippinesExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // M-tier brackets (ranks 151-183)
        ("134M", 151), ("67M", 152), ("33M", 154), ("16M", 157), ("8M", 160),
        ("4M", 165), ("2M", 171), ("1M", 177),
        // K-tier brackets (ranks 184-676)
        ("524K", 184), ("262K", 208), ("131K", 241), ("65K", 307), ("32K", 399), ("16K", 676),
        // Raw number brackets (ranks 1111-43210)
        ("8192", 1111), ("4096", 1676), ("2048", 2222), ("1024", 2667), ("512", 3676),
        ("256", 5222), ("128", 6767), ("64", 7144), ("32", 10000), ("16", 12345),
        ("8", 16767), ("4", 22210), ("2", 32109), ("0", 36767)  // Score 0 = ranks 36767-43210
    ]

    // Extended Netherlands milestone brackets for rank calculation (ranks 151+)
    // Total Netherlands players: ~46,767
    static let netherlandsExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // M-tier brackets (ranks 151-599)
        ("134M", 151), ("67M", 153), ("33M", 172), ("16M", 211), ("8M", 263),
        ("4M", 331), ("2M", 441), ("1M", 600),
        // K-tier brackets (ranks 873-3722)
        ("524K", 873), ("262K", 1123), ("131K", 1603), ("65K", 2222), ("32K", 2837), ("16K", 3722),
        // Raw number brackets (ranks 5111-46767)
        ("8192", 5111), ("4096", 6767), ("2048", 8276), ("1024", 10000), ("512", 11839),
        ("256", 14000), ("128", 16000), ("64", 18312), ("32", 22222), ("16", 24399),
        ("8", 28736), ("4", 32323), ("2", 36666), ("0", 41111)  // Score 0 = ranks 41111-46767
    ]

    // Shared function to get US player milestone data (ensures consistency between Global and US tabs)
    // Only returns top 150 for display, but extended data exists for rank calculations
    private static func usPlayerData(day: Int, milestones: [String]) -> [(index: Int, milestoneIdx: Int, exactMilestone: String)] {
        var players: [(index: Int, milestoneIdx: Int, exactMilestone: String)] = []
        for i in 0..<150 {  // Only show top 150 in leaderboard
            let exactMilestone = usPlayerMilestones[i]
            // Find the milestone index (for sorting purposes, use array position)
            let milestoneIdx = 150 - i  // Higher rank = higher milestone index for sorting
            players.append((i, milestoneIdx, exactMilestone))
        }
        return players
    }

    // Extended US milestone brackets for rank calculation (ranks 151+)
    // Total US players: 84,721
    static let usExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // a-tier brackets (ranks 151-256)
        ("4b", 151), ("2b", 153), ("1b", 154), ("562a", 155), ("281a", 158),
        ("140a", 164), ("70a", 168), ("35a", 171), ("17a", 182), ("8a", 196),
        ("4a", 211), ("2a", 232), ("1a", 256),
        // B-tier brackets (ranks 287-477)
        ("549B", 287), ("274B", 304), ("137B", 341), ("68B", 367), ("34B", 400),
        ("17B", 422), ("8B", 445), ("4B", 459), ("2B", 466), ("1B", 477),
        // M-tier brackets (ranks 519-1422)
        ("536M", 519), ("268M", 556), ("134M", 613), ("67M", 657), ("33M", 712),
        ("16M", 798), ("8M", 921), ("4M", 1055), ("2M", 1199), ("1M", 1422),
        // K-tier brackets (ranks 1788-7112)
        ("524K", 1788), ("262K", 2234), ("131K", 2876), ("65K", 4113), ("32K", 5422), ("16K", 7112),
        // Raw number brackets (ranks 11111-84721)
        ("8192", 11111), ("4096", 17775), ("2048", 22222), ("1024", 31234), ("512", 37665),
        ("256", 52260), ("128", 67676), ("64", 74456), ("32", 79657), ("16", 81246),
        ("8", 83256), ("4", 83765), ("2", 84065), ("0", 84323)  // Score 0 = new players
    ]

    // Extended UK milestone brackets for rank calculation (ranks 151+)
    // Total UK players: ~17,676
    static let ukExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // M-tier brackets (ranks 151-190)
        ("67M", 151), ("33M", 155), ("16M", 162), ("8M", 168), ("4M", 175), ("2M", 183), ("1M", 190),
        // K-tier brackets (ranks 200-263)
        ("524K", 200), ("262K", 214), ("131K", 221), ("65K", 237), ("32K", 253), ("16K", 263),
        // Raw number brackets (ranks 298-17676)
        ("8192", 298), ("4096", 388), ("2048", 518), ("1024", 688), ("512", 896),
        ("256", 1234), ("128", 2598), ("64", 6330), ("32", 9358), ("16", 12482),
        ("8", 14677), ("4", 16086), ("2", 16842), ("0", 17365)  // Score 0 = ranks 17365-17676
    ]

    // Extended Global milestone brackets for rank calculation (ranks 151+)
    private static let globalExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // ap-tier brackets (ranks 151-154)
        ("372ap", 151), ("46ap", 152), ("11ap", 153), ("2ap", 154),
        // ao-tier brackets (ranks 155-157)
        ("726ao", 155), ("22ao", 156), ("5ao", 157),
        // an-tier brackets (ranks 158-163)
        ("709an", 158), ("354an", 159), ("177an", 160), ("44an", 161), ("2an", 162), ("1an", 163),
        // am-tier brackets (ranks 164-168)
        ("693am", 164), ("173am", 165), ("86am", 166), ("1am", 168),
        // al-tier brackets (ranks 169-173)
        ("676al", 169), ("338al", 171), ("169al", 172), ("42al", 173),
        // ak-tier brackets (ranks 174-177)
        ("661ak", 174), ("165ak", 175), ("41ak", 176), ("2ak", 177),
        // aj-tier brackets (ranks 178-185)
        ("645aj", 178), ("322aj", 179), ("161aj", 181), ("80aj", 182), ("40aj", 183), ("20aj", 184), ("10aj", 185),
        // ai-tier brackets (ranks 186-194)
        ("630ai", 186), ("315ai", 187), ("157ai", 188), ("78ai", 189), ("39ai", 190), ("19ai", 192), ("9ai", 193), ("2ai", 194),
        // ah-tier brackets (ranks 195-198)
        ("615ah", 195), ("38ah", 196), ("4ah", 197), ("1ah", 198),
        // ag-tier brackets (ranks 199-207)
        ("601ag", 199), ("300ag", 201), ("150ag", 203), ("75ag", 204), ("37ag", 205), ("9ag", 206), ("2ag", 207),
        // af-tier brackets (ranks 208-217)
        ("587af", 208), ("293af", 209), ("146af", 210), ("36af", 211), ("4af", 212), ("2af", 214), ("1af", 216),
        // ae-tier brackets (ranks 218-221)
        ("573ae", 218), ("143ae", 219), ("71ae", 220), ("8ae", 221),
        // ad-tier brackets (ranks 222-225)
        ("559ad", 222), ("69ad", 223), ("17ad", 224), ("2ad", 225),
        // ac-tier brackets (ranks 226-229)
        ("546ac", 226), ("136ac", 227), ("68ac", 228), ("17ac", 229),
        // ab-tier brackets (ranks 230-236)
        ("533ab", 230), ("266ab", 231), ("133ab", 233), ("66ab", 234), ("33ab", 235), ("2ab", 236),
        // aa-tier brackets (ranks 237-244)
        ("521aa", 237), ("260aa", 238), ("130aa", 239), ("65aa", 240), ("32aa", 241), ("16aa", 242), ("8aa", 243), ("2aa", 244),
        // z-tier brackets (ranks 245-251)
        ("509z", 245), ("254z", 247), ("127z", 248), ("63z", 249), ("15z", 250), ("3z", 251),
        // y-tier brackets (ranks 252-256)
        ("994y", 252), ("497y", 253), ("248y", 254), ("31y", 255), ("3y", 256),
        // x-tier brackets (ranks 257-263)
        ("971x", 257), ("485x", 258), ("242x", 259), ("60x", 260), ("30x", 261), ("15x", 262), ("7x", 263),
        // w-tier brackets (ranks 264-269)
        ("948w", 264), ("474w", 265), ("237w", 266), ("59w", 267), ("14w", 268), ("7w", 269),
        // v-tier brackets (ranks 270-274)
        ("926v", 270), ("463v", 271), ("115v", 272), ("28v", 273), ("3v", 274),
        // u-tier brackets (ranks 275-281)
        ("904u", 275), ("452u", 276), ("226u", 277), ("113u", 278), ("28u", 279), ("7u", 280), ("1u", 281),
        // t-tier brackets (ranks 282-287)
        ("883t", 282), ("220t", 283), ("110t", 284), ("27t", 285), ("6t", 286), ("3t", 287),
        // s-tier brackets (ranks 288-295)
        ("862s", 288), ("431s", 289), ("215s", 290), ("107s", 291), ("53s", 292), ("26s", 293), ("13s", 294), ("3s", 295),
        // r-tier brackets (ranks 296-301)
        ("842r", 296), ("421r", 297), ("52r", 298), ("13r", 299), ("6r", 300), ("3r", 301),
        // q-tier brackets (ranks 302-309)
        ("822q", 302), ("411q", 303), ("205q", 304), ("102q", 305), ("51q", 306), ("12q", 307), ("6q", 308), ("3q", 309),
        // p-tier brackets (ranks 310-317)
        ("803p", 310), ("401p", 311), ("200p", 313), ("100p", 314), ("25p", 315), ("12p", 316), ("6p", 317),
        // o-tier brackets (ranks 318-323)
        ("784o", 318), ("392o", 319), ("98o", 320), ("49o", 321), ("12o", 322), ("3o", 323),
        // n-tier brackets (ranks 324-327)
        ("766n", 324), ("383n", 325), ("95n", 326), ("23n", 327),
        // m-tier brackets (ranks 328-334)
        ("748m", 328), ("374m", 329), ("93m", 330), ("23m", 331), ("11m", 332), ("2m", 333), ("1m", 334),
        // l-tier brackets (ranks 335-342)
        ("730l", 335), ("365l", 336), ("182l", 337), ("45l", 338), ("11l", 339), ("5l", 340), ("2l", 342),
        // k-tier brackets (ranks 343-348)
        ("713k", 343), ("356k", 344), ("178k", 345), ("44k", 346), ("11k", 347), ("5k", 348),
        // j-tier brackets (ranks 349-352)
        ("696j", 349), ("348j", 350), ("87j", 351), ("10j", 352),
        // i-tier brackets (ranks 353-358)
        ("680i", 353), ("340i", 354), ("170i", 355), ("85i", 356), ("42i", 357), ("10i", 358),
        // h-tier brackets (ranks 359-367)
        ("664h", 359), ("332h", 360), ("83h", 361), ("41h", 362), ("20h", 365), ("10h", 366), ("5h", 367),
        // g-tier brackets (ranks 368-376)
        ("649g", 368), ("324g", 369), ("81g", 371), ("40g", 372), ("20g", 373), ("10g", 374), ("5g", 375), ("1g", 376),
        // f-tier brackets (ranks 377-390)
        ("633f", 377), ("316f", 379), ("158f", 380), ("79f", 381), ("39f", 383), ("19f", 384), ("9f", 385), ("4f", 387), ("2f", 389), ("1f", 390),
        // e-tier brackets (ranks 391-399)
        ("309e", 391), ("154e", 392), ("77e", 393), ("38e", 394), ("19e", 395), ("9e", 396), ("4e", 398), ("1e", 399),
        // d-tier brackets (ranks 400-415)
        ("604d", 400), ("302d", 401), ("151d", 403), ("75d", 404), ("37d", 406), ("18d", 409), ("9d", 410), ("4d", 411), ("2d", 412), ("1d", 413),
        // c-tier brackets (ranks 416-430)
        ("590c", 416), ("295c", 417), ("147c", 418), ("73c", 419), ("36c", 420), ("18c", 421), ("9c", 423), ("4c", 425), ("2c", 427), ("1c", 429),
        // b-tier brackets (ranks 431-450)
        ("576b", 431), ("288b", 433), ("144b", 434), ("72b", 436), ("36b", 437), ("18b", 438), ("9b", 440), ("4b", 444), ("2b", 447), ("1b", 450),
        // a-tier brackets (ranks 456-687)
        ("562a", 456), ("281a", 463), ("140a", 472), ("70a", 479), ("35a", 484),
        ("17a", 497), ("8a", 512), ("4a", 529), ("2a", 554), ("1a", 687),
        // B-tier brackets (ranks 734-1633)
        ("549B", 734), ("274B", 774), ("137B", 810), ("68B", 945), ("34B", 1002),
        ("17B", 1134), ("8B", 1248), ("4B", 1404), ("2B", 1467), ("1B", 1633),
        // M-tier brackets (ranks 1743-11248)
        ("536M", 1743), ("268M", 1902), ("134M", 2123), ("67M", 2975), ("33M", 3784),
        ("16M", 4564), ("8M", 5223), ("4M", 6530), ("2M", 7399), ("1M", 11248),
        // K-tier brackets (ranks 17132-67412)
        ("524K", 17132), ("262K", 23582), ("131K", 32486), ("65K", 42421), ("32K", 54867), ("16K", 67412),
        // Raw number brackets (ranks 76767-877890+)
        ("8192", 76767), ("4096", 112486), ("2048", 157780), ("1024", 248624),
        ("512", 402486), ("256", 577398), ("128", 676767), ("64", 733337),
        ("32", 789012), ("16", 822228), ("8", 847790), ("4", 863074), ("2", 877890),
        ("0", 882349)  // Score 0 = new players (ranks 882349-885676)
    ]

    // Exact Global player milestones from screenshots (ranks 1-150)
    private static let globalPlayerMilestones: [String] = [
        // Ranks 1-15
        "436bz", "109bz", "13bz", "853by", "213by", "106by", "26by", "6by", "1by", "833bx", "208bx", "208bx", "104bx", "52bx", "3bx",
        // Ranks 16-30
        "1bx", "101bw", "25bw", "3bw", "1bw", "794bv", "99bv", "12bv", "1bv", "758bt", "189bt", "94bt", "23bt", "2bt", "370bs",
        // Ranks 31-45
        "722br", "180br", "45br", "11br", "5br", "5br", "1br", "2bq", "10bp", "168bo", "21bo", "5bo", "1bo", "657bn", "328bn",
        // Ranks 46-60
        "328bn", "164bn", "41bn", "642bm", "80bm", "20bm", "10bm", "78bl", "19bl", "4bl", "1bl", "76bk", "19bk", "4bk", "598bj",
        // Ranks 61-75
        "149bj", "149bj", "74bj", "18bj", "4bj", "1bj", "583bi", "291bi", "291bi", "145bi", "72bi", "9bi", "570bh", "285bh", "142bh",
        // Ranks 76-90
        "35bh", "556bg", "556bg", "278bg", "139bg", "69bg", "17bg", "543bf", "271bf", "67bf", "16bf", "1bf", "531be", "265be", "66be",
        // Ranks 91-105
        "33be", "8be", "1be", "518bd", "259bd", "129bd", "64bd", "32bd", "16bd", "16bd", "506bc", "253bc", "126bc", "63bc", "31bc",
        // Ranks 106-120
        "7bc", "989bb", "494bb", "247bb", "30bb", "966ba", "241ba", "15ba", "943az", "471az", "117az", "14az", "921ay", "115ay", "28ay",
        // Ranks 121-135
        "899ax", "224ax", "14ax", "878aw", "27aw", "13aw", "1aw", "214av", "107av", "1av", "837au", "209au", "26au", "6au", "818at",
        // Ranks 136-150
        "409at", "51at", "799as", "99as", "24as", "3as", "780ar", "97ar", "48ar", "24ar", "762aq", "381aq", "95aq", "47aq", "2aq"
    ]

    // Map of milestone -> US player index for matching names across leaderboards
    private static let milestoneToUSPlayerIndex: [String: Int] = {
        var map: [String: Int] = [:]
        for (index, milestone) in usPlayerMilestones.enumerated() {
            if map[milestone] == nil {
                map[milestone] = index
            }
        }
        return map
    }()

    // Helper function to get player name with daily variation
    private static func nameForPlayer(index: Int, names: [String], countrySeed: Int, day: Int) -> String {
        // Delegate to MockLeaderboardData.nameForPlayer for consistent 6-digit number handling
        return MockLeaderboardData.nameForPlayer(index: index, names: names, countrySeed: countrySeed, day: day)
    }

    // Helper function to get player avatar with daily variation
    private static func avatarForPlayer(index: Int, countrySeed: Int, day: Int) -> String {
        // Use seeded random to vary avatars daily
        let seed = index + countrySeed + day * 7
        let randomOffset = Int(MockLeaderboardData.seededRandom(seed: seed, index: 1) * 5)
        return MockLeaderboardData.avatarIDs[(index + randomOffset) % MockLeaderboardData.avatarIDs.count]
    }

    // Global leaderboard - combines all country leaderboards (US + UK + more to come)
    // Ranks are based on milestone - higher milestone = better rank
    private static func globalEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Combine players from all countries
        var playerData: [(originalIndex: Int, playerIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, country: String, platform: Platform, avatar: String, id: String)] = []

        // Add US players
        for i in 0..<min(150, usPlayerMilestones.count) {
            let baseMilestone = usPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.usNames, countrySeed: 0, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 0, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i, progressedMilestone, milestoneIdx, name, "US", platform, avatar, "us_\(i)"))
        }

        // Add UK players
        for i in 0..<min(150, ukPlayerMilestones.count) {
            let baseMilestone = ukPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.ukNames, countrySeed: 5000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 5000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 5000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 5000, progressedMilestone, milestoneIdx, name, "GB", platform, avatar, "uk_\(i)"))
        }

        // Add Canada players
        for i in 0..<min(150, canadaPlayerMilestones.count) {
            let baseMilestone = canadaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.canadaNames, countrySeed: 10000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 10000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 10000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 10000, progressedMilestone, milestoneIdx, name, "CA", platform, avatar, "ca_\(i)"))
        }

        // Add Australia players
        for i in 0..<min(150, australiaPlayerMilestones.count) {
            let baseMilestone = australiaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.australiaNames, countrySeed: 15000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 15000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 15000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 15000, progressedMilestone, milestoneIdx, name, "AU", platform, avatar, "au_\(i)"))
        }

        // Add Germany players
        for i in 0..<min(150, germanyPlayerMilestones.count) {
            let baseMilestone = germanyPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.germanyNames, countrySeed: 20000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 20000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 20000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 20000, progressedMilestone, milestoneIdx, name, "DE", platform, avatar, "de_\(i)"))
        }

        // Add France players
        for i in 0..<min(150, francePlayerMilestones.count) {
            let baseMilestone = francePlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.franceNames, countrySeed: 25000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 25000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 25000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 25000, progressedMilestone, milestoneIdx, name, "FR", platform, avatar, "fr_\(i)"))
        }

        // Add Japan players
        for i in 0..<min(150, japanPlayerMilestones.count) {
            let baseMilestone = japanPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.japanNames, countrySeed: 30000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 30000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 30000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 30000, progressedMilestone, milestoneIdx, name, "JP", platform, avatar, "jp_\(i)"))
        }

        // Add India players
        for i in 0..<min(150, indiaPlayerMilestones.count) {
            let baseMilestone = indiaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.indiaNames, countrySeed: 35000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 35000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 35000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 35000, progressedMilestone, milestoneIdx, name, "IN", platform, avatar, "in_\(i)"))
        }

        // Add Brazil players
        for i in 0..<min(150, brazilPlayerMilestones.count) {
            let baseMilestone = brazilPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.brazilNames, countrySeed: 40000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 40000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 40000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 40000, progressedMilestone, milestoneIdx, name, "BR", platform, avatar, "br_\(i)"))
        }

        // Add Mexico players
        for i in 0..<min(150, mexicoPlayerMilestones.count) {
            let baseMilestone = mexicoPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.mexicoNames, countrySeed: 45000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 45000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 45000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 45000, progressedMilestone, milestoneIdx, name, "MX", platform, avatar, "mx_\(i)"))
        }

        // Add Afghanistan players
        for i in 0..<min(150, afghanistanPlayerMilestones.count) {
            let baseMilestone = afghanistanPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.afghanistanNames, countrySeed: 50000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 50000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 50000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 50000, progressedMilestone, milestoneIdx, name, "AF", platform, avatar, "af_\(i)"))
        }

        // Add Albania players
        for i in 0..<min(150, albaniaPlayerMilestones.count) {
            let baseMilestone = albaniaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.albaniaNames, countrySeed: 55000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 55000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 55000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 55000, progressedMilestone, milestoneIdx, name, "AL", platform, avatar, "al_\(i)"))
        }

        // Add Algeria players
        for i in 0..<min(150, algeriaPlayerMilestones.count) {
            let baseMilestone = algeriaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.algeriaNames, countrySeed: 60000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 60000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 60000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 60000, progressedMilestone, milestoneIdx, name, "DZ", platform, avatar, "dz_\(i)"))
        }

        // Add China players
        for i in 0..<min(150, chinaPlayerMilestones.count) {
            let baseMilestone = chinaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.chinaNames, countrySeed: 65000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 65000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 65000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 65000, progressedMilestone, milestoneIdx, name, "CN", platform, avatar, "cn_\(i)"))
        }

        // Add South Korea players
        for i in 0..<min(150, southKoreaPlayerMilestones.count) {
            let baseMilestone = southKoreaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.southKoreaNames, countrySeed: 70000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 70000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 70000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 70000, progressedMilestone, milestoneIdx, name, "KR", platform, avatar, "kr_\(i)"))
        }

        // Add Italy players
        for i in 0..<min(150, italyPlayerMilestones.count) {
            let baseMilestone = italyPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.italyNames, countrySeed: 75000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 75000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 75000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 75000, progressedMilestone, milestoneIdx, name, "IT", platform, avatar, "it_\(i)"))
        }

        // Add Spain players
        for i in 0..<min(150, spainPlayerMilestones.count) {
            let baseMilestone = spainPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.spainNames, countrySeed: 80000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 80000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 80000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 80000, progressedMilestone, milestoneIdx, name, "ES", platform, avatar, "es_\(i)"))
        }

        // Add Netherlands players
        for i in 0..<min(150, netherlandsPlayerMilestones.count) {
            let baseMilestone = netherlandsPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.netherlandsNames, countrySeed: 85000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 85000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 85000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 85000, progressedMilestone, milestoneIdx, name, "NL", platform, avatar, "nl_\(i)"))
        }

        // Add Switzerland players
        for i in 0..<min(150, switzerlandPlayerMilestones.count) {
            let baseMilestone = switzerlandPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.switzerlandNames, countrySeed: 90000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 90000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 90000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 90000, progressedMilestone, milestoneIdx, name, "CH", platform, avatar, "ch_\(i)"))
        }

        // Add Norway players
        for i in 0..<min(150, norwayPlayerMilestones.count) {
            let baseMilestone = norwayPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.norwayNames, countrySeed: 95000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 95000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 95000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 95000, progressedMilestone, milestoneIdx, name, "NO", platform, avatar, "no_\(i)"))
        }

        // Add Denmark players
        for i in 0..<min(150, denmarkPlayerMilestones.count) {
            let baseMilestone = denmarkPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.denmarkNames, countrySeed: 100000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 100000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 100000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 100000, progressedMilestone, milestoneIdx, name, "DK", platform, avatar, "dk_\(i)"))
        }

        // Add Finland players
        for i in 0..<min(150, finlandPlayerMilestones.count) {
            let baseMilestone = finlandPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.finlandNames, countrySeed: 105000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 105000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 105000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 105000, progressedMilestone, milestoneIdx, name, "FI", platform, avatar, "fi_\(i)"))
        }

        // Add Poland players
        for i in 0..<min(150, polandPlayerMilestones.count) {
            let baseMilestone = polandPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.polandNames, countrySeed: 110000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 110000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 110000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 110000, progressedMilestone, milestoneIdx, name, "PL", platform, avatar, "pl_\(i)"))
        }

        // Add Belgium players
        for i in 0..<min(150, belgiumPlayerMilestones.count) {
            let baseMilestone = belgiumPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.belgiumNames, countrySeed: 115000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 115000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 115000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 115000, progressedMilestone, milestoneIdx, name, "BE", platform, avatar, "be_\(i)"))
        }

        // Add Sweden players
        for i in 0..<min(150, swedenPlayerMilestones.count) {
            let baseMilestone = swedenPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.swedenNames, countrySeed: 120000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 120000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 120000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 120000, progressedMilestone, milestoneIdx, name, "SE", platform, avatar, "se_\(i)"))
        }

        // Add Austria players
        for i in 0..<min(150, austriaPlayerMilestones.count) {
            let baseMilestone = austriaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.austriaNames, countrySeed: 125000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 125000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 125000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 125000, progressedMilestone, milestoneIdx, name, "AT", platform, avatar, "at_\(i)"))
        }

        // Add Ireland players
        for i in 0..<min(150, irelandPlayerMilestones.count) {
            let baseMilestone = irelandPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.irelandNames, countrySeed: 130000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 130000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 130000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 130000, progressedMilestone, milestoneIdx, name, "IE", platform, avatar, "ie_\(i)"))
        }

        // Add Portugal players
        for i in 0..<min(150, portugalPlayerMilestones.count) {
            let baseMilestone = portugalPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.portugalNames, countrySeed: 135000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 135000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 135000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 135000, progressedMilestone, milestoneIdx, name, "PT", platform, avatar, "pt_\(i)"))
        }

        // Add Greece players
        for i in 0..<min(150, greecePlayerMilestones.count) {
            let baseMilestone = greecePlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.greeceNames, countrySeed: 140000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 140000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 140000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 140000, progressedMilestone, milestoneIdx, name, "GR", platform, avatar, "gr_\(i)"))
        }

        // Add Czechia players
        for i in 0..<min(150, czechiaPlayerMilestones.count) {
            let baseMilestone = czechiaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.czechiaNames, countrySeed: 145000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 145000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 145000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 145000, progressedMilestone, milestoneIdx, name, "CZ", platform, avatar, "cz_\(i)"))
        }

        // Add Romania players
        for i in 0..<min(150, romaniaPlayerMilestones.count) {
            let baseMilestone = romaniaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.romaniaNames, countrySeed: 150000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 150000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 150000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 150000, progressedMilestone, milestoneIdx, name, "RO", platform, avatar, "ro_\(i)"))
        }

        // Add Malaysia players
        for i in 0..<min(150, malaysiaPlayerMilestones.count) {
            let baseMilestone = malaysiaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.malaysiaNames, countrySeed: 155000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 155000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 155000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 155000, progressedMilestone, milestoneIdx, name, "MY", platform, avatar, "my_\(i)"))
        }

        // Add New Zealand players
        for i in 0..<min(150, newZealandPlayerMilestones.count) {
            let baseMilestone = newZealandPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.newZealandNames, countrySeed: 160000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 160000, day: day)

            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 160000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 160000, progressedMilestone, milestoneIdx, name, "NZ", platform, avatar, "nz_\(i)"))
        }

        // Add Hungary players
        for i in 0..<min(150, hungaryPlayerMilestones.count) {
            let baseMilestone = hungaryPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.hungaryNames, countrySeed: 165000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 165000, day: day)

            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 165000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, i + 165000, progressedMilestone, milestoneIdx, name, "HU", platform, avatar, "hu_\(i)"))
        }

        // Add the user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userCountry = UserLeaderboardData.currentCountry
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        // Use compareMilestones for better index if standard index returns 0
        var effectiveUserIdx = userMilestoneIdx
        if userMilestoneIdx == 0 {
            // Calculate effective index based on milestone parsing
            // Find the first milestone in allMilestones that user beats
            var foundIdx = 0
            for (idx, m) in MockLeaderboardData.allMilestones.enumerated() {
                if MockLeaderboardData.compareMilestones(userMilestone, m) >= 0 {
                    foundIdx = idx
                }
            }
            effectiveUserIdx = foundIdx
        }
        playerData.append((-1, 999999, userMilestone, effectiveUserIdx, UserLeaderboardData.playerName, userCountry, .ios, UserLeaderboardData.avatarID, "me"))


        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            // Equal milestones - user always comes first
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            // Equal milestones - lower original index = reached first = better rank
            return $0.originalIndex < $1.originalIndex
        }

        // Calculate total players for rank calculation
        let totalUSPlayers = MockLeaderboardData.totalPlayers(on: day, isUS: true)
        let totalUKPlayers = 17_676
        let totalCanadaPlayers = 12_847
        let totalAustraliaPlayers = 63_213
        let totalGermanyPlayers = 76_767
        let totalFrancePlayers = 127_676
        let totalJapanPlayers = 894
        let totalIndiaPlayers = 1_488
        let totalBrazilPlayers = 10_000
        let totalMexicoPlayers = 7_229
        let totalAfghanistanPlayers = 11_111
        let totalAlbaniaPlayers = 11_222
        let totalAlgeriaPlayers = 3_333
        let totalChinaPlayers = 8_192
        let totalSouthKoreaPlayers = 3_123
        let totalItalyPlayers = 13_856
        let totalSpainPlayers = 14_399
        let totalNetherlandsPlayers = 46_767
        let totalSwitzerlandPlayers = 20_000
        let totalNorwayPlayers = 34_924
        let totalDenmarkPlayers = 90_123
        let totalFinlandPlayers = 87_654
        let totalPolandPlayers = 67_108
        let totalBelgiumPlayers = 8_989
        let totalSwedenPlayers = 6_288
        let totalAustriaPlayers = 7_543
        let totalIrelandPlayers = 34_567
        let totalPortugalPlayers = 98_989
        let totalGreecePlayers = 41_414
        let totalCzechiaPlayers = 61_616
        let totalRomaniaPlayers = 5_966
        let totalMalaysiaPlayers = 52_111
        let totalNewZealandPlayers = 2_623
        let totalHungaryPlayers = 111_111
        let totalPlayers = totalUSPlayers + totalUKPlayers + totalCanadaPlayers + totalAustraliaPlayers + totalGermanyPlayers + totalFrancePlayers + totalJapanPlayers + totalIndiaPlayers + totalBrazilPlayers + totalMexicoPlayers + totalAfghanistanPlayers + totalAlbaniaPlayers + totalAlgeriaPlayers + totalChinaPlayers + totalSouthKoreaPlayers + totalItalyPlayers + totalSpainPlayers + totalNetherlandsPlayers + totalSwitzerlandPlayers + totalNorwayPlayers + totalDenmarkPlayers + totalFinlandPlayers + totalPolandPlayers + totalBelgiumPlayers + totalSwedenPlayers + totalAustriaPlayers + totalIrelandPlayers + totalPortugalPlayers + totalGreecePlayers + totalCzechiaPlayers + totalRomaniaPlayers + totalMalaysiaPlayers + totalNewZealandPlayers + totalHungaryPlayers

        // Build entries with ranks based on sorted order (top 150 only)
        // User is already in playerData and sorted, so they'll appear at correct position
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.playerIndex, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: player.country,
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            // Calculate user rank using same bracket system as profile
            let userRank = MockLeaderboardData.calculateGlobalRank(milestone: userMilestone, totalPlayers: totalPlayers)

            // Use global names and a global seed for extended bracket entries
            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: userRank,
                userMilestone: userMilestone,
                countryCode: userCountry,
                countrySeed: 888888,  // Global seed
                names: MockLeaderboardData.globalNames,
                day: day,
                totalPlayers: totalPlayers,
                extendedBrackets: usExtendedRankBrackets  // Use US brackets as reference for global
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    // Country (US) leaderboard - shows only US players with exact milestones from screenshots
    // Ranks are based on milestone - higher milestone = better rank
    private static func countryEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // First, build player data with milestones (including user)
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<150 {  // Only show top 150 in leaderboard
            let baseMilestone = usPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.usNames, countrySeed: 0, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            // Use seeded avatar selection for variety (different from names)
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 0, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "us_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        var effectiveUserIdx = userMilestoneIdx
        if userMilestoneIdx == 0 {
            var foundIdx = 0
            for (idx, m) in MockLeaderboardData.allMilestones.enumerated() {
                if MockLeaderboardData.compareMilestones(userMilestone, m) >= 0 {
                    foundIdx = idx
                }
            }
            effectiveUserIdx = foundIdx
        }
        playerData.append((-1, userMilestone, effectiveUserIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        // Build entries with ranks based on sorted order
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalUSPlayers = MockLeaderboardData.totalPlayers(on: day, isUS: true)

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "US",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var usRank = totalUSPlayers

            for bracket in usExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   effectiveUserIdx >= bracketIndex {
                    usRank = bracket.startRank
                    break
                }
            }

            // Add extended bracket entries with surrounding players
            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: usRank,
                userMilestone: userMilestone,
                countryCode: "US",
                countrySeed: 0,
                names: MockLeaderboardData.usNames,
                day: day,
                totalPlayers: totalUSPlayers,
                extendedBrackets: usExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    // UK leaderboard - shows only UK players with milestones
    // Ranks are based on milestone - higher milestone = better rank
    private static func ukEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones - include user for proper sorting
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, ukPlayerMilestones.count) {
            let baseMilestone = ukPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.ukNames, countrySeed: 5000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 5000, day: day)

            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "uk_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        let totalUKPlayers = 17_676

        // Build entries with ranks based on sorted order (top 150 only)
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry { userInTop150 = true }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 5000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "GB",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var ukRank = totalUKPlayers

            for bracket in ukExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    ukRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: ukRank,
                userMilestone: userMilestone,
                countryCode: "GB",
                countrySeed: 5000,
                names: MockLeaderboardData.ukNames,
                day: day,
                totalPlayers: totalUKPlayers,
                extendedBrackets: ukExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    // Canada leaderboard - shows top 150 Canadian players
    private static func canadaEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones - include user for proper sorting
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, canadaPlayerMilestones.count) {
            let baseMilestone = canadaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.canadaNames, countrySeed: 10000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 10000, day: day)

            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "ca_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        let totalCanadaPlayers = 12_847

        // Build entries with ranks based on sorted order (top 150 only)
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry { userInTop150 = true }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 10000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "CA",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var canadaRank = totalCanadaPlayers

            for bracket in canadaExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    canadaRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: canadaRank,
                userMilestone: userMilestone,
                countryCode: "CA",
                countrySeed: 10000,
                names: MockLeaderboardData.canadaNames,
                day: day,
                totalPlayers: totalCanadaPlayers,
                extendedBrackets: canadaExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    // Australia leaderboard - shows top 150 Australian players
    private static func australiaEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones - include user for proper sorting
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, australiaPlayerMilestones.count) {
            let baseMilestone = australiaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.australiaNames, countrySeed: 15000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 15000, day: day)

            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "au_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        let totalAustraliaPlayers = 63_213

        // Build entries with ranks based on sorted order (top 150 only)
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry { userInTop150 = true }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 15000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "AU",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var australiaRank = totalAustraliaPlayers

            for bracket in australiaExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    australiaRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: australiaRank,
                userMilestone: userMilestone,
                countryCode: "AU",
                countrySeed: 15000,
                names: MockLeaderboardData.australiaNames,
                day: day,
                totalPlayers: totalAustraliaPlayers,
                extendedBrackets: australiaExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    // Germany leaderboard - shows only German players with exact milestones
    private static func germanyEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, germanyPlayerMilestones.count) {
            let baseMilestone = germanyPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.germanyNames, countrySeed: 20000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 20000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "de_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx { return $0.milestoneIdx > $1.milestoneIdx }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        let totalGermanyPlayers = 76_767
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry { userInTop150 = true }
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 20000, day: day)
            entries.append(LeaderboardEntry(id: player.id, rank: rank + 1, name: player.name, score: score, countryCode: "DE", platform: player.platform, isMe: isUserEntry, avatarURL: player.avatar, highestTile: player.progressedMilestone))
        }

        if !userInTop150 {
            let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
            var germanyRank = totalGermanyPlayers
            for bracket in germanyExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone), userMilestoneIdx >= bracketIndex {
                    germanyRank = bracket.startRank
                    break
                }
            }
            entries.append(LeaderboardEntry(id: "me", rank: germanyRank, name: UserLeaderboardData.playerName, score: userScore, countryCode: "DE", platform: .ios, isMe: true, avatarURL: UserLeaderboardData.avatarID, highestTile: userMilestone))
        }

        return entries
    }

    // France leaderboard
    private static func franceEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, francePlayerMilestones.count) {
            let baseMilestone = francePlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.franceNames, countrySeed: 25000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 25000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 25000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "fr_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx { return $0.milestoneIdx > $1.milestoneIdx }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        let totalFrancePlayers = 127_676
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry { userInTop150 = true }
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 25000, day: day)
            entries.append(LeaderboardEntry(id: player.id, rank: rank + 1, name: player.name, score: score, countryCode: "FR", platform: player.platform, isMe: isUserEntry, avatarURL: player.avatar, highestTile: player.progressedMilestone))
        }

        if !userInTop150 {
            let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
            var franceRank = totalFrancePlayers
            for bracket in franceExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone), userMilestoneIdx >= bracketIndex {
                    franceRank = bracket.startRank
                    break
                }
            }
            entries.append(LeaderboardEntry(id: "me", rank: franceRank, name: UserLeaderboardData.playerName, score: userScore, countryCode: "FR", platform: .ios, isMe: true, avatarURL: UserLeaderboardData.avatarID, highestTile: userMilestone))
        }

        return entries
    }

    // Japan leaderboard - shows only Japanese players with exact milestones
    private static func japanEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones - include user for proper sorting
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, japanPlayerMilestones.count) {
            let baseMilestone = japanPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.japanNames, countrySeed: 30000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 30000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 30000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)

            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "jp_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            // Equal milestones - user always comes first
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        let totalJapanPlayers = 894  // Japan player count

        // Build entries with ranks based on sorted order (top 150 only)
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 30000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "JP",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var japanRank = totalJapanPlayers

            for bracket in japanExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    japanRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: japanRank,
                userMilestone: userMilestone,
                countryCode: "JP",
                countrySeed: 30000,
                names: MockLeaderboardData.japanNames,
                day: day,
                totalPlayers: totalJapanPlayers,
                extendedBrackets: japanExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    // India leaderboard - shows only Indian players with exact milestones
    private static func indiaEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, indiaPlayerMilestones.count) {
            let baseMilestone = indiaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.indiaNames, countrySeed: 35000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 35000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "in_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx { return $0.milestoneIdx > $1.milestoneIdx }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        let totalIndiaPlayers = 1_488
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry { userInTop150 = true }
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 35000, day: day)
            entries.append(LeaderboardEntry(id: player.id, rank: rank + 1, name: player.name, score: score, countryCode: "IN", platform: player.platform, isMe: isUserEntry, avatarURL: player.avatar, highestTile: player.progressedMilestone))
        }

        if !userInTop150 {
            let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
            var indiaRank = totalIndiaPlayers
            for bracket in indiaExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone), userMilestoneIdx >= bracketIndex {
                    indiaRank = bracket.startRank
                    break
                }
            }
            entries.append(LeaderboardEntry(id: "me", rank: indiaRank, name: UserLeaderboardData.playerName, score: userScore, countryCode: "IN", platform: .ios, isMe: true, avatarURL: UserLeaderboardData.avatarID, highestTile: userMilestone))
        }

        return entries
    }

    // Brazil leaderboard
    private static func brazilEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, brazilPlayerMilestones.count) {
            let baseMilestone = brazilPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.brazilNames, countrySeed: 40000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 40000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "br_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx { return $0.milestoneIdx > $1.milestoneIdx }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        let totalBrazilPlayers = 10_000
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry { userInTop150 = true }
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 40000, day: day)
            entries.append(LeaderboardEntry(id: player.id, rank: rank + 1, name: player.name, score: score, countryCode: "BR", platform: player.platform, isMe: isUserEntry, avatarURL: player.avatar, highestTile: player.progressedMilestone))
        }

        if !userInTop150 {
            let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
            var brazilRank = totalBrazilPlayers
            for bracket in brazilExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone), userMilestoneIdx >= bracketIndex {
                    brazilRank = bracket.startRank
                    break
                }
            }
            entries.append(LeaderboardEntry(id: "me", rank: brazilRank, name: UserLeaderboardData.playerName, score: userScore, countryCode: "BR", platform: .ios, isMe: true, avatarURL: UserLeaderboardData.avatarID, highestTile: userMilestone))
        }

        return entries
    }

    // Mexico leaderboard
    private static func mexicoEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, mexicoPlayerMilestones.count) {
            let baseMilestone = mexicoPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.mexicoNames, countrySeed: 45000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 45000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "mx_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx { return $0.milestoneIdx > $1.milestoneIdx }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        let totalMexicoPlayers = 7_229
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry { userInTop150 = true }
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 45000, day: day)
            entries.append(LeaderboardEntry(id: player.id, rank: rank + 1, name: player.name, score: score, countryCode: "MX", platform: player.platform, isMe: isUserEntry, avatarURL: player.avatar, highestTile: player.progressedMilestone))
        }

        if !userInTop150 {
            let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
            var mexicoRank = totalMexicoPlayers
            for bracket in mexicoExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone), userMilestoneIdx >= bracketIndex {
                    mexicoRank = bracket.startRank
                    break
                }
            }
            entries.append(LeaderboardEntry(id: "me", rank: mexicoRank, name: UserLeaderboardData.playerName, score: userScore, countryCode: "MX", platform: .ios, isMe: true, avatarURL: UserLeaderboardData.avatarID, highestTile: userMilestone))
        }

        return entries
    }

    // Afghanistan leaderboard
    private static func afghanistanEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, afghanistanPlayerMilestones.count) {
            let baseMilestone = afghanistanPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.afghanistanNames, countrySeed: 50000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 50000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "af_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx { return $0.milestoneIdx > $1.milestoneIdx }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        let totalAfghanistanPlayers = 11_111
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry { userInTop150 = true }
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 50000, day: day)
            entries.append(LeaderboardEntry(id: player.id, rank: rank + 1, name: player.name, score: score, countryCode: "AF", platform: player.platform, isMe: isUserEntry, avatarURL: player.avatar, highestTile: player.progressedMilestone))
        }

        if !userInTop150 {
            let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
            var afghanistanRank = totalAfghanistanPlayers
            for bracket in afghanistanExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone), userMilestoneIdx >= bracketIndex {
                    afghanistanRank = bracket.startRank
                    break
                }
            }
            entries.append(LeaderboardEntry(id: "me", rank: afghanistanRank, name: UserLeaderboardData.playerName, score: userScore, countryCode: "AF", platform: .ios, isMe: true, avatarURL: UserLeaderboardData.avatarID, highestTile: userMilestone))
        }

        return entries
    }

    // Albania leaderboard - shows only Albanian players with exact milestones
    // Ranks are based on milestone - higher milestone = better rank
    private static func albaniaEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, albaniaPlayerMilestones.count) {
            let baseMilestone = albaniaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.albaniaNames, countrySeed: 55000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 55000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "al_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx { return $0.milestoneIdx > $1.milestoneIdx }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        let totalAlbaniaPlayers = 11_222
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry { userInTop150 = true }
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 55000, day: day)
            entries.append(LeaderboardEntry(id: player.id, rank: rank + 1, name: player.name, score: score, countryCode: "AL", platform: player.platform, isMe: isUserEntry, avatarURL: player.avatar, highestTile: player.progressedMilestone))
        }

        if !userInTop150 {
            let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
            var albaniaRank = totalAlbaniaPlayers
            for bracket in albaniaExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone), userMilestoneIdx >= bracketIndex {
                    albaniaRank = bracket.startRank
                    break
                }
            }
            entries.append(LeaderboardEntry(id: "me", rank: albaniaRank, name: UserLeaderboardData.playerName, score: userScore, countryCode: "AL", platform: .ios, isMe: true, avatarURL: UserLeaderboardData.avatarID, highestTile: userMilestone))
        }

        return entries
    }

    // Algeria leaderboard - shows only Algerian players with exact milestones
    // Ranks are based on milestone - higher milestone = better rank
    private static func algeriaEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, algeriaPlayerMilestones.count) {
            let baseMilestone = algeriaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.algeriaNames, countrySeed: 60000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 60000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "dz_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx { return $0.milestoneIdx > $1.milestoneIdx }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        let totalAlgeriaPlayers = 3_333
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry { userInTop150 = true }
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 60000, day: day)
            entries.append(LeaderboardEntry(id: player.id, rank: rank + 1, name: player.name, score: score, countryCode: "DZ", platform: player.platform, isMe: isUserEntry, avatarURL: player.avatar, highestTile: player.progressedMilestone))
        }

        if !userInTop150 {
            let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
            var algeriaRank = totalAlgeriaPlayers
            for bracket in algeriaExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone), userMilestoneIdx >= bracketIndex {
                    algeriaRank = bracket.startRank
                    break
                }
            }
            entries.append(LeaderboardEntry(id: "me", rank: algeriaRank, name: UserLeaderboardData.playerName, score: userScore, countryCode: "DZ", platform: .ios, isMe: true, avatarURL: UserLeaderboardData.avatarID, highestTile: userMilestone))
        }

        return entries
    }

    private static func chinaEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, chinaPlayerMilestones.count) {
            let baseMilestone = chinaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.chinaNames, countrySeed: 65000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 65000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "cn_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx { return $0.milestoneIdx > $1.milestoneIdx }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        let totalChinaPlayers = 8_192
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry { userInTop150 = true }
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 65000, day: day)
            entries.append(LeaderboardEntry(id: player.id, rank: rank + 1, name: player.name, score: score, countryCode: "CN", platform: player.platform, isMe: isUserEntry, avatarURL: player.avatar, highestTile: player.progressedMilestone))
        }

        if !userInTop150 {
            let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
            var chinaRank = totalChinaPlayers
            for bracket in chinaExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone), userMilestoneIdx >= bracketIndex {
                    chinaRank = bracket.startRank
                    break
                }
            }
            entries.append(LeaderboardEntry(id: "me", rank: chinaRank, name: UserLeaderboardData.playerName, score: userScore, countryCode: "CN", platform: .ios, isMe: true, avatarURL: UserLeaderboardData.avatarID, highestTile: userMilestone))
        }

        return entries
    }

    private static func southKoreaEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, southKoreaPlayerMilestones.count) {
            let baseMilestone = southKoreaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.southKoreaNames, countrySeed: 70000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 70000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "kr_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx { return $0.milestoneIdx > $1.milestoneIdx }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        let totalSouthKoreaPlayers = 3_123
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry { userInTop150 = true }
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 70000, day: day)
            entries.append(LeaderboardEntry(id: player.id, rank: rank + 1, name: player.name, score: score, countryCode: "KR", platform: player.platform, isMe: isUserEntry, avatarURL: player.avatar, highestTile: player.progressedMilestone))
        }

        if !userInTop150 {
            let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
            var southKoreaRank = totalSouthKoreaPlayers
            for bracket in southKoreaExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone), userMilestoneIdx >= bracketIndex {
                    southKoreaRank = bracket.startRank
                    break
                }
            }
            entries.append(LeaderboardEntry(id: "me", rank: southKoreaRank, name: UserLeaderboardData.playerName, score: userScore, countryCode: "KR", platform: .ios, isMe: true, avatarURL: UserLeaderboardData.avatarID, highestTile: userMilestone))
        }

        return entries
    }

    private static func italyEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // First, build player data with milestones (including user)
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, italyPlayerMilestones.count) {
            let baseMilestone = italyPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.italyNames, countrySeed: 75000, day: day)
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 75000, day: day)

            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "it_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        // Build entries with ranks based on sorted order
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalItalyPlayers = 13_856

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 80000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "IT",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var italyRank = totalItalyPlayers

            for bracket in italyExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    italyRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: italyRank,
                userMilestone: userMilestone,
                countryCode: "IT",
                countrySeed: 75000,
                names: MockLeaderboardData.italyNames,
                day: day,
                totalPlayers: totalItalyPlayers,
                extendedBrackets: italyExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func spainEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones (including user)
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, spainPlayerMilestones.count) {
            let baseMilestone = spainPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.spainNames, countrySeed: 80000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 80000, day: day)

            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "es_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        // Build entries with ranks
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalSpainPlayers = 14_399

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 90000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "ES",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var spainRank = totalSpainPlayers

            for bracket in spainExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    spainRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: spainRank,
                userMilestone: userMilestone,
                countryCode: "ES",
                countrySeed: 80000,
                names: MockLeaderboardData.spainNames,
                day: day,
                totalPlayers: totalSpainPlayers,
                extendedBrackets: spainExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func switzerlandEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones (including user)
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, switzerlandPlayerMilestones.count) {
            let baseMilestone = switzerlandPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.switzerlandNames, countrySeed: 90000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 90000, day: day)

            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "ch_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        // Build entries with ranks
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalSwitzerlandPlayers = 20_000

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 110000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "CH",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var switzerlandRank = totalSwitzerlandPlayers

            for bracket in switzerlandExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    switzerlandRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: switzerlandRank,
                userMilestone: userMilestone,
                countryCode: "CH",
                countrySeed: 90000,
                names: MockLeaderboardData.switzerlandNames,
                day: day,
                totalPlayers: totalSwitzerlandPlayers,
                extendedBrackets: switzerlandExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func netherlandsEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones (including user)
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, netherlandsPlayerMilestones.count) {
            let baseMilestone = netherlandsPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.netherlandsNames, countrySeed: 85000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 85000, day: day)

            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "nl_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        // Build entries with ranks
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalNetherlandsPlayers = 46_767

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 100000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "NL",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var netherlandsRank = totalNetherlandsPlayers

            for bracket in netherlandsExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    netherlandsRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: netherlandsRank,
                userMilestone: userMilestone,
                countryCode: "NL",
                countrySeed: 85000,
                names: MockLeaderboardData.netherlandsNames,
                day: day,
                totalPlayers: totalNetherlandsPlayers,
                extendedBrackets: netherlandsExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func norwayEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones (including user)
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, norwayPlayerMilestones.count) {
            let baseMilestone = norwayPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.norwayNames, countrySeed: 95000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 95000, day: day)

            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "no_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        // Build entries with ranks
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalNorwayPlayers = 34_924

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 120000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "NO",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var norwayRank = totalNorwayPlayers

            for bracket in norwayExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    norwayRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: norwayRank,
                userMilestone: userMilestone,
                countryCode: "NO",
                countrySeed: 95000,
                names: MockLeaderboardData.norwayNames,
                day: day,
                totalPlayers: totalNorwayPlayers,
                extendedBrackets: norwayExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func denmarkEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones (including user)
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, denmarkPlayerMilestones.count) {
            let baseMilestone = denmarkPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.denmarkNames, countrySeed: 100000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 100000, day: day)

            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)
            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar, "dk_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        // Build entries with ranks
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalDenmarkPlayers = 90_123

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 130000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "DK",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var denmarkRank = totalDenmarkPlayers

            for bracket in denmarkExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    denmarkRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: denmarkRank,
                userMilestone: userMilestone,
                countryCode: "DK",
                countrySeed: 100000,
                names: MockLeaderboardData.denmarkNames,
                day: day,
                totalPlayers: totalDenmarkPlayers,
                extendedBrackets: denmarkExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func finlandEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones (including user)
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, finlandPlayerMilestones.count) {
            let baseMilestone = finlandPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.finlandNames, countrySeed: 105000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 105000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 105000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "fi_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        // Build entries with ranks
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalFinlandPlayers = 87_654

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 135000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "FI",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var finlandRank = totalFinlandPlayers

            for bracket in finlandExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    finlandRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: finlandRank,
                userMilestone: userMilestone,
                countryCode: "FI",
                countrySeed: 105000,
                names: MockLeaderboardData.finlandNames,
                day: day,
                totalPlayers: totalFinlandPlayers,
                extendedBrackets: finlandExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func polandEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones (including user)
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, polandPlayerMilestones.count) {
            let baseMilestone = polandPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.polandNames, countrySeed: 110000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 110000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 110000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "pl_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        // Build entries with ranks
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalPolandPlayers = 67_108

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 140000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "PL",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var polandRank = totalPolandPlayers

            for bracket in polandExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    polandRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: polandRank,
                userMilestone: userMilestone,
                countryCode: "PL",
                countrySeed: 110000,
                names: MockLeaderboardData.polandNames,
                day: day,
                totalPlayers: totalPolandPlayers,
                extendedBrackets: polandExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func belgiumEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones (including user)
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, belgiumPlayerMilestones.count) {
            let baseMilestone = belgiumPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.belgiumNames, countrySeed: 115000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 115000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 115000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "be_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        // Build entries with ranks
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalBelgiumPlayers = 8_989

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 115000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "BE",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var belgiumRank = totalBelgiumPlayers

            for bracket in belgiumExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    belgiumRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: belgiumRank,
                userMilestone: userMilestone,
                countryCode: "BE",
                countrySeed: 115000,
                names: MockLeaderboardData.belgiumNames,
                day: day,
                totalPlayers: totalBelgiumPlayers,
                extendedBrackets: belgiumExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func swedenEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones (including user)
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, swedenPlayerMilestones.count) {
            let baseMilestone = swedenPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.swedenNames, countrySeed: 120000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 120000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 120000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "se_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        // Build entries with ranks
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalSwedenPlayers = 6_288

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 120000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "SE",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var swedenRank = totalSwedenPlayers

            for bracket in swedenExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    swedenRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: swedenRank,
                userMilestone: userMilestone,
                countryCode: "SE",
                countrySeed: 120000,
                names: MockLeaderboardData.swedenNames,
                day: day,
                totalPlayers: totalSwedenPlayers,
                extendedBrackets: swedenExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func austriaEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones (including user)
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, austriaPlayerMilestones.count) {
            let baseMilestone = austriaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.austriaNames, countrySeed: 125000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 125000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 125000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "at_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        // Build entries with ranks
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalAustriaPlayers = 7_543

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 125000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "AT",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var austriaRank = totalAustriaPlayers

            for bracket in austriaExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    austriaRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: austriaRank,
                userMilestone: userMilestone,
                countryCode: "AT",
                countrySeed: 125000,
                names: MockLeaderboardData.austriaNames,
                day: day,
                totalPlayers: totalAustriaPlayers,
                extendedBrackets: austriaExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func irelandEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones (including user)
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, irelandPlayerMilestones.count) {
            let baseMilestone = irelandPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.irelandNames, countrySeed: 130000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 130000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 130000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "ie_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        // Build entries with ranks
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalIrelandPlayers = 34_567

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 130000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "IE",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var irelandRank = totalIrelandPlayers

            for bracket in irelandExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    irelandRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: irelandRank,
                userMilestone: userMilestone,
                countryCode: "IE",
                countrySeed: 130000,
                names: MockLeaderboardData.irelandNames,
                day: day,
                totalPlayers: totalIrelandPlayers,
                extendedBrackets: irelandExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func portugalEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones (including user)
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, portugalPlayerMilestones.count) {
            let baseMilestone = portugalPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.portugalNames, countrySeed: 135000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 135000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 135000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "pt_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        // Build entries with ranks
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalPortugalPlayers = 98_989

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 135000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "PT",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var portugalRank = totalPortugalPlayers

            for bracket in portugalExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    portugalRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: portugalRank,
                userMilestone: userMilestone,
                countryCode: "PT",
                countrySeed: 135000,
                names: MockLeaderboardData.portugalNames,
                day: day,
                totalPlayers: totalPortugalPlayers,
                extendedBrackets: portugalExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func greeceEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones (including user)
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, greecePlayerMilestones.count) {
            let baseMilestone = greecePlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.greeceNames, countrySeed: 140000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 140000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 140000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "gr_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        // Build entries with ranks
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalGreecePlayers = 41_414

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 140000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "GR",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var greeceRank = totalGreecePlayers

            for bracket in greeceExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    greeceRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: greeceRank,
                userMilestone: userMilestone,
                countryCode: "GR",
                countrySeed: 140000,
                names: MockLeaderboardData.greeceNames,
                day: day,
                totalPlayers: totalGreecePlayers,
                extendedBrackets: greeceExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func czechiaEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones (including user)
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, czechiaPlayerMilestones.count) {
            let baseMilestone = czechiaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.czechiaNames, countrySeed: 145000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 145000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 145000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "cz_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        // Build entries with ranks
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalCzechiaPlayers = 61_616

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 145000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "CZ",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var czechiaRank = totalCzechiaPlayers

            for bracket in czechiaExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    czechiaRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: czechiaRank,
                userMilestone: userMilestone,
                countryCode: "CZ",
                countrySeed: 145000,
                names: MockLeaderboardData.czechiaNames,
                day: day,
                totalPlayers: totalCzechiaPlayers,
                extendedBrackets: czechiaExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func romaniaEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Build player data with milestones (including user)
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, romaniaPlayerMilestones.count) {
            let baseMilestone = romaniaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.romaniaNames, countrySeed: 150000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 150000, day: day)

            // Apply daily progression to milestones
            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 150000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "ro_\(i)"))
        }

        // Add user to playerData so they get sorted with everyone else
        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))

        // Filter out infinity players (they belong in Hall of Fame only)

        // Sort by milestone index (highest first = best milestone)
        // Tiebreaker 1: user comes first when milestones are equal
        // Tiebreaker 2: lower originalIndex = reached milestone first = better rank
        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        // Build entries with ranks
        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalRomaniaPlayers = 5_966

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 150000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "RO",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // If user is not in top 150, show them with surrounding extended bracket players
        if !userInTop150 {
            var romaniaRank = totalRomaniaPlayers

            for bracket in romaniaExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    romaniaRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: romaniaRank,
                userMilestone: userMilestone,
                countryCode: "RO",
                countrySeed: 150000,
                names: MockLeaderboardData.romaniaNames,
                day: day,
                totalPlayers: totalRomaniaPlayers,
                extendedBrackets: romaniaExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func malaysiaEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, malaysiaPlayerMilestones.count) {
            let baseMilestone = malaysiaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.malaysiaNames, countrySeed: 155000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 155000, day: day)

            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 155000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "my_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))


        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalMalaysiaPlayers = 52_111

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 155000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "MY",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        if !userInTop150 {
            var malaysiaRank = totalMalaysiaPlayers

            for bracket in malaysiaExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    malaysiaRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: malaysiaRank,
                userMilestone: userMilestone,
                countryCode: "MY",
                countrySeed: 155000,
                names: MockLeaderboardData.malaysiaNames,
                day: day,
                totalPlayers: totalMalaysiaPlayers,
                extendedBrackets: malaysiaExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func newZealandEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, newZealandPlayerMilestones.count) {
            let baseMilestone = newZealandPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.newZealandNames, countrySeed: 160000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 160000, day: day)

            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 160000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "nz_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))


        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalNewZealandPlayers = 2_623

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 160000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "NZ",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        if !userInTop150 {
            var newZealandRank = totalNewZealandPlayers

            for bracket in newZealandExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    newZealandRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: newZealandRank,
                userMilestone: userMilestone,
                countryCode: "NZ",
                countrySeed: 160000,
                names: MockLeaderboardData.newZealandNames,
                day: day,
                totalPlayers: totalNewZealandPlayers,
                extendedBrackets: newZealandExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func hungaryEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, hungaryPlayerMilestones.count) {
            let baseMilestone = hungaryPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.hungaryNames, countrySeed: 165000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 165000, day: day)

            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 165000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "hu_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))


        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalHungaryPlayers = 111_111

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 165000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "HU",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        if !userInTop150 {
            var hungaryRank = totalHungaryPlayers

            for bracket in hungaryExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    hungaryRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: hungaryRank,
                userMilestone: userMilestone,
                countryCode: "HU",
                countrySeed: 165000,
                names: MockLeaderboardData.hungaryNames,
                day: day,
                totalPlayers: totalHungaryPlayers,
                extendedBrackets: hungaryExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    private static func thailandEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, thailandPlayerMilestones.count) {
            let baseMilestone = thailandPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.thailandNames, countrySeed: 170000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 170000, day: day)

            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 170000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "th_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))


        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalThailandPlayers = 5_444

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 170000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "TH",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        if !userInTop150 {
            var thailandRank = totalThailandPlayers

            for bracket in thailandExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    thailandRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: thailandRank,
                userMilestone: userMilestone,
                countryCode: "TH",
                countrySeed: 170000,
                names: MockLeaderboardData.thailandNames,
                day: day,
                totalPlayers: totalThailandPlayers,
                extendedBrackets: thailandExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    // UAE Leaderboard - 19,889 total players
    private static func uaeEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, uaePlayerMilestones.count) {
            let baseMilestone = uaePlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.uaeNames, countrySeed: 175000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 175000, day: day)

            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 175000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "ae_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))


        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalUAEPlayers = 19_889

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 175000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "AE",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        if !userInTop150 {
            var uaeRank = totalUAEPlayers

            for bracket in uaeExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    uaeRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: uaeRank,
                userMilestone: userMilestone,
                countryCode: "AE",
                countrySeed: 175000,
                names: MockLeaderboardData.uaeNames,
                day: day,
                totalPlayers: totalUAEPlayers,
                extendedBrackets: uaeExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    // Philippines Leaderboard - 43,210 total players
    private static func philippinesEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, philippinesPlayerMilestones.count) {
            let baseMilestone = philippinesPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.philippinesNames, countrySeed: 180000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 180000, day: day)

            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 180000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "ph_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))


        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalPhilippinesPlayers = 43_210

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 180000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "PH",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        if !userInTop150 {
            var philippinesRank = totalPhilippinesPlayers

            for bracket in philippinesExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    philippinesRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: philippinesRank,
                userMilestone: userMilestone,
                countryCode: "PH",
                countrySeed: 180000,
                names: MockLeaderboardData.philippinesNames,
                day: day,
                totalPlayers: totalPhilippinesPlayers,
                extendedBrackets: philippinesExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    // MARK: - Andorra Leaderboard Data

    // Andorra leaderboard data - top 150 player milestones
    // Total Andorra players: 1,977
    static let andorraPlayerMilestones: [String] = [
        // Ranks 1-10 (from screenshot: 328bn, 4bl, 33bf, 966ba, 1aw, 381aq, 88an, 20aj, 573ae, 4aa)
        "328bn", "4bl", "33bf", "966ba", "1aw", "381aq", "88an", "20aj", "573ae", "4aa",
        // Ranks 11-20 (from screenshot: 7w, 3r, 6p, 11n, 22l, 87j, 1i, 81f, 19f, 19e)
        "7w", "3r", "6p", "11n", "22l", "87j", "1i", "81g", "19f", "19e",
        // Ranks 21-30 (from screenshot: 75d, 1d, 73c, 18c, 9c, 2c, 288b, 18b, 1b, 70a)
        "75d", "1d", "73c", "18c", "9c", "2c", "288b", "18b", "1b", "70a",
        // Ranks 31-42 (from screenshot: 2a, 68B, 17B, 8B, 2B, 1B, 268M, 134M, 134M, 67M, 67M, 33M)
        "2a", "68B", "17B", "8B", "2B", "1B", "268M", "134M", "134M", "67M",
        "67M", "33M",
        // Ranks 43-50 (extended bracket starts at 44 with 16M, so rank 43 is 33M or 16M boundary)
        "16M", "16M", "16M", "8M", "8M", "8M", "8M", "4M",
        // Ranks 51-60
        "4M", "4M", "4M", "4M", "4M", "2M", "2M", "2M", "2M", "2M",
        // Ranks 61-70 (62 starts 2M, 69 starts 1M)
        "2M", "1M", "1M", "1M", "1M", "1M", "1M", "1M", "524K", "524K",
        // Ranks 71-80 (77 starts 524K)
        "524K", "524K", "524K", "524K", "524K", "524K", "262K", "262K", "262K", "262K",
        // Ranks 81-90 (86 starts 262K)
        "262K", "262K", "262K", "262K", "262K", "131K", "131K", "131K", "131K", "131K",
        // Ranks 91-100 (98 starts 131K)
        "131K", "131K", "131K", "131K", "131K", "131K", "131K", "65K", "65K", "65K",
        // Ranks 101-110 (113 starts 65K)
        "65K", "65K", "65K", "65K", "65K", "65K", "65K", "65K", "65K", "65K",
        // Ranks 111-120
        "65K", "65K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K",
        // Ranks 121-130 (132 starts 32K)
        "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K",
        // Ranks 131-140
        "32K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K",
        // Ranks 141-150 (151 starts 8192)
        "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K"
    ]

    // Extended Andorra milestone brackets for rank calculation (ranks 151+)
    // Based on screenshot: 151: 8192, 187: 4096, 233: 2048, 344: 1024, 400: 512
    // 487: 256, 676: 128, 857: 64, 999: 32, 1167: 16, 1296: 8, 1467: 4, 1667: 2, 1799-1977: 0
    static let andorraExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // Raw number brackets (ranks 151-1977)
        ("8192", 151), ("4096", 187), ("2048", 233), ("1024", 344), ("512", 400),
        ("256", 487), ("128", 676), ("64", 857), ("32", 999), ("16", 1167),
        ("8", 1296), ("4", 1467), ("2", 1667), ("0", 1799)  // Score 0 = ranks 1799-1977
    ]

    // Generate Andorra entries with milestone progression and user insertion
    private static func andorraEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, andorraPlayerMilestones.count) {
            let baseMilestone = andorraPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.andorraNames, countrySeed: 185000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 185000, day: day)

            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 185000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "ad_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))


        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalAndorraPlayers = 1_977

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 185000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "AD",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        if !userInTop150 {
            var andorraRank = 151
            for bracket in andorraExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    andorraRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: andorraRank,
                userMilestone: userMilestone,
                countryCode: "AD",
                countrySeed: 185000,
                names: MockLeaderboardData.andorraNames,
                day: day,
                totalPlayers: totalAndorraPlayers,
                extendedBrackets: andorraExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    // Indonesia player milestones (98,982 total players)
    // Top 86 from screenshots, ranks 87-150 filled with appropriate milestones
    static let indonesiaPlayerMilestones: [String] = [
        // Ranks 1-10 (from screenshot: 3bu, 1bp, 598bj, 1bi, 4bf, 129bd, 63bc, 1bc, 1ba, 1az)
        "3bu", "1bp", "598bj", "1bi", "4bf", "129bd", "63bc", "1bc", "1ba", "1az",
        // Ranks 11-20 (from screenshot: 460ay, 230ay, 28ay, 858av, 416au, 1au, 780ar, 2aq, 88an, 1am)
        "460ay", "230ay", "28ay", "858av", "416au", "1au", "780ar", "2aq", "88an", "1am",
        // Ranks 21-30 (from screenshot: 20aj, 615ah, 300ag, 1ag, 4ae, 8ac, 8aa, 994y, 248y, 62y)
        "20aj", "615ah", "300ag", "1ag", "4ae", "8ac", "8aa", "994y", "248y", "62y",
        // Ranks 31-40 (from screenshot: 31y, 1y, 3x, 6t, 1s, 3r, 1q, 766n, 2m, 5k)
        "31y", "1y", "3x", "6t", "1s", "3r", "1q", "766n", "2m", "5k",
        // Ranks 41-52 (from screenshot: 85i, 1h, 79f, 77e, 1e, 4d, 9c, 2c, 576b, 288b, 36b, 2b)
        "85i", "1h", "79f", "77e", "1e", "4d", "9c", "2c", "576b", "288b",
        "36b", "2b",
        // Ranks 53-60 (from screenshot: 4a, 2a, 2a, 1a, 549B, 34B, 34B, 17B)
        "4a", "2a", "2a", "1a", "549B", "34B", "34B", "17B",
        // Ranks 61-70 (from screenshot: 17B, 8B, 8B, 8B, 8B, 4B, 4B, 4B, 4B, 4B)
        "17B", "8B", "8B", "8B", "8B", "4B", "4B", "4B", "4B", "4B",
        // Ranks 71-80 (from screenshot: 2B, 2B, 2B, 2B, 2B, 2B, 2B, 1B, 1B, 1B)
        "2B", "2B", "2B", "2B", "2B", "2B", "2B", "1B", "1B", "1B",
        // Ranks 81-86 (from screenshot: 1B, 1B, 1B, 1B, 1B, 536M)
        "1B", "1B", "1B", "1B", "1B", "536M",
        // Ranks 87-96 (between 536M and 268M at rank 96)
        "536M", "536M", "536M", "536M", "536M", "536M", "536M", "536M", "536M", "268M",
        // Ranks 97-114 (between 268M and 134M at rank 114)
        "268M", "268M", "268M", "268M", "268M", "268M", "268M", "268M", "268M", "268M",
        "268M", "268M", "268M", "268M", "268M", "268M", "268M", "134M",
        // Ranks 115-150 (between 134M and 67M at rank 153)
        "134M", "134M", "134M", "134M", "134M", "134M", "134M", "134M", "134M", "134M",
        "134M", "134M", "134M", "134M", "134M", "134M", "134M", "134M", "134M", "134M",
        "134M", "134M", "134M", "134M", "134M", "134M", "134M", "134M", "134M", "134M",
        "134M", "134M", "134M", "134M", "134M", "134M"
    ]

    // Extended Indonesia milestone brackets for rank calculation (ranks 151+)
    // Based on screenshot data
    static let indonesiaExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        ("67M", 153), ("33M", 231), ("16M", 369), ("8M", 633), ("4M", 844),
        ("2M", 1111), ("1M", 1593), ("524K", 2222), ("262K", 2855), ("131K", 3388),
        ("65K", 4222), ("32K", 5302), ("16K", 6488), ("8192", 7777), ("4096", 9332),
        ("2048", 11234), ("1024", 12345), ("512", 14459), ("256", 18199), ("128", 22222),
        ("64", 28339), ("32", 35339), ("16", 42223), ("8", 51111), ("4", 60292),
        ("2", 72192), ("0", 83298)  // Score 0 = ranks 83298-98982
    ]

    // Generate Indonesia entries with milestone progression and user insertion
    private static func indonesiaEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, indonesiaPlayerMilestones.count) {
            let baseMilestone = indonesiaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.indonesiaNames, countrySeed: 190000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 190000, day: day)

            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 190000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "id_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))


        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalIndonesiaPlayers = 98_982

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 190000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "ID",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        if !userInTop150 {
            var indonesiaRank = 151
            for bracket in indonesiaExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    indonesiaRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: indonesiaRank,
                userMilestone: userMilestone,
                countryCode: "ID",
                countrySeed: 190000,
                names: MockLeaderboardData.indonesiaNames,
                day: day,
                totalPlayers: totalIndonesiaPlayers,
                extendedBrackets: indonesiaExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }
    
    // South Africa player milestones (top 150)
    static let southAfricaPlayerMilestones: [String] = [
        // Ranks 1-10 (from screenshot)
        "642bm", "1bl", "299bj", "583bi", "1bi", "17bh", "556bg", "34bg", "543bf", "16bf",
        // Ranks 11-20 (from screenshot)
        "531be", "253bc", "943az", "449ax", "3ax", "390ar", "3ar", "693am", "1am", "661ak",
        // Ranks 21-30 (from screenshot)
        "40aj", "2ah", "4ad", "7z", "3y", "15x", "948w", "14w", "3v", "6s",
        // Ranks 31-40 (from screenshot)
        "766n", "2n", "2m", "5l", "5k", "5j", "5i", "1i", "664h", "166h",
        // Ranks 41-50 (from screenshot)
        "20h", "5h", "324g", "81g", "20g", "10g", "1g", "79f", "1f", "590c",
        // Ranks 51-60 (from screenshot)
        "2c", "4b", "549B", "274B", "34B", "34B", "4B", "2B", "1B", "536M",
        // Ranks 61-70 (from screenshot)
        "536M", "268M", "67M", "33M", "33M", "16M", "16M", "8M", "8M", "8M",
        // Ranks 71-80 (from screenshot)
        "4M", "4M", "4M", "4M", "4M", "2M", "2M", "2M", "2M", "2M",
        // Ranks 81-92 (from screenshot)
        "2M", "2M", "1M", "1M", "1M", "1M", "1M", "1M", "1M", "1M",
        "1M", "1M",
        // Ranks 93-150 (filling in with decreasing milestones)
        "524K", "524K", "524K", "524K", "524K", "524K", "524K", "524K", "524K", "524K",
        "524K", "524K", "524K", "524K", "524K", "262K", "262K", "262K", "262K", "262K",
        "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K",
        "262K", "262K", "262K", "262K", "262K", "131K", "131K", "131K", "131K", "131K",
        "131K", "131K", "131K", "131K", "131K", "131K", "131K", "131K", "131K", "131K",
        "131K", "131K", "131K", "65K", "65K", "65K", "65K", "65K"
    ]

    // Extended South Africa milestone brackets for rank calculation (ranks 151+)
    // Based on screenshot data
    static let southAfricaExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        ("65K", 146), ("32K", 169), ("16K", 201), ("8192", 239), ("4096", 285),
        ("2048", 355), ("1024", 434), ("512", 548), ("256", 667), ("128", 767),
        ("64", 899), ("32", 1067), ("16", 1234), ("8", 1470), ("4", 1798),
        ("2", 2142), ("0", 2567)  // Score 0 = ranks 2567-2974
    ]

    // Generate South Africa entries with milestone progression and user insertion
    private static func southAfricaEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, southAfricaPlayerMilestones.count) {
            let baseMilestone = southAfricaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.southAfricaNames, countrySeed: 195000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 195000, day: day)

            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 195000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "za_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))


        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalSouthAfricaPlayers = 2_974

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 195000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "ZA",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        if !userInTop150 {
            var southAfricaRank = 151
            for bracket in southAfricaExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    southAfricaRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: southAfricaRank,
                userMilestone: userMilestone,
                countryCode: "ZA",
                countrySeed: 195000,
                names: MockLeaderboardData.southAfricaNames,
                day: day,
                totalPlayers: totalSouthAfricaPlayers,
                extendedBrackets: southAfricaExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    // Kenya player milestones (15,111 total players)
    // Top 150 from screenshots
    static let kenyaPlayerMilestones: [String] = [
        // Ranks 1-10 (from screenshot)
        "109bz", "1bz", "3bw", "689bp", "2bj", "16bf", "471az", "399as", "381aq", "726ao",
        // Ranks 11-20 (from screenshot)
        "693am", "88an", "1al", "2aj", "315ai", "2ai", "1ah", "18ag", "587af", "36af",
        // Ranks 21-30 (from screenshot)
        "1af", "143ae", "2ae", "4ad", "8ac", "266ab", "16ab", "2ab", "254z", "63z",
        // Ranks 31-40 (from screenshot)
        "31z", "7z", "1z", "3x", "27t", "1t", "3s", "52r", "13r", "3r",
        // Ranks 41-50 (from screenshot)
        "1r", "205q", "51q", "3q", "1q", "3p", "1p", "392o", "98o", "49o",
        // Ranks 51-60 (from screenshot)
        "12o", "1o", "383n", "191n", "23n", "23n", "11n", "5n", "2n", "1n",
        // Ranks 61-70 (from screenshot)
        "748m", "748m", "187m", "89k", "44k", "11k", "5k", "680i", "2i", "5g",
        // Ranks 71-80 (from screenshot)
        "2f", "9e", "4e", "1e", "302d", "18d", "2d", "1d", "1d", "1d",
        // Ranks 81-90 (from screenshot)
        "590c", "590c", "590c", "295c", "147c", "147c", "36c", "9c", "2c", "1c",
        // Ranks 91-100 (from screenshot)
        "576b", "288b", "144b", "72b", "36b", "36b", "9b", "9b", "4b", "4b",
        // Ranks 101-110 (from screenshot)
        "2b", "2b", "1b", "562a", "281a", "70a", "17a", "4a", "1a", "274B",
        // Ranks 111-120 (from screenshot)
        "137B", "68B", "34B", "34B", "17B", "17B", "8B", "4B", "4B", "2B",
        // Ranks 121-128 (from screenshot)
        "2B", "1B", "1B", "1B", "536M", "536M", "536M", "268M",
        // Ranks 129-132 (134M bracket)
        "134M", "134M", "134M", "134M",
        // Ranks 133-135 (67M bracket)
        "67M", "67M", "67M",
        // Ranks 136-140 (33M bracket)
        "33M", "33M", "33M", "33M", "33M",
        // Ranks 141-144 (16M bracket)
        "16M", "16M", "16M", "16M",
        // Ranks 145-148 (8M bracket)
        "8M", "8M", "8M", "8M",
        // Ranks 149-150 (4M bracket)
        "4M", "4M"
    ]

    // Extended Kenya milestone brackets for rank calculation (ranks 151+)
    // Based on screenshot data showing bracket boundaries
    static let kenyaExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        ("4M", 151), ("2M", 154), ("1M", 159), ("524K", 164), ("262K", 171),
        ("131K", 180), ("65K", 193), ("32K", 206), ("16K", 229),
        ("8192", 255), ("4096", 284), ("2048", 433), ("1024", 676), ("512", 1000),
        ("256", 1596), ("128", 2222), ("64", 3029), ("32", 3987), ("16", 5222),
        ("8", 6666), ("4", 8444), ("2", 10837), ("0", 12888)  // Score 0 = ranks 12888-15111
    ]

    // Generate Kenya entries with milestone progression and user insertion
    private static func kenyaEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, kenyaPlayerMilestones.count) {
            let baseMilestone = kenyaPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.kenyaNames, countrySeed: 200000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 200000, day: day)

            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 200000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "ke_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))


        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalKenyaPlayers = 15_111

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 200000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "KE",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        if !userInTop150 {
            var kenyaRank = 151
            for bracket in kenyaExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    kenyaRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: kenyaRank,
                userMilestone: userMilestone,
                countryCode: "KE",
                countrySeed: 200000,
                names: MockLeaderboardData.kenyaNames,
                day: day,
                totalPlayers: totalKenyaPlayers,
                extendedBrackets: kenyaExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    // Fiji player milestones (1,214 total players)
    // Top 150 from screenshots
    static let fijiPlayerMilestones: [String] = [
        // Ranks 1-10 (from screenshot)
        "3bu", "1bp", "570bh", "2be", "943az", "1au", "1aq", "1ao", "2am", "645aj",
        // Ranks 11-20 (from screenshot)
        "1ai", "587af", "1ad", "7y", "1u", "12q", "1q", "3p", "5n", "2l",
        // Ranks 21-30 (from screenshot)
        "1j", "5i", "10h", "10g", "19f", "9e", "4d", "2c", "1b", "4a",
        // Ranks 31-40 (from screenshot)
        "137B", "17B", "4B", "2B", "536M", "268M", "67M", "33M", "16M", "16M",
        // Ranks 41-46 (8M bracket)
        "8M", "8M", "8M", "8M", "8M", "8M",
        // Ranks 47-51 (4M bracket)
        "4M", "4M", "4M", "4M", "4M",
        // Ranks 52-58 (2M bracket)
        "2M", "2M", "2M", "2M", "2M", "2M", "2M",
        // Ranks 59-65 (1M bracket)
        "1M", "1M", "1M", "1M", "1M", "1M", "1M",
        // Ranks 66-73 (524K bracket)
        "524K", "524K", "524K", "524K", "524K", "524K", "524K", "524K",
        // Ranks 74-83 (262K bracket)
        "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K", "262K",
        // Ranks 84-93 (131K bracket)
        "131K", "131K", "131K", "131K", "131K", "131K", "131K", "131K", "131K", "131K",
        // Ranks 94-103 (65K bracket)
        "65K", "65K", "65K", "65K", "65K", "65K", "65K", "65K", "65K", "65K",
        // Ranks 104-114 (32K bracket)
        "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K", "32K",
        // Ranks 115-126 (16K bracket)
        "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K", "16K",
        // Ranks 127-143 (8192 bracket)
        "8192", "8192", "8192", "8192", "8192", "8192", "8192", "8192", "8192",
        "8192", "8192", "8192", "8192", "8192", "8192", "8192", "8192",
        // Ranks 144-150 (4096 bracket)
        "4096", "4096", "4096", "4096", "4096", "4096", "4096"
    ]

    // Extended Fiji milestone brackets for rank calculation (ranks 151+)
    // Based on screenshot data showing bracket boundaries
    static let fijiExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        ("4096", 151), ("2048", 161), ("1024", 177), ("512", 196), ("256", 221),
        ("128", 247), ("64", 280), ("32", 322), ("16", 399), ("8", 487),
        ("4", 589), ("2", 711), ("0", 844)  // Score 0 = ranks 844-1214
    ]

    // Generate Fiji entries with milestone progression and user insertion
    private static func fijiEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, fijiPlayerMilestones.count) {
            let baseMilestone = fijiPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.fijiNames, countrySeed: 205000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 205000, day: day)

            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 205000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "fj_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))


        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalFijiPlayers = 1_214

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 205000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "FJ",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        if !userInTop150 {
            var fijiRank = 151
            for bracket in fijiExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    fijiRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: fijiRank,
                userMilestone: userMilestone,
                countryCode: "FJ",
                countrySeed: 205000,
                names: MockLeaderboardData.fijiNames,
                day: day,
                totalPlayers: totalFijiPlayers,
                extendedBrackets: fijiExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    // Vietnam player milestones (167,676 total players)
    // Top 206 from screenshots (extra entries beyond 150 for daily progression)
    static let vietnamPlayerMilestones: [String] = [
        // Ranks 1-10
        "873bz", "436bz", "436bz", "109bz", "27bz", "1bz", "1bv", "776bu", "194bu", "3bu",
        // Ranks 11-20
        "758bt", "2bt", "1bs", "22br", "706bq", "176bq", "88bq", "44bq", "22bq", "22bq",
        // Ranks 21-30
        "5bq", "1bp", "4bl", "1bk", "583bi", "285bh", "556bg", "1bg", "1bf", "4be",
        // Ranks 31-40
        "8bd", "1bd", "63bc", "3bc", "15bb", "966ba", "483ba", "483ba", "241ba", "120ba",
        // Ranks 41-50
        "30ba", "15ba", "7ba", "943az", "471az", "117az", "14az", "921ay", "14ay", "26av",
        // Ranks 51-60
        "1at", "1ar", "1ao", "84al", "1aj", "4ag", "1ae", "8ac", "65aa", "1aa",
        // Ranks 61-70
        "509z", "254z", "127z", "31z", "3z", "1z", "124y", "62y", "31y", "15y",
        // Ranks 71-80
        "7y", "3y", "3y", "1y", "1y", "971x", "485x", "485x", "242x", "121x",
        // Ranks 81-90
        "30x", "15x", "3x", "948w", "118w", "29w", "7w", "1w", "57v", "3v",
        // Ranks 91-100
        "113u", "1u", "220t", "6t", "6r", "3r", "1r", "822q", "411q", "205q",
        // Ranks 101-110
        "102q", "102q", "51q", "51q", "25q", "25q", "6q", "3q", "803p", "401p",
        // Ranks 111-120
        "200p", "100p", "50p", "50p", "25p", "12p", "6p", "3p", "1p", "784o",
        // Ranks 121-130
        "196o", "49o", "3o", "1o", "766n", "383n", "383n", "191n", "95n", "23n",
        // Ranks 131-140
        "5n", "1n", "187m", "5m", "730l", "730l", "182l", "91l", "91l", "45l",
        // Ranks 141-150
        "22l", "11l", "11l", "11l", "11l", "2l", "356k", "89k", "44k", "22k",
        // Ranks 151-160 (buffer for progression)
        "1k", "174j", "21j", "2j", "170i", "1i", "5h", "10g", "2g", "316f",
        // Ranks 161-170
        "19f", "2f", "154e", "4e", "151d", "31d", "9d", "4d", "2d", "2d",
        // Ranks 171-180
        "1d", "590c", "295c", "147c", "73c", "36c", "18c", "18c", "1c",
        // Ranks 179-190
        "576b", "288b", "144b", "72b", "72b", "36b", "2b", "562a", "281a",
        // Ranks 191-200
        "35a", "17a", "8a", "4a", "2a", "2a", "1a", "1a",
        // Ranks 201-206
        "549B", "549B", "274B", "274B", "274B", "137B"
    ]

    // Extended Vietnam milestone brackets for rank calculation (ranks 211+)
    // Total Vietnam players: ~167,676
    static let vietnamExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        ("68B", 211), ("34B", 217), ("17B", 223), ("8B", 230), ("4B", 239),
        ("2B", 251), ("1B", 266), ("536M", 283), ("268M", 302), ("134M", 326),
        ("67M", 344), ("33M", 367), ("16M", 393), ("8M", 422), ("4M", 462),
        ("2M", 506), ("1M", 555), ("524K", 600), ("262K", 676), ("131K", 799),
        ("65K", 959), ("32K", 1111), ("16K", 1254), ("8192", 1456), ("4096", 1888),
        ("2048", 2667), ("1024", 4222), ("512", 8484), ("256", 10987), ("128", 16767),
        ("64", 23938), ("32", 32222), ("16", 46767), ("8", 67676), ("4", 89898),
        ("2", 112345), ("0", 139426)  // Score 0 = ranks 139426-167676
    ]

    // Generate Vietnam entries with milestone progression and user insertion
    private static func vietnamEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, vietnamPlayerMilestones.count) {
            let baseMilestone = vietnamPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.vietnamNames, countrySeed: 210000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 210000, day: day)

            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 210000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "vn_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))


        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalVietnamPlayers = 167_676

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 210000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "VN",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        if !userInTop150 {
            var vietnamRank = totalVietnamPlayers

            for bracket in vietnamExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    vietnamRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: vietnamRank,
                userMilestone: userMilestone,
                countryCode: "VN",
                countrySeed: 210000,
                names: MockLeaderboardData.vietnamNames,
                day: day,
                totalPlayers: totalVietnamPlayers,
                extendedBrackets: vietnamExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
    }

    // Curaçao player milestones (39,999 total players)
    // Top 56 from screenshots (smaller leaderboard)
    static let curacaoPlayerMilestones: [String] = [
        // Ranks 1-10
        "706bq", "1bl", "1be", "1ba", "28ax", "1aw", "1au", "799as", "3as", "1ar",
        // Ranks 11-20
        "726ao", "1an", "84al", "1aj", "1ah", "4ae", "8ab", "994y", "1w", "7u",
        // Ranks 21-30
        "6s", "3r", "1q", "803p", "200p", "1k", "2i", "5g", "79f", "1f",
        // Ranks 31-40
        "19e", "604d", "18d", "590c", "18c", "576b", "18b", "1b", "70a", "4a",
        // Ranks 41-50
        "549B", "68B", "17B", "8B", "2B", "536M", "268M", "134M", "134M", "67M",
        // Ranks 51-56 (continued from top list)
        "67M", "33M", "33M", "33M", "33M", "16M"
    ]

    // Extended Curaçao milestone brackets for rank calculation (ranks 63+)
    // Total Curaçao players: ~39,999
    static let curacaoExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        ("8M", 63), ("4M", 71), ("2M", 82), ("1M", 97), ("524K", 122),
        ("262K", 166), ("131K", 222), ("65K", 299), ("32K", 400),
        ("16K", 566), ("8192", 797), ("4096", 1066), ("2048", 1499),
        ("1024", 2111), ("512", 2788), ("256", 3555), ("128", 4559),
        ("64", 6000), ("32", 7898), ("16", 10444), ("8", 14440),
        ("4", 19277), ("2", 25333), ("0", 33073)  // Score 0 = ranks 33073-39999
    ]

    // Generate Curaçao entries with milestone progression and user insertion
    private static func curacaoEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String, id: String)] = []

        for i in 0..<min(150, curacaoPlayerMilestones.count) {
            let baseMilestone = curacaoPlayerMilestones[i]
            let name = MockLeaderboardData.nameForPlayer(index: i, names: MockLeaderboardData.curacaoNames, countrySeed: 215000, day: day)
            let platform: Platform = i % 3 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarForPlayer(index: i, countrySeed: 215000, day: day)

            let progressedMilestone = MockLeaderboardData.milestoneWithProgression(baseMilestone: baseMilestone, playerIndex: i + 215000, day: day)
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: progressedMilestone)
            playerData.append((i, progressedMilestone, milestoneIdx, name, platform, avatar, "cw_\(i)"))
        }

        let userMilestone = UserLeaderboardData.currentMilestone
        let userMilestoneIdx = MockLeaderboardData.milestoneIndex(for: userMilestone)
        playerData.append((-1, userMilestone, userMilestoneIdx, UserLeaderboardData.playerName, .ios, UserLeaderboardData.avatarID, "me"))


        playerData = playerData.filter { !$0.progressedMilestone.hasSuffix("∞") }
        playerData.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx
            }
            if $0.id == "me" { return true }
            if $1.id == "me" { return false }
            return $0.originalIndex < $1.originalIndex
        }

        var entries: [LeaderboardEntry] = []
        var userInTop150 = false
        let totalCuracaoPlayers = 39_999

        for (rank, player) in playerData.prefix(150).enumerated() {
            let isUserEntry = player.id == "me"
            if isUserEntry {
                userInTop150 = true
            }

            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = isUserEntry ? baseScore : MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 215000, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "CW",
                platform: player.platform,
                isMe: isUserEntry,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        if !userInTop150 {
            var curacaoRank = totalCuracaoPlayers

            for bracket in curacaoExtendedRankBrackets {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIdx >= bracketIndex {
                    curacaoRank = bracket.startRank
                    break
                }
            }

            let extendedEntries = MockLeaderboardData.extendedBracketEntries(
                aroundRank: curacaoRank,
                userMilestone: userMilestone,
                countryCode: "CW",
                countrySeed: 215000,
                names: MockLeaderboardData.curacaoNames,
                day: day,
                totalPlayers: totalCuracaoPlayers,
                extendedBrackets: curacaoExtendedRankBrackets
            )
            entries.append(contentsOf: extendedEntries)
        }

        return entries
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

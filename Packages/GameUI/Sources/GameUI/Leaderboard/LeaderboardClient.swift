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

// MARK: - Daily Progression System
// Players progress through milestones daily. The leaderboard updates at midnight.

private enum MockLeaderboardData {
    // Reference date for calculating day offset
    static let referenceDate: Date = {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }()

    // Calculate days since reference date for progression
    static var daysSinceReference: Int {
        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: referenceDate, to: now).day ?? 0
        return days
    }

    // All milestone tiers in order (lowest to highest)
    static let allMilestones: [String] = [
        "1M", "2M", "4M", "8M", "16M", "33M", "67M", "134M", "268M", "536M",
        "1B", "2B", "4B", "8B", "17B", "34B", "68B", "137B", "274B", "549B",
        "1a", "2a", "4a", "8a", "17a", "35a", "70a", "140a", "281a", "562a",
        "1b", "2b", "4b", "9b", "18b", "36b", "72b", "144b", "288b", "576b",
        "1c", "2c", "4c", "9c", "18c", "37c", "74c", "148c", "296c", "592c",
        "1d", "2d", "4d", "9d", "19d", "38d", "76d", "152d", "304d", "608d",
        "1e", "2e", "5e", "10e", "19e", "39e", "78e", "156e", "312e", "624e",
        "1f", "2f", "5f", "10f", "20f", "40f", "80f", "160f", "320f", "640f",
        "1g", "2g", "5g", "10g", "20g", "41g", "82g", "164g", "328g", "656g",
        "1h", "2h", "5h", "10h", "21h", "42h", "84h", "168h", "336h", "672h",
        "1i", "2i", "5i", "11i", "21i", "43i", "86i", "172i", "344i", "688i",
        "1j", "2j", "5j", "11j", "22j", "44j", "88j", "176j", "352j", "704j",
        "1k", "2k", "5k", "11k", "22k", "45k", "90k", "180k", "360k", "720k",
        "1l", "2l", "6l", "11l", "23l", "46l", "92l", "184l", "368l", "736l",
        "1m", "3m", "6m", "12m", "24m", "48m", "96m", "192m", "384m", "768m",
        "1n", "3n", "6n", "12n", "24n", "49n", "98n", "196n", "392n", "784n",
        "1o", "3o", "6o", "12o", "25o", "50o", "100o", "200o", "400o", "800o",
        "1p", "3p", "6p", "13p", "26p", "52p", "104p", "208p", "416p", "832p",
        "1q", "3q", "7q", "13q", "26q", "53q", "106q", "212q", "424q", "848q",
        "1r", "3r", "7r", "13r", "27r", "54r", "108r", "216r", "432r", "864r",
        "1s", "3s", "7s", "14s", "28s", "56s", "112s", "224s", "448s", "896s",
        "1t", "3t", "7t", "14t", "28t", "57t", "114t", "228t", "456t", "912t",
        "1u", "3u", "7u", "14u", "29u", "58u", "116u", "232u", "464u", "928u",
        "1v", "4v", "7v", "15v", "30v", "60v", "120v", "240v", "480v", "960v",
        "1w", "4w", "8w", "15w", "30w", "61w", "122w", "244w", "488w", "976w",
        "1x", "4x", "8x", "15x", "31x", "62x", "124x", "248x", "496x", "992x",
        "1y", "4y", "8y", "16y", "32y", "64y", "128y", "256y", "512y",
        "1z", "4z", "8z", "16z", "32z", "65z", "130z", "260z", "520z",
        "1aa", "4aa", "8aa", "17aa", "34aa", "68aa", "136aa", "272aa", "544aa",
        "1ab", "4ab", "9ab", "17ab", "35ab", "70ab", "140ab", "280ab", "560ab",
        "1ac", "4ac", "9ac", "18ac", "36ac", "72ac", "144ac", "288ac", "576ac",
        "1ad", "4ad", "9ad", "18ad", "36ad", "73ad", "146ad", "292ad", "584ad",
        "1ae", "5ae", "9ae", "18ae", "37ae", "74ae", "148ae", "296ae", "592ae",
        "1af", "5af", "9af", "19af", "38af", "76af", "152af", "304af", "608af",
        "1ag", "5ag", "10ag", "19ag", "38ag", "77ag", "154ag", "308ag", "616ag",
        "1ah", "5ah", "10ah", "20ah", "40ah", "80ah", "160ah", "320ah", "640ah",
        "1ai", "5ai", "10ai", "20ai", "40ai", "81ai", "162ai", "324ai", "648ai",
        "1aj", "5aj", "10aj", "20aj", "41aj", "82aj", "164aj", "328aj", "656aj",
        "1ak", "5ak", "10ak", "21ak", "42ak", "84ak", "168ak", "336ak", "672ak",
        "1al", "5al", "11al", "21al", "43al", "86al", "172al", "344al", "688al",
        "1am", "5am", "11am", "22am", "44am", "88am", "176am", "352am", "704am",
        "1an", "6an", "11an", "22an", "45an", "90an", "180an", "360an", "720an",
        "1ao", "6ao", "12ao", "23ao", "46ao", "92ao", "184ao", "368ao", "736ao",
        "1ap", "6ap", "12ap", "24ap", "48ap", "96ap", "192ap", "384ap", "768ap",
        "1aq", "6aq", "12aq", "24aq", "48aq", "97aq", "194aq", "388aq", "776aq",
        "1ar", "6ar", "12ar", "24ar", "49ar", "98ar", "196ar", "392ar", "784ar",
        "1as", "6as", "12as", "25as", "50as", "100as", "200as", "400as", "800as",
        "1at", "6at", "13at", "25at", "51at", "102at", "204at", "408at", "816at",
        "1au", "6au", "13au", "26au", "52au", "104au", "208au", "416au", "832au",
        "1av", "7av", "13av", "26av", "53av", "106av", "212av", "424av", "848av",
        "1aw", "7aw", "14aw", "27aw", "54aw", "108aw", "216aw", "432aw", "864aw",
        "1ax", "7ax", "14ax", "28ax", "56ax", "112ax", "224ax", "448ax", "896ax",
        "1ay", "7ay", "14ay", "28ay", "57ay", "114ay", "228ay", "456ay", "912ay",
        "1az", "7az", "14az", "29az", "58az", "116az", "232az", "464az", "928az",
        "1ba", "7ba", "15ba", "30ba", "60ba", "120ba", "240ba", "480ba", "960ba",
        "1bb", "8bb", "15bb", "30bb", "61bb", "122bb", "244bb", "488bb", "976bb",
        "1bc", "8bc", "15bc", "31bc", "62bc", "124bc", "248bc", "496bc", "992bc",
        "1bd", "8bd", "16bd", "32bd", "64bd", "128bd", "256bd", "512bd",
        "1be", "8be", "16be", "32be", "65be", "130be", "260be", "520be",
        "1bf", "8bf", "16bf", "33bf", "66bf", "132bf", "264bf", "528bf",
        "1bg", "8bg", "17bg", "34bg", "68bg", "136bg", "272bg", "544bg",
        "1bh", "9bh", "17bh", "34bh", "69bh", "138bh", "276bh", "552bh",
        "1bi", "9bi", "18bi", "35bi", "70bi", "140bi", "280bi", "560bi",
        "1bj", "9bj", "18bj", "36bj", "72bj", "144bj", "288bj", "576bj",
        "1bk", "9bk", "18bk", "37bk", "74bk", "148bk", "296bk", "592bk",
        "1bl", "9bl", "19bl", "38bl", "76bl", "152bl", "304bl", "608bl",
        "1bm", "9bm", "19bm", "38bm", "77bm", "154bm", "308bm", "616bm",
        "1bn", "10bn", "19bn", "39bn", "78bn", "156bn", "312bn", "624bn",
        "1bo", "10bo", "20bo", "40bo", "80bo", "160bo", "320bo", "640bo",
        "1bp", "10bp", "20bp", "41bp", "82bp", "164bp", "328bp", "656bp",
        "1bq", "10bq", "21bq", "42bq", "84bq", "168bq", "336bq", "672bq",
        "1br", "10br", "21br", "42br", "85br", "170br", "340br", "680br",
        "1bs", "11bs", "21bs", "43bs", "86bs", "172bs", "344bs", "688bs",
        "1bt", "11bt", "22bt", "44bt", "88bt", "176bt", "352bt", "704bt",
        "1bu", "11bu", "22bu", "45bu", "90bu", "180bu", "360bu", "720bu",
        "1bv", "11bv", "23bv", "46bv", "92bv", "184bv", "368bv", "736bv",
        "1bw", "12bw", "23bw", "46bw", "93bw", "186bw", "372bw", "744bw",
        "1bx", "12bx", "24bx", "48bx", "96bx", "192bx", "384bx", "768bx",
        "1by", "12by", "24by", "49by", "98by", "196by", "392by", "784by",
        "1bz", "12bz", "25bz", "50bz", "100bz", "200bz", "400bz", "800bz",
        "873bz"
    ]

    static let globalNames = [
        "DefenselessMetal49", "LopingLemming57", "DensePage91", "BrittleBelly111", "PerfectPirate2198",
        "CaramelStamp47", "Player6362", "CulturalDerision48", "KnownOwner26", "SwiftCoder99",
        "PixelMaster42", "NeonRacer77", "CloudJumper88", "StarGazer2024", "ThunderBolt55",
        "CryptoKing101", "MidnightOwl33", "SolarFlare22", "OceanWave44", "MountainPeak99",
        "DesertStorm77", "JungleCat55", "ArcticFox88", "TropicalBird11", "CosmicDust66",
        "QuantumLeap23", "NebulaStar45", "GalaxyRider78", "AsteroidHunter12", "CometChaser34",
        "MeteorShower56", "SaturnRing89", "JupiterMoon01", "MarsRover67", "VenusFlyer90",
        "MercuryDash43", "PlutoExplorer21", "NeptuneWave65", "UranusOrbit87", "EarthGuard09",
        "SunBlaze32", "MoonWalker54", "StarDancer76", "SpacePilot98", "RocketMan10",
        "LaserBeam38", "PhotonBlast60", "NeutronStar82", "ProtonPower04", "ElectronFlow26",
        "AtomSmasher48", "MoleculeMix70", "CellDivider92", "DNAHelix14", "RNAStrand36",
        "ProteinFold58", "EnzymeCat80", "VitaminBoost02", "MineralRock24", "CrystalClear46",
        "DiamondEdge68", "RubyGlow91", "SapphireShine13", "EmeraldDream35", "AmethystMist57",
        "TopazSun79", "OpalMoon01", "PearlOcean23", "JadeForest45", "OnyxShadow67",
        "GarnetFire89", "TurquoiseSky11", "CoralReef33", "IvoryTower55", "BronzeAge77",
        "SilverLining99", "GoldRush21", "PlatinumPro43", "TitaniumStrong65", "CopperGlow87",
        "IronWill09", "SteelNerve31", "AluminumLight53", "ZincShield75", "NickelSpin97",
        "CobaltBlue19", "ChromeFinish41", "TungstenTough63", "MolybdenumMax85", "VanadiumVibe07",
        "ManganeseMight29", "PalladiumPure51", "RhodiumRare73", "IridiumIntense95", "OsmiumOdd17",
        "RheniumRich39", "TantalumTwist61", "HafniumHigh83", "ZirconiumZest05", "NiobiumNova27"
    ]

    static let hallOfFameNames = [
        "InfinityMaster01", "EndlessVoyager", "BeyondLimits99", "EternalChamp", "UltimatePlayer",
        "LegendaryGamer", "InfiniteWinner", "CosmicConqueror", "SupremeVictor", "DivinePlayer",
        "MythicalHero", "TranscendentOne", "OmnipotentGamer", "CelestialKing", "ImmortalPlayer",
        "UnstoppableForce", "PerfectScore99", "FlawlessVictory", "AbsoluteChamp", "MaxLevelPro",
        "GodTierPlayer", "EliteInfinity", "MasterOfAll", "ChampOfChamps", "NumberOneForever",
        "SkillMaxed100", "TopDogForever", "KingOfKings", "QueenSupreme", "UltimateVictory",
        "BeyondPerfect", "EndgameBoss", "FinalFormPro", "MaxPowerUser", "InfiniteGlory",
        "EternalVictory", "LimitBreaker00", "BoundlessSkill", "NeverEndingWin", "ForeverFirst"
    ]

    static let usNames = [
        "AmericanEagle01", "StarsAndStripes", "USAChamp99", "LibertyGamer", "PatriotPlayer",
        "FreedomFighter", "StateStar77", "CapitalCity55", "RedWhiteBlue", "UncleSamPro",
        "NYCGamer01", "LAPlayer99", "ChicagoChamp", "TexasHero", "FloridaFan",
        "CaliforniaDream", "NewYorkNinja", "BostonBoss", "SeattleStar", "DenverDude",
        "PhoenixPro", "HoustonHawk", "AtlantaAce", "MiamiMaster", "DetroitDynamo",
        "PhillyPhenom", "DCDefender", "VegasVictor", "PortlandPower", "AustinAce"
    ]

    static let countries = ["JP", "BR", "PK", "DE", "UZ", "IN", "FR", "GB", "LB", "CA", "AU", "KR", "MX", "IT", "ES", "US", "CN", "RU", "NG", "EG", "ZA", "AR", "CL", "CO", "PE"]

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
}

public extension LeaderboardClient {
    static let noop = LeaderboardClient(
        authenticate: { true },
        submitScore: { _ in },
        fetchPage: { _, filter, _, _ in
            let entries: [LeaderboardEntry]
            switch filter {
            case .hallOfFame:
                entries = hallOfFameEntries()
            case .country:
                entries = countryEntries()
            case .global:
                entries = globalEntries()
            }
            let totalPlayers: Int
            switch filter {
            case .hallOfFame:
                totalPlayers = hallOfFameEntries().count
            case .country:
                totalPlayers = 127_493  // 100k+ US players
            case .global:
                totalPlayers = 943_817  // 900k+ global players
            }
            return .init(entries: entries, myEntry: entries.last, nextCursor: nil, totalPlayers: totalPlayers)
        },
        fetchMyRank: { _, _ in globalEntries().last }
    )

    // Hall of Fame - only players who reached ∞, ordered by number of infinity tiles made
    private static func hallOfFameEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference
        let countries = ["US", "JP", "KR", "DE", "GB", "FR", "CA", "AU", "BR", "IN", "CN", "RU", "IT", "ES", "MX"]

        // Build list of players who reached infinity with their counts
        var infinityPlayers: [(index: Int, count: Int)] = []
        for i in 0..<40 {
            let count = MockLeaderboardData.infinityCount(for: i, day: day)
            infinityPlayers.append((i, count))
        }

        // Sort by infinity count descending
        infinityPlayers.sort { $0.count > $1.count }

        var entries: [LeaderboardEntry] = []
        for (rank, player) in infinityPlayers.enumerated() {
            let name = MockLeaderboardData.hallOfFameNames[player.index % MockLeaderboardData.hallOfFameNames.count]
            let country = countries[player.index % countries.count]
            let platform: Platform = player.index % 2 == 0 ? .ios : .android
            let score = 9999000 - (rank * 50000)

            entries.append(LeaderboardEntry(
                id: "hof_\(player.index)",
                rank: rank + 1,
                name: name,
                score: score,
                countryCode: country,
                platform: platform,
                highestTile: "\(player.count)∞"
            ))
        }

        return entries
    }

    // Shared function to get US player milestone data (ensures consistency between Global and US tabs)
    private static func usPlayerData(day: Int, milestones: [String]) -> [(index: Int, milestoneIdx: Int)] {
        var players: [(index: Int, milestoneIdx: Int)] = []
        for i in 0..<30 {
            // Use consistent seed and base index for US players
            let baseIndex = max(0, milestones.count - 80 - (i * 4))
            let currentMilestoneIdx = MockLeaderboardData.milestoneIndex(for: i + 500, baseIndex: baseIndex, day: day)

            if currentMilestoneIdx >= milestones.count - 1 {
                continue
            }

            players.append((i, currentMilestoneIdx))
        }
        return players
    }

    // Global leaderboard - includes all players (international + US)
    private static func globalEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference
        let milestones = MockLeaderboardData.allMilestones

        // Build player list with current milestones
        // Mix of international players and US players
        var players: [(index: Int, milestoneIdx: Int, isUS: Bool)] = []

        // International players (70 players from various countries)
        for i in 0..<70 {
            let baseIndex = max(0, milestones.count - 50 - (i * 2))
            let currentMilestoneIdx = MockLeaderboardData.milestoneIndex(for: i + 100, baseIndex: baseIndex, day: day)

            if currentMilestoneIdx >= milestones.count - 1 {
                continue
            }

            players.append((i, currentMilestoneIdx, false))
        }

        // US players (30 players) - use shared function for consistency
        let usPlayers = usPlayerData(day: day, milestones: milestones)
        for player in usPlayers {
            players.append((player.index, player.milestoneIdx, true))
        }

        // Sort all players by milestone descending
        players.sort { $0.milestoneIdx > $1.milestoneIdx }

        var entries: [LeaderboardEntry] = []
        for (rank, player) in players.prefix(100).enumerated() {
            let name: String
            let country: String
            let id: String

            if player.isUS {
                name = MockLeaderboardData.usNames[player.index % MockLeaderboardData.usNames.count]
                country = "US"
                id = "us_\(player.index)"
            } else {
                name = MockLeaderboardData.globalNames[player.index % MockLeaderboardData.globalNames.count]
                country = MockLeaderboardData.countries[player.index % MockLeaderboardData.countries.count]
                id = "global_\(player.index)"
            }

            let platform: Platform = player.index % 2 == 0 ? .ios : .android
            let milestone = milestones[player.milestoneIdx]
            let score = max(1000, 873000 - (rank * 8500))

            entries.append(LeaderboardEntry(
                id: id,
                rank: rank + 1,
                name: name,
                score: score,
                countryCode: country,
                platform: platform,
                highestTile: milestone
            ))
        }

        // Add current user entry (ranked among 900k+ global players)
        entries.append(LeaderboardEntry(
            id: "me",
            rank: 487_293,
            name: "Angel Junior711",
            score: 1000,
            countryCode: "US",
            platform: .ios,
            isMe: true,
            highestTile: "2M"
        ))

        return entries
    }

    // Country (US) leaderboard - shows only US players with same milestones as Global
    private static func countryEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference
        let milestones = MockLeaderboardData.allMilestones

        // Use shared function for US players (ensures same milestones as Global tab)
        var players = usPlayerData(day: day, milestones: milestones)
        players.sort { $0.milestoneIdx > $1.milestoneIdx }

        var entries: [LeaderboardEntry] = []
        for (rank, player) in players.enumerated() {
            let name = MockLeaderboardData.usNames[player.index % MockLeaderboardData.usNames.count]
            let platform: Platform = player.index % 2 == 0 ? .ios : .android
            let milestone = milestones[player.milestoneIdx]
            let score = max(1000, 873000 - (rank * 15000))

            entries.append(LeaderboardEntry(
                id: "us_\(player.index)",
                rank: rank + 1,
                name: name,
                score: score,
                countryCode: "US",
                platform: platform,
                highestTile: milestone
            ))
        }

        // Add current user entry (ranked among 100k+ US players)
        entries.append(LeaderboardEntry(
            id: "me",
            rank: 58_472,
            name: "Angel Junior711",
            score: 1000,
            countryCode: "US",
            platform: .ios,
            isMe: true,
            highestTile: "2M"
        ))

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

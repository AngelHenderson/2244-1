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
            return .init(entries: entries, myEntry: entries.last, nextCursor: nil, totalPlayers: filter == .hallOfFame ? 47 : 12847)
        },
        fetchMyRank: { _, _ in globalEntries().last }
    )

    // Hall of Fame - only players who reached ∞
    private static func hallOfFameEntries() -> [LeaderboardEntry] {
        let names = [
            "InfinityMaster01", "EndlessVoyager", "BeyondLimits99", "EternalChamp", "UltimatePlayer",
            "LegendaryGamer", "InfiniteWinner", "CosmicConqueror", "SupremeVictor", "DivinePlayer",
            "MythicalHero", "TranscendentOne", "OmnipotentGamer", "CelestialKing", "ImmotalPlayer",
            "UnstoppableForce", "PerfectScore99", "FlawlessVictory", "AbsoluteChamp", "MaxLevelPro",
            "GodTierPlayer", "EliteInfinity", "MasterOfAll", "ChampOfChamps", "NumberOneForever",
            "SkillMaxed100", "TopDogForever", "KingOfKings", "QueenSupreme", "UltimateVictory",
            "BeyondPerfect", "EndgameBoss", "FinalFormPro", "MaxPowerUser", "InfiniteGlory",
            "EternalVictory", "LimitBreaker00", "BoundlessSkill", "NeverEndingWin", "ForeverFirst"
        ]
        let countries = ["US", "JP", "KR", "DE", "GB", "FR", "CA", "AU", "BR", "IN", "CN", "RU", "IT", "ES", "MX"]

        var entries: [LeaderboardEntry] = []
        for i in 0..<40 {
            let rank = i + 1
            let name = names[i % names.count]
            let country = countries[i % countries.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let score = max(999000, 9999000 - (i * 50000))

            entries.append(LeaderboardEntry(
                id: "hof_\(rank)",
                rank: rank,
                name: name,
                score: score,
                countryCode: country,
                platform: platform,
                highestTile: "∞"
            ))
        }

        return entries
    }

    // Global leaderboard - regular players (no infinity)
    private static func globalEntries() -> [LeaderboardEntry] {
        let names = [
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
        let countries = ["JP", "BR", "PK", "DE", "UZ", "IN", "FR", "GB", "LB", "CA", "AU", "KR", "MX", "IT", "ES", "US", "CN", "RU", "NG", "EG", "ZA", "AR", "CL", "CO", "PE"]
        // Global leaderboard starts at 873bz (no infinity - those are in Hall of Fame)
        let milestones = [
            "873bz", "436bz", "218bz", "109bz", "54bz", "27bz", "13bz", "6bz", "3bz", "1bz",
            "436by", "218by", "109by", "54by", "27by", "13by", "6by", "3by", "1by",
            "436bx", "218bx", "109bx", "54bx", "27bx", "13bx", "6bx", "3bx", "1bx",
            "436bw", "218bw", "109bw", "54bw", "27bw", "13bw", "6bw", "3bw", "1bw",
            "436bv", "218bv", "109bv", "54bv", "27bv", "13bv", "6bv", "3bv", "1bv",
            "436bu", "218bu", "109bu", "54bu", "27bu", "13bu", "6bu", "3bu", "1bu",
            "436bt", "218bt", "109bt", "54bt", "27bt", "13bt", "6bt", "3bt", "1bt",
            "436bs", "218bs", "109bs", "54bs", "27bs", "13bs", "6bs", "3bs", "1bs",
            "436br", "218br", "109br", "54br", "27br", "13br", "6br", "3br", "1br",
            "436bq", "218bq", "109bq", "54bq", "27bq", "13bq", "6bq", "3bq", "1bq"
        ]

        var entries: [LeaderboardEntry] = []
        for i in 0..<100 {
            let rank = i + 1
            let name = names[i % names.count]
            let country = countries[i % countries.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let milestone = milestones[min(i, milestones.count - 1)]
            let score = max(1000, 873000 - (i * 8500))

            entries.append(LeaderboardEntry(
                id: "\(rank)",
                rank: rank,
                name: name,
                score: score,
                countryCode: country,
                platform: platform,
                highestTile: milestone
            ))
        }

        // Add current user entry
        entries.append(LeaderboardEntry(
            id: "me",
            rank: 536,
            name: "Angel Junior711",
            score: 1000,
            countryCode: "US",
            platform: .ios,
            isMe: true,
            highestTile: "2M"
        ))

        return entries
    }

    // Country (US) leaderboard - US players only
    private static func countryEntries() -> [LeaderboardEntry] {
        let names = [
            "AmericanEagle01", "StarsAndStripes", "USAChamp99", "LibertyGamer", "PatriotPlayer",
            "FreedomFighter", "StateStar77", "CapitalCity55", "RedWhiteBlue", "UncleSamPro",
            "NYCGamer01", "LAPlayer99", "ChicagoChamp", "TexasHero", "FloridaFan",
            "CaliforniaDream", "NewYorkNinja", "BostonBoss", "SeattleStar", "DenverDude",
            "PhoenixPro", "HoustonHawk", "AtlantaAce", "MiamiMaster", "DetroitDynamo",
            "PhillyPhenom", "DCDefender", "VegasVictor", "PortlandPower", "AustinAce"
        ]
        let milestones = [
            "873bz", "436bz", "218bz", "109bz", "54bz", "27bz", "13bz", "6bz", "3bz", "1bz",
            "436by", "218by", "109by", "54by", "27by", "13by", "6by", "3by", "1by",
            "436bx", "218bx", "109bx", "54bx", "27bx", "13bx", "6bx", "3bx", "1bx",
            "436bw", "218bw", "109bw", "54bw", "27bw", "13bw", "6bw", "3bw", "1bw",
            "436bv", "218bv", "109bv", "54bv", "27bv", "13bv", "6bv", "3bv", "1bv"
        ]

        var entries: [LeaderboardEntry] = []
        for i in 0..<50 {
            let rank = i + 1
            let name = names[i % names.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let milestone = milestones[min(i, milestones.count - 1)]
            let score = max(1000, 873000 - (i * 15000))

            entries.append(LeaderboardEntry(
                id: "us_\(rank)",
                rank: rank,
                name: name,
                score: score,
                countryCode: "US",
                platform: platform,
                highestTile: milestone
            ))
        }

        // Add current user entry
        entries.append(LeaderboardEntry(
            id: "me",
            rank: 46,
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

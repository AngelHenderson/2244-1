import SwiftUI
import Foundation

// MARK: - User Milestone Storage (for mock leaderboard)
public enum UserLeaderboardData {
    /// The user's current highest milestone (e.g., "16M", "33M", "1B")
    /// Reads from UserDefaults "leaderboard.milestone" (set by GameStore)
    public static var currentMilestone: String {
        UserDefaults.standard.string(forKey: "leaderboard.milestone") ?? "16M"
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
    /// Uses device locale to determine country
    public static var currentCountry: String {
        Locale.current.region?.identifier ?? "US"
    }
}

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

    // All milestone tiers in order (lowest to highest) - generated from doubling sequence
    static let allMilestones: [String] = [
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
        "2bj", "4bj", "9bj", "18bj", "37bj", "74bj", "149bj", "298bj", "598bj", "1bk",
        "2bk", "4bk", "9bk", "19bk", "38bk", "76bk", "152bk", "306bk", "612bk", "1bl",
        "2bl", "4bl", "9bl", "19bl", "39bl", "78bl", "156bl", "313bl", "627bl", "1bm",
        "2bm", "5bm", "10bm", "20bm", "40bm", "80bm", "160bm", "321bm", "642bm", "1bn",
        "2bn", "5bn", "10bn", "20bn", "41bn", "82bn", "164bn", "328bn", "657bn", "1bo",
        "2bo", "5bo", "10bo", "21bo", "42bo", "84bo", "168bo", "336bo", "673bo", "1bp",
        "2bp", "5bp", "10bp", "21bp", "43bp", "86bp", "172bp", "345bp", "689bp", "1bq",
        "2bq", "5bq", "11bq", "22bq", "44bq", "88bq", "177bq", "354bq", "707bq", "1br",
        "2br", "5br", "11br", "22br", "45br", "90br", "180br", "361br", "722br", "1bs",
        "2bs", "5bs", "11bs", "23bs", "46bs", "92bs", "185bs", "370bs", "740bs", "1bt",
        "2bt", "5bt", "11bt", "23bt", "47bt", "94bt", "189bt", "379bt", "758bt", "1bu",
        "2bu", "5bu", "11bu", "23bu", "48bu", "97bu", "194bu", "388bu", "776bu", "1bv",
        "2bv", "5bv", "12bv", "24bv", "49bv", "99bv", "198bv", "397bv", "794bv", "1bw",
        "3bw", "6bw", "12bw", "25bw", "50bw", "101bw", "203bw", "407bw", "814bw", "1bx",
        "3bx", "6bx", "13bx", "26bx", "52bx", "104bx", "208bx", "416bx", "833bx", "1by",
        "3by", "6by", "13by", "26by", "53by", "106by", "213by", "426by", "853by", "1bz",
        "3bz", "6bz", "13bz", "27bz", "54bz", "109bz", "218bz", "436bz", "872bz", "873bz"
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
        "RheniumRich39", "TantalumTwist61", "HafniumHigh83", "ZirconiumZest05", "NiobiumNova27",
        "TokyoTiger01", "LondonLion22", "ParisPanther33", "BerlinBear44", "SydneySerpent55",
        "TorontoTornado66", "MadridMaverick77", "RomeRaider88", "SaoPauloStar99", "MumbaiMaster00",
        "ShanghaiShark11", "MoscowMight23", "DubaiDragon34", "SingaporeSurge45", "HongKongHero56",
        "SeoulSniper67", "BangkokBolt78", "JakartaJet89", "CairoChamp90", "LagoosLegend01",
        "NairobiNinja12", "CapeTownCrush23", "BuenosAiresBoss34", "MexicoCityMaster45", "LimaaLion56",
        "SantiagoStorm67", "BogotaBeast78", "CaracasChamp89", "HavannaHawk90", "KingstonKing01",
        "MontrealMaverick12", "VancouverVictor23", "MelbourneMight34", "AucklandAce45", "WellingtonWolf56",
        "OsakaOracle67", "KyotoKnight78", "NagoyaNinja89", "FukuokaaFury90", "SapporoStrike01",
        "MunichMaster12", "HamburgHero23", "FrankfurtFlash34", "CologneCrusher45", "DusseldorfDragon56",
        "AmsterdamAce67", "BrussellsBoss78", "ViennaViking89", "ZurichZealot90", "GenevaGhost01"
    ]

    static let hallOfFameNames = [
        // Ranks 1-30
        "InfinityMaster01", "EndlessVoyager", "BeyondLimits99", "EternalChamp", "UltimatePlayer",
        "LegendaryGamer", "InfiniteWinner", "CosmicConqueror", "SupremeVictor", "DivinePlayer",
        "MythicalHero", "TranscendentOne", "OmnipotentGamer", "CelestialKing", "ImmortalPlayer",
        "UnstoppableForce", "PerfectScore99", "FlawlessVictory", "AbsoluteChamp", "MaxLevelPro",
        "GodTierPlayer", "EliteInfinity", "MasterOfAll", "ChampOfChamps", "NumberOneForever",
        "SkillMaxed100", "TopDogForever", "KingOfKings", "QueenSupreme", "UltimateVictory",
        // Ranks 31-60
        "BeyondPerfect", "EndgameBoss", "FinalFormPro", "MaxPowerUser", "InfiniteGlory",
        "EternalVictory", "LimitBreaker00", "BoundlessSkill", "NeverEndingWin", "ForeverFirst",
        "AlphaOmega01", "ZenithReached", "ApexPredator99", "PinnaclePlayer", "SummitSeeker",
        "VanguardVictor", "ParagonPrime", "SupremeSeeker", "TitanTamer", "OlympianOne",
        "PhoenixRisen", "DragonSlayer99", "ThunderGod01", "StormBringer", "LightningLord",
        "ShadowMaster", "VoidWalker00", "CosmicRuler", "GalacticKing", "UniversalChamp",
        // Ranks 61-90
        "StarForger01", "NebulaNinja", "QuantumKing99", "DimensionLord", "RealityBender",
        "TimeTraveler", "SpaceConqueror", "MatterMaster", "EnergyElite", "ForceField99",
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
        "MindMaster01", "BrainBoss99", "ThoughtTitan", "IdeaIcon", "ConceptChamp",
        "VisionVictor", "DreamDynamo", "HopeHero", "FaithFighter", "BelieveBoss",
        "TrustTitan", "LoyalLegend", "HonorHero", "GloryGamer", "FameFlame",
        "ReputationRuler", "PrestigePro", "StatusStar", "RankRoyal", "TierTitan",
        "LevelLord", "GradientGuru", "ScaleSeeker", "MeasureMaster", "MetricMight",
        "UnitUltimate", "ValueVictor", "WorthWinner", "PricePlayer", "CostChamp"
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

        // Find milestone index in allMilestones array
        if let index = allMilestones.firstIndex(of: milestone) {
            // Score grows with milestone tier
            // Use a logarithmic scale to prevent overflow
            let baseScore = 1_000_000  // 1 million base
            let tierBonus = index * 10_000_000  // 10 million per tier
            return baseScore + tierBonus
        }

        // Fallback: try to estimate based on suffix
        let suffixes = ["M", "B", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
        let doubleSuffixes = ["aa", "ab", "ac", "ad", "ae", "af", "ag", "ah", "ai", "aj", "ak", "al", "am", "an", "ao", "ap", "aq", "ar", "as", "at", "au", "av", "aw", "ax", "ay", "az", "ba", "bb", "bc", "bd", "be", "bf", "bg", "bh", "bi", "bj", "bk", "bl", "bm", "bn", "bo", "bp", "bq", "br", "bs", "bt", "bu", "bv", "bw", "bx", "by", "bz"]

        // Extract mantissa and suffix
        var mantissa = 1
        var suffix = ""
        for (i, char) in milestone.enumerated() {
            if char.isLetter {
                suffix = String(milestone.dropFirst(i))
                mantissa = Int(milestone.prefix(i)) ?? 1
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

    // Calculate new players joining on a given day (10-1000 per day)
    static func newPlayersJoining(on day: Int, isUS: Bool) -> Int {
        let seed = isUS ? 12345 : 67890
        let random = seededRandom(seed: seed, index: day)
        return 10 + Int(random * 990)  // 10 to 1000 new players per day
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

    // Calculate total players including all who joined up to this day
    static func totalPlayers(on day: Int, isUS: Bool) -> Int {
        let basePlayers = isUS ? baseUSPlayers : baseGlobalPlayers
        var totalNew = 0
        for d in 0...day {
            totalNew += newPlayersJoining(on: d, isUS: isUS)
        }
        return basePlayers + totalNew
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

    // Avatar IDs from AvatarCatalog (12 options, cycled for all players)
    static let avatarIDs = [
        "avatar-shiba-dog", "avatar-astronaut-cat", "avatar-robot-green", "avatar-phoenix-fire",
        "avatar-shark-teeth", "avatar-paper-plane", "avatar-baseball-cap", "avatar-warrior-samurai",
        "avatar-burger-food", "avatar-chicken-bird", "avatar-anchor-nautical", "avatar-bear-grizzly"
    ]

    // Calculate infinity count with daily progression for Hall of Fame players
    // Players gain 0.25-1.5 infinities per day
    static func infinityCountWithProgression(baseCount: Int, playerIndex: Int, day: Int) -> Int {
        // Each player gets a consistent daily infinity gain rate between 0.25 and 1.5
        let dailyRate = 0.25 + seededRandom(seed: playerIndex * 888, index: playerIndex) * 1.25  // 0.25 to 1.5
        // Accumulate infinities over days
        let totalGained = dailyRate * Double(day)
        return baseCount + Int(totalGained)
    }

    // Calculate milestone progression for regular leaderboard players
    // Players progress through milestone tiers at different rates (0.25-1.5 milestones per day)
    // But cap total progression to prevent everyone reaching max milestone
    static func milestoneWithProgression(baseMilestone: String, playerIndex: Int, day: Int) -> String {
        guard let baseIndex = allMilestones.firstIndex(of: baseMilestone) else {
            return baseMilestone
        }

        // Each player gets a consistent daily milestone progression rate
        let dailyRate = 0.25 + seededRandom(seed: playerIndex * 888, index: playerIndex) * 1.25  // 0.25 to 1.5 milestones per day

        // Cap the effective days to prevent over-progression (max ~30 days worth of progression)
        let effectiveDays = min(day, 30)
        let tiersGained = Int(dailyRate * Double(effectiveDays))

        // Progress through milestone tiers (capped at max tier)
        let newIndex = min(baseIndex + tiersGained, allMilestones.count - 1)
        return allMilestones[newIndex]
    }

    // Get milestone index for sorting (higher index = better milestone)
    static func milestoneIndex(for milestone: String) -> Int {
        return allMilestones.firstIndex(of: milestone) ?? 0
    }

    // Exact Hall of Fame infinity counts from screenshots (ranks 1-150)
    static let hallOfFameInfinityCounts: [Int] = [
        // Ranks 1-15
        15552, 11987, 9534, 8923, 8099, 7833, 7344, 7099, 6904, 6654, 6544, 6467, 6400, 6355, 6311,
        // Ranks 16-30
        6166, 6161, 6144, 6022, 5866, 5621, 5294, 5102, 4755, 4463, 3776, 3234, 3012, 2975, 2789,
        // Ranks 31-45
        2342, 1996, 1775, 1532, 1165, 1002, 888, 855, 828, 777, 764, 749, 732, 721, 709,
        // Ranks 46-60
        665, 623, 583, 558, 543, 511, 397, 376, 354, 333, 277, 232, 196, 155, 124,
        // Ranks 61-75
        99, 77, 73, 67, 65, 65, 64, 62, 59, 58, 57, 57, 55, 52, 50,
        // Ranks 76-90
        48, 47, 47, 46, 46, 45, 44, 42, 41, 40, 39, 37, 33, 32, 32,
        // Ranks 91-105
        31, 31, 30, 27, 26, 26, 25, 25, 24, 23, 23, 22, 22, 21, 19,
        // Ranks 106-120
        19, 18, 18, 18, 17, 16, 15, 15, 14, 14, 14, 13, 13, 13, 12,
        // Ranks 121-135
        11, 11, 10, 10, 9, 9, 9, 9, 8, 8, 8, 8, 8, 7, 7,
        // Ranks 136-150
        6, 6, 6, 5, 5, 4, 3, 3, 3, 2, 2, 2, 1, 1, 1
    ]

    static let usNames = [
        "AmericanEagle01", "StarsAndStripes", "USAChamp99", "LibertyGamer", "PatriotPlayer",
        "FreedomFighter", "StateStar77", "CapitalCity55", "RedWhiteBlue", "UncleSamPro",
        "NYCGamer01", "LAPlayer99", "ChicagoChamp", "TexasHero", "FloridaFan",
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
        "LondonLegend01", "ManchesterMaverick", "BirminghamBoss", "LiverpoolLion", "LeedsLightning",
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
        "ParisPro", "MarseilleMaster", "LyonLegend", "ToulouseTitan", "NiceNinja",
        "NantesNomad", "StrasbourgStar", "MontpellierMaverick", "BordeauxBoss", "LilleLion",
        "RennesRaider", "ReimsRogue", "LeHavreHawk", "SaintEtienneSlayer", "ToulonTornado",
        "GrenobleGhost", "DijonDestroyer", "AngersAce", "NimesNinja", "VilleurbannneVictor",
        "ClermontCrusher", "LeMansLegend", "AixEnProvenceAce", "BrestBrawler", "ToursThunder",
        "AmiensAssassin", "LimogesLion", "MetzMaster", "BesanconBolt", "PerpignanProwler",
        "OrleansOracle", "MulhouseMaverick", "RouenRaider", "CaenCrusher", "NancyNinja",
        "ArgenteueilAce", "SaintDenisStar", "RoubaixRogue", "TourcoingTitan", "MontreueilMaster",
        "AvignonAvenger", "DunkerqueDestroyer", "AsnieresAce", "VersaillesVictor", "ColombesChamp",
        "SaintPaulStar", "AubervilliersAce", "ChampignyShadow", "CourbevoieChamp", "VitryVictor",
        "PoitiersPhantom", "CalaisCrusher", "AntibesAce", "LaRochelleLegend", "CannesChamp",
        "StMaloMaster", "ChamberyChamp", "NiortNinja", "HyeresHero", "ColmarChamp",
        "ValenceVictor", "CholetsChamp", "QuimperQuake", "LorientLegend", "ChartresChamp",
        "SoissonsStar", "LavalLion", "EpinalEagle", "DraguignanDragon", "SarcellesShadow",
        "BagneuxBoss", "BoulogneBolt", "PantinProwler", "MontreuillMaster", "ClichyChamp",
        "NanterreNinja", "IvryImpact", "FontenayFlash", "BondyBolt", "AulnayAce",
        "SevranStar", "LivryLion", "StOuenOracle", "GagnyGhost", "RosnyRogue",
        "SartrouvilleStar", "MaisonsAce", "GennevilliersGhost", "CergyChamp", "EvryEagle"
    ]

    static let japanNames = [
        "TokyoTitan", "OsakaOracle", "KyotoKnight", "YokohamYusha", "NagoyaNinja",
        "SapporoSamurai", "KobeKenshi", "FukuokaFighter", "KawasakiKaze", "SaitamaShogun",
        "HiroshimaHero", "SendaiSenshi", "ChibaChampion", "KitakyushuKage", "SakaiShinobi",
        "NiigataNinja", "HamamatsuHawk", "KumamotoKing", "SagamiharaStar", "OkayamaOni",
        "ShizuokaShadow", "KagoshimaKami", "FunabashiFury", "HachiojiHunter", "HimejiHero",
        "MatsuyamaMaster", "NagasakiNinja", "KanazawaKenshi", "UtsunomiyaUltra", "MatsudoMage",
        "NishinomiyaNinja", "IchikawaIkazuchi", "AmagasakiAce", "KashiwaKaze", "ToyamaThunder",
        "NahaNoble", "NagareyamaLegend", "FujisawaFist", "ToyohashiTiger", "MinatoMaster",
        "SuginamSensei", "ItabashiIron", "EdogawaEagle", "AdachiAce", "NerimaNoble",
        "OtaOracle", "KatsushikaKing", "NakanoNinja", "ShinagawaShogun", "ToshimaTitan",
        "MeguroMaster", "ShibuyaShadow", "SetagayaStar", "BunkyoBlade", "KotokuKenshi",
        "SumidaSamurai", "ArakawAce", "TaitoTiger", "ChiyodaChamp", "ChochuChallenger",
        "MachidaMaster", "TamaThunder", "HinoHero", "HachiojiHawk", "KodairaKing",
        "NishitokyStar", "FuchuFighter", "AkishimaAce", "MusashinoMaster", "MitakaMarvel",
        "KoganeiKaze", "TachikawaThunder", "OmOni", "KokubujiKnight", "HigashikurHero",
        "TsukubaThunder", "KasukabeStar", "SokaShogun", "TokorozawaTitan", "KawagoeChampi",
        "KoshigayaKing", "IchinomiyaIron", "OtsuOracle", "AomoriAce", "MoriokaMarvel",
        "AkitaAssassin", "YamagataYusha", "FukushimaFury", "MitoMaster", "TsuchiuraTiger"
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
            case .global:
                entries = globalEntries()
            }
            let day = MockLeaderboardData.daysSinceReference
            let totalPlayers: Int
            switch filter {
            case .hallOfFame:
                totalPlayers = hallOfFameEntries().count
            case .country:
                totalPlayers = MockLeaderboardData.totalPlayers(on: day, isUS: true)
            case .countryUK:
                totalPlayers = 17_676  // UK player count
            case .countryCA:
                totalPlayers = 12_847  // Canada player count
            case .countryAU:
                totalPlayers = 63_213  // Australia player count
            case .countryDE:
                totalPlayers = 76_767  // Germany player count
            case .countryFR:
                totalPlayers = 127_676  // France player count
            case .countryJP:
                totalPlayers = 894  // Japan player count
            case .countryIN:
                totalPlayers = 1_488  // India player count
            case .countryBR:
                totalPlayers = 10_000  // Brazil player count
            case .countryMX:
                totalPlayers = 7_229  // Mexico player count
            case .global:
                // Global = sum of all country players (US + UK + Canada + Australia + Germany + France + Japan + India + Brazil + Mexico)
                totalPlayers = MockLeaderboardData.totalPlayers(on: day, isUS: true) + 17_676 + 12_847 + 63_213 + 76_767 + 127_676 + 894 + 1_488 + 10_000 + 7_229
            }
            return .init(entries: entries, myEntry: entries.last, nextCursor: nil, totalPlayers: totalPlayers)
        },
        fetchMyRank: { _, _ in globalEntries().last }
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

    // Hall of Fame - players who reached ∞, names from US/Global leaderboards
    // Ranks are based on milestone (infinity count) - higher infinity = better rank
    private static func hallOfFameEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // First, build player data with progressed infinity counts
        var playerData: [(originalIndex: Int, progressedCount: Int, name: String, country: String, platform: Platform, avatar: String)] = []

        for (index, baseCount) in MockLeaderboardData.hallOfFameInfinityCounts.enumerated() {
            let source = hallOfFamePlayerSources[index]
            let name: String
            let country: String

            if let sourceIndex = source.sourceIndex {
                if source.isUS {
                    name = MockLeaderboardData.usNames[sourceIndex % MockLeaderboardData.usNames.count]
                    country = "US"
                } else {
                    name = MockLeaderboardData.globalNames[sourceIndex % MockLeaderboardData.globalNames.count]
                    country = MockLeaderboardData.countries[sourceIndex % MockLeaderboardData.countries.count]
                }
            } else {
                name = MockLeaderboardData.hallOfFameNames[index % MockLeaderboardData.hallOfFameNames.count]
                country = ["US", "JP", "KR", "DE", "GB", "FR", "CA", "AU", "BR", "IN"][index % 10]
            }

            // Apply daily infinity progression (0.25-1.5 infinities per day)
            let progressedCount = MockLeaderboardData.infinityCountWithProgression(baseCount: baseCount, playerIndex: index, day: day)

            let platform: Platform = index % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[index % MockLeaderboardData.avatarIDs.count]

            playerData.append((index, progressedCount, name, country, platform, avatar))
        }

        // Sort by progressed infinity count (highest first)
        playerData.sort { $0.progressedCount > $1.progressedCount }

        // Build entries with ranks based on sorted order
        var entries: [LeaderboardEntry] = []
        for (rank, player) in playerData.enumerated() {
            let score = MockLeaderboardData.scoreForMilestone("\(player.progressedCount)∞")

            entries.append(LeaderboardEntry(
                id: "hof_\(player.originalIndex)",
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: player.country,
                platform: player.platform,
                avatarURL: player.avatar,
                highestTile: "\(player.progressedCount)∞"
            ))
        }

        return entries
    }

    // Exact US player milestones from screenshots (ranks 1-256+)
    private static let usPlayerMilestones: [String] = [
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
    private static let ukPlayerMilestones: [String] = [
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
        // Ranks 121-150 (from screenshot)
        "8a", "4a", "4a", "2a", "2a", "1a", "549B", "274B", "137B", "68B",
        "68B", "34B", "17B", "8B", "2B", "1B", "1B", "536M", "536M", "268M",
        "268M", "268M", "134M", "134M", "134M", "134M", "134M", "67M", "67M", "67M"
    ]

    // Canada player milestones from screenshots (ranks 1-150)
    private static let canadaPlayerMilestones: [String] = [
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
        // Ranks 121-150
        "562a", "140a", "35a", "8a", "2a", "549B", "137B", "34B", "8B", "2B",
        "536M", "134M", "33M", "8M", "2M", "524K", "131K", "32K", "8K", "2K",
        "8192", "2048", "512", "128", "32", "16", "8", "4", "2", "2"
    ]

    // Extended Canada milestone brackets for rank calculation (ranks 151+)
    // Total Canada players: ~12,847
    private static let canadaExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
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
    private static let australiaPlayerMilestones: [String] = [
        // Ranks 1-30 (from screenshot)
        "13bz", "794bv", "2br", "657bn", "1bm", "9bk", "556bg", "278bg", "69bg", "989bb",
        "463ay", "3a", "409at", "48ar", "46ap", "88an", "676al", "1al", "10aj", "2ah",
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
        // Ranks 121-150 (from screenshot)
        "1a", "274B", "137B", "137B", "68B", "34B", "34B", "34B", "17B", "17B",
        "8B", "8B", "8B", "8B", "4B", "4B", "4B", "2B", "2B", "1B",
        "1B", "1B", "1B", "1B", "1B", "1B", "1B", "1B", "1B", "1B"
    ]

    // Extended Australia milestone brackets for rank calculation (ranks 151+)
    // Total Australia players: ~63,213
    private static let australiaExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
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
    private static let germanyPlayerMilestones: [String] = [
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
        // Ranks 121-150
        "1d", "1d", "1d", "1d", "590c", "590c", "590c", "590c", "590c", "590c",
        "295c", "295c", "295c", "295c", "295c", "295c", "147c", "147c", "147c", "147c",
        "147c", "147c", "73c", "73c", "73c", "73c", "73c", "73c", "73c", "36c"
    ]

    // Extended Germany milestone brackets for rank calculation (ranks 151+)
    // Total Germany players: ~76,767
    private static let germanyExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
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
    private static let francePlayerMilestones: [String] = [
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
        // Ranks 121-150
        "2i", "2i", "2i", "2i", "2i", "2i", "2i", "1i", "1i", "1i",
        "1i", "1i", "1i", "1i", "1i", "1i", "1i", "1i", "1i", "1i",
        "1i", "664h", "664h", "664h", "664h", "664h", "664h", "664h", "664h", "664h"
    ]

    // Extended France milestone brackets for rank calculation (ranks 151+)
    // Total France players: ~127,676
    private static let franceExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
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
    private static let japanPlayerMilestones: [String] = [
        // Ranks 1-30
        "436bz", "134by", "667bx", "333bw", "166bv", "83bu", "41bt", "20bs", "10br", "5bq",
        "2bp", "1bo", "512bn", "256bm", "128bl", "64bk", "32bj", "16bi", "8bh", "4bg",
        "2bf", "1be", "500bd", "250bc", "125bb", "62ba", "31az", "15ay", "7ax", "3aw",
        // Ranks 31-60
        "1av", "488au", "244at", "122as", "61ar", "30aq", "15ap", "7ao", "3an", "1am",
        "476al", "238ak", "119aj", "59ai", "29ah", "14ag", "7af", "3ae", "1ad", "464ac",
        "232ab", "116aa", "58z", "29y", "14x", "7w", "3v", "1u", "452t", "226s",
        // Ranks 61-90
        "113r", "56q", "28p", "14o", "7n", "3m", "1l", "440k", "220j", "110i",
        "55h", "27g", "13f", "6e", "3d", "1c", "428b", "214a", "107B", "53M",
        "26K", "13K", "6K", "3K", "1K", "416K", "208K", "104K", "52K", "26K",
        // Ranks 91-120
        "13K", "6K", "3K", "1K", "404K", "202K", "101K", "50K", "25K", "12K",
        "6K", "3K", "1K", "392K", "196K", "98K", "49K", "24K", "12K", "6K",
        "3K", "1K", "380K", "190K", "95K", "47K", "23K", "11K", "5K", "2K",
        // Ranks 121-150
        "1K", "368K", "184K", "92K", "46K", "23K", "11K", "5K", "2K", "1K",
        "356K", "178K", "89K", "44K", "22K", "11K", "5K", "2K", "1K", "344K",
        "172K", "86K", "43K", "21K", "10K", "5K", "2K", "1K", "332K", "32K"
    ]

    // Extended Japan milestone brackets for rank calculation (ranks 151+)
    // Total Japan players: ~894
    private static let japanExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // K-tier brackets (ranks 151-311)
        ("32K", 150), ("16K", 161), ("8K", 175), ("4K", 187), ("2K", 205),
        ("1K", 223), ("512K", 241), ("256K", 260), ("128K", 278), ("64K", 295),
        ("32K", 311),
        // Lower K-tier and raw number brackets (ranks 312-787)
        ("16K", 333), ("8192", 361), ("4096", 392), ("2048", 434), ("1024", 476),
        ("512", 521), ("256", 567), ("128", 612), ("64", 656), ("32", 701),
        ("16", 733), ("8", 756), ("4", 771), ("2", 781), ("1", 787),
        // Score 0 bracket (ranks 788-894)
        ("0", 788)
    ]

    // India player milestones (ranks 1-150)
    private static let indiaPlayerMilestones: [String] = [
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
    private static let indiaExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // Raw number brackets (ranks 151-1210)
        ("8192", 151), ("4096", 162), ("2048", 171), ("1024", 180), ("512", 196),
        ("256", 222), ("128", 258), ("64", 300), ("32", 377), ("16", 512),
        ("8", 666), ("4", 835), ("2", 1033),
        // Score 0 bracket (ranks 1211-1488)
        ("0", 1211)
    ]

    // Brazil player milestones (ranks 1-150)
    private static let brazilPlayerMilestones: [String] = [
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
    private static let brazilExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
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
    private static let mexicoPlayerMilestones: [String] = [
        // Ranks 1-30
        "97bu", "1bu", "2bs", "5bn", "10bm", "615bk", "285bh", "1bf", "64bd", "235az",
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
    private static let mexicoExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
        // K-tier brackets
        ("524K", 150), ("262K", 161), ("131K", 173), ("65K", 186), ("32K", 203), ("16K", 226),
        // Raw number brackets
        ("8192", 264), ("4096", 322), ("2048", 402), ("1024", 488), ("512", 574),
        ("256", 688), ("128", 822), ("64", 1000), ("32", 1175), ("16", 1558),
        ("8", 2222), ("4", 3377), ("2", 4444),
        // Score 0 bracket (ranks 5783-7229)
        ("0", 5783)
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
    private static let usExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
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
    private static let ukExtendedRankBrackets: [(milestone: String, startRank: Int)] = [
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

    // Global leaderboard - combines all country leaderboards (US + UK + more to come)
    // Ranks are based on milestone - higher milestone = better rank
    private static func globalEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // Combine players from all countries
        var playerData: [(originalIndex: Int, playerIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, country: String, platform: Platform, avatar: String, id: String)] = []

        // Add US players
        for i in 0..<min(150, usPlayerMilestones.count) {
            let baseMilestone = usPlayerMilestones[i]
            let name = MockLeaderboardData.usNames[i % MockLeaderboardData.usNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[i % MockLeaderboardData.avatarIDs.count]

            // US milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, i, baseMilestone, milestoneIdx, name, "US", platform, avatar, "us_\(i)"))
        }

        // Add UK players
        for i in 0..<min(150, ukPlayerMilestones.count) {
            let baseMilestone = ukPlayerMilestones[i]
            let name = MockLeaderboardData.ukNames[i % MockLeaderboardData.ukNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[(i + 6) % MockLeaderboardData.avatarIDs.count]  // Offset for variety

            // UK milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, i + 5000, baseMilestone, milestoneIdx, name, "GB", platform, avatar, "uk_\(i)"))
        }

        // Add Canada players
        for i in 0..<min(150, canadaPlayerMilestones.count) {
            let baseMilestone = canadaPlayerMilestones[i]
            let name = MockLeaderboardData.canadaNames[i % MockLeaderboardData.canadaNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[(i + 12) % MockLeaderboardData.avatarIDs.count]  // Offset for variety

            // Canada milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, i + 10000, baseMilestone, milestoneIdx, name, "CA", platform, avatar, "ca_\(i)"))
        }

        // Add Australia players
        for i in 0..<min(150, australiaPlayerMilestones.count) {
            let baseMilestone = australiaPlayerMilestones[i]
            let name = MockLeaderboardData.australiaNames[i % MockLeaderboardData.australiaNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[(i + 18) % MockLeaderboardData.avatarIDs.count]  // Offset for variety

            // Australia milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, i + 15000, baseMilestone, milestoneIdx, name, "AU", platform, avatar, "au_\(i)"))
        }

        // Add Germany players
        for i in 0..<min(150, germanyPlayerMilestones.count) {
            let baseMilestone = germanyPlayerMilestones[i]
            let name = MockLeaderboardData.germanyNames[i % MockLeaderboardData.germanyNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[(i + 24) % MockLeaderboardData.avatarIDs.count]  // Offset for variety

            // Germany milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, i + 20000, baseMilestone, milestoneIdx, name, "DE", platform, avatar, "de_\(i)"))
        }

        // Add France players
        for i in 0..<min(150, francePlayerMilestones.count) {
            let baseMilestone = francePlayerMilestones[i]
            let name = MockLeaderboardData.franceNames[i % MockLeaderboardData.franceNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[(i + 30) % MockLeaderboardData.avatarIDs.count]  // Offset for variety

            // France milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, i + 25000, baseMilestone, milestoneIdx, name, "FR", platform, avatar, "fr_\(i)"))
        }

        // Add Japan players
        for i in 0..<min(150, japanPlayerMilestones.count) {
            let baseMilestone = japanPlayerMilestones[i]
            let name = MockLeaderboardData.japanNames[i % MockLeaderboardData.japanNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[(i + 36) % MockLeaderboardData.avatarIDs.count]  // Offset for variety

            // Japan milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, i + 30000, baseMilestone, milestoneIdx, name, "JP", platform, avatar, "jp_\(i)"))
        }

        // Add India players
        for i in 0..<min(150, indiaPlayerMilestones.count) {
            let baseMilestone = indiaPlayerMilestones[i]
            let name = MockLeaderboardData.indiaNames[i % MockLeaderboardData.indiaNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[(i + 42) % MockLeaderboardData.avatarIDs.count]  // Offset for variety

            // India milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, i + 35000, baseMilestone, milestoneIdx, name, "IN", platform, avatar, "in_\(i)"))
        }

        // Add Brazil players
        for i in 0..<min(150, brazilPlayerMilestones.count) {
            let baseMilestone = brazilPlayerMilestones[i]
            let name = MockLeaderboardData.brazilNames[i % MockLeaderboardData.brazilNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[(i + 48) % MockLeaderboardData.avatarIDs.count]  // Offset for variety

            // Brazil milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, i + 40000, baseMilestone, milestoneIdx, name, "BR", platform, avatar, "br_\(i)"))
        }

        // Add Mexico players
        for i in 0..<min(150, mexicoPlayerMilestones.count) {
            let baseMilestone = mexicoPlayerMilestones[i]
            let name = MockLeaderboardData.mexicoNames[i % MockLeaderboardData.mexicoNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[(i + 54) % MockLeaderboardData.avatarIDs.count]  // Offset for variety

            // Mexico milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, i + 45000, baseMilestone, milestoneIdx, name, "MX", platform, avatar, "mx_\(i)"))
        }

        // Sort by milestone index (highest first = best milestone)
        playerData.sort { $0.milestoneIdx > $1.milestoneIdx }

        // Build entries with ranks based on sorted order (top 150 only)
        var entries: [LeaderboardEntry] = []
        for (rank, player) in playerData.prefix(150).enumerated() {
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.playerIndex, day: day)

            entries.append(LeaderboardEntry(
                id: player.id,
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: player.country,
                platform: player.platform,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // Add current user entry
        // Total global players = sum of all country players (US + UK + Canada + Australia + Germany + France)
        let userMilestone = UserLeaderboardData.currentMilestone
        let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
        let userMilestoneIndex = MockLeaderboardData.milestoneIndex(for: userMilestone)
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
        let totalPlayers = totalUSPlayers + totalUKPlayers + totalCanadaPlayers + totalAustraliaPlayers + totalGermanyPlayers + totalFrancePlayers + totalJapanPlayers + totalIndiaPlayers + totalBrazilPlayers + totalMexicoPlayers

        // Find user's rank based on milestone compared to sorted players
        var globalRank = totalPlayers

        // Check if user would be in top 150 based on milestone
        if let lastTop150 = playerData.last {
            if userMilestoneIndex > lastTop150.milestoneIdx {
                // User's milestone is better than some in top 150, find exact position
                for (rank, player) in playerData.enumerated() {
                    if userMilestoneIndex >= player.milestoneIdx {
                        globalRank = rank + 1
                        break
                    }
                }
            } else {
                // User is below top 150 - use bracket-based ranking
                for bracket in globalExtendedRankBrackets {
                    if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                       userMilestoneIndex >= bracketIndex {
                        globalRank = bracket.startRank
                        break
                    }
                }
            }
        }

        entries.append(LeaderboardEntry(
            id: "me",
            rank: globalRank,
            name: UserLeaderboardData.playerName,
            score: userScore,
            countryCode: "US",
            platform: .ios,
            isMe: true,
            avatarURL: UserLeaderboardData.avatarID,
            highestTile: userMilestone
        ))

        return entries
    }

    // Country (US) leaderboard - shows only US players with exact milestones from screenshots
    // Ranks are based on milestone - higher milestone = better rank
    private static func countryEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // First, build player data with milestones
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String)] = []

        for i in 0..<150 {  // Only show top 150 in leaderboard
            let baseMilestone = usPlayerMilestones[i]
            let name = MockLeaderboardData.usNames[i % MockLeaderboardData.usNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[i % MockLeaderboardData.avatarIDs.count]

            // US milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar))
        }

        // Sort by milestone index (highest first = best milestone)
        playerData.sort { $0.milestoneIdx > $1.milestoneIdx }

        // Build entries with ranks based on sorted order
        var entries: [LeaderboardEntry] = []
        for (rank, player) in playerData.enumerated() {
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex, day: day)

            entries.append(LeaderboardEntry(
                id: "us_\(player.originalIndex)",
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "US",
                platform: player.platform,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // Add current user entry (ranked among 100k+ US players)
        let userMilestone = UserLeaderboardData.currentMilestone
        let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
        let userMilestoneIndex = MockLeaderboardData.milestoneIndex(for: userMilestone)
        let totalUSPlayers = MockLeaderboardData.totalPlayers(on: day, isUS: true)

        // Find user's rank based on milestone compared to sorted players
        var usRank = totalUSPlayers

        // Check if user would be in top 150 based on milestone
        if let lastTop150 = playerData.last {
            if userMilestoneIndex > lastTop150.milestoneIdx {
                // User's milestone is better than some in top 150, find exact position
                for (rank, player) in playerData.enumerated() {
                    if userMilestoneIndex >= player.milestoneIdx {
                        usRank = rank + 1
                        break
                    }
                }
            } else {
                // User is below top 150 - use bracket-based ranking
                // Iterate forward (high tier to low tier) to find best matching bracket
                for bracket in usExtendedRankBrackets {
                    if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                       userMilestoneIndex >= bracketIndex {
                        usRank = bracket.startRank
                        break
                    }
                }
            }
        }

        entries.append(LeaderboardEntry(
            id: "me",
            rank: usRank,
            name: UserLeaderboardData.playerName,
            score: userScore,
            countryCode: "US",
            platform: .ios,
            isMe: true,
            avatarURL: UserLeaderboardData.avatarID,
            highestTile: userMilestone
        ))

        return entries
    }

    // UK leaderboard - shows only UK players with milestones
    // Ranks are based on milestone - higher milestone = better rank
    private static func ukEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // First, build player data with progressed milestones
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String)] = []

        for i in 0..<min(150, ukPlayerMilestones.count) {
            let baseMilestone = ukPlayerMilestones[i]
            let name = MockLeaderboardData.ukNames[i % MockLeaderboardData.ukNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[i % MockLeaderboardData.avatarIDs.count]

            // UK milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar))
        }

        // Sort by milestone index (highest first = best milestone)
        playerData.sort { $0.milestoneIdx > $1.milestoneIdx }

        // Build entries with ranks based on sorted order
        var entries: [LeaderboardEntry] = []
        for (rank, player) in playerData.enumerated() {
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 5000, day: day)

            entries.append(LeaderboardEntry(
                id: "uk_\(player.originalIndex)",
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "GB",
                platform: player.platform,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // Add current user entry
        let userMilestone = UserLeaderboardData.currentMilestone
        let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
        let userMilestoneIndex = MockLeaderboardData.milestoneIndex(for: userMilestone)
        let totalUKPlayers = 17_676  // UK player count

        // Find user's rank based on milestone compared to sorted players
        var ukRank = totalUKPlayers

        // Check if user would be in top 150 based on milestone
        if let lastTop150 = playerData.last {
            if userMilestoneIndex > lastTop150.milestoneIdx {
                // User's milestone is better than some in top 150, find exact position
                for (rank, player) in playerData.enumerated() {
                    if userMilestoneIndex >= player.milestoneIdx {
                        ukRank = rank + 1
                        break
                    }
                }
            } else {
                // User is below top 150 - use bracket-based ranking
                for bracket in ukExtendedRankBrackets {
                    if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                       userMilestoneIndex >= bracketIndex {
                        ukRank = bracket.startRank
                        break
                    }
                }
            }
        }

        entries.append(LeaderboardEntry(
            id: "me",
            rank: ukRank,
            name: UserLeaderboardData.playerName,
            score: userScore,
            countryCode: "GB",
            platform: .ios,
            isMe: true,
            avatarURL: UserLeaderboardData.avatarID,
            highestTile: userMilestone
        ))

        return entries
    }

    // Canada leaderboard - shows top 150 Canadian players
    private static func canadaEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // First, build player data with milestones
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String)] = []

        for i in 0..<min(150, canadaPlayerMilestones.count) {
            let baseMilestone = canadaPlayerMilestones[i]
            let name = MockLeaderboardData.canadaNames[i % MockLeaderboardData.canadaNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[i % MockLeaderboardData.avatarIDs.count]

            // Canada milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar))
        }

        // Sort by milestone index (highest first = best milestone)
        playerData.sort { $0.milestoneIdx > $1.milestoneIdx }

        // Build entries with ranks based on sorted order
        var entries: [LeaderboardEntry] = []
        for (rank, player) in playerData.enumerated() {
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 10000, day: day)

            entries.append(LeaderboardEntry(
                id: "ca_\(player.originalIndex)",
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "CA",
                platform: player.platform,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // Add current user entry
        let userMilestone = UserLeaderboardData.currentMilestone
        let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
        let userMilestoneIndex = MockLeaderboardData.milestoneIndex(for: userMilestone)
        let totalCanadaPlayers = 12_847  // Canada player count

        // Find user's rank based on milestone compared to sorted players
        var canadaRank = totalCanadaPlayers

        // Check if user would be in top 150 based on milestone
        if let lastTop150 = playerData.last {
            if userMilestoneIndex > lastTop150.milestoneIdx {
                // User's milestone is better than some in top 150, find exact position
                for (rank, player) in playerData.enumerated() {
                    if userMilestoneIndex >= player.milestoneIdx {
                        canadaRank = rank + 1
                        break
                    }
                }
            } else {
                // User is below top 150 - use bracket-based ranking
                for bracket in canadaExtendedRankBrackets {
                    if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                       userMilestoneIndex >= bracketIndex {
                        canadaRank = bracket.startRank
                        break
                    }
                }
            }
        }

        entries.append(LeaderboardEntry(
            id: "me",
            rank: canadaRank,
            name: UserLeaderboardData.playerName,
            score: userScore,
            countryCode: "CA",
            platform: .ios,
            isMe: true,
            avatarURL: UserLeaderboardData.avatarID,
            highestTile: userMilestone
        ))

        return entries
    }

    // Australia leaderboard - shows top 150 Australian players
    private static func australiaEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // First, build player data with milestones
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String)] = []

        for i in 0..<min(150, australiaPlayerMilestones.count) {
            let baseMilestone = australiaPlayerMilestones[i]
            let name = MockLeaderboardData.australiaNames[i % MockLeaderboardData.australiaNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[i % MockLeaderboardData.avatarIDs.count]

            // Australia milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar))
        }

        // Sort by milestone index (highest first = best milestone)
        playerData.sort { $0.milestoneIdx > $1.milestoneIdx }

        // Build entries with ranks based on sorted order
        var entries: [LeaderboardEntry] = []
        for (rank, player) in playerData.enumerated() {
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 15000, day: day)

            entries.append(LeaderboardEntry(
                id: "au_\(player.originalIndex)",
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "AU",
                platform: player.platform,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // Add current user entry
        let userMilestone = UserLeaderboardData.currentMilestone
        let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
        let userMilestoneIndex = MockLeaderboardData.milestoneIndex(for: userMilestone)
        let totalAustraliaPlayers = 63_213  // Australia player count

        // Find user's rank based on milestone compared to sorted players
        var australiaRank = totalAustraliaPlayers

        // Check if user would be in top 150 based on milestone
        if let lastTop150 = playerData.last {
            if userMilestoneIndex > lastTop150.milestoneIdx {
                // User's milestone is better than some in top 150, find exact position
                for (rank, player) in playerData.enumerated() {
                    if userMilestoneIndex >= player.milestoneIdx {
                        australiaRank = rank + 1
                        break
                    }
                }
            } else {
                // User is below top 150 - use bracket-based ranking
                for bracket in australiaExtendedRankBrackets {
                    if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                       userMilestoneIndex >= bracketIndex {
                        australiaRank = bracket.startRank
                        break
                    }
                }
            }
        }

        entries.append(LeaderboardEntry(
            id: "me",
            rank: australiaRank,
            name: UserLeaderboardData.playerName,
            score: userScore,
            countryCode: "AU",
            platform: .ios,
            isMe: true,
            avatarURL: UserLeaderboardData.avatarID,
            highestTile: userMilestone
        ))

        return entries
    }

    // Germany leaderboard - shows only German players with exact milestones
    private static func germanyEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // First, build player data with milestones
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String)] = []

        for i in 0..<min(150, germanyPlayerMilestones.count) {
            let baseMilestone = germanyPlayerMilestones[i]
            let name = MockLeaderboardData.germanyNames[i % MockLeaderboardData.germanyNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[i % MockLeaderboardData.avatarIDs.count]

            // Germany milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar))
        }

        // Sort by milestone index (highest first = best milestone)
        playerData.sort { $0.milestoneIdx > $1.milestoneIdx }

        // Build entries with ranks based on sorted order
        var entries: [LeaderboardEntry] = []
        for (rank, player) in playerData.enumerated() {
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 20000, day: day)

            entries.append(LeaderboardEntry(
                id: "de_\(player.originalIndex)",
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "DE",
                platform: player.platform,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // Add current user entry
        let userMilestone = UserLeaderboardData.currentMilestone
        let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
        let userMilestoneIndex = MockLeaderboardData.milestoneIndex(for: userMilestone)
        let totalGermanyPlayers = 76_767  // Germany player count

        // Find user's rank based on milestone compared to sorted players
        var germanyRank = totalGermanyPlayers

        // Check if user would be in top 150 based on milestone
        if let lastTop150 = playerData.last {
            if userMilestoneIndex > lastTop150.milestoneIdx {
                // User's milestone is better than some in top 150, find exact position
                for (rank, player) in playerData.enumerated() {
                    if userMilestoneIndex >= player.milestoneIdx {
                        germanyRank = rank + 1
                        break
                    }
                }
            } else {
                // User is below top 150 - use bracket-based ranking
                for bracket in germanyExtendedRankBrackets {
                    if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                       userMilestoneIndex >= bracketIndex {
                        germanyRank = bracket.startRank
                        break
                    }
                }
            }
        }

        entries.append(LeaderboardEntry(
            id: "me",
            rank: germanyRank,
            name: UserLeaderboardData.playerName,
            score: userScore,
            countryCode: "DE",
            platform: .ios,
            isMe: true,
            avatarURL: UserLeaderboardData.avatarID,
            highestTile: userMilestone
        ))

        return entries
    }

    // France leaderboard - shows only French players with exact milestones
    private static func franceEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // First, build player data with milestones
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String)] = []

        for i in 0..<min(150, francePlayerMilestones.count) {
            let baseMilestone = francePlayerMilestones[i]
            let name = MockLeaderboardData.franceNames[i % MockLeaderboardData.franceNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[i % MockLeaderboardData.avatarIDs.count]

            // France milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar))
        }

        // Sort by milestone index (highest first = best milestone)
        playerData.sort { $0.milestoneIdx > $1.milestoneIdx }

        // Build entries with ranks based on sorted order
        var entries: [LeaderboardEntry] = []
        for (rank, player) in playerData.enumerated() {
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 25000, day: day)

            entries.append(LeaderboardEntry(
                id: "fr_\(player.originalIndex)",
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "FR",
                platform: player.platform,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // Add current user entry
        let userMilestone = UserLeaderboardData.currentMilestone
        let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
        let userMilestoneIndex = MockLeaderboardData.milestoneIndex(for: userMilestone)
        let totalFrancePlayers = 127_676  // France player count

        // Find user's rank based on milestone compared to sorted players
        var franceRank = totalFrancePlayers

        // Check if user would be in top 150 based on milestone
        if let lastTop150 = playerData.last {
            if userMilestoneIndex > lastTop150.milestoneIdx {
                // User's milestone is better than some in top 150, find exact position
                for (rank, player) in playerData.enumerated() {
                    if userMilestoneIndex >= player.milestoneIdx {
                        franceRank = rank + 1
                        break
                    }
                }
            } else {
                // User is below top 150 - use bracket-based ranking
                for bracket in franceExtendedRankBrackets {
                    if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                       userMilestoneIndex >= bracketIndex {
                        franceRank = bracket.startRank
                        break
                    }
                }
            }
        }

        entries.append(LeaderboardEntry(
            id: "me",
            rank: franceRank,
            name: UserLeaderboardData.playerName,
            score: userScore,
            countryCode: "FR",
            platform: .ios,
            isMe: true,
            avatarURL: UserLeaderboardData.avatarID,
            highestTile: userMilestone
        ))

        return entries
    }

    // Japan leaderboard - shows only Japanese players with exact milestones
    private static func japanEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // First, build player data with milestones
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String)] = []

        for i in 0..<min(150, japanPlayerMilestones.count) {
            let baseMilestone = japanPlayerMilestones[i]
            let name = MockLeaderboardData.japanNames[i % MockLeaderboardData.japanNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[i % MockLeaderboardData.avatarIDs.count]

            // Japan milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar))
        }

        // Sort by milestone index (highest first = best milestone)
        playerData.sort { $0.milestoneIdx > $1.milestoneIdx }

        // Build entries with ranks based on sorted order
        var entries: [LeaderboardEntry] = []
        for (rank, player) in playerData.enumerated() {
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 30000, day: day)

            entries.append(LeaderboardEntry(
                id: "jp_\(player.originalIndex)",
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "JP",
                platform: player.platform,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // Add current user entry
        let userMilestone = UserLeaderboardData.currentMilestone
        let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
        let userMilestoneIndex = MockLeaderboardData.milestoneIndex(for: userMilestone)
        let totalJapanPlayers = 894  // Japan player count

        // Find user's rank based on milestone compared to sorted players
        var japanRank = totalJapanPlayers

        // Check if user would be in top 150 based on milestone
        if let lastTop150 = playerData.last {
            if userMilestoneIndex > lastTop150.milestoneIdx {
                // User's milestone is better than some in top 150, find exact position
                for (rank, player) in playerData.enumerated() {
                    if userMilestoneIndex >= player.milestoneIdx {
                        japanRank = rank + 1
                        break
                    }
                }
            } else {
                // User is below top 150 - use bracket-based ranking
                for bracket in japanExtendedRankBrackets {
                    if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                       userMilestoneIndex >= bracketIndex {
                        japanRank = bracket.startRank
                        break
                    }
                }
            }
        }

        entries.append(LeaderboardEntry(
            id: "me",
            rank: japanRank,
            name: UserLeaderboardData.playerName,
            score: userScore,
            countryCode: "JP",
            platform: .ios,
            isMe: true,
            avatarURL: UserLeaderboardData.avatarID,
            highestTile: userMilestone
        ))

        return entries
    }

    // India leaderboard - shows only Indian players with exact milestones
    private static func indiaEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // First, build player data with milestones
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String)] = []

        for i in 0..<min(150, indiaPlayerMilestones.count) {
            let baseMilestone = indiaPlayerMilestones[i]
            let name = MockLeaderboardData.indiaNames[i % MockLeaderboardData.indiaNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[i % MockLeaderboardData.avatarIDs.count]

            // India milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar))
        }

        // Sort by milestone index (highest first = best milestone)
        playerData.sort { $0.milestoneIdx > $1.milestoneIdx }

        // Build entries with ranks based on sorted order
        var entries: [LeaderboardEntry] = []
        for (rank, player) in playerData.enumerated() {
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 35000, day: day)

            entries.append(LeaderboardEntry(
                id: "in_\(player.originalIndex)",
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "IN",
                platform: player.platform,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // Add current user entry
        let userMilestone = UserLeaderboardData.currentMilestone
        let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
        let userMilestoneIndex = MockLeaderboardData.milestoneIndex(for: userMilestone)
        let totalIndiaPlayers = 1_488  // India player count

        // Find user's rank based on milestone compared to sorted players
        var indiaRank = totalIndiaPlayers

        // Check if user would be in top 150 based on milestone
        if let lastTop150 = playerData.last {
            if userMilestoneIndex > lastTop150.milestoneIdx {
                // User's milestone is better than some in top 150, find exact position
                for (rank, player) in playerData.enumerated() {
                    if userMilestoneIndex >= player.milestoneIdx {
                        indiaRank = rank + 1
                        break
                    }
                }
            } else {
                // User is below top 150 - use bracket-based ranking
                for bracket in indiaExtendedRankBrackets {
                    if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                       userMilestoneIndex >= bracketIndex {
                        indiaRank = bracket.startRank
                        break
                    }
                }
            }
        }

        entries.append(LeaderboardEntry(
            id: "me",
            rank: indiaRank,
            name: UserLeaderboardData.playerName,
            score: userScore,
            countryCode: "IN",
            platform: .ios,
            isMe: true,
            avatarURL: UserLeaderboardData.avatarID,
            highestTile: userMilestone
        ))

        return entries
    }

    // Brazil leaderboard - shows only Brazilian players with exact milestones
    private static func brazilEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // First, build player data with milestones
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String)] = []

        for i in 0..<min(150, brazilPlayerMilestones.count) {
            let baseMilestone = brazilPlayerMilestones[i]
            let name = MockLeaderboardData.brazilNames[i % MockLeaderboardData.brazilNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[i % MockLeaderboardData.avatarIDs.count]

            // Brazil milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar))
        }

        // Sort by milestone index (highest first = best milestone)
        playerData.sort { $0.milestoneIdx > $1.milestoneIdx }

        // Build entries with ranks based on sorted order
        var entries: [LeaderboardEntry] = []
        for (rank, player) in playerData.enumerated() {
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 40000, day: day)

            entries.append(LeaderboardEntry(
                id: "br_\(player.originalIndex)",
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "BR",
                platform: player.platform,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // Add current user entry
        let userMilestone = UserLeaderboardData.currentMilestone
        let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
        let userMilestoneIndex = MockLeaderboardData.milestoneIndex(for: userMilestone)
        let totalBrazilPlayers = 10_000  // Brazil player count

        // Find user's rank based on milestone compared to sorted players
        var brazilRank = totalBrazilPlayers

        // Check if user would be in top 150 based on milestone
        if let lastTop150 = playerData.last {
            if userMilestoneIndex > lastTop150.milestoneIdx {
                // User's milestone is better than some in top 150, find exact position
                for (rank, player) in playerData.enumerated() {
                    if userMilestoneIndex >= player.milestoneIdx {
                        brazilRank = rank + 1
                        break
                    }
                }
            } else {
                // User is below top 150 - use bracket-based ranking
                for bracket in brazilExtendedRankBrackets {
                    if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                       userMilestoneIndex >= bracketIndex {
                        brazilRank = bracket.startRank
                        break
                    }
                }
            }
        }

        entries.append(LeaderboardEntry(
            id: "me",
            rank: brazilRank,
            name: UserLeaderboardData.playerName,
            score: userScore,
            countryCode: "BR",
            platform: .ios,
            isMe: true,
            avatarURL: UserLeaderboardData.avatarID,
            highestTile: userMilestone
        ))

        return entries
    }

    // Mexico leaderboard - shows only Mexican players with exact milestones
    // Ranks are based on milestone - higher milestone = better rank
    private static func mexicoEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference

        // First, build player data with milestones
        var playerData: [(originalIndex: Int, progressedMilestone: String, milestoneIdx: Int, name: String, platform: Platform, avatar: String)] = []

        for i in 0..<min(150, mexicoPlayerMilestones.count) {
            let baseMilestone = mexicoPlayerMilestones[i]
            let name = MockLeaderboardData.mexicoNames[i % MockLeaderboardData.mexicoNames.count]
            let platform: Platform = i % 2 == 0 ? .ios : .android
            let avatar = MockLeaderboardData.avatarIDs[(i + 54) % MockLeaderboardData.avatarIDs.count]  // Offset for variety

            // Mexico milestones are already current values - don't apply progression
            let milestoneIdx = MockLeaderboardData.milestoneIndex(for: baseMilestone)

            playerData.append((i, baseMilestone, milestoneIdx, name, platform, avatar))
        }

        // Sort by milestone index (descending - higher milestone = better rank)
        playerData.sort { $0.milestoneIdx > $1.milestoneIdx }

        // Build entries with ranks based on sorted order
        var entries: [LeaderboardEntry] = []
        for (rank, player) in playerData.enumerated() {
            let baseScore = MockLeaderboardData.scoreForMilestone(player.progressedMilestone)
            let score = MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.originalIndex + 45000, day: day)

            entries.append(LeaderboardEntry(
                id: "mx_\(player.originalIndex)",
                rank: rank + 1,
                name: player.name,
                score: score,
                countryCode: "MX",
                platform: player.platform,
                isMe: false,
                avatarURL: player.avatar,
                highestTile: player.progressedMilestone
            ))
        }

        // Add current user entry
        let userMilestone = UserLeaderboardData.currentMilestone
        let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)
        let userMilestoneIndex = MockLeaderboardData.milestoneIndex(for: userMilestone)
        let totalMexicoPlayers = 7_229  // Mexico player count

        // Find user's rank based on milestone compared to sorted players
        var mexicoRank = totalMexicoPlayers

        // Check if user would be in top 150 based on milestone
        if let lastTop150 = playerData.last {
            if userMilestoneIndex > lastTop150.milestoneIdx {
                // User's milestone is better than some in top 150, find exact position
                for (rank, player) in playerData.enumerated() {
                    if userMilestoneIndex >= player.milestoneIdx {
                        mexicoRank = rank + 1
                        break
                    }
                }
            } else {
                // User is below top 150 - use bracket-based ranking
                for bracket in mexicoExtendedRankBrackets {
                    if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                       userMilestoneIndex >= bracketIndex {
                        mexicoRank = bracket.startRank
                        break
                    }
                }
            }
        }

        entries.append(LeaderboardEntry(
            id: "me",
            rank: mexicoRank,
            name: UserLeaderboardData.playerName,
            score: userScore,
            countryCode: "MX",
            platform: .ios,
            isMe: true,
            avatarURL: UserLeaderboardData.avatarID,
            highestTile: userMilestone
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

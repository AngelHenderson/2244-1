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
        "3at", "6at", "12at", "25at", "51at", "102at", "204at", "409at", "818at", "1au"
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

    // Calculate score with daily progression for a player
    // - Players with score 0: add 2 per day
    // - Other players: multiply by 1.01x-1.5x per day
    static func scoreWithDailyProgression(baseScore: Int, playerIndex: Int, day: Int) -> Int {
        if baseScore == 0 {
            // New players (score 0) gain 2 points per day
            return day * 2
        } else {
            // Other players get 1.01x-1.5x multiplier per day
            // Use seeded random for consistent daily results per player
            let dailyMultiplier = 1.01 + seededRandom(seed: playerIndex * 777, index: day) * 0.49  // 1.01 to 1.5
            // Apply multiplier cumulatively but cap to prevent overflow
            // Use log scale for many days
            let effectiveDays = min(day, 365)  // Cap at 1 year of progression
            let totalMultiplier = pow(dailyMultiplier, Double(effectiveDays) * 0.01)  // Slower growth
            let newScore = Double(baseScore) * totalMultiplier
            return min(Int(newScore), Int.max / 2)  // Prevent overflow
        }
    }

    // Avatar IDs from AvatarCatalog (12 options, cycled for all players)
    static let avatarIDs = [
        "avatar-shiba-dog", "avatar-astronaut-cat", "avatar-robot-green", "avatar-phoenix-fire",
        "avatar-shark-teeth", "avatar-paper-plane", "avatar-baseball-cap", "avatar-warrior-samurai",
        "avatar-burger-food", "avatar-chicken-bird", "avatar-anchor-nautical", "avatar-bear-grizzly"
    ]

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
                totalPlayers = 84_721  // US players
            case .global:
                totalPlayers = 885_676  // ~885k global players
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
    private static func hallOfFameEntries() -> [LeaderboardEntry] {
        var entries: [LeaderboardEntry] = []

        for (index, count) in MockLeaderboardData.hallOfFameInfinityCounts.enumerated() {
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

            let platform: Platform = index % 2 == 0 ? .ios : .android
            // Score based on infinity tile count
            let score = MockLeaderboardData.scoreForMilestone("\(count)∞")

            let avatar = MockLeaderboardData.avatarIDs[index % MockLeaderboardData.avatarIDs.count]

            entries.append(LeaderboardEntry(
                id: "hof_\(index)",
                rank: index + 1,
                name: name,
                score: score,
                countryCode: country,
                platform: platform,
                avatarURL: avatar,
                highestTile: "\(count)∞"
            ))
        }

        return entries
    }

    // Exact US player milestones from screenshots (ranks 1-256+)
    private static let usPlayerMilestones: [String] = [
        // Ranks 1-15
        "106by", "3bw", "1br", "1bo", "20bm", "76bk", "74bj", "1bj", "9bi", "35bh", "278bg", "543bf", "16bf", "506bc", "30bb",
        // Ranks 16-30
        "943az", "28ay", "28ax", "1aw", "818at", "24as", "48ar", "2aq", "22ao", "709an", "176an", "1an", "676al", "42al", "661ak",
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

    // Global leaderboard - uses exact milestones from screenshots
    private static func globalEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference
        var entries: [LeaderboardEntry] = []

        for (index, milestone) in globalPlayerMilestones.enumerated() {
            let name: String
            let country: String
            let id: String
            let playerIndex: Int

            // Check if this milestone belongs to a US player
            if let usIndex = milestoneToUSPlayerIndex[milestone] {
                name = MockLeaderboardData.usNames[usIndex % MockLeaderboardData.usNames.count]
                country = "US"
                id = "us_\(usIndex)"
                playerIndex = usIndex
            } else {
                name = MockLeaderboardData.globalNames[index % MockLeaderboardData.globalNames.count]
                country = MockLeaderboardData.countries[index % MockLeaderboardData.countries.count]
                id = "global_\(index)"
                playerIndex = index + 1000  // Offset to differentiate from US players
            }

            let platform: Platform = index % 2 == 0 ? .ios : .android
            // Score based on milestone value with daily progression
            let baseScore = MockLeaderboardData.scoreForMilestone(milestone)
            let score = MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: playerIndex, day: day)
            let avatar = MockLeaderboardData.avatarIDs[index % MockLeaderboardData.avatarIDs.count]

            entries.append(LeaderboardEntry(
                id: id,
                rank: index + 1,
                name: name,
                score: score,
                countryCode: country,
                platform: platform,
                avatarURL: avatar,
                highestTile: milestone
            ))
        }

        // Add current user entry (ranked among 900k+ global players)
        // Rank is calculated based on user's milestone relative to top 150 cutoff
        let userMilestone = UserLeaderboardData.currentMilestone
        let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)

        // Global top 150 cutoff is "2aq" - need this or higher to be in top 150
        let globalTop150Cutoff = "2aq"
        let globalCutoffIndex = MockLeaderboardData.allMilestones.firstIndex(of: globalTop150Cutoff) ?? 480
        let userMilestoneIndex = MockLeaderboardData.allMilestones.firstIndex(of: userMilestone) ?? 0
        let totalPlayers = 943_817

        let globalRank: Int
        if userMilestoneIndex >= globalCutoffIndex {
            // User is in top 150 - rank based on position above cutoff
            let aboveCutoff = userMilestoneIndex - globalCutoffIndex
            globalRank = max(1, 150 - aboveCutoff)
        } else {
            // User is below top 150 - use bracket-based ranking
            var foundRank = totalPlayers
            for bracket in globalExtendedRankBrackets.reversed() {
                if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIndex >= bracketIndex {
                    foundRank = bracket.startRank
                    break
                }
            }
            globalRank = foundRank
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
    private static func countryEntries() -> [LeaderboardEntry] {
        let day = MockLeaderboardData.daysSinceReference
        let milestones = MockLeaderboardData.allMilestones

        // Use shared function for US players (ensures same milestones as Global tab)
        let players = usPlayerData(day: day, milestones: milestones)
        // Players are already in rank order (0 = rank 1, etc.)

        var entries: [LeaderboardEntry] = []
        for (rank, player) in players.enumerated() {
            let name = MockLeaderboardData.usNames[player.index % MockLeaderboardData.usNames.count]
            let platform: Platform = player.index % 2 == 0 ? .ios : .android
            let milestone = player.exactMilestone  // Use exact milestone from screenshots
            // Score based on milestone value with daily progression
            let baseScore = MockLeaderboardData.scoreForMilestone(milestone)
            let score = MockLeaderboardData.scoreWithDailyProgression(baseScore: baseScore, playerIndex: player.index, day: day)
            let avatar = MockLeaderboardData.avatarIDs[player.index % MockLeaderboardData.avatarIDs.count]

            entries.append(LeaderboardEntry(
                id: "us_\(player.index)",
                rank: rank + 1,
                name: name,
                score: score,
                countryCode: "US",
                platform: platform,
                avatarURL: avatar,
                highestTile: milestone
            ))
        }

        // Add current user entry (ranked among 100k+ US players)
        // Rank is calculated based on user's milestone relative to top 150 cutoff
        let userMilestone = UserLeaderboardData.currentMilestone
        let userScore = MockLeaderboardData.scoreForMilestone(userMilestone)

        // US top 150 cutoff is "9b" - need this or higher to be in top 150
        let usTop150Cutoff = "9b"
        let usCutoffIndex = MockLeaderboardData.allMilestones.firstIndex(of: usTop150Cutoff) ?? 33
        let userMilestoneIndex = MockLeaderboardData.allMilestones.firstIndex(of: userMilestone) ?? 0
        let totalUSPlayers = 84_721

        let usRank: Int
        if userMilestoneIndex >= usCutoffIndex {
            // User is in top 150 - rank based on position above cutoff
            let aboveCutoff = userMilestoneIndex - usCutoffIndex
            usRank = max(1, 150 - aboveCutoff)
        } else {
            // User is below top 150 - use bracket-based ranking from extended data
            // Find the bracket and distribute rank within the bracket range
            var bracketStart = totalUSPlayers
            var bracketEnd = totalUSPlayers
            var foundBracketIndex = -1

            // For milestones in allMilestones (M-tier and above), iterate forward
            // and find the FIRST bracket where user's milestone index >= bracket's index
            // (brackets are ordered high-to-low milestone, so first match is the correct one)
            if userMilestoneIndex > 0 {
                for (i, bracket) in usExtendedRankBrackets.enumerated() {
                    if let bracketIndex = MockLeaderboardData.allMilestones.firstIndex(of: bracket.milestone),
                       userMilestoneIndex >= bracketIndex {
                        // First match is the correct bracket (highest milestone user qualifies for)
                        foundBracketIndex = i
                        break
                    }
                }

                if foundBracketIndex >= 0 {
                    bracketStart = usExtendedRankBrackets[foundBracketIndex].startRank
                    if foundBracketIndex + 1 < usExtendedRankBrackets.count {
                        bracketEnd = usExtendedRankBrackets[foundBracketIndex + 1].startRank - 1
                    } else {
                        bracketEnd = totalUSPlayers
                    }
                }
            }

            // For milestones below 1M (K-tier and raw numbers), find bracket by string matching
            if foundBracketIndex < 0 {
                for (i, bracket) in usExtendedRankBrackets.enumerated() {
                    if userMilestone == bracket.milestone {
                        bracketStart = bracket.startRank
                        if i + 1 < usExtendedRankBrackets.count {
                            bracketEnd = usExtendedRankBrackets[i + 1].startRank - 1
                        } else {
                            bracketEnd = totalUSPlayers
                        }
                        foundBracketIndex = i
                        break
                    }
                }
            }

            // Distribute user within the bracket range based on their score
            // Higher scores get lower (better) ranks within the bracket
            let range = bracketEnd - bracketStart
            if range > 0 && foundBracketIndex >= 0 {
                // Use score to position within bracket - create deterministic but varied position
                let scoreHash = abs(userScore.hashValue) % (range + 1)
                usRank = bracketStart + scoreHash
            } else {
                usRank = bracketStart
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

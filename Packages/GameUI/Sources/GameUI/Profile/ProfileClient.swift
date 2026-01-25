import SwiftUI
import GameCore

// MARK: - Service Protocol

public struct ProfilePayload: Sendable {
    public var playerName: String
    public var bestScoreText: String
    public var globalRank: Int
    public var tiers: [TierStat]
    public var friendCode: String
    public var season: SeasonInfo
    public var avatarSystemName: String
    public var countryCode: String?
    public var highestTile: String?
    
    public init(
        playerName: String,
        bestScoreText: String,
        globalRank: Int,
        tiers: [TierStat],
        friendCode: String,
        season: SeasonInfo,
        avatarSystemName: String,
        countryCode: String? = nil,
        highestTile: String? = nil
    ) {
        self.playerName = playerName
        self.bestScoreText = bestScoreText
        self.globalRank = globalRank
        self.tiers = tiers
        self.friendCode = friendCode
        self.season = season
        self.avatarSystemName = avatarSystemName
        self.countryCode = countryCode
        self.highestTile = highestTile
    }
}

public protocol ProfileClient: Sendable {
    func fetchProfile() async throws -> ProfilePayload
    func updatePlayerName(_ name: String) async throws
    func updateCountry(_ countryCode: String?) async throws
    func shareDeepLink(for payload: ProfilePayload) -> URL
}

// MARK: - Environment Key

private struct ProfileClientKey: EnvironmentKey {
    static let defaultValue: any ProfileClient = LiveProfileClient()
}

public extension EnvironmentValues {
    var profileClient: ProfileClient {
        get { self[ProfileClientKey.self] }
        set { self[ProfileClientKey.self] = newValue }
    }
}

// MARK: - Live Implementation

public struct LiveProfileClient: ProfileClient, Sendable {
    public init() {}

    public func fetchProfile() async throws -> ProfilePayload {
        let defaults = UserDefaults.standard

        // Read best score from UserDefaults (same keys as GameStore)
        let bestScoreText: String
        if let alphaString = defaults.string(forKey: "savedBestScoreAlpha"), !alphaString.isEmpty {
            // Format large numbers with commas
            bestScoreText = formatScoreString(alphaString)
        } else {
            let intScore = defaults.integer(forKey: "savedBestScore")
            bestScoreText = formatScore(intScore)
        }

        // Read player name (with fallback)
        let playerName = defaults.string(forKey: "profilePlayerName") ?? "Player"

        // Read friend code (with fallback)
        let friendCode = defaults.string(forKey: "profileFriendCode") ?? generateFriendCode()

        // Read country code
        let countryCode = defaults.string(forKey: "profileCountryCode")

        // Read highest tile - use leaderboard.milestone for consistency with HUD
        // This ensures Profile and HUD always show the same rank
        let highestTile: String? = {
            // Primary: Use leaderboard.milestone (same as HUD)
            if let milestone = defaults.string(forKey: "leaderboard.milestone"), !milestone.isEmpty {
                return milestone
            }
            // Fallback: Use step-based formatting
            let savedHighestTileStep = defaults.integer(forKey: "savedHighestTileStep")
            if savedHighestTileStep > 0 {
                return TileStepLabelFormatter.labelForStep(savedHighestTileStep)
            }
            // Legacy fallback
            let savedHighestTile = defaults.integer(forKey: "savedHighestTile")
            if savedHighestTile > 0 {
                return TileStepLabelFormatter.formatTileValue(savedHighestTile)
            }
            return nil
        }()

        // Read avatar
        let avatarId = defaults.string(forKey: "profileAvatarId") ?? AvatarCatalog.default.id

        // Calculate global rank based on user's milestone
        let globalRank = calculateGlobalRank(milestone: highestTile)

        // Tier stats are loaded separately from GameStore, so return empty here
        // The view will update them from gameStore.tierMasteryCounts
        let tiers: [TierStat] = []

        return .init(
            playerName: playerName,
            bestScoreText: bestScoreText,
            globalRank: globalRank,
            tiers: tiers,
            friendCode: friendCode,
            season: .init(name: "Season 7", division: "Diamond"),
            avatarSystemName: avatarId,
            countryCode: countryCode,
            highestTile: highestTile
        )
    }

    public func updatePlayerName(_ name: String) async throws {
        UserDefaults.standard.set(name, forKey: "profilePlayerName")
    }

    public func updateCountry(_ countryCode: String?) async throws {
        if let code = countryCode {
            UserDefaults.standard.set(code, forKey: "profileCountryCode")
        } else {
            UserDefaults.standard.removeObject(forKey: "profileCountryCode")
        }
    }

    public func shareDeepLink(for payload: ProfilePayload) -> URL {
        return URL(string: "game2244://profile?id=\(payload.friendCode)")!
    }

    // MARK: - Helpers

    private func formatScore(_ score: Int) -> String {
        // Use abbreviated format (K/M/B/a/b/etc.) for scores
        let alpha = AlphaNumber(score)
        return alpha.formattedWithCommas()
    }

    private func formatScoreString(_ decimalString: String) -> String {
        // Clean the string first - remove any whitespace or non-numeric characters
        let cleaned = decimalString.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()

        guard !cleaned.isEmpty else { return "0" }

        // Parse as AlphaNumber to handle very large values
        if let alpha = AlphaNumber(decimalString: cleaned) {
            return alpha.formattedWithCommas()
        }

        // Fallback: if we can parse as Int, use that
        if let intValue = Int(cleaned) {
            return formatScore(intValue)
        }

        // Last resort: return the cleaned string
        return cleaned
    }

    private func formatTileValue(_ value: Int) -> String {
        // Format tile values using K, M, B, then alphabetic suffixes (a, b, c, ..., z, aa, ab, ..., bz)
        if value >= 1_000_000_000_000 {
            // Use alphabetic suffixes for trillions+
            var remaining = Double(value)
            var tierIndex = 0
            while remaining >= 1_000 && tierIndex < 100 {
                remaining /= 1_000
                tierIndex += 1
            }
            let letterIndex = tierIndex - 3 // 4->1 (a), 5->2 (b), etc.
            let suffix = excelStyleLetters(for: letterIndex)
            return "\(Int(remaining))\(suffix)"
        } else if value >= 1_000_000_000 {
            return "\(value / 1_000_000_000)B"
        } else if value >= 1_000_000 {
            return "\(value / 1_000_000)M"
        } else if value >= 1_000 {
            return "\(value / 1_000)K"
        }
        return "\(value)"
    }

    /// Excel-style letters: 1->"a", 26->"z", 27->"aa", 52->"az", 53->"ba", 78->"bz"
    private func excelStyleLetters(for index: Int) -> String {
        guard index >= 1 else { return "a" }
        var i = index
        var result = ""
        while i > 0 {
            let rem = (i - 1) % 26
            let scalar = UnicodeScalar(97 + rem)! // 'a'..'z'
            result = String(scalar) + result
            i = (i - 1) / 26
        }
        return result
    }

    private func generateFriendCode() -> String {
        // Generate a simple friend code if none exists
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let randomLetters = String((0..<3).map { _ in letters.randomElement()! })
        let randomNumbers = String(format: "%03d", Int.random(in: 0...999))
        let code = "\(randomLetters)-\(randomNumbers)"
        UserDefaults.standard.set(code, forKey: "profileFriendCode")
        return code
    }

    private func calculateGlobalRank(milestone: String?) -> Int {
        // Use milestone from leaderboard data if available, otherwise use profile's highestTile
        let userMilestone = UserDefaults.standard.string(forKey: "leaderboard.milestone") ?? milestone ?? "16M"

        // All milestone tiers in order (same as LeaderboardClient)
        let allMilestones: [String] = [
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

        // Global top 150 cutoff is "2aq" - need this or higher to be in top 150
        let globalTop150Cutoff = "2aq"
        let globalCutoffIndex = allMilestones.firstIndex(of: globalTop150Cutoff) ?? 480
        let userMilestoneIndex = allMilestones.firstIndex(of: userMilestone) ?? 0
        // Calculate dynamic total players based on days since reference and joining rate
        let referenceDate = DateComponents(calendar: .current, year: 2025, month: 1, day: 1).date ?? Date()
        let day = max(0, Calendar.current.dateComponents([.day], from: referenceDate, to: Date()).day ?? 0)
        let baseGlobalPlayers = 885_676
        var totalNewPlayers = 0
        for d in 0...day {
            // 10-1000 new players per day (deterministic based on day)
            let seed = 67890
            let random = Double((seed * 31 + d * 17) % 1000) / 1000.0
            totalNewPlayers += 10 + Int(random * 990)
        }
        let totalPlayers = baseGlobalPlayers + totalNewPlayers

        if userMilestoneIndex >= globalCutoffIndex {
            // User is in top 150 - rank based on position above cutoff
            let aboveCutoff = userMilestoneIndex - globalCutoffIndex
            return max(1, 150 - aboveCutoff)
        } else {
            // User is below top 150 - use bracket-based ranking
            let globalExtendedBrackets: [(milestone: String, startRank: Int)] = [
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

            // Find the bracket and distribute rank within the bracket range
            // Iterate forward and find the FIRST bracket where user's milestone index >= bracket's index
            // (brackets are ordered high-to-low milestone, so first match is the correct one)
            var bracketStart = totalPlayers
            var foundBracketIndex = -1

            for (i, bracket) in globalExtendedBrackets.enumerated() {
                if let bracketIndex = allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIndex >= bracketIndex {
                    // First match is the correct bracket (highest milestone user qualifies for)
                    foundBracketIndex = i
                    break
                }
            }

            if foundBracketIndex >= 0 {
                bracketStart = globalExtendedBrackets[foundBracketIndex].startRank
            }

            // Return the bracket start rank - each milestone bracket has a distinct rank
            // Higher milestone = earlier (lower) bracket index = better (lower) rank
            return bracketStart
        }
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
            bestScoreText: "3513812",
            globalRank: 534,
            tiers: left + right,
            friendCode: "AJ711-534",
            season: .init(name: "Season 7", division: "Diamond"),
            avatarSystemName: AvatarCatalog.default.id,
            countryCode: "US",
            highestTile: "1an"
        )
    }

    func updatePlayerName(_ name: String) async throws { /* no-op */ }

    func updateCountry(_ countryCode: String?) async throws { /* no-op */ }

    func shareDeepLink(for payload: ProfilePayload) -> URL {
        // Replace with your real deep link scheme
        return URL(string: "game2244://profile?id=\(payload.friendCode)")!
    }
}
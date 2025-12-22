import SwiftUI

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

        // Read highest tile and format it
        let savedHighestTile = defaults.integer(forKey: "savedHighestTile")
        let highestTile: String? = savedHighestTile > 0 ? formatTileValue(savedHighestTile) : nil

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
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: score)) ?? "\(score)"
    }

    private func formatScoreString(_ decimalString: String) -> String {
        // The decimalString is stored as a plain number string (e.g., "13000000")
        // We need to format it with commas
        if let intValue = Int(decimalString) {
            return formatScore(intValue)
        }
        // If it's already a large number beyond Int, just return as-is with basic formatting
        return decimalString
    }

    private func formatTileValue(_ value: Int) -> String {
        // Format tile values like "1an" for large numbers
        // This matches the game's AlphaNumber formatting
        if value >= 1_000_000_000_000 {
            return "\(value / 1_000_000_000_000)T"
        } else if value >= 1_000_000_000 {
            return "\(value / 1_000_000_000)B"
        } else if value >= 1_000_000 {
            return "\(value / 1_000_000)M"
        } else if value >= 1_000 {
            return "\(value / 1_000)K"
        }
        return "\(value)"
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
        let totalPlayers = 943_817

        if userMilestoneIndex >= globalCutoffIndex {
            // User is in top 150 - rank based on position above cutoff
            let aboveCutoff = userMilestoneIndex - globalCutoffIndex
            return max(1, 150 - aboveCutoff)
        } else {
            // User is below top 150 - use bracket-based ranking
            let globalExtendedBrackets: [(milestone: String, startRank: Int)] = [
                // a-tier brackets
                ("1aq", 151), ("562a", 200), ("281a", 300), ("140a", 450), ("70a", 650),
                ("35a", 900), ("17a", 1300), ("8a", 1900), ("4a", 2800), ("2a", 4200), ("1a", 6500),
                // B-tier brackets
                ("549B", 10000), ("274B", 16000), ("137B", 26000), ("68B", 42000), ("34B", 68000),
                ("17B", 110000), ("8B", 175000), ("4B", 280000), ("2B", 420000), ("1B", 550000),
                // M-tier brackets
                ("536M", 620000), ("268M", 680000), ("134M", 740000), ("67M", 800000), ("33M", 850000),
                ("16M", 890000), ("8M", 915000), ("4M", 930000), ("2M", 940000), ("1M", 943000)
            ]

            // Find the bracket and distribute rank within the bracket range
            var bracketStart = totalPlayers
            var bracketEnd = totalPlayers
            var foundBracket = false

            for (i, bracket) in globalExtendedBrackets.enumerated().reversed() {
                if let bracketIndex = allMilestones.firstIndex(of: bracket.milestone),
                   userMilestoneIndex >= bracketIndex {
                    bracketStart = bracket.startRank
                    // Get the next bracket's start rank as our end
                    if i + 1 < globalExtendedBrackets.count {
                        bracketEnd = globalExtendedBrackets[i + 1].startRank - 1
                    } else {
                        bracketEnd = totalPlayers
                    }
                    foundBracket = true
                    break
                }
            }

            // Distribute user within the bracket range
            let range = bracketEnd - bracketStart
            if range > 0 && foundBracket {
                // Use milestone string hash for deterministic but varied position
                let milestoneHash = abs(userMilestone.hashValue) % (range + 1)
                return bracketStart + milestoneHash
            }
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
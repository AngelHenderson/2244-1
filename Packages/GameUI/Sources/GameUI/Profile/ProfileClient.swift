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

        // Read global rank (placeholder - would come from server)
        let globalRank = defaults.integer(forKey: "profileGlobalRank")

        // Tier stats are loaded separately from GameStore, so return empty here
        // The view will update them from gameStore.tierMasteryCounts
        let tiers: [TierStat] = []

        return .init(
            playerName: playerName,
            bestScoreText: bestScoreText,
            globalRank: globalRank > 0 ? globalRank : 999,
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
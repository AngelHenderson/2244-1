import SwiftUI
import Observation
import GameCore

// MARK: - Domain Models

public struct TierStat: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var key: String      // e.g., "K"
    public var value: Int       // e.g., 244
    public var color: Color     // badge color
    public var label: String    // e.g., "K-Tier Best"
    
    public init(key: String, value: Int, color: Color, label: String) {
        self.key = key
        self.value = value
        self.color = color
        self.label = label
    }
}

public extension TierStat {
    /// Presentation glyph; keep canonical casing for K/M/B, curve l, otherwise lowercase.
    var displayKey: String {
        if key == "l" { return "ℓ" }
        // If it's one of the uppercase standard tiers, return as is
        if ["K", "M", "B"].contains(key) { return key }
        // Otherwise return the key (which should be lowercase for alpha tiers)
        return key
    }
    
    var usesCurvedLStyling: Bool {
        key == "l"
    }
    
    @MainActor
    static func stats(from counts: [String: Int]) -> [TierStat] {
        // Use counts directly without normalizing to lowercase to preserve K/M/B vs k/m/b distinction
        // But we still need to handle infinity normalization if needed
        var normalizedCounts: [String: Int] = [:]
        counts.forEach { rawKey, value in
            if rawKey.lowercased() == "∞" || rawKey.lowercased() == "infinity" {
                normalizedCounts["∞"] = value
            } else {
                // Strip any digits if the key comes in as "1K" etc (though usually it's just the suffix)
                // Assuming counts keys match the suffixes generated in allTierKeys
                normalizedCounts[rawKey] = value
            }
        }

        // Return tiers in fixed order from allTierKeys
        // Only show color if user has at least 1 of that tier
        return allTierKeys.map { key in
            let value = normalizedCounts[key] ?? 0
            let tierColor = value >= 1 ? color(for: key) : Color.gray.opacity(0.4)
            return TierStat(
                key: key,
                value: value,
                color: tierColor,
                label: "\(key.uppercased())-Tier"
            )
        }
    }
    
    @MainActor
    private static func color(for key: String) -> Color {
        // Map tier key to step index for consistent colors with game tiles
        // Step indices: K=13 (16K), M=19 (1M), B=29 (1B), then letters follow
        if let step = stepForTierKey(key) {
            return Theme.colorForStep(step)
        }

        // Special case for infinity
        if key == "∞" {
            return Theme.color(for: 262_144)
        }

        // Fallback to gray for unknown tiers
        return .gray
    }

    /// Maps a tier key (K, M, B, a, b, ..., aa, ab, ..., bz) to its step index
    private static func stepForTierKey(_ key: String) -> Int? {
        let uppercased = key.uppercased()

        // Base tiers with fixed steps
        // K = step 13 (2^14 = 16,384 = 16K)
        // M = step 19 (2^20 = 1,048,576 = 1M)
        // B = step 29 (2^30 = 1,073,741,824 = 1B)
        switch uppercased {
        case "K": return 13
        case "M": return 19
        case "B": return 29
        default: break
        }

        // Lowercase letter tiers (a-z, aa-bz)
        // After B (step 29), each new tier suffix adds ~10 steps
        // a = step 39 (2^40 = 1T), b = step 49 (2^50), etc.
        let lowercased = key.lowercased()

        if lowercased.count == 1, let firstChar = lowercased.first,
           firstChar >= "a" && firstChar <= "z" {
            // Single letter: a=0, b=1, ..., z=25
            let letterIndex = Int(firstChar.asciiValue! - Character("a").asciiValue!)
            // Each letter adds ~10 steps from B's base (step 29)
            return 29 + (letterIndex + 1) * 10
        }

        if lowercased.count == 2 {
            let chars = Array(lowercased)
            guard chars[0] >= "a" && chars[0] <= "b",
                  chars[1] >= "a" && chars[1] <= "z" else { return nil }

            // aa, ab, ..., az = indices 26-51
            // ba, bb, ..., bz = indices 52-77
            let firstIndex = Int(chars[0].asciiValue! - Character("a").asciiValue!) // 0 for 'a', 1 for 'b'
            let secondIndex = Int(chars[1].asciiValue! - Character("a").asciiValue!) // 0-25
            let letterIndex = 26 + firstIndex * 26 + secondIndex
            return 29 + (letterIndex + 1) * 10
        }

        return nil
    }
    
    private static var allTierKeys: [String] {
        // Generate a comprehensive hardcoded list of all possible tier keys
        // This ensures all tiers are present regardless of JourneyAbbreviationTiers initialization timing
        var keys: [String] = ["K", "M", "B"]
        
        // Add single letters a-z (26 letters)
        for i in 0..<26 {
            let char = String(UnicodeScalar(97 + i)!) // 'a' to 'z'
            keys.append(char)
        }
        
        // Add double letters aa-az, ba-bz (52 total)
        for prefix in ["a", "b"] {
            for i in 0..<26 {
                let suffix = String(UnicodeScalar(97 + i)!) // 'a' to 'z'
                keys.append("\(prefix)\(suffix)")
            }
        }
        
        // Add infinity at the end
        keys.append("∞")
        
        return keys
    }
}

public struct SeasonInfo: Equatable, Sendable {
    public var name: String        // "Season 7"
    public var division: String    // "Diamond"
    
    public init(name: String, division: String) {
        self.name = name
        self.division = division
    }
}

public enum SyncStatus: Equatable {
    case syncing
    case synced(Date)
    case error(String)
}

@MainActor
@Observable
public final class ProfileModel {
    // Identity
    public var playerName: String = "Angel Junior711"
    public var avatarSystemName: String = AvatarCatalog.default.id
    public var friendCode: String = "AJ711-534"
    public var countryCode: String? = nil
    public var highestTile: String? = nil

    // Stats
    public var bestScoreText: String = "3513812"
    public var globalRank: Int = 534
    public var tiers: [TierStat] = []

    // Season & sync
    public var season: SeasonInfo = .init(name: "Season 7", division: "Diamond")
    public var sync: SyncStatus = .synced(Date())

    // Sheets
    public var showCustomize = false
    public var showRename = false
    public var showSeasonHistory = false
    public var showCompare = false
    public var showCountryPicker = false
    
    public init() {}

    // Loading
    public func load(using client: ProfileClient) async {
        sync = .syncing
        do {
            let data = try await client.fetchProfile()
            apply(data)
            sync = .synced(Date())
        } catch {
            sync = .error("Failed to sync")
        }
    }

    public func rename(to newName: String, using client: ProfileClient) async -> Bool {
        guard newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return false }
        do {
            try await client.updatePlayerName(newName)
            playerName = newName
            return true
        } catch { return false }
    }
    
    public func updateCountry(to countryCode: String?, using client: ProfileClient) async {
        do {
            try await client.updateCountry(countryCode)
            self.countryCode = countryCode
        } catch {
            // Handle error silently for now
        }
    }

    private func apply(_ d: ProfilePayload) {
        playerName = d.playerName
        bestScoreText = d.bestScoreText
        globalRank = d.globalRank
        tiers = d.tiers
        friendCode = d.friendCode
        season = d.season
        avatarSystemName = AvatarCatalog.option(for: d.avatarSystemName).id
        countryCode = d.countryCode
        highestTile = d.highestTile
    }
}
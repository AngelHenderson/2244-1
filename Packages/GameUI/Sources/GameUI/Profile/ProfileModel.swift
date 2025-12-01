import SwiftUI
import Observation

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
    static func stats(from counts: [String: Int]) -> [TierStat] {
        counts
            .filter { $0.value > 0 }
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .map { (key, value) in
                TierStat(
                    key: key,
                    value: value,
                    color: color(for: key),
                    label: "\(key.uppercased())-Tier"
                )
            }
    }
    
    private static func color(for key: String) -> Color {
        let lowered = key.lowercased()
        if let predefined = predefinedColors[lowered] {
            return predefined
        }
        let palette: [Color] = [.purple, .pink, .red, .orange, .yellow, .green, .teal, .cyan, .blue, .indigo]
        let hash = lowered.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[abs(hash) % palette.count]
    }
    
    private static let predefinedColors: [String: Color] = [
        "k": .purple,
        "m": .pink,
        "b": .red
    ]
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
    public var avatarSystemName: String = "person.circle.fill" // placeholder for your asset id
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
        avatarSystemName = d.avatarSystemName
        countryCode = d.countryCode
        highestTile = d.highestTile
    }
}
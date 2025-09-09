import SwiftUI
import Observation

// MARK: - Domain Models

public struct TierStat: Identifiable, Hashable {
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

public struct SeasonInfo: Equatable {
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

    // Stats
    public var bestScoreText: String = "3,513,812"
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

    private func apply(_ d: ProfilePayload) {
        playerName = d.playerName
        bestScoreText = d.bestScoreText
        globalRank = d.globalRank
        tiers = d.tiers
        friendCode = d.friendCode
        season = d.season
        avatarSystemName = d.avatarSystemName
    }
}
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
        let lower = key.lowercased()
        if lower == "k" { return "K" }
        if lower == "m" { return "M" }
        if lower == "b" { return "B" }
        return lower
    }
    
    var usesCurvedLStyling: Bool {
        key == "l"
    }
    
    static func stats(from counts: [String: Int]) -> [TierStat] {
        // Build canonical map and normalize counts to that casing (K/M/B uppercase; others as defined).
        var canonicalMap: [String: String] = [:]
        allTierKeys.forEach { key in
            let lower = key.lowercased()
            if canonicalMap[lower] == nil {
                canonicalMap[lower] = key
            }
        }
        // Ensure K/M/B exist
        canonicalMap["k"] = canonicalMap["k"] ?? "K"
        canonicalMap["m"] = canonicalMap["m"] ?? "M"
        canonicalMap["b"] = canonicalMap["b"] ?? "B"
        
        var normalizedCounts: [String: Int] = [:]
        counts.forEach { rawKey, value in
            let lower = rawKey.lowercased()
            if lower == "∞" || lower == "infinity" {
                normalizedCounts["∞"] = value
            } else if let canonical = canonicalMap[lower] {
                normalizedCounts[canonical] = value
            }
        }
        
        var orderedKeys = allTierKeys
        for key in normalizedCounts.keys where !orderedKeys.contains(key) {
            orderedKeys.append(key)
        }
        let mergedKeys = normalizedCounts.keys.filter { allTierKeys.contains($0) || $0 == "∞" }
        let unmergedKeys = orderedKeys.filter { !mergedKeys.contains($0) }
        
        // keep any merged tiers at the top, sorted by value desc then key
        let mergedOrdered = mergedKeys.sorted { lhs, rhs in
            let leftValue = normalizedCounts[lhs] ?? 0
            let rightValue = normalizedCounts[rhs] ?? 0
            if leftValue == rightValue {
                return lhs < rhs
            }
            return leftValue > rightValue
        }
        
        // place special end-caps (bz and infinity) at the bottom; everything else before them
        let specialEndCaps: Set<String> = ["bz", "∞", "infinity"]
        let (endCaps, regularUnmerged) = unmergedKeys.reduce(into: ([String](), [String]())) { partial, key in
            if specialEndCaps.contains(key.lowercased()) || key == "∞" {
                partial.0.append(key)
            } else {
                partial.1.append(key)
            }
        }
        let orderedWithProgress = mergedOrdered + regularUnmerged + endCaps
        
        return orderedWithProgress.map { key in
            let value = normalizedCounts[key] ?? 0
            return TierStat(
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
    
    private static let allTierKeys: [String] = {
        let suffixes = JourneyAbbreviationTiers.tiers.compactMap { tier -> String? in
            let label = tier.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = label.trimmingCharacters(in: .decimalDigits)
            return suffix.isEmpty ? nil : suffix
        }
        // preserve order while removing duplicates
        var seen: Set<String> = []
        return suffixes.compactMap { suffix in
            if seen.contains(suffix) {
                return nil
            }
            seen.insert(suffix)
            return suffix
        }
    }()
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
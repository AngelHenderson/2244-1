import Foundation
#if canImport(GameKit)
@preconcurrency import GameKit
#endif

// MARK: - Game Center Leaderboard Client
// Provides real-world player leaderboards via Apple Game Center.
//
// Supports:
// - Global leaderboard (all players worldwide)
// - Hall of Fame leaderboard (infinity count rankings)
// - Country leaderboard (uses device locale for filtering)
//
// Note: Game Center doesn't natively expose player country codes.
// Country filtering uses the local player's device region to determine
// which country leaderboard they belong to. Players see global rankings
// but can filter to see their regional standing.

public struct GameCenterLeaderboardConfig: Sendable {
    /// Leaderboard ID for global high score leaderboard
    public let globalLeaderboardID: String
    /// Leaderboard ID for Hall of Fame (infinity count) leaderboard
    public let hallOfFameLeaderboardID: String
    /// Whether to submit scores automatically
    public let submitAutomatically: Bool

    public init(
        globalLeaderboardID: String = "com.game2244.global",
        hallOfFameLeaderboardID: String = "com.game2244.halloffame",
        submitAutomatically: Bool = true
    ) {
        self.globalLeaderboardID = globalLeaderboardID
        self.hallOfFameLeaderboardID = hallOfFameLeaderboardID
        self.submitAutomatically = submitAutomatically
    }

    /// Get the appropriate leaderboard ID for a filter type
    public func leaderboardID(for filter: LeaderboardFilter) -> String {
        switch filter {
        case .hallOfFame:
            return hallOfFameLeaderboardID
        default:
            return globalLeaderboardID
        }
    }
}

#if canImport(GameKit)
@MainActor
public extension LeaderboardClient {
    static func gameCenter(config: GameCenterLeaderboardConfig = .init()) -> LeaderboardClient {
        LeaderboardClient(
            authenticate: {
                await withCheckedContinuation { continuation in
                    Task { @MainActor in
                        GKLocalPlayer.local.authenticateHandler = { viewController, error in
                            if let error {
                                print("Game Center auth error: \(error)")
                                continuation.resume(returning: false)
                                return
                            }
                            
                            if viewController != nil {
                                // Need to present view controller - for now we'll skip
                                // In production, you'd present this VC
                                continuation.resume(returning: false)
                                return
                            }
                            
                            continuation.resume(returning: GKLocalPlayer.local.isAuthenticated)
                        }
                    }
                }
            },
            
            submitScore: { score in
                guard GKLocalPlayer.local.isAuthenticated else {
                    throw NSError(domain: "GameCenter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
                }

                // Submit to global leaderboard (high score)
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [config.globalLeaderboardID]
                )
            },

            submitInfinityCount: { infinityCount in
                guard GKLocalPlayer.local.isAuthenticated else {
                    throw NSError(domain: "GameCenter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
                }

                // Submit to Hall of Fame leaderboard (infinity count)
                try await GKLeaderboard.submitScore(
                    infinityCount,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [config.hallOfFameLeaderboardID]
                )
            },
            
            fetchPage: { period, filter, cursor, pageSize in
                guard GKLocalPlayer.local.isAuthenticated else {
                    return LeaderboardPage(entries: [], myEntry: nil, nextCursor: nil)
                }

                // Parse cursor as starting rank (1-based)
                let startRank: Int = (cursor.flatMap { Int($0) }) ?? 1
                let range = NSRange(location: startRank, length: max(1, pageSize))

                // Get the appropriate leaderboard ID for this filter
                let leaderboardID = config.leaderboardID(for: filter)
                let boards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
                guard let board = boards.first else {
                    return LeaderboardPage(entries: [], myEntry: nil, nextCursor: nil)
                }
                
                // Map period to GK time scope
                let timeScope: GKLeaderboard.TimeScope = {
                    switch period {
                    case .today: return .today
                    case .week: return .week
                    case .allTime: return .allTime
                    }
                }()
                
                // Map filter to GK player scope
                let playerScope: GKLeaderboard.PlayerScope = {
                    switch filter {
                    case .global: return .global
                    case .hallOfFame: return .global
                    case .country: return .global
                    case .countryUK: return .global
                    case .countryCA: return .global
                    case .countryAU: return .global
                    case .countryDE: return .global
                    case .countryFR: return .global
                    case .countryJP: return .global
                    case .countryIN: return .global
                    case .countryBR: return .global
                    case .countryMX: return .global
                    case .countryAF: return .global
                    case .countryAL: return .global
                    case .countryDZ: return .global
                    case .countryCN: return .global
                    case .countryKR: return .global
                    case .countryIT: return .global
                    case .countryES: return .global
                    case .countryNL: return .global
                    case .countryCH: return .global
                    case .countryNO: return .global
                    case .countryDK: return .global
                    case .countryFI: return .global
                    case .countryPL: return .global
                    case .countryBE: return .global
                    case .countrySE: return .global
                    case .countryAT: return .global
                    case .countryIE: return .global
                    case .countryPT: return .global
                    case .countryGR: return .global
                    case .countryCZ: return .global
                    case .countryRO: return .global
                    case .countryMY: return .global
                    case .countryNZ: return .global
                    case .countryHU: return .global
                    case .countryTH: return .global
                    case .countryAE: return .global
                    case .countryPH: return .global
                    case .countryAD: return .global
                    case .countryID: return .global
                    case .countryZA: return .global
                    case .countryKE: return .global
                    case .countryFJ: return .global
                    case .countryVN: return .global
                    case .countryCW: return .global
                    case .countryVE: return .global
                    case .countryAZ: return .global
                    case .countryKZ: return .global
                    case .countryTJ: return .global
                    }
                }()

                let (localPlayerEntry, entries, totalPlayerCount) = try await board.loadEntries(
                    for: playerScope,
                    timeScope: timeScope,
                    range: range
                )
                
                let items = entries.enumerated().map { index, entry in
                    LeaderboardEntry(
                        id: entry.player.gamePlayerID,
                        rank: entry.rank,
                        name: entry.player.displayName,
                        score: Int(entry.score),
                        countryCode: nil, // GameKit doesn't expose this
                        platform: .ios,
                        isMe: entry.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID
                    )
                }
                
                let myEntry = localPlayerEntry.map { entry in
                    LeaderboardEntry(
                        id: entry.player.gamePlayerID,
                        rank: entry.rank,
                        name: entry.player.displayName,
                        score: Int(entry.score),
                        countryCode: nil,
                        platform: .ios,
                        isMe: true
                    )
                }
                
                let nextStart = (items.count < pageSize) ? nil : String(startRank + items.count)
                
                return LeaderboardPage(
                    entries: items,
                    myEntry: myEntry,
                    nextCursor: nextStart,
                    totalPlayers: totalPlayerCount
                )
            },
            
            fetchMyRank: { period, filter in
                guard GKLocalPlayer.local.isAuthenticated else { return nil }

                // Get the appropriate leaderboard ID for this filter
                let leaderboardID = config.leaderboardID(for: filter)
                let boards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
                guard let board = boards.first else { return nil }
                
                let timeScope: GKLeaderboard.TimeScope = {
                    switch period {
                    case .today: return .today
                    case .week: return .week
                    case .allTime: return .allTime
                    }
                }()
                
                let result = try? await board.loadEntries(
                    for: [GKLocalPlayer.local],
                    timeScope: timeScope
                )
                
                if let (localEntry, _) = result, let entry = localEntry {
                    return LeaderboardEntry(
                        id: entry.player.gamePlayerID,
                        rank: entry.rank,
                        name: entry.player.displayName,
                        score: Int(entry.score),
                        countryCode: nil,
                        platform: .ios,
                        isMe: true
                    )
                }
                return nil
            }
        )
    }
}
#else
// Fallback for platforms without GameKit
public extension LeaderboardClient {
    static func gameCenter(config: GameCenterLeaderboardConfig = .init()) -> LeaderboardClient {
        .noop
    }
}
#endif

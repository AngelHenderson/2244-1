import Foundation
#if canImport(GameKit)
@preconcurrency import GameKit
#endif

public struct GameCenterLeaderboardConfig: Sendable {
    public let leaderboardID: String
    public let submitAutomatically: Bool
    
    public init(leaderboardID: String = "com.game2244.highscore", submitAutomatically: Bool = true) {
        self.leaderboardID = leaderboardID
        self.submitAutomatically = submitAutomatically
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
                
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [config.leaderboardID]
                )
            },
            
            fetchPage: { period, filter, cursor, pageSize in
                guard GKLocalPlayer.local.isAuthenticated else {
                    return LeaderboardPage(entries: [], myEntry: nil, nextCursor: nil)
                }
                
                // Parse cursor as starting rank (1-based)
                let startRank: Int = (cursor.flatMap { Int($0) }) ?? 1
                let range = NSRange(location: startRank, length: max(1, pageSize))
                
                let boards = try await GKLeaderboard.loadLeaderboards(IDs: [config.leaderboardID])
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
                
                let boards = try await GKLeaderboard.loadLeaderboards(IDs: [config.leaderboardID])
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

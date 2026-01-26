import Foundation
import GameCore

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(GameServices)
import GameServices

/// Firebase-based implementation of LeaderboardClient
public extension LeaderboardClient {
    
    /// Creates a Firebase leaderboard client using the provided service
    static func firebase(_ service: LeaderboardService) -> LeaderboardClient {
        LeaderboardClient(
            authenticate: {
                try await authenticateFirebase()
            },
            submitScore: { score in
                try await submitFirebaseScore(score, service: service)
            },
            fetchPage: { period, filter, cursor, pageSize in
                try await fetchFirebasePage(
                    period: period,
                    filter: filter,
                    cursor: cursor,
                    pageSize: pageSize,
                    service: service
                )
            },
            fetchMyRank: { period, filter in
                try await fetchFirebaseUserRank(
                    period: period,
                    filter: filter,
                    service: service
                )
            }
        )
    }
}

// MARK: - Private Firebase Implementation

@MainActor
private func authenticateFirebase() async throws -> Bool {
    // Check if already authenticated
    if Auth.auth().currentUser != nil {
        return true
    }
    
    // Sign in anonymously to enable leaderboard access
    do {
        try await FirebaseService.shared.signInAnonymously()
        return true
    } catch {
        print("Firebase authentication failed: \(error)")
        return false
    }
}

@MainActor
private func submitFirebaseScore(_ score: Int, service: LeaderboardService) async throws {
    // For now, we'll submit to global leaderboard
    // In a real implementation, you'd determine this based on game context
    let board = LeaderboardBoard.global
    
    // Create run data from just the score
    // In a real implementation, you'd have access to more game data
    let runData = GameRunData(
        highestTile: estimateHighestTileFromScore(score),
        secondsToHighest: 0, // Would need to track this in game
        movesToHighest: 0,   // Would need to track this in game
        runScore: score
    )
    
    // Get user display name
    let displayName = Auth.auth().currentUser?.displayName ?? "Anonymous Player"
    
    try await service.submit(to: board, runData: runData, displayName: displayName)
}

@MainActor
private func fetchFirebasePage(
    period: LeaderboardPeriod,
    filter: LeaderboardFilter,
    cursor: String?,
    pageSize: Int,
    service: LeaderboardService
) async throws -> LeaderboardPage {
    
    // Map UI enums to our Firebase board types
    let board = mapPeriodToBoard(period)
    
    do {
        // Fetch entries from Firebase
        let firebaseEntries = try await service.fetchTopEntries(from: board, limit: pageSize)
        
        // Convert to UI model
        let entries = try await convertFirebaseEntriesToUI(firebaseEntries, service: service)
        
        // Fetch user's entry if authenticated
        let myEntry: LeaderboardEntry?
        if Auth.auth().currentUser != nil {
            if let userFirebaseEntry = try? await service.fetchUserEntry(from: board) {
                myEntry = try await convertFirebaseEntryToUI(userFirebaseEntry, service: service)
            } else {
                myEntry = nil
            }
        } else {
            myEntry = nil
        }
        
        return LeaderboardPage(
            entries: entries,
            myEntry: myEntry,
            nextCursor: entries.count == pageSize ? "next" : nil, // Simple cursor implementation
            totalPlayers: nil // Firebase doesn't provide total count easily
        )
        
    } catch {
        throw LeaderboardError.fetchFailed(error)
    }
}

@MainActor
private func fetchFirebaseUserRank(
    period: LeaderboardPeriod,
    filter: LeaderboardFilter,
    service: LeaderboardService
) async throws -> LeaderboardEntry? {
    
    guard Auth.auth().currentUser != nil else { return nil }
    
    let board = mapPeriodToBoard(period)
    
    do {
        if let userEntry = try await service.fetchUserEntry(from: board),
           let rank = try await service.fetchUserRank(in: board) {
            
            return try await convertFirebaseEntryToUI(userEntry, rank: rank, service: service)
        }
        return nil
    } catch {
        print("Failed to fetch user rank: \(error)")
        return nil
    }
}

// MARK: - Helper Functions

private func mapPeriodToBoard(_ period: LeaderboardPeriod) -> LeaderboardBoard {
    switch period {
    case .today:
        return .daily(date: Date())
    case .week:
        // For now, map to global. In a real implementation, you might have weekly boards
        return .global
    case .allTime:
        return .global
    }
}

@MainActor
private func convertFirebaseEntriesToUI(
    _ firebaseEntries: [GameCore.LeaderboardServiceEntry],
    service: LeaderboardService
) async throws -> [LeaderboardEntry] {
    
    var uiEntries: [LeaderboardEntry] = []
    
    for (index, firebaseEntry) in firebaseEntries.enumerated() {
        let rank = index + 1 // Simple rank calculation
        let uiEntry = try await convertFirebaseEntryToUI(
            firebaseEntry,
            rank: rank,
            service: service
        )
        uiEntries.append(uiEntry)
    }
    
    return uiEntries
}

@MainActor 
private func convertFirebaseEntryToUI(
    _ firebaseEntry: GameCore.LeaderboardServiceEntry,
    rank: Int? = nil,
    service: LeaderboardService
) async throws -> LeaderboardEntry {
    
    let currentUserId = Auth.auth().currentUser?.uid
    let isCurrentUser = firebaseEntry.uid == currentUserId
    
    // Decode composite score to get actual game score
    let compositeScore = Int64(firebaseEntry.value) ?? 0
    let decoded = CompositeScore.decode(compositeScore)
    
    // Format highest tile for display
    let highestTileDisplay = formatTileForDisplay(decoded.tile)
    
    return LeaderboardEntry(
        id: firebaseEntry.uid,
        rank: rank ?? 1,
        name: firebaseEntry.displayName,
        score: decoded.score, // Use the original game score
        countryCode: nil, // Firebase doesn't store country code by default
        platform: .ios, // Assume iOS for now
        isMe: isCurrentUser,
        avatarURL: nil,
        highestTile: highestTileDisplay
    )
}

private func formatTileForDisplay(_ tile: Int) -> String {
    // Convert tile value to display format
    // This matches the format used in the existing UI ("1an", "873bz", etc.)
    
    if tile >= 1024 {
        let k = tile / 1024
        if k >= 1024 {
            let m = k / 1024
            return "\(m)an" // "million" abbreviated
        }
        return "\(k)bz" // Custom abbreviation
    }
    
    return "\(tile)"
}

private func estimateHighestTileFromScore(_ score: Int) -> Int {
    // Rough estimation of highest tile based on score
    // This is a placeholder - in a real implementation, you'd track this properly
    
    switch score {
    case 0..<1000: return 64
    case 1000..<5000: return 128
    case 5000..<20000: return 256
    case 20000..<80000: return 512
    case 80000..<200000: return 1024
    case 200000..<500000: return 2048
    case 500000..<1000000: return 4096
    default: return 8192
    }
}
#endif

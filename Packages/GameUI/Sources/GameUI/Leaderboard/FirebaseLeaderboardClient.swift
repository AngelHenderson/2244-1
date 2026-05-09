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
            submitRun: { summary in
                try await submitFirebaseRun(summary, service: service)
            },
            submitInfinityCount: { count in
                try await submitFirebaseInfinityCount(count, service: service)
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
private func submitFirebaseRun(_ summary: GameRunSummary, service: LeaderboardService) async throws {
    let displayName = Auth.auth().currentUser?.displayName ?? UserLeaderboardData.playerName
    let runData = GameRunData(summary: summary)
    
    var firstError: Error?
    
    // 1. Submit to global
    do {
        try await service.submit(
            to: .global,
            runData: runData,
            displayName: displayName
        )
    } catch {
        firstError = error
    }
    
    // 2. Submit to country
    let countryCode = UserLeaderboardData.currentCountry.lowercased()
    do {
        try await service.submit(
            to: .mode("country_\(countryCode)"),
            runData: runData,
            displayName: displayName
        )
    } catch {
        if firstError == nil { firstError = error }
    }
    
    if let firstError {
        throw firstError
    }
}

@MainActor
private func submitFirebaseInfinityCount(_ count: Int, service: LeaderboardService) async throws {
    let displayName = Auth.auth().currentUser?.displayName ?? UserLeaderboardData.playerName
    
    // Hall of Fame uses a special format where we place the infinity count in the runScore
    // The highestTile is technically fixed, but we provide realistic values to pass validation.
    let runData = GameRunData(
        highestTile: 2,
        highestTileStep: 2,
        secondsToHighest: 0,
        movesToHighest: 0,
        runScore: count
    )
    
    try await service.submit(
        to: .mode("hallOfFame"),
        runData: runData,
        displayName: displayName
    )
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
    let board = mapFilterToBoard(period: period, filter: filter)
    
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
    
    let board = mapFilterToBoard(period: period, filter: filter)
    
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

private func mapFilterToBoard(period: LeaderboardPeriod, filter: LeaderboardFilter) -> LeaderboardBoard {
    switch filter {
    case .global:
        switch period {
        case .today:
            return .daily(date: Date())
        case .week, .allTime:
            // For now, map to global. In a real implementation, you might have weekly boards
            return .global
        }
    case .hallOfFame:
        return .mode("hallOfFame")
    case .country:
        let code = filter.countryCode ?? UserLeaderboardData.currentCountry
        return .mode("country_\(code.lowercased())")
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
    
    let compositeScore = Int64(firebaseEntry.value) ?? 0
    let decoded = CompositeScore.decode(compositeScore)
    let highestTileDisplay = formatTileForDisplay(
        tile: firebaseEntry.highestTile,
        step: firebaseEntry.highestTileStep
    )
    
    return LeaderboardEntry(
        id: firebaseEntry.uid,
        rank: rank ?? 1,
        name: firebaseEntry.displayName,
        score: firebaseEntry.runScore > 0 ? firebaseEntry.runScore : decoded.score,
        countryCode: nil, // Firebase doesn't store country code by default
        platform: .ios, // Assume iOS for now
        isMe: isCurrentUser,
        avatarURL: nil,
        highestTile: highestTileDisplay
    )
}

private func formatTileForDisplay(tile: Int, step: Int?) -> String {
    if let step {
        return TileStepLabelFormatter.labelForStep(step, start: 2)
    }
    return TileStepLabelFormatter.formatTileValue(tile)
}

private func estimateHighestTileFromScore(_ score: Int) -> Int {
    // Legacy fallback for score-only leaderboard rows written before
    // `highestTileStep` was included in the Cloud Function payload.
    
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

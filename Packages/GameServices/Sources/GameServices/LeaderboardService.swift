import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

/// Service for managing Firebase-based leaderboards
@MainActor
public final class LeaderboardService: @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let functions: Functions
    private let firestore: Firestore
    private let auth: Auth
    
    // MARK: - Initialization
    
    public init(
        functions: Functions = Functions.functions(),
        firestore: Firestore = Firestore.firestore(),
        auth: Auth = Auth.auth()
    ) {
        self.functions = functions
        self.firestore = firestore
        self.auth = auth
    }
    
    // MARK: - Public Interface
    
    /// Submits a score to the specified leaderboard
    /// - Parameters:
    ///   - board: The leaderboard to submit to
    ///   - runData: Game run data containing score information
    ///   - displayName: Player display name
    /// - Throws: LeaderboardError on submission failure
    public func submit(
        to board: LeaderboardBoard,
        runData: GameRunData,
        displayName: String
    ) async throws {
        // Ensure user is authenticated
        guard auth.currentUser != nil else {
            throw LeaderboardError.notAuthenticated
        }
        
        let submission = LeaderboardSubmission(
            boardId: board.identifier,
            runData: runData,
            displayName: displayName
        )
        
        do {
            let callable = functions.httpsCallable("submitScore")
            let data: [String: Any] = [
                "boardId": submission.boardId,
                "highestTile": submission.runData.highestTile,
                "secondsToHighest": submission.runData.secondsToHighest,
                "movesToHighest": submission.runData.movesToHighest,
                "runScore": submission.runData.runScore,
                "displayName": submission.displayName
            ]
            
            _ = try await callable.call(data)
            
        } catch {
            throw LeaderboardError.submissionFailed(error)
        }
    }
    
    /// Fetches top entries from the specified leaderboard
    /// - Parameters:
    ///   - board: The leaderboard to fetch from
    ///   - limit: Maximum number of entries to return (default: 50)
    /// - Returns: Array of leaderboard entries sorted by score descending
    /// - Throws: LeaderboardError on fetch failure
    public func fetchTopEntries(
        from board: LeaderboardBoard,
        limit: Int = 50
    ) async throws -> [LeaderboardEntry] {
        do {
            let snapshot = try await firestore
                .collection("leaderboards")
                .document(board.identifier)
                .collection("scores")
                .order(by: "value", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: LeaderboardEntry.self)
            }
            
        } catch {
            throw LeaderboardError.fetchFailed(error)
        }
    }
    
    /// Fetches the current user's entry from the specified leaderboard
    /// - Parameter board: The leaderboard to fetch from
    /// - Returns: User's leaderboard entry if it exists
    /// - Throws: LeaderboardError on fetch failure
    public func fetchUserEntry(from board: LeaderboardBoard) async throws -> LeaderboardEntry? {
        guard let uid = auth.currentUser?.uid else {
            throw LeaderboardError.notAuthenticated
        }
        
        do {
            let document = try await firestore
                .collection("leaderboards")
                .document(board.identifier)
                .collection("scores")
                .document(uid)
                .getDocument()
            
            guard document.exists else { return nil }
            
            return try document.data(as: LeaderboardEntry.self)
            
        } catch {
            throw LeaderboardError.fetchFailed(error)
        }
    }
    
    /// Fetches user's rank in the specified leaderboard
    /// - Parameter board: The leaderboard to check rank in
    /// - Returns: User's rank (1-based) or nil if not ranked
    /// - Throws: LeaderboardError on fetch failure
    public func fetchUserRank(in board: LeaderboardBoard) async throws -> Int? {
        guard let userEntry = try await fetchUserEntry(from: board) else {
            return nil
        }
        
        guard let userScore = Int64(userEntry.value) else {
            throw LeaderboardError.invalidData
        }
        
        do {
            let snapshot = try await firestore
                .collection("leaderboards")
                .document(board.identifier)
                .collection("scores")
                .whereField("value", isGreaterThan: userEntry.value)
                .getDocuments()
            
            return snapshot.documents.count + 1
            
        } catch {
            throw LeaderboardError.fetchFailed(error)
        }
    }
    
    /// Fetches leaderboard entries around the current user's position
    /// - Parameters:
    ///   - board: The leaderboard to fetch from
    ///   - context: Number of entries above and below user (default: 5)
    /// - Returns: Array of entries around user's position
    /// - Throws: LeaderboardError on fetch failure
    public func fetchEntriesAroundUser(
        from board: LeaderboardBoard,
        context: Int = 5
    ) async throws -> [LeaderboardEntry] {
        guard let userEntry = try await fetchUserEntry(from: board) else {
            return []
        }
        
        // This is a simplified implementation
        // In a production app, you might want to implement proper pagination
        // around the user's position using Firestore queries
        
        let allEntries = try await fetchTopEntries(from: board, limit: 1000)
        
        if let userIndex = allEntries.firstIndex(where: { $0.uid == userEntry.uid }) {
            let start = max(0, userIndex - context)
            let end = min(allEntries.count, userIndex + context + 1)
            return Array(allEntries[start..<end])
        }
        
        return [userEntry]
    }
}

// MARK: - Error Handling

public enum LeaderboardError: LocalizedError, Sendable {
    case notAuthenticated
    case submissionFailed(Error)
    case fetchFailed(Error)
    case invalidData
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User must be authenticated to access leaderboards"
        case .submissionFailed(let error):
            return "Failed to submit score: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch leaderboard data: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid leaderboard data received"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Mock Implementation for Testing

public final class MockLeaderboardService: LeaderboardService {
    
    private var mockEntries: [String: [LeaderboardEntry]] = [:]
    private var shouldFailSubmission = false
    private var shouldFailFetch = false
    
    public override init(
        functions: Functions = Functions.functions(),
        firestore: Firestore = Firestore.firestore(),
        auth: Auth = Auth.auth()
    ) {
        super.init(functions: functions, firestore: firestore, auth: auth)
        setupMockData()
    }
    
    public func setShouldFailSubmission(_ shouldFail: Bool) {
        shouldFailSubmission = shouldFail
    }
    
    public func setShouldFailFetch(_ shouldFail: Bool) {
        shouldFailFetch = shouldFail
    }
    
    public override func submit(
        to board: LeaderboardBoard,
        runData: GameRunData,
        displayName: String
    ) async throws {
        if shouldFailSubmission {
            throw LeaderboardError.submissionFailed(NSError(domain: "Mock", code: 1))
        }
        
        let entry = LeaderboardEntry(
            uid: "mock-uid",
            displayName: displayName,
            value: String(runData.compositeScore),
            highestTile: runData.highestTile,
            movesToHighest: runData.movesToHighest,
            secondsToHighest: runData.secondsToHighest,
            runScore: runData.runScore,
            achievedAt: Date()
        )
        
        var entries = mockEntries[board.identifier] ?? []
        entries.append(entry)
        entries.sort { Int64($0.value) ?? 0 > Int64($1.value) ?? 0 }
        mockEntries[board.identifier] = entries
    }
    
    public override func fetchTopEntries(
        from board: LeaderboardBoard,
        limit: Int = 50
    ) async throws -> [LeaderboardEntry] {
        if shouldFailFetch {
            throw LeaderboardError.fetchFailed(NSError(domain: "Mock", code: 1))
        }
        
        let entries = mockEntries[board.identifier] ?? []
        return Array(entries.prefix(limit))
    }
    
    private func setupMockData() {
        let mockEntries = [
            LeaderboardEntry(
                uid: "player1",
                displayName: "Player 1",
                value: String(CompositeScore.encode(highestTile: 2048, seconds: 300, moves: 150, score: 25000)),
                highestTile: 2048,
                movesToHighest: 150,
                secondsToHighest: 300,
                runScore: 25000
            ),
            LeaderboardEntry(
                uid: "player2",
                displayName: "Player 2",
                value: String(CompositeScore.encode(highestTile: 1024, seconds: 250, moves: 120, score: 15000)),
                highestTile: 1024,
                movesToHighest: 120,
                secondsToHighest: 250,
                runScore: 15000
            ),
            LeaderboardEntry(
                uid: "player3",
                displayName: "Player 3",
                value: String(CompositeScore.encode(highestTile: 512, seconds: 200, moves: 100, score: 8000)),
                highestTile: 512,
                movesToHighest: 100,
                secondsToHighest: 200,
                runScore: 8000
            )
        ]
        
        self.mockEntries["global"] = mockEntries
        self.mockEntries["daily:\(ISO8601DateFormatter().string(from: Date()))"] = mockEntries
    }
}
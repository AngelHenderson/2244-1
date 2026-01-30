import Foundation
#if canImport(GameKit)
import GameKit
#endif

public protocol GameCenterServiceProtocol: Sendable {
    func authenticate() async -> Bool
    func submit(score: Int, leaderboard: String) async throws
    var isAuthenticated: Bool { get async }
    var displayName: String { get async }
}

// Real Game Center service implementation
public actor DefaultGameCenterService: GameCenterServiceProtocol, Sendable {
    public private(set) var lastSubmitted: (score: Int, leaderboard: String)?
    private var authenticationComplete = false

    public init() {}

    public var isAuthenticated: Bool {
        #if canImport(GameKit)
        return GKLocalPlayer.local.isAuthenticated
        #else
        return false
        #endif
    }

    public var displayName: String {
        #if canImport(GameKit)
        return GKLocalPlayer.local.displayName
        #else
        return ""
        #endif
    }

    public func authenticate() async -> Bool {
        #if canImport(GameKit)
        return await withCheckedContinuation { continuation in
            GKLocalPlayer.local.authenticateHandler = { viewController, error in
                if let error = error {
                    print("Game Center auth error: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }

                // If viewController is returned, user needs to sign in via Settings
                // We can't present it here, so just return current auth state
                continuation.resume(returning: GKLocalPlayer.local.isAuthenticated)
            }
        }
        #else
        return false
        #endif
    }

    public func submit(score: Int, leaderboard: String) async throws {
        lastSubmitted = (score: score, leaderboard: leaderboard)

        #if canImport(GameKit)
        guard GKLocalPlayer.local.isAuthenticated else {
            throw NSError(domain: "GameCenter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        try await GKLeaderboard.submitScore(
            score,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [leaderboard]
        )
        #endif
    }
}

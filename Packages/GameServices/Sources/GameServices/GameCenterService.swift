import Foundation

public protocol GameCenterServiceProtocol: Sendable {
    func authenticate() async -> Bool
    func submit(score: Int, leaderboard: String) async throws
}

public actor DefaultGameCenterService: GameCenterServiceProtocol, Sendable {
    public private(set) var lastSubmitted: (score: Int, leaderboard: String)?
    
    public init() {}
    
    public func authenticate() async -> Bool {
        true
    }
    
    public func submit(score: Int, leaderboard: String) async throws {
        lastSubmitted = (score: score, leaderboard: leaderboard)
    }
}





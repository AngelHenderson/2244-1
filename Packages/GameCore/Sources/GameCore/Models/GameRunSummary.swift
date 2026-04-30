import Foundation

public struct GameRunSummary: Codable, Equatable, Sendable {
    public let id: String
    public let score: Int
    public let scoreAlpha: AlphaNumber
    public let highestTile: Int
    public let highestTileStep: Int
    public let moves: Int
    public let duration: TimeInterval
    public let seed: UInt64
    public let infinityMergeCount: Int
    public let endedAt: Date

    public init(
        id: String? = nil,
        score: Int,
        scoreAlpha: AlphaNumber,
        highestTile: Int,
        highestTileStep: Int,
        moves: Int,
        duration: TimeInterval,
        seed: UInt64,
        infinityMergeCount: Int,
        endedAt: Date = Date()
    ) {
        self.id = id ?? Self.makeID(
            seed: seed,
            moves: moves,
            score: score,
            highestTileStep: highestTileStep,
            infinityMergeCount: infinityMergeCount
        )
        self.score = score
        self.scoreAlpha = scoreAlpha
        self.highestTile = highestTile
        self.highestTileStep = highestTileStep
        self.moves = moves
        self.duration = max(0, duration)
        self.seed = seed
        self.infinityMergeCount = infinityMergeCount
        self.endedAt = endedAt
    }

    public static func makeID(
        seed: UInt64,
        moves: Int,
        score: Int,
        highestTileStep: Int,
        infinityMergeCount: Int
    ) -> String {
        "\(seed)-\(moves)-\(score)-\(highestTileStep)-\(infinityMergeCount)"
    }
}

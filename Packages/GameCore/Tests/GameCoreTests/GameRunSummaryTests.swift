import Testing
import Foundation
@testable import GameCore

@Suite("GameRunSummary")
struct GameRunSummaryTests {
    @Test("Generates a stable id from seed/moves/score/step/infinity counts")
    func stableIDFromKeyFields() {
        let summary = GameRunSummary(
            score: 1234,
            scoreAlpha: AlphaNumber(1234),
            highestTile: 256,
            highestTileStep: 7,
            moves: 42,
            duration: 65.0,
            seed: 9001,
            infinityMergeCount: 0
        )
        #expect(summary.id == "9001-42-1234-7-0")
    }

    @Test("Negative duration clamps to zero")
    func negativeDurationClamps() {
        let summary = GameRunSummary(
            score: 0,
            scoreAlpha: AlphaNumber(0),
            highestTile: 4,
            highestTileStep: 1,
            moves: 1,
            duration: -50,
            seed: 1,
            infinityMergeCount: 0
        )
        #expect(summary.duration == 0)
    }

    @Test("Encodes/decodes through JSON without loss")
    func roundTripsThroughJSON() throws {
        let summary = GameRunSummary(
            score: 99,
            scoreAlpha: AlphaNumber(99),
            highestTile: 8,
            highestTileStep: 2,
            moves: 7,
            duration: 12.5,
            seed: 42,
            infinityMergeCount: 1
        )
        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(GameRunSummary.self, from: data)
        #expect(decoded == summary)
    }

    @Test("GameRunData accepts a GameRunSummary directly")
    func gameRunDataFromSummary() {
        let summary = GameRunSummary(
            score: 250,
            scoreAlpha: AlphaNumber(250),
            highestTile: 64,
            highestTileStep: 5,
            moves: 18,
            duration: 31,
            seed: 7,
            infinityMergeCount: 0
        )
        let runData = GameRunData(summary: summary)
        #expect(runData.highestTile == summary.highestTile)
        #expect(runData.highestTileStep == summary.highestTileStep)
        #expect(runData.movesToHighest == summary.moves)
        #expect(runData.runScore == summary.score)
        #expect(runData.secondsToHighest == 31)
    }

    @Test("CompositeScore.encode prefers explicit step over log2(highestTile)")
    func compositeUsesProvidedStep() {
        // For very high values where log2 might be inaccurate, the explicit
        // step is the source of truth. Here we use a step of 30 and a tile
        // value below it to assert the step wins.
        let composite = CompositeScore.encode(
            highestTile: 4, // step 1 if derived
            highestTileStep: 30,
            seconds: 0,
            moves: 0,
            score: 0
        )
        let derived = CompositeScore.encode(
            highestTile: 4,
            seconds: 0,
            moves: 0,
            score: 0
        )
        #expect(composite > derived)
    }
}

import Testing
@testable import GameCore

@Suite("Challenge Target Satisfaction")
struct ChallengeTargetTests {
    @Test("Chain target completes from tracked longest chain length")
    func chainTargetUsesLongestChainLength() {
        let target = ChallengeTarget.chain(length: 7)

        #expect(!target.isSatisfied(
            score: 0,
            highestTile: 2,
            highestTileStep: 0,
            containsInfinityTile: false,
            longestChainLength: 6
        ))
        #expect(target.isSatisfied(
            score: 0,
            highestTile: 2,
            highestTileStep: 0,
            containsInfinityTile: false,
            longestChainLength: 7
        ))
    }

    @Test("Infinity step target requires an infinity tile")
    func infinityTargetRequiresInfinityTile() {
        let target = ChallengeTarget.tileStep(Int.max)

        #expect(!target.isSatisfied(
            score: 0,
            highestTile: Int.max,
            highestTileStep: Int.max,
            containsInfinityTile: false,
            longestChainLength: 0
        ))
        #expect(target.isSatisfied(
            score: 0,
            highestTile: Int.max,
            highestTileStep: Int.max,
            containsInfinityTile: true,
            longestChainLength: 0
        ))
    }
}

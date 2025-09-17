import Testing
@testable import GameCore

@Suite("Chain Validation Integration Tests")
struct ChainValidationTests {

    @Test("Chain [2,2,4,8] validates correctly")
    func standardChainValidation() async {
        let engine = GameEngine()
        let board = Board(columns: 5, rows: 8)

        let tiles = [
            Tile(value: 2),
            Tile(value: 2),
            Tile(value: 4),
            Tile(value: 8)
        ]

        let positions = [
            Position(x: 0, y: 0),
            Position(x: 1, y: 0),
            Position(x: 2, y: 0),
            Position(x: 3, y: 0)
        ]

        let chain = Chain(tiles: tiles, positions: positions)
        let result = engine.validateChain(chain, on: board)

        #expect(result.isValid == true)
        #expect(result.mergedValue == 16)
        #expect(result.score > 0)
    }

    @Test("Invalid chains are rejected")
    func invalidChainRejection() async {
        let engine = GameEngine()
        let board = Board(columns: 5, rows: 8)

        let invalidChain1 = Chain(
            tiles: [Tile(value: 2), Tile(value: 4)],
            positions: [Position(x: 0, y: 0), Position(x: 1, y: 0)]
        )

        let result1 = engine.validateChain(invalidChain1, on: board)
        #expect(result1.isValid == false)

        let invalidChain2 = Chain(
            tiles: [Tile(value: 2), Tile(value: 2), Tile(value: 5)],
            positions: [
                Position(x: 0, y: 0),
                Position(x: 1, y: 0),
                Position(x: 2, y: 0)
            ]
        )

        let result2 = engine.validateChain(invalidChain2, on: board)
        #expect(result2.isValid == false)
    }

    @Test("Non-adjacent tiles are invalid")
    func nonAdjacentTilesInvalid() async {
        let engine = GameEngine()
        let board = Board(columns: 5, rows: 8)

        let chain = Chain(
            tiles: [Tile(value: 2), Tile(value: 2)],
            positions: [Position(x: 0, y: 0), Position(x: 3, y: 3)]
        )

        let result = engine.validateChain(chain, on: board)
        #expect(result.isValid == false)
        #expect(result.errorReason == .notAdjacent)
    }
}

struct Chain {
    let tiles: [Tile]
    let positions: [Position]
}

struct ChainValidationResult {
    let isValid: Bool
    let mergedValue: Int
    let score: Int
    let errorReason: ChainError?
}

enum ChainError {
    case tooShort
    case firstTwoNotEqual
    case invalidProgression
    case notAdjacent
}

extension GameEngine {
    func validateChain(_ chain: Chain, on board: Board) -> ChainValidationResult {
        guard chain.tiles.count >= 2 else {
            return ChainValidationResult(
                isValid: false,
                mergedValue: 0,
                score: 0,
                errorReason: .tooShort
            )
        }

        guard chain.tiles[0].value == chain.tiles[1].value else {
            return ChainValidationResult(
                isValid: false,
                mergedValue: 0,
                score: 0,
                errorReason: .firstTwoNotEqual
            )
        }

        for i in 2..<chain.tiles.count {
            let current = chain.tiles[i].value
            let previous = chain.tiles[i - 1].value
            if current != previous && current != previous * 2 {
                return ChainValidationResult(
                    isValid: false,
                    mergedValue: 0,
                    score: 0,
                    errorReason: .invalidProgression
                )
            }
        }

        if !board.areAdjacent(chain.positions) {
            return ChainValidationResult(
                isValid: false,
                mergedValue: 0,
                score: 0,
                errorReason: .notAdjacent
            )
        }

        let mergedValue = chain.tiles.last!.value * 2
        let score = chain.tiles.reduce(0) { $0 + $1.value }

        return ChainValidationResult(
            isValid: true,
            mergedValue: mergedValue,
            score: score,
            errorReason: nil
        )
    }
}
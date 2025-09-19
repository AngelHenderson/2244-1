import Testing
@testable import GameCore

@Suite("GameSession Contract Tests")
struct GameSessionContractTests {

    @Test("GameSession has 5×8 fixed board dimensions")
    func fixedBoardDimensions() async {
        let session = GameSession()

        #expect(session.board.columns == 5)
        #expect(session.board.rows == 8)
        #expect(session.board.tiles.count == 40)
    }

    @Test("Board supports tile placement at positions")
    func tilePlacementAtPositions() async {
        var session = GameSession()

        let tile = Tile(value: 2)
        session.board.place(tile, at: Position(row: 3, col: 2))

        let placedTile = session.board.tile(at: Position(row: 3, col: 2))
        #expect(placedTile?.value == 2)
    }

    @Test("Board validates chain with first two equal rule")
    func chainValidationFirstTwoEqual() async {
        let validator = ChainValidator()

        let chain1 = [
            Tile(value: 2),
            Tile(value: 2),
            Tile(value: 4),
            Tile(value: 8)
        ]
        #expect(validator.isValid(chain: chain1) == true)

        let chain2 = [
            Tile(value: 2),
            Tile(value: 4),
            Tile(value: 8)
        ]
        #expect(validator.isValid(chain: chain2) == false)
    }

    @Test("Board validates subsequent tiles same or double")
    func chainValidationSubsequentTiles() async {
        let validator = ChainValidator()

        let validChain = [
            Tile(value: 2),
            Tile(value: 2),
            Tile(value: 2),
            Tile(value: 4),
            Tile(value: 8)
        ]
        #expect(validator.isValid(chain: validChain) == true)

        let invalidChain = [
            Tile(value: 2),
            Tile(value: 2),
            Tile(value: 5)
        ]
        #expect(validator.isValid(chain: invalidChain) == false)
    }

    @Test("Board validates adjacency for chains")
    func chainAdjacencyValidation() async {
        let session = GameSession()

        let positions = [
            Position(row: 0, col: 0),
            Position(row: 0, col: 1),
            Position(row: 1, col: 1),
            Position(row: 1, col: 2)
        ]

        #expect(session.board.areAdjacent(positions) == true)

        let nonAdjacentPositions = [
            Position(row: 0, col: 0),
            Position(row: 2, col: 2)
        ]

        #expect(session.board.areAdjacent(nonAdjacentPositions) == false)
    }

    @Test("GameSession tracks score and moves")
    func tracksScoreAndMoves() async {
        let session = GameSession()

        #expect(session.score == 0)
        #expect(session.moves == 0)
        #expect(session.mergesCount == 0)
    }

    @Test("GameSession supports game modes")
    func supportsGameModes() async {
        let classicSession = GameSession(mode: .classic)
        #expect(classicSession.mode == .classic)

        let journeySession = GameSession(mode: .journey)
        #expect(journeySession.mode == .journey)

        let dailySession = GameSession(mode: .daily)
        #expect(dailySession.mode == .daily)
    }
}

struct GameSession {
    var board: Board
    let mode: GameMode
    var score: Int = 0
    var moves: Int = 0
    var mergesCount: Int = 0

    init(mode: GameMode = .classic) {
        self.mode = mode
        self.board = Board(columns: 5, rows: 8)
    }
}

enum GameMode {
    case classic
    case journey
    case daily
    case challenge
}

struct Board {
    let columns: Int
    let rows: Int
    var tiles: [Position: Tile] = [:]

    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
    }

    mutating func place(_ tile: Tile, at position: Position) {
        tiles[position] = tile
    }

    func tile(at position: Position) -> Tile? {
        return tiles[position]
    }

    func areAdjacent(_ positions: [Position]) -> Bool {
        guard positions.count > 1 else { return true }

        for i in 1..<positions.count {
            let current = positions[i]
            let previous = positions[i - 1]

            let dx = abs(current.col - previous.col)
            let dy = abs(current.row - previous.row)

            if dx > 1 || dy > 1 {
                return false
            }
        }

        return true
    }
}

struct ChainValidator {
    func isValid(chain: [Tile]) -> Bool {
        guard chain.count >= 2 else { return false }

        guard chain[0].value == chain[1].value else {
            return false
        }

        for i in 2..<chain.count {
            let current = chain[i].value
            let previous = chain[i - 1].value

            if current != previous && current != previous * 2 {
                return false
            }
        }

        return true
    }
}
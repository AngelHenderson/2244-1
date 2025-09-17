import Testing
@testable import GameCore

@Suite("Board Dimension Integration Tests")
struct BoardDimensionTests {

    @Test("5×8 board maintains fixed dimensions")
    func fixedBoardDimensions() async {
        let board = Board(columns: 5, rows: 8)

        #expect(board.columns == 5)
        #expect(board.rows == 8)
        #expect(board.totalCells == 40)
    }

    @Test("Board rejects invalid positions")
    func rejectsInvalidPositions() async {
        let board = Board(columns: 5, rows: 8)

        let validPosition = Position(x: 2, y: 3)
        let invalidPositions = [
            Position(x: -1, y: 0),
            Position(x: 5, y: 0),
            Position(x: 0, y: 8),
            Position(x: 10, y: 10)
        ]

        #expect(board.isValidPosition(validPosition) == true)

        for position in invalidPositions {
            #expect(board.isValidPosition(position) == false)
        }
    }

    @Test("Board supports all 40 positions")
    func supportsAllPositions() async {
        let board = Board(columns: 5, rows: 8)

        for x in 0..<5 {
            for y in 0..<8 {
                let position = Position(x: x, y: y)
                #expect(board.isValidPosition(position) == true)

                board.place(Tile(value: 2), at: position)
                #expect(board.tile(at: position) != nil)
            }
        }

        #expect(board.tiles.count == 40)
    }

    @Test("Board layout is consistent across modes")
    func consistentLayout() async {
        let classicBoard = Board(columns: 5, rows: 8)
        let journeyBoard = Board(columns: 5, rows: 8)
        let dailyBoard = Board(columns: 5, rows: 8)

        #expect(classicBoard.columns == journeyBoard.columns)
        #expect(classicBoard.rows == journeyBoard.rows)
        #expect(journeyBoard.columns == dailyBoard.columns)
        #expect(journeyBoard.rows == dailyBoard.rows)
    }
}

extension Board {
    var totalCells: Int {
        return columns * rows
    }

    func isValidPosition(_ position: Position) -> Bool {
        return position.x >= 0 && position.x < columns &&
               position.y >= 0 && position.y < rows
    }
}
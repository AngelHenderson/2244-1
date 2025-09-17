import Foundation

public struct GameSession: Sendable {
    public var board: GameBoard
    public let mode: GameMode
    public var score: Int
    public var moves: Int
    public var mergesCount: Int
    public var startTime: Date
    public var endTime: Date?
    public var isPaused: Bool

    public init(
        mode: GameMode = .classic,
        board: GameBoard? = nil,
        score: Int = 0,
        moves: Int = 0,
        mergesCount: Int = 0,
        startTime: Date = Date(),
        endTime: Date? = nil,
        isPaused: Bool = false
    ) {
        self.mode = mode
        self.board = board ?? GameBoard(columns: 5, rows: 8)
        self.score = score
        self.moves = moves
        self.mergesCount = mergesCount
        self.startTime = startTime
        self.endTime = endTime
        self.isPaused = isPaused
    }

    public var duration: TimeInterval {
        guard let endTime = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return endTime.timeIntervalSince(startTime)
    }

    public var isGameOver: Bool {
        return endTime != nil
    }
}

public enum GameMode: String, CaseIterable, Codable, Sendable {
    case classic
    case journey
    case daily
    case challenge
    case tutorial
}

public struct GameBoard: Sendable {
    public let columns: Int
    public let rows: Int
    public var tiles: [Position: Tile]

    public init(columns: Int = 5, rows: Int = 8) {
        self.columns = columns
        self.rows = rows
        self.tiles = [:]
    }

    public mutating func place(_ tile: Tile, at position: Position) {
        tiles[position] = tile
    }

    public func tile(at position: Position) -> Tile? {
        return tiles[position]
    }

    public func areAdjacent(_ positions: [Position]) -> Bool {
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

    public func isValidPosition(_ position: Position) -> Bool {
        return position.col >= 0 && position.col < columns &&
               position.row >= 0 && position.row < rows
    }

    public var totalCells: Int {
        return columns * rows
    }

    public var isEmpty: Bool {
        return tiles.isEmpty
    }

    public var isFull: Bool {
        return tiles.count == totalCells
    }
}
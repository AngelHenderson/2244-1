import Foundation

public struct Position: Equatable, Hashable, Sendable, Codable {
    public let row: Int
    public let col: Int
    
    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }
    
    public func isValid(for board: Board) -> Bool {
        row >= 0 && row < board.height && col >= 0 && col < board.width
    }
    
    public func moved(in direction: Direction) -> Position {
        Position(row: row + direction.rowDelta, col: col + direction.colDelta)
    }
    
    public func isAdjacent(to other: Position) -> Bool {
        let rowDiff = abs(row - other.row)
        let colDiff = abs(col - other.col)
        // Allow orthogonal and diagonal adjacency (8 directions)
        return rowDiff <= 1 && colDiff <= 1 && (rowDiff != 0 || colDiff != 0)
    }
}

public enum Direction: CaseIterable, Sendable {
    case up, down, left, right
    case upLeft, upRight, downLeft, downRight
    
    var rowDelta: Int {
        switch self {
        case .up, .upLeft, .upRight: return -1
        case .down, .downLeft, .downRight: return 1
        case .left, .right: return 0
        }
    }
    
    var colDelta: Int {
        switch self {
        case .left, .upLeft, .downLeft: return -1
        case .right, .upRight, .downRight: return 1
        case .up, .down: return 0
        }
    }
}
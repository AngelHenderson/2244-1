import Foundation

public enum TileType: Equatable, Hashable, Sendable {
    case normal
    case infinity
    case locked
    case bomb(turnsRemaining: Int)
}

public struct Tile: Equatable, Hashable, Sendable {
    public let id: UUID
    public let value: Int
    public let type: TileType
    
    public init(value: Int, type: TileType = .normal) {
        self.id = UUID()
        self.value = value
        self.type = type
    }
    
    public var isInfinity: Bool {
        type == .infinity
    }
    
    public var isLocked: Bool {
        type == .locked
    }
    
    public var isBomb: Bool {
        if case .bomb = type {
            return true
        }
        return false
    }
    
    public var canMerge: Bool {
        type == .normal
    }
}
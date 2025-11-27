import Foundation

public enum TileType: Equatable, Hashable, Sendable, Codable {
    case normal
    case infinity
    case locked
    case bomb(turnsRemaining: Int)
    case highValue(step: Int)  // For tiles beyond Int.max, track the doubling step
}

public struct Tile: Equatable, Hashable, Sendable, Codable {
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
        switch type {
        case .normal, .highValue:
            return true
        default:
            return false
        }
    }
}

public extension Tile {
    var stepIndex: Int? {
        switch type {
        case .highValue(let step):
            return step
        default:
            return Tile.stepIndex(forValue: value)
        }
    }
    
    static func make(forStep step: Int) -> Tile {
        let shift = step + 1
        if shift > 0 && shift < Int.bitWidth {
            return Tile(value: 1 << shift)
        } else {
            return Tile(value: Int.max, type: .highValue(step: step))
        }
    }
    
    static func approximateValue(forStep step: Int) -> Int {
        let shift = step + 1
        if shift > 0 && shift < Int.bitWidth {
            return 1 << shift
        }
        return Int.max
    }
    
    func matches(_ other: Tile) -> Bool {
        if let leftStep = self.stepIndex,
           let rightStep = other.stepIndex {
            return leftStep == rightStep
        }
        return value == other.value
    }
    
    private static func stepIndex(forValue value: Int) -> Int? {
        guard value > 0 else { return nil }
        if value & (value - 1) == 0 {
            let trailing = value.trailingZeroBitCount
            return max(0, trailing - 1)
        }
        // Fallback: use floating-point log if value isn't an exact power of two.
        let approx = Int(log2(Double(value)))
        return max(0, approx - 1)
    }
}
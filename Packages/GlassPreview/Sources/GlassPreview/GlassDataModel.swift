import Foundation
import GameCore

// MARK: - Glass Preview Data Model

/// Tile state for glass preview functionality
public enum TileState: Equatable, Sendable {
    case normal
    case preview(glass: Bool)    // Only lives in the preview row
}

/// Enhanced tile with glass state support
public struct GlassTile: Identifiable, Equatable, Sendable {
    public let id: UUID = UUID()
    public let value: Int               // 2,4,8,…
    public let state: TileState
    
    public init(value: Int, state: TileState = .normal) {
        self.value = value
        self.state = state
    }
    
    /// Create a glass preview tile
    public static func glassPreview(value: Int) -> GlassTile {
        GlassTile(value: value, state: .preview(glass: true))
    }
    
    /// Create a normal preview tile (glass already shattered)
    public static func normalPreview(value: Int) -> GlassTile {
        GlassTile(value: value, state: .preview(glass: false))
    }
    
    /// Create a normal board tile
    public static func normal(value: Int) -> GlassTile {
        GlassTile(value: value, state: .normal)
    }
    
    public var isGlass: Bool {
        if case .preview(glass: let isGlass) = state {
            return isGlass
        }
        return false
    }
    
    public var isPreview: Bool {
        if case .preview = state {
            return true
        }
        return false
    }
    
    public var isNormal: Bool {
        state == .normal
    }
}

/// Cell that can hold a glass tile
public struct GlassCell: Identifiable, Equatable, Sendable {
    public let id: UUID = UUID()
    public var tile: GlassTile?              // nil == empty
    
    public init(tile: GlassTile? = nil) {
        self.tile = tile
    }
}

/// Point coordinate for glass board
public struct Point: Equatable, Hashable, Sendable {
    public let col: Int
    public let row: Int
    
    public init(col: Int, row: Int) {
        self.col = col
        self.row = row
    }
    
    /// Check if this point is adjacent to another (8-direction)
    public func isAdjacent(to other: Point) -> Bool {
        let dx = abs(col - other.col)
        let dy = abs(row - other.row)
        return (dx <= 1 && dy <= 1) && !(dx == 0 && dy == 0)
    }
}

/// Power-up types for glass shatter rewards
public enum PowerUp: String, CaseIterable, Sendable {
    case hammer = "hammer"
    case swap = "swap"
    case magnet = "magnet"
    case shuffle = "shuffle"
    case undo = "undo"
    case bomb = "bomb"
    
    /// Default reward weights (can be configured via remote config)
    public static let defaultWeights: [PowerUp: Int] = [
        .hammer: 30,
        .swap: 20,
        .magnet: 15,
        .shuffle: 15,
        .undo: 15,
        .bomb: 5
    ]
}

/// Random number generator wrapper for deterministic behavior
public struct AnyRandomNumberGenerator: RandomNumberGenerator {
    private var generator: any RandomNumberGenerator
    
    public init<T: RandomNumberGenerator>(_ generator: T) {
        self.generator = generator
    }
    
    public mutating func next() -> UInt64 {
        generator.next()
    }
}

/// Simple Xoroshiro128+ implementation for deterministic RNG
public struct Xoroshiro: RandomNumberGenerator {
    private var state: (UInt64, UInt64)
    
    public init(seed: UInt64) {
        // Split seed into two parts for initial state
        state = (seed, seed &* 0x9e3779b97f4a7c15)
        // Warm up the generator
        for _ in 0..<10 {
            _ = next()
        }
    }
    
    public mutating func next() -> UInt64 {
        let result = state.0 &+ state.1
        state.1 ^= state.0
        state.0 = rotateLeft(state.0, by: 24) ^ state.1 ^ (state.1 << 16)
        state.1 = rotateLeft(state.1, by: 37)
        return result
    }
    
    private func rotateLeft(_ value: UInt64, by amount: Int) -> UInt64 {
        (value << amount) | (value >> (64 - amount))
    }
}

/// Weighted random selection helper
public func weightedPick<T>(weights: [(T, Int)], rng: inout AnyRandomNumberGenerator) -> T? {
    let totalWeight = weights.reduce(0) { $0 + $1.1 }
    guard totalWeight > 0 else { return nil }
    
    let randomValue = Int(rng.next() % UInt64(totalWeight))
    var currentWeight = 0
    
    for (item, weight) in weights {
        currentWeight += weight
        if randomValue < currentWeight {
            return item
        }
    }
    
    return weights.last?.0
}

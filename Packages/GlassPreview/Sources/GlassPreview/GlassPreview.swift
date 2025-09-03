import Foundation
import SwiftUI

// MARK: - Public API

/// Main entry point for the Glass Preview module
@MainActor
public struct GlassPreview {
    /// Create a new glass game view with default configuration
    public static func gameView(
        cols: Int = 5,
        rows: Int = 8,
        seed: UInt64? = nil,
        config: GlassGameStore.Config = GlassGameStore.Config()
    ) -> some View {
        let store = GlassGameStore(cols: cols, rows: rows, seed: seed, config: config)
        return GlassGameView(gameStore: store)
    }
    
    /// Create a glass game store for custom integration
    public static func gameStore(
        cols: Int = 5,
        rows: Int = 8,
        seed: UInt64? = nil,
        config: GlassGameStore.Config = GlassGameStore.Config()
    ) -> GlassGameStore {
        return GlassGameStore(cols: cols, rows: rows, seed: seed, config: config)
    }
    
    /// Default configuration with the specified background color
    public static var defaultConfig: GlassGameStore.Config {
        GlassGameStore.Config(backgroundColorHex: "#020617")
    }
    

}

// MARK: - Extensions for existing game integration

extension GlassGameStore {
    /// Convert to legacy GameCore format for compatibility
    public func toLegacyGameState() -> (board: [[Int?]], score: Int, moves: Int) {
        var legacyBoard: [[Int?]] = []
        
        for col in 0..<cols {
            var column: [Int?] = []
            for row in 0..<rows {
                column.append(grid[col][row].tile?.value)
            }
            legacyBoard.append(column)
        }
        
        return (board: legacyBoard, score: score, moves: moves)
    }
    
    /// Import from legacy GameCore format (simplified - creates new game)
    public static func fromLegacyGameState(
        board: [[Int?]],
        score: Int,
        moves: Int,
        seed: UInt64? = nil,
        config: Config = Config()
    ) -> GlassGameStore {
        let cols = board.count
        let rows = board.first?.count ?? 0
        
        // For now, just create a new store with the same dimensions
        // Full state restoration would need additional methods
        return GlassGameStore(cols: cols, rows: rows, seed: seed, config: config)
    }
}

// MARK: - Configuration Presets

extension GlassGameStore.Config {
    /// Balanced configuration for normal gameplay
    public static var balanced: GlassGameStore.Config {
        GlassGameStore.Config(
            giftWeights: [
                .hammer: 25,
                .swap: 20,
                .magnet: 20,
                .shuffle: 15,
                .undo: 15,
                .bomb: 5
            ],
            giftOnAutoDrop: false,
            requireDirectBelowInChain: true,
            backgroundColorHex: "#020617"
        )
    }
    
    /// Generous configuration with more frequent rewards
    public static var generous: GlassGameStore.Config {
        GlassGameStore.Config(
            giftWeights: [
                .hammer: 30,
                .swap: 25,
                .magnet: 20,
                .shuffle: 15,
                .undo: 8,
                .bomb: 2
            ],
            giftOnAutoDrop: true, // Award gifts on auto-drop
            requireDirectBelowInChain: false, // More lenient chain rules
            backgroundColorHex: "#020617"
        )
    }
    
    /// Challenging configuration with fewer rewards
    public static var challenging: GlassGameStore.Config {
        GlassGameStore.Config(
            giftWeights: [
                .hammer: 20,
                .swap: 15,
                .magnet: 10,
                .shuffle: 10,
                .undo: 5,
                .bomb: 40 // More destructive rewards
            ],
            giftOnAutoDrop: false,
            requireDirectBelowInChain: true,
            backgroundColorHex: "#020617",
            spawnWeights: [2: 0.5, 4: 0.3, 8: 0.2] // Harder starting tiles
        )
    }
}

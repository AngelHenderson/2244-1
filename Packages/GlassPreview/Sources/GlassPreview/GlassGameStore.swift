import Foundation
import SwiftUI
import GameCore
import Observation

@Observable
@MainActor
public final class GlassGameStore {
    // MARK: - Board Configuration
    public let cols: Int
    public let rows: Int
    
    // MARK: - Game State
    public private(set) var grid: [[GlassCell]]           // [col][row]
    public private(set) var preview: [[GlassTile]]        // Preview queues per column
    public private(set) var score: Int = 0
    public private(set) var moves: Int = 0
    public private(set) var isGameOver: Bool = false
    
    // MARK: - Chain Building
    public private(set) var currentChain: [Point] = []
    public private(set) var chainValidation: String? = nil
    
    // MARK: - Power-ups & RNG
    public private(set) var powerups: [PowerUp: Int] = [:]
    private var rng: AnyRandomNumberGenerator
    public let sessionSeed: UInt64
    private var glassBreakIndex: Int = 0
    
    // MARK: - Analytics & Events
    public struct AnalyticsEvent: Sendable {
        public let type: String
        public let parameters: [String: String]
        public let timestamp: Date = Date()
    }
    public private(set) var analyticsEvents: [AnalyticsEvent] = []
    
    // MARK: - Configuration
    public struct Config: Sendable {
        public let giftWeights: [PowerUp: Int]
        public let giftOnAutoDrop: Bool
        public let requireDirectBelowInChain: Bool
        public let backgroundColorHex: String
        public let spawnWeights: [Int: Double]
        
        public init(
            giftWeights: [PowerUp: Int] = PowerUp.defaultWeights,
            giftOnAutoDrop: Bool = false,
            requireDirectBelowInChain: Bool = true,
            backgroundColorHex: String = "#020617",
            spawnWeights: [Int: Double] = [2: 0.7, 4: 0.25, 8: 0.05]
        ) {
            self.giftWeights = giftWeights
            self.giftOnAutoDrop = giftOnAutoDrop
            self.requireDirectBelowInChain = requireDirectBelowInChain
            self.backgroundColorHex = backgroundColorHex
            self.spawnWeights = spawnWeights
        }
    }
    
    public let config: Config
    
    public init(cols: Int = 5, rows: Int = 8, seed: UInt64? = nil, config: Config = Config()) {
        self.cols = cols
        self.rows = rows
        self.config = config
        
        // Initialize seed
        let actualSeed = seed ?? UInt64(Date().timeIntervalSince1970 * 1000)
        self.sessionSeed = actualSeed
        self.rng = AnyRandomNumberGenerator(Xoroshiro(seed: actualSeed))
        
        // Initialize grid
        self.grid = (0..<cols).map { _ in
            (0..<rows).map { _ in GlassCell() }
        }
        
        // Initialize preview queues
        self.preview = (0..<cols).map { _ in [] }
        
        // Bootstrap initial state
        bootstrapPreview()
        fillBoardFromPreview()
        
        // Log session start
        logAnalytics(type: "session_start", parameters: ["seed": "\(actualSeed)"])
    }
    
    // MARK: - Public Interface
    
    /// Check if a chain can start at the given position
    public func canStart(at point: Point) -> Bool {
        guard let tile = tile(at: point) else { return false }
        
        // Cannot start on glass preview tiles
        if case .preview(glass: _) = tile.state {
            return false
        }
        
        return true
    }
    
    /// Check if a point can be appended to the current chain
    public func canAppend(_ next: Point, to chain: [Point]) -> Bool {
        guard let prev = chain.last else { return false }
        guard isAdjacent(prev, next) else { return false }
        guard let tNext = tile(at: next) else { return false }
        guard !chain.contains(next) else { return false }
        
        // Check glass rules
        let isPreviewGlass: Bool = {
            if case .preview(glass: true) = tNext.state { return true }
            else { return false }
        }()
        
        // Glass only allowed as terminal and only if previous is top cell of same column
        if isPreviewGlass {
            guard chain.count >= 1,
                  prev.col == next.col,
                  prev.row == 0 else {
                return false
            }
        }
        
        // 2244 link rule validation
        guard let first = tile(at: chain.first!) else { return false }
        guard let last = tile(at: prev) else { return false }
        
        let allowed: Bool
        if chain.count == 1 {
            // Need ≥2 identical to start
            allowed = (tNext.value == first.value)
        } else {
            // Can continue with same value or exactly double
            // Safe multiplication to prevent overflow
            let (doubled, overflow) = last.value.multipliedReportingOverflow(by: 2)
            allowed = (tNext.value == last.value || (!overflow && tNext.value == doubled))
        }
        
        return allowed
    }
    
    /// Begin a new chain at the given position
    public func beginChain(at point: Point) {
        guard canStart(at: point) else {
            chainValidation = "Cannot start chain on this tile"
            return
        }
        
        currentChain = [point]
        chainValidation = nil
    }
    
    /// Extend the current chain to include the given position
    public func extendChain(to point: Point) {
        guard canAppend(point, to: currentChain) else {
            if isPreview(point) && tile(at: point)?.isGlass == true {
                chainValidation = "End on the glass by linking the tile beneath it"
            } else {
                chainValidation = "Invalid chain extension"
            }
            return
        }
        
        currentChain.append(point)
        chainValidation = nil
    }
    
    /// Cancel the current chain
    public func cancelChain() {
        currentChain = []
        chainValidation = nil
    }
    
    /// Commit the current chain and apply game logic
    public func commitChain() {
        guard currentChain.count >= 2 else {
            chainValidation = "Chain must have at least 2 tiles"
            return
        }
        
        let chain = currentChain
        let last = chain.last!
        
        // Check for glass shatter
        var endedOnGlass = false
        if let tLast = tile(at: last), case .preview(glass: let isGlass) = tLast.state {
            endedOnGlass = isGlass
            if isGlass {
                // Shatter: remove glass & award power-up
                setTileState(at: last, to: .preview(glass: false))
                awardRandomPowerUp()
            }
        }
        
        // Compute result value: 2 × terminal tile's value
        // Safe multiplication to prevent overflow
        let baseValue = tile(at: last)?.value ?? 2
        let resultValue = baseValue <= (Int.max >> 1) ? baseValue * 2 : Int.max
        
        // Calculate score (sum of all tiles in chain)
        let chainScore = chain.compactMap { tile(at: $0)?.value }.reduce(0, +)
        score += chainScore
        moves += 1
        
        // Clear all tiles in chain from board (except last if it's preview)
        for point in chain {
            if isBoard(point) {
                clear(point)
            }
        }
        
        // Place result tile
        if isPreview(last) {
            // Land result at (col, 0)
            placeTile(at: Point(col: last.col, row: 0), GlassTile.normal(value: resultValue))
        } else {
            placeTile(at: last, GlassTile.normal(value: resultValue))
        }
        
        // Apply gravity and refill
        applyGravity()
        refillFromPreview()
        
        // Log analytics
        logAnalytics(type: "merge_chain", parameters: [
            "length": "\(chain.count)",
            "startValue": "\(tile(at: chain.first!)?.value ?? 0)",
            "endValue": "\(tile(at: chain.last!)?.value ?? 0)",
            "resultValue": "\(resultValue)",
            "endedOnGlass": "\(endedOnGlass)"
        ])
        
        // Clear chain state
        currentChain = []
        chainValidation = nil
        
        // Check game over
        checkGameOver()
    }
    
    // MARK: - Power-up System
    
    public func usePowerUp(_ powerUp: PowerUp) -> Bool {
        guard let count = powerups[powerUp], count > 0 else { return false }
        
        powerups[powerUp] = count - 1
        
        // Log usage
        logAnalytics(type: "powerup_use", parameters: [
            "type": powerUp.rawValue,
            "boardStateHash": boardStateHash()
        ])
        
        return true
    }
    
    private func awardRandomPowerUp() {
        let weights = config.giftWeights.map { ($0.key, $0.value) }
        if let pick = weightedPick(weights: weights, rng: &rng) {
            powerups[pick, default: 0] += 1
            
            logAnalytics(type: "glass_break", parameters: [
                "col": "\(currentChain.last?.col ?? -1)",
                "previewAgeTurns": "\(moves)", // Simplified
                "rewardType": pick.rawValue
            ])
        }
        
        glassBreakIndex += 1
    }
    
    // MARK: - Private Helpers
    
    private func tile(at point: Point) -> GlassTile? {
        if isBoard(point) {
            return grid[point.col][point.row].tile
        } else if isPreview(point) {
            let previewIndex = point.row + rows
            let queue = preview[point.col]
            let queueIndex = previewIndex - rows
            return queueIndex < queue.count ? queue[queueIndex] : nil
        }
        return nil
    }
    
    private func isBoard(_ point: Point) -> Bool {
        point.col >= 0 && point.col < cols && point.row >= 0 && point.row < rows
    }
    
    private func isPreview(_ point: Point) -> Bool {
        point.col >= 0 && point.col < cols && point.row >= rows
    }
    
    private func isAdjacent(_ a: Point, _ b: Point) -> Bool {
        a.isAdjacent(to: b)
    }
    
    private func clear(_ point: Point) {
        if isBoard(point) {
            grid[point.col][point.row].tile = nil
        }
    }
    
    private func placeTile(at point: Point, _ tile: GlassTile) {
        if isBoard(point) {
            grid[point.col][point.row].tile = tile
        }
    }
    
    private func setTileState(at point: Point, to state: TileState) {
        if let currentTile = tile(at: point) {
            let newTile = GlassTile(value: currentTile.value, state: state)
            if isPreview(point) {
                let previewIndex = point.row - rows
                if previewIndex >= 0 && previewIndex < preview[point.col].count {
                    preview[point.col][previewIndex] = newTile
                }
            }
        }
    }
    
    private func applyGravity() {
        // Compact each column downward
        for col in 0..<cols {
            var compacted: [GlassTile] = []
            
            // Collect all non-nil tiles from bottom to top
            for row in (0..<rows).reversed() {
                if let tile = grid[col][row].tile {
                    compacted.append(tile)
                }
                grid[col][row].tile = nil
            }
            
            // Place compacted tiles back from bottom
            for (index, tile) in compacted.enumerated() {
                let targetRow = rows - 1 - index
                if targetRow >= 0 {
                    grid[col][targetRow].tile = tile
                }
            }
        }
    }
    
    private func refillFromPreview() {
        for col in 0..<cols {
            // Count empty cells at top of column
            var emptyCount = 0
            for row in 0..<rows {
                if grid[col][row].tile == nil {
                    emptyCount += 1
                } else {
                    break
                }
            }
            
            // Fill empties from preview queue
            for _ in 0..<emptyCount {
                guard !preview[col].isEmpty else { break }
                
                var previewTile = preview[col].removeFirst()
                
                // If tile still has glass when auto-dropped, remove glass without reward
                if previewTile.isGlass {
                    previewTile = GlassTile.normal(value: previewTile.value)
                    logAnalytics(type: "preview_refill", parameters: [
                        "col": "\(col)",
                        "droppedWithGlass": "true"
                    ])
                } else {
                    logAnalytics(type: "preview_refill", parameters: [
                        "col": "\(col)",
                        "droppedWithGlass": "false"
                    ])
                }
                
                // Convert to normal board tile and place at top
                let boardTile = GlassTile.normal(value: previewTile.value)
                
                // Find first empty row from top
                for row in 0..<rows {
                    if grid[col][row].tile == nil {
                        grid[col][row].tile = boardTile
                        break
                    }
                }
            }
        }
        
        // Spawn new preview tiles to replace used ones
        spawnNewPreviewTiles()
    }
    
    private func bootstrapPreview() {
        // Fill each column's preview queue with initial glass tiles
        for col in 0..<cols {
            for _ in 0..<3 { // Initial queue depth
                let value = generateRandomValue()
                preview[col].append(GlassTile.glassPreview(value: value))
            }
        }
    }
    
    private func fillBoardFromPreview() {
        // Initially fill the board by triggering refill
        refillFromPreview()
    }
    
    private func spawnNewPreviewTiles() {
        for col in 0..<cols {
            // Maintain queue depth of 3
            while preview[col].count < 3 {
                let value = generateRandomValue()
                preview[col].append(GlassTile.glassPreview(value: value))
            }
        }
    }
    
    private func generateRandomValue() -> Int {
        let weights = config.spawnWeights
        let totalWeight = weights.values.reduce(0, +)
        let randomValue = Double(rng.next() % UInt64(Int(totalWeight * 1000))) / 1000.0
        
        var currentWeight = 0.0
        for (value, weight) in weights.sorted(by: { $0.key < $1.key }) {
            currentWeight += weight
            if randomValue < currentWeight {
                return value
            }
        }
        
        return 2 // Fallback
    }
    
    private func checkGameOver() {
        // Simple game over check: no valid moves possible
        var hasValidMove = false
        
        for col in 0..<cols {
            for row in 0..<rows {
                let point = Point(col: col, row: row)
                if canStart(at: point) {
                    // Check if we can extend in any direction
                    for dcol in -1...1 {
                        for drow in -1...1 {
                            if dcol == 0 && drow == 0 { continue }
                            let next = Point(col: col + dcol, row: row + drow)
                            if canAppend(next, to: [point]) {
                                hasValidMove = true
                                break
                            }
                        }
                        if hasValidMove { break }
                    }
                }
                if hasValidMove { break }
            }
            if hasValidMove { break }
        }
        
        isGameOver = !hasValidMove
    }
    
    private func boardStateHash() -> String {
        // Simple hash of board state for analytics
        var hash = 0
        for col in 0..<cols {
            for row in 0..<rows {
                if let tile = grid[col][row].tile {
                    hash = hash &* 31 &+ tile.value
                }
            }
        }
        return String(hash)
    }
    
    private func logAnalytics(type: String, parameters: [String: String]) {
        let event = AnalyticsEvent(type: type, parameters: parameters)
        analyticsEvents.append(event)
        
        // Keep only recent events to prevent memory bloat
        if analyticsEvents.count > 100 {
            analyticsEvents.removeFirst(analyticsEvents.count - 100)
        }
    }
    
    // MARK: - Test Helpers (internal for @testable import)
    
    public func _setTileForTesting(at point: Point, tile: GlassTile?) {
        if isBoard(point) {
            grid[point.col][point.row].tile = tile
        }
    }
    
    func _setPreviewForTesting(col: Int, tiles: [GlassTile]) {
        if col >= 0 && col < cols {
            preview[col] = tiles
        }
    }
    
    func _getTileForTesting(at point: Point) -> GlassTile? {
        return tile(at: point)
    }
    
    // MARK: - Debug Helpers
    
    public func debugInfo() -> String {
        var info = "=== Glass Game Store Debug ===\n"
        info += "Cols: \(cols), Rows: \(rows)\n"
        info += "Score: \(score), Moves: \(moves)\n"
        info += "Session Seed: \(sessionSeed)\n"
        info += "Chain: \(currentChain)\n"
        info += "Validation: \(chainValidation ?? "OK")\n"
        info += "Power-ups: \(powerups)\n"
        info += "\nPreview Queues:\n"
        for (col, queue) in preview.enumerated() {
            info += "Col \(col): \(queue.map { $0.isGlass ? "G\($0.value)" : "\($0.value)" })\n"
        }
        return info
    }
    
    public func forceAllGlass() {
        for col in 0..<cols {
            for i in 0..<preview[col].count {
                let tile = preview[col][i]
                preview[col][i] = GlassTile.glassPreview(value: tile.value)
            }
        }
    }
}

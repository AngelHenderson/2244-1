import Foundation
import SwiftUI
import GameCore
import GameServices
import Observation
import CryptoKit

@Observable
@MainActor
public final class GameStore {
    private var engine: GameEngine
    public private(set) var state: GameState
    public private(set) var currentPath: [Position] = []
    public private(set) var pathValidation: ChainValidation = .valid
    public var achievementEvaluator: AchievementEvaluator?
    // Track if we're building a chain that may end on a gift
    public private(set) var isExtendingToGift: Bool = false
    // Pending unlock reward (base amount before multiplier)
    public private(set) var pendingUnlockRewardBase: Int? = nil
    public private(set) var pendingUnlockTile: Int? = nil
    // Last merge info for UI board
    public struct MergeInfo: Equatable, Sendable {
        public let unlocked: Int?
        public let added: Int
        public let excluded: Int?
    }
    public private(set) var lastMergeInfo: MergeInfo? = nil
    // Value of the most recently created tile from a commit (for HUD banner)
    public private(set) var lastAddedTileValue: Int? = nil
    // Pending double offer value to apply (base value for doubling)
    public private(set) var pendingDoubleBase: Int? = nil
    // Track which glass tiles have been broken (positions in row 0)
    public private(set) var brokenGlassTiles: Set<Position> = []
    // Gift reward state
    public var pendingGiftReward: GiftReward? = nil
    // Power-up inventory tracking
    public private(set) var powerUpInventory: [String: Int] = [
        "hammer": 3,
        "shuffle": 2,
        "swap": 2,
        "undo": 1
    ]
    
    public func addPowerUp(_ type: String, count: Int) {
        powerUpInventory[type, default: 0] += count
    }
    
    // JourneyKit integration
    public let journey = JourneyKit.Store(
        config: .init(minPower: 8, maxPower: 22) // 256 to 4,194,304
    )
    
    public var coins: Int {
        get { state.gems }
        set { 
            state.gems = newValue
            UserDefaults.standard.set(newValue, forKey: "coins")
        }
    }
    
    // Lowest allowed spawn tile based on current highest (mirrors engine logic)
    public func currentMinAllowedTile() -> Int {
        let highest = state.highestTile
        // Progressive elimination starts at 1024 to maintain game balance
        guard highest >= 1024 else { return 2 }
        let exp = highest > 0 ? Int(floor(log2(Double(highest)))) : 0
        // Set minimum exponent: 2^10 -> 4, 2^11 -> 8, 2^12 -> 16, ...
        let minExp = max(1, exp - 8)
        return 1 << minExp
    }
    public private(set) var lastDailyDateUTC: String?
    
    // Replay recording
    public private(set) var movesHistory: [[Position]] = []
    public private(set) var powerUpHistory: [PowerUpAction] = []
    
    public init(config: GameConfig = GameConfig()) {
        let engine = GameEngine(config: config)
        self.engine = engine
        
        // Note: Gift row initialization is now optional and can be called separately
        // _ = engine.initializeGiftRow()
        
        self.state = engine.currentState()
        self.state.gems = UserDefaults.standard.integer(forKey: "coins")
        self.lastDailyDateUTC = UserDefaults.standard.string(forKey: "lastDailyDateUTC")
        
        // Sync JourneyKit with initial game state or saved progress
        // Check for legacy saved highest tile
        let savedHighest = UserDefaults.standard.integer(forKey: "highestTile")
        if savedHighest > 0 {
            journey.didReach(tile: savedHighest)
            state.highestTile = savedHighest
        } else if state.highestTile > 0 {
            journey.didReach(tile: state.highestTile)
        }
    }
    
    public func beginPath(at position: Position) {
        // Don't allow starting on gift cells
        let boardIndex = BoardIndex(position)
        if state.board[boardIndex].kind == .gift {
            return
        }
        
        currentPath = [position]
        pathValidation = .valid
        isExtendingToGift = false
    }
    
    public func extendPath(to position: Position) {
        guard !currentPath.contains(position) else { return }
        
        if let last = currentPath.last, !last.isAdjacent(to: position) {
            return
        }
        
        currentPath.append(position)
        
        // Check if we're extending to a gift cell
        let boardIndex = BoardIndex(position)
        isExtendingToGift = state.board[boardIndex].kind == .gift
        
        // Use gift-aware validation if the chain ends on a gift
        if isExtendingToGift {
            pathValidation = engine.validateGiftChain(currentPath)
        } else {
            pathValidation = engine.validateChain(currentPath)
        }
    }
    
    public func backtrackPath() {
        guard currentPath.count > 1 else { return }
        currentPath.removeLast()
        
        // Re-check if we're still extending to a gift
        if let last = currentPath.last {
            let boardIndex = BoardIndex(last)
            isExtendingToGift = state.board[boardIndex].kind == .gift
        } else {
            isExtendingToGift = false
        }
        
        // Use appropriate validation
        if isExtendingToGift {
            pathValidation = engine.validateGiftChain(currentPath)
        } else {
            pathValidation = engine.validateChain(currentPath)
        }
    }
    
    public func cancelPath() {
        currentPath = []
        pathValidation = .valid
        isExtendingToGift = false
    }
    
    public func commitPath() {
        guard pathValidation.isValid else { return }
        let previousHighest = state.highestTile
        let positions = currentPath
        let lastPos = positions.last
        // Capture removed values before commit (all but last)
        let removedValuesBefore = positions.dropLast().compactMap { pos in state.board[pos]?.value }
        
        // Check if ending on gift and use appropriate commit method
        let endsOnGift = lastPos.map { BoardIndex($0) }.map { state.board[$0].kind == .gift } ?? false
        
        if endsOnGift {
            state = engine.commitGiftChain(positions)
            
            // Generate gift reward only when a gift (glass) is broken
            if pendingGiftReward == nil {
                pendingGiftReward = GiftReward.randomReward()
            }
        } else {
            state = engine.commitChain(positions)
        }
        
        // Break glass tiles for any positions in row 0 that were part of this connection
        for position in positions {
            if position.row == 0 {
                brokenGlassTiles.insert(position)
            }
        }
        // Added value is the tile now at lastPos
        let addedValue: Int = {
            if let lp = lastPos, let v = state.board[lp]?.value { return v }
            return 0
        }()
        lastAddedTileValue = addedValue > 0 ? addedValue : nil

        // IMPORTANT: Remove non-glass gift triggers. Gifts are only awarded on shattered glass.
        // (No milestone/random gift triggers here.)
        
        // Notify JourneyKit of the new tile value
        if addedValue > 0 {
            journey.didReach(tile: addedValue)
            // Also persist the highest tile to UserDefaults
            if addedValue > previousHighest {
                UserDefaults.standard.set(addedValue, forKey: "highestTile")
            }
        }
        // Offer to double only if we created a tile that is one below the previous highest
        // or another instance of the previous highest.
        if addedValue > 0 {
            let offerIfOneBelow = (previousHighest >= 4) && (addedValue == previousHighest / 2)
            let offerIfAnotherHighest = (addedValue == previousHighest)
            pendingDoubleBase = (offerIfOneBelow || offerIfAnotherHighest) ? addedValue : nil
        } else {
            pendingDoubleBase = nil
        }
        let unlockedValue: Int? = state.highestTile > previousHighest ? state.highestTile : nil
        if let unlockedValue {
            setPendingUnlockRewardIfNeeded(for: unlockedValue, previousHigh: previousHighest)
        }
        let excludedValue: Int? = removedValuesBefore.first
        // Only show the merge info board when a new highest tile is unlocked
        if let unlockedValue {
            lastMergeInfo = .init(unlocked: unlockedValue, added: addedValue, excluded: excludedValue)
        } else {
            lastMergeInfo = nil
        }
        movesHistory.append(currentPath)
        
        // Evaluate achievements
        achievementEvaluator?.onChainCommitted(chain: positions, state: state, resultingTileValue: addedValue)
        
        currentPath = []
        pathValidation = .valid
    }
    
    public func resetGame() {
        engine = GameEngine(config: GameConfig())
        
        // Note: Gift row initialization is optional
        // _ = engine.initializeGiftRow()
        
        state = engine.currentState()
        currentPath = []
        pathValidation = .valid
        lastAddedTileValue = nil
        pendingDoubleBase = nil
        brokenGlassTiles = []
        movesHistory = []
        powerUpHistory = []
        
        // Notify achievement evaluator
        achievementEvaluator?.onGameStart(state: state)
    }
    
    // Start a new game with a custom seed (user-designed challenge)
    public func startCustomGame(seed: UInt64) {
        engine = GameEngine(config: GameConfig(seed: seed))
        
        // Note: Gift row initialization is optional
        // _ = engine.initializeGiftRow()
        
        state = engine.currentState()
        currentPath = []
        pathValidation = .valid
        lastAddedTileValue = nil
        pendingDoubleBase = nil
        brokenGlassTiles = []
        movesHistory = []
        powerUpHistory = []
    }
    
    // MARK: - Economy
    public func addCoins(_ amount: Int) {
        state.gems = max(0, state.gems + amount)
        UserDefaults.standard.set(state.gems, forKey: "coins")
    }
    
    public func spendCoins(_ amount: Int) -> Bool {
        guard state.gems >= amount else { return false }
        state.gems -= amount
        UserDefaults.standard.set(state.gems, forKey: "coins")
        return true
    }
    
    // MARK: - Unlock Rewards
    private func baseUnlockReward(for tileValue: Int) -> Int {
        // Start at 512 => 50 gems, then +2 per higher step (1024 => 52, 2048 => 54, ...)
        guard tileValue >= 512 else { return 0 }
        let exponent = Int(floor(log2(Double(tileValue))))
        let baseExponent = 9 // 2^9 = 512
        return 50 + max(0, (exponent - baseExponent)) * 2
    }
    
    private func setPendingUnlockRewardIfNeeded(for newHigh: Int, previousHigh: Int) {
        guard newHigh > previousHigh else { return }
        let base = baseUnlockReward(for: newHigh)
        guard base > 0 else { return }
        pendingUnlockRewardBase = base
        pendingUnlockTile = newHigh
    }
    
    public func claimPendingUnlockReward(multiplier: Int) {
        guard let base = pendingUnlockRewardBase, base > 0 else { return }
        let total = max(1, multiplier) * base
        addCoins(total)
        clearPendingUnlockReward()
    }
    
    public func clearPendingUnlockReward() {
        pendingUnlockRewardBase = nil
        pendingUnlockTile = nil
    }

    
    // MARK: - Gift Rewards

    public func claimGiftReward() {
        guard let reward = pendingGiftReward else { return }
        
        // Apply the rewards to the player's inventory
        for item in reward.items {
            switch item.type {
            case .hammer:
                addPowerUp("hammer", count: item.amount)
            case .magnet:
                addPowerUp("magnet", count: item.amount)
            case .gems:
                // Add gems to coins (assuming gems are stored as coins)
                addCoins(item.amount)
            case .swap:
                addPowerUp("swap", count: item.amount)
            case .undo:
                addPowerUp("undo", count: item.amount)
            }
        }
        
        // Clear the pending reward
        pendingGiftReward = nil
    }
    
    public func dismissGiftReward() {
        pendingGiftReward = nil
    }
    
    // MARK: - Double Offer
    public func clearPendingDoubleOffer() {
        pendingDoubleBase = nil
    }
    
    @discardableResult
    public func applyDouble(to position: Position) -> Bool {
        guard let base = pendingDoubleBase else { return false }
        state = engine.applyDouble(to: position, from: base)
        pendingDoubleBase = nil
        
        // Notify JourneyKit if we created a new highest tile  
        let doubledValue = base * 2
        journey.didReach(tile: doubledValue)
        
        // Persist if this is a new highest tile
        if doubledValue > state.highestTile {
            UserDefaults.standard.set(doubledValue, forKey: "highestTile")
        }
        
        return true
    }
    
    // MARK: - Merge Info
    public func clearLastMergeInfo() {
        lastMergeInfo = nil
    }
    
    // MARK: - PowerUps via Engine wrapper
    public enum PowerUpAction: Codable, Sendable, Equatable {
        case hammer(Position)
        case swap(Position, Position)
        case shuffle
        case undo
    }
    
    public enum PowerUpCost {
        public static let hammer = 50
        public static let swap = 75
        public static let shuffle = 100
    }
    
    @discardableResult
    public func useHammer(at position: Position) -> Bool {
        guard powerUpInventory["hammer", default: 0] > 0 || spendCoins(PowerUpCost.hammer) else { return false }
        // Use inventory first, then coins
        if powerUpInventory["hammer", default: 0] > 0 {
            powerUpInventory["hammer", default: 0] -= 1
        } else {
            _ = spendCoins(PowerUpCost.hammer)
        }
        state = engine.hammer(at: position)
        powerUpHistory.append(.hammer(position))
        achievementEvaluator?.onPowerUpUsed(type: "hammer")
        return true
    }
    
    @discardableResult
    public func useSwap(_ a: Position, _ b: Position) -> Bool {
        guard powerUpInventory["swap", default: 0] > 0 || spendCoins(PowerUpCost.swap) else { return false }
        // Use inventory first, then coins
        if powerUpInventory["swap", default: 0] > 0 {
            powerUpInventory["swap", default: 0] -= 1
        } else {
            _ = spendCoins(PowerUpCost.swap)
        }
        state = engine.swap(a, b)
        powerUpHistory.append(.swap(a, b))
        achievementEvaluator?.onPowerUpUsed(type: "swap")
        return true
    }
    
    @discardableResult
    public func useShuffle() -> Bool {
        guard powerUpInventory["shuffle", default: 0] > 0 || spendCoins(PowerUpCost.shuffle) else { return false }
        // Use inventory first, then coins
        if powerUpInventory["shuffle", default: 0] > 0 {
            powerUpInventory["shuffle", default: 0] -= 1
        } else {
            _ = spendCoins(PowerUpCost.shuffle)
        }
        state = engine.shuffle()
        powerUpHistory.append(.shuffle)
        achievementEvaluator?.onPowerUpUsed(type: "shuffle")
        return true
    }
    
    @discardableResult
    public func useUndo() -> Bool {
        guard state.undoAvailable else { return false }
        // Undo doesn't use inventory in this implementation
        state = engine.undo()
        powerUpHistory.append(.undo)
        achievementEvaluator?.onUndoUsed()
        return true
    }
    
    @discardableResult
    public func useMagnet(value: Int, to position: Position) -> Bool {
        // Simple magnet implementation: move one matching tile adjacent to target
        guard state.board[position] != nil else { return false }
        
        // Find first tile with matching value
        for row in 0..<state.board.height {
            for col in 0..<state.board.width {
                let pos = Position(row: row, col: col)
                if let tile = state.board[pos], tile.value == value && pos != position {
                    // Try to swap with target
                    if pos.isAdjacent(to: position) {
                        _ = engine.swap(pos, position)
                        return true
                    }
                }
            }
        }
        return false
    }
    
    // Helper to check if power-up is available (inventory or affordable)
    public func isPowerUpAvailable(_ powerUp: String) -> Bool {
        if powerUpInventory[powerUp, default: 0] > 0 { return true }
        switch powerUp {
        case "hammer": return coins >= PowerUpCost.hammer
        case "shuffle": return coins >= PowerUpCost.shuffle
        case "swap": return coins >= PowerUpCost.swap
        default: return false
        }
    }
    
    // MARK: - Optional Gift Row Features
    
    /// Enable gift row functionality in the top row (optional feature)
    @discardableResult
    public func enableGiftRow() -> Bool {
        _ = engine.initializeGiftRow()
        state = engine.currentState()
        return true
    }
    
    /// Check if gift row is currently enabled
    public var hasGiftRow: Bool {
        return !engine.giftPositions().isEmpty
    }
    
    // MARK: - Daily Seed
    public func configureDailyGameIfNeeded(salt: String, utcDate: Date) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateString = formatter.string(from: utcDate)
        guard lastDailyDateUTC != dateString else { return }
        let seed = Self.dailySeed(from: dateString, salt: salt)
        engine = GameEngine(config: GameConfig(seed: seed))
        
        // Note: Gift row initialization is optional
        // _ = engine.initializeGiftRow()
        
        state = engine.currentState()
        currentPath = []
        pathValidation = .valid
        lastDailyDateUTC = dateString
        UserDefaults.standard.set(dateString, forKey: "lastDailyDateUTC")
        movesHistory = []
        powerUpHistory = []
    }
    
    static func dailySeed(from dateString: String, salt: String) -> UInt64 {
        let combined = salt + dateString
        let data = Data(combined.utf8)
        let digest = SHA256.hash(data: data)
        // First 8 bytes as UInt64 big-endian
        let bytes = Array(digest)
        let value = bytes.prefix(8).reduce(UInt64(0)) { acc, byte in
            (acc << 8) | UInt64(byte)
        }
        return value
    }
    
    // Derive a deterministic seed from an arbitrary string
    public static func seed(from string: String) -> UInt64 {
        let data = Data(string.utf8)
        let digest = SHA256.hash(data: data)
        let bytes = Array(digest)
        return bytes.prefix(8).reduce(UInt64(0)) { acc, byte in (acc << 8) | UInt64(byte) }
    }
    
    // MARK: - Replay
    public struct Replay: Codable, Sendable, Equatable {
        public let seed: UInt64?
        public let moves: [[Position]]
        public let powerUps: [PowerUpAction]
    }

    
    public func exportReplay() throws -> String {
        let replay = Replay(seed: engine.seedUsed, moves: movesHistory, powerUps: powerUpHistory)
        let data = try JSONEncoder().encode(replay)
        return "GR1|" + data.base64EncodedString()
    }
    
    public func importReplay(_ code: String) throws -> Replay {
        let parts = code.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2, parts[0] == "GR1" else { throw ReplayError.invalidFormat }
        guard let data = Data(base64Encoded: parts[1]) else { throw ReplayError.invalidFormat }
        return try JSONDecoder().decode(Replay.self, from: data)
    }
    
    public enum ReplayError: Error { case invalidFormat }

    // Simulate a replay quickly (headless). Returns final state.
    public func simulateReplay(_ replay: Replay) -> GameState {
        let engine = GameEngine(config: GameConfig(seed: replay.seed))
        var state = engine.currentState()
        for path in replay.moves {
            _ = engine.commitChain(path)
            state = engine.currentState()
        }
        for action in replay.powerUps {
            switch action {
            case .hammer(let p):
                _ = engine.hammer(at: p)
            case .swap(let a, let b):
                _ = engine.swap(a, b)
            case .shuffle:
                _ = engine.shuffle()
            case .undo:
                _ = engine.undo()
            }
            state = engine.currentState()
        }
        return state
    }
}

// MARK: - Persistence (Local Slots)
extension GameStore {
    private func flattenBoard(_ board: Board) -> [Int] {
        var values: [Int] = []
        values.reserveCapacity(board.width * board.height)
        for row in 0..<board.height {
            for col in 0..<board.width {
                let position = Position(row: row, col: col)
                if let tile = board[position] {
                    values.append(tile.value)
                } else {
                    values.append(0)
                }
            }
        }
        return values
    }
    
    private func board(from flat: [Int], width: Int, height: Int) -> Board {
        var board = Board(width: width, height: height)
        let expectedCount = width * height
        guard flat.count == expectedCount else { return board }
        var index = 0
        for row in 0..<height {
            for col in 0..<width {
                let v = flat[index]
                if v > 0 { board[Position(row: row, col: col)] = Tile(value: v) }
                index += 1
            }
        }
        return board
    }
    
    public func save(to slotId: String, using storage: any StorageServiceProtocol, theme: String) async {
        let current = state
        let bestExisting = await storage.bestScore()
        let bestToPersist = max(bestExisting, current.score)
        let payload = SaveData(
            board: flattenBoard(current.board),
            width: current.board.width,
            height: current.board.height,
            score: current.score,
            best: bestToPersist,
            seed: engine.seedUsed,
            theme: theme,
            timestamp: Date()
        )
        await storage.save(slotId: slotId, data: payload)
    }
    
    @discardableResult
    public func load(from slotId: String, using storage: any StorageServiceProtocol) async -> Bool {
        guard let data = await storage.load(slotId: slotId) else { return false }
        // If saved board size differs from current defaults (5x8), reinitialize to new size
        if data.width != 5 || data.height != 8 {
            engine = GameEngine(config: GameConfig(boardWidth: 5, boardHeight: 8, seed: data.seed))
            state = engine.currentState()
        } else {
            let restoredBoard = board(from: data.board, width: data.width, height: data.height)
            let config = GameConfig(boardWidth: data.width, boardHeight: data.height, seed: data.seed)
            let restoredEngine = GameEngine(
                config: config,
                initialBoard: restoredBoard,
                initialScore: data.score,
                initialMoves: 0,
                initialLevel: 1,
                initialGems: state.gems
            )
            engine = restoredEngine
            state = restoredEngine.currentState()
        }
        
        // IMPORTANT: Sync JourneyKit with the loaded game state
        if state.highestTile > 0 {
            journey.didReach(tile: state.highestTile)
        }
        
        currentPath = []
        pathValidation = .valid
        movesHistory = []
        powerUpHistory = []
        return true
    }
    
    public func deleteSlot(_ slotId: String, using storage: any StorageServiceProtocol) async {
        await storage.delete(slotId: slotId)
    }
    
    public func listSlots(using storage: any StorageServiceProtocol) async -> [SaveSlotMeta] {
        await storage.loadSlots()
    }
    
    public func bestScore(using storage: any StorageServiceProtocol) async -> Int {
        await storage.bestScore()
    }
}

import Foundation

public struct GameConfig: Sendable {
    public let boardWidth: Int
    public let boardHeight: Int
    public let seed: UInt64?
    public let spawnWeights: [Int: Double]
    public let initialTileCount: Int
    public let allowDiagonals: Bool
    // Fill policy: in classic 2244, the board should remain full after every move
    // This is added for clarity and future extensibility; currently we always use always-full.
    public enum FillMode: Sendable { case alwaysFull, sparse }
    public let fillMode: FillMode
    
    public init(
        boardWidth: Int = 5,
        boardHeight: Int = 8,
        seed: UInt64? = nil,
        spawnWeights: [Int: Double] = [
            2: 0.75,
            4: 0.22,
            8: 0.03
        ],
        initialTileCount: Int = 2,
        allowDiagonals: Bool = true,
        fillMode: FillMode = .alwaysFull
    ) {
        self.boardWidth = boardWidth
        self.boardHeight = boardHeight
        self.seed = seed
        self.spawnWeights = spawnWeights
        self.initialTileCount = initialTileCount
        self.allowDiagonals = allowDiagonals
        self.fillMode = fillMode
    }
}

public struct GameState: Equatable, Sendable {
    public var board: Board
    public var score: Int
    public var scoreValue: AlphaNumber
    public var moves: Int
    public var isGameOver: Bool
    public var highestTile: Int
    public var highestTileStep: Int
    public var level: Int
    public var gems: Int
    public var undoAvailable: Bool
    
    public init(
        board: Board,
        score: Int = 0,
        scoreValue: AlphaNumber? = nil,
        moves: Int = 0,
        isGameOver: Bool = false,
        highestTile: Int = 0,
        highestTileStep: Int? = nil,
        level: Int = 1,
        gems: Int = 0,
        undoAvailable: Bool = false
    ) {
        self.board = board
        self.score = score
        self.scoreValue = scoreValue ?? AlphaNumber(score)
        self.moves = moves
        self.isGameOver = isGameOver
        self.highestTile = highestTile
        self.highestTileStep = highestTileStep
            ?? TileStepLabelFormatter.stepForValue(highestTile, start: 2) ?? 0
        self.level = level
        self.gems = gems
        self.undoAvailable = undoAvailable
    }
}

public enum PowerUpType: String, CaseIterable, Codable, Sendable {
    case shuffle = "shuffle"
    case hammer = "hammer"
    case swap = "swap"
    case undo = "undo"
    case magnet = "magnet"
    case double = "double"
}

public enum SpecialTileType: String, Sendable {
    case infinity = "∞"
    case locked = "Locked"
    case bomb = "Bomb"
}

public struct ChainValidation: Sendable {
    public let isValid: Bool
    public let reason: String?
    
    public static let valid = ChainValidation(isValid: true, reason: nil)
    public static func invalid(_ reason: String) -> ChainValidation {
        ChainValidation(isValid: false, reason: reason)
    }
}

public final class GameEngine {
    private let config: GameConfig
    private var rng: DeterministicRNG
    private var state: GameState
    private var previousState: GameState?
    public let seedUsed: UInt64
    private var highestTileAchieved: Int = 0
    private var milestonesReached: Set<Int> = []
    private var lastMergeAtMs: Int? = nil
    private var pendingGiftRefillValue: Int? = nil
    private var scoreMultiplier: Int = 1
    
    // Track which milestones have already triggered elimination
    private var eliminatedMilestones: Set<Int> = []
    
    public init(config: GameConfig = GameConfig()) {
        self.config = config
        let selectedSeed = config.seed ?? UInt64(Date().timeIntervalSince1970)
        self.seedUsed = selectedSeed
        self.rng = DeterministicRNG(seed: selectedSeed)
        self.state = GameState(board: Board(width: config.boardWidth, height: config.boardHeight))
        spawnInitialTiles()
    }
    
    // Restoring initializer for loading a saved game
    public init(config: GameConfig, initialBoard: Board, initialScore: Int = 0, initialMoves: Int = 0, initialLevel: Int = 1, initialGems: Int = 0) {
        self.config = config
        let selectedSeed = config.seed ?? UInt64(Date().timeIntervalSince1970)
        self.seedUsed = selectedSeed
        self.rng = DeterministicRNG(seed: selectedSeed)
        
        // Calculate highest tile from board
        var highest = 0
        for row in 0..<initialBoard.height {
            for col in 0..<initialBoard.width {
                if let tile = initialBoard[Position(row: row, col: col)] {
                    highest = max(highest, tile.value)
                }
            }
        }
        
        self.state = GameState(
            board: initialBoard,
            score: initialScore,
            moves: initialMoves,
            isGameOver: false,
            highestTile: highest,
            level: initialLevel,
            gems: initialGems
        )
        self.highestTileAchieved = highest
        
        // Reconstruct eliminatedMilestones based on highest tile achieved
        // Each milestone at 16K, 32K, 64K, etc. should have eliminated tiles
        // Milestone 16K eliminates 1 (not a real tile), 32K eliminates 2, 64K eliminates 4, etc.
        reconstructEliminatedMilestones(fromHighestTile: highest)
        
        // Apply eliminations to remove any stale tiles that shouldn't be on the board
        applyPendingEliminationsOnRestore()
    }
    
    /// Reconstruct the eliminatedMilestones set from the highest tile value
    /// This ensures proper elimination state when restoring a saved game
    private func reconstructEliminatedMilestones(fromHighestTile highest: Int) {
        // List of all milestones that trigger elimination (excluding skipped ones)
        let eliminationMilestones = [
            2048, 4096, // 8192 skipped
            16384, 32768, 65536, // 131072 skipped
            262144, 524288, 1048576, // 2097152 skipped
            4194304, 8388608, 16777216, // 33554432 skipped
            67108864, 134217728
        ]

        // Add all milestones up to and including the highest tile
        for milestone in eliminationMilestones {
            if milestone <= highest {
                eliminatedMilestones.insert(milestone)
            } else {
                break
            }
        }

        // Handle milestones beyond 134M using the infinite repeating pattern
        if highest >= 268435456 { // 268M and beyond
            var currentMilestone = 268435456 // Start at 268M
            while currentMilestone <= highest {
                // Calculate position relative to 67M
                let log67M = 26 // log2(67108864)
                let logCurrent = Int(log2(Double(currentMilestone)))
                let position = logCurrent - log67M

                // Every 3rd position (2, 5, 8, 11...) is a skip
                if position % 3 != 2 { // Not a skip position
                    eliminatedMilestones.insert(currentMilestone)
                }

                // Safeguard against overflow when doubling
                if currentMilestone > Int.max / 2 {
                    break
                }
                currentMilestone *= 2
            }
        }

        if !eliminatedMilestones.isEmpty {
            print("🔄 RESTORE: Reconstructed \(eliminatedMilestones.count) elimination milestones from highest tile \(highest)")
        }
    }
    
    /// Apply any pending eliminations after restoring a game
    /// This removes tiles that should have been eliminated but exist in the saved board
    private func applyPendingEliminationsOnRestore() {
        guard !eliminatedMilestones.isEmpty else { return }

        // Collect all values that should be eliminated based on reached milestones
        var valuesToEliminate: Set<Int> = []
        for milestone in eliminatedMilestones {
            if let eliminatedValue = milestoneExcludedValue(for: milestone) {
                valuesToEliminate.insert(eliminatedValue)
            }
        }

        guard !valuesToEliminate.isEmpty else { return }

        var didRemove = false
        var totalRemoved = 0

        // Remove ALL tiles with values that should be eliminated
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let pos = Position(row: row, col: col)
                if let tile = state.board[pos], valuesToEliminate.contains(tile.value) {
                    print("🗑️ RESTORE ELIMINATION: Removing stale tile \(tile.value) at \(pos)")
                    state.board[pos] = nil
                    didRemove = true
                    totalRemoved += 1
                }
            }
        }

        if didRemove {
            print("   ✅ Eliminated \(totalRemoved) stale tiles from restored board")
            refillAfterGravity()
            print("   ✅ Board refilled after restore elimination")
        }
    }
    
    public func currentState() -> GameState {
        state
    }
    
    /// Synchronize the engine's gem count with an external source (e.g., GameStore rewards).
    public func overrideGems(with newValue: Int) {
        state.gems = newValue
    }
    
    /// Apply a temporary score multiplier (defaults to 1 when not boosted).
    public func setScoreMultiplier(_ multiplier: Int) {
        scoreMultiplier = max(1, multiplier)
    }
    
    public func validateChain(_ positions: [Position]) -> ChainValidation {
        guard positions.count >= 2 else {
            return .invalid("Chain must have at least 2 tiles")
        }
        
        let uniquePositions = Set(positions)
        guard uniquePositions.count == positions.count else {
            return .invalid("Chain contains duplicate positions")
        }
        
        for i in 1..<positions.count {
            guard positions[i-1].isAdjacent(to: positions[i]) else {
                return .invalid("Tiles must be adjacent (including diagonals)")
            }
        }
        
        let tiles = positions.compactMap { state.board[$0] }
        guard tiles.count == positions.count else {
            return .invalid("Chain contains empty tiles")
        }
        
        // Check for special tiles that can't merge
        for tile in tiles {
            if tile.isInfinity {
                return .invalid("Infinity tiles cannot be merged")
            }
            if tile.isLocked {
                return .invalid("Locked tiles cannot be merged")
            }
        }
        
        let steps = tiles.compactMap { TileStepMath.step(for: $0) }
        guard steps.count == tiles.count, steps.count >= 2 else {
            return .invalid("Chain must have at least 2 tiles")
        }
        
        // First two tiles must match to start a chain.
        if steps[1] != steps[0] {
            return .invalid("First two tiles must match")
        }
        
        // After the opening pair, each tile may either match the previous tile or double it.
        if steps.count > 2 {
            for index in 2..<steps.count {
                let previous = steps[index - 1]
                let current = steps[index]
                if current != previous && current != previous + 1 {
                    return .invalid("Tiles must continue with equal or doubled values")
                }
            }
        }
        
        return .valid
    }
    
    // MARK: - Enhanced Gift Chain Validation
    
    public func validateGiftChain(_ positions: [Position]) -> ChainValidation {
        let boardIndices = positions.map { BoardIndex($0) }
        return state.board.validateGiftChain(boardIndices)
    }
    
    public func commitGiftChain(_ positions: [Position]) -> GameState {
        let boardIndices = positions.map { BoardIndex($0) }
        
        // Validate the gift chain
        guard state.board.validateGiftChain(boardIndices).isValid else { 
            return state 
        }
        
        // Save previous state for undo
        previousState = state
        state.undoAvailable = true
        
        // Check if ending on gift
        let endingOnGift = state.board[boardIndices.last!].kind == .gift
        
        // Perform the merge (need to ensure board changes are applied to state)
        var boardCopy = state.board
        guard let outcome = boardCopy.performMerge(chain: boardIndices, endingOnGift: endingOnGift) else {
            return state
        }
        
        // Apply the modified board back to state
        state.board = boardCopy
        
        // Update score and game state
        addScoreForStep(outcome.resultStep)
        state.moves += 1
        
        // Update highest tile and level
        if outcome.resultStep > state.highestTileStep {
            let previousHighest = state.highestTile
            state.highestTile = max(outcome.resultValue, state.highestTile)
            state.highestTileStep = outcome.resultStep
            highestTileAchieved = state.highestTile
            updateLevel()
            checkMilestoneRewards(outcome.resultValue)
        
            // Apply eliminations for ALL milestones between previous highest and new value
            applyAllMilestonesBetween(previousHighest, and: outcome.resultValue)
        } else {
            // Even if not a new highest, check if this specific value triggers elimination
        applyMilestoneEliminationIfNeeded(createdValue: outcome.resultValue)
        }
        
        // Award gems for long chains (10+ tiles)
        if positions.count >= 10 {
            state.gems += positions.count / 5
        }
        
        // Special gift rewards
        if outcome.giftBroken {
            // Award bonus gems for breaking gifts
            state.gems += 1
            // TODO: Fire gift reward logic here (power-ups, etc.)
        }
        
        // Flag pending gift refill so it can be handled during the refill phase
        if outcome.giftBroken {
            pendingGiftRefillValue = generateRandomValue()
        }

        return state
    }
    
    // MARK: - Gift Management
    
    @discardableResult
    public func placeGift(at position: Position, targetValue: Int = 0) -> GameState {
        let boardIndex = BoardIndex(position)
        guard state.board.isValid(boardIndex) else { return state }
        
        // Save state for undo
        previousState = state
        state.undoAvailable = true
        
        let gift = Gift(targetValue: targetValue)
        state.board.placeGift(gift, at: boardIndex)
        
        return state
    }
    
    public func giftPositions() -> [Position] {
        return state.board.giftPositions().map { $0.position }
    }
    
    // Initialize top row with gift cells (glass preview row)
    @discardableResult
    public func initializeGiftRow() -> GameState {
        // Clear top row first
        for col in 0..<config.boardWidth {
            let position = Position(row: 0, col: col)
            state.board[position] = nil
        }
        
        // Place gifts in the top row (row 0)
        for col in 0..<config.boardWidth {
            let position = Position(row: 0, col: col)
            let targetValue = generateRandomValue()
            placeGift(at: position, targetValue: targetValue)
        }
        return state
    }
    
    // Check if a position is in the gift row (top row)
    public func isGiftRow(_ position: Position) -> Bool {
        return position.row == 0  // Top row is the gift row
    }
    
    public func commitChain(_ positions: [Position], applyGravity: Bool = true) -> GameState {
        guard validateChain(positions).isValid else { return state }
        
        // Save previous state for undo
        previousState = state
        state.undoAvailable = true
        
        let tiles = positions.compactMap { state.board[$0] }
        guard tiles.count == positions.count else { return state }
        let steps = tiles.compactMap { TileStepMath.step(for: $0) }
        guard steps.count == tiles.count else { return state }
        let mergedStep = TileStepMath.mergedStep(from: steps)
        let mergedValue = TileStepMath.value(forStep: mergedStep)
        let mergedTile = Tile.make(forStep: mergedStep)
        
        // Debug logging for large chains
        if positions.count >= 10 {
            print("🔗 LARGE CHAIN DEBUG:")
            print("   Chain size: \(positions.count) tiles")
            print("   Tile values: \(tiles.map { $0.value })")
            print("   Steps: \(steps)")
            print("   Merged step: \(mergedStep)")
            print("   Merged value: \(mergedValue)")

            // Check if this is a skip milestone
            if mergedValue == 8192 || mergedValue == 131072 || mergedValue == 2097152 || mergedValue == 33554432 {
                print("   ⚠️ This is a SKIP milestone - NO elimination should occur!")
            }
        }
        
        // Remove all tiles in the chain
        for position in positions.dropLast() {
            state.board[position] = nil
        }
        
        // Place merged tile at the last position in the chain
        if let lastPosition = positions.last {
            state.board[lastPosition] = mergedTile
        }
        
        // Update highest tile and level
        if mergedStep > state.highestTileStep {
            let previousHighest = state.highestTile
            state.highestTile = max(mergedValue, state.highestTile)
            state.highestTileStep = mergedStep
            highestTileAchieved = state.highestTile
            updateLevel()
            checkMilestoneRewards(mergedValue)
        
            // Apply eliminations for ALL milestones between previous highest and new value
            applyAllMilestonesBetween(previousHighest, and: mergedValue)
        } else {
            // Even if not a new highest, check if this specific value triggers elimination
        applyMilestoneEliminationIfNeeded(createdValue: mergedValue)
        }
        
        // Award points
        addScoreForStep(mergedStep)
        state.moves += 1
        
        // Award gems for long chains (10+ tiles)
        if positions.count >= 10 {
            state.gems += positions.count / 5
        }
        
        if applyGravity {
            applyGravityDown()
            
            // Check for game over only after gravity resolves
            if !hasValidMoves() {
                state.isGameOver = true
            }
        }
        
        return state
    }
    
    // Public method to trigger refill explicitly
    public func refillBoard() -> GameState {
        processPendingGiftRefillIfNeeded()
        if config.fillMode == .alwaysFull {
            refillToFullWithCascade()
        } else {
            refillToFull()
        }

        if !hasValidMoves() {
            state.isGameOver = true
        }

        return state
    }
    
    private func processPendingGiftRefillIfNeeded() {
        guard let giftValue = pendingGiftRefillValue else { return }
        state.board.refillTopRowWithGifts { giftValue }
        pendingGiftRefillValue = nil
    }

    /// Applies gravity and game-over evaluation after a chain has been committed
    /// without immediately resolving gravity (e.g., during animation pipelines).
    /// - Returns: The updated `GameState` after gravity settles.
    @discardableResult
    public func applyGravityAfterChain() -> GameState {
        applyGravityDown()
        
        if !hasValidMoves() {
            state.isGameOver = true
        }
        
        return state
    }
    
    // MARK: - Power-ups
    
    @discardableResult
    public func hammer(at position: Position, applyGravity: Bool = true) -> GameState {
        guard position.isValid(for: state.board), state.board[position] != nil else {
            return state
        }
        
        // Save state for undo
        previousState = state
        state.undoAvailable = true
        
        state.board[position] = nil
        state.moves += 1
        
        if applyGravity {
        // Keep board full after destructive action
        refillAfterGravity()
        
        if !hasValidMoves() {
            state.isGameOver = true
            }
        }
        
        return state
    }
    
    @discardableResult
    public func swap(_ a: Position, _ b: Position) -> GameState {
        guard a.isValid(for: state.board), b.isValid(for: state.board) else { return state }
        guard a != b else { return state }
        
        // Save state for undo
        previousState = state
        state.undoAvailable = true
        
        // Perform the swap
        let temp = state.board[a]
        state.board[a] = state.board[b]
        state.board[b] = temp
        state.moves += 1
        
        // Swap-drop-refill: keep gravity/refill consistent without triggering auto-cascade
        refillAfterGravity()
        
        if !hasValidMoves() {
            state.isGameOver = true
        }
        
        return state
    }
    
    @discardableResult
    public func magnetize(value: Int, to position: Position) -> GameState {
        guard position.isValid(for: state.board) else { return state }
        guard let targetTile = state.board[position],
              let targetStep = TileStepMath.step(for: targetTile) else { return state }
        guard targetTile.value == value else { return state }
        
        // Save state for undo
        previousState = state
        state.undoAvailable = true
        
        // Find all tiles with the target value (including the target position)
        var matchingPositions: [Position] = []
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let pos = Position(row: row, col: col)
                if let tile = state.board[pos],
                   let step = TileStepMath.step(for: tile),
                   step == targetStep {
                    matchingPositions.append(pos)
                }
            }
        }
        
        // If only one tile exists with this value, nothing to merge
        guard matchingPositions.count > 1 else {
            state.undoAvailable = false
            previousState = nil
            return state
        }
        
        let mergedStep = TileStepMath.mergedStep(from: Array(repeating: targetStep, count: matchingPositions.count))
        let mergedValue = TileStepMath.value(forStep: mergedStep)
        let mergedTile = Tile.make(forStep: mergedStep)
        
        // STEP 1: Remove all matching tiles (including the target position)
        // This clears the board of all tiles that are being merged
        for pos in matchingPositions {
            state.board[pos] = nil
        }
        
        // STEP 2: Place the merged result tile at the target position
        // This happens BEFORE gravity, so the tile will fall if needed
        state.board[position] = mergedTile
        
        // Update highest tile and level if needed
        if mergedStep > state.highestTileStep {
            let previousHighest = state.highestTile
            state.highestTile = max(mergedValue, state.highestTile)
            state.highestTileStep = mergedStep
            highestTileAchieved = state.highestTile
            updateLevel()
            checkMilestoneRewards(mergedValue)
        
            // Apply eliminations for ALL milestones between previous highest and new value
            applyAllMilestonesBetween(previousHighest, and: mergedValue)
        } else {
            // Even if not a new highest, check if this specific value triggers elimination
        applyMilestoneEliminationIfNeeded(createdValue: mergedValue)
        }
        
        // Award score for the merge (use safe addition to prevent overflow)
        addScoreForStep(mergedStep)
        
        state.moves += 1
        
        return state
    }
    
    @discardableResult
    public func collapseColumns(_ columns: Set<Int>) -> GameState {
        guard !columns.isEmpty else { return state }
        var board = state.board
        board.collapseColumns(columns)
        state.board = board
        return state
    }
    
    @discardableResult
    public func refillColumns(_ columns: Set<Int>) -> GameState {
        guard !columns.isEmpty else { return state }
        if config.fillMode == .alwaysFull {
            refillColumnsWithCascade(columns)
        } else {
            var board = state.board
            board.refillColumns(columns, fillAll: false) { [self] in
                generateRandomValue()
            }
            state.board = board
        }
        if !hasValidMoves() {
            state.isGameOver = true
        }
        return state
    }

    private func refillColumnsWithCascade(_ columns: Set<Int>) {
        // Spawn tiles only at the top of specified columns and apply gravity repeatedly
        // This creates a natural cascade effect instead of tiles appearing mid-column
        var maxIterations = config.boardHeight * columns.count // Safety limit

        while maxIterations > 0 {
            maxIterations -= 1

            // Count empty cells in the specified columns
            var emptyCount = 0
            for col in columns {
                for row in 0..<config.boardHeight {
                    let pos = Position(row: row, col: col)
                    let boardIndex = BoardIndex(pos)
                    if state.board[boardIndex].kind != .gift && state.board[pos] == nil {
                        emptyCount += 1
                    }
                }
            }

            // If columns are full, we're done
            if emptyCount == 0 { break }

            // Spawn new tiles ONLY in the TOP ROW for specified columns
            for col in columns {
                let pos = Position(row: 0, col: col)
                let boardIndex = BoardIndex(pos)
                // Skip gift cells in top row
                if state.board[boardIndex].kind == .gift {
                    continue
                }
                if state.board[pos] == nil {
                    state.board[pos] = Tile(value: generateRandomValue())
                }
            }

            // Apply gravity to make the newly spawned tiles fall down
            applyGravityDown()
        }
    }
    
    @discardableResult
    public func shuffle() -> GameState {
        // Save state for undo
        previousState = state
        state.undoAvailable = true
        
        var tiles: [Tile] = []
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let pos = Position(row: row, col: col)
                if let t = state.board[pos] {
                    tiles.append(t)
                    state.board[pos] = nil
                }
            }
        }
        
        // Fisher-Yates shuffle using deterministic RNG
        var i = tiles.count - 1
        while i > 0 {
            let j = Int(rng.next() % UInt64(i + 1))
            tiles.swapAt(i, j)
            i -= 1
        }
        
        // Place shuffled tiles back
        var tileIndex = 0
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                if tileIndex < tiles.count {
                    let pos = Position(row: row, col: col)
                    state.board[pos] = tiles[tileIndex]
                    tileIndex += 1
                }
            }
        }
        
        state.moves += 1
        
        if !hasValidMoves() {
            state.isGameOver = true
        }
        
        return state
    }
    
    @discardableResult
    public func undo() -> GameState {
        guard state.undoAvailable, let prev = previousState else {
            return state
        }
        
        state = prev
        state.undoAvailable = false // Can only undo once
        previousState = nil
        return state
    }
    
    // Apply: set a target tile's value to double of a given base value.
    // Used by the UI "double to another block" action.
    @discardableResult
    public func applyDouble(to position: Position, from baseValue: Int) -> GameState {
        guard position.isValid(for: state.board), state.board[position] != nil else { return state }
        // Save state for undo
        previousState = state
        state.undoAvailable = true
        let doubled: Int = {
            if baseValue >= (Int.max >> 1) { return Int.max }
            let (next, overflow) = baseValue.multipliedReportingOverflow(by: 2)
            return overflow ? Int.max : next
        }()
        let baseStep = TileStepLabelFormatter.stepForValue(baseValue, start: 2) ?? 0
        let doubledStep = baseStep + 1
        state.board[position] = Tile.make(forStep: doubledStep)
        // Update highest tile & level if needed
        if doubledStep > state.highestTileStep {
            let previousHighest = state.highestTile
            state.highestTile = max(doubled, state.highestTile)
            state.highestTileStep = doubledStep
            highestTileAchieved = state.highestTile
            updateLevel()

            // Apply eliminations for ALL milestones between previous highest and new value
            applyAllMilestonesBetween(previousHighest, and: doubled)
        } else {
            // Even if not a new highest, check if this specific value triggers elimination
        applyMilestoneEliminationIfNeeded(createdValue: doubled)
        }
        
        state.moves += 1
        if !hasValidMoves() { state.isGameOver = true }
        return state
    }
    
    private func isBoardFull() -> Bool {
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                if state.board[Position(row: row, col: col)] == nil {
                    return false
                }
            }
        }
        return true
    }
    
    private func spawnInitialTiles() {
        switch config.fillMode {
        case .alwaysFull:
            fillBoardToFull()
        case .sparse:
            var emptyPositions: [Position] = []
            for row in 0..<config.boardHeight {
                for col in 0..<config.boardWidth {
                    let position = Position(row: row, col: col)
                    // Skip top row if it has gift cells
                    if row == 0 && state.board[BoardIndex(position)].kind == .gift {
                        continue
                    }
                    emptyPositions.append(position)
                }
            }
            for _ in 0..<min(config.initialTileCount, emptyPositions.count) {
                let index = Int(rng.next() % UInt64(emptyPositions.count))
                let position = emptyPositions.remove(at: index)
                state.board[position] = Tile(value: generateRandomValue())
            }
        }
    }
    
    private func spawnNewTile() {
        var emptyPositions: [Position] = []
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let position = Position(row: row, col: col)
                if state.board[position] == nil {
                    emptyPositions.append(position)
                }
            }
        }
        
        guard !emptyPositions.isEmpty else { return }
        
        // Spawn one new tile at a random empty position
        let index = Int(rng.next() % UInt64(emptyPositions.count))
        let position = emptyPositions[index]
        state.board[position] = Tile(value: generateRandomValue())
    }
    
    private func checkMilestoneRewards(_ newHighTile: Int) {
        // Milestone bombs: Clear random tiles when reaching 2048, 4096, etc.
        let milestones = [2048, 4096, 8192, 16384, 32768]
        for milestone in milestones {
            if newHighTile >= milestone && !milestonesReached.contains(milestone) {
                milestonesReached.insert(milestone)
                // Clear 3-4 random tiles as bomb reward
                // Avoid clearing the newly created milestone tile itself
                clearRandomTiles(count: Int.random(in: 3...4), protectValue: newHighTile)
                break
            }
        }
    }
    
    private func clearRandomTiles(count: Int, protectValue: Int? = nil) {
        var filledPositions: [Position] = []
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let position = Position(row: row, col: col)
                if let tile = state.board[position] {
                    // Keep milestone tile(s) on the board when rewarding the player
                    if let protectValue, tile.value == protectValue {
                        continue
                    }
                    filledPositions.append(position)
                }
            }
        }
        
        let toClear = min(count, filledPositions.count / 2) // Don't clear more than half
        for _ in 0..<toClear {
            guard !filledPositions.isEmpty else { break }
            let index = Int(rng.next() % UInt64(filledPositions.count))
            let position = filledPositions.remove(at: index)
            state.board[position] = nil
        }
    }

    private func updateLevel() {
        // Level increments based on highest tile achieved
        let tileToLevel = [
            128: 2, 256: 3, 512: 4, 1024: 5,
            2048: 10, 4096: 20, 8192: 30,
            16384: 40, 32768: 50, 65536: 60
        ]
        
        for (tile, level) in tileToLevel {
            if state.highestTile >= tile {
                state.level = max(state.level, level)
            }
        }
    }
    
    private func hasValidMoves() -> Bool {
        // Check if any two adjacent identical tiles exist
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let position = Position(row: row, col: col)
                guard let tile = state.board[position] else { continue }
                
                let directions = config.allowDiagonals ? Direction.allCases : [Direction.up, .down, .left, .right]
                for direction in directions {
                    let neighbor = position.moved(in: direction)
                    if neighbor.isValid(for: state.board),
                       let neighborTile = state.board[neighbor],
                       neighborTile.value == tile.value {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    private func generateRandomValue() -> Int {
        // For high milestones (>= 67M), spawn tiles close to current progress
        if state.highestTile >= 67_108_864 {
            let highSpawn = spawnNearHighest()
            if let highSpawn {
                return highSpawn
            }
        }
        
        return spawnProgressively(from: minAllowedSpawnValue())
    }

    private func spawnNearHighest() -> Int? {
        let highest = state.highestTile
        guard highest >= 2 else { return nil }
        
        let maxSpawn = max(2, highest >> 1)
        let minSpawn = max(2, highest >> 7)
        let eliminationThreshold = max(2, getEliminationThreshold())
        let actualMinSpawn = min(maxSpawn, max(minSpawn, eliminationThreshold))

        guard actualMinSpawn <= maxSpawn else { return nil }
        
        var candidates: [Int] = []
        var current = actualMinSpawn
        var iterations = 0
        
        while current <= maxSpawn && iterations < 7 {
            candidates.append(current)
            if current > (Int.max >> 1) { break }
            current = current << 1
            iterations += 1
        }

        guard !candidates.isEmpty else { return nil }
        let index = Int(rng.next() % UInt64(candidates.count))
        return candidates[index]
    }

    private func spawnProgressively(from start: Int) -> Int {
        var candidates: [Int] = []
        var current = max(2, start)
        for _ in 0..<7 {
            candidates.append(current)
            if current > (Int.max >> 1) {
                current = Int.max
            } else {
                current = current << 1
            }
        }
        let index = Int(rng.next() % UInt64(candidates.count))
        return candidates[index]
    }

    private func getEliminationThreshold() -> Int {
        // Get the elimination threshold based on reached milestones
        if let highestLargeMilestone = eliminatedMilestones.filter({ $0 >= 67_108_864 }).max() {
            return highestLargeMilestone >> 14
        }
        return 2
    }

    private func minAllowedSpawnValue() -> Int {
        // Check if we have any eliminated milestones >= 67M
        let largeMilestones = eliminatedMilestones.filter { $0 >= 67108864 }
        if let highestLargeMilestone = largeMilestones.max() {
            // For milestones >= 67M:
            // - Minimum spawn should be above the elimination threshold
            // - We use 7 steps down from the milestone as the spawn base
            let eliminationThreshold = highestLargeMilestone >> 14  // What gets eliminated
            let spawnBase = highestLargeMilestone >> 7  // 7 steps down from milestone

            // Use whichever is higher to ensure we don't spawn below elimination threshold
            return max(eliminationThreshold, spawnBase)
        }

        // For milestones < 67M, use the old logic: min spawn is X*2 where X is eliminated value
        if let removed = latestEliminatedValue() {
            // Protect against overflow when doubling
            let doubled = removed <= (Int.max >> 1) ? removed << 1 : Int.max
            return max(2, doubled)
        }
        return 2
    }
    
    /// Returns all milestones between two values (useful for tracking what was passed)
    public func milestonesBetween(_ previousHighest: Int, and newHighest: Int) -> [Int] {
        var milestones: [Int] = []

        // ALL milestones including early ones
        let standardMilestones = [
            128, 256, 512, 1024,  // Early milestones
            2048, 4096, 8192, 16384, 32768, 65536, 131072,
            262144, 524288, 1048576, 2097152,
            4194304, 8388608, 16777216, 33554432,
            67108864, 134217728
        ]

        for milestone in standardMilestones {
            if milestone > previousHighest && milestone <= newHighest {
                milestones.append(milestone)
            }
        }

        // Handle milestones beyond 134M using the infinite repeating pattern
        if newHighest >= 268435456 {
            var currentMilestone = 268435456
            while currentMilestone <= newHighest {
                if currentMilestone > previousHighest {
                    milestones.append(currentMilestone)
                }
                if currentMilestone > Int.max / 2 {
                    break
                }
                currentMilestone *= 2
            }
        }

        return milestones
    }

    /// Returns the tile value that gets added to the spawn pool when reaching a milestone
    /// Returns nil if no new tiles are added for this milestone
    public func milestoneAddedValue(for milestone: Int) -> Int? {
        // Skip milestones don't add anything to spawn pool
        let skipMilestones = [8192, 131072, 2097152, 33554432]
        if skipMilestones.contains(milestone) {
            return nil
        }

        // For milestones beyond 134M, check skip pattern
        if milestone >= 268435456 {
            let log67M = 26 // log2(67108864)
            let logMilestone = Int(log2(Double(milestone)))
            let position = logMilestone - log67M
            // Every 3rd position (2, 5, 8, 11...) is a skip
            if position % 3 == 2 {
                return nil // Skip milestone
            }
        }

        // For ALL other milestones, calculate what gets added
        // If there's an explicit elimination, use that to calculate added value
        if let eliminated = milestoneExcludedValue(for: milestone) {
            // When we eliminate X, we add tiles 7 steps above X
            let addedSpawnValue = eliminated <= (Int.max >> 7) ? eliminated << 7 : Int.max
            return addedSpawnValue
        }

        // For milestones without explicit elimination (like 128, 256, 512, 1024)
        // They still add new tiles to the spawn pool
        // The added value is typically the milestone divided by 16 then multiplied by 128
        // This gives us a value 7 steps above what would be eliminated
        if milestone >= 128 {
            // For these milestones, we add tiles based on the milestone value
            // The pattern is: milestone/16 is roughly what gets "eliminated"
            // And we add 7 steps above that
            let implicitEliminated = milestone / 16
            if implicitEliminated >= 1 {
                let addedSpawnValue = implicitEliminated <= (Int.max >> 7) ? implicitEliminated << 7 : Int.max
                return addedSpawnValue
            }
        }

        return nil
    }

    /// Returns the tile value that gets eliminated when reaching a milestone
    /// Returns nil if the milestone doesn't eliminate anything (skip milestone)
    public func milestoneExcludedValue(for milestone: Int) -> Int? {
        // Skip milestones don't eliminate anything
        let skipMilestones = [8192, 131072, 2097152, 33554432]
        if skipMilestones.contains(milestone) {
            return nil
        }

        // Explicit elimination pattern for major milestones
        switch milestone {
        case 128: return 1         // 128 eliminates 1s (if they exist)
        case 256: return 1         // 256 eliminates 1s
        case 512: return 1         // 512 eliminates 1s
        case 1024: return 1        // 1024 eliminates 1s
        case 2048: return 2        // 2K eliminates 2s
        case 4096: return 4        // 4K eliminates 4s
        case 8192: return nil      // 8K - skip
        case 16384: return 8       // 16K eliminates 8s
        case 32768: return 16      // 32K eliminates 16s
        case 65536: return 32      // 65K eliminates 32s
        case 131072: return nil    // 131K - skip
        case 262144: return 64     // 262K eliminates 64s
        case 524288: return 128    // 524K eliminates 128s
        case 1048576: return 256   // 1M eliminates 256s
        case 2097152: return nil   // 2M - skip
        case 4194304: return 512   // 4M eliminates 512s
        case 8388608: return 1024  // 8M eliminates 1024s
        case 16777216: return 2048 // 16M eliminates 2048s
        case 33554432: return nil  // 33M - skip
        case 67108864: return 4096 // 67M eliminates 4096s
        case 134217728: return 8192 // 134M eliminates 8192s
        default:
            // For values beyond 134M, use the consistent pattern:
            // Eliminated value is always 14 steps (doublings) down from the milestone
            // Skip pattern still applies: every 3rd position relative to 67M skips
            if milestone >= 268435456 { // 268M and beyond
                // Calculate position relative to 67M for skip pattern
                let log67M = 26 // log2(67108864)
                let logMilestone = Int(log2(Double(milestone)))
                let position = logMilestone - log67M // How many doublings from 67M

                // Every 3rd position (2, 5, 8, 11...) is a skip
                if position % 3 == 2 {
                    return nil // Skip position
                }

                // Eliminated value is always 14 steps down from milestone
                // milestone / 2^14 = milestone >> 14
                let eliminated = milestone >> 14

                // Safeguard against underflow (though unlikely at these large values)
                return eliminated > 0 ? eliminated : nil
            }
            return nil
        }
    }
    
    private func milestoneProtectionValue(for milestone: Int) -> Int? {
        milestoneExcludedValue(for: milestone) != nil ? milestone : nil
    }
    
    private func latestEliminatedValue() -> Int? {
        // Find the highest eliminated value from all reached milestones
        var highestEliminatedValue: Int? = nil
        for milestone in eliminatedMilestones {
            if let eliminated = milestoneExcludedValue(for: milestone) {
                if highestEliminatedValue == nil || eliminated > highestEliminatedValue! {
                    highestEliminatedValue = eliminated
                }
            }
        }
        return highestEliminatedValue
    }

    // MARK: - Gravity and Refill (Always-Full)

    private func applyGravityDown() {
        state.board.applyGravity()
    }

    private func refillAfterGravity(applyGravity: Bool = true) {
        if applyGravity {
            applyGravityDown()
        }
        processPendingGiftRefillIfNeeded()
        if config.fillMode == .alwaysFull {
            refillToFullWithCascade()
        } else {
            refillToFull()
        }
    }

    private func refillToFull() {
        // In alwaysFull mode, fill ALL empty cells to keep board completely full
        // In match-3 auto-cascade gameplay, this ensures continuous action
        if config.fillMode == .alwaysFull {
            // Fill entire board
            for row in 0..<config.boardHeight {
                for col in 0..<config.boardWidth {
                    let pos = Position(row: row, col: col)
                    let boardIndex = BoardIndex(pos)
                    // Skip gift cells in top row
                    if state.board[boardIndex].kind == .gift {
                        continue
                    }
                    if state.board[pos] == nil {
                        state.board[pos] = Tile(value: generateRandomValue())
                    }
                }
            }
        } else {
            // Sparse mode: only spawn new tiles in the TOP ROW (row 0)
            // Tiles will fall down via gravity on next move
            for col in 0..<config.boardWidth {
                let pos = Position(row: 0, col: col)
                let boardIndex = BoardIndex(pos)
                // Skip gift cells in top row
                if state.board[boardIndex].kind == .gift {
                    continue
                }
                if state.board[pos] == nil {
                    state.board[pos] = Tile(value: generateRandomValue())
                }
            }
        }
    }
    
    private func refillToFullWithCascade() {
        // Spawn tiles only at the top and apply gravity repeatedly
        // This creates a natural cascade effect instead of tiles appearing mid-board
        var maxIterations = config.boardHeight * config.boardWidth // Safety limit
        
        while maxIterations > 0 {
            maxIterations -= 1
            
            // Count empty cells to check if board is full
            var emptyCount = 0
            for row in 0..<config.boardHeight {
                for col in 0..<config.boardWidth {
                    let pos = Position(row: row, col: col)
                    let boardIndex = BoardIndex(pos)
                    if state.board[boardIndex].kind != .gift && state.board[pos] == nil {
                        emptyCount += 1
                    }
                }
            }
            
            // If board is full, we're done
            if emptyCount == 0 { break }
            
            // Spawn new tiles ONLY in the TOP ROW
            for col in 0..<config.boardWidth {
                let pos = Position(row: 0, col: col)
                let boardIndex = BoardIndex(pos)
                // Skip gift cells in top row
                if state.board[boardIndex].kind == .gift {
                    continue
                }
                if state.board[pos] == nil {
                    state.board[pos] = Tile(value: generateRandomValue())
                }
            }
            
            // Apply gravity to make the newly spawned tiles fall down
            applyGravityDown()
        }
    }

    private func fillBoardToFull() {
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let pos = Position(row: row, col: col)
                let boardIndex = BoardIndex(pos)
                // Skip gift cells in top row
                if state.board[boardIndex].kind == .gift {
                    continue
                }
                if state.board[pos] == nil {
                    state.board[pos] = Tile(value: generateRandomValue())
                }
            }
        }
    }

    private func ensureAtLeastOneStartableLink(attempts: Int) {
        var remaining = max(0, attempts)
        while !state.board.hasAdjacentEqualPair(includeDiagonals: config.allowDiagonals) && remaining > 0 {
            rerollRandomCells(count: 3)
            remaining -= 1
        }
    }

    private func rerollRandomCells(count: Int) {
        guard count > 0 else { return }
        let total = config.boardWidth * config.boardHeight
        for _ in 0..<count {
            let index = Int(rng.next() % UInt64(total))
            let r = index / config.boardWidth
            let c = index % config.boardWidth
            let pos = Position(row: r, col: c)
            state.board[pos] = Tile(value: generateRandomValue())
        }
    }
    
    private func highestTileValue() -> Int {
        var maxVal = 0
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let pos = Position(row: row, col: col)
                if let tile = state.board[pos] {
                    if tile.value > maxVal { maxVal = tile.value }
                }
            }
        }
        return maxVal
    }
    
    private func lowestTileValue() -> Int {
        var minVal: Int = Int.max
        var found = false
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let pos = Position(row: row, col: col)
                if let tile = state.board[pos] {
                    if tile.value < minVal { minVal = tile.value }
                    found = true
                }
            }
        }
        return found ? minVal : 0
    }

    // MARK: - Milestone elimination helpers

    /// Apply eliminations for all milestones between two values
    private func applyAllMilestonesBetween(_ previousHighest: Int, and newHighest: Int) {
        print("🎯 Checking for milestone eliminations between \(formatLargeNumber(previousHighest)) and \(formatLargeNumber(newHighest))")

        // List of all elimination milestones (excluding skipped ones)
        let eliminationMilestones = [
            2048, 4096, // 8192 skipped
            16384, 32768, 65536, // 131072 skipped
            262144, 524288, 1048576, // 2097152 skipped
            4194304, 8388608, 16777216, // 33554432 skipped
            67108864, 134217728
        ]

        // Apply elimination for each milestone we've passed
        for milestone in eliminationMilestones {
            // Check if this milestone is newly reached
            if milestone > previousHighest && milestone <= newHighest {
                print("   📍 Passed milestone: \(formatLargeNumber(milestone))")
                applyMilestoneEliminationIfNeeded(createdValue: milestone)
            }
        }

        // Handle milestones beyond 134M using the infinite repeating pattern
        if newHighest >= 268435456 { // 268M and beyond
            var currentMilestone = 268435456 // Start at 268M
            while currentMilestone <= newHighest {
                if currentMilestone > previousHighest {
                    // Calculate position relative to 67M
                    let log67M = 26 // log2(67108864)
                    let logCurrent = Int(log2(Double(currentMilestone)))
                    let position = logCurrent - log67M

                    // Every 3rd position (2, 5, 8, 11...) is a skip
                    if position % 3 != 2 { // Not a skip position
                        print("   📍 Passed milestone: \(formatLargeNumber(currentMilestone))")
                        applyMilestoneEliminationIfNeeded(createdValue: currentMilestone)
                    }
                }

                // Safeguard against overflow when doubling
                if currentMilestone > Int.max / 2 {
                    break
                }
                currentMilestone *= 2
            }
        }
    }

    private func applyMilestoneEliminationIfNeeded(createdValue: Int) {
        print("🎯 Checking milestone elimination for value: \(formatLargeNumber(createdValue))")

        // For milestones >= 67M, use threshold elimination
        // This eliminates all tiles below (milestone >> 14)
        if createdValue >= 67_108_864 { // 67M or higher
            // Check if it's a skip milestone
            let log67M = 26 // log2(67108864)
            let logMilestone = Int(log2(Double(createdValue)))
            let position = logMilestone - log67M

            // Skip milestones don't eliminate anything
            if createdValue >= 268_435_456 && position % 3 == 2 {
                print("🔄 SKIP MILESTONE: Reached \(formatLargeNumber(createdValue)) - no elimination")
                eliminatedMilestones.insert(createdValue)
                return
            }

            // Eliminate everything below (createdValue >> 14)
            let threshold = createdValue >> 14

            print("🗑️ MILESTONE ELIMINATION: Reached \(formatLargeNumber(createdValue))")
            print("   Eliminating all tiles below \(formatLargeNumber(threshold))")

            eliminateAllTilesBelowThreshold(threshold: threshold)

            // Mark this milestone as reached
            eliminatedMilestones.insert(createdValue)
            return
        }

        // For milestones < 67M, use the original single-value elimination
        guard let toRemove = milestoneExcludedValue(for: createdValue) else {
            print("   ✅ No elimination for \(formatLargeNumber(createdValue)) - skip milestone or not a milestone")
            return
        }

        let isNewMilestone = eliminatedMilestones.insert(createdValue).inserted
        if isNewMilestone {
            print("🗑️ MILESTONE ELIMINATION: Reached \(createdValue), eliminating \(toRemove) from board and spawn pool")
        } else {
            print("🔁 MILESTONE RE-ELIMINATION: Reached \(createdValue) again, purging \(toRemove)")
        }

        eliminateAllTiles(withValue: toRemove)
    }

    private func formatLargeNumber(_ value: Int) -> String {
        if value >= 1_000_000_000_000 {
            return "\(value / 1_000_000_000_000)T"
        } else if value >= 1_000_000_000 {
            return "\(value / 1_000_000_000)B"
        } else if value >= 1_000_000 {
            return "\(value / 1_000_000)M"
        } else if value >= 1_000 {
            return "\(value / 1_000)K"
        } else {
            return "\(value)"
        }
    }
    
    private func eliminateAllTiles(withValue value: Int) {
        var didRemove = false
        var removedCount = 0

        // IMMEDIATELY scan and remove ALL tiles with this value
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let pos = Position(row: row, col: col)
                if let tile = state.board[pos], tile.value == value {
                    state.board[pos] = nil
                    didRemove = true
                    removedCount += 1
                }
            }
        }

        if didRemove {
            print("   ✅ Eliminated \(removedCount) tiles of value \(value)")
            // IMMEDIATELY pull down and refill so the board stays valid
            refillAfterGravity()
            print("   ✅ Board refilled with higher-value tiles only")
        }
    }

    private func eliminateAllTilesBelowThreshold(threshold: Int) {
        var didRemove = false
        var removedCount = 0
        var removedValues = Set<Int>()

        // Remove ALL tiles below the threshold
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let pos = Position(row: row, col: col)
                if let tile = state.board[pos], tile.value < threshold {
                    removedValues.insert(tile.value)
                    state.board[pos] = nil
                    didRemove = true
                    removedCount += 1
                }
            }
        }

        if didRemove {
            print("   ✅ Eliminated \(removedCount) tiles below \(threshold)")
            print("      Removed values: \(removedValues.sorted())")
            // IMMEDIATELY pull down and refill so the board stays valid
            refillAfterGravity()
            print("   ✅ Board refilled with higher-value tiles only")
        }
    }

    // MARK: - Auto-Cascade Merge System
    
    /// Find all groups of adjacent matching tiles on the board
    /// - Parameter excludePosition: Optional position to exclude from matching groups (protects player-created tiles)
    /// - Parameter protectedMilestoneValue: Optional milestone value to protect from merging
    private func findMatchingGroups(excludePosition: Position? = nil, protectedMilestoneValue: Int? = nil) -> [[Position]] {
        var visited = Set<Position>()
        var groups: [[Position]] = []

        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let pos = Position(row: row, col: col)

                // Skip if already visited or empty
                guard !visited.contains(pos),
                      let tile = state.board[pos],
                      tile.canMerge else {
                    continue
                }

                // Find all connected tiles with same value using flood fill
                var group: [Position] = []
                var queue: [Position] = [pos]
                let referenceTile = tile

                while !queue.isEmpty {
                    let current = queue.removeFirst()

                    // Skip if already visited
                    guard !visited.contains(current) else { continue }

                    // Check if this tile matches
                    guard let currentTile = state.board[current],
                          currentTile.canMerge,
                          tilesMatch(currentTile, referenceTile) else {
                        continue
                    }

                    // Add to group and mark as visited
                    group.append(current)
                    visited.insert(current)

                // Add adjacent tiles to queue (match-3 style: orthogonal only)
                let directions: [Direction] = [.up, .down, .left, .right]
                    for direction in directions {
                        let neighbor = current.moved(in: direction)
                        if neighbor.isValid(for: state.board) && !visited.contains(neighbor) {
                            queue.append(neighbor)
                        }
                    }
                }

                // Only keep groups of 3 or more tiles (match-3 style)
                if group.count >= 3 {
                    if let excludePos = excludePosition, group.contains(excludePos) {
                        // Skip this group - it contains the player's newly created tile
                        continue
                    }
                    if let protectValue = protectedMilestoneValue {
                        let containsProtectedValue = group.contains { pos in
                            guard let tile = state.board[pos] else { return false }
                            return tile.value == protectValue
                        }
                        if containsProtectedValue {
                            print("🛡️ PROTECTED: Skipping merge group containing milestone value \(protectValue)")
                            continue
                        }
                    }
                    groups.append(group)
                }
            }
        }

        return groups
    }
    
    private func tilesMatch(_ a: Tile?, _ b: Tile?) -> Bool {
        guard let left = a, let right = b else { return false }
        return left.matches(right)
    }
    
    /// Merge a group of matching tiles and return the score earned
    @discardableResult
    private func mergeGroup(_ group: [Position]) -> (value: Int, step: Int) {
        guard group.count >= 3 else { return (0, 0) }
        let tiles = group.compactMap { state.board[$0] }
        guard tiles.count == group.count else { return (0, 0) }
        let steps = tiles.compactMap { TileStepMath.step(for: $0) }
        guard steps.count == tiles.count else { return (0, 0) }
        let mergedStep = TileStepMath.mergedStep(from: steps)
        let mergedValue = TileStepMath.value(forStep: mergedStep)
        
        // Find the lowest position in the group (bottom-most, then leftmost)
        let mergePosition = group.sorted { a, b in
            if a.row != b.row {
                return a.row > b.row // Lower row number = lower on screen
            }
            return a.col < b.col // Leftmost
        }.first!
        
        // Remove all tiles in the group
        for pos in group {
            state.board[pos] = nil
        }
        
        // Place merged tile at the merge position
        state.board[mergePosition] = Tile.make(forStep: mergedStep)
        
        // Update highest tile
        if mergedStep > state.highestTileStep {
            let previousHighest = state.highestTile
            state.highestTile = max(mergedValue, state.highestTile)
            state.highestTileStep = mergedStep
            highestTileAchieved = state.highestTile
            updateLevel()
            checkMilestoneRewards(mergedValue)
        
            // Apply eliminations for ALL milestones between previous highest and new value
            applyAllMilestonesBetween(previousHighest, and: mergedValue)
        } else {
            // Even if not a new highest, check if this specific value triggers elimination
        applyMilestoneEliminationIfNeeded(createdValue: mergedValue)
        }
        
        return (mergedValue, mergedStep)
    }
    
    /// Perform one cascade step: find and merge all matching groups
    /// - Parameter excludePosition: Optional position to exclude from first cascade iteration
    /// - Parameter protectedMilestoneValue: Optional milestone value to protect across all iterations
    /// - Returns: Tuple of (merged: whether any merges occurred, score: points earned)
    @discardableResult
    private func performCascadeStep(
        excludePosition: Position? = nil,
        protectedMilestoneValue: Int? = nil
    ) -> (merged: Bool, score: Int, alpha: AlphaNumber) {
        let groups = findMatchingGroups(excludePosition: excludePosition, protectedMilestoneValue: protectedMilestoneValue)

        guard !groups.isEmpty else {
            return (false, 0, .zero)
        }

        var totalScore = 0
        var totalAlpha = AlphaNumber.zero

        // Merge all groups
        for group in groups {
            let result = mergeGroup(group)
            totalScore += result.value
            totalAlpha.addPowerStep(result.step)
        }

        // Apply gravity and refill from top (creates natural cascade effect)
        applyGravityDown()

        // Use cascade-aware refill that spawns only from top
        if config.fillMode == .alwaysFull {
            refillToFullWithCascade()
        } else {
            refillToFull()
        }

        return (true, totalScore, totalAlpha)
    }
    
    /// Run the full cascade: repeatedly merge until no more matches exist
    /// - Parameter protectPosition: Optional position to protect in the first cascade only (prevents immediate merging of player-created tiles)
    /// - Parameter protectedValue: Optional milestone value to protect across all iterations
    /// - Returns: Total score from all cascades
    @discardableResult
    public func runAutoCascade(protectPosition: Position? = nil, protectedValue: Int? = nil) -> Int {
        var totalScore = 0
        var totalAlpha = AlphaNumber.zero
        var cascadeCount = 0
        let maxCascades = 50 // Safety limit to prevent infinite loops

        while cascadeCount < maxCascades {
            // Only protect the position in the FIRST cascade iteration
            let excludePos = (cascadeCount == 0) ? protectPosition : nil
            let result = performCascadeStep(
                excludePosition: excludePos,
                protectedMilestoneValue: protectedValue
            )

            if !result.merged {
                break // No more matches found
            }

            // Safe addition to prevent overflow
            let (newTotal, overflow) = totalScore.addingReportingOverflow(result.score)
            totalScore = overflow ? Int.max : newTotal
            totalAlpha.add(result.alpha)
            cascadeCount += 1
        }

        // Award score with combo multiplier for cascades
        if cascadeCount > 1 {
            // Bonus for combos: 2x for 2 cascades, 3x for 3, etc.
            // Use safe multiplication to prevent overflow
            let (bonusProduct, overflowMult) = totalScore.multipliedReportingOverflow(by: cascadeCount - 1)
            let comboBonus = overflowMult ? Int.max / 2 : bonusProduct / 2
            let (newTotal, overflowAdd) = totalScore.addingReportingOverflow(comboBonus)
            totalScore = overflowAdd ? Int.max : newTotal
            
            totalAlpha.multiply(by: cascadeCount + 1)
            totalAlpha.halve()
        }

        if cascadeCount > 0 {
            addScoreAlpha(totalAlpha)
        }

        return totalScore
    }
    
    // MARK: - Safe Arithmetic Helpers
    
    /// Safely add two integers, capping at Int.max to prevent overflow
    private func safeAddScore(_ a: Int, _ b: Int) -> Int {
        let gain = applyScoreMultiplier(to: b)
        let (result, overflow) = a.addingReportingOverflow(gain)
        return overflow ? Int.max : result
    }
    
    private func applyScoreMultiplier(to value: Int) -> Int {
        guard scoreMultiplier > 1, value > 0 else { return value }
        let (product, overflow) = value.multipliedReportingOverflow(by: scoreMultiplier)
        return overflow ? Int.max : product
    }
    
    private func addScoreForStep(_ step: Int) {
        state.scoreValue.addPowerStep(step)
        let mergedValue = TileStepMath.value(forStep: step)
        state.score = safeAddScore(state.score, mergedValue)
    }
    
    private func addScoreValue(_ value: Int) {
        guard value > 0 else { return }
        state.scoreValue.add(value)
        state.score = safeAddScore(state.score, value)
    }
    
    private func addScoreAlpha(_ alpha: AlphaNumber) {
        guard !alpha.isZero else { return }
        state.scoreValue.add(alpha)
        state.score = safeAddScore(state.score, alpha.toInt())
    }
    
    // MARK: - Test Helpers (internal)
    // These helpers are internal for use in @testable imports only.
    func _setTileForTesting(at position: Position, value: Int?) {
        if let v = value {
            state.board[position] = Tile(value: v)
        } else {
            state.board[position] = nil
        }
    }

    func _setHighValueTileForTesting(at position: Position, step: Int) {
        state.board[position] = Tile.make(forStep: step)
    }
    
    func _setAllTilesForTesting(value: Int?) {
        for row in 0..<state.board.height {
            for col in 0..<state.board.width {
                let pos = Position(row: row, col: col)
                if let v = value {
                    state.board[pos] = Tile(value: v)
                } else {
                    state.board[pos] = nil
                }
            }
        }
    }
    
    func _resetScoreForTesting() {
        state.score = 0
        state.scoreValue = .zero
        state.moves = 0
    }

    func _setLastMergeAtMsForTesting(_ value: Int?) {
        lastMergeAtMs = value
    }
    
    func _applyMilestoneEliminationForTesting(createdValue: Int) {
        applyMilestoneEliminationIfNeeded(createdValue: createdValue)
    }
    
    func _latestEliminatedValueForTesting() -> Int? {
        latestEliminatedValue()
    }
}

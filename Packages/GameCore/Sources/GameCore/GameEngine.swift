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
    public var moves: Int
    public var isGameOver: Bool
    public var highestTile: Int
    public var level: Int
    public var gems: Int
    public var undoAvailable: Bool
    
    public init(board: Board, score: Int = 0, moves: Int = 0, isGameOver: Bool = false, highestTile: Int = 0, level: Int = 1, gems: Int = 0, undoAvailable: Bool = false) {
        self.board = board
        self.score = score
        self.moves = moves
        self.isGameOver = isGameOver
        self.highestTile = highestTile
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
    }
    
    public func currentState() -> GameState {
        state
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
        
        let values = tiles.map { $0.value }
        
        // 2244 rules: First two tiles must be identical
        guard values.count >= 2 else {
            return .invalid("Chain must have at least 2 tiles")
        }
        
        guard values[0] == values[1] else {
            return .invalid("First two tiles must have the same value")
        }
        
        // After the first two, each tile must be same value or double the previous
        var currentValue = values[0]
        for i in 2..<values.count {
            let value = values[i]
            if value == currentValue {
                continue
            } else if value == currentValue * 2 {
                currentValue = value
            } else {
                return .invalid("Each tile must be the same value or double the previous value")
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
        let chainScore = outcome.resultValue
        state.score += chainScore
        state.moves += 1
        
        // Update highest tile and level
        if outcome.resultValue > state.highestTile {
            state.highestTile = outcome.resultValue
            highestTileAchieved = outcome.resultValue
            updateLevel()
            checkMilestoneRewards(outcome.resultValue)
        }
        
        // Apply milestone elimination if needed (remove specific tier when milestone is created)
        applyMilestoneEliminationIfNeeded(createdValue: outcome.resultValue)
        
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
        
        // Apply gravity using the enhanced Board method
        state.board.applyGravity()
        
        // If a gift was broken, refill the top row with a new gift
        if outcome.giftBroken {
            // Generate values first to avoid concurrent access
            let giftValue = generateRandomValue()
            state.board.refillTopRowWithGifts { giftValue }
        }
        
        // Generate values for refill to avoid concurrent access
        var refillValues: [Int] = []
        for _ in 0..<(state.board.width * state.board.height) {
            refillValues.append(generateRandomValue())
        }
        var refillIndex = 0
        
        // Refill remaining empty cells to keep board full
        state.board.refillEmptyCells { 
            let value = refillValues[refillIndex % refillValues.count]
            refillIndex += 1
            return value
        }
        
        // Check for game over
        if !hasValidMoves() {
            state.isGameOver = true
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
    
    public func commitChain(_ positions: [Position]) -> GameState {
        guard validateChain(positions).isValid else { return state }
        
        // Save previous state for undo
        previousState = state
        state.undoAvailable = true
        
        let values = positions.compactMap { state.board[$0]?.value }
        
        // Merge rule: Round SUM up to the next power of two (inclusive).
        // Overflow-safe summation and rounding
        let sumResult = values.reduce((total: 0, overflowed: false)) { acc, value in
            let (next, didOverflow) = acc.total.addingReportingOverflow(value)
            return (didOverflow ? Int.max : next, acc.overflowed || didOverflow)
        }
        let chainSum = sumResult.total
        let mergedValue: Int = {
            if sumResult.overflowed { return Int.max }
            guard chainSum > 0 else { return 0 }
            if chainSum & (chainSum - 1) == 0 { return chainSum }
            if chainSum > (1 << 62) { return Int.max }
            var x = chainSum - 1
            x |= x >> 1
            x |= x >> 2
            x |= x >> 4
            x |= x >> 8
            x |= x >> 16
            #if arch(x86_64) || arch(arm64)
            x |= x >> 32
            #endif
            let next = x + 1
            return next > 0 ? next : Int.max
        }()
        
        // Score equals the resulting merged tile value (no combo multipliers)
        let nowMs = Int(Date().timeIntervalSince1970 * 1000)
        let chainScore = mergedValue
        
        // Remove all tiles in the chain
        for position in positions.dropLast() {
            state.board[position] = nil
        }
        
        // Place merged tile at the last position in the chain
        if let lastPosition = positions.last {
            state.board[lastPosition] = Tile(value: mergedValue)
        }
        
        // Update highest tile and level
        if mergedValue > state.highestTile {
            state.highestTile = mergedValue
            highestTileAchieved = mergedValue
            updateLevel()
            checkMilestoneRewards(mergedValue)
        }
        
        // Apply milestone elimination if needed (remove specific tier when milestone is created)
        applyMilestoneEliminationIfNeeded(createdValue: mergedValue)
        
        // Award points
        state.score += chainScore
        state.moves += 1
        lastMergeAtMs = nowMs
        
        // Award gems for long chains (10+ tiles)
        if positions.count >= 10 {
            state.gems += positions.count / 5 // 2 gems per 10 tiles
        }
        
        // Always-full policy: apply gravity and refill to keep the board dense
        applyGravityDown()
        refillToFull()
        
        // Check for game over
        if !hasValidMoves() {
            state.isGameOver = true
        }
        
        return state
    }
    
    // MARK: - Power-ups
    
    @discardableResult
    public func hammer(at position: Position) -> GameState {
        guard position.isValid(for: state.board), state.board[position] != nil else {
            return state
        }
        
        // Save state for undo
        previousState = state
        state.undoAvailable = true
        
        state.board[position] = nil
        state.moves += 1
        // Keep board full after destructive action
        applyGravityDown()
        refillToFull()
        
        if !hasValidMoves() {
            state.isGameOver = true
        }
        
        return state
    }
    
    @discardableResult
    public func swap(_ a: Position, _ b: Position) -> GameState {
        guard a.isValid(for: state.board), b.isValid(for: state.board) else { return state }
        guard a != b else { return state }
        // Swap power-up can swap ANY two tiles, not just adjacent ones
        
        // Save state for undo
        previousState = state
        state.undoAvailable = true
        
        let temp = state.board[a]
        state.board[a] = state.board[b]
        state.board[b] = temp
        state.moves += 1
        
        if !hasValidMoves() {
            state.isGameOver = true
        }
        
        return state
    }
    
    @discardableResult
    public func magnetize(value: Int, to position: Position) -> GameState {
        guard position.isValid(for: state.board) else { return state }
        guard state.board[position] != nil else { return state }
        
        // Save state for undo
        previousState = state
        state.undoAvailable = true
        
        // Find all tiles with the target value
        var tilesToMove: [Position] = []
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let pos = Position(row: row, col: col)
                if let tile = state.board[pos], tile.value == value && pos != position {
                    tilesToMove.append(pos)
                }
            }
        }
        
        // Move tiles toward the target position (adjacent positions)
        for tilePos in tilesToMove {
            let neighbors = state.board.neighbors(of: position, includeDiagonals: config.allowDiagonals)
            for neighbor in neighbors where state.board[neighbor] == nil {
                state.board[neighbor] = state.board[tilePos]
                state.board[tilePos] = nil
                break
            }
        }
        
        // Apply gravity after magnetization
        applyGravityDown()
        refillToFull()
        
        state.moves += 1
        
        if !hasValidMoves() {
            state.isGameOver = true
        }
        
        return state
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
        state.board[position] = Tile(value: doubled)
        // Update highest tile & level if needed
        if doubled > state.highestTile {
            state.highestTile = doubled
            highestTileAchieved = doubled
            updateLevel()
        }
        // Apply milestone elimination if needed
        applyMilestoneEliminationIfNeeded(createdValue: doubled)
        
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
            ensureAtLeastOneStartableLink(attempts: 8)
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
                clearRandomTiles(count: Int.random(in: 3...4))
                break
            }
        }
    }
    
    private func clearRandomTiles(count: Int) {
        var filledPositions: [Position] = []
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let position = Position(row: row, col: col)
                if state.board[position] != nil {
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
        // Progressive spawning: always spawn from the seven lowest allowed tiles
        // Window is based on the latest eliminated tier only.
        let minAllowed = minAllowedSpawnValue()
        var candidates: [Int] = []
        var current = minAllowed
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

    private func minAllowedSpawnValue() -> Int {
        // If we’ve eliminated X, min spawn is X*2; otherwise 2.
        if let removed = latestEliminatedValue() {
            return max(2, removed << 1)
        }
        return 2
    }
    
    private func latestEliminatedValue() -> Int? {
        // Find the highest milestone achieved and eliminated (or achievable by highestTile)
        let triggers = EliminationRules.map.keys.sorted()
        var lastRemoved: Int? = nil
        for t in triggers where t <= state.highestTile {
            lastRemoved = EliminationRules.map[t]
        }
        return lastRemoved
    }

    // MARK: - Gravity and Refill (Always-Full)

    private func applyGravityDown() {
        // Compact each column so tiles fall toward bottom
        for col in 0..<config.boardWidth {
            var writeRow = config.boardHeight - 1
            var row = config.boardHeight - 1
            while row >= 0 {
                let pos = Position(row: row, col: col)
                if let tile = state.board[pos] {
                    if writeRow != row {
                        let writePos = Position(row: writeRow, col: col)
                        state.board[writePos] = tile
                        state.board[pos] = nil
                    }
                    writeRow -= 1
                }
                row -= 1
            }
        }
    }

    private func refillToFull() {
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

    private func applyMilestoneEliminationIfNeeded(createdValue: Int) {
        guard let toRemove = EliminationRules.map[createdValue] else { return }
        // Only trigger once per milestone creation
        if !eliminatedMilestones.contains(createdValue) {
            eliminatedMilestones.insert(createdValue)
            // Remove lower value tiles from board (NOT the milestone itself)
            eliminateAllTiles(withValue: toRemove)
        }
    }
    
    private func eliminateAllTiles(withValue value: Int) {
        var didRemove = false
        for row in 0..<config.boardHeight {
            for col in 0..<config.boardWidth {
                let pos = Position(row: row, col: col)
                if let tile = state.board[pos], tile.value == value {
                    state.board[pos] = nil
                    didRemove = true
                }
            }
        }
        if didRemove {
            // Pull down and refill so the board stays valid
            applyGravityDown()
            refillToFull()
        }
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
    
    func _resetScoreForTesting() {
        state.score = 0
        state.moves = 0
    }

    func _setLastMergeAtMsForTesting(_ value: Int?) {
        lastMergeAtMs = value
    }
}

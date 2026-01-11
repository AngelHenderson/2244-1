import Foundation

// MARK: - Enhanced Data Model for Gift Support

public enum CellKind: Equatable, Sendable, Codable {
    case tile
    case gift
    case empty
}

public struct BoardIndex: Hashable, Sendable, Codable {
    public let row: Int
    public let col: Int
    
    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }
    
    public init(_ position: Position) {
        self.row = position.row
        self.col = position.col
    }
    
    public var position: Position {
        Position(row: row, col: col)
    }
}

public struct Gift: Equatable, Sendable, Codable {
    public let id: UUID
    public let targetValue: Int
    
    public init(targetValue: Int = 0) {
        self.id = UUID()
        self.targetValue = targetValue
    }
}

public struct Cell: Equatable, Sendable, Codable {
    public var kind: CellKind
    public var tile: Tile?
    public var gift: Gift?
    
    public init(kind: CellKind = .empty, tile: Tile? = nil, gift: Gift? = nil) {
        self.kind = kind
        self.tile = tile
        self.gift = gift
    }
    
    public static func withTile(_ tile: Tile) -> Cell {
        Cell(kind: .tile, tile: tile)
    }
    
    public static func withGift(_ gift: Gift) -> Cell {
        Cell(kind: .gift, gift: gift)
    }
    
    public static let empty = Cell(kind: .empty)
}

public struct MergeOutcome: Sendable, Codable {
    public let consumed: [BoardIndex]
    public let resultAt: BoardIndex
    public let resultValue: Int
    public let resultStep: Int
    public let giftBroken: Bool
    public let giftColumn: Int?

    public init(
        consumed: [BoardIndex],
        resultAt: BoardIndex,
        resultValue: Int,
        resultStep: Int,
        giftBroken: Bool = false,
        giftColumn: Int? = nil
    ) {
        self.consumed = consumed
        self.resultAt = resultAt
        self.resultValue = resultValue
        self.resultStep = resultStep
        self.giftBroken = giftBroken
        self.giftColumn = giftColumn
    }
}

public struct Board: Equatable, Sendable, Codable {
    public let width: Int
    public let height: Int
    public private(set) var cells: [[Cell]]
    
    public init(width: Int = 5, height: Int = 8) {
        self.width = width
        self.height = height
        self.cells = Array(repeating: Array(repeating: Cell.empty, count: width), count: height)
    }
    
    // MARK: - Legacy Tile Access (for compatibility)
    public subscript(position: Position) -> Tile? {
        get {
            guard position.isValid(for: self) else { return nil }
            return cells[position.row][position.col].tile
        }
        set {
            guard position.isValid(for: self) else { return }
            if let tile = newValue {
                cells[position.row][position.col] = Cell.withTile(tile)
            } else {
                // Only set to empty if the cell is not a gift, to avoid accidentally clearing gifts.
                if cells[position.row][position.col].kind != .gift {
                    cells[position.row][position.col] = Cell.empty
                }
            }
        }
    }
    
    // MARK: - Enhanced Cell Access
    public subscript(index: BoardIndex) -> Cell {
        get {
            guard isValid(index) else { return Cell.empty }
            return cells[index.row][index.col]
        }
        set {
            guard isValid(index) else { return }
            cells[index.row][index.col] = newValue
        }
    }
    
    public func cell(at position: Position) -> Cell {
        return self[BoardIndex(position)]
    }
    
    public mutating func setCell(_ cell: Cell, at index: BoardIndex) {
        self[index] = cell
    }
    
    public func isValid(_ index: BoardIndex) -> Bool {
        return index.row >= 0 && index.row < height && index.col >= 0 && index.col < width
    }
    
    // MARK: - Gift Management
    public mutating func placeGift(_ gift: Gift, at index: BoardIndex) {
        guard isValid(index) else { return }
        cells[index.row][index.col] = Cell.withGift(gift)
    }
    
    public func giftPositions() -> [BoardIndex] {
        var positions: [BoardIndex] = []
        for row in 0..<height {
            for col in 0..<width {
                let index = BoardIndex(row: row, col: col)
                if self[index].kind == .gift {
                    positions.append(index)
                }
            }
        }
        return positions
    }
    
    // MARK: - Chain Validation Helpers
    public func isAdjacent(_ a: BoardIndex, _ b: BoardIndex) -> Bool {
        return abs(a.row - b.row) <= 1 && abs(a.col - b.col) <= 1 && !(a.row == b.row && a.col == b.col)
    }
    
    public func canAppend(next index: BoardIndex, to chain: [BoardIndex]) -> Bool {
        guard let last = chain.last, isAdjacent(last, index), !chain.contains(index) else { 
            return false 
        }
        
        let lastCell = self[last]
        let nextCell = self[index]
        
        // If next is gift: only allow if this would be FINAL; caller enforces terminal step.
        if nextCell.kind == .gift { 
            return true // provisional; must be last
        }
        
        guard lastCell.kind == .tile, nextCell.kind == .tile,
              let lastTile = lastCell.tile,
              let nextTile = nextCell.tile,
              let lastStep = TileStepMath.step(for: lastTile),
              let nextStep = TileStepMath.step(for: nextTile) else { 
            return false 
        }
        
        // 2244 rule: after starting with two equal tiles, you can continue with same or double
        if chain.count < 2 {
            // need at least 2 identical to start
            return nextStep == lastStep
        } else {
            return nextStep == lastStep || nextStep == lastStep + 1
        }
    }
    
    // MARK: - Enhanced Merge Logic
    
    public mutating func performMerge(chain: [BoardIndex], endingOnGift: Bool = false) -> MergeOutcome? {
        guard chain.count >= 2 else { return nil }
        
        // Validate chain except the final gift step
        var path: [BoardIndex] = [chain[0]]
        for i in 1..<chain.count {
            let idx = chain[i]
            let nextCell = self[idx]
            let nextIsGift = nextCell.kind == .gift
            let isTerminalGift = nextIsGift && (i == chain.count - 1)
            
            if !isTerminalGift && !canAppend(next: idx, to: path) { 
                return nil 
            }
            path.append(idx)
        }
        
        let stepsOnPath: [Int] = path.enumerated().compactMap { offset, index in
            if endingOnGift && offset == path.count - 1 {
                return nil
            }
            return TileStepMath.step(for: self[index].tile)
        }
        guard stepsOnPath.count == (endingOnGift ? path.count - 1 : path.count) else { return nil }
        let resultStep = TileStepMath.mergedStep(from: stepsOnPath)
        let resultVal = TileStepMath.value(forStep: resultStep)
        
        // Check if ending on gift
        let finalIndex = chain.last!
        let giftBroken = endingOnGift && self[finalIndex].kind == .gift
        let giftColumn = giftBroken ? finalIndex.col : nil

        // Clear consumed cells (all except the final position)
        let consumed = Array(chain.dropLast())
        for index in consumed {
            self[index] = Cell.empty
        }

        // If ending on gift, consume the gift and place result
        let resultTile = Tile.make(forStep: resultStep)
        self[finalIndex] = Cell.withTile(resultTile)

        return MergeOutcome(
            consumed: consumed,
            resultAt: finalIndex,
            resultValue: resultVal,
            resultStep: resultStep,
            giftBroken: giftBroken,
            giftColumn: giftColumn
        )
    }
    
    // MARK: - Gravity System
    
    public mutating func applyGravity() {
        // Compact each column so tiles fall toward bottom
        for col in 0..<width {
            collapseColumn(col)
        }
    }
    
    public mutating func collapseColumns(_ columns: Set<Int>) {
        guard !columns.isEmpty else { return }
        for col in columns {
            collapseColumn(col)
        }
    }
    
    private mutating func collapseColumn(_ col: Int) {
        guard col >= 0 && col < width else { return }
        var compactedColumn: [Cell] = []
        var fixedGifts: [Int: Cell] = [:]
        
        // Collect all non-empty, non-gift cells from bottom to top
        for row in (0..<height).reversed() {
            let index = BoardIndex(row: row, col: col)
            let cell = self[index]
            switch cell.kind {
            case .gift:
                fixedGifts[row] = cell
            case .empty:
                continue
            default:
                compactedColumn.append(cell)
            }
        }
        
        // Clear the column except for gifts
        for row in 0..<height {
            let index = BoardIndex(row: row, col: col)
            if fixedGifts[row] != nil {
                continue
            }
            self[index] = Cell.empty
        }
        
        // Place compacted cells back from bottom
        for (i, cell) in compactedColumn.enumerated() {
            let targetRow = height - 1 - i
            // Skip rows reserved for gifts
            var adjustedRow = targetRow
            while adjustedRow >= 0 && fixedGifts[adjustedRow] != nil {
                adjustedRow -= 1
            }
            if adjustedRow >= 0 {
                let index = BoardIndex(row: adjustedRow, col: col)
                self[index] = cell
            }
        }
        
        // Restore gifts at their original rows
        for (row, giftCell) in fixedGifts {
            let index = BoardIndex(row: row, col: col)
            self[index] = giftCell
        }
    }
    
    public mutating func refillColumns(_ columns: Set<Int>, fillAll: Bool, generator: () -> Int) {
        guard !columns.isEmpty else { return }
        for col in columns {
            refillColumn(col, fillAll: fillAll, generator: generator)
        }
    }
    
    private mutating func refillColumn(_ col: Int, fillAll: Bool, generator: () -> Int) {
        guard col >= 0 && col < width else { return }
        if fillAll {
            for row in 0..<height {
                let index = BoardIndex(row: row, col: col)
                guard self[index].kind == .empty else { continue }
                let value = generator()
                self[index] = Cell.withTile(Tile(value: value))
            }
        } else {
            let topIndex = BoardIndex(row: 0, col: col)
            if self[topIndex].kind == .empty {
                let value = generator()
                self[topIndex] = Cell.withTile(Tile(value: value))
            }
        }
    }
    
    public mutating func refillEmptyCells(generator: () -> Int) {
        for row in 0..<height {
            for col in 0..<width {
                let index = BoardIndex(row: row, col: col)
                if self[index].kind == .empty {
                    let value = generator()
                    self[index] = Cell.withTile(Tile(value: value))
                }
            }
        }
    }
    
    // Refill a specific column in the top row with a new gift cell
    public mutating func refillGiftAtColumn(_ col: Int, generator: () -> Int) {
        guard col >= 0 && col < width else { return }
        let index = BoardIndex(row: 0, col: col)
        // Always replace with a gift, even if the cell currently has a tile
        let value = generator()
        let gift = Gift(targetValue: value)
        self[index] = Cell.withGift(gift)
    }

    // Refill only the top row with new gift cells (fills empty cells only)
    public mutating func refillTopRowWithGifts(generator: () -> Int) {
        for col in 0..<width {
            let index = BoardIndex(row: 0, col: col)
            if self[index].kind == .empty {
                let value = generator()
                let gift = Gift(targetValue: value)
                self[index] = Cell.withGift(gift)
            }
        }
    }
    
    // MARK: - Gift Interaction Helpers
    
    public func validateGiftChain(_ chain: [BoardIndex]) -> ChainValidation {
        guard chain.count >= 2 else {
            return ChainValidation.invalid("Chain must have at least 2 tiles")
        }
        
        // Check if ending on gift
        let lastIndex = chain.last!
        let lastCell = self[lastIndex]
        let endingOnGift = lastCell.kind == .gift
        
        if endingOnGift {
            // Ensure previous tile is adjacent
            guard chain.count >= 2 else {
                return ChainValidation.invalid("Cannot start chain on gift")
            }
            
            let prevIndex = chain[chain.count - 2]
            if !isAdjacent(prevIndex, lastIndex) {
                return ChainValidation.invalid("Gift must be adjacent to previous tile")
            }
            
            // Validate chain up to the gift (excluding gift from normal validation)
            let chainWithoutGift = Array(chain.dropLast())
            return validateNormalChain(chainWithoutGift)
        } else {
            return validateNormalChain(chain)
        }
    }
    
    private func validateNormalChain(_ chain: [BoardIndex]) -> ChainValidation {
        guard chain.count >= 2 else {
            return ChainValidation.invalid("Chain must have at least 2 tiles")
        }
        
        // Validate chain links
        for i in 1..<chain.count {
            if !canAppend(next: chain[i], to: Array(chain.prefix(i))) {
                return ChainValidation.invalid("Invalid chain link at position \(i)")
            }
        }
        
        return ChainValidation.valid
    }
    
    public func neighbors(of position: Position, includeDiagonals: Bool = true) -> [Position] {
        let candidates = includeDiagonals ? 
            Direction.allCases.map { position.moved(in: $0) } :
            [position.moved(in: .up),
             position.moved(in: .down),
             position.moved(in: .left),
             position.moved(in: .right)]
        return candidates.filter { $0.isValid(for: self) }
    }
    
    public func hasAdjacentEqualPair(includeDiagonals: Bool = true) -> Bool {
        for row in 0..<height {
            for col in 0..<width {
                let position = Position(row: row, col: col)
                guard let tile = self[position] else { continue }
                
                for neighbor in neighbors(of: position, includeDiagonals: includeDiagonals) {
                    if tilesMatch(self[neighbor], tile) {
                        return true
                    }
                }
            }
        }
        return false
    }
}

private func tilesMatch(_ a: Tile?, _ b: Tile?) -> Bool {
    guard let left = a, let right = b else { return false }
    return left.matches(right)
}
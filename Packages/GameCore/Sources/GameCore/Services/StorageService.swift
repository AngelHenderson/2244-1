import Foundation

public struct SaveData: Codable, Sendable, Equatable {
    public let board: [Int]
    public let width: Int
    public let height: Int
    public let score: Int
    public let best: Int
    public let seed: UInt64?
    public let theme: String
    public let timestamp: Date
    
    public init(
        board: [Int],
        width: Int,
        height: Int,
        score: Int,
        best: Int,
        seed: UInt64?,
        theme: String,
        timestamp: Date
    ) {
        self.board = board
        self.width = width
        self.height = height
        self.score = score
        self.best = best
        self.seed = seed
        self.theme = theme
        self.timestamp = timestamp
    }
}

public struct SaveSlotMeta: Codable, Sendable, Equatable {
    public let id: String
    public let best: Int
    public let updatedAt: Date
    
    public init(id: String, best: Int, updatedAt: Date) {
        self.id = id
        self.best = best
        self.updatedAt = updatedAt
    }
}

public protocol StorageServiceProtocol: Sendable {
    func loadSlots() async -> [SaveSlotMeta]
    func load(slotId: String) async -> SaveData?
    func save(slotId: String, data: SaveData) async
    func delete(slotId: String) async
    func bestScore() async -> Int
    func setBestScore(_ value: Int) async
}

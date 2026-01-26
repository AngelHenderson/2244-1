import Foundation

public struct UserDefaultsStorageService: StorageServiceProtocol, @unchecked Sendable {
    private let suiteName: String
    
    public init(suiteName: String = "com.angelhenderson.game2248.storage") {
        self.suiteName = suiteName
    }
    
    // MARK: - Keys
    private enum Keys {
        static let slotsIndex = "slots.index"
        static let slotPrefix = "slot."
        static let bestScore = "best.score"
    }
    
    // MARK: - Slots Index Helpers
    private var defaults: UserDefaults { UserDefaults(suiteName: suiteName) ?? .standard }
    
    private func readSlotsIndex() -> [String] {
        (defaults.array(forKey: Keys.slotsIndex) as? [String]) ?? []
    }
    
    private func writeSlotsIndex(_ ids: [String]) {
        defaults.set(ids, forKey: Keys.slotsIndex)
    }
    
    private func slotKey(_ id: String) -> String { Keys.slotPrefix + id }
    
    // MARK: - StorageServiceProtocol
    public func loadSlots() async -> [SaveSlotMeta] {
        let ids = readSlotsIndex()
        let decoder = JSONDecoder()
        return ids.compactMap { id in
            guard let data = defaults.data(forKey: slotKey(id)),
                  let save = try? decoder.decode(SaveData.self, from: data) else { return nil }
            return SaveSlotMeta(id: id, best: max(save.best, save.score), updatedAt: save.timestamp)
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }
    
    public func load(slotId: String) async -> SaveData? {
        guard let data = defaults.data(forKey: slotKey(slotId)) else { return nil }
        return try? JSONDecoder().decode(SaveData.self, from: data)
    }
    
    public func save(slotId: String, data: SaveData) async {
        var index = readSlotsIndex()
        if !index.contains(slotId) {
            index.append(slotId)
            writeSlotsIndex(index)
        }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: slotKey(slotId))
        }
        // Update best score cache if higher
        let best = await bestScore()
        if max(data.best, data.score) > best {
            await setBestScore(max(data.best, data.score))
        }
    }
    
    public func delete(slotId: String) async {
        var index = readSlotsIndex()
        if let i = index.firstIndex(of: slotId) {
            index.remove(at: i)
            writeSlotsIndex(index)
        }
        defaults.removeObject(forKey: slotKey(slotId))
    }
    
    public func bestScore() async -> Int {
        defaults.integer(forKey: Keys.bestScore)
    }
    
    public func setBestScore(_ value: Int) async {
        defaults.set(value, forKey: Keys.bestScore)
    }
}
